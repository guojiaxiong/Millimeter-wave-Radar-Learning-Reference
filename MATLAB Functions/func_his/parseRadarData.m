function [rx0Data, rx1Data, chirpCount, hasMoreData, newPosition] = parseRadarData(filePath, currentPosition)
% parseRadarData - 解析雷达二进制数据文件中的一对帧数据(相同chirp序号的RX0和RX1)
%
% 输入:
%   filePath - 雷达数据文件的路径
%   currentPosition - 当前文件位置，首次调用时传入0
%
% 输出:
%   rx0Data - RX0通道的chirp数据
%   rx1Data - RX1通道的chirp数据
%   chirpCount - 当前chirp的序号
%   hasMoreData - 是否还有更多chirp数据可供读取
%   newPosition - 更新后的文件位置，用于下次调用

    % 初始化返回值
    rx0Data = [];
    rx1Data = [];
    chirpCount = NaN;
    hasMoreData = false;
    newPosition = currentPosition;  % 默认保持位置不变
    
    % 静态变量存储，避免重复读取文件
    persistent fileData;
    persistent processedPosition;
    persistent fileSize;
    
    % 如果是首次调用或者切换了文件，读取整个文件数据
    if isempty(fileData) || currentPosition == 0
        % 读取二进制数据文件
        fid = fopen(filePath, 'rb');
        
        if fid == -1
            error('无法打开文件: %s', filePath);
        end
        
        % 读取所有数据
        fileData = fread(fid, 'uint8');
        fclose(fid);
        
        % 显示文件基本信息
        fileSize = length(fileData);
        fprintf('文件名: %s\n', filePath);
        fprintf('文件大小: %d 字节\n', fileSize);
        
        % 初始化处理位置
        processedPosition = 1;
    else
        % 继续从上次位置开始处理
        processedPosition = currentPosition;
    end
    
    % 存储当前帧对中找到的数据
    frameDataPair = cell(1, 2);
    pairCount = 0;
    
    % 开始查找MCU数据包
    while processedPosition <= fileSize - 12 && pairCount < 2
        % 检查是否找到有效的MCU包头 (0x49, 0x43, 0x4C, 0x48)
        if fileData(processedPosition) == hex2dec('49') && ...
           fileData(processedPosition+1) == hex2dec('43') && ...
           fileData(processedPosition+2) == hex2dec('4C') && ...
           fileData(processedPosition+3) == hex2dec('48')
            
            % 提取长度字段 (2个字节)
            dataLength = typecast(uint8(fileData(processedPosition+4:processedPosition+5)), 'uint16');
            
            % 提取类型字段 (1个字节)
            packetType = fileData(processedPosition+6);
            
            % 提取额外字段（通道号，1个字节）
            channelNum = fileData(processedPosition+7);
            
            % 验证这是一个数据包 (Type = 0x00)
            if packetType == 0
                % 这是一个有效的数据包
                fprintf('\n找到有效的MCU数据包:\n');
                fprintf('包位置: 0x%06X\n', processedPosition-1);
                fprintf('Data长度: %d 字节\n', dataLength);
                fprintf('通道号: %d\n', channelNum);
                
                % 验证数据长度的合理性
                if dataLength > 0 && dataLength < 10000  % 设置一个合理上限
                    % 提取数据部分
                    dataStart = processedPosition + 8;
                    dataEnd = dataStart + dataLength - 1;
                    
                    % 确保我们有足够的数据
                    if dataEnd <= fileSize
                        % 获取这一帧的数据
                        currentFrameData = fileData(dataStart:dataEnd);
                        
                        % 打印帧内容的前几个字节作为参考
                        fprintf('\n帧数据前32个字节 (十六进制):\n');
                        for i = 1:min(32, length(currentFrameData))
                            fprintf('%02X ', currentFrameData(i));
                            if mod(i, 16) == 0
                                fprintf('\n');
                            end
                        end
                        fprintf('\n');
                        
                        % 存储当前帧数据
                        pairCount = pairCount + 1;
                        frameDataPair{pairCount} = currentFrameData;
                        
                        % 记录当前处理位置用于下次调用
                        newPosition = dataEnd + 5;  % 4字节尾部 + 1
                        
                        % 移动到下一个可能的包位置
                        processedPosition = dataEnd + 5;
                    else
                        % 数据不足以完成一个完整包，跳过此包
                        fprintf('警告：帧数据不完整，跳过此帧\n');
                        processedPosition = processedPosition + 1;
                    end
                else
                    % 数据长度不合理，跳过此包
                    fprintf('警告：无效的数据长度 (%d)，跳过此潜在包\n', dataLength);
                    processedPosition = processedPosition + 1;
                end
            else
                % 不是数据包，前进
                processedPosition = processedPosition + 1;
            end
        else
            % 不是有效的头部，前进
            processedPosition = processedPosition + 1;
        end
    end
    
    % 处理找到的帧
    if pairCount > 0
        % 尝试从帧中提取RX0和RX1数据
        [rx0Data, rx1Data, chirpCount] = processFramePair(frameDataPair);
        
        % 设置返回标志
        hasMoreData = (processedPosition < fileSize - 12);
    else
        fprintf('\n未找到有效的雷达数据帧\n');
        hasMoreData = false;
    end
end

function [rx0Data, rx1Data, chirpCount] = processFramePair(frameDataPair)
    % 初始化RX0和RX1数据数组
    rx0Data = [];
    rx1Data = [];
    chirpCount = NaN;
    
    % 依次处理帧数据，寻找RX0和RX1通道
    for frameIdx = 1:length(frameDataPair)
        if isempty(frameDataPair{frameIdx})
            continue; % 跳过空帧
        end
        
        fprintf('\n处理第 %d 帧数据\n', frameIdx);
        frameData = frameDataPair{frameIdx};
        
        % 查找AA开头的DS RAW数据
        position = 1;
        while position < length(frameData)
            % 检查是否是DS RAW包头标记 (0xAA 开头)
            if frameData(position) == hex2dec('AA')
                % 读取完整的头部（4字节）
                if position + 3 <= length(frameData)
                    % 解析头部
                    header = typecast(uint8(frameData(position+3:-1:position)), 'uint32');
                    
                    % 提取各个字段以便调试
%                     header_bits = fliplr(dec2bin(header, 32));
%                     header_bits1 = dec2bin(header, 32);
%                     
%                     % 按照格式分割字段
%                     b1010_1010 = fliplr(header_bits(25:32));
%                     field_23_1 = header_bits(24);
%                     b010 = header_bits(21:23);
%                     RAW_chirp_cnt = fliplr(header_bits(12:20));
%                     RAW_DATA_cnt = fliplr(header_bits(1:11));
                    
%                     fprintf('DS RAW头部解析:\n');
%                     fprintf('反转后的数据: %s\n', header_bits);
%                     fprintf('原始数据: %s\n', header_bits1);
%                     fprintf('''b1010 1010: %s\n', b1010_1010);
%                     fprintf('[23][1]: %s\n', field_23_1);
%                     fprintf('''b010: %s\n', b010);
%                     fprintf('RAW_chirp_cnt (bit 7:0, 8) [19:11][2]: %s\n', RAW_chirp_cnt);
%                     fprintf('RAW_DATA_cnt[10:0][3]: %s\n', RAW_DATA_cnt);
                    
                    % 提取数据点数 (RAW_DATA_cnt [10:0])
                    dataCount = bitand(header, 2047);  % 2^11-1 = 2047
                    
                    % 如果数据长度字段显示为0，尝试使用替代值
                    if dataCount == 0
                        fprintf('警告：数据长度为0，使用默认值256\n');
                        dataCount = 256;
                    else
                        dataCount = dataCount - 1;  % 减1处理
                    end
                    
                    % 提取通道信息 (RX0/RX1) [23]位
                    isRx1 = bitget(header, 24) == 1;
                    
                    % 提取Chirp序号 [19:11]
                    chirpCount = bitand(bitshift(header, -11), 511);  % 2^9-1 = 511
                    
                    % 验证数据点数的合理性
                    if dataCount > 0 && dataCount < 1000  % 设置一个合理上限
                        % 计算整个DS RAW包需要的总字节数
                        totalPacketSize = 4 + dataCount * 4 + 4;  % 头部 + 数据 + 尾部
                        
                        fprintf('检测到DS RAW包: 通道=%s, Chirp序号=%d, 数据点数=%d, 需要总字节数=%d\n', ...
                            iif(isRx1, 'RX1', 'RX0'), chirpCount, dataCount, totalPacketSize);
                        
                        % 确认我们有足够的数据来处理这个包
                        if position + totalPacketSize - 1 <= length(frameData)
                            % 提取复数数据
                            complexData = extractComplexData(frameData, position, dataCount);
                            
                            % 将提取的数据添加到相应通道
                            if isRx1
                                rx1Data = complexData;
                                fprintf('成功提取RX1通道数据，chirp序号=%d\n', chirpCount);
                            else
                                rx0Data = complexData;
                                fprintf('成功提取RX0通道数据，chirp序号=%d\n', chirpCount);
                            end
                            
                            % 移动位置到下一个可能的包头
                            position = position + totalPacketSize;
                        else
                            fprintf('警告：DS RAW包数据不完整，可用=%d字节，需要=%d字节\n', ...
                                length(frameData) - position + 1, totalPacketSize);
                            position = position + 1;  % 尝试寻找下一个可能的包头
                        end
                    else
                        % 数据点数不合理
                        fprintf('警告：无效的数据点数 (%d)，跳过此潜在包\n', dataCount);
                        position = position + 1;
                    end
                else
                    % 头部不完整
                    position = position + 1;
                end
            else
                % 不是包头标记，继续
                position = position + 1;
            end
        end
    end
    
    % 显示提取的数据统计
    fprintf('\nRX0通道数据点数: %d\n', length(rx0Data));
    fprintf('RX1通道数据点数: %d\n', length(rx1Data));
    
%     % 显示前几个数据点
%     maxDisplay = 5;
%     if ~isempty(rx0Data)
%         fprintf('\nRX0前%d个数据点 (实部和虚部都是有符号数):\n', min(maxDisplay, length(rx0Data)));
%         for i = 1:min(maxDisplay, length(rx0Data))
%             fprintf('  数据点 %d: %d%+dj\n', i, real(rx0Data(i)), imag(rx0Data(i)));
%         end
%     end
%     
%     if ~isempty(rx1Data)
%         fprintf('\nRX1前%d个数据点 (实部和虚部都是有符号数):\n', min(maxDisplay, length(rx1Data)));
%         for i = 1:min(maxDisplay, length(rx1Data))
%             fprintf('  数据点 %d: %d%+dj\n', i, real(rx1Data(i)), imag(rx1Data(i)));
%         end
%     end
end

function complexData = extractComplexData(frameData, position, dataCount)
    % 准备存储的数组
    tempRealData = zeros(dataCount, 1);
    tempImagData = zeros(dataCount, 1);
    
    % 开始提取数据 - 从头部后的位置开始
    dataStartPos = position + 4;
    
    % 循环提取每个复数数据点 (实部和虚部)
    for i = 1:dataCount
        if dataStartPos + 3 <= length(frameData)
            dataWord = typecast(uint8(frameData(dataStartPos+1:-1:dataStartPos)), 'uint16');
            dataWord1 = typecast(uint8(frameData(dataStartPos+3:-1:dataStartPos+2)), 'uint16');
            dataWord_bits = dec2bin(dataWord, 16);
            dataWord_bits1 = dec2bin(dataWord1, 16);

            realPart = bin2dec(dataWord_bits);
            imagPart = bin2dec(dataWord_bits1);
            
            % 检查最高位（符号位）
            if dataWord_bits(1) == '1'
                % 如果是负数，计算补码
                realPart = -(2^16 - realPart);
            end
            if dataWord_bits1(1) == '1'
                % 如果是负数，计算补码
                imagPart = -(2^16 - imagPart);
            end   
            % 存储数据
            tempRealData(i) = double(realPart);
            tempImagData(i) = double(imagPart);
            
            % 移动到下一个数据字
            dataStartPos = dataStartPos + 4;
        else
            fprintf('警告：读取数据字时遇到文件结尾\n');
            break;
        end
    end
    
    % 创建复数数据
    complexData = complex(tempRealData, tempImagData);
end

function result = iif(condition, trueVal, falseVal)
    % 实现类似三元运算符的功能
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end