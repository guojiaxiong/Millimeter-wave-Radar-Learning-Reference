function [breathRate, heartRate,diff_ag] = get_heartBreath_rate(target_rangeProfile, slowtime_fs)

% Calculate the number of targets
target_num = length(target_rangeProfile(1,:));
breathRate = zeros(1,target_num);
heartRate  = zeros(1,target_num);
% useFramesNum = 150;
% diff_ag=zeros(useFramesNum,2);
for kk = 1:target_num
 %% Extract the respiration and heartbeat waveform from the range profile for the existing targets
    target_profile = target_rangeProfile(:,kk);%依次计算目标相位
    dcRemove_ag = angle(target_profile); % Calculate phase
    unwrap_dcRemove_ag(:,kk) = unwrap(dcRemove_ag); % Phase unwrapping
    diff_ag(:,kk) = unwrap_dcRemove_ag(1:end-1,kk) - unwrap_dcRemove_ag(2:end,kk); % 相位差分，增强心跳信号1200*1的数据矩阵
    agl = diff_ag(:,kk);

    %% Use a band-pass filter to filter out other frequency components and extract the respiration and heartbeat signals
    agl = agl - mean(agl);
    %--------------------------------- Filter to obtain the respiration waveform and count
    breath_wave = filter(RR_BPF20, agl); % Respiration component
%     [b,a]=butter(5,[0.01,0.05]); % Design a 5th-order Butterworth filter, sampling frequency is 20Hz, respiration frequency range is 0.1-0.5Hz
%     breath_wave = filter(b,a,agl); % Respiration component
    % Calculate the count
    breath_fft = abs(fftshift(fft(breath_wave)));
    breath_fft = breath_fft(ceil(end/2):end); % 取正半部分频谱
    % Calculate the frequency corresponding to respiration
    [~, breath_index] = max(breath_fft);
    breath_hz = breath_index * (slowtime_fs / 2 / length(breath_fft));
    breathRate(kk) = ceil(breath_hz * 60);

    %--------------------------------- Filter to obtain the heartbeat waveform and count
    heart_wave = filter(HR_BPF20, agl); % Heartbeat component
%     [b,a]=butter(9,[0.08,0.2]); % Design a 9th-order Butterworth filter, sampling frequency is 20Hz, heartbeat frequency range is 0.8-2Hz
%     heart_wave = filter(b,a,agl); % Heartbeat component
    % Calculate the count
    heart_fft = abs(fftshift(fft(heart_wave)));
    heart_fft = heart_fft(ceil(end/2):end); % Since it is a double-sided spectrum, take only half
    % Calculate the frequency corresponding to heartbeat
    [~, heart_index] = max(heart_fft);
    heart_hz = heart_index * (slowtime_fs / 2 / length(heart_fft));
    heartRate(kk) = ceil(heart_hz * 1.2 * 60);

    %--------------------------------- Display
    xAxis = linspace(0,slowtime_fs/2,length(breath_fft)) * 60;
    t_axis = linspace(0,1/slowtime_fs * length(target_profile),length(target_profile)-1 );
    [~,bb]=max(breath_fft);
    [~,hh]=max(heart_fft);
    % figure(3);
    % subplot(311); plot([t_axis,60],dcRemove_ag); xlabel('Time (s)'); ylabel('Magnitude'); title('Unwrapped Waveform'); grid on
    % subplot(312); plot([t_axis,60],unwrap_dcRemove_ag(:,kk),'linewidth',1.2);
    % xlabel('Time (s)'); ylabel('Magnitude'); title('Unwrapped Waveform');
    % xlabel('\fontsize{12} Time\fontname{Times New Roman}\fontsize{8} (s)')
    % ylabel('\fontsize{12} Phase\fontname{Times New Roman}\fontsize{8} (rads)'); grid on
    % subplot(313); plot(t_axis,diff_ag(:,kk)); xlabel('Time (s)'); ylabel('Magnitude'); title('Post-Difference Waveform'); grid on
    % 
    % figure(3);
    % subplot(221); plot(t_axis,breath_wave); title('Respiration Waveform'); xlabel('Time (s)'); ylabel('Magnitude'); grid on
    % subplot(223); plot(xAxis,breath_fft); title('Respiration Spectrum'); xlabel('Frequency (times/min)'); ylabel('Magnitude'); 
    % text(200,30,['呼吸率为：',num2str(bb)]);grid on
    % subplot(222); plot(t_axis,heart_wave); title('Heartbeat Waveform'); xlabel('Time (s)'); ylabel('Magnitude'); grid on
    % subplot(224); plot(xAxis,heart_fft); title('Heartbeat Spectrum'); xlabel('Frequency (times/min)'); ylabel('Magnitude');
    % text(200,30,['心率为：',num2str(hh)]);grid on

end