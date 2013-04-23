function output = hmmForecastSingle(obj, data, ahead)
    %prior should be a 1 by numStates
    %mu = sizeDimensions by States by numMixtures
        
    %Set the obeservation likelihoods for the whole dataset
    obslik = mixgauss_prob(data, obj.mu, obj.sigma, obj.mixmat);
    [alpha, ~, ~, ~] = fwdback(obj.prior, obj.transmat, obslik, 'fwd_only', 1);
    
    futureState = alpha(:, end);
        
    for i = 1:ahead
        futureState = obj.transmat' * futureState;
        futureState(futureState < 0.0001) = 0.0001;
        futureState = futureState / sum(futureState);
    end
        
    %Compute the output from the future state.
    output = sum(futureState' .* obj.stateEVal, 2);    
end
