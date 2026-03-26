function [breathRate, heartRate, agl] = get_heartBreath_rate(filterd_rangProfile, param)
% GET_HEARTBREATH_RATE 雷达非接触生命体征检测：提取呼吸率/心率（集成CEEMDAN增强模块）
% 【核心功能】
%   从角度滤波后的目标距离剖面中，通过相位解缠绕、小波降噪、带通滤波/CEEMDAN分解、频谱分析，计算呼吸率/心率
%   支持2种相位解缠绕算法、2种带通滤波方法、2种频率提取方法（FFT/CEEMDAN），算法选择通过param.vital配置
%   所有结果统一为「次/分钟」单位，新增参考值对比可视化
% 
% 【输入参数】
%   target_rangeProfile : 二维矩阵（有效Chirp数×目标数），角度滤波后的目标距离剖面（每列对应1个目标）
%   param               : 嵌套结构体，来自param_config()函数，包含所有雷达/生命体征/CEEMDAN参数
% 
% 【输出参数】
%   breathRate          : 一维数组（1×目标数），各目标的呼吸率（单位：次/分钟）
%   heartRate           : 一维数组（1×目标数），各目标的心率（单位：次/分钟）
%   agl                 : 一维数组，去噪后的相位差分信号（最后一个目标的结果，多目标取最后一个）
% 
% 【算法配置】
%   所有算法选择/参数配置均在param_config()的param.vital中定义，无需修改本函数

    %% ====================== 从param提取核心参数（删除冗余）======================
    % 1. 雷达慢时间/帧参数（仅保留用到的）
    slowtime_fs = param.radar.FPS;               % 慢时间采样率（帧率，Hz）
    frames = param.radar.N_Frame;                % 总帧数/Chirp数
    
    % 2. 生命体征算法配置
    phase_unwrap_method = param.vital.phase_unwrap_method; % 相位解缠绕：'unwrap'/'dacm'
    filter_method = param.vital.filter_method;            % 带通滤波：'pre_defined_bpf'/'butterworth'
    freq_extract_method = param.vital.freq_extract_method;% 频率提取：'fft'/'ceemdan'
    wavelet_level = param.vital.wavelet_level;            % 小波降噪层数
    wavelet_name = param.vital.wavelet_name;              % 小波基函数
    breath_freq_range = param.vital.BR_range / 60;         % 呼吸频率范围（Hz）→ 内部转换用
    heart_freq_range = param.vital.HR_range / 60;          % 心跳频率范围（Hz）→ 内部转换用
    
    % 3. 参考值（次/分钟，用于对比）
    ref_breath_rate = param.vital.resp_rate;      % 参考呼吸率（次/分钟）
    ref_heart_rate = param.vital.heart_rate;      % 参考心率（次/分钟）
    
    % 4. CEEMDAN算法参数（仅保留用到的）
    ceemdan_Nstd = param.vital.ceemdan_Nstd;      % 高斯白噪声标准差
    ceemdan_NR = param.vital.ceemdan_NR;          % 实现次数
    ceemdan_MaxIter = param.vital.ceemdan_MaxIter;% 最大迭代次数
    ceemdan_SNRFlag = param.vital.ceemdan_SNRFlag;% 信噪比递增标志
    %% ==========================================================================

    % 定义RGB颜色数组（统一管理，便于修改）
    color_red = [1 0 0];           % 纯红（对应原'r'/'red'）
    color_green = [0 1 0];         % 纯绿（对应原'g'）
    color_darkgreen = [0 0.5 0];   % 深绿（对应原'darkgreen'）
    
    % 初始化输出变量
    target_num = size(filterd_rangProfile, 2);  % 目标数量
    breathRate = zeros(1, target_num);
    heartRate  = zeros(1, target_num);
    agl = [];  % 初始化去噪相位信号

    % 遍历每个目标处理
    for kk = 1:target_num
        % 提取当前目标复信号
        complex_signal = filterd_rangProfile(:, kk);
        N = length(complex_signal);  % 信号长度（有效Chirp数）
        Num_plot = 1; % CEEMDAN绘图编号初始化

        %% -------------------------- 步骤1：相位解缠绕（保留核心逻辑）--------------------------
        [diff_ag, dcRemove_ag, unwrap_dcRemove_ag] = phase_unwrap(complex_signal, slowtime_fs, phase_unwrap_method);

        %% -------------------------- 步骤2：小波降噪（删除冗余变量）--------------------------
        Sr = diff_ag;
        t_axis = linspace(0, frames / slowtime_fs, N-1);  % 时间轴（s）
        f_axis_hz = (0:N-1)*slowtime_fs/(N-1);  % 频率轴（Hz）
        f_axis_bpm = f_axis_hz * 60;  % 频率轴（次/分钟）→ 统一单位

        % 小波降噪核心逻辑（仅保留必要输出）
        [C, L] = wavedec(Sr, wavelet_level, wavelet_name);
        [thr, ~] = wdcbm(C, L, 1.001);
        [Sr_denoise, ~, ~, ~, ~] = wdencmp('lvd', C, L, wavelet_name, wavelet_level, thr, 's');
        agl = Sr_denoise - mean(Sr_denoise);  % 最终去噪相位信号

        %% -------------------------- 步骤3：频率提取（统一单位+参考值对比）--------------------------
        if strcmp(freq_extract_method, 'ceemdan')
            % ====================== CEEMDAN分解模块（统一单位+参考值对比）=====================
            Process_Sig = agl;
            % CEEMDAN分解（需确保ceemdan函数已定义）
            [modes,~] = ceemdan(Process_Sig, ceemdan_Nstd, ceemdan_NR, ceemdan_MaxIter, ceemdan_SNRFlag);

            % 绘制CEEMDAN分解时域图
            figure(NumberTitle="off",Name=sprintf("目标%d-CEEMDAN分解时域   Num：%d",kk,Num_plot));
            Num_plot = Num_plot+1;      
            [modes_r, modes_l] = size(modes);
            for i = 1:modes_r
                subplot(modes_r,1,i);plot(t_axis,modes(i,:));
                title(sprintf("modes %d时域",i)); grid on;
                xlabel("时间 (s)"); ylabel("幅度");
            end

            % 绘制CEEMDAN分解频域图（统一为次/分钟+添加参考值）
            figure(NumberTitle="off",Name=sprintf("目标%d-CEEMDAN分解频域（次/分钟）   Num：%d",kk,Num_plot));
            Num_plot = Num_plot+1;      
            Predict_Matrix_CEEMDAN_bpm = zeros(1,modes_r);  % 直接存储次/分钟
            CorrC_CEEMDAN = zeros(1,modes_r);  
            for i = 1:modes_r
                Process_Sig_fft =  fft(modes(i,:)); 
                subplot(modes_r,1,i);
                % 绘制频域图（次/分钟）
                plot(f_axis_bpm(1:N/2),abs(Process_Sig_fft(1:N/2))); grid on; hold on;
                % 添加参考值虚线（替换'r--'/'g--'为RGB+线型）
                y_max = max(abs(Process_Sig_fft(1:N/2)));
                plot([ref_breath_rate, ref_breath_rate], [0, y_max], 'LineStyle','--', 'Color',color_red, 'LineWidth',1.5, 'DisplayName','参考呼吸率');
                plot([ref_heart_rate, ref_heart_rate], [0, y_max], 'LineStyle','--', 'Color',color_green, 'LineWidth',1.5, 'DisplayName','参考心率');
                legend('show');
                title(sprintf("modes %d频域（次/分钟）",i));
                xlabel("频率 (次/分钟)"); ylabel("幅度");
                hold off;
                
                % 提取最大频率分量（直接转次/分钟）
                [max_fft, max_idx] = max(abs(Process_Sig_fft(1:N/2)));
                Predict_Matrix_CEEMDAN_bpm(i) = (max_idx-1) * slowtime_fs/(N-1) * 60;
                CorrC_CEEMDAN(i) = corr(modes(i,1:N/2)',Process_Sig(1:N/2),'type','Pearson');
            end

            % 筛选呼吸/心跳频率范围（次/分钟，无需转换）
            Predict_Breathe_CEEMDAN = Predict_Matrix_CEEMDAN_bpm(...
                Predict_Matrix_CEEMDAN_bpm>=param.vital.BR_range(1) & ...
                Predict_Matrix_CEEMDAN_bpm <= param.vital.BR_range(2));
            Predict_Breathe_CEEMDAN = unique(Predict_Breathe_CEEMDAN);    
            Predict_HeartBeat_CEEMDAN = Predict_Matrix_CEEMDAN_bpm(...
                Predict_Matrix_CEEMDAN_bpm>=param.vital.HR_range(1) & ...
                Predict_Matrix_CEEMDAN_bpm <= param.vital.HR_range(2));
            Predict_HeartBeat_CEEMDAN = unique(Predict_HeartBeat_CEEMDAN); 

            % 打印CEEMDAN结果（统一次/分钟+对比参考值）
            fprintf("\n===== 目标%d 生命体征检测结果（CEEMDAN）=====\n",kk);
            fprintf("参考呼吸率：%.1f次/分钟 | 参考心率：%.1f次/分钟\n", ref_breath_rate, ref_heart_rate);
            fprintf("检测到的可能心跳频率：");
            for i = 1:length(Predict_HeartBeat_CEEMDAN)
                fprintf("%.1f次/分钟 ",Predict_HeartBeat_CEEMDAN(i));
            end
            fprintf("\n检测到的可能呼吸频率：");
            for i = 1:length(Predict_Breathe_CEEMDAN)
                fprintf("%.1f次/分钟 ",Predict_Breathe_CEEMDAN(i));
            end
            fprintf("\n");

            % 互相关筛选呼吸频率
            Predict_Amend = Predict_Matrix_CEEMDAN_bpm(CorrC_CEEMDAN >= 0.6); 
            Predict_Amend = unique(Predict_Amend); 
            br=intersect(Predict_Breathe_CEEMDAN,Predict_Amend );
            fprintf("互相关筛选 - 呼吸频率：%.1f次/分钟（参考值：%.1f次/分钟）\n",br, ref_breath_rate);

            % 去除呼吸谐波提取心跳信号（频率转Hz计算）
            Predict_Amend_hz = Predict_Amend / 60; % 转Hz用于信号生成
            HeartbeatSig_CEEMDAN = Process_Sig - sum(2*sin(2*pi*2*t_axis'*Predict_Amend_hz),2);
            HeartbeatSig_CEEMDAN_fft = fft(HeartbeatSig_CEEMDAN);    

            % 绘制心跳信号结果（统一次/分钟+参考值）
            figure(NumberTitle="off",Name=sprintf("目标%d-去除呼吸谐波（CEEMDAN）   Num：%d",kk,Num_plot));
            Num_plot = Num_plot+1;
            subplot(2,1,1)  % 时域
            plot(t_axis,HeartbeatSig_CEEMDAN); grid on;
            xlabel("时间 (s)"); ylabel("幅度"); title("心跳信号时域");

            subplot(2,1,2)  % 频域（次/分钟+参考值）
            plot(f_axis_bpm(1:N/2),abs(HeartbeatSig_CEEMDAN_fft(1:N/2))); grid on; hold on;
            [max_heart_fft, max_heart_idx] = max(abs(HeartbeatSig_CEEMDAN_fft(1:N/2)));
            Heart_Pred_MED_bpm = (max_heart_idx-1)*slowtime_fs/(N-1)*60;% 心跳频率（次/分钟）
            % 标注检测值和参考值（替换'r'/'g--'为RGB）
            stem(Heart_Pred_MED_bpm,max_heart_fft,'Color',color_red, 'DisplayName','检测心率');
            plot([ref_heart_rate, ref_heart_rate], [0, max_heart_fft*1.1], 'LineStyle','--', 'Color',color_green, 'LineWidth',1.5, 'DisplayName','参考心率');
            legend('show');
            xlabel("频率 (次/分钟)"); ylabel("幅度"); title(sprintf("心跳信号频域（参考心率：%.1f次/分钟）", ref_heart_rate));
            hold off;

            % CEEMDAN结果赋值（次/分钟）
            if ~isempty(br)
                breathRate(kk) = ceil(br);
            else
                breathRate(kk) = 0; % 无有效呼吸频率时置0
            end
            if ~isempty(Heart_Pred_MED_bpm)
                heartRate(kk) = ceil(Heart_Pred_MED_bpm);
            else
                heartRate(kk) = 0; % 无有效心跳频率时置0
            end
            fprintf("最终检测结果 - 呼吸率：%.1f次/分钟 | 心率：%.1f次/分钟\n", breathRate(kk), heartRate(kk));

        else  % 原有FFT+带通滤波逻辑（统一单位+参考值对比）
            %% -------------------------- 步骤3：带通滤波（保留核心逻辑）--------------------------


            switch filter_method
                case 'pre_defined_bpf'
                    breath_wave = filter(RR_BPF20, agl);
                    heart_wave  = filter(HR_BPF20, agl);

                case 'butterworth'
                    breath_norm_freq = breath_freq_range / slowtime_fs;
                    heart_norm_freq  = heart_freq_range / slowtime_fs;
                    [b_breath, a_breath] = butter(5, breath_norm_freq);
                    [b_heart, a_heart] = butter(9, heart_norm_freq);
                    breath_wave = filter(b_breath, a_breath, agl);
                    heart_wave  = filter(b_heart, a_heart, agl);

                otherwise
                    error('带通滤波方法选择错误！仅支持''pre_defined_bpf''或''butterworth''');
            end

            %% -------------------------- 步骤4：频谱分析（统一单位+参考值对比）--------------------------
            % 呼吸率计算（次/分钟）
            breath_fft = abs(fftshift(fft(breath_wave)));
            breath_fft = breath_fft(ceil(end/2):end);
            [~, breath_idx] = max(breath_fft);
            breath_hz = breath_idx * (slowtime_fs / 2 / length(breath_fft));
            breathRate(kk) = ceil(breath_hz * 60); % 转次/分钟

            % 心率计算（次/分钟）
            heart_fft = abs(fftshift(fft(heart_wave)));
            heart_fft = heart_fft(ceil(end/2):end);
            [~, heart_idx] = max(heart_fft);
            heart_hz = heart_idx * (slowtime_fs / 2 / length(heart_fft));
            heartRate(kk) = ceil(heart_hz * 60); % 转次/分钟

            %% -------------------------- 步骤5：可视化（统一单位+参考值对比）--------------------------
            freq_axis_bpm = linspace(0, slowtime_fs/2, length(breath_fft)) * 60; % 次/分钟
            figure('Name', sprintf('目标%d 呼吸/心率分析（次/分钟） (FPS=%dHz)', kk, param.radar.FPS));
            
            % 呼吸波形+频谱（添加参考值，替换'r--'/'r'/'red'为RGB）
            subplot(221); plot(t_axis, breath_wave, 'LineWidth', 1);
            xlabel('时间 (s)'); ylabel('幅值'); title('呼吸波形'); grid on;
            subplot(223); plot(freq_axis_bpm, breath_fft, 'LineWidth', 1); hold on;
            % 标注检测值和参考值
            plot([ref_breath_rate, ref_breath_rate], [0, max(breath_fft)], 'LineStyle','--', 'Color',color_red, 'LineWidth',1.5, 'DisplayName','参考呼吸率');
            stem(breathRate(kk), max(breath_fft), 'Color',color_red, 'DisplayName','检测呼吸率');
            legend('show');
            xlabel('频率 (次/分钟)'); ylabel('幅值'); title(sprintf('呼吸频谱（参考值：%.1f次/分钟）', ref_breath_rate)); grid on;
            text(ref_breath_rate+5, max(breath_fft)*0.8, ['参考：', num2str(ref_breath_rate)], 'Color',color_red);
            text(breathRate(kk)+5, max(breath_fft)*0.7, ['检测：', num2str(breathRate(kk))], 'Color',color_red);
            hold off;

            % 心跳波形+频谱（添加参考值，替换'g--'/'g'/'darkgreen'为RGB）
            subplot(222); plot(t_axis, heart_wave, 'LineWidth', 1);
            xlabel('时间 (s)'); ylabel('幅值'); title('心跳波形'); grid on;
            subplot(224); plot(freq_axis_bpm, heart_fft, 'LineWidth', 1); hold on;
            % 标注检测值和参考值
            plot([ref_heart_rate, ref_heart_rate], [0, max(heart_fft)], 'LineStyle','--', 'Color',color_green, 'LineWidth',1.5, 'DisplayName','参考心率');
            stem(heartRate(kk), max(heart_fft), 'Color',color_green, 'DisplayName','检测心率');
            legend('show');
            xlabel('频率 (次/分钟)'); ylabel('幅值'); title(sprintf('心跳频谱（参考值：%.1f次/分钟）', ref_heart_rate)); grid on;
            text(ref_heart_rate+5, max(heart_fft)*0.8, ['参考：', num2str(ref_heart_rate)], 'Color',color_green);
            text(heartRate(kk)+5, max(heart_fft)*0.7, ['检测：', num2str(heartRate(kk))], 'Color',color_darkgreen);
            hold off;

            % 打印FFT结果（对比参考值）
            fprintf("\n===== 目标%d 生命体征检测结果（FFT）=====\n",kk);
            fprintf("参考呼吸率：%.1f次/分钟 | 检测呼吸率：%.1f次/分钟\n", ref_breath_rate, breathRate(kk));
            fprintf("参考心率：%.1f次/分钟 | 检测心率：%.1f次/分钟\n", ref_heart_rate, heartRate(kk));
        end

        % 相位处理过程可视化（保留+统一标签）
        figure('Name', sprintf('目标%d 相位处理过程 (总帧数=%d)', kk, param.radar.N_Frame));
        subplot(311); plot(t_axis, dcRemove_ag(1:end-1));
        xlabel('时间 (s)'); ylabel('相位 (rad)'); title('原始相位'); grid on;
        subplot(312); plot(t_axis, unwrap_dcRemove_ag(1:end-1));
        xlabel('时间 (s)'); ylabel('相位 (rad)'); title('解缠绕后相位'); grid on;
        subplot(313); plot(t_axis, diff_ag);
        xlabel('时间 (s)'); ylabel('幅值'); title('差分后相位'); grid on;
    end

end