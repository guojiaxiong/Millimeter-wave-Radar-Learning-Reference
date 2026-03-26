function [rx0AllData, rx1AllData, chirpCounts, hasMoreData, newPosition] = ...
    readRadarFrame(filename, chirpsPerFrame, currentPosition)
% readRadarFrame - 从雷达数据文件中读取一整帧数据，并返回文件新位置
%
% 输入:
%   filename - 雷达数据文件的路径
%   chirpsPerFrame - 每帧包含的chirp数量(默认32)
%   currentPosition - 当前文件位置(若为0则从文件开始处读取)
%
% 输出:
%   rx0AllData - 包含所有RX0通道chirp数据的cell数组
%   rx1AllData - 包含所有RX1通道chirp数据的cell数组
%   chirpCounts - 每个chirp的序号数组
%   hasMoreData - 是否还有更多数据可供读取
%   newPosition - 更新后的文件位置，用于下次调用

% 设置默认参数
if nargin < 3
    currentPosition = uint64(0);
end
if nargin < 2
    chirpsPerFrame = 32; % 默认每帧32个chirp
end

% 初始化返回变量
rx0AllData = cell(1, chirpsPerFrame);
rx1AllData = cell(1, chirpsPerFrame);
chirpCounts = zeros(1, chirpsPerFrame);
hasMoreData = false;
newPosition = currentPosition;

% 期望的chirp序号
expectedChirps = 0:2:((chirpsPerFrame*2)-2);

% fprintf('从文件位置 0x%X 开始读取雷达数据...\n', currentPosition);
tic; % 开始计时

% 变量用于跟踪帧读取状态
chirpsInFrame = 0;
foundChirps = false(1, chirpsPerFrame);
frameComplete = false;

% 设置每个chirp的查找起始位置
% 对于第一帧或重新开始的情况，需要找到chirp序号0
needFirstChirp = (currentPosition == 0);
firstChirpIndex = 1; % 对应chirp序号0

% 尝试读取足够多的chirp直到完成一帧
maxAttempts = chirpsPerFrame * 20; % 设置最大尝试次数防止死循环
attempts = 0;

while ~frameComplete && attempts < maxAttempts
    attempts = attempts + 1;
    
    % 读取下一个chirp数据
    [rx0Data, rx1Data, chirpCount, stillHasData, currentPosition] = ...
        parseRadarData(filename, currentPosition);
    
    % 更新hasMoreData状态
    hasMoreData = stillHasData;
    
    % 如果没有更多数据，退出循环
    if ~hasMoreData
        fprintf('文件结束，无法完成当前帧\n');
        break;
    end
    
    % 检查是否成功提取了数据
    if isempty(rx0Data) && isempty(rx1Data)
        fprintf('未能提取有效数据，尝试下一个位置\n');
        continue;
    end
    
    % 检查是否需要找到第一个chirp(序号0)
    if needFirstChirp
        if chirpCount == 0
            fprintf('找到第一个chirp序号0的数据\n');
            needFirstChirp = false;
            
            % 保存数据
            rx0AllData{firstChirpIndex} = rx0Data;
            rx1AllData{firstChirpIndex} = rx1Data;
            chirpCounts(firstChirpIndex) = chirpCount;
            foundChirps(firstChirpIndex) = true;
            chirpsInFrame = chirpsInFrame + 1;
        else
%             fprintf('跳过非序号0的chirp: %d\n', chirpCount);
            continue;
        end
    else
        % 检查chirp序号是否在期望范围内
        chirpIndex = find(expectedChirps == chirpCount, 1);
        
        if ~isempty(chirpIndex) && ~foundChirps(chirpIndex)
            % 找到了期望的chirp
            foundChirps(chirpIndex) = true;
            chirpsInFrame = chirpsInFrame + 1;
            
            % 存储chirp数据
            rx0AllData{chirpIndex} = rx0Data;
            rx1AllData{chirpIndex} = rx1Data;
            chirpCounts(chirpIndex) = chirpCount;
            
%             fprintf('找到chirp序号 %d (index=%d)，已完成 %d/%d\n', ...
%                 chirpCount, chirpIndex, chirpsInFrame, chirpsPerFrame);
        else
            % 如果找到了已经在帧中的chirp序号，可能是下一帧的开始
            if ~isempty(chirpIndex) && chirpCount == 0 && chirpsInFrame > 0
                fprintf('检测到新帧的开始(chirp 0)，当前帧读取结束\n');
                
                % 将文件位置回退，以便下次从这个位置开始读取
                newPosition = currentPosition;
                break;
            else
                % 不在期望范围内的chirp或已找到的chirp
                fprintf('跳过非期望序号的chirp: %d\n', chirpCount);
            end
        end
    end
    
    % 记录文件位置
    newPosition = currentPosition;
    
    % 检查一帧是否完成
    if chirpsInFrame >= chirpsPerFrame || all(foundChirps)
        frameComplete = true;
    end
end

% 帧处理完成后的统计
frameTime = toc;
fprintf('\n帧读取完成，包含 %d 个chirp，处理时间 %.2f 秒\n', chirpsInFrame, frameTime);

% 检查帧完整性
if frameComplete
    fprintf('成功读取完整帧数据\n');
else
    fprintf('警告: 未能读取完整帧数据，仅获取了 %d/%d 个chirp\n', chirpsInFrame, chirpsPerFrame);
end
end

function [rx0Data, rx1Data, chirpCount, hasMoreData, newPosition] = parseRadarData(filePath, currentPosition)
% parseRadarData - 解析雷达二进制数据文件中的一对帧数据(相同chirp序号的RX0和RX1)
%
% 输入:
% filePath - 雷达数据文件的路径
% currentPosition - 当前文件位置，首次调用时传入0 (现在使用64位整型)
%
% 输出:
% rx0Data - RX0通道的chirp数据
% rx1Data - RX1通道的chirp数据
% chirpCount - 当前chirp的序号
% hasMoreData - 是否还有更多chirp数据可供读取
% newPosition - 更新后的文件位置，用于下次调用

% 将位置转换为64位整型
currentPosition = int64(currentPosition);

% 初始化返回值
rx0Data = [];
rx1Data = [];
chirpCount = NaN;
hasMoreData = false;
newPosition = currentPosition;  % 默认保持位置不变

% 静态变量存储，避免重复打开文件
persistent fid;
persistent fileSize;
persistent filePath_prev;

% 如果是首次调用或者切换了文件，打开新文件
if isempty(fid) || currentPosition == 0 || ~strcmp(filePath, filePath_prev)
    % 关闭之前的文件句柄（如果存在）
    if ~isempty(fid) && fid ~= -1
        fclose(fid);
    end
    
    % 打开新文件
    fid = fopen(filePath, 'rb');
    filePath_prev = filePath;
    
    if fid == -1
        error('无法打开文件: %s', filePath);
    end
    
    % 获取文件大小
    fseek(fid, 0, 'eof');
    fileSize = int64(ftell(fid));
    fseek(fid, 0, 'bof');
    
    % 显示文件基本信息
    fprintf('文件名: %s\n', filePath);
    fprintf('文件大小: %d 字节\n', fileSize);
end

% 确保文件位置正确
if currentPosition > 0
    status = fseek(fid, currentPosition, 'bof');
    if status == -1
        error('无法设置文件位置到 %d', currentPosition);
    end
end

% 声明最大尝试次数，防止无限循环
maxAttempts = 100;
attemptCount = 0;

% 主循环：尝试找到完整的RX0/RX1数据对
while attemptCount < maxAttempts
    attemptCount = attemptCount + 1;
    
    % 清空现有的缓存数据
    tempChirpData = struct();  % 用于存储不同chirp号的数据
    processedPosition = currentPosition;
    
    % 定义读取缓冲区大小
    bufferSize = int64(1024 * 1024); % 1MB 缓冲区
    
    % 搜索数据包，直到找到完整的RX0/RX1数据对或达到文件末尾
    while processedPosition <= fileSize - 12
        % 读取足够的数据进行包头检测
        bytesToRead = min(bufferSize, fileSize - processedPosition);
        if bytesToRead < 12
            break; % 剩余数据不足以构成一个完整头部
        end
        
        % 设置文件位置并读取数据块
        fseek(fid, processedPosition, 'bof');
        dataBlock = fread(fid, bytesToRead, 'uint8');
        
        % 在数据块中查找包头
        blockPos = int64(1);
        while blockPos <= length(dataBlock) - 11
            % 检查是否找到有效的MCU包头 (0x49, 0x43, 0x4C, 0x48)
            if dataBlock(blockPos) == hex2dec('49') && ...
               dataBlock(blockPos+1) == hex2dec('43') && ...
               dataBlock(blockPos+2) == hex2dec('4C') && ...
               dataBlock(blockPos+3) == hex2dec('48')
                
                % 提取长度字段 (2个字节)
                dataLength = int64(typecast(uint8(dataBlock(blockPos+4:blockPos+5)), 'uint16'));
                
                % 提取类型字段 (1个字节)
                packetType = dataBlock(blockPos+6);
                
                % 提取额外字段（通道号，1个字节）
                channelNum = dataBlock(blockPos+7);
                
                % 验证这是一个数据包 (Type = 0x00)
                if packetType == 0
                    % 验证数据长度的合理性
                    if dataLength > 0 && dataLength < 10000  % 设置一个合理上限
                        % 计算数据范围
                        dataStart = int64(blockPos + 8);
                        dataEnd = dataStart + dataLength - int64(1);
                        
                        % 确保数据块包含完整数据
                        if dataEnd <= length(dataBlock)
                            % 获取这一帧的数据
                            currentFrameData = dataBlock(dataStart:dataEnd);
                            
                            % 检查这是否含有DS RAW数据
                            [hasRawData, isRx1, curChirpCount] = checkRawDataType(currentFrameData);
                            
                            if hasRawData
%                                 fprintf('包含DS RAW数据，通道=%s, Chirp序号=%d\n', ...
%                                     iif(isRx1, 'RX1', 'RX0'), curChirpCount);
                                
                                % 创建或更新该chirp序号的数据结构
                                if ~isfield(tempChirpData, ['c' num2str(curChirpCount)])
                                    tempChirpData.(['c' num2str(curChirpCount)]) = struct('rx0', [], 'rx1', [], 'complete', false);
                                end
                                
                                % 存储数据到对应的通道
                                if isRx1
                                    tempChirpData.(['c' num2str(curChirpCount)]).rx1 = currentFrameData;
                                else
                                    tempChirpData.(['c' num2str(curChirpCount)]).rx0 = currentFrameData;
                                end
                                
                                % 检查该chirp是否已有完整的RX0和RX1数据
                                if ~isempty(tempChirpData.(['c' num2str(curChirpCount)]).rx0) && ...
                                   ~isempty(tempChirpData.(['c' num2str(curChirpCount)]).rx1)
                                    tempChirpData.(['c' num2str(curChirpCount)]).complete = true;
                                    
                                    % 找到完整的数据对，提取数据并返回
                                    rx0Data = extractComplexDataFromFrame(tempChirpData.(['c' num2str(curChirpCount)]).rx0);
                                    rx1Data = extractComplexDataFromFrame(tempChirpData.(['c' num2str(curChirpCount)]).rx1);
                                    chirpCount = curChirpCount;
                                    
                                    % 更新文件位置
                                    newPosition = processedPosition + blockPos + int64(1);
                                    hasMoreData = (newPosition < fileSize - 12);
                                    
%                                     fprintf('找到完整的RX0/RX1数据对，Chirp序号=%d\n', chirpCount);
%                                     fprintf('RX0通道数据点数: %d\n', length(rx0Data));
%                                     fprintf('RX1通道数据点数: %d\n', length(rx1Data));
                                    
                                    return;  % 找到完整数据对，提前返回
                                end
                            end
                            
                            % 移动位置到下一个可能的包
                            blockPos = dataEnd + int64(5); % 4字节尾部 + 1
                        else
                            % 如果当前数据块不足以包含完整数据包
                            % 直接从文件读取完整的包
                            totalPacketSize = int64(8) + dataLength + int64(4); % 头部8字节 + 数据 + 尾部4字节
                            
                            % 检查文件是否有足够数据
                            if processedPosition + blockPos + totalPacketSize - int64(2) <= fileSize
                                % 设置文件位置到数据包开始
                                fseek(fid, processedPosition + blockPos - int64(1), 'bof');
                                
                                % 读取整个数据包
                                completePacket = fread(fid, totalPacketSize, 'uint8');
                                
                                % 提取数据部分
                                currentFrameData = completePacket(9:9+double(dataLength)-1);
                                
                                % 检查这是否含有DS RAW数据
                                [hasRawData, isRx1, curChirpCount] = checkRawDataType(currentFrameData);
                                
                                if hasRawData
%                                     fprintf('包含DS RAW数据，通道=%s, Chirp序号=%d\n', ...
%                                         iif(isRx1, 'RX1', 'RX0'), curChirpCount);
                                    
                                    % 创建或更新该chirp序号的数据结构
                                    if ~isfield(tempChirpData, ['c' num2str(curChirpCount)])
                                        tempChirpData.(['c' num2str(curChirpCount)]) = struct('rx0', [], 'rx1', [], 'complete', false);
                                    end
                                    
                                    % 存储数据到对应的通道
                                    if isRx1
                                        tempChirpData.(['c' num2str(curChirpCount)]).rx1 = currentFrameData;
                                    else
                                        tempChirpData.(['c' num2str(curChirpCount)]).rx0 = currentFrameData;
                                    end
                                    
                                    % 检查该chirp是否已有完整的RX0和RX1数据
                                    if ~isempty(tempChirpData.(['c' num2str(curChirpCount)]).rx0) && ...
                                       ~isempty(tempChirpData.(['c' num2str(curChirpCount)]).rx1)
                                        tempChirpData.(['c' num2str(curChirpCount)]).complete = true;
                                        
                                        % 找到完整的数据对，提取数据并返回
                                        rx0Data = extractComplexDataFromFrame(tempChirpData.(['c' num2str(curChirpCount)]).rx0);
                                        rx1Data = extractComplexDataFromFrame(tempChirpData.(['c' num2str(curChirpCount)]).rx1);
                                        chirpCount = curChirpCount;
                                        
                                        % 更新文件位置
                                        newPosition = processedPosition + blockPos + totalPacketSize - int64(1);
                                        hasMoreData = (newPosition < fileSize - 12);
                                        
                                        %fprintf('找到完整的RX0/RX1数据对，Chirp序号=%d\n', chirpCount);
%                                         fprintf('RX0通道数据点数: %d\n', length(rx0Data));
%                                         fprintf('RX1通道数据点数: %d\n', length(rx1Data));
                                        
                                        return;  % 找到完整数据对，提前返回
                                    end
                                end
                                
                                % 更新处理位置
                                processedPosition = processedPosition + blockPos + totalPacketSize - int64(2);
                                blockPos = int64(length(dataBlock) + 1); % 强制跳出当前数据块循环
                                break;  % 跳出当前循环，更新数据块
                            else
                                % 文件末尾，数据不足
                                fprintf('警告：文件末尾，数据不足以构成完整包\n');
                                blockPos = blockPos + int64(1);
                            end
                        end
                    else
                        % 数据长度不合理，跳过此包
                        fprintf('警告：无效的数据长度 (%d)，跳过此潜在包\n', dataLength);
                        blockPos = blockPos + int64(1);
                    end
                else
                    % 不是数据包，前进
                    blockPos = blockPos + int64(1);
                end
            else
                % 不是有效的头部，前进
                blockPos = blockPos + int64(1);
            end
            
            % 如果已到达块末尾，跳出内层循环
            if blockPos > length(dataBlock) - 11
                break;
            end
        end
        
        % 更新处理位置
        if blockPos <= length(dataBlock)
            processedPosition = processedPosition + blockPos - int64(12);
            if processedPosition < currentPosition
                processedPosition = currentPosition;
            end
        else
            processedPosition = processedPosition + int64(length(dataBlock)) - int64(11);
        end
        
        % 检查是否到达文件末尾
        if processedPosition >= fileSize - 12
            break;
        end
    end
    
    % 检查是否有任何不完整的chirp数据并清理
    fprintf('尝试%d: 未找到完整的RX0/RX1数据对，清理缓存并继续\n', attemptCount);
    
    % 如果已经到达文件末尾，退出循环
    if processedPosition >= fileSize - 12
        fprintf('到达文件末尾，无法找到完整的RX0/RX1数据对\n');
        break;
    end
    
    % 更新当前位置，继续尝试
    currentPosition = processedPosition;
end

% 如果达到最大尝试次数仍未找到完整数据对
if attemptCount >= maxAttempts
    fprintf('警告：超过最大尝试次数(%d)，未能找到完整的RX0/RX1数据对\n', maxAttempts);
end

% 更新返回值
newPosition = processedPosition;
hasMoreData = (processedPosition < fileSize - 12);
fprintf('未找到完整的RX0/RX1数据对，返回空数据\n');
end




function [hasRawData, isRx1, chirpCount] = checkRawDataType(frameData)
    % 初始化返回值
    hasRawData = false;
    isRx1 = false;
    chirpCount = NaN;
    
    % 查找AA开头的DS RAW数据
    position = 1;
    while position < length(frameData)
        % 检查是否是DS RAW包头标记 (0xAA 开头)
        if frameData(position) == hex2dec('AA')
            % 读取完整的头部（4字节）
            if position + 3 <= length(frameData)
                % 解析头部
                header = typecast(uint8(frameData(position+3:-1:position)), 'uint32');
                
                % 检查这是否是有效的DS RAW包头 - 最高8位应该是0xAA
                if bitand(bitshift(header, -24), 255) == hex2dec('AA')
                    % 提取通道信息 (RX0/RX1) [23]位
                    isRx1 = bitget(header, 24) == 1;
                    
                    % 提取Chirp序号 [19:11]
                    chirpCount = bitand(bitshift(header, -11), 511);  % 2^9-1 = 511
                    
                    hasRawData = true;
                    return;  % 找到有效数据，立即返回
                end
            end
        end
        
        % 继续搜索
        position = position + 1;
    end
end

function complexData = extractComplexDataFromFrame(frameData)
    % 初始化返回值
    complexData = [];
    
    % 查找AA开头的DS RAW数据
    position = 1;
    while position < length(frameData)
        % 检查是否是DS RAW包头标记 (0xAA 开头)
        if frameData(position) == hex2dec('AA')
            % 读取完整的头部（4字节）
            if position + 3 <= length(frameData)
                % 解析头部
                header = typecast(uint8(frameData(position+3:-1:position)), 'uint32');
                
                % 提取数据点数 (RAW_DATA_cnt [10:0])
                dataCount = int64(bitand(header, 2047));  % 2^11-1 = 2047
                
                % 如果数据长度字段显示为0，尝试使用替代值
                if dataCount == 0
                    dataCount = int64(256);
                else
                    dataCount = dataCount - int64(1);  % 减1处理
                end
                
                % 验证数据点数的合理性
                if dataCount > 0 && dataCount < 1000  % 设置一个合理上限
                    % 提取复数数据
                    complexData = extractComplexData(frameData, position, dataCount);
                    return;  % 找到并提取了数据，立即返回
                end
            end
        end
        
        % 继续搜索
        position = position + 1;
    end
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

