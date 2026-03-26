function mergedData = readDCA1000(fileName,numRx,numADCSamples,numChirpsPerFrame,numFrames)


if exist([fileName, '.mat'], 'file') == 2
    load([fileName, '.mat'], 'mergedData');
    fprintf('提示：MAT文件 %s 已存在，直接加载。\n', [fileName, '.mat']);
    return;
end
numADCBits = 16;
numLanes = 2;
isReal = 0;
fid = fopen([fileName, '.bin'],'r');
adcData = fread(fid, 'int16');
if numADCBits ~= 16
   l_max = 2^(numADCBits-1)-1;
   adcData(adcData > l_max) = adcData(adcData > l_max) - 2^numADCBits;
end
fclose(fid);
fileSize = size(adcData, 1);
if isReal
    numChirps = fileSize/numADCSamples/numRx;
    LVDS = zeros(1, fileSize);
    LVDS = reshape(adcData, numADCSamples*numRx, numChirps);
    LVDS = LVDS.';
else
    numChirps = fileSize/2/numADCSamples/numRx;
    LVDS = zeros(1, fileSize/2);
    counter = 1;
    for i=1:4:fileSize-1
        LVDS(1,counter) = adcData(i) + sqrt(-1)*adcData(i+2); LVDS(1,counter+1) = adcData(i+1)+sqrt(-1)*adcData(i+3); counter = counter + 2;
    end
    LVDS = reshape(LVDS, numADCSamples*numRx, numChirps);
    LVDS = LVDS.';
end
adcData = zeros(numRx,numChirps*numADCSamples);
for row = 1:numRx
    for i = 1: numChirps
        adcData(row, (i-1)*numADCSamples+1:i*numADCSamples) = LVDS(i, (row-1)*numADCSamples+1:row*numADCSamples);
    end
end
retVal = adcData;
data = zeros([numRx,numADCSamples,numChirpsPerFrame,numFrames]);
for i = 1:numRx
    data(i,:,:,:) = reshape(retVal(i,:), [numADCSamples,numChirpsPerFrame,numFrames]);
end
mergedData = permute(data,[4,1,3,2]);
save([fileName, '.mat'], 'mergedData');
fprintf('成功：mergedData已保存到MAT文件 %s\n', [fileName, '.mat']);
end