function observations_filterd = mutlpathfilt(observations, p)
observations_filterd = [];
if isempty(observations)
    return;
end
xy = observations(:, 2:3);
removeIdx = xy(:, 1) < p.x(1) | xy(:, 1) > p.x(2) | xy(:, 2) < p.y(1) | xy(:, 2) > p.y(2);
observations(removeIdx, :) = [];
if isempty(observations)
    return;
end
theta = observations(:, 7);
minPts = 1;             % 至少一个点成一类
groups = dbscan(theta, p.de, minPts);
removeIdx = false([length(theta) 1]);
% 提取每个聚类的中心值
labels = unique(groups(groups > 0));
% groupLabels = zeros(length(labels), 1);
% for i = 1:length(labels)
%     groupLabels(i) = mean(theta(groups == labels(i)));
% end
for i = 1:length(labels)
    vct = groups == i;
    target = [find(vct==1) observations(vct, [2 3 6])];
    if size(target, 1) == 1;continue;end
    [~, ref] = min(target(:, 4));
    x = target(ref, 2);
    y = target(ref, 3);
    r = target(ref, 4);
    if x > 0
        xm = p.x(2);
        t = y / (2 - x / xm);
        Rx = (sqrt(xm^2 + t^2) + sqrt((xm - x)^2 + (y - t)^2) + r) / 2;
    else
        xm = p.x(1);
        t = y / (2 - x / xm);
        Rx = (sqrt(xm^2 + t^2) + sqrt((xm - x)^2 + (y - t)^2) + r) / 2;
    end
    ym = p.y(2);
    t = x / (2 - y / ym);
    Ry = (sqrt(ym^2 + t^2) + sqrt((ym - y)^2 + (x - t)^2) + r) / 2;
    removeIdx(target(abs(target(:, 4) - Rx) < p.dr, 1)) =  1;
    removeIdx(target(abs(target(:, 4) - Ry) < p.dr, 1)) =  1;
end
observations(removeIdx, :) = [];
observations_filterd = observations;
end