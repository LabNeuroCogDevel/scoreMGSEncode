%%%%%%%%%%
% 2013 04 22
% Arranging David Montez's Code
% all of output in scored-20130422.mat
%%%%%%%%%%

%% INPUT
% xls (old format please!) with header:
% LunaID, Sex, Visit, Age at Visit, Path to Eyd, Eyd File, Date of Scan
%

%% FINAL OUTPUT
%
% errorArray and correctArray
% lunaid,visit,run,targetcode,trialtime,errorCode
%
%   where errorCode == 1 if correct
%                      2 if abs(mostAccVGS(1,15)) > IQRs(1,4) + (3*IQRs(1,5))
%                      3 if isempty(vgs)
%                      4 if abs(mostAccMGS(1,15)) > IQRs(1,10) + (3*IQRs(1,11))
%                      5 if isempty(mgs)
%
%

%% OTHER OUTPUT
%
% collapsedMGSEncodeData
% correctedMGSEncodeData
% meansIQRs

% mgsEncodeData similiar to  visitSummary ???
%  xdatCode,                               ...       % (6)
%  eccentricity,                           ...       % (7)
%  encodeType,                             ...       % (8)
%  maintType,                              ...       % (9)
%  mostAccEncLatency,                      ...       % (10)
%  firstEncLatency,                        ...       % (11)
%  lastEncLatency,                         ...       % (12)
%  mostAccEncAccuracy,                     ...       % (13)
%  firstEncAccuracy,                       ...       % (14)
%  lastEncAccuracy,                        ...       % (15)
%  mostAccMGSLatency,                      ...       % (16)
%  firstMGSLatency,                        ...       % (17)
%  lastMGSLatency,                         ...       % (18)
%  mostAccMGSAccuracy,                     ...       % (19)
%  firstMGSAccuracy,                       ...       % (10)
%  lastMGSAccuracy,                        ...       % (21)
%  (mostAccEncAccuracy - mostAccMGSAccuracy), ...    % (22)
%  (firstEncAccuracy - firstMGSAccuracy), ...        % (23)
%  trialCorrect];                                    % (24)  
%
%% NOTES
% runNumber and time are set using eyd
% runNumber is in the xdat
% lookupTable for which set of xdats to take as the truth is hardcoded
% and set by runNumber

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all

%% add paths
% import that ilab is in this path
addpath(genpath('.')) 

%% load excel file, open each eyd, fixation correct, score
%results = MGSEncodeAnalyze;
results = MGSEncodeAnalyze_unixpath;
% eyd raw data --> results 

%% lump data into age groups, eccentricity, etc
ProcessMGSEncodeResults
% results --> MGSEncodeData, ageGrpEcc{Data,Means,MeanDiffs,IQR,Max,Min}
%             collapsedMGSEncodeData, correctedMGSEncodeData

%% give correct and incorrect 
RescoreMGSEncode
%   MGSEncodeData --> correctArray  & incorrectArray

%% save
save('scored.mat')