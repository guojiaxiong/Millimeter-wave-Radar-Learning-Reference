function plotTracks(tracks)
    hold on;
    for i = 1:numel(tracks)
        h = tracks{i}.history;
        plot(h(:, 1), h(:, 2), '-', 'LineWidth', 1.2);
        plot(h(end, 1), h(end, 2), 'o');
    end
end
