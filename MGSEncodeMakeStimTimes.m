
% Root directory string
rootDir = 'Z:\MGSENCODE\Raw\';

deconvolveList = {{'deconvolve_enc_maint.sh', 26}; ...
                  {'deconvolve_maintenanceonly2.sh', 24}; ...
                  {'deconvolve_maintenanceonly4.sh', 26}; ...
                  {'deconvolve_encodeonly.sh', 24}; ...
                  {'deconvolve_WM.sh', 26}; ...
                  {'deconvolve_eyemovements.sh', 26};...
                  {'deconvolve_encodeandmaintenance.sh', 28};...
                  {'deconvolve_WAV.sh', 28}};
                  

% Get list of unique LunaIDs
lunaids = unique(subjectData(:,1));

for i=1:size(lunaids,1)
    
    subjectInfo = subjectData(subjectData(:,1)==lunaids(i,1),:);
    
    for visit=1:max(subjectInfo(:,3))
        
        visitInfo = subjectInfo(subjectInfo(:,3)==visit,:);
        
        if ~isempty(visitInfo)
            lunaid    = visitInfo(1,1);
            sexid     = visitInfo(1,2);
            visitAge  = visitInfo(1,4);
            visitDate = visitInfo(1,5);
            motionRegressor = [];
            firstVisit = 0;
            badTRCount = 0;
            incorrectTrialCount = 0;
            correctTrialCount = 0;
            
            if visitDate == min(subjectInfo(:,5))
                firstVisit = 1;
            end
            visitData = totalArray(totalArray(:,1)==lunaid & ...
                totalArray(:,2)==visit,:);
            
            createdCensorTR = false;
            censoredTRs = '-CENSORTR';
            censoredTRVel = [];
            
            for trialCode=[20 30 40 50]
                
                correctFileContents = [];
                incorrectFileContents = [];
                
                trialData = visitData(visitData(:,4) >= 100 + trialCode & ...
                                      visitData(:,4) <= 100 + trialCode + 9,:);
                
                correctData = trialData(trialData(:,6)==1,:);
                incorrectData = trialData(trialData(:,6)~=1,:);
                
                for run=1:size(dir([rootDir num2str(lunaid) '\' num2str(visitDate) '\run*']),1)
                    
                    correctRun = {num2str((correctData(correctData(:,3)==run,5)')/1000)};
                    incorrectRun = {num2str((incorrectData(incorrectData(:,3)==run,5)')/1000)};
                    
                    correctTrialCount = correctTrialCount + size(correctData(correctData(:,3)==run,:),1);
                    incorrectTrialCount = incorrectTrialCount + size(incorrectData(incorrectData(:,3)==run,:),1);
                    
                    if strcmpi(correctRun{1},'')
                        correctFileContents = [correctFileContents;{'* *'}];
                    else
                        correctFileContents = [correctFileContents;correctRun];
                    end
                    
                    if strcmpi(incorrectRun{1},'')
                        incorrectFileContents = [incorrectFileContents;{'* *'}];
                    else
                        incorrectFileContents = [incorrectFileContents;incorrectRun];
                    end
                    
                    if ~createdCensorTR
                        runDir = [rootDir num2str(lunaid) '\' num2str(visitDate) '\run' num2str(run) '\'];
                        if size(dir(runDir),1) ~= 0
                            
                            ParFileContents = ParFileMotion([runDir 'mcplots.par'],.9,pi,false);
                            motionRegressor = [motionRegressor;ParFileContents.regressors.translational,ParFileContents.regressors.rotational];
                            
                            if ParFileContents.regressors.translational(115,1) >= .87
                                disp(['Too much movement in middle volume of LunaID: ' num2str(lunaid) ' visit: ' num2str(visit) ' run: ' num2str(run) '.  Please examine.'])
                            end
                            
                            
                            if~isempty(ParFileContents.flaggedIndices)
                                for t=1:size(ParFileContents.flaggedIndices,1)
                                    if ParFileContents.flaggedIndices(t) > 0
                                        censoredTRs = [censoredTRs ' ' ...
                                            num2str(run) ':' num2str(ParFileContents.flaggedIndices(t)-1) ' '...
                                            num2str(run) ':' num2str(ParFileContents.flaggedIndices(t)) ' '...
                                            num2str(run) ':' num2str(ParFileContents.flaggedIndices(t)+1)];
                                        
                                        
                                        censoredTRVel = [censoredTRVel ' ' ...
                                            num2str(run) ':' num2str(ParFileContents.flaggedIndices(t)) ' ' num2str(ParFileContents.regressors.translational(ParFileContents.flaggedIndices(t),1))];
                                    else
                                        censoredTRs = [censoredTRs ' ' ...
                                            num2str(run) ':' num2str(ParFileContents.flaggedIndices(t)) ' '...
                                            num2str(run) ':' num2str(ParFileContents.flaggedIndices(t)+1)];
                                    end
                                    
                                end
                            end
                            
                            
                        end
                    end
                    
                end
                
                createdCensorTR = true;
                
                switch trialCode
                    case 20
                        correctFileName     = 'lesm_correct_stimtimes.txt';
                        incorrectFileName   = 'lesm_incorrect_stimtimes.txt';
                    case 30
                        correctFileName     = 'lelm_correct_stimtimes.txt';
                        incorrectFileName   = 'lelm_incorrect_stimtimes.txt';
                    case 40
                        correctFileName     = 'sesm_correct_stimtimes.txt';
                        incorrectFileName   = 'sesm_incorrect_stimtimes.txt';
                    case 50
                        correctFileName     = 'selm_correct_stimtimes.txt';
                        incorrectFileName   = 'selm_incorrect_stimtimes.txt';
                    otherwise
                        disp('Error!')
                        return
                end
                
                path = [rootDir num2str(lunaid) '\' num2str(visitDate) '\tlrc\'];
                
                % Generate the motion regressor files
                if 1==1
                    if size(dir(path),1)~=0
                        fidRegressor = fopen([path 'trans_rot.par'], 'w');

                        for c=1:size(motionRegressor,1)
                            
                            fprintf(fidRegressor, '%f', motionRegressor(c,1));
                            fprintf(fidRegressor, '\t');
                            fprintf(fidRegressor, '%f', motionRegressor(c,2));
                            fprintf(fidRegressor, '\n');
                        end
                        fclose(fidRegressor);

                    end
                end
                
                
                
                
                % THIS PART GENERATES THE STIMTIMES
                % FILES
                if 1==1
                    if size(dir(path),1)~=0
                        fidCorrect   = fopen([path correctFileName], 'w');

                        fidIncorrect = fopen([path incorrectFileName], 'w');

                        for c=1:size(correctFileContents,1)
                            fprintf(fidCorrect ,'%s',correctFileContents{c,1});
                            fprintf(fidCorrect ,'\n');
                        end
                        
                        for c=1:size(incorrectFileContents,1)
                            fprintf(fidIncorrect ,'%s',incorrectFileContents{c,1});
                            fprintf(fidIncorrect ,'\n');
                        end
                        
                        fclose(fidCorrect);

                        fclose(fidIncorrect);

                    else
                        disp(['path: ' path ' not found!'])
                    end
                end    
            end
            
            
            for x=1:size(deconvolveList,1)
                
                deconvolveFileName = deconvolveList{x}{1};
                deconvolveFLength = deconvolveList{x}{2};
                deconvolveFID = fopen([rootDir deconvolveFileName]);

                deconvolveText = textscan(deconvolveFID,'%s',deconvolveFLength,'delimiter','\n');
                fclose(deconvolveFID);
                
                subjectDeconvolve = deconvolveText;
                
                if ~strcmpi(censoredTRs,'-censortr')
                    disp(['LunaID: ' num2str(lunaid) ' VisitDate:' num2str(visitDate) ' ' censoredTRs ])
                    disp(['LunaID: ' num2str(lunaid) ' VisitDate:' num2str(visitDate) ' ' censoredTRVel ])
                    subjectDeconvolve{1}{deconvolveFLength} = [subjectDeconvolve{1}{deconvolveFLength} ' \'];
                    subjectDeconvolve{1} = [subjectDeconvolve{1};censoredTRs];
                end
                
                if 1==1
                    
                    subjectDeconvFID = fopen([path deconvolveFileName],'w');
                    
                    if subjectDeconvFID ~=-1
                        fprintf('%s is being prepped,  FID %d\n', [path deconvolveFileName], subjectDeconvFID);
                        
                        for c=1:size(subjectDeconvolve{1},1)
                            fprintf(subjectDeconvFID ,'%s',subjectDeconvolve{1}{c});
                            fprintf(subjectDeconvFID ,'\n');
                        end
                        
                        fclose(subjectDeconvFID);

                        fprintf('%s has been written.\n', [path, deconvolveFileName]);
                    else
                        fprintf('Could not open %s.  Directory may not exist.\n',[path, deconvolveFileName]);
                    end
                end
            end
            
        end     % ~isempty(visitInfo)
        
    end     % for visit=1:max(subjectInfo(:,3))
    
end     % for i=1:size(lunaids,1)







