function truth = truthdata(p)
Rooftop = 1;
Corridor = 2;
Room = 3;
% 创建真值表
if p.testscene == Rooftop
    truthdata1pS = [zeros([200, 1]), linspace(1, 8, 200)', ones([200, 1])];
    truthdata2pS = [-2 * ones([200, 1]), linspace(1, 8, 200)', 2 * ones([200, 1]);
                               2 * ones([200, 1]), linspace(1, 8, 200)', 2 * ones([200, 1])];
    truthdata3pS = [zeros([200, 1]), linspace(1, 8, 200)', 3 * ones([200, 1]); 
                              -2 * ones([200, 1]), linspace(1, 8, 200)' , 3 * ones([200, 1]);
                              2 * ones([200, 1]), linspace(1, 8, 200)', 3 * ones([200, 1])];
    truth{1} = truthdata1pS;
    truth{2} = truthdata2pS;
    truth{3} = truthdata3pS;
    % elseif p.testscene == Corridor
elseif p.testscene == Room
    truthdata1pS = [2 * ones([200, 1]), linspace(2, 4, 200)', ones([200, 1]);
        linspace(2, -2, 200)', 4 * ones([200, 1]), ones([200, 1]);
        -2 * ones([200, 1]), linspace(4, 2, 200)', ones([200, 1])];
    truth{1} = truthdata1pS;
    % else
    % plot(truthdata1pS(:, 1), truthdata1pS(:, 2), 'o');
end