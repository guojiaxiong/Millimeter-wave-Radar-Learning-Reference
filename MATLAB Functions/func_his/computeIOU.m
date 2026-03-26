function iou = computeIOU(box1, box2)
    % box = [x, y, w, h], 左上角坐标
    x1 = max(box1(1), box2(1));
    y1 = max(box1(2), box2(2));
    x2 = min(box1(1)+box1(3), box2(1)+box2(3));
    y2 = min(box1(2)+box1(4), box2(2)+box2(4));

    interArea = max(0, x2 - x1) * max(0, y2 - y1);
    unionArea = box1(3)*box1(4) + box2(3)*box2(4) - interArea;
    iou = interArea / unionArea;
end
