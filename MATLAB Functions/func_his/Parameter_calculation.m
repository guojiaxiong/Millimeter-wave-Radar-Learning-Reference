%%用于计算FMCW radar的相关参数
clc;clear;
c = 3e8;
k = 1.38*10e-23;
T = 290;

R_max = 8;
f_c = 24e9;     %工作频率
lambda = f_c/c; %工作波长
B_max = 1e9;    %最大扫频带宽
T_chirp = 5.5 * 2*R_max / c;  %单个chirp持续时间
S_max = B_max / T_chirp;
N_chirp = 64;   %每帧内chirp总数
Tf = T_chirp * N_chirp;     %一帧内chirp总时间

delta_R_max = c / (2*B_max);
delta_V_max = lambda / (2*N_chirp*T_chirp);
V_max = lambda / 4*T_chirp;
% Gt = 0;     %dbm
% Gr = 0;     %dbm
% Pt = 16;    %dbm
% RCS = 0.02*0.02;
% 

% 
% %单位标准化
% % Gt = 10*exp(Gt/10);
% Gr = 10*exp(Gr/10);
% Pt = 10*exp(Pt/10)/1000;
% 
% %赋值测试
% 
% delta_R = c/2*B;
% SNR_o = 10*log((Pt * Gt * RCS * Gr * lambda^2 * Tf)/((4*pi*R^2)^2 * 4*pi * k*T * NF));
% SNR_o = collect(simplify(SNR_o));
% 
