clc;
clear;
% 读取 Excel 文件数据，这里假设文件名为 'data.xlsx'，如果不是请修改
[numData, txtData, rawData] = xlsread('data.xlsx');

% 确定 HR 和 BR 所在列索引
hrCol = 3; 
brCol = 13;

% 提取时间、HR、BR 数据，时间在 C 列（索引 3）
timeData = numData(:, 3);
hrData = numData(:, hrCol);
brData = numData(:, brCol);

% 找到 BR 开始大于 10bpm 的起始索引
startIdx = find(brData > 10, 1, 'first');
if isempty(startIdx)
    disp('未找到BR大于10bpm的数据');
    return;
end

% 数据总长度
totalLen = length(timeData);
% 单次记录时长（秒）
recordLen = 30; 
% 滑窗步长（秒）
stepLen = 1; 

% 计算可以保存的文件数量
fileNum = totalLen - startIdx - recordLen + 1;
if fileNum <= 0
    disp('没有足够的数据进行记录');
    return;
end

for i = 1:fileNum
    % 确定当前记录的起始和结束索引
    currentStartIdx = startIdx + (i - 1) * stepLen;
    currentEndIdx = currentStartIdx + recordLen - 1;
    
    % 截取对应的数据
    currentTime = timeData(currentStartIdx:currentEndIdx);
    currentHr = hrData(currentStartIdx:currentEndIdx);
    currentBr = brData(currentStartIdx:currentEndIdx);
    
    % 构建要保存的数据矩阵
    saveData = [currentTime, currentHr, currentBr];
    
    % 构建文件名
    fileName = sprintf('record_%d.csv', i);
    
    % 保存为CSV文件，第一行是表头
    csvwrite(fileName, saveData, 1, 0);
    % 添加表头
    fileID = fopen(fileName, 'r+');
    fseek(fileID, 0, 'bof');
    fprintf(fileID, 'Time,HR,BR\n');
    fclose(fileID);
end

disp('数据摘取和保存完成');