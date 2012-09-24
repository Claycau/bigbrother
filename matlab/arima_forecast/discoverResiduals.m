%%%%
%Discover a set of residuals for all days of the week.  Residuals are
%extracted and then clustered.
%%%%
clear all
load './data/countData.mat'

data = sensors(1).data;
days = sensors(1).days;

ar = 1;
diff = 0;
ma = 1;
sar = 0;
sdiff = 24;
sma = 1;

allWindows = [];
allDayNums = [];

for weekDay = 1:7
    fprintf(1, 'Day of the week: %i\n', weekDay);
    
    dayIndex = find(days == weekDay);
    dayData = data(dayIndex, :);
    dayNums = sensors(1).dayNums;
    dayNums = dayNums(dayIndex);

    %Reshaping isn't working how I expected.  Do a stupid for loop for now.
    d2 = [];
    for i = 1:size(dayData,1)
        d2 = [d2 dayData(i, :)]; %#ok<AGROW>
    end
    dayData = d2';

    arimaModel = arima('ARLags', 1:ar, 'D', diff, 'MALags', 1:ma, ...
                'SARLags', 1:sar, 'Seasonality', sdiff, 'SMALags', 1:sma);

    model = estimate(arimaModel, dayData, 'print', false);
    res = infer(model, dayData);
    fitdist(res, 'normal')

    %For now slide by days
    removeThreshold = 0.1*(24*(model.Variance^0.5));
    [ind, window, val] = simpleExtraction(res, 24, removeThreshold);
    foo = round(ind/24);
    foo = foo(2:end);
    dates = datestr(dayNums(foo));
    
    allWindows = [allWindows; window];
    allDayNums = [allDayNums; dayNums(foo)];
end

for i = 2:30
    total = 0;
    for j = 1:10
        [idx, centers] = kmeans(allWindows, i);
        s = silhouette(allWindows, idx);
        total = total + sum(s)/length(s);
    end
    total = total / 10;
    fprintf(1, 'Number clusters: %i     Avg sil score: %f\n', i, total);
end

[idx, centers] = kmeans(allWindows, 48);
silhouette(allWindows, idx)

waitforbuttonpress;

%Plot each cluster
for i = 1:48
    index = find(idx == i);
    plotData = allWindows(index, :);
    x = linspace(1, 24, 24);
    xflip = [x(1 : end - 1) fliplr(x)];
    for j = 1:size(plotData, 1)
        y = plotData(j, :);
        yflip = [y(1 : end - 1) fliplr(y)];
        patch(xflip, yflip, 'r', 'EdgeAlpha', 0.15, 'FaceColor', 'none');
        hold on
    end
    hold off
    
    clusterDays = allDayNums(index);
    datestr(clusterDays)
    weekday(clusterDays)
    
    waitforbuttonpress;
    clf
end
