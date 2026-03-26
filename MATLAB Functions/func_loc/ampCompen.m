function AACdata = ampCompen(inputData, rangeAxis, compenTargetDim)
% AMPCOMPEN 雷达数据幅度补偿函数（距离维度幅度衰减补偿）
% 用法:
%   AACdata = ampCompen(inputData, rangeAxis, compenTargetDim)
% 输入参数:
%   inputData       - 任意维度的雷达复数数据
%   rangeAxis       - 距离轴向量（长度需与补偿目标维度的长度一致）
%   compenTargetDim - 幅度补偿的目标维度（即距离维度，如Sample维度，必填）
% 输出参数:
%   AACdata         - 完成幅度补偿后的雷达数据，维度与输入完全一致

inputDataDims = size(inputData);
inputDimNum = length(inputDataDims);
compenDimLength = inputDataDims(compenTargetDim);

if compenTargetDim < 1 || compenTargetDim > inputDimNum
    error('补偿目标维度compenTargetDim=%d超出输入数据的维度范围[1,%d]', compenTargetDim, inputDimNum);
end

if length(rangeAxis) ~= compenDimLength
    error('距离轴rangeAxis长度(%d)与补偿维度长度(%d)不匹配', length(rangeAxis), compenDimLength);
end

compenWin = (rangeAxis).^2;
compenWin(compenWin<1) = 1;
winShape = ones(1, inputDimNum);
winShape(compenTargetDim) = compenDimLength;
compenWinND = reshape(compenWin, winShape);
AACdata = inputData .* compenWinND;

end