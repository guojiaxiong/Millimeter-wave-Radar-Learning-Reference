function [azimuSpectrogram_norm, angleAxis, Rxv] = IWR6843ISK_DOA(rangeProfile, param)
% IWR6843ISK_DOA 基于IWR6843ISK雷达数据实现DOA估计（CBF/MVDR）
% 输入：
%   rangeProfile - 单帧去杂波后的距离像，维度[Chirp数, 距离门数, 天线通道数(8)]
%   param        - 配置结构体，包含DOA相关参数：
%                  param.doa.doaFlag: DOA算法选择（0=FFT 1=CBF 2=MVDR）
%                  param.doa.useChirpNum: 用于DOA的Chirp数量
%                  param.doa.searchAngleRange: 角度搜索范围（±N°，单位：度）
%                  param.doa.c: Chirp偏移量（用于截取有效Chirp段）
% 输出：
%   azimuSpectrogram_norm - 归一化后的方位角谱（维度[角度数, 距离门数]）
%   angleAxis             - 角度轴向量（±searchAngleRange°，1°步长）

% 算法模式定义
CBF_DOA_MODE   = 1;   % 常规波束形成
MVDR_DOA_MODE  = 2;   % 最小方差无失真响应

% 提取DOA参数（从结构体中解耦，增强可读性）
doaFlag = param.doa.doaFlag;
useChirpNum = param.radar.N_Chirp;
searchAngleRange = param.doa.searchAngleRange;
c = param.doa.c;

% 基础参数计算
rangNum = size(rangeProfile,2);        % 距离门数量
lambda = param.radar.lambda;                         % 雷达波长（5mm）
d = lambda / 2;                        % 天线阵元间距（半波长）
SEARCH_ANGLE_RANGE = searchAngleRange/180*pi;  % 角度范围转弧度
SEARCH_ANGLE_SPACE = 1/180*pi;         % 角度步长（1°转弧度）

% 生成角度相位因子（fai = 2πd sinθ/λ）
fai = 2 * pi * sin(-SEARCH_ANGLE_RANGE:SEARCH_ANGLE_SPACE:SEARCH_ANGLE_RANGE) * d / lambda;
angleAxis = -searchAngleRange:1:searchAngleRange;  % 角度轴（与fai一一对应）

% 初始化方位角谱矩阵
azimuSpectrogram = zeros(length(fai), rangNum);

% DOA估计主逻辑（仅处理CBF/MVDR模式）
if (doaFlag == CBF_DOA_MODE) || (doaFlag == MVDR_DOA_MODE)
    % 遍历每个距离门
    for r = 1:rangNum
        % 截取有效Chirp段并重构天线数据矩阵
        xt = squeeze(rangeProfile(1:useChirpNum-c, r, :))';  % 维度[天线数, Chirp数]
        Rx = xt * xt';  % 计算协方差矩阵（天线数×天线数）
        
        % 遍历每个搜索角度
        for an = 1:length(fai)
            % 生成8阵元导向矢量
            aTheta = [1,exp(-j*1*fai(an)),exp(-j*2*fai(an)),exp(-j*3*fai(an)),...
                      exp(-j*4*fai(an)),exp(-j*5*fai(an)),exp(-j*6*fai(an)),exp(-j*7*fai(an))];
            
            if doaFlag == CBF_DOA_MODE
                % CBF算法：波束功率计算
                azimuSpectrogram(an,r) = abs(aTheta * Rx * aTheta'); 
            else
                % MVDR算法：最小方差功率计算（伪逆求解）
                Rxv = pinv(Rx);  
                azimuSpectrogram(an,r) = 1 / abs(aTheta * Rxv * aTheta');
            end
        end
    end
end

% 归一化处理（全局最大值归一化，避免维度错误）
azimuSpectrogram_norm = azimuSpectrogram / max(azimuSpectrogram(:));

end