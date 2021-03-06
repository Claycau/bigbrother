function [windows, ind, values] = simpleExtraction(data, windowSize, threshold, center, smoothData)
%Scan through windows and search for ones that are sufficiently "deviant"
%the center option givens the ability to center the largest error

    sdata = data;

    if smoothData
        sdata = smooth(data, 5);
        sdata = sdata';
    end
    
    numWindows = floor(size(data, 2) / windowSize);
    ind = [];
    windows = [];
    values = [];
    
    for i = 0:numWindows-2
        currentIndex = i * windowSize + 1;
        tmp = sdata(1, currentIndex:currentIndex + windowSize - 1);
        val = sum(abs(tmp));
        
        if val >= threshold
            if center
                [~, maxInd] = max(abs(tmp));
                
                %shift the currentIndex so that maxInd is in the center
                currentIndex = currentIndex + maxInd - floor(windowSize/2);
                tmp = sdata(1, currentIndex:currentIndex + windowSize - 1);
                %val = sum(abs(tmp));
                
                %if val < threshold
                    %fprintf('Would have removed the window\n');
                %end
            end

            ind = [ind; currentIndex];
            windows = [windows; tmp];
            values = [values; val];
        end
    end
    
    
end

