
minSaccadeLatency = 60;
maxSaccadeLatency = 1500;

minVGSSaccadeAccuracy = 1.5;
minMGSSaccadeAccuracy = 8;

mgsEncodeData = [];
incorrectTrials = {};

lunaids = unique(results(:,1));

for i=1: size(lunaids,1)
    
    lunaid = lunaids(i);
    subjectData = results(results(:,1) == lunaid,:);
    
    for visit=1:10
        
        visitData = subjectData(subjectData(:,4)==visit,:);
        visitEntry = [];
        visitSummary = [];
        
        if ~isempty(visitData)
            
            age = visitData(1,2);
            sexid = visitData(1,3);
            
            for run=1:3
                
                runData = visitData(visitData(:,5)==run,:);
                runEntry = [];
                
                for trial=1:42
                    
                    trialData = runData(runData(:,6)==trial,:);
                    
                    if ~isempty(trialData)
                        
                        % Calculate the latency and accuracy of the first saccade
                        % and the most accurate saccade
                        
                        encSaccades = trialData(trialData(:,9) == 1,:);
                        mgsSaccades = trialData(trialData(:,9) == 2,:);
                        xdatCode = trialData(1,7);
                        targetCode = trialData(1,17);
                        trialStartTime = trialData(1,16)/1000;
                        locCode = targetCode - 100 - xdatCode;
                        
                        
                        % Get the Encoding (VGS) saccades
                        if ~isempty(encSaccades)
                            
                            minAcc = min(abs(encSaccades(:,15)));
                            
                            if ~isnan(minAcc)
                                mostAccEncIndex = find(abs(encSaccades(:,15))== minAcc,1) ;
                                mostAccEncAccuracy = encSaccades(mostAccEncIndex,15);
                                mostAccEncLatency = encSaccades(mostAccEncIndex,11);
                            else
                                mostAccEncAccuracy = nan;
                                mostAccEncLatency = nan;
                            end
                            
                            firstEncLatency = encSaccades(1,11);
                            lastEncLatency = encSaccades(end,11);
                            
                            firstEncAccuracy = encSaccades(1,15);
                            lastEncAccuracy = encSaccades(end,15);
                            
                        else
                            mostAccEncLatency = nan;
                            firstEncLatency = nan;
                            lastEncLatency = nan;
                            
                            mostAccEncAccuracy = nan;
                            firstEncAccuracy = nan;
                            lastEncAccuracy = nan;
                        end
                        
                        % Get the memory-guided (MGS) saccades
                        if ~isempty(mgsSaccades)
                            
                            minAcc = min(abs(mgsSaccades(:,15)));
                            
                            if ~isnan(minAcc)
                                mostAccMGSIndex = find(abs(mgsSaccades(:,15))==minAcc,1);
                                mostAccMGSLatency = mgsSaccades(mostAccMGSIndex,11);
                                mostAccMGSAccuracy = mgsSaccades(mostAccMGSIndex,15);
                            else
                                mostAccMGSLatency = nan;
                                mostAccMGSAccuracy = nan;
                            end
                            
                            firstMGSLatency = mgsSaccades(1,11);
                            lastMGSLatency = mgsSaccades(end,11);
                            
                            firstMGSAccuracy = mgsSaccades(1,15);
                            lastMGSAccuracy = mgsSaccades(end,15);
                            
                        else
                            mostAccMGSLatency = nan;
                            firstMGSLatency = nan;
                            lastMGSLatency = nan;
                            
                            mostAccMGSAccuracy = nan;
                            firstMGSAccuracy = nan;
                            lastMGSAccuracy = nan;
                        end
                        
                        summaryScore = nan * zeros(1,18);
                        eccentricity = [];
                        
                        switch locCode
                            
                            case {1,6}
                                summaryScore(1,1) = firstMGSLatency;
                                summaryScore(1,2) = lastMGSLatency;
                                summaryScore(1,3) = mostAccMGSLatency;
                                summaryScore(1,4) = firstMGSAccuracy;
                                summaryScore(1,5) = lastMGSAccuracy;
                                summaryScore(1,6) = mostAccMGSAccuracy;
                                eccentricity = 3;
                            case {2,5}
                                summaryScore(1,7) = firstMGSLatency;
                                summaryScore(1,8) = lastMGSLatency;
                                summaryScore(1,9) = mostAccMGSLatency;
                                summaryScore(1,10) = firstMGSAccuracy;
                                summaryScore(1,11) = lastMGSAccuracy;
                                summaryScore(1,12) = mostAccMGSAccuracy;
                                eccentricity = 2;
                            case {3,4}
                                summaryScore(1,13) = firstMGSLatency;
                                summaryScore(1,14) = lastMGSLatency;
                                summaryScore(1,15) = mostAccMGSLatency;
                                summaryScore(1,16) = firstMGSAccuracy;
                                summaryScore(1,17) = lastMGSAccuracy;
                                summaryScore(1,18) = mostAccMGSAccuracy;
                                eccentricity = 1;
                        end
                        
                        
                        
                        summaryScore = abs(summaryScore);
                        trialCorrect = 1;
                        % INSERT SOME TRIAL SCORING CODE HERE ONCE THINGS
                        % GET FIGURED OUT A BIT
                        
                        % Classify the trial type by both encode and
                        % maintenance length
                        if xdatCode == 20
                            encodeType = 2;
                            maintType = 1;
                        elseif xdatCode == 30
                            encodeType = 2;
                            maintType =  2;
                        elseif xdatCode == 40
                            encodeType = 1;
                            maintType =  1;
                        elseif xdatCode == 50
                            encodeType = 1;
                            maintType =  2;
                        end
                        
                        
                        trialEntry = [                              ...       
                            xdatCode,                               ...       % (6)
                            eccentricity,                           ...       % (7)
                            encodeType,                             ...       % (8)
                            maintType,                              ...       % (9)
                            mostAccEncLatency,                      ...       % (10)
                            firstEncLatency,                        ...       % (11)
                            lastEncLatency,                         ...       % (12)
                            mostAccEncAccuracy,                     ...       % (13)
                            firstEncAccuracy,                       ...       % (14)
                            lastEncAccuracy,                        ...       % (15)
                            mostAccMGSLatency,                      ...       % (16)
                            firstMGSLatency,                        ...       % (17)
                            lastMGSLatency,                         ...       % (18)
                            mostAccMGSAccuracy,                     ...       % (19)
                            firstMGSAccuracy,                       ...       % (10)
                            lastMGSAccuracy,                        ...       % (21)
                            (mostAccEncAccuracy - mostAccMGSAccuracy), ...    % (22)
                            (firstEncAccuracy - firstMGSAccuracy), ...        % (23)
                            trialCorrect];                                    % (24)  
                        
                        
                        if size(trialEntry) ~= [1,13]
                            disp('halt!')
                        end
                        
                        visitEntry = [visitEntry;trialEntry];
                        
                       % disp([i,visit,run,trial])
                    end
                    
                    
                end
                
                
                
            end
            if ~isempty(visitEntry)
                
                                
                if age < 13.5
                    ageCat = 1;
                elseif age >= 13.5 && age < 17.5
                    ageCat = 2;
                elseif age >= 17.5
                    ageCat = 3;
                else
                    ageCat = 9;
                end
                
                idCols = zeros(size(visitEntry,1),5) + 1;
                idCols(:,1) = lunaid;       % (1)
                idCols(:,2) = sexid;        % (2)
                idCols(:,3) = age;          % (3)
                idCols(:,4) = ageCat;       % (4)
                idCols(:,5) = visit;        % (5)
                
                visitEntry = [idCols,visitEntry];
                
                
                % Split up the data by condition and excentricity
                lesmData1 = visitEntry(visitEntry(:,1)==20 & visitEntry(:,2)==1,:);
                lesmData2 = visitEntry(visitEntry(:,1)==20 & visitEntry(:,2)==2,:);
                lesmData3 = visitEntry(visitEntry(:,1)==20 & visitEntry(:,2)==3,:);
                
                lelmData1 = visitEntry(visitEntry(:,1)==30 & visitEntry(:,2)==1,:);
                lelmData2 = visitEntry(visitEntry(:,1)==30 & visitEntry(:,2)==2,:);
                lelmData3 = visitEntry(visitEntry(:,1)==30 & visitEntry(:,2)==3,:);
                
                sesmData1 = visitEntry(visitEntry(:,1)==40 & visitEntry(:,2)==1,:);
                sesmData2 = visitEntry(visitEntry(:,1)==40 & visitEntry(:,2)==2,:);
                sesmData3 = visitEntry(visitEntry(:,1)==40 & visitEntry(:,2)==3,:);
                
                selmData1 = visitEntry(visitEntry(:,1)==50 & visitEntry(:,2)==1,:);
                selmData2 = visitEntry(visitEntry(:,1)==50 & visitEntry(:,2)==2,:);
                selmData3 = visitEntry(visitEntry(:,1)==50 & visitEntry(:,2)==3,:);
                               
                visitSummary = [visitSummary; visitEntry];
                                              
                mgsEncodeData = [mgsEncodeData;visitSummary];
                
                              
            end
            
        end
        
        
        
    end
    
    
    
end

correctedMGSEncodeData = [];

discardcount = 0;


disp(['Visit,AgeGroup,Eccentricity,MeanMostAccVGS,MostAccVGSIQR,MeanFirstVGS,FirstVGSIQR,MeanLastVGS,LastVGSIQR,MeanMostAccMGS,MostAccMGSIQR,MeanFirstMGS,FirstMGSIQR,MeanLastMGS,FirstMGSIQR'])
meansIQRs = [];

for v=1:max(mgsEncodeData(:,5))
    
    visitGrpData = mgsEncodeData(mgsEncodeData(:,5)==v,:);
    if ~isempty(visitGrpData)
        
        for a=1:max(visitGrpData(:,4))
            
            ageGrpData = visitGrpData(visitGrpData(:,4)==a,:);
            ageGrpMeans = nanmean(ageGrpData,1);
                        
            for e=1:3
                
                ageGrpEccData  = ageGrpData(ageGrpData(:,7)==e,:);
                ageGrpEccMeans = nanmean(ageGrpEccData,1);
                ageGrpEccMeansDiff = ageGrpMeans - ageGrpEccMeans;
      
                % Apply age group eccentricity correction
                %ageGrpEccData(:,13) = ageGrpEccData(:,13) + ageGrpEccMeansDiff(1,13);
                %ageGrpEccData(:,14) = ageGrpEccData(:,14) + ageGrpEccMeansDiff(1,14);
                %ageGrpEccData(:,15) = ageGrpEccData(:,15) + ageGrpEccMeansDiff(1,15);
                
                %ageGrpEccData(:,19) = ageGrpEccData(:,19) + ageGrpEccMeansDiff(1,19);
                %ageGrpEccData(:,20) = ageGrpEccData(:,20) + ageGrpEccMeansDiff(1,20);
                %ageGrpEccData(:,21) = ageGrpEccData(:,21) + ageGrpEccMeansDiff(1,21);
                
                ageGrpEccIQR = iqr(ageGrpEccData,1);
                ageGrpEccMax = ageGrpEccMeans + (ageGrpEccIQR .* 3);
                ageGrpEccMin = ageGrpEccMeans - (ageGrpEccIQR .* 3);
                lunaids = unique(ageGrpEccData(:,1));
                
                
                meansIQRs = [meansIQRs; ...
                    [v,a,e,                                 ...
                    ageGrpEccMeans(1,13),ageGrpEccIQR(1,13),...
                    ageGrpEccMeans(1,14),ageGrpEccIQR(1,14),...
                    ageGrpEccMeans(1,15),ageGrpEccIQR(1,15),...
                    ageGrpEccMeans(1,19),ageGrpEccIQR(1,19),...
                    ageGrpEccMeans(1,20),ageGrpEccIQR(1,20),...
                    ageGrpEccMeans(1,21),ageGrpEccIQR(1,21)]];
                
                                        
                
                if ~isempty(ageGrpData)
                    disp([num2str(v),',',num2str(a),',',num2str(e),',', ...
                    num2str(ageGrpEccMeans(1,13)),',',num2str(ageGrpEccIQR(1,13)),',',...
                    num2str(ageGrpEccMeans(1,14)),',',num2str(ageGrpEccIQR(1,14)),',',...
                    num2str(ageGrpEccMeans(1,15)),',',num2str(ageGrpEccIQR(1,15)),',',...
                    num2str(ageGrpEccMeans(1,19)),',',num2str(ageGrpEccIQR(1,19)),',',...
                    num2str(ageGrpEccMeans(1,20)),',',num2str(ageGrpEccIQR(1,20)),',',...
                    num2str(ageGrpEccMeans(1,21)),',',num2str(ageGrpEccIQR(1,21))...
                    ])
                end
                
                for l=1:size(lunaids,1)
                    discardIDX = [];
                    subjData = ageGrpEccData(ageGrpEccData(:,1)==lunaids(l,1),:);
                    if ~isempty(subjData)
                        for s=1:size(subjData,1)
                           
                            if subjData(s,20) > ageGrpEccMax(1,20) || ...
                               subjData(s,20) < ageGrpEccMin(1,20)     
                                discardcount = discardcount + 1;
                                
                            else
                                correctedMGSEncodeData = [correctedMGSEncodeData;subjData(s,:)];
                            end
                            
                        end                        
                        
                    end                 
                   
                end
                                            
            end
        
        end
        
    end

end




collapsedMGSEncodeData = [];

for v=1:max(correctedMGSEncodeData(:,5))
    
    lunaids = unique(correctedMGSEncodeData(correctedMGSEncodeData(:,5)==v,1));
    
    for l=1:size(lunaids,1)
        
        lesmData1 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==20 & correctedMGSEncodeData(:,7)==1,:);
        lesmData2 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==20 & correctedMGSEncodeData(:,7)==2,:);
        lesmData3 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==20 & correctedMGSEncodeData(:,7)==3,:);
        
        lelmData1 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==30 & correctedMGSEncodeData(:,7)==1,:);
        lelmData2 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==30 & correctedMGSEncodeData(:,7)==2,:);
        lelmData3 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==30 & correctedMGSEncodeData(:,7)==3,:);
        
        sesmData1 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==40 & correctedMGSEncodeData(:,7)==1,:);
        sesmData2 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==40 & correctedMGSEncodeData(:,7)==2,:);
        sesmData3 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==40 & correctedMGSEncodeData(:,7)==3,:);
        
        selmData1 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==50 & correctedMGSEncodeData(:,7)==1,:);
        selmData2 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==50 & correctedMGSEncodeData(:,7)==2,:);
        selmData3 = correctedMGSEncodeData(correctedMGSEncodeData(:,1)==lunaids(l,1) & correctedMGSEncodeData(:,5)==v & correctedMGSEncodeData(:,6)==50 & correctedMGSEncodeData(:,7)==3,:);
        
        lesmData1(:,22:23) = abs(lesmData1(:,22:23));
        lesmData2(:,22:23) = abs(lesmData2(:,22:23));
        lesmData3(:,22:23) = abs(lesmData3(:,22:23));
        
        lelmData1(:,22:23) = abs(lelmData1(:,22:23));
        lelmData2(:,22:23) = abs(lelmData2(:,22:23));
        lelmData3(:,22:23) = abs(lelmData3(:,22:23));
        
        sesmData1(:,22:23) = abs(sesmData1(:,22:23));
        sesmData2(:,22:23) = abs(sesmData2(:,22:23));
        sesmData3(:,22:23) = abs(sesmData3(:,22:23));
        
        selmData1(:,22:23) = abs(selmData1(:,22:23));
        selmData2(:,22:23) = abs(selmData2(:,22:23));
        selmData3(:,22:23) = abs(selmData3(:,22:23));
        
        
        collapsedMGSEncodeData = [ collapsedMGSEncodeData; ...
                                   nanmean(lesmData1,1); ... 
                                   nanmean(lesmData2,1); ...
                                   nanmean(lesmData3,1); ...
                                   nanmean(lelmData1,1); ... 
                                   nanmean(lelmData2,1); ...
                                   nanmean(lelmData3,1); ...
                                   nanmean(sesmData1,1); ... 
                                   nanmean(sesmData2,1); ...
                                   nanmean(sesmData3,1); ...
                                   nanmean(selmData1,1); ... 
                                   nanmean(selmData2,1); ...
                                   nanmean(selmData3,1); ...
                                 ];
        
    
    end    
disp(['Collapsing visit ' , num2str(v)])
end

