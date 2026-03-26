% ================================================================
%  RadarFrameReader.m
%  面向对象的雷达帧解析器 —— 解决 filePosition 溢出与性能问题
%
%  用  法:
%     rdr = RadarFrameReader('myRadar.dat',32);   % 每帧 32 个 chirp
%     while true
%         [rx0,rx1,chirpIdx,hasMore] = rdr.readFrame();
%         if isempty(rx0);   break;   end        % 文件读完
%         % -------- 在这里处理这一帧的数据 -----------------
%         % rx0、rx1 均为 1×chirpsPerFrame 的 cell，每个元素是复数列向量
%         if ~hasMore; break; end
%     end
%     rdr.close();                               % 释放文件句柄
% ================================================================
classdef RadarFrameReader < handle
    properties (Access = private)
        fid              % 文件句柄
        fileSize  uint64 % 文件大小 (字节)
        chirpsPerFrame   % 每帧 chirp 数
        buf   uint8      % 缓冲区 (未解析数据)
        filePos  uint64  % 已经读取到的绝对文件偏移
        chirpMap         % containers.Map , 暂存未成对的 RX0/RX1
    end
    
    methods
        %------------------- 构造函数 -----------------------------
        function obj = RadarFrameReader(filename,chirpsPerFrame)
            if nargin<2,  chirpsPerFrame = 32;  end
            obj.fid = fopen(filename,'rb');
            if obj.fid==-1
                error("无法打开文件: %s",filename);
            end
            fseek(obj.fid,0,'eof');
            obj.fileSize = uint64(ftell(obj.fid));
            fseek(obj.fid,0,'bof');
            
            obj.chirpsPerFrame = chirpsPerFrame;
            obj.buf      = uint8([]);
            obj.filePos  = uint64(0);
            obj.chirpMap = containers.Map('KeyType','char','ValueType','any');
            
            fprintf("文件: %s  已打开 (%.3f GB)\n",filename,double(obj.fileSize)/2^30);
        end
        
        %---------------------- 关闭文件 --------------------------
        function close(obj)
            if obj.fid>0
                fclose(obj.fid);
                obj.fid = -1;
            end
        end
        
        %---------------------- 读取一帧 --------------------------
        function [rx0All,rx1All,chirpArr,hasMore] = readFrame(obj)
            % 初始化返回
            rx0All   = cell(1,obj.chirpsPerFrame);
            rx1All   = cell(1,obj.chirpsPerFrame);
            chirpArr = nan(1,obj.chirpsPerFrame);
            found    = false(1,obj.chirpsPerFrame);
            targetIdx= 0:2:2*obj.chirpsPerFrame-2;     % 期望序号
            
            while true
                [rx0,rx1,cc] = obj.nextChirpPair();    % 取下一对
                if isempty(rx0)            % 文件已耗尽
                    rx0All = {};  rx1All = {};  chirpArr = [];
                    hasMore = false;
                    return;
                end
                
                idx = find(targetIdx==cc,1);
                if isempty(idx) || found(idx)   % 不是本帧需要的 / 已有
                    continue;
                end
                rx0All{idx}   = rx0;
                rx1All{idx}   = rx1;
                chirpArr(idx) = cc;
                found(idx)    = true;
                
                if all(found)
                    hasMore = obj.filePos < obj.fileSize;
                    return;
                end
            end
        end
    end
    
    % ================== 私有工具函数 =============================
    methods (Access = private)
        
        % -------- 从缓冲 / 文件里拿到下一对 RX0+RX1 --------------
        function [rx0,rx1,chirpCnt] = nextChirpPair(obj)
            rx0=[]; rx1=[]; chirpCnt=nan;
            
            while true
                % -> 缓冲区至少保留 12 字节用于头检测
                while numel(obj.buf) < 12 && obj.filePos < obj.fileSize
                    obj.readMore();
                end
                if numel(obj.buf) < 12
                    return;                 % 文件结束
                end
                
                % ---- 搜索包头 0x49 43 4C 48 ----------------------
                hdrIdx = find(obj.buf(1:end-11)==hex2dec('49') & ...
                               obj.buf(2:end-10)==hex2dec('43') & ...
                               obj.buf(3:end-9) ==hex2dec('4C') & ...
                               obj.buf(4:end-8) ==hex2dec('48'),1);
                if isempty(hdrIdx)
                    obj.discard(numel(obj.buf)-11);
                    continue;
                end
                
                % ---- 读取长度字段 --------------------------------
                if hdrIdx+5 > numel(obj.buf)
                    obj.readMore();  continue;
                end
                dataLen = typecast(obj.buf(hdrIdx+4:hdrIdx+5),'uint16');
                pktSize = uint64(8) + uint64(dataLen) + 4; % 8B头+数据+4B尾
                
                while numel(obj.buf) < hdrIdx-1+double(pktSize)
                    if obj.filePos >= obj.fileSize, return; end
                    obj.readMore();
                end
                
                packet = obj.buf(hdrIdx:hdrIdx+double(pktSize)-1);
                obj.discard(hdrIdx-1+double(pktSize));
                
                % 只处理 Type==0x00 的数据包
                if packet(7) ~= 0
                    continue;
                end
                
                packetPayload = packet(9:end-4); % 去掉头尾
                [hasRaw,isRx1,cc] = obj.checkRawDataType(packetPayload);
                if ~hasRaw, continue; end
                
                key = sprintf('c%d',cc);
                if ~isKey(obj.chirpMap,key)
                    obj.chirpMap(key)=struct('rx0',[],'rx1',[]);
                end
                entry = obj.chirpMap(key);
                if isRx1
                    entry.rx1 = packetPayload;
                else
                    entry.rx0 = packetPayload;
                end
                obj.chirpMap(key) = entry;
                
                % 若已成对
                if ~isempty(entry.rx0) && ~isempty(entry.rx1)
                    rx0 = obj.extractComplexDataFromFrame(entry.rx0);
                    rx1 = obj.extractComplexDataFromFrame(entry.rx1);
                    chirpCnt = cc;
                    remove(obj.chirpMap,key);
                    return;
                end
            end
        end
        
        % ---------------- 读更多字节到缓冲区 ----------------------
        function readMore(obj)
            chunk = 1024*1024;                           % 1 MB/次
            remain = min(uint64(chunk),obj.fileSize-obj.filePos);
            if remain==0, return; end
            data = fread(obj.fid,double(remain),'uint8=>uint8');
            obj.buf     = [obj.buf; data];
            obj.filePos = obj.filePos + remain;
        end
        
        % ---------------- 丢掉缓冲区前 n 字节 --------------------
        function discard(obj,n)
            if n<=0, return; end
            obj.buf = obj.buf(n+1:end);
        end
        
        % ================== 数据解析辅助 ========================
        function [hasRaw,isRx1,chirpCnt] = checkRawDataType(~,frameData)
            hasRaw   = false;   isRx1 = false;   chirpCnt = NaN;
            p = 1;
            while p <= numel(frameData)-3
                if frameData(p)==hex2dec('AA')
                    hdr = typecast(uint8(frameData(p+3:-1:p)),'uint32');
                    if bitand(bitshift(hdr,-24),255)==hex2dec('AA')
                        isRx1    = bitget(hdr,24)==1;
                        chirpCnt = bitand(bitshift(hdr,-11),511); % 9 位
                        hasRaw   = true;
                        return;
                    end
                end
                p = p+1;
            end
        end
        
        function cplx = extractComplexDataFromFrame(obj,frameData)
            % 先找到 DS RAW 头
            p = 1;
            while p <= numel(frameData)-3
                if frameData(p)==hex2dec('AA')
                    hdr = typecast(uint8(frameData(p+3:-1:p)),'uint32');
                    if bitand(bitshift(hdr,-24),255)==hex2dec('AA')
                        N = int64(bitand(hdr,2047));      % 11 位
                        if N==0, N=256; else, N=N-1; end
                        cplx = obj.extractComplexData(frameData,p+4,N);
                        return;
                    end
                end
                p = p+1;
            end
            cplx = [];
        end
        
        function cplx = extractComplexData(~,data,startPos,N)
            realPart = zeros(N,1);
            imagPart = zeros(N,1);
            pos = startPos;
            for k = 1:N
                if pos+3 > numel(data), break; end
                w0 = typecast(uint8(data(pos+1:-1:pos)),'uint16');
                w1 = typecast(uint8(data(pos+3:-1:pos+2)),'uint16');
                realPart(k) = RadarFrameReader.twosComplement(w0,16);
                imagPart(k) = RadarFrameReader.twosComplement(w1,16);
                pos = pos + 4;
            end
            cplx = complex(double(realPart),double(imagPart));
        end
    end
    
    % ================== 静态工具 ===============================
    methods (Static, Access = private)
        function y = twosComplement(x,nbits)
            mask = 2^nbits;
            if bitget(x,nbits)==1
                y = double(x) - mask;
            else
                y = double(x);
            end
        end
    end
end