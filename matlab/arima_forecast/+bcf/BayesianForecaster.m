classdef BayesianForecaster < handle
    %Class for a Bayesian forecaster
    
    %TODO FIX BAYESIAN FORECASTER.  PROBS DON'T COMPUTE CORRECTLY WITH HMMS
    %right now.
    
    properties
        models = {};
        minProb;
        maxProb;
    end
    
    methods
        function obj = BayesianForecaster(models)
            obj.models = models;
            obj.minProb = 0.001;
            obj.maxProb = 0.999;
            %obj.stds = ones(1, size(models, 2));
            %obj.means = zeros(1, size(models, 2));
        end
        
        function setMinMaxProb(obj, minProb, maxProb)
            %Set the minimum and maximum values for pmodel
            obj.minProb = minProb;
            obj.maxProb = maxProb;
        end
        
        function [pmodel] = ...
                    updatepmodel(obj, data, pmodel) 
            %Update the probabilities for all models

            probs = zeros(size(pmodel));
            
            for k = 1:size(pmodel, 2)
                probs(1, k) = mvnpdf(data(:, end) - obj.models{k}.forecast(data(:, 1:(end - 1)), 1), ...
                                    obj.models{k}.fnMu, obj.models{k}.fnSigma);
            end

            nc = pmodel * probs';
            pmodel = (probs.*pmodel)./nc;
            
            pmodel(pmodel <= obj.minProb) = obj.minProb;
            pmodel(pmodel >= obj.maxProb) = obj.maxProb;
            
            %TODO
            %Redistribute the probabilities according to the probability
            %limits
        end
        
        function [f] = forecastSingle(obj, data, pmodel, ahead, ftype)
            %Forecast a single point in a time series.  The point may be
            %steps ahead
            tmp = obj.models(1).forecast(data(:, end - 1));
            f = zeros(size(tmp));
            
            if strcmp(ftype, 'aggregate')
                for k = 1:size(pmodel, 2)
                    f = f + pmodel(k).*obj.models{k}.forecast(data(:, 1:end), ahead);
                end
            end
            
            if strcmp(ftype, 'best')
                [~, ind] = max(pmodel);
                f = obj.models(ind).forecast(data(:, 1:end), ahead);
            end            
        end
        
        function [fdata probs models] = ...
                forecast(obj, data, windowLen, ahead, ftype)
            %Perform a complete forecast for a dataset.  Initial model
            %probabilities are set to 1/numModels
            
            %Returns all forecasts for data and all probabilities of
            %forecasts
            probs = ones(size(obj.models, 2), size(data, 2));
            probs = probs ./ size(obj.models, 2);            
            models = zeros(1, size(data, 2));
            fdata = data;
            
            for i = windowLen + 1:size(data, 2) - ahead
                pmodels = probs(:, i - 1)';
                probs(:, i) = obj.updatepmodel(data(i - windowLen:i), pmodels);

                [f] = obj.forecastSingle(data(i - windowLen:i), ...
                                           probs(:, i)', ahead, ftype);
                [~, ind] = max(pmodels);
                models(1, i) = ind;
                fdata(:, i + ahead) = f;
            end
        end
        
        function [fdata probs rawProbs] = forecastAll(obj, data, ahead, modelAhead, ftype, threshold, defaultModel)
            %Perform a complete forecast for a dataset.  Initial model
            %probabilities are set to 1/numModels
            
            %This method works with static window and ahead forecasters.
            %Such as neural networks
            
            %Ahead refers to how far ahead the bcf forecast function
            %produces forecasts
            
            %modelAhead referes to how far back the bcf forecaster uses
            %data to know which model is more accurate at time t.
            
            %threshold is for determining the minimum pvalue at which to
            %use a model.  If the pvalue is sufficiently small then
            %forecasts will come from the default model only.
            
            %First make a forecast for each model.
            fcasts = repmat(data, [1 1 size(obj.models, 2)]);
            fdata = data;
            dexpand = repmat(data, [1 1 size(obj.models, 2)]);
            for k = 1:size(obj.models, 2)
                %fprintf(1, 'Forcast for model %i\n', k);
                fcasts(:, :, k) = obj.models{k}.forecastAll(data, modelAhead, 'window', 3);
            end
            
            if ahead ~= modelAhead
                for k = 1:size(obj.models, 2)
                    %fprintf(1, 'Forcast for model %i\n', k);
                    fcastsAhead(:, :, k) = obj.models{k}.forecastAll(data, ahead, 'window', 3);
                end
            else
                fcastsAhead = fcasts;
            end
                     
            diffs = fcasts - dexpand;
            initial = ones(size(obj.models));
            initial = initial ./ size(obj.models, 2);
           
            %batch update pmodels
            [aPmodels rawProbs] = obj.updatePModelsAll(diffs, initial);
            
            %Find instances where all models are below threshold.  If so
            %then set default model to 1 and all others to zero.
            for t = 1:size(aPmodels, 2)
                if all(rawProbs(:, t) < threshold)
                    %fprintf(1, 'Happened\n');
                    aPmodels(:, t) = zeros(size(obj.models, 2), 1);
                    aPmodels(defaultModel, t) = 1;
                end
            end
            
            %Forecast - perform either best or aggregate.
            if strcmp(ftype, 'best')
                [~, ind] = max(aPmodels);
                %aPmodels
                %I know this way sucks but I can't figure out a direct
                %indexing way to do this for now
                for i = 1 + ahead:size(data, 2)
                    fdata(:, i) = fcastsAhead(:, i, ind(i - ahead));
                end
            end
            
            if strcmp(ftype, 'aggregate')
                %This is an absurd way to do this.  There must be a better
                %way
                y = reshape(aPmodels', [1 size(aPmodels')]);
                y = repmat(y, [size(data, 1) 1 1]);
                fdata = zeros(size(data));
                fdata(:, 1) = data(:, 1);
                
                for k = 1:size(obj.models, 2)
                   fdata(:, 1 + ahead:end) = fdata(:, 1 + ahead:end) + fcastsAhead(:, 1 + ahead:end, k) .* y(:, 1:end - ahead, k); 
                end
            end
            
            %TODO fill in prob models here
            probs = aPmodels;
            %models = [];
        end
        
        function [aPmodels rawPValues] = updatePModelsAll(obj, diffs, pmodels)
            %Diffs is presumed to be a N by M by numModels matrix where
            %data is of length M with dimensionality N
            
            %pmodels is of size 1 by numModels
            %aPmodels will be of size numModels by M
            %pks (probability of model k given forecasting noise) is
            %numModels by M
            
            aPmodels = ones(size(obj.models, 2), size(diffs, 2));
            aPmodels(:, 1) = pmodels';
            pks = ones(size(pmodels, 2), size(diffs, 2));
            
            %diffs(:, 150:170, :)
            %size(diffs(:, :, 1))
            
            for k = 1:size(obj.models, 2)
                pks(k, :) = obj.models{k}.probabilityNoise(diffs(:, :, k));
            end
            
            %pks(:, 150:170)
            
            %Reset values
            pks(pks <= obj.minProb) = obj.minProb;
            %pks(pks >= obj.maxProb) = obj.maxProb;
            
            for i = 2:size(diffs, 2)
                %First compute the normalizing constant
                %i
                nc = aPmodels(:, i - 1)' * pks(:, i);
                %nc
                aPmodels(:, i) = (aPmodels(:, i - 1) .* pks(:, i)) ./ nc;
                %aPmodels(:, i)
                aPmodels(aPmodels(:, i) <= obj.minProb, i) = obj.minProb;
                %aPmodels(aPmodels(:, i) >= obj.maxProb, i) = obj.maxProb;
                
                %Renormalize
                aPmodels(:, i) = aPmodels(:, i) ./ sum(aPmodels(:, i), 1);
            end
            
            rawPValues = pks;
        end
        
        
        function [fdata probs models windows modelForecasts] = ...
                windowForecast(obj, data, minWindow, maxWindow, ahead, ftype)
        
            %Its fine to do this slowly for now
            
            fdata = data;
            numWindows = maxWindow - minWindow + 1;
            probs = ones(size(obj.models, 2), size(data, 2));
            probs = probs ./ size(obj.models, 1);
            
            modelForecasts = ones(size(probs)); %Only hits the first dimension for now
            windows = zeros(size(obj.models, 2), size(data, 2)); %best window for each model
            models = [];
            
            forecasts = zeros(size(data, 1), size(obj.models, 2));            
            wforecasts = zeros(size(data, 1), numWindows);
            %Array sizes
            %probs                  numModels X lenghtData
            %t = time location in data
            %w = window size
            
            %Loop over all data
            for t = maxWindow + 1:size(data, 2) - ahead
                
                if mod(t, 1000) == 0
                    fprintf(1, '%i\n', t);
                end
                %Loop over all models
                for k = 1:size(obj.models, 2)
                    
                    %Loop over all windows
                    for w = minWindow:maxWindow
                        wforecasts(:, w - minWindow + 1) = obj.models{k}.forecastSingle(data(:, t - w:t-1), 1);
                    end
                    
                    %Remove the real data
                    wres = bsxfun(@minus, wforecasts, data(:, t));
                    
                    %compute the prob of each residual for the noise dist
                    pTmp = zeros(1, size(obj.models, 2));
                    for w = 1:numWindows
                        pTmp(1, w) = obj.models{k}.probabilityNoise(wres(:, w));
                    end
                    
                    %Select the best window length
                    [val, ind] = max(pTmp);
                    
                    windows(k, t) = ind + minWindow - 1;
                    probs(k, t) = val;
                end
                
                %Update probabilities and normalize.
                probs(:, t) = probs(:, t-1) .* probs(:, t);
                probs(:, t) = probs(:, t) ./ sum(probs(:, t));
                tmpP = probs(:, t);
                tmpP(tmpP <= obj.minProb) = obj.minProb;
                tmpP(tmpP >= obj.maxProb) = obj.maxProb;
                tmpP = tmpP ./ sum(tmpP);
                probs(:, t) = tmpP;
               
                if strcmp(ftype, 'aggregate')
                    %Perform forecast based on current probabilities
                    for k = 1:size(obj.models, 2)
                        forecasts(:, k) = obj.models{k}.forecastSingle(data(:, t - windows(k, t) + 1:t), ahead);
                        modelForecasts(k, t) = forecasts(1, k);
                    end
                    tmp = sum(bsxfun(@times, forecasts, probs(:, t)'), 2);
                    
                    %Weight the forecasts by the probability
                    fdata(:, t + ahead) = tmp;
                end
                
                if strcmp(ftype, 'best')
                    %Perform forecast based on current probabilities
                    [v, ind] = max(probs(:, t));
                    fdata(:, t + ahead) = obj.models{k}.forecastSingle(data(:, t - windows(ind, t) + 1:t), ahead);
                end
            end
        end
    end
end