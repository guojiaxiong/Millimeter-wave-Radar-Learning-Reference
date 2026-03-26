%% 帧率更新函数
function frameTimeBuffer = updateFrameRate(frameStartTime, frameTimeBuffer, bufferSize, hFrameRateText)
% 计算当前帧处理时间
currentFrameTime = toc(frameStartTime);

% 更新帧时间缓冲区
frameTimeBuffer = [frameTimeBuffer, currentFrameTime];
if length(frameTimeBuffer) > bufferSize
    frameTimeBuffer = frameTimeBuffer(end-bufferSize+1:end);
end

% 计算平均帧率
avgFrameTime = mean(frameTimeBuffer);
currentFPS = 1 / avgFrameTime;
instantFPS = 1 / currentFrameTime;

% 更新帧率显示
frameRateText = sprintf('FPS: %.1f (平均: %.1f)\n处理时间: %.1f ms', ...
    instantFPS, currentFPS, currentFrameTime * 1000);
set(hFrameRateText, 'String', frameRateText);
end