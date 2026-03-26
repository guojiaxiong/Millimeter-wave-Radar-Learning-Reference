function rangeProfile = reshape_ant(rangeFFT)
% 功能：将Tx×Rx×Frame×Chirp×Sample格式的rangeFFT重组为ant×Frame×Chirp×Sample格式
% 输入：rangeFFT - 原始数据，维度 Tx×Rx×Frame×Chirp×Sample（Tx=2, Rx=4）
% 输出：rangeProfile - 重组后数据，维度 ant×Frame×Chirp×Sample（ant=8）
    % 2. 定义8个天线通道的组合顺序（tx1-rx1 → tx1-rx4 → tx3-rx1 → tx3-rx4）
    ant1 = rangeFFT(1, 1, :, :, :);  % tx1-rx1
    ant2 = rangeFFT(1, 2, :, :, :);  % tx1-rx2
    ant3 = rangeFFT(1, 3, :, :, :);  % tx1-rx3
    ant4 = rangeFFT(1, 4, :, :, :);  % tx1-rx4
    ant5 = rangeFFT(2, 1, :, :, :);  % tx3-rx1
    ant6 = rangeFFT(2, 2, :, :, :);  % tx3-rx2
    ant7 = rangeFFT(2, 3, :, :, :);  % tx3-rx3
    ant8 = rangeFFT(2, 4, :, :, :);  % tx3-rx4
    % 3. 拼接为8个天线通道的维度（ant×Frame×Chirp×Sample）
    rangeProfile = squeeze(cat(1, ant1, ant2, ant3, ant4, ant5, ant6, ant7, ant8));
end