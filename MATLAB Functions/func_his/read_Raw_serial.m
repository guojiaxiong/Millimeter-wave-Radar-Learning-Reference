classdef read_Raw_serial < handle
    properties (Access = private)
        serialObj        % 串口对象
        buf              % 缓存区
        chirpsPerFrame   % 每帧chirp数
        chirpMap         % 用于存储RX0和RX1的数据
    end

    methods
        % ------------------- 构造函数 -----------------------------
        function obj = read_Raw_serial(port, chirpsPerFrame)
            if nargin < 2
                chirpsPerFrame = 32;  % 默认值为32
            end
            obj.serialObj = serialport(port, 115200);  % 串口连接
            configureTerminator(obj.serialObj, "LF");  % 设置终止符
            obj.chirpsPerFrame = chirpsPerFrame;
            obj.buf = uint8([]);
            obj.chirpMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            disp(['串口已连接: ', port]);
        end

        % ---------------------- 关闭串口 ---------------------------
        function close(obj)
            if ~isempty(obj.serialObj)
                clear obj.serialObj;
                disp('串口已关闭');
            end
        end
        
        % ---------------------- 读取一帧 ---------------------------
        function [rx0All, rx1All, chirpArr, hasMore] = readFrame(obj)
            % 初始化返回
            rx0All = cell(1, obj.chirpsPerFrame);
            rx1All = cell(1, obj.chirpsPerFrame);
            chirpArr = nan(1, obj.chirpsPerFrame);
            found = false(1, obj.chirpsPerFrame);
            targetIdx = 0:2:2*obj.chirpsPerFrame - 2;  % 期望的chirp索引
            while true
                [rx0, rx1, cc] = obj.nextChirpPair();  % 获取下一对 RX0 和 RX1
                if isempty(rx0)   % 没有数据时返回
                    rx0All = {};  rx1All = {};  chirpArr = [];
                    hasMore = false;
                    return;
                end
                
                idx = find(targetIdx == cc, 1);
                if isempty(idx) || found(idx)   % 不是本帧需要的 / 已有
                    continue;
                end
                
                rx0All{idx} = rx0;
                rx1All{idx} = rx1;
                chirpArr(idx) = cc;
                found(idx) = true;
                
                if all(found)
                    hasMore = true;
                    return;
                end
            end
        end
        % ---------------------- 读取 N 帧并合并 ----------------------
        function mergedData = readNFramesAndMerge(obj, N)
            % 初始化变量
            rx0 = {};  % 用于存储每帧的RX0数据
            rx1 = {};  % 用于存储每帧的RX1数据
            frameIdx = 0;  % 帧计数器
    
            while frameIdx < N
                % 读取一帧数据
                [rx0Data, rx1Data, ~, hasMore] = obj.readFrame();
                if ~hasMore
                    disp("数据读取完毕，退出循环");
                    break;
                end
                frameIdx = frameIdx + 1;
    
                % 将读取到的RX0、RX1数据拼接到变量中
                rx0 = vertcat(rx0, rx0Data);
                rx1 = vertcat(rx1, rx1Data);
    
                % 合并数据并存储
                mergedData = obj.mergeCells(rx0, rx1);
            end
        end
    end

    % ================== 私有工具函数 ============================
    methods (Access = private)
        function mergedData = mergeCells(obj, rx0, rx1)
            % 数据整理
            frameNum = size(rx0, 1);
            chirpNum = size(rx0, 2);
            sampleNum = size(rx0{1,1}, 1); % 取第一个cell的数据长度
            
            % 初始化目标数组
            % 注意顺序：[Frame, Chirp, Antenna, Sample]
            mergedData = zeros(frameNum, chirpNum, 2, sampleNum);
            
            % 填充数据
            for frameIdx = 1:frameNum
                for chirpIdx = 1:chirpNum
                    mergedData(frameIdx, chirpIdx, 1, :) = rx0{frameIdx, chirpIdx}; % 天线 0
                    mergedData(frameIdx, chirpIdx, 2, :) = rx1{frameIdx, chirpIdx}; % 天线 1
                end
            end
        end
        % -------- 从串口缓冲区获取下一对 RX0 和 RX1 ----------
        function [rx0, rx1, chirpCnt] = nextChirpPair(obj)
            rx0 = []; rx1 = []; chirpCnt = nan;
%             obj.buf = read(obj.serialObj, 1024*1024*2, "uint8");
            while true
                % 缓冲区至少保留12字节用于头部检测
                while numel(obj.buf) < 12
                    obj.readMore();
                end
                if numel(obj.buf) < 12
                    return;  % 文件结束
                end
                
                % ---- 搜索包头 0x49 43 4C 48 ----------------------
                hdrIdx = find(obj.buf(1:end-11) == hex2dec('49') & ...
                               obj.buf(2:end-10) == hex2dec('43') & ...
                               obj.buf(3:end-9) == hex2dec('4C') & ...
                               obj.buf(4:end-8) == hex2dec('48'), 1);
                if isempty(hdrIdx)
                    obj.discard(numel(obj.buf) - 11);
                    continue;
                end
                
                % ---- 读取数据长度字段 ---------------------------
                if hdrIdx + 5 > numel(obj.buf)
                    obj.readMore();
                    continue;
                end
                dataLen = typecast(obj.buf(hdrIdx + 4:hdrIdx + 5), 'uint16');
                pktSize = uint64(8) + uint64(dataLen) + 4;  % 头部+数据+尾部大小
                
                while numel(obj.buf) < hdrIdx - 1 + double(pktSize)
                    obj.readMore();
                end
                
                packet = obj.buf(hdrIdx:hdrIdx + double(pktSize) - 1);
                obj.discard(hdrIdx - 1 + double(pktSize));
                
                % 只处理 Type == 0x00 的数据包
                if packet(7) ~= 0
                    continue;
                end
                
                packetPayload = packet(9:end-4);  % 去除头部和尾部
                [hasRaw, isRx1, cc] = obj.checkRawDataType(packetPayload);
                if ~hasRaw, continue; end
                
                key = sprintf('c%d', cc);
                if ~isKey(obj.chirpMap, key)
                    obj.chirpMap(key) = struct('rx0', [], 'rx1', []);
                end
                entry = obj.chirpMap(key);
                
                if isRx1
                    entry.rx1 = packetPayload;
                else
                    entry.rx0 = packetPayload;
                end
                obj.chirpMap(key) = entry;
                
                % 检查 RX0 和 RX1 是否已经成对
                if ~isempty(entry.rx0) && ~isempty(entry.rx1)
                    rx0 = obj.extractComplexDataFromFrame(entry.rx0);
                    rx1 = obj.extractComplexDataFromFrame(entry.rx1);
                    chirpCnt = cc;
                    remove(obj.chirpMap, key);
                    return;
                end
            end
        end

        % ---------------- 从串口读取更多字节到缓冲区 ----------------
        function readMore(obj)
            % 从串口读取1024字节数据并存入缓冲区
            data = read(obj.serialObj, 1024*128, "uint8");
            obj.buf(end + 1:end + numel(data)) = data;
        end

        % ---------------- 丢弃缓冲区前 n 字节 --------------------
        function discard(obj, n)
            if n <= 0, return; end
            obj.buf = obj.buf(n + 1:end);
        end

        % ================== 数据解析辅助 =========================
        function [hasRaw, isRx1, chirpCnt] = checkRawDataType(~, frameData)
            hasRaw = false; isRx1 = false; chirpCnt = NaN;
            p = 1;
            while p <= numel(frameData) - 3
                if frameData(p) == hex2dec('AA')
                    hdr = typecast(uint8(frameData(p + 3:-1:p)), 'uint32');
                    if bitand(bitshift(hdr, -24), 255) == hex2dec('AA')
                        isRx1 = bitget(hdr, 24) == 1;
                        chirpCnt = bitand(bitshift(hdr, -11), 511);  % 9 位
                        hasRaw = true;
                        return;
                    end
                end
                p = p + 1;
            end
        end

        % ---------------- 提取复数数据 ------------------------
        function cplx = extractComplexDataFromFrame(obj, frameData)
            p = 1;
            while p <= numel(frameData) - 3
                if frameData(p) == hex2dec('AA')
                    hdr = typecast(uint8(frameData(p + 3:-1:p)), 'uint32');
                    if bitand(bitshift(hdr, -24), 255) == hex2dec('AA')
                        N = int64(bitand(hdr, 2047));  % 11 位
                        if N == 0, N = 256; else, N = N - 1; end
                        cplx = obj.extractComplexData(frameData, p + 4, N);
                        return;
                    end
                end
                p = p + 1;
            end
            cplx = [];
        end

        % ---------------- 提取复数数据 ------------------------
        function cplx = extractComplexData(~, data, startPos, N)
            realPart = zeros(N, 1);
            imagPart = zeros(N, 1);
            pos = startPos;
            for k = 1:N
                if pos + 3 > numel(data), break; end
                w0 = typecast(uint8(data(pos + 1:-1:pos)), 'uint16');
                w1 = typecast(uint8(data(pos + 3:-1:pos + 2)), 'uint16');
                realPart(k) = read_Raw_serial.twosComplement(w0, 16);
                imagPart(k) = read_Raw_serial.twosComplement(w1, 16);
                pos = pos + 4;
            end
            cplx = complex(double(realPart), double(imagPart));
        end
    end

    % ================== 静态工具 ===============================
    methods (Static, Access = private)
        function y = twosComplement(x, nbits)
            mask = 2^nbits;
            if bitget(x, nbits) == 1
                y = double(x) - mask;
            else
                y = double(x);
            end
        end
    end
end
