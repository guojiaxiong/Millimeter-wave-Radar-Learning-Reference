function [merged_reflect_structs, labels] = refCluster(RefDbscan, Room, reflect_structs)
% refCluster 基于DBSCAN聚类合并相似反射线段
% 输入：
%   RefDbscan   - 结构体，包含DBSCAN聚类参数：
%                .epsilon: 邻域半径（归一化空间）
%                .minPts: 最小聚类点数
%                .extend_ratio: 合并后线段长度扩展比例
%   Room        - 结构体，包含室内空间范围：
%                .x: 室内x轴范围 [xmin, xmax]
%                .y: 室内y轴范围 [ymin, ymax]
%   reflect_structs - 原始线段结构体数组，每个元素含.reflection_array（3×2数组）
% 输出：
%   merged_reflect_structs - 合并后的线段结构体数组
%   labels - DBSCAN聚类标签

eps_dbscan = RefDbscan.epsilon;
minPts_dbscan = RefDbscan.minPts;
extend_ratio = RefDbscan.extend_ratio;

room_x_range = Room.x;
room_y_range = Room.y;

n_segs = length(reflect_structs);
if n_segs == 0
    error('输入的reflect_structs为空！无可用线段进行聚类合并');
end

if length(room_x_range) ~= 2 || length(room_y_range) ~= 2
    error('Room结构体的x/y字段需为长度2的数组（[min, max]）');
end

feat_array = zeros(n_segs, 7);
for i = 1:n_segs
    seg = reflect_structs(i).reflection_array;
    start_pt = seg(1, :);
    mid_pt = seg(2, :);
    end_pt = seg(3, :);
    
    dx = end_pt(1) - start_pt(1);
    dy = end_pt(2) - start_pt(2);
    theta = atan2(dy, dx);
    
    feat_array(i, 1:2) = mid_pt;
    feat_array(i, 3) = theta;
    feat_array(i, 4:5) = start_pt;
    feat_array(i, 6:7) = end_pt;
end

mid_x_norm = (feat_array(:,1) - room_x_range(1)) / (room_x_range(2) - room_x_range(1));
mid_y_norm = (feat_array(:,2) - room_y_range(1)) / (room_y_range(2) - room_y_range(1));
theta_norm = (feat_array(:,3) + pi/3) / (2/3 * pi);
% range_norm = sqrt(mid_x_norm.^2 + mid_y_norm.^2) ./ sqrt(2);

norm_feats = [mid_x_norm, mid_y_norm, theta_norm];


labels = dbscan(norm_feats, eps_dbscan, minPts_dbscan);

n_outliers = sum(labels == -1);
unique_labels = unique(labels);
unique_labels(unique_labels == -1) = [];
n_clusters = length(unique_labels);

fprintf('DBSCAN聚类完成：有效聚类数=%d，离群线段数=%d\n', n_clusters, n_outliers);
if n_clusters == 0
    fprintf('无有效聚类，所有线段均为离群点！\n');
    merged_reflect_structs = [];
    return;
end

merged_reflect_structs = [];

for c = 1:n_clusters
    cluster_label = unique_labels(c);
    cluster_idx = find(labels == cluster_label);
    cluster_feats = feat_array(cluster_idx, :);
    n_original = length(cluster_idx);
    
    cluster_mid_x = mean(cluster_feats(:,1));
    cluster_mid_y = mean(cluster_feats(:,2));
    cluster_mid = [cluster_mid_x, cluster_mid_y];
    
    dx_sum = sum(cos(cluster_feats(:,3)));
    dy_sum = sum(sin(cluster_feats(:,3)));
    avg_theta = atan2(dy_sum, dx_sum);

    all_endpoints = [cluster_feats(:,4:5); cluster_feats(:,6:7)];

    dir_vec = [cos(avg_theta), sin(avg_theta)];

    pts_rel_center = all_endpoints - cluster_mid;
    proj_vals = pts_rel_center * dir_vec';

    proj_min = min(proj_vals);
    proj_max = max(proj_vals);

    proj_min_ext = proj_min * extend_ratio;
    proj_max_ext = proj_max * extend_ratio;

    start_pt_merged = cluster_mid + proj_min_ext * dir_vec;
    end_pt_merged = cluster_mid + proj_max_ext * dir_vec;
    mid_pt_merged = cluster_mid;

    merged_seg = [start_pt_merged; mid_pt_merged; end_pt_merged];

    merged_reflect_structs(c).reflection_array = merged_seg;
    merged_reflect_structs(c).cluster_label = cluster_label;
    merged_reflect_structs(c).n_original_segs = n_original;
end

fprintf('线段合并完成：原始%d条 → 合并后%d条\n', n_segs - n_outliers, length(merged_reflect_structs));

end