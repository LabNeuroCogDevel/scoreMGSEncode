
legitSet1 = [122 0 ; ...
    131 16.5; ...
    153 39; ...
    135 61.5; ...
    151 81; ...
    142 103.5; ...
    124 112.5; ...
    144 129; ...
    133 139.5; ...
    126 157.5; ...
    134 169.5; ...
    152 192; ...
    141 216; ...
    125 229.5; ...
    132 241.5; ...
    155 262.5; ...
    146 279; ...
    123 292.5; ...
    156 304.5; ...
    145 325.5];

legitSet2 = [155 0; ...
    153 18; ...
    124 36; ...
    141 48; ...
    145 63; ...
    122 72; ...
    133 85.5; ...
    151 108; ...
    134 124.5; ...
    123 144; ...
    125 159; ...
    131 175.5; ...
    126 201; ...
    156 219; ...
    142 240; ...
    144 255; ...
    135 264; ...
    152 285; ...
    146 310.5; ...
    132 324];


legitSet3 = [134 0; ...
    125 19.5; ...
    133 31.5; ...
    145 52.5; ...
    131 66; ...
    151 85.5; ...
    122 108; ...
    124 118.5; ...
    141 130.5; ...
    155 138.5; ...
    123 163.5; ...
    153 180; ...
    126 201; ...
    142 214.5; ...
    135 229.5; ...
    152 252; ...
    146 276; ...
    144 294; ...
    156 304.5; ...
    132 321];



lunaids = unique(results(:,1));
errorArray = [];
correctArray = [];
runCount = 0;
count = 0;


mgsIQRFilterCount = 0;
vgsIQRFilterCount = 0;
mgsDirFilterCount = 0;
vgsDirFilterCount = 0;
missingTrialCount = 0;

for l=1:size(lunaids,1)
    
    lunaid =lunaids(l,1);
    
    subjectData = results(results(:,1)==lunaid,:);
    
    for visit=1:max(subjectData(:,4))
        
        visitData = subjectData(subjectData(:,4)==visit,:);
        
        if ~isempty(visitData)
            
            for run=1:3
               
                runData = visitData(visitData(:,5)==run,:);
                
                if ~isempty(runData)
                     runCount = runCount + 1;
                    switch run
                        case 1
                            lookupTable = legitSet1;
                        case 2
                            lookupTable = legitSet2;
                        case 3
                            lookupTable = legitSet3;
                        otherwise
                            disp ('bah');
                    end
                    
                    % Add all trials missing from this run to the error
                    % array
                    for n=1:size(lookupTable,1)
                        if ~ismember(lookupTable(n,1),runData(:,17))
                            errorArray = [errorArray;lunaid,visit,run,lookupTable(n,1),lookupTable(n,2)*1000,0];
                            missingTrialCount = missingTrialCount + 1;
                        end
                    end
                    
                    for trial=1:max(runData(:,6))
                        
                        trialData = runData(runData(:,6)==trial,:);
                        
                        % Correct trials are marked with a 1
                        errorCode = 1;
                        
                        
                        if ~isempty(trialData)
                            targetcode = trialData(1,17);
                            trialtime = trialData(1,16);
                            % Initializes the a flag to indicate whether the trial
                            % passes all tests required to be correct
                            correct = true;
                            
                            % Generate the age category variable value
                            age = trialData(1,2);
                            if age < 13.5
                                ageCat = 1;
                            elseif age >= 13.5 && age < 17.5
                                ageCat = 2;
                            elseif age >= 17.5
                                ageCat = 3;
                            else
                                ageCat = 9;
                            end
                            
                            
                            if trialData(1,19) == 0;
                                correct = false;
                            else
                                
                                % Get the location code for the target displayed during
                                % this trial
                                locCode = trialData(1,17) - 100 - trialData(1,7);
                                
                                % Collapse the six eccentricities
                                eccentricity = [];
                                switch locCode
                                    case {1,6}
                                        eccentricity = 3;
                                    case {2,5}
                                        eccentricity = 2;
                                    case {3,4}
                                        eccentricity = 1;
                                end
                                
                                % Get the group means and inter-quartile ranges for
                                % this trial type.  This will be used to filter
                                % outliers
                                IQRs = meansIQRs( ...
                                    meansIQRs(:,1) == visit & ...
                                    meansIQRs(:,2) == ageCat & ...
                                    meansIQRs(:,3) == eccentricity,:);
                                
                                
                                % Extract the saccades categorized as encode period
                                % saccades and maintenance period saccades from the
                                % block of trial data.
                                vgs = trialData(trialData(:,9) == 1,:);
                                mgs = trialData(trialData(:,9) == 2,:);
                                
                                
                                if ~isempty(vgs)
                                    switch locCode
                                        case {1,2,3}    % Target in left hemi-field
                                            
                                            % Check to make sure that the subject has a
                                            % saccade in the left direction
                                            vgs = vgs(vgs(:,13) < 0,:);
                                            
                                        case {4,5,6}    % Target in right hemi-field
                                            
                                            % Check to make sure that the subject has a
                                            % saccade in the righ direction
                                            vgs = vgs(vgs(:,13) > 0,:);
                                            
                                    end   % switch locCode
                                    
                                    
                                    
                                end     % ~isempty(vgs)
                                
                                
                                
                                if ~isempty(vgs)
                                    mostAccVGS = vgs(abs(vgs(:,15)) == min(abs(vgs(:,15))),:);
                                    
                                    if abs(mostAccVGS(1,15)) > IQRs(1,4) + (3*IQRs(1,5))
                                        correct = false;
                                        errorCode = 2;
                                        vgsIQRFilterCount = vgsIQRFilterCount + 1;
                                    end
                                else
                                    correct = false;
                                    errorCode = 3;
                                    vgsDirFilterCount = vgsDirFilterCount + 1;
                                end     % ~isempty(vgs)
                                
                                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                
                                
                                if ~isempty(mgs)
                                    switch locCode
                                        case {1,2,3}    % Target in left hemi-field
                                            
                                            % Check to make sure that the subject has a
                                            % saccade in the left direction
                                            mgs = mgs(mgs(:,13) < 0,:);
                                            
                                        case {4,5,6}    % Target in right hemi-field
                                            
                                            % Check to make sure that the subject has a
                                            % saccade in the righ direction
                                            mgs = mgs(mgs(:,13) > 0,:);
                                            
                                    end   % switch locCode
                              
                                end     % ~isempty(mgs)
                            
                                if ~isempty(mgs)
                                    mostAccMGS = mgs(abs(mgs(:,15)) == min(abs(mgs(:,15))),:);
                                    
                                    if abs(mostAccMGS(1,15)) > IQRs(1,10) + (3*IQRs(1,11))
                                        correct = false;
                                        errorCode = 4;
                                        mgsIQRFilterCount = mgsIQRFilterCount + 1;
                                    end
                                else
                                    correct = false;
                                    errorCode = 5;
                                    mgsDirFilterCount = mgsDirFilterCount + 1;
                                end     % ~isempty(mgs)
                   
                            end     % trialData(1,19) == 0;
                         
                            if correct
                                correctArray = [correctArray;lunaid,visit,run,targetcode,trialtime,errorCode];
                            else
                                errorArray = [errorArray;lunaid,visit,run,targetcode,trialtime,errorCode];
                            end   %  if correct
                            
                        end     % ~isempty(trialData)
                        
                        
                    end     % trial=1:max(runData(:,6))
                    
                end     % ~isempty(runData)
                
                
            end     % for run=1:3
            
            
        end     % ~isempty(visitData)
        
        
    end     % visit=1:max(subjectData(:,4))
    
    
end     % l=1:size(lunaids,1)


disp([num2str(runCount),' runs'])
disp([num2str(count), ' entries.'])
