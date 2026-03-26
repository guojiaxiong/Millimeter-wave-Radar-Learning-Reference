function observations = PositionModel(rangeIdx, velIdx, angle, axis_info)
% POSITIONMODEL 基于雷达检测结果计算目标位置与速度观测值
% 用法:
%   observations = PositionModel(rangeIdx, velIdx, angle, axis_info)
% 输入参数:
%   rangeIdx   - 距离索引标量（单帧单个目标）
%   velIdx     - 速度索引标量（单帧单个目标）
%   angle      - 目标角度标量（单位：度，单帧单个目标）
%   axis_info  - 坐标轴信息结构体，包含 axis_info.range（距离轴）、axis_info.velocity（速度轴）
% 输出参数:
%   observations - [1 × 6] 行向量，对应 [x, y, vx, vy, range, theta]
%                  x/y: 目标位置坐标; vx/vy: 目标速度分量; range: 目标距离; theta: 目标角度（弧度）

range = axis_info.range(rangeIdx);
velocity = axis_info.velocity(velIdx);
theta = deg2rad(angle) + pi/2;
y = range * sin(theta);
x = -range * cos(theta);
vx = velocity * cos(theta);
vy = velocity * sin(theta);
observations = [x, y, vx, vy, range, theta];
end