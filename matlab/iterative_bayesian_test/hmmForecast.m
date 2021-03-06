function output = hmmForecast(obj, data, ahead)
    %prior should be a 1 by numStates
    %mu = sizeDimensions by States by numMixtures
    %fprintf(1, 'Here we are\n');
    
    output = data;
        
    %Set the obeservation likelihoods for the whole dataset
    obslik = mixgauss_prob(data, obj.mu, obj.sigma, obj.mixmat);
    [alpha, ~, gamma, ~] = fwdback(obj.prior, obj.transmat, obslik, 'fwd_only', 1);
    
    %size(alpha)
    
    for t = 1:size(data, 2) - ahead
        %Get the current state
        currentState = alpha(:, t);
        currentState(currentState < 0.0001) = 0.0001;
        currentState = currentState / sum(currentState);
        
        futureState = currentState;
        
        for i = 1:ahead
            %Step ahead in states
            futureState = obj.transmat' * futureState;
            futureState(futureState < 0.0001) = 0.0001;
            futureState = futureState / sum(futureState);
        end
        
        [foo, bar] =  max(abs(futureState));
        if bar == size(futureState, 1)
            futureState
            fprintf(1, '%i\n', t);
        end
        %Compute the output from the future state.
        output(:, t + ahead) = sum(futureState' .* obj.stateEVal, 2);
    end
end

