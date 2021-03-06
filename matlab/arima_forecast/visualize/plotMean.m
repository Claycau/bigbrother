function fig = plotMean(means, varargin)
%Function to plot the mean, standard deviation, and min/max values

%Varagin can allow for a std parameter and a minmax parameter
%example:
%plotMean(means, 'std', stds, 'minmax', minmax)

if nargin < 1
   error(message('plotMean - Not enough inputs'))
end

parser = inputParser;
parser.CaseSensitive = false;
parser.addOptional('std', zeros(size(means)));
parser.addOptional('minmax', zeros(size(means)));
parser.addOptional('figsizeX', 1000);
parser.addOptional('figsizeY', 750);
parser.addOptional('xlabel', 'xlabel');
parser.addOptional('ylabel', 'ylabel');
parser.addOptional('plotTitle', 'Sensor Activation vs Time of Day');
parser.addOptional('smoothData', true);
parser.addOptional('startTime', -1);
parser.addOptional('endTime', -1);
parser.addOptional('blocksInDay', 78);
parser.addOptional('width', 3);
parser.addOptional('meanColor', [0, 0.5, 0.5]);
parser.addOptional('stdColor', [0.5, 0, 0]);
parser.addOptional('lineGraph', false);


try 
  parser.parse(varargin{:});
catch exception
  exception.throwAsCaller();
end

dataLen = size(means, 2);
stds = parser.Results.std;
minmaxes = parser.Results.minmax; %#ok<NASGU>
figsizeX = parser.Results.figsizeX;
figsizeY = parser.Results.figsizeY;
graph_xlabel = parser.Results.xlabel;
graph_ylabel = parser.Results.ylabel;
plotTitle = parser.Results.plotTitle;
smoothData = parser.Results.smoothData;
startTime = parser.Results.startTime;
endTime = parser.Results.endTime;
blocksInDay = parser.Results.blocksInDay;
width = parser.Results.width;
meanColor = parser.Results.meanColor;
stdColor = parser.Results.stdColor;
lineGraph = parser.Results.lineGraph;

%Reguarding the fliplr function used: Must flip the values due to fill 
%attempting to make a closed polygon.
%Fliping the values allows for 1 to fill with 1 and xlimit to fill with
%xlimit

if smoothData
    means = smooth(means, 3)';
end

fig = figure('Position', [100, 100, 100 + figsizeX, 100 + figsizeY]);
xvals = 1:1:dataLen;
xvals = [xvals, fliplr(xvals)];

y1 = means - stds;
y2 = means + stds;
yvals = [y1, fliplr(y2)];
tmp = fill(xvals, yvals, stdColor);
set(tmp,'EdgeColor',stdColor,'FaceAlpha',0.5,'EdgeAlpha',0.5);
hold on;

if ~lineGraph
    means1 = means - (width/2);
    means2 = means + (width/2);
    meanVals = [means1, fliplr(means2)];
    tmp2 = fill(xvals, meanVals, meanColor);
    set(tmp2, 'EdgeColor', meanColor, 'FaceAlpha', 1.0, 'EdgeAlpha', 1.0);
    hold on;
else
    plot(1:1:dataLen, means, 'LineWidth', width, 'Color', meanColor); 
    hold on
end
xlim([1, dataLen]);
%set(gca,'DefaultAxesFontName', 'Symbol')
xlabel(graph_xlabel, 'FontSize', 18, 'FontName', MyConstants.FONT_TYPE)
ylabel(graph_ylabel, 'FontSize', 18, 'FontName', MyConstants.FONT_TYPE)
title(plotTitle, 'FontSize', 24, 'FontName', MyConstants.FONT_TYPE);
set(gca,'XTickLabel',[]);

increment = blocksInDay/((endTime - startTime));

if startTime > 0
    set(gca, 'XTick', 0:increment:blocksInDay);
    set(gca, 'XTickLabel', startTime:1:endTime);
end

