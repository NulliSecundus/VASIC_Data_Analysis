%% Setup and parameters
clearvars

% Begin Filter Controls
filter1ON = true; % show duration filter
filter2ON = true; % show total weight filter
filter3ON = true; % show minimum weight per footpad filter
histBins = 60; % controls the number of 'bins' for each histogram
sizeParameter = 2; % Variable determining minimum data points per epoch
errorRate = 0.2; % error rate, allowed percentage deviation from max weight
positionError = 0.03; % how much minimum weight required per footpad
% End Filter Controls

fileListing = dir('*.csv');
fileNum = size(fileListing,1);
fileNameList = strings(1,1);
fileNameListIndex = 1;
dirPath = 'Results/Figures/';
mkdir(dirPath);

filterNum = filter1ON + filter2ON + filter3ON;
plotNum = 1 + filterNum;
plotHeight = plotNum * 230;

date = '';
replicateName = '';
replicateIndex = 1;

errorIndex = 1;
errorList = strings(1,1);

avgTotTime = cell(1);
avgTotTimeIndex = 1;
numAccessArray = cell(1);
avgTimeAccess = cell(1);
rawLRDiff = cell(1);
filter1LRDiff = cell(1);
filter2LRDiff = cell(1);
filter3LRDiff = cell(1);
rawLRDiffNorm = cell(1);
filter1LRDiffNorm = cell(1);
filter2LRDiffNorm = cell(1);
filter3LRDiffNorm = cell(1);

%% Main loop - file processing
for index = 1:fileNum
    try
        %% Prepare file import and parse raw data
        filename = fileListing(index).name; % get .csv file
        splitFilename = strsplit(filename, '_');
        
        if size(splitFilename, 2) <= 1
           splitFilename = strsplit(filename); 
        end
        
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
        dispStr = ['Loading ' filename ' (' num2str(index) ')'];
        disp(dispStr);
        rawData = readtable(filename, opts);
        
        % Check raw data for previous read
        
        
        curDate = string(splitFilename{1,1});
        replicateName = string(splitFilename{1,2});
        avgTotTimeRepSize = size(avgTotTime, 2);
        
        replicateFound = false;
        dateFound = strcmp(curDate, date);
        
        for attrs = 2:avgTotTimeRepSize
            if strcmp(string(avgTotTime{1,attrs}),replicateName)
                replicateFound = true;
                replicateIndex = attrs;
            end
        end
        
        if ~replicateFound
            replicateIndex = replicateIndex + 1;
            avgTotTime{1,replicateIndex} = replicateName;
            numAccessArray{1,replicateIndex} = replicateName;
            avgTimeAccess{1,replicateIndex} = replicateName;
            rawLRDiff{1,replicateIndex} = replicateName;
            filter1LRDiff{1,replicateIndex} = replicateName;
            filter2LRDiff{1,replicateIndex} = replicateName;
            filter3LRDiff{1,replicateIndex} = replicateName;
            rawLRDiffNorm{1,replicateIndex} = replicateName;
            filter1LRDiffNorm{1,replicateIndex} = replicateName;
            filter2LRDiffNorm{1,replicateIndex} = replicateName;
            filter3LRDiffNorm{1,replicateIndex} = replicateName;
        end
        
        if ~dateFound
            date = curDate;
            avgTotTimeIndex = avgTotTimeIndex + 1;
            avgTotTime{avgTotTimeIndex,1} = date;
            numAccessArray{avgTotTimeIndex,1} = date;
            avgTimeAccess{avgTotTimeIndex,1} = date;
            rawLRDiff{avgTotTimeIndex,1} = date;
            filter1LRDiff{avgTotTimeIndex,1} = date;
            filter2LRDiff{avgTotTimeIndex,1} = date;
            filter3LRDiff{avgTotTimeIndex,1} = date;
            rawLRDiffNorm{avgTotTimeIndex,1} = date;
            filter1LRDiffNorm{avgTotTimeIndex,1} = date;
            filter2LRDiffNorm{avgTotTimeIndex,1} = date;
            filter3LRDiffNorm{avgTotTimeIndex,1} = date;
        end
        
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
        numAccessArray{avgTotTimeIndex,replicateIndex} = numAccess;
        
        %% Plot L - R diff of extracted data (raw)
        clear Y;
        Y = parseData(2:end,4); % Extract L-R column
        Y = cell2mat(Y);
        Mean = mean(Y); % L-R mean
        rawLRDiff{avgTotTimeIndex,replicateIndex} = Mean;
        Stdev = std(Y); % L-R Stdev
        AvgDur = mean(cell2mat(avgDur),1); % Average epoch duration
        avgTimeAccess{avgTotTimeIndex,replicateIndex} = AvgDur;
        TotDur = sum(cell2mat(avgDur),1); % Cumulative valid data point duration
        avgTotTime{avgTotTimeIndex,replicateIndex} = TotDur;
        
        % Plot 'Raw Data' L-R difference over time
        fig = figure('position', [300, 50, 1500, plotHeight], 'visible', 'off'); % Create new figure with specified size
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
        
        clear Y;
        Y = filterData1(2:end,4);
        Y = cell2mat(Y);
        Mean = mean(Y);
        filter1LRDiff{avgTotTimeIndex,replicateIndex} = Mean;
        Stdev = std(Y);
        
        % Show plot and histogram if desired
        if filter1ON
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

        clear Y;
        Y = filterData2(2:end,4);
        Y = cell2mat(Y);
        Mean = mean(Y);
        filter2LRDiff{avgTotTimeIndex,replicateIndex} = Mean;
        Stdev = std(Y);
        
        % Show plot and histogram if desired
        if filter2ON
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
        
        clear Y;
        Y = filterData3(2:end,4);
        Y = cell2mat(Y);
        Mean = mean(Y);
        filter3LRDiff{avgTotTimeIndex,replicateIndex} = Mean;
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
        figureNameBase = filename(1:end-4);
        figureName = [figureNameBase '_Figure_[Weight_' num2str(weightMetric) 'g]'];
        dispStr = ['Saving ' figureName];
        disp(dispStr);
        savePath = ['Results/Figures/' figureName];
        %savefig(savePath);
        saveas(fig,[savePath '.jpg']);
        close;
        
        %% Save filename for file-read log
        fileNameList(fileNameListIndex,1) = [filename ' (' num2str(index) ')'];
        fileNameListIndex = fileNameListIndex + 1;
        
    catch
        close;
        disp(['Error processing data in file ' filename]);
        errorList(errorIndex,1) = [filename ' (' num2str(index) ')'];
        errorIndex = errorIndex + 1;
    end
end

%% Calculate final stats
avgTotTime{1,end+1} = 'Average';
s = size(avgTotTime, 1);
for n = 2:s
    index = size(avgTotTime, 2);
    for i = 2:index-1
        avg{1,i-1} = avgTotTime{n,i};
    end
    avgTotTime{n,end} = mean(cell2mat(avg));
end
avg = {};

numAccessArray{1,end+1} = 'Average';
s = size(numAccessArray, 1);
for n = 2:s
    index = size(numAccessArray, 2);
    for i = 2:index-1
        avg{1,i-1} = numAccessArray{n,i};
    end
    numAccessArray{n,end} = mean(cell2mat(avg));
end
avg = {};

avgTimeAccess{1,end+1} = 'Average';
s = size(avgTimeAccess, 1);
for n = 2:s
    index = size(avgTimeAccess, 2);
    for i = 2:index-1
        avg{1,i-1} = avgTimeAccess{n,i};
    end
    avgTimeAccess{n,end} = mean(cell2mat(avg));
end
avg = {};

rawLRDiff{1,end+1} = 'Average';
s = size(rawLRDiff, 1);
for n = 2:s
    index = size(rawLRDiff, 2);
    for i = 2:index-1
        avg{1,i-1} = rawLRDiff{n,i};
    end
    rawLRDiff{n,end} = mean(cell2mat(avg));
end
avg = {};

filter1LRDiff{1,end+1} = 'Average';
s = size(filter1LRDiff, 1);
for n = 2:s
    index = size(filter1LRDiff, 2);
    for i = 2:index-1
        avg{1,i-1} = filter1LRDiff{n,i};
    end
    filter1LRDiff{n,end} = mean(cell2mat(avg));
end
avg = {};

filter2LRDiff{1,end+1} = 'Average';
s = size(filter2LRDiff, 1);
for n = 2:s
    index = size(filter2LRDiff, 2);
    for i = 2:index-1
        avg{1,i-1} = filter2LRDiff{n,i};
    end
    filter2LRDiff{n,end} = mean(cell2mat(avg));
end
avg = {};

filter3LRDiff{1,end+1} = 'Average';
s = size(filter3LRDiff, 1);
for n = 2:s
    index = size(filter3LRDiff, 2);
    for i = 2:index-1
        avg{1,i-1} = filter3LRDiff{n,i};
    end
    filter3LRDiff{n,end} = mean(cell2mat(avg));
end
avg = {};

%% Plot and save cumulative stats
mkdir('Results/Access_Stats');
mkdir('Results/LR_Differences');

%{
timeFig = figure('position', [300, 50, 500, 400], 'visible', 'off');
s = size(avgTotTime, 1);
clear Y;
for n = 2:s
  Y(n-1,1) = avgTotTime{n,end};
end
plot(Y)
title('Average Total Access Time');
xlabel('Date');
ylabel('Seconds');
axis([0 inf 0 inf]);
saveas(timeFig, 'Results/Access_Stats/Average_Total_Access_Time_Figure.jpg');
close;
%}

%% Write out Error-Log and stats
fid = fopen('Results/Errors.txt', 'w');
fprintf(fid, 'Error processing data in file: %s \r\n', errorList);
fclose(fid);

fid = fopen('Results/Log.txt', 'w');
fprintf(fid, 'File Read: %s \r\n', fileNameList);
fclose(fid);

fid = fopen('Results/Access_Stats/Average_Total_Access_Time.csv', 'w');
fprintf(fid, '%s,', avgTotTime{1,1:end-1});
fprintf(fid, '%s\n', avgTotTime{1,end});
s = size(avgTotTime, 1);
for n = 2:s
    fprintf(fid, 'Day %s,', avgTotTime{n,1});
    fprintf(fid, '%f,', avgTotTime{n,2:end-1});
    fprintf(fid, '%f\n', avgTotTime{n,end});
end
fclose(fid);

fid = fopen('Results/Access_Stats/Average_Number_Access_Events.csv', 'w');
fprintf(fid, '%s,', numAccessArray{1,1:end-1});
fprintf(fid, '%s\n', numAccessArray{1,end});
s = size(numAccessArray, 1);
for n = 2:s
    fprintf(fid, 'Day %s,', numAccessArray{n,1});
    fprintf(fid, '%f,', numAccessArray{n,2:end-1});
    fprintf(fid, '%f\n', numAccessArray{n,end});
end
fclose(fid);

fid = fopen('Results/Access_Stats/Average_Time_Per_Access_Event.csv', 'w');
fprintf(fid, '%s,', avgTimeAccess{1,1:end-1});
fprintf(fid, '%s\n', avgTimeAccess{1,end});
s = size(avgTimeAccess, 1);
for n = 2:s
    fprintf(fid, 'Day %s,', avgTimeAccess{n,1});
    fprintf(fid, '%f,', avgTimeAccess{n,2:end-1});
    fprintf(fid, '%f\n', avgTimeAccess{n,end});
end
fclose(fid);

fid = fopen('Results/LR_Differences/Average_Raw_LR_Difference.csv', 'w');
fprintf(fid, '%s,', rawLRDiff{1,1:end-1});
fprintf(fid, '%s\n', rawLRDiff{1,end});
s = size(rawLRDiff, 1);
for n = 2:s
    fprintf(fid, 'Day %s,', rawLRDiff{n,1});
    fprintf(fid, '%f,', rawLRDiff{n,2:end-1});
    fprintf(fid, '%f\n', rawLRDiff{n,end});
end
fclose(fid);

fid = fopen('Results/LR_Differences/Average_Filter1_LR_Difference.csv', 'w');
fprintf(fid, '%s,', filter1LRDiff{1,1:end-1});
fprintf(fid, '%s\n', filter1LRDiff{1,end});
s = size(filter1LRDiff, 1);
for n = 2:s
    fprintf(fid, 'Day %s,', filter1LRDiff{n,1});
    fprintf(fid, '%f,', filter1LRDiff{n,2:end-1});
    fprintf(fid, '%f\n', filter1LRDiff{n,end});
end
fclose(fid);

fid = fopen('Results/LR_Differences/Average_Filter2_LR_Difference.csv', 'w');
fprintf(fid, '%s,', filter2LRDiff{1,1:end-1});
fprintf(fid, '%s\n', filter2LRDiff{1,end});
s = size(filter2LRDiff, 1);
for n = 2:s
    fprintf(fid, 'Day %s,', filter2LRDiff{n,1});
    fprintf(fid, '%f,', filter2LRDiff{n,2:end-1});
    fprintf(fid, '%f\n', filter2LRDiff{n,end});
end
fclose(fid);

fid = fopen('Results/LR_Differences/Average_Filter3_LR_Difference.csv', 'w');
fprintf(fid, '%s,', filter3LRDiff{1,1:end-1});
fprintf(fid, '%s\n', filter3LRDiff{1,end});
s = size(filter3LRDiff, 1);
for n = 2:s
    fprintf(fid, 'Day %s,', filter3LRDiff{n,1});
    fprintf(fid, '%f,', filter3LRDiff{n,2:end-1});
    fprintf(fid, '%f\n', filter3LRDiff{n,end});
end
fclose(fid);

disp('Finished');