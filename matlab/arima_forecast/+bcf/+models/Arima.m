classdef Arima < bcf.models.Model
    %GAUSSIANMODEL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        model
    end
    
    methods
        function obj = Arima(model)
            obj.model = model;
        end
        
%         function val = forecast(obj, data, ahead)
%             val = obj.mu;
%         end
        
        function output = forcastAll(obj, data, ahead)
            output = bcf.forecast.arimaForecast(obj.model, data', ahead);
        end
            
%         function val = probability(obj, data)
%             %Forecast for a model the probability of each observation
%             %TODO Change this later
%             val = 1;
%         end
        
        function prob = probabilityNoise(obj, data)
            prob = mvnpdf(data, obj.fnMu, obj.fnSigma);
        end
        
        function calculateNoiseDistribution(obj, data)
            res = infer(obj.model, data');
            pd =  fitdist(res, 'Normal');
            obj.noiseMu = pd.mean;
            obj.noiseSigma = pd.std;
        end
    end
end


