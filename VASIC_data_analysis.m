%% Setup and import raw data, parse raw data
clearvars

% Begin Filter Controls
filter1ON = false; % show duration filter
filter2ON = false; % show total weight filter
filter3ON = true; % show minimum weight per footpad filter
histBins = 60; % controls the number of 'bins' for each histogram
sizeParameter = 2; % Variable determining minimum data points per epoch
errorRate = 0.2; % error rate, allowed percentage deviation from max weight
positionError = 0.1; % how much minimum weight required per footpad
% End Filter Controls

filterNum = filter1ON + filter2ON + filter3ON;
plotNum = 1 + filterNum;
plotHeight = plotNum * 230;

filename = uigetfile('*.csv') % get .csv file, print name to console
opts = detectImportOptions(filename);
opts.DataLine = 2; % data begins on line 2 (set according to file format)
opts.VariableNames(1) = {'Time'};
opts.VariableNames(2) = {'break1'};
opts.VariableNames(3) = {'Start_Stop'};
opts.VariableNames(4) = {'TimeStamp'};
opts.VariableNames(5) = {'break2'};
opts.VariableNames(6) = {'Left'};
opts.VariableNames(7) = {'break3'};
opts.VariableNames(8) = {'Right'};
opts.VariableNames(9) = {'Duration'};
opts.Delimiter = ',';
opts = setvartype(opts, {'Left','Right','Duration'}, 'double');
rawData = readtable(filename, opts);

parseData = {'tRef', 'Left', 'Right', 'L - R', 'L + R'};

s = size(rawData, 1);
i = 2;

avgDur = []; % array to hold duration values from each valid epoch

left = 0;
right = 0;
duration = 0;
totalMetric = 400; % Exclude format errors from older VASIC (set to ~2xBW)

% Iterate through rawData table, exclude invalid values, store in parseData
for n = 1:s
    left = rawData{n,6};
    right = rawData{n,8};
    total = left + right;
    duration = rawData{n,9};
    if((left>0) && (right>0) && (duration>=0))
        if((totalMetric - total) > 0)
            parseData{i,1} = duration;
            parseData{i,2} = left;
            parseData{i,3} = right;
            parseData{i,4} = left - right;
            parseData{i,5} = left + right;
            i = i + 1;
        end
    end
end

% Build an array 'avgDur' of duration per valid epoch (sensor breaks)
prevDur = -1;
curDur = 0;
s = size(parseData, 1);
i = 1;
for n = 2:s
    curDur = parseData{n,1};
    if((curDur > prevDur) && (curDur > 0.95))
        prevDur = curDur;
    elseif(prevDur>curDur && prevDur>2)
        avgDur{i,1} = prevDur;
        i = i+1;
        prevDur = curDur;
    end
end

numAccess = size(avgDur, 1); % Total number of access epochs
%% Plot L - R diff of extracted data (raw)
Y = parseData(2:end,4); % Extract L-R column
Y = cell2mat(Y);
Mean = mean(Y); % L-R mean
Stdev = std(Y); % L-R Stdev
AvgDur = mean(cell2mat(avgDur),1); % Average epoch duration
TotDur = sum(cell2mat(avgDur),1); % Cumulative valid data point duration

% Plot 'Raw Data' L-R difference over time
fig = figure('position', [300, 50, 1500, plotHeight]); % Create new figure with specified size
set(gcf,'name',filename,'numbertitle','off')
plotIndex = 1;
subplot(plotNum,2,plotIndex);
plotIndex = plotIndex + 1;
plot(Y)
values = ['Mean: ' num2str(Mean) ', Stdev: ' num2str(Stdev) ', Times Accessed: ' num2str(numAccess) ' (' num2str(AvgDur) ' sec avg)'];
title({'L - R diff of raw data'; values})
ylabel('L - R');
xlabel(['time (data points = ' num2str(size(Y,1)) ', Total Duration = ' num2str(TotDur) ' seconds)']);

% In the same figure, plot histogram of 'Raw Data'
subplot(plotNum,2,plotIndex);
plotIndex = plotIndex + 1;
hist = histfit(Y,histBins);
title('Histogram (L - R)')
xlabel('L - R')
ylabel('Counts')

%% Filter data by duration
filterData1 = {'tRef', 'Left', 'Right', 'L - R', 'L + R'};
s = size(parseData, 1);
container = [];
ref1 = -1;
ref2 = 0;
i = 1;

% Iterate through parseData, exclude epochs with less than 2 data points
for n = 2:s
    ref2 = parseData{n,1};
    if((ref2-ref1) > 0.5)
        container{i,1} = parseData{n,1};
        container{i,2} = parseData{n,2};
        container{i,3} = parseData{n,3};
        container{i,4} = parseData{n,4};
        container{i,5} = parseData{n,5};
        i = i + 1;
        ref1 = ref2;
    else
        if(size(container,1)>=sizeParameter)
            filterData1 = cat(1, filterData1, container);
        end
        container = [];
        i = 1;
        ref1 = ref2;
        container{i,1} = parseData{n,1};
        container{i,2} = parseData{n,2};
        container{i,3} = parseData{n,3};
        container{i,4} = parseData{n,4};
        container{i,5} = parseData{n,5};
        i = i + 1;
    end
end

% Show plot and histogram if desired
if filter1ON
    Y = filterData1(2:end,4);
    Y = cell2mat(Y);
    Mean = mean(Y);
    Stdev = std(Y);
    
    subplot(plotNum,2,plotIndex);
    plotIndex = plotIndex + 1;
    plot(Y)
    values = ['Mean: ' num2str(Mean) ', Stdev: ' num2str(Stdev)];
    title({['L - R plot filtered by duration (' num2str(sizeParameter) ')'];
        values});
    ylabel(filterData1(1,4));
    xlabel(['time (data points = ' num2str(size(Y,1)) ')']);
    
    subplot(plotNum,2,plotIndex);
    plotIndex = plotIndex + 1;
    hist = histfit(Y,histBins);
    title('Histogram (L - R)')
    xlabel('L - R')
    ylabel('Counts')
end

%% Filter data that is significantly off from total weight
filterData2 = {'tRef', 'Left', 'Right', 'L - R', 'L + R'};
s = size(filterData1, 1);

% Calculate the animal's weight from max weight(s)
weights = cell2mat(filterData1(2:end,5));
weightsSort = sort(weights, 'descend');
if(size(weightsSort,1) >= 10)
    weightsTen = weightsSort(1:10,:);
    weightMetric = mean(weightsTen);
else
    weightMetric = max(weights);
end

windowName = [filename '    (Weight: ' num2str(weightMetric) 'g)    (Filters Shown: ' num2str(filterNum) ')'];
set(gcf,'name',windowName,'numbertitle','off')

error = weightMetric * errorRate;

i = 2;

for n = 2:s
    diff = abs(weights(n-1,1) - weightMetric);
    if(diff <= error)
        filterData2{i,1} = filterData1{n,1};
        filterData2{i,2} = filterData1{n,2};
        filterData2{i,3} = filterData1{n,3};
        filterData2{i,4} = filterData1{n,4};
        filterData2{i,5} = filterData1{n,5};
        i = i + 1;
    end
end

% Show plot and histogram if desired
if filter2ON
    Y = filterData2(2:end,4);
    Y = cell2mat(Y);
    Mean = mean(Y);
    Stdev = std(Y);
    
    subplot(plotNum,2,plotIndex);
    plotIndex = plotIndex + 1;
    plot(Y)
    values = ['Mean: ' num2str(Mean) ', Stdev: ' num2str(Stdev)];
    title({['L - R plot filtered by total weight (' num2str(errorRate) ') and duration (' num2str(sizeParameter) ')'];
        values});
    ylabel(filterData2(1,4));
    xlabel(['time (data points = ' num2str(size(Y,1)) ')']);
    
    subplot(plotNum,2,plotIndex);
    plotIndex = plotIndex + 1;
    hist = histfit(Y,histBins);
    title('Histogram (L - R)')
    xlabel('L - R')
    ylabel('Counts')
end
%% Filter out data that is likely bad positioning (ie. too little weight on one footpad)
filterData3 = {'tRef', 'Left', 'Right', 'L - R', 'L + R'};
s = size(filterData2, 1);

error = weightMetric * positionError;

i = 2;
for n = 2:s
    left = filterData2{n,2};
    right = filterData2{n,3};
    if((left >= error) && (right >= error))
        filterData3{i,1} = filterData2{n,1};
        filterData3{i,2} = filterData2{n,2};
        filterData3{i,3} = filterData2{n,3};
        filterData3{i,4} = filterData2{n,4};
        filterData3{i,5} = filterData2{n,5};
        i = i + 1;
    end
end

Y = filterData3(2:end,4);
Y = cell2mat(Y);
Mean = mean(Y);
Stdev = std(Y);



% Show plot and histogram if desired
if filter3ON
    subplot(plotNum,2,plotIndex);
    plotIndex = plotIndex + 1;
    plot(Y)
    values = ['Mean: ' num2str(Mean) ', Stdev: ' num2str(Stdev)];
    title({['L - R plot filtered: minimum weight (' num2str(positionError) '), total weight (' num2str(errorRate) '), duration (' num2str(sizeParameter) ')'];
        values});
    ylabel(filterData3(1,4));
    xlabel(['time (data points = ' num2str(size(Y,1)) ')']);
    
    subplot(plotNum,2,plotIndex);
    plotIndex = plotIndex + 1;
    hist = histfit(Y,histBins);
    title('Histogram (L - R)')
    xlabel('L - R')
    ylabel('Counts')
end

%% Save Figure
%{
folderName = filename(1:end-4);
dirPath = ['Results/' folderName];
mkdir(dirPath);
figureName = [folderName '_Figure.fig'];
savePath = ['Results/' folderName '/' figureName];
savefig(savePath);
%}