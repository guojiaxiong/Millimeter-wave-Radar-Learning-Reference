function Cancel_PulseCompre_Data = MTI(fftData, cancelFlag)

%% Perform clutter cancellation and pulse compression on the data
% MTI
%     编号    MTI方法
%     ____    ___________
%      1      均值
%      2      双脉冲
%      3      三脉冲
meanCancel_mode = 1;
twopCancel_mode = 2;
thrpCancel_mode = 3;
%--------------------------------Mean Cancellation
if(cancelFlag == meanCancel_mode)
    Cancel_PulseCompre_Data = fftData - mean(fftData,2); % Mean cancellation to remove DC component
    disp('Mean Cancellation done.');
end
%--------------------------------Two-Pulse Cancellation
if(cancelFlag == twopCancel_mode)
    Cancel_PulseCompre_Data = fftData(:, 2:end, :, :) - fftData(:, 1:end-1, :, :);
    Cancel_PulseCompre_Data(:, end+1,:,:) = fftData(:, end,:,:);
    disp('Two-Pulse Cancellation done.');
end
%--------------------------------Three-Pulse Cancellation
if(cancelFlag == thrpCancel_mode)
    Cancel_PulseCompre_Data = fftData(:, 1:end-2,:,:) - 2 * fftData(:, 2:end-1,:,:) + fftData(:, 3:end,:,:);
    Cancel_PulseCompre_Data(:, end+1,:,:) = fftData(:, end-1,:,:);
    Cancel_PulseCompre_Data(:, end+1,:,:) = fftData(:, end,:,:);
    disp('Three-Pulse Cancellation done.');
end