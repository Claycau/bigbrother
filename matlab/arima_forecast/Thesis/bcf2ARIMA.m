%file: bcf2ARIMA
%author: James Howard
%
%Compute ABCF for ARIMA models

clear all;

%--------------------------------------------------------------------------
%SETUP CONSTANTS
%--------------------------------------------------------------------------
dataSet = 3;
model = 2; %Set MODEL to ARIMA
horizon = 2;

dataLocation = MyConstants.FILE_LOCATIONS_CLEAN{dataSet};
load(dataLocation);
load(MyConstants.RESULTS_DATA_LOCATIONS{dataSet});

%DON"T TOUCH FSTART AND END - I SHOULD HAVE FIXED THIS EARLIER
%Constrain the data for the purpose of makeing shorter runs
fStart = data.blocksInDay * 1;
fEnd = size(data.testData, 2);



%--------------------------------------------------------------------------
%SETUP DATASETS
%--------------------------------------------------------------------------
validData = data.validData(:, fStart:fEnd);
validTimes = data.validTimes(:, fStart:fEnd);
testData = data.testData(:, fStart:fEnd);
testTimes = data.testTimes(:, fStart:fEnd);
fValid = results.arima.validForecast{horizon};
validRes = validData - fValid;
fTest = results.arima.testForecast{horizon};
testRes = testData - fTest;
[~, validStds] = computeMean(validData, data.blocksInDay);


%--------------------------------------------------------------------------
%CLUSTER DATA
%--------------------------------------------------------------------------
%clusters
clustMin = 4;
clustMax = 6;
windowMin = 6;
windowMax = 10;
smoothAmount = 1;
verbose = true;
extractPer = 0.1;
                        
[windows, ind, idx, centers, kdists] = ...
                         createCluster(validRes, 1, clustMin, clustMax, ...
                         extractPer, windowMin, windowMax, ...
                         smoothAmount, verbose); 
plotClusters(windows, idx, 'centers', centers);



%--------------------------------------------------------------------------
%MODEL AND FORECAST DATA
%--------------------------------------------------------------------------
models = createGaussModels(windows, idx, validRes);

forecaster = bcf.BayesianLocalForecaster(models);
[adjRes, p, post, l, histPost] = forecaster.forecastAll(testRes, horizon);


%--------------------------------------------------------------------------
%COMPUTE RESULTS
%--------------------------------------------------------------------------
newData = fTest + adjRes;
newRes = testData - newData;

BCFRMSE = errperf(testData(1:end), fTest(1:end), 'rmse');
modBCFRMSE = errperf(testData(1:end), newData(1:end), 'rmse');
[ponanValue rmseonanValue SSEONANTest ~] = ponan(testRes, 3 * validStds);
[ponanValue rmseonanValue modSSEONAN ~] = ponan(newRes, 3 * validStds);

fprintf(1, 'RMSE - Test: %f     New: %f\n', BCFRMSE, modBCFRMSE);
fprintf(1, 'SSEONAN - Test: %f     New: %f\n', SSEONANTest, modSSEONAN);


%Save dataset

%--------------------------------------------------------------------------
%BEST CLUSTER ALL HORIZON
%--------------------------------------------------------------------------

%Dataset 1
clustMin = 5;
clustMax = 10;
windowMin = 7;
windowMax = 15;
smoothAmount = 1;
verbose = true;
extractPer = 0.15;


%Dataset 2
% clustMin = 4;
% clustMax = 8;
% windowMin = 6;
% windowMax = 12;
% smoothAmount = 1;
% verbose = true;
% extractPer = 0.15;


%Dataset 3
% clustMin = 5;
% clustMax = 10;
% windowMin = 5;
% windowMax = 8;
% smoothAmount = 1;
% verbose = true;
% extractPer = 0.15;


%Run on all horizons
for i = 1:MyConstants.HORIZON
    validRes = validData - results.arima.validForecast{i};
    testRes = testData - results.arima.testForecast{i};

    
    [windows, ind, idx, centers, kdists] = ...
                         createCluster(validRes, 1, clustMin, clustMax, ...
                         extractPer, windowMin, windowMax, ...
                         smoothAmount, false); 
    
    models = createGaussModels(windows, idx, validRes);
    forecaster = bcf.BayesianLocalForecaster(models);
                     
    
    [adjRes, p, post, l, histPost] = forecaster.forecastAll(testRes, i);
    newData = results.arima.testForecast{i} + adjRes;
    newRes = testData - newData;

    BCFRMSE = errperf(testData(1:end), results.arima.validForecast{i}(1:end), 'rmse');
    newBCFRMSE = errperf(testData(1:end), newData(1:end), 'rmse');
    [~, rmseonanValue, sqeonan, ~] = ponan(testRes, 3 * validStds);
    [~, newRmseonanValue, newSqeonan, ~] = ponan(newRes, 3 * validStds);

    fprintf(1, 'Horizon %i\n', i);
    fprintf(1, '   RMSE - Test: %f     New: %f\n', BCFRMSE, newBCFRMSE);
    fprintf(1, '   rmseonanValue - Test: %f     New: %f\n', rmseonanValue, newRmseonanValue);
    fprintf(1, '   sqeonan - Test: %f     New: %f\n', sqeonan, newSqeonan);

    
    %Save results
    results.ABCF.arima.testForecast{i} = newData;
    results.ABCF.arima.rmse(3, i) = newBCFRMSE;
    results.ABCF.arima.rmseonan(3, i) = newRmseonanValue; 
    results.ABCF.arima.sqeonan(3, i) = newSqeonan;
end

save(MyConstants.RESULTS_DATA_LOCATIONS{dataSet}, 'results');
