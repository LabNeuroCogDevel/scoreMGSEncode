function [results] = MGSEncodeAnalyze_unixpat()

minSaccadeCount = 5;    % Minimum number of saccades per .eyd file allowed before a warning is thrown
maxInterpSamples = 5;       % Maixmum number of samples with lost pupil fix to interpolate over.  Anything above will be marked as a blink


% GETS A LIST OF ALL OF THE SUBJECTS THAT NEED TO BE PROCESSED
[num txt raw] = xlsread('/mnt/B/bea_res/Personal/David/MGSEncode/subjectlist_2013_04_22.xls',1);
clear num txt

results = [];

% DEFINE TIMECOURSE SMOOTHING FILTER
filter = ilabGaussWindow(7,2);
xfilter = ilabGaussWindow(7,2);
yfilter =  ilabGaussWindow(7,2);
% BUILD A STRUCTRUE THAT CONTAINS TRIAL INFORMATION
trialTypes = MGSEncodeCreateTrialTypes;

% BUILD ANALYSISPARMS
AP = MGSEncodeAnalysisParms;
AP.filter = ilabRegisterFilters(AP);
AP.roi.roi  = ilabGetROI('reset');
AP.warnings = ilabWarnings;

resultCount = 0;

for z=2:size(raw,1)
    
    lunaid = raw{z,1};
    sexid = raw{z,2};
    visit = raw{z,3};
    age = raw{z,4};
    pname = raw{z,5};
    fname = raw{z,6};
    
    fprintf('Opening %s\n', [pname fname])
    
    try
        % OPEN THE SUPPLIED .EYD FILE AND CREATE THE ILAB RAW DATA VARIABLE
        ILAB = LoadEYDFile(AP,pname,fname,6);
        
        % LOAD THE ASL COORDINATE SYSTEM INTO THE ILAB VARIABLE
        ILAB.coordSys = AP.coordSys(1,2);
        
        % Remove any duplicate XDAT codes
        ILAB.data = RemoveDuplicateXDAT(ILAB.data);
        
        % Remove any leading 250 or 60 XDAT codes 
        ILAB.data = TrimLeadingXDAT(ILAB.data,[250,60]);
        
        [errorTrial,codeTable] = CheckSerialCodes(ILAB,AP.trialCodes)
        
        
        
        %ILAB = CleanILABData(ILAB,AP);
        success = true;
    catch exception
        fprintf('\t%s',exception.message)
        success = false;
    end
    
    if success
        
        experimentStartIndex = [];
        
        fileCreationTime = regexp(ILAB.time, '[:\ ]', 'split');
        
        if strcmpi(fileCreationTime(end),'pm')
            fileCreationTime = [str2num(fileCreationTime{1}) + 12 ...
                str2num(fileCreationTime{2}) ...
                str2num(fileCreationTime{3})];
        else
            fileCreationTime = [str2num(fileCreationTime{1}) ...
                str2num(fileCreationTime{2}) ...
                str2num(fileCreationTime{3})];
        end
        

        
        % GENERATE THE INITIAL PLOTPARMS VARIABLE
        PP = MGSEncodeDefaultPlotParms;
        
        % ATTEMPT TO GENERATE THE TRIAL INDEX FOR THIS DATASET
        [hasCodes,index] = CreateIndex(ILAB.data(:,3), AP.trialCodes);
        resultCount = resultCount + 1;
        if hasCodes && size(index,1) > 1
            
            % INSERT THE TRIAL INDEX INTO THE ILAB VARIABLE
            % LOAD THE INDEX AND TRIAL INFO INTO THE ILAB VARIABLE
            ILAB.index = index;
            ILAB.trialCodes = AP.trialCodes;
            ILAB.trials = size(index,1);
            
            % DETERMINE WHAT THE RUN NUMBER
            switch ILAB.data(ILAB.index(1,1),3)
                
                case 20
                    % Run 1 starts with a LESM trial
                    runNumber = 1;
                case 30
                    runNumber = 3;
                    
                case 50
                    runNumber = 2;
                otherwise
                    runNumber = 4;
            end
            
            
            %CorrectILABData(ILAB,AP,runNumber)
            
            % The fMRI starts when the first trial code
            % appears, so if the variable experimentStartIndex
            % is empty, set it to the start index of this trial
            experimentStartIndex = ILAB.index(1,1);
            
            
            % Clear the unused index and hasCodes variables
            clear index hasCodes
            
            % MERGE CONSECUTIVE FIXATION TRIAL INTO A SINGLE FIXATION TRIAL
            MergeFixations
            
            % PATCH SMALL GAPS DUE TO PUPIL LOSS WITH INTERPOLATED DATA
            fprintf('\tThere are %d samples with pupil loss before interpolation.\n', nnz(ILAB.data(:,4)==0))
            ILAB.data = ASLPupilFill(ILAB,AP);
            fprintf('\tThere are %d samples with pupil loss after interpolation.\n', nnz(ILAB.data(:,4)==0))
           
            % SYNC THE PLOT PARMS VARIABLE WITH THE ILAB VARIABLE
            PP.data = ILAB.data;
            PP.index = ILAB.index;
            PP.trials = ILAB.trials;
            
            fprintf('\tRun: %d\n\tTrials: %d\n', runNumber,size(PP.index,1))
            
            

            % FILTER BLINKS FROM RAW DATA
            fprintf('\tFiltering blinks...\n')
            AP.blink.list  = ilabMkBlinkList(PP.data, ILAB.index, AP.blink);
            PP.data = ilabFilterBlinks(PP.data, AP.blink.list);
            fprintf('\tBlinks removed by pupil filter: %d\n', size(AP.blink.list.pupil,1))
            fprintf('\tBlinks removed by location filter: %d\n', size(AP.blink.list.loc,1))
            
            % CONVERT FROM ASL COORDINATES TO ILAB COORDINATES (640x480)
            ConvertToILABCoord('normal',true)
            
            % APPLY GAUSSIAN SMOOTHING KERNEL TO THE DATA
            for x = 1:size(PP.index,1)
                
                PP.data(PP.index(x,1):PP.index(x,2),1) = ...
                    ilabFilter(xfilter,1,PP.data(PP.index(x,1):PP.index(x,2),1));
                
                PP.data(PP.index(x,1):PP.index(x,2),2) = ...
                    ilabFilter(yfilter,1,PP.data(PP.index(x,1):PP.index(x,2),2));
                
                PP.data(PP.index(x,1):PP.index(x,2),4) = ...
                    ilabFilter(xfilter,1,PP.data(PP.index(x,1):PP.index(x,2),4));
                
            end
            
            
            % CALCULATE AND APPLY THE DRIFT CORRECTION TO THE TIMECOURSE DATA
            fprintf('\tCalculating drift correction...\n')
            CorrectDrift([320,230],160,50)
            
            try
                saccadesTable= ExtractSaccades(ILAB,AP,PP);
                if size(saccadesTable,1) < minSaccadeCount
                    fprintf('\tWARNING: Only %d saccades extracted from file!\n',size(saccadesTable,1) )
                else
                    fprintf('\tSaccades extracted from file: %d\n',size(saccadesTable,1) )
                end
            catch
                fprintf('\tWARNING: Failed to extract saccades!\n')
            end
            

            pixPerCm = 640/AP.screen.width;
            
            for i=1:size(PP.index,1)
                
                trialStartIndex = PP.index(i,1);
                trialEndIndex = PP.index(i,2);
                trialTargetIndex = PP.index(i,3);
                
                startCode = PP.data(trialStartIndex,3);
                targetCode = PP.data(trialTargetIndex,3);
                
                % Select the saccades associated with this trial
                % Select the first four columns
                % [Trial SaccadeNumber StartIndex EndIndex]
                % Start and End indices are relative to the start of the
                % trial
                if ~isempty(saccadesTable)
                    trialSaccades = saccadesTable(saccadesTable(:,1)==i,1:4);
                else
                    trialSaccades = [];
                end
                
                
                
                if ~isempty(trialSaccades)
                    
                    % Retrieve the information about this trial type
                    trialTypeSearch = arrayfun(@(x)find(x.startCode==startCode),trialTypes,'uniformoutput',false);
                    trialTypeIndex = find(cellfun(@(x)~isempty(x),trialTypeSearch));
                    trialInfo = trialTypes(trialTypeIndex);
                    
                    if ~isempty(trialInfo)
                        
                        
                        % Get the target information for this trial type
                        targetInfoSearch = arrayfun(@(x)find(x.targetCode==targetCode),trialInfo.location,'uniformoutput',false);
                        targetInfoIndex = find(cellfun(@(x)~isempty(x),targetInfoSearch));
                        targetInfo = trialInfo.location(targetInfoIndex);
                        targetInfo.location = targetInfo.location - [320,240];
                        % At what horizontal visual angle is the target located from center fix?
                        targetAngleH = atan((targetInfo.location(1)/pixPerCm)/AP.screen.distance);
                        % disp('---------------------------------')
                        % disp(['Target angle: ', num2str(targetAngleH * (180/pi)), 'degrees'])
                        % Convert saccade start and end indices to time in ms
                        % Add this information on as additional columns 5 and 6
                        % disp(ilabGetAcqIntvl)
                        trialSaccades = [trialSaccades,trialSaccades(:,[3,4]) * GetAcqIntvl];
                        
                        % Categorize the trial saccades in to three groups by examining the time
                        % in the trial during which they took place.
                        % 1) Encoding saccades
                        % 2) Presaccades (occur when the subject is supposed to be fixating)
                        % 3) Memory-guides saccades
                        encSaccadesIndex = (ceil(trialSaccades(:,5)) >= trialInfo.encodeTime(1) & ...
                            floor(trialSaccades(:,5)) <= trialInfo.encodeTime(2));
                        encSaccades = trialSaccades(encSaccadesIndex,:);
                        
                        encLatencyOffset = trialInfo.encodeTime(1);
                        encSaccades(:,[5,6]) =  encSaccades(:,[5,6]) - encLatencyOffset;
                        
                        preSaccadesIndex = (ceil(trialSaccades(:,5)) > trialInfo.encodeTime(2) & ...
                            floor(trialSaccades(:,5)) < trialInfo.maintenanceTime(1));
                        preSaccades = trialSaccades(preSaccadesIndex,:);
                        
                        memSaccadesIndex = (ceil(trialSaccades(:,5)) >= trialInfo.maintenanceTime(1) & ...
                            floor(trialSaccades(:,5)) <= trialInfo.maintenanceTime(2));
                        memSaccades = trialSaccades(memSaccadesIndex,:);
                        
                        memLatencyOffset = trialInfo.maintenanceTime(1);
                        memSaccades(:,[5,6]) = memSaccades(:,[5,6]) - memLatencyOffset;
                        
                        % Insert a column that reflects what type of saccade each one is
                        % Insert a 1 for encoding saccades, 2 for MGS, and 3 for presaccades
                        encMarker = zeros(size(encSaccades,1),1) + 1;
                        memMarker = zeros(size(memSaccades,1),1) + 2;
                        preMarker = zeros(size(preSaccades,1),1) + 3;
                        
                        encSaccades = [encSaccades(:,[1,2]),encMarker,encSaccades(:,3:end)];
                        memSaccades = [memSaccades(:,[1,2]),memMarker,memSaccades(:,3:end)];
                        preSaccades = [preSaccades(:,[1,2]),preMarker,preSaccades(:,3:end)];
                        
                        
                        % If there are more than 1 memory guided saccades, check to see
                        % if they occur close enough together to be considered a 'split'
                        % That is, the distance between the end of one saccade and the
                        % start of another is less than 67 ms
                        splitMarker = zeros(size(memSaccades,1),1);
                        if size(memSaccades,1) > 1
                            for j=1:size(memSaccades,1)-1
                                if memSaccades(j+1,4) - memSaccades(j,5) <=(67/GetAcqIntvl)
                                    splitMarker(j:j+1) = 1;
                                end
                            end
                        end
                        
                        encSaccades = [encSaccades(:,1:3), zeros(size(encSaccades,1),1),encSaccades(:,4:end)];
                        preSaccades = [preSaccades(:,1:3), zeros(size(preSaccades,1),1),preSaccades(:,4:end)];
                        memSaccades = [memSaccades(:,1:3), splitMarker,memSaccades(:,4:end)];
                        
                        % ONLY OUTPUT THE ENCODING AND MEMORY GUIDED
                        % SACCADES
                        %trialSaccades = [encSaccades;preSaccades;memSaccades];
                        trialSaccades = [encSaccades;memSaccades];
                        
                        
                        % At this point, the array trialSaccades has 8 columns:
                        % [ TrialNumber SaccadeNumber SaccadeType Split SaccadeStartSample SaccadeEndSample SaccadeStartTime SaccadeEndTime ]
                        
                        
                        % Build the final output table
                        for j=1:size(trialSaccades,1)
                            
                            trialNumber = trialSaccades(j,1);
                            saccadeNumber = trialSaccades(j,2);
                            saccadeType = trialSaccades(j,3);
                            saccadeSplit = trialSaccades(j,4);
                            saccadeStartIndexRel = trialSaccades(j,5);
                            saccadeEndIndexRel = trialSaccades(j,6);
                            saccadeStartTime = trialSaccades(j,7);
                            saccadeEndTime = trialSaccades(j,8);
                            saccadeLatency = GetAcqIntvl * saccadeStartIndexRel;
                            trialStartTime = (PP.index(i,1) - experimentStartIndex) * GetAcqIntvl;
                            saccadeStartIndexAbs = trialStartIndex + saccadeStartIndexRel - 1;
                            saccadeEndIndexAbs = trialStartIndex + saccadeEndIndexRel - 1;
                            
                            
                            % Get the saccade timecourse.  This will be used to get saccadic
                            % accuracy
                            saccadeTimeCourse = PP.data(saccadeStartIndexAbs:saccadeEndIndexAbs,[1,2]);
                            
                            % Calculate the accuracy in terms of pixels for this trial by
                            % comparing the last coordinate of the saccade timecourse to
                            % the target location
                            accuracyPix = saccadeTimeCourse(end,:)-[320,240];
                            
                            % disp(['Saccade angle: ', num2str((atan((accuracyPix(1)/pixPerCm)/AP.screen.distance)* (180/pi)))])
                            
                            accuracyAngle = abs(atan((accuracyPix(1)/pixPerCm)/AP.screen.distance)) - abs(targetAngleH);
                            
                            % Convert angle from radians to degrees
                            accuracyAngle = accuracyAngle * (180/pi);
                            
                            % disp(['Accuracy angle: ', num2str(accuracyAngle), ' degrees'])
                            
                            resultsEntry = [lunaid,          ...
                                age,             ...
                                sexid,           ...
                                visit,           ...
                                runNumber,       ...
                                trialNumber,     ...
                                startCode,       ...
                                saccadeNumber,   ...
                                saccadeType,     ...
                                saccadeSplit,    ...
                                saccadeStartTime,...
                                saccadeEndTime,  ...
                                accuracyPix,     ...
                                accuracyAngle    ...
                                trialStartTime   ...
                                targetCode,fileCreationTime];
                            
                            
                            results = [results; resultsEntry];
                            
                            
                        end
                    end
                    
                end
                
            end
            
            
            
            
        else   % Is missing start/target/stop codes
            fprintf('\tXDAT Error!\n')
        end    % Verify the existence of start/target/stop codes
    else
        fprintf('\tUnable to open file!\n')      
    end
    
    
end

    function [w, h] = GetILABCoord()
        %ILABGETILABCOORD Returns the size in pixels of the ILAB coordinate system
        %   [W, H] = ILABGETILABCOORD - Returns width & height of ILAB Coord System.
        %   First checks if a coordinate system has been loaded. If not then returns
        %   default values of 640 x 480, which were based on the size
        %   of a typical Macintosh screen at the time of original development.
        
        % Authors: Roger Ray, Darren Gitelman
        % $Id: ilabGetILABCoord.m 91 2010-06-08 16:39:25Z drg $
        
        
        if isfield(ILAB.coordSys,'screen')
            w = ILAB.coordSys.screen(1);
            h = ILAB.coordSys.screen(2);
        else
            w = 640;
            h = 480;
        end
        
    end

    function [ acqIntvl ] = GetAcqIntvl()
        %ILABGETACQINTVL Gets acquisition interval (ms)
        %   ACQINTVL = ILABGETAQINTVL returns the acquisition interval without having to
        %   return the entire ILAB structure.
        
        % __________________________________________________________________________
        
        % Authors: Roger Ray
        % $Id: ilabGetAcqIntvl.m 91 2010-06-08 16:39:25Z drg $
        
        acqIntvl = ILAB.acqIntvl;
        
    end

    function [startStopTargOK, index] = CreateIndex(serialCodes, trialCodes)
        
        iStart  = find(ismember(serialCodes, trialCodes.start));
        iStop   = find(ismember(serialCodes, trialCodes.end));
        iTarget = find(ismember(serialCodes, trialCodes.target));
        
        nStartCodes   = length(iStart);
        nStopCodes    = length(iStop);
        nTargetCodes  = length(iTarget);
        
        startStopTargOK = 0;
        index         = [];
        
        if nStartCodes == nStopCodes
            index = [iStart, iStop];
            if ~isempty(iTarget)
                if nTargetCodes == nStartCodes
                    index = [index, iTarget];
                    startStopTargOK = 1;
                else
                    index = [];
                    startStopTargOK = 0;
                end
            else
                index(:,3) = NaN;
                startStopTargOK = 1;
            end
        end
        
        return;
        
    end

    function MergeFixations()
        
        sampleRate = 60;  % Hz
        indicesToDelete = [];
        indicesToRemark = [];
        stopCodeUpdates = [];
        trialCount = 0;
        position = '';
        
        
        for q=1:size(ILAB.index,1)-1
            
            trial1StartIndex = ILAB.index(q,1);
            trial1TargetIndex = ILAB.index(q,3);
            trial1StopIndex = ILAB.index(q,2);
            trial1StartCode = ILAB.data(trial1StartIndex,3);
            trial1TargetCode = ILAB.data(trial1TargetIndex,3);
            
            trial2StartIndex = ILAB.index(q+1,1);
            trial2TargetIndex = ILAB.index(q+1,3);
            trial2StopIndex = ILAB.index(q+1,2);
            trial2StartCode = ILAB.data(trial2StartIndex,3);
            trial2TargetCode = ILAB.data(trial2TargetIndex,3);
            
            if (trial1StartCode ~=60 && trial2StartCode == 60 ) || ...
                    (trial1TargetCode ~=160 && trial2TargetCode ==160)
                % Entering Fixation Block
                update = [];
                update(1,1) = q+1;
                position = 'entering';
            elseif (trial1StartCode == 60 && trial2StartCode == 60) || ...
                    (trial1TargetCode == 160 && trial2TargetCode == 160)
                % Inside Fixation Block
                if isempty(position)
                    update = [];
                    update(1,1) = q+1;
                    position = 'entering';
                else
                    indicesToDelete = cat(2,indicesToDelete,q+1);
                    indicesToRemark = cat(2,indicesToRemark, [trial1StopIndex,trial2StartIndex,trial2TargetIndex]);
                    position ='inside';
                end
                
                if q+1 == size(ILAB.index,1)
                    
                    % Exiting Fixation Block
                    update(1,2) = trial2StopIndex;
                    stopCodeUpdates = cat(1,stopCodeUpdates,update);
                    position = 'exiting';
                end
                
                
                
            elseif (trial1StartCode ==60 && trial2StartCode ~=60) || ...
                    (trial1TargetCode == 160 && trial2TargetCode ~= 160)
                % Exiting Fixation Block
                update(1,2) = trial1StopIndex;
                stopCodeUpdates = cat(1,stopCodeUpdates,update);
                position = 'exiting';
                
            end
            
            
        end
        
        % Update the Stop Codes to reflect the collapsed fixation period length
        if ~isempty(stopCodeUpdates)
            for q=1:size(stopCodeUpdates,1)
                ILAB.index(stopCodeUpdates(q,1),2) = stopCodeUpdates(q,2);
            end
        end
        ILAB.data(indicesToRemark,3)= 0;
        ILAB.index(indicesToDelete,:) = [];
        
        
        % MGS Encode trials are missing the Start/Target/End codes for the first
        % fixation period.  Look at the MGS Encode EPRIME (ugh...) scripts under
        % disacq. The first fixation period is 6 seconds long, so we'll insert a
        % new first trial using the standard codes Start:60 Target:160 End:250
        % Get the index of the first trial, and move back 6 seconds, and insert the
        % codes
        
        trial1StartIndex = ILAB.index(1,1);
        trial1TargetIndex = ILAB.index(1,3);
        trial1StopIndex = ILAB.index(1,2);
        
        % Check to see if there are enough data points at the beginning to insert the
        % fixation period.  If not, the tester may have started the recording late...
        
        if trial1StartIndex >= 361
            
            newFixationStartIndex = trial1StartIndex - (sampleRate * 6);
            newFixationTargetIndex = (trial1StartIndex - (sampleRate * 6))+5;
            newFixationEndIndex = trial1StartIndex - 6;
            
            % Insert start code 6 seconds before
            ILAB.data(newFixationStartIndex,3) =  60;
            % Insert the target code a few samples after
            ILAB.data(newFixationTargetIndex,3) =  160;
            % Insert the end code a few samples before the start of the real first trial
            ILAB.data(newFixationEndIndex,3) =  250;
            % Update the index table to show the new trial
            ILAB.index  = cat(1,[newFixationStartIndex, newFixationEndIndex,newFixationTargetIndex] , ILAB.index);
            % Update the trial count for the new ILAB structure to reflect the new
            % count
            
        end
        
        % Update the trial count property
        ILAB.trials = size(ILAB.index,1);
        
        
    end

    function ConvertToILABCoord(type,zeroflag)
        % ILABABCOORD Converts eye tracker to standard screen coordinates and vice versa
        %   [dataout] = ILABabCoord(PP.data, type, zeroflag)
        %   ________________________________________________________
        %   PP.data  input ISCAN data matrix (n x 3)
        %   type    normal    eye tracker coordinates     -> computer screen coordinates
        %           inverse   computer screen coordinates -> eye tracker coordinates
        %
        %   zeroflag: if zeroflag == 1 then maintain (0,0) coord in PP.data
        %
        %   ILABabCoord takes a data matrix of eye positions in
        %   ISCAN coordinates and converts them to computer screen
        %   coordinates based on a data specific coordinate system
        %   Mapping was determined empirically by measuring both the
        %   Eye tracker screen and computer screen simultaneously. The
        %   ISCAN/ ASL screen DOES NOT map to the mac screen starting at 0,0.
        
        % Authors: Darren Gitelman
        % $Id: ILABabCoord.m 41 2010-06-07 00:01:25Z drg $
        
        % Get the coordinate system for the current dataset
        %-----------------------------------------------------------------------
        
        switch type
            
            case 'normal'
                PP.data = [((PP.data(:,1) * ILAB.coordSys.params.h(1)) + ILAB.coordSys.params.h(2)),...
                    ((PP.data(:,2) * ILAB.coordSys.params.v(1)) + ILAB.coordSys.params.v(2)),PP.data(:,3:end)];
                
            case 'inverse'
                PP.data = [((PP.data(:,1) + ILAB.coordSys.params.h(2)) / ILAB.coordSys.params.h(1)),...
                    ((PP.data(:,2) + ILAB.coordSys.params.v(2)) / ILAB.coordSys.params.v(1)),PP.data(:,3:end)];
                
        end
        
        % Force (0,0) coords in PP.data to map to (0,0) in dataout
        %-----------------------------------------------------------------------
        if zeroflag && ~isempty(PP.data)
            q = find(PP.data(:,1) ==0 & PP.data(:,2) == 0);
            PP.data(q,1:2) = zeros(size(q,1),2);
        end
        
        
        
        
    end

    function CorrectDrift( fixationCoords, fixationXDAT, minFixSamples  )
        % ILABGETDRIFTCORRECTEDPLOTPARMS
        % Generates a replacement for the PLOTPARMS PP.data structure that corrects
        % for linear drit in fixation.
        
        fixationIndex = [];
        driftCorrectionVectors = [];
        driftCorrection = [];
        minValidSamplePoints = minFixSamples;
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % BEGIN DRIFT CORRECTION
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Build a list of start and stop indices for the fixation trials and a list
        % of the fixation correction vectors at from each fixation trial
        for m=1:size(PP.index,1)
            
            % index of the onset of the fixation cue
            targetIndex = PP.index(m,3);
            % index of the end of the fixation trial
            endIndex = PP.index(m,2);
            % index of the mid point in the fixation period
            %middleIndex = targetIndex + floor((endIndex - targetIndex)/2);
            middleIndex = [];
            
            
            % Check to see if the trial is a fixation trial by examining the target
            % XDAT code.  If so, estimate the fixation point vector.  This will be
            % used to correct for fixation drift.
            
            if PP.data(targetIndex,3) == fixationXDAT
                
                % Assume that the subject at the instant before the cue onset is
                % looking at fixation, but it is offset by some amount from true
                % fixation.
                
                % If the fixation period has a trial that follows it, get the index
                % of the
                
                % Start-----------------------------Fix-------------------End---------Start-----------------CueStart------------End
                %                                    |_________________________________________________________|
                %                                        |                               |________________|
                % Valid range of PP.data from which      |                                  |
                % to estimate fixation offset for________|                                  |
                % this trial                                                                |
                %                                                                           |
                %                                                                           |
                % The points samples closes to the                                          |
                % onset of the cue are the best                                             |
                % estimators of the fixation drift                                          |
                % for a trial.  Fixation carries over                                       |
                % into the first 1300 ms of a trial. So                                     |
                % the PP.data points we are interested in                                      |
                % extracting for our estimate are here:   __________________________________|
                %
                % Attempt to extract 50 valid samples from
                % the time period closest to 100 ms before
                % cue onset
                % 1400 ms = 84 samples
                
                trialFixRange = 84;
                
                
                if m < size(PP.index,1)
                    
                    nextTrialStartIndex = PP.index(m+1,1);
                    maxIndex = nextTrialStartIndex + trialFixRange;
                    fixationRange = PP.data((targetIndex):maxIndex,1:2);
                    validSamples = [];
                    
                    % Work backwards and extract 50 valid sample points.  Valid sample
                    % point that will be used to estimate the fixation drift offset
                    % will no non Nan entries whose instantaneous velocity is less than
                    % some threshold value
                    for n=size(fixationRange,1):-1:2
                        
                        if ~isnan(fixationRange(n,1)) && ~isnan(fixationRange(n,2))
                            
                            x1 = fixationRange(n-1,1) - 320;
                            x2 = fixationRange(n,1) - 320;
                            y1 = fixationRange(n-1,2) - 240;
                            y2 = fixationRange(n,2) - 240;
                            
                            vx = atan(x1/AP.screen.distance) - atan(x2/AP.screen.distance);
                            vy = atan(y1/AP.screen.distance) - atan(y2/AP.screen.distance);
                            
                            v = sqrt(vx^2 + vy^2) * (180/pi);
                            
                            if v < AP.saccade.velThresh
                                validSamples = [validSamples; fixationRange(n,1:2)];
                            end
                            
                        end
                        
                        % Exit loop if we have found the minimum number valid points
                        if size(validSamples,1) == minValidSamplePoints
                            break
                        end
                        
                    end
                    
                    if size(validSamples,1) >= minValidSamplePoints
                        
                        middleIndex = maxIndex - floor(n/2);
                        
                        % Estimate the fixation vector
                        % Winsorize the PP.data before averaging
                        for n = 1:size(validSamples,2)
                            validSamples(:,n) = winsor(validSamples(:,n),[20,80]);
                        end
                        
                        % Get the average of the Winsorized X and Y coordinate during the
                        % fixation range
                        validSamples = nanmean(validSamples,1);
                        
                        
                        driftCorrectionVectors = cat(1,driftCorrectionVectors,[middleIndex,fixationCoords - validSamples]);
                        
                    else
                        % Not enough valid sample points to estimate fixation correction
                        
                        middleIndex = maxIndex - floor(minValidSamplePoints/2);
                        
                        if size(driftCorrectionVectors,1) > 0
                            % Use the previously calculated correction if one exisits
                            prevCorrection = driftCorrectionVectors(size(driftCorrectionVectors,1),:);
                            correction = [middleIndex,prevCorrection(1,2:3)];
                            driftCorrectionVectors = cat(1, driftCorrectionVectors,correction);
                        else
                            % Do not apply a correction
                            driftCorrectionVectors = cat(1, driftCorrectionVectors, [middleIndex,0,0]);
                        end
                        
                    end
                    
                end
                
            end
            
        end
        
        
        
        % Create the correction for the sample points that precede the first
        % fixation period.  Assume that initially no fixation drift has occurred.
        IDX1 = 1;
        IDX2 = driftCorrectionVectors(1,1);
        CV1 = [0,0];
        CV2 = driftCorrectionVectors(1,[2,3]);
        length = IDX2-IDX1+1;
        driftCorrection = vectorTimeWarp(CV1,CV2,length);
        
        % Generate the corrections vectors for each time point of the raw PP.data and
        % concatenate it to the correction generated above.
        for m=1:size(driftCorrectionVectors,1)-1
            
            size(driftCorrection,1);
            IDX1 = driftCorrectionVectors(m,1);
            IDX2 = driftCorrectionVectors(m+1,1);
            CV1 = driftCorrectionVectors(m,[2,3]);
            CV2 = driftCorrectionVectors(m+1,[2,3]);
            length = IDX2-IDX1;
            driftCorrection = cat(1,driftCorrection, vectorTimeWarp(CV1,CV2,length));
            
        end
        
        % Create the correction for the sample points that follow the last fixation
        % period.  Assume that no fixation drift has occurred since the last
        % fixation drift measurment and concatenate that correction vector to the
        % end of the drift correction matrix
        
        IDX1 = driftCorrectionVectors(size(driftCorrectionVectors,1),1);
        IDX2 = size(PP.data,1);
        CV2 = driftCorrectionVectors(size(driftCorrectionVectors,1),[2,3]);
        length= IDX2-IDX1;
        tailCorrection = zeros(length,2);
        tailCorrection(:,1) = CV2(1);
        tailCorrection(:,2) = CV2(2);
        driftCorrection = cat(1,driftCorrection,tailCorrection);
        
        
        % Apply the correction to the PP.data
        PP.data(:,1) = PP.data(:,1) + driftCorrection(:,1);
        PP.data(:,2) = PP.data(:,2) + driftCorrection(:,2);
        
    end

    function [ analysis ] = AnalyzeSaccades()
        
        % constrainedIndex = MkConstrainedTrialList(ILAB.index,AP.time,AP.targets);
        % saccadesTable = MkSaccadeList();
        saccadesTable = ExtractSaccades(ILAB, AP, PP, 30)
        saccadeInfo = [];
        
        pixPerCm = 640/AP.screen.width;
        
        % Loop through each trial and examine the saccades with which it is associated
        for n=1:size(PP.index,1)
            
            trialStartIndex = PP.index(n,1);
            trialEndIndex = PP.index(n,2);
            trialTargetIndex = PP.index(n,3);
            
            startCode = PP.data(trialStartIndex,3);
            targetCode = PP.data(trialTargetIndex,3);
            
            % Select the saccades associated with this trial
            % Select the first four columns
            % [Trial SaccadeNumber StartIndex EndIndex]
            % Start and End indices are relative to the start of the trial
            trialSaccades = saccadesTable(saccadesTable(:,1)==n,1:4);
            
            if ~isempty(trialSaccades)
                
                % Retrieve the information about this trial type
                trialTypeSearch = arrayfun(@(x)find(x.startCode==startCode),trialTypes,'uniformoutput',false);
                trialTypeIndex = find(cellfun(@(x)~isempty(x),trialTypeSearch));
                trialInfo = trialTypes(trialTypeIndex);
                
                if ~isempty(trialInfo)
                    
                    % Get the target information for this trial type
                    targetInfoSearch = arrayfun(@(x)find(x.targetCode==targetCode),trialInfo.location,'uniformoutput',false);
                    targetInfoIndex = find(cellfun(@(x)~isempty(x),targetInfoSearch));
                    targetInfo = trialInfo.location(targetInfoIndex);
                    
                    % At what horizontal visual angle is the target located from center fix?
                    % Convert to <0,0| centered coordinates
                    targetLoc = targetInfo.location - [320,240];
                    targetAngleH = atan((targetLoc(1)/pixPerCm)/AP.screen.distance)
                    
                    % Convert saccade start and end indices to time in ms
                    % Add this information on as additional columns 5 and 6
                    trialSaccades = [trialSaccades,trialSaccades(:,[3,4]) * GetAcqIntvl];
                    
                    % Categorize the trial saccades in to three groups by examining the time
                    % in the trial during which they took place.
                    % 1) Encoding saccades
                    % 2) Presaccades (occur when the subject is supposed to be fixating)
                    % 3) Memory-guides saccades
                    encSaccadesIndex = (ceil(trialSaccades(:,5)) >= trialInfo.encodeTime(1) & ...
                        floor(trialSaccades(:,5)) <= trialInfo.encodeTime(2));
                    encSaccades = trialSaccades(encSaccadesIndex,:);
                    
                    preSaccadesIndex = (ceil(trialSaccades(:,5)) > trialInfo.encodeTime(2) & ...
                        floor(trialSaccades(:,5)) < trialInfo.maintenanceTime(1));
                    preSaccades = trialSaccades(preSaccadesIndex,:);
                    
                    memSaccadesIndex = (ceil(trialSaccades(:,5)) >= trialInfo.maintenanceTime(1) & ...
                        floor(trialSaccades(:,5)) <= trialInfo.maintenanceTime(2));
                    memSaccades = trialSaccades(memSaccadesIndex,:);
                    
                    % Insert a column that reflects what type of saccade each one is
                    % Insert a 1 for encoding saccades, 2 for MGS, and 3 for presaccades
                    encMarker = zeros(size(encSaccades,1),1) + 1;
                    memMarker = zeros(size(memSaccades,1),1) + 2;
                    preMarker = zeros(size(preSaccades,1),1) + 3;
                    
                    encSaccades = [encSaccades(:,[1,2]),encMarker,encSaccades(:,3:end)];
                    memSaccades = [memSaccades(:,[1,2]),memMarker,memSaccades(:,3:end)];
                    preSaccades = [preSaccades(:,[1,2]),preMarker,preSaccades(:,3:end)];
                    
                    
                    % If there are more than 1 memory guided saccades, check to see
                    % if they occur close enough together to be considered a 'split'
                    % That is, the distance between the end of one saccade and the
                    % start of another is less than 67 ms
                    splitMarker = zeros(size(memSaccades,1),1);
                    if size(memSaccades,1) > 1
                        for j=1:size(memSaccades,1)-1
                            if memSaccades(j+1,4) - memSaccades(j,5) <=(67/GetAcqIntvl)
                                splitMarker(j:j+1) = 1;
                            end
                        end
                    end
                    
                    encSaccades = [encSaccades(:,1:3), zeros(size(encSaccades,1),1),encSaccades(:,4:end)];
                    preSaccades = [preSaccades(:,1:3), zeros(size(preSaccades,1),1),preSaccades(:,4:end)];
                    memSaccades = [memSaccades(:,1:3), splitMarker,memSaccades(:,4:end)];
                    
                    trialSaccades = [encSaccades;preSaccades;memSaccades];
                    
                    % At this point, the array trialSaccades has 8 columns:
                    % [ TrialNumber SaccadeNumber SaccadeType Split SaccadeStartSample SaccadeEndSample SaccadeStartTime SaccadeEndTime ]
                    
                    
                    % Build the final output table
                    for j=1:size(trialSaccades,1)
                        
                        trialNumber = trialSaccades(j,1);
                        saccadeNumber = trialSaccades(j,2);
                        saccadeType = trialSaccades(j,3);
                        saccadeSplit = trialSaccades(j,4);
                        saccadeStartIndexRel = trialSaccades(j,5);
                        saccadeEndIndexRel = trialSaccades(j,6);
                        saccadeStartTime = trialSaccades(j,7);
                        saccadeEndTime = trialSaccades(j,8);
                        saccadeLatency = ilabGetAcqIntvl * saccadeStartIndexRel;
                        
                        saccadeStartIndexAbs = trialStartIndex + saccadeStartIndexRel - 1;
                        saccadeEndIndexAbs = trialStartIndex + saccadeEndIndexRel - 1;
                        
                        
                        % Get the saccade timecourse.  This will be used to get saccadic
                        % accuracy
                        saccadeTimeCourse = PP.data(saccadeStartIndexAbs:saccadeEndIndexAbs,[1,2]);
                        
                        % Calculate the accuracy in terms of pixels for this trial by
                        % comparing the last coordinate of the saccade timecourse to
                        % the target location
                        accuracyPix = saccadeTimeCourse(end,:);
                        
                        % Convert to a <0,0| centered coordinate system
                        accuracyPix = accuracyPix - [320,230];
                        
                        
                        accuracyAngle = abs(targetAngleH) - abs(atan((accuracyPix(1)/pixPerCm)/AP.screen.distance));
                        
                        % Convert angle from radians to degrees
                        accuracyAngle = accuracyAngle * (180/pi);
                        
                        saccadeInfo = [saccadeInfo; trialNumber startCode targetCode saccadeNumber saccadeType saccadeSplit saccadeStartTime saccadeEndTime accuracyPix accuracyAngle  ];
                        
                        
                    end
                    
                end
            end
            
        end
        
        
        analysis = saccadeInfo;
        
    end

    function [ saccadeList ] = MkSaccadeList()
        % ILABMKSACCADELIST Creates the saccade list
        %    SACCADELIST = ILABMKSACCADELIST(saccadeList, layoutType) -- creates a list of
        %    saccades and their parameters.
        %    The saccade identification algorithm is based on
        %    Fischer, B., Biscaldi, M., and Otto, P.1993.  Saccadic eye movements of
        %    dyslexic adults.  Neuropsychologia, Vol. 31, No 9, pp. 887-906.
        %
        %    This algorithm will be fooled if there is a lot of variability
        %    to the data. It does not check that all points in the saccade
        %    have a velocity greater than the critical velocity
        %
        %    saccadeList col value
        %              1   trial number
        %              2   saccade count
        %              3   saccade start (ms) from trial start
        %              4   saccade end   (ms)
        %              5   peak saccade velocity  (deg/s)
        %              6   mean saccade velocity  (deg/s)
        %              7   saccadic reaction time (time from target(or start) to vCutoff vel)
        %              8   time-to-peak velocity  (time from target(or start) to vPeak vel)
        %              9   saccade amplitude (deg) ( vMean * saccade duration)
        %              10  percentage of invalid pts in the saccade
        
        
        % Authors: Roger Ray, Darren Gitelman
        % $Id: ilabMkSaccadeList.m 93 2010-06-08 16:40:30Z drg $
        
        
        saccadeList = [];
        % -----------------------------------------
        % Get acquisition interval
        % -----------------------------------------
        acqIntvl = GetAcqIntvl;
        
        % --------------------------------------------------------------------
        %  Find threshold (critical) velocity in ILAB pixels/acq_interval: vCrit
        %  Find search window width in samples: wSamples
        % -----------------------------------------------------------------
        [wILAB, hILAB] = GetILABCoord;
        factor = 50;
        pixPerDegH = (wILAB/factor)/(atan((AP.screen.width/factor)/AP.screen.distance) * 180/pi);
        pixPerDegV = (hILAB/factor)/(atan((AP.screen.height/factor)/AP.screen.distance) * 180/pi);
        
        % assumes the horizontal and vertical pixels per degree are equal
        % needs to be updated.
        vCrit = pixPerDegH * AP.saccade.velThresh / ILAB.acqRate;
        
        wSamples = round(AP.saccade.window/acqIntvl);
        if wSamples < 1; wSamples = 1; end;
        
        trials = size(PP.index,1);
        
        % -----------------------------------------
        %  Is there a fixation ROI supplied?
        % -----------------------------------------
        isFixROI = ~isempty(AP.saccade.ROI.name);
        
        % -----------------------------------------
        %  min duration of ROI fixation (in samples)
        % -----------------------------------------
        
        fLen = round(AP.saccade.minFixDuration/acqIntvl);
        
        % -----------------------------------------
        %  Loop over the trials
        % -----------------------------------------
        
        for i = 1:trials
            
            
            t1 = PP.index(i,1);
            t2 = PP.index(i,2);
            
            trialx = PP.data(t1:t2,1);
            trialy = PP.data(t1:t2,2);
            
            if AP.saccade.onset == 1
                % calculate w.r.t. trial start
                tT = 1;
            else
                % calculate w.r.t. target start
                tT = PP.index(i,3) - t1 +1;    % target index (rel. to trial start)
            end;
            
            % ------------------------------------------------------------------
            % Determine if gaze maintained in specified ROI (if any) for the
            %  minimum specified duration.
            % ------------------------------------------------------------------
            
            if isFixROI
                
                %  Find search range g1:g2 for gaze maintenance.
                %  Start at target, if there is one.  Otherwise start at beginning of trial
                
                g1 = tT;
                g2 = tT + fLen-1;         % minus 1 time point to make sure fixation
                % is within fLen time points of the actual
                % trial start at t=0
                if g2 > t2;  g2 = t2; end;
                
                % Search only valid sample pts (finite values, exclude (NaN, NaN))
                
                g = find(isfinite(trialx(g1:g2)));
                
                
                % Test if all finite elements in ROI
                if ~all(inpolygon(trialx(g), trialy(g), AP.saccade.ROI.x, AP.saccade.ROI.y));
                    inROI = 0;
                else
                    inROI = 1;
                end;
                
            else
                inROI = 1;
            end;
            
            
            
            %  ---------------------------------------------------------------------
            %  Continue to process if fixation maintained in designated ROI, if any.
            %  ---------------------------------------------------------------------
            if inROI
                
                %  --------------------------------------------------------
                %  Find the absolute velocity vector (ILAB pixels/sample)
                %  --------------------------------------------------------
                vx = [0; diff(trialx)];
                vy = [0; diff(trialy)];
                
                vabs = sqrt(vx.^2 + vy.^2);
                
                % ------------------- plotting during debugging ---------------------
                %       figure;
                %       vRange = acqIntvl*(1:length(vabs));        % range of vabs in ms.
                %       plot(vRange/1000, vabs, 'k');
                %       hold on;
                %       plot(acqIntvl*[1 length(vabs)]./1000, [ vCrit vCrit], 'b--');
                %       drawnow;
                % ------------------- plotting during debugging ---------------------
                
                iCrit = find(vabs >= vCrit);
                
                %  Search for saccades by looking through list of pts where vabs exceeds the
                %  specified critical velocity.
                
                %  Find the next available pt in the critcal velocity list
                %  Limit the search to the specified window width (saccade.window <-> wSamples) (i1:i2)
                %  Find first occurence of vPeak (whose index is iPeak)
                %  Find the cutoff velocity from vPeak * saccade.pctPeak/100
                %  Find extent of saccade working back & fwd from vPeak to vCutoff (s1:s2)
                %  Verify that duration of saccade satifies saccade.minSaccDuration
                %  Calculate remainder of saccade parameters.
                %  Calculate the distance from mean vel * duration to avoid
                %   possible invalid points at begin and/or end of saccade.
                %   (Trajectory is assumed to be straight line during saccade.)
                %  Add saccade info to list
                %  Advance the ptr in iCrit beyond identified saccade.
                %  __________________________________________________________________
                
                if ~isempty(iCrit)
                    
                    k    = 1;  % index for iCrit
                    scnt = 0;  % counter for saccades
                    s2   = 1;  % initialize end of last saccade to beginning of trial
                    
                    while k <= length(iCrit)
                        
                        % First bound for peak search
                        i1 = iCrit(k);
                        
                        % Second bound for peak search
                        % Wsamples provides the maximum window for finding the peak. If
                        % too wide then saccades will be merged.
                        i2 = i1 + wSamples;
                        % Set the second bound to the smaller of the
                        % window or the end of the saccade index, so
                        % we don't go beyond the end of the trial
                        i2 = min(i2, length(vabs));
                        
                        % The peak is the maximum in the bounds
                        vPeak = max(vabs(i1:i2));
                        
                        % and get the peaks index
                        iPeak = i1 + min(find(vabs(i1:i2) == vPeak)) - 1;  % first maximum
                        
                        % the saccade limits are defined as a percent of the peak
                        vCutoff = vPeak * AP.saccade.pctPeak/100;
                        
                        s1 = min(find(vabs(iPeak:-1:s2) <= vCutoff)); % search back
                        s1 = iPeak - s1 + 1;
                        
                        s2 = min(find(vabs(iPeak:end) <= vCutoff));    % search fwd
                        if isempty(s2)
                            s2 = length(vabs);
                        else
                            s2 = iPeak + s2 - 1;
                        end;
                        
                        ts1 = s1 * acqIntvl;  %  saccade start time (ms) from trial start
                        ts2 = s2 * acqIntvl;  %  saccade   end time
                        
                        if ( (ts2-ts1) > AP.saccade.minSaccDuration)
                            
                            
                            % pct of invalid vabs pts in saccade
                            % There are more invalid pts in the vabs vector than in trialx
                            
                            iNaN = find(~isfinite(vabs(s1:s2)));
                            pctInvalid=(length(iNaN)/(s2-s1+1))*100;
                            
                            iV = find(isfinite(vabs(s1:s2)));
                            iV = s1 + iV - 1;
                            if ~isempty(iV)
                                vMean = mean(vabs(iV));            % mean velocity (valid pts only)
                            else
                                vMean = NaN;
                            end;
                            sRT = (s1-tT+1)* acqIntvl;        % saccadic reaction time (ms)
                            ttP = (iPeak-tT+1)* acqIntvl;     % time to peak  (ms)
                            
                            % --------------- plotting during debugging ------------------
                            %
                            %      disp(sprintf('Trial %d  Saccade st: %.2f end: %.2f dur: %.1f ms vPk = %.1f vAvg = %.1f Inv = %.0f',...
                            %      i, ts1/1000, ts2/1000, ts2-ts1, vPeak, vMean, pctInvalid));
                            %
                            %      sRange = (s1:s2) * acqIntvl;
                            %      plot(sRange/1000, vabs(s1:s2), 'r');
                            %      plot(iPeak*acqIntvl/1000, vabs(iPeak), 'ro');  % vPeak where search started
                            %
                            %      plot([s1 s2]*acqIntvl/1000, [vCutoff vCutoff], 'r:');
                            %      plot(ts1/1000, vCutoff, 'r^');
                            %      plot(ts2/1000, vCutoff, 'r^');
                            %      drawnow
                            % --------------- plotting during debugging ----------------
                            
                            vPeak = vPeak*ILAB.acqRate/pixPerDegH; %  convert to deg/s
                            vMean = vMean*ILAB.acqRate/pixPerDegH; %  convert to deg/s
                            
                            dSac = vMean * (ts2 - ts1) / 1000; % distance travelled (deg)
                            %     x1 = trialx(s1);  x2 = trialx(s2);
                            %     y1 = trialy(s1);  y2 = trialy(s2);
                            %     dist = sqrt((x2-x1)^2 + (y2-y1)^2)/pixPerDeg;
                            %     disp(sprintf('Trial %d dist %.1f %.1f\n', i, dSac, dist));
                            
                            % advance saccade count
                            scnt = scnt + 1;
                            
                            % The values in saccadeList are
                            % trial# saccade# start_of_saccade end_of_saccade peak_velocity mean_velocity saccade_RT time_to_peak distance_travelled pct_invalid_points
                            % NOTE: start_of_saccade and end_of_saccade are indices
                            % into the data list. These indices must be converted
                            % to times in the saccade table.
                            saccadeList = [saccadeList; i scnt s1 s2 vPeak vMean sRT,...
                                ttP dSac pctInvalid];
                            
                            k = min(find(iCrit > s2));
                        else
                            k = k + 1;    % minSaccDuration not achieved.
                        end;          % endif minSaccDuration
                        
                    end;  % endwhile
                    
                    
                end;  % endif ~isempty(iCrit)
                
            end;  % endif inROI
            
        end;   % end loop over trials
        
    end

    function [ PP ] = MGSEncodeDefaultPlotParms()
        %ILABDEFAULTPLOTPARMS Returns the default PLOTPARMS parameters
        %    PP = ILABDEFAULTPLOTPARMS returns the default plotparms
        %    parameters. Users can edit this file to change the defaults.
        %    The plotParms data structure contains the information needed for
        %    displaying plots and access to plot objects.
        %
        %   NOTE: Always make a backup of the original file before messing
        %   with it. Some of the parameters such as tags for GUI objects are
        %   very specific and you may cause errors by changing them.
        %
        % --------------------------------------------------------
        %  AXES FIELD
        % --------------------------------------------------------
        %  axes.IMG_TAG         Tag for image plotting axis.
        %                       'BkgndImgAxes'
        %  axes.PCA_TAG         Tag for plot control area axis.
        %                       'PlotCtlAxes'
        %  axes.CPA_TAG         Tag for coordinate plot axis
        %                       (Main plot area) 'CoordPlotAxes'
        %  axes.APA_TAG         Tag for auxillary plot axis.
        %                       'AuxiliaryPlotAxes'
        %  axes.XYPLOT_TAG      Tag(s) for upper time plot contains either
        %                       'XTimePlotAxis' & 'YTimePlotAxis' or just
        %                       'XTimePlotAxis' alone.
        %  axes.PUPILPLOT_TAG   Tag for lower time plot is either empty or contains
        %                       'PupilPlotAxis'
        % --------------------------------------------------------
        %
        %
        % --------------------------------------------------------
        %  DATA
        % --------------------------------------------------------
        %  Data     Data converted to proper computer screen coordinates based
        %           on the ILAB.coordSys structure.
        %  index    Index to transformed data.
        % --------------------------------------------------------
        %
        %
        % --------------------------------------------------------
        %  PLOT COORDINATES
        % --------------------------------------------------------
        %  coordGrid.axis       1 (1=matrix [0,0 upper left], 2=coordinate [0,0 lower left)
        %  coordGrid.axisUnits  coord (coord=pixel units, deg=degree units)
        %  coordGrid.degOrigin  center of plot when shhown in degrees
        %  coordGrid.show       off (off=hide axis units, on=show axis units)
        %  coordGrid.visible    off (off=hide grid, on=show grid)
        % --------------------------------------------------------
        %
        %
        % --------------------------------------------------------
        %  FIXATIONS
        % --------------------------------------------------------
        %  A circle is drawn for each fixation. The radius of the circle is
        %  proportional to the length of the fixation.  The size is scaled
        %  to the maximum length fixation,
        %  i.e.  circleSz = fix.maxCircleSz * (fixationLength/fix.maxDuration)
        %
        %  fix.maxduration      maximum duration (msecs) of fixation used for
        %                       plotting relative size of fixation circles.
        %  fix.maxCircleSz      maximum size of circle corresponding to maximum
        %                       duration
        %  fix.show             0 (0=hide fixations, 1=show fixations)
        % --------------------------------------------------------
        %
        %
        % --------------------------------------------------------
        %  BACKGROUND IMAGES
        % --------------------------------------------------------
        %  image.files.fname     full filename of background image
        %  image.files.sfname    short filename of background image for display
        %  image.files.trial     trial to display images
        %  image.files.start     start time to show image
        %  image.files.duration  duration of image display
        %  image.pathpref        1 (1=relative path, 2=absolute path)
        %  image.version         version of stimulus structure
        %  image.loaded          index into image structure for each image
        %  image.handle          handle of displayed image
        %  image.show            0 (0=hide, 1=show image)
        % --------------------------------------------------------
        %
        %
        % --------------------------------------------------------
        %  FILTERCACHE
        % --------------------------------------------------------
        %  filtercache.type
        %  filtercache.params
        %  filtercache.colidx
        %  filtercache.data
        % --------------------------------------------------------
        %
        %
        % --------------------------------------------------------
        %  DISPLAY PARAMETERS
        % --------------------------------------------------------
        %  pllotSpeedConst    0.002 (Multiplier for how long to delay between each point
        %                     plotted. This is calculated by the formula
        %                     PP.plotSpeedConst*(10-speed)^2)
        %
        %  pupil              0 (0=hide, 1=show pupil data)
        %  relMovmnt          0 (0=hide, 1=show relative movement plot)
        %  scanPath           1 (0=hide, 1=show scan path plot)
        %  showROI            0 (0=hide, 1=show ROIs) [first=original,
        %                                              second=dynamic]
        %  segPlot.colors     [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 1 1 1]
        %                     'rgbcmykw' (order of colors)
        %  segPlot.tMinMax    plotting by time
        %  segPlot.pctMinMax  plotting by percent of trial
        %  segPlot.method     1 (1=time plot, 2=percent plot)
        %  segPlot.show       0 (0=hide, 1=show segmented plot)
        %  showTime           show trials constrained by time
        %  showVel            show velocity plot (saccades)
        %  speed              speed of display
        %  trialList          list of trials to show
        % --------------------------------------------------------
        
        % Authors: Darren Gitelman
        % $Id: ilabDefaultPlotParms.m 147 2010-07-07 14:06:23Z drg $
        
        %  AXES FIELDS
        % --------------------------------------------------------
        axes = [];
        axes.IMG_TAG       = 'BkgndImgAxes';
        axes.PCA_TAG       = 'PlotCtlAxes';
        axes.CPA_TAG       = 'CoordPlotAxes';
        axes.APA_TAG       = 'AuxiliaryPlotAxes';
        axes.XYPLOT_TAG    = ' ';
        axes.PUPILPLOT_TAG = ' ';
        % Matlab won't create an empty cell if the field doesn't already
        % exist. Hence now make the empty scalar an empty cell.
        axes.XYPLOT_TAG    = {' '};
        
        
        %  COORDGRID FIELDS
        % --------------------------------------------------------
        % The plot parameters and coordinate system should be based on
        % the loaded dataset. However, when ILAB starts there is no
        % loaded dataset, so this defaults to 640 x 480 through
        % ilabGetILABCoord
        % --------------------------------------------------------
        if isfield(ILAB.coordSys,'screen')
            wILAB = ILAB.coordSys.screen(1);
            hILAB = ILAB.coordSys.screen(2);
        else
            wILAB = 640;
            hILAB = 480;
        end
        coordGrid            =  [];
        coordGrid.axis       =  1;
        coordGrid.axisUnits  = 'coord';
        coordGrid.degOrigin  = [wILAB/2 hILAB/2];
        coordGrid.show       = 'off';
        coordGrid.visible    = 'off';
        
        
        %  DATA FIELDS
        % --------------------------------------------------------
        data    = [];
        index   = [];
        
        
        %  FIXATION PLOT FIELDS
        % --------------------------------------------------------
        fix = [];
        fix.maxDuration  = 2000;
        fix.maxCircleSz  = 240;
        fix.show         = 0;
        
        
        %  FILES FIELDS (PART OF IMAGE FIELD)
        % --------------------------------------------------------
        files = [];
        files.fname     = '';
        files.sfname    = '';
        files.trial     = '';
        files.start     = '';
        files.duration  = '';
        
        %  IMAGE FIELDS
        % --------------------------------------------------------
        image = [];
        image.files     = files;
        image.pathpref  = 0;
        image.version   = '';
        image.loaded    = 0;
        image.handle    = [];
        image.show      = 0;
        
        
        %  FILTERCACHE FIELDS
        % --------------------------------------------------------
        filtercache = [];
        filtercache.type   = '';
        filtercache.params = [];
        filtercache.colidx = 0;
        filtercache.data   = [];
        % replicate filtercache 3 times. (Not using repmat for simplicity)
        filtercache(1:3)   = filtercache;
        
        
        %  PLOTSPEED FIELDS
        % --------------------------------------------------------
        plotSpeedConst = 0.002;
        
        
        %  SEGMENTED PLOT FIELDS
        % --------------------------------------------------------
        segPlot = [];
        segPlot.colors    = [1 0 0; 0 1 0; 0 0 1; 0 1 1; 1 0 1; 1 1 0; 0 0 0; 1 1 1];
        segPlot.tMinMax   = zeros(8,2);
        segPlot.pctMinMax = zeros(8,2);
        segPlot.method    = 1;
        segPlot.show      = 0;
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        PP = [];
        PP.axes           = axes;
        PP.coordGrid      = coordGrid;
        PP.data           = data;
        PP.index          = index;
        PP.fix            = fix;
        PP.image          = image;
        PP.filtercache    = filtercache;
        PP.plotSpeedConst = 0.002;
        PP.pupil          = 0;
        PP.relMovmnt      = 0;
        PP.scanPath       = 1;
        PP.segPlot        = segPlot;
        PP.showROI        = [0 0];
        PP.showTime       = 0;
        PP.showVel        = 0;
        PP.speed          = 10;
        PP.trialList      = [];
        
    end

    function [ idx ] = MkConstrainedTrialList(Iin,timeCon,targetFlag)
        %ILABMKCONSTRAINEDTRIALLIST Restricts data based on a time index.
        %   IDX = ILABMKCONSTRAINEDTRIALLILIST(Iin,AP) sets up a timing index to the
        %   data for calculations. The timing index itself comes from other calculations.
        %   Timing constraints can be created through fixation, ROI, saccade and gaze calculations.
        %   For example if only the first 500 msec of a 1000 msec trial is analyzed for fixations
        %   then just that 500 msec can be displayed by clicking the time checkbox
        %   in the main window.
        %
        %   The output index may then be applied to the data. A returned value of
        %   -1 indicates an error has occurred.
        
        % Authors: Darren Gitelman, Roger Ray
        % $Id: ilabMkConstrainedTrialList.m 88 2010-06-07 01:29:46Z drg $
        
        tDlg = 'TRIAL CONSTRAINT ERROR';
        idx  = -1;
        
        % Must have both inputs to proceed
        if nargin < 2
            errordlg('Must provide both index and AnalysisParms as input to ilabMkConstrainedTrialList.',tDlg);
            return
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %  VALIDATE PARAMETER SETTINGS
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        [nTrials cols] = size(Iin);
        
        % exit if expt type does not use targets and user has requested a
        % calculation which depends on targets
        
        hErr=[];
        if targetFlag && (timeCon.startMark == 3 || timeCon.endMark == 3)
            msg = {'Cannot perform the requested calculation.';...
                'No target information available for calculation.'};
            hErr = errordlg(msg, tDlg, 'modal');
        end
        
        %  Check if validation fails and return empty index.
        %  =============================================================================
        
        if (isnumeric(hErr) & hErr > 0 ) | strcmpi(hErr,'yes')
            idx = -1;
            %    AP.index = idx;
            %    ilabSetAnalysisParms(AP);
            return
        end
        
        
        % Convert the analysis offset intervals (ms) into index displacements.
        % ____________________________________________________________________
        
        acqIntvl = GetAcqIntvl;
        
        dIS = round(timeCon.startIntvl/acqIntvl);
        dIE = round(timeCon.endIntvl/acqIntvl);
        
        idx = zeros(nTrials, cols);
        
        % constrained trial start
        % -------------------------------
        switch timeCon.startMark
            
            case 1, idx(:,1) = Iin(:,1) + dIS;
            case 2, idx(:,1) = Iin(:,2) - dIS;
            case 3, idx(:,1) = Iin(:,3) + dIS;
                
        end;
        
        % calculate constrained trial end
        % --------------------------------
        switch timeCon.endMark
            
            case 1, idx(:,2) = Iin(:,2) - dIE;
            case 2, idx(:,2) = Iin(:,1) + dIE;
            case 3, idx(:,2) = Iin(:,3) + dIE;
                
        end
        
        %  Copy the remainder of the cols in the input index array
        
        idx(:,3:cols) = Iin(:,3:cols);
        
        % ______________________________________________________________
        %
        %  VALIDATE RESULTS
        %
        %  Don't wind past beginning or end of input trial indices
        %  Make sure that all beginning indices are <= ending indices.
        % ______________________________________________________________
        
        begErr = find((idx(:,1) < Iin(:,1)) | (idx(:,2) < Iin(:,1)));
        endErr = find((idx(:,2) > Iin(:,2)) | (idx(:,1) > Iin(:,2)));
        seqErr = find( idx(:,1) > idx(:,2));
        
        if ~isempty(begErr) || ~isempty(endErr) || ~isempty(seqErr)
            msg = {'Error(s) in constraining trials'};
            if ~isempty(begErr)
                msg = [msg; {sprintf('  %d trials have limits which precede trial start', length(begErr))}];
            end;
            if ~isempty(endErr)
                msg = [msg; {sprintf('  %d trials have limits which extend beyond trial end', length(endErr))}];
            end;
            if ~isempty(seqErr)
                msg = [msg; {sprintf('  %d trials with start limit beyond end limit', length(seqErr))}];
            end;
            
            errordlg(msg, tDlg, 'modal');
            
            idx = -1;   % Return an empty index array
        end;
        
        % AP.index = idx;
        % ilabSetAnalysisParms(AP);
        
    end

end
