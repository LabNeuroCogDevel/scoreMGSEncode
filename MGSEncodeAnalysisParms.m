function AP = MGSEncodeAnalysisParms()
%ILABDEFAULTANALYSISPARMS Returns the default ANALYSISPARMS data structure.
%   AP = ILABDEFAULTANALYSISPARMS returns the default
%   analysisparms parameters. Users can edit this file to change the
%   defaults.
%
%   NOTE: Always make a backup of the original file before messing
%   with it. Some of the parameters are fairly specific and changing
%   them may cause errors.
%
%   -------------------------------
%   ANALYSISPARMS FIELDS
%   -------------------------------
%
%   Analysis types do not use all the analysis parameters and may have
%   restrictions on others:
%     ROI statistics requires one or more ROIs to be specified.
%     gaze maintenance requires one, and only one, ROI to be specified.
%     fixation detection requires using a coordinate basis
%     saccade detection requires using a coordinate basis
%
%     basis:    coordinate (0) or fixation (1) based analysis
%
%     targets:  {0,1} depending if no targets/targets present in data set.
%               This is a convenience field which is often used in processing
%               analysis parameters and in performing analyses.
%               It is set each time a new data set is loaded (ilabLoadDataCB)
%
%   -------------------------------
%   COORDINATE SYSTEM
%   -------------------------------
%   coordSys.data      [] (n x 4 matrix describing correspondence between
%                          screen and eye tracker coordinates (optional))
%   coordSys.params    horizontal and vertical parameters (slope and
%                      intercept) describing linear transformation between
%                      screen and eye tracker coordinates.
%   coordSys.screen    Width and Height of computer screen in pixels
%   coordSys.eyetrack  Width and Height of eye tracker screen in pixels
%
%
%   -------------------------------
%   minReactTime  DEPRECATED
%   -------------------------------
%
%
%   -------------------------------
%   FILE EXTENSION
%   -------------------------------
%   file.Ext        Permits filtering of different file types in the file
%                   selection box
%
%
%   -------------------------------
%   BLINK PARAMETERS
%   -------------------------------
%   Blink filtering parameters (This could be independent of any other
%   analysis). A list of replacements is maintained to enable quick
%   switching between filtered/non-filtered states since entire data
%   arrays can be large.
%   -------------------------------
%   blink.filter      [0 0] Blink filter method: (1) by pupil size, (2) by bad locations
%   blink.limits      [0 640 0 480] Limits for location filtering (Hmin Hmax Vmin Vmax)
%   blink.list        [ ] List of replacements for blink periods [i1 i2 x y]
%   blink.method      [ 0 ] Replacement method: Substitute invalid (0)
%                           or last valid point (1) for blinks.
%   blink.replace     [ 0 ] Don't replace (0) or Replace (1) pre/post blink values
%   blink.vertThresh  [ 20 ] Threshold for vertical movement (pixels/samplingInterval)
%   blink.window      [ 5 ] Number of pre- & post-blink samples to search for replacement
%
%
%   -------------------------------
%   FILTER PARAMETERS
%   -------------------------------
%   Filters are now added throught the analysis directory and calling
%   ilabRegisterFilters.
%   filter = [];
%
%
%   -------------------------------
%   FIXATION PARAMETERS
%   -------------------------------
%   fix.params                   parameters for various fixation calcs
%   fix.params.vel               parameters for velocity/distance based calculations
%   fix.params.vel.hMax          hMax, vMax maximum horizontal and vertical excursion allowed
%   fix.params.vel.vMax          between samples during a fixation period(ILAB pixels)
%                                since the acquisition time is constant between samples
%                                distance measures are equivalent to velocity measures.
%   fix.params.vel.minDuration   Minimum duration of a fixation period
%   fix.params.disp.Disp         Dispersion
%   fix.params.disp.minDuration  Minimum duration of a fixation period
%   fix.params.disp.NaNDur       Maximum data loss per fixation
%   fix.type                     currently chosen calculation type. Vel = velocity and
%                                disp = dispersion
%   fix.list                     List of fixation calculation results.
%   fix.table                    Formatted table of calculation results.
%
%
%  -------------------------------
%   FONT PARAMETERS
%  -------------------------------
%  font.name = 'FixedWidth';
%  font.size = 10;
%
%
%   -------------------------------
%   GAP PARAMETERS
%   -------------------------------
%   Data gap handling parameters
%   Data gaps occur when the coordinate values are invalid.
%   The eye tracker program usually places (0,0) coords at these sampling
%   points.  The value pair (NaN, NaN) could also be used to mark invalid coords.
%
%   gap.min     Minimum number of consecutive invalid  samples that define a "gap"
%   gap.maxPct  Maximum percent of invalid samples/trial allowed per trial
%   gap.method  Gap-handling method when # of consecutive invalid samples <= gap.min
%               (0 => count only time for gaps. 1=> count time & interpolate coords)
%               The methods should probably be expanded to include
%               No handling (Ignore? reject?), 
%               count gap times, interpolate (linearly) coords, or both.
%    gap.calc   Flag to calculate or not calculate trials with %zero exceeding maxPct.
%               0 = don't calc, 1 = calc.
%
%
%   -------------------------------
%   GAZE MAINTENANCE PARAMETERS
%   -------------------------------
%   gaze.ROI          The ROI which defines the gaze boundary
%   gaze.list         List of gaze calculation results. 
%                     {0,1}=>gaze {not maintained,maintained}
%   gaze.table        Formatted table of calculation results.
%   gaze.DataOutpts   List of horiz, vert coords and whether they are in selected ROI.
%
%
%   -------------------------------
%   ROI PARAMETERS
%   -------------------------------
%   roi.dataType          [0] 0=points, 1=fixations
%   roi.calcType          [0] 0=inside, 1=outside
%   roi.dynam{1}          [1] ROI choice from a popup menu (a value of 1 is
%                         the default menu string and not a ROI) 
%   roi.dynam{2}          [1] #points/fixations. This parameter specifies
%                         how many points/fixations to average for
%                         determining the dynamic ROI location. In
%                         general the choice for fixation will be 1. 
%   roi.dynam{3}          [0] Frame of reference (A static ROI frame of
%                         reference does not adjust other ROI positions
%                         based on the chosen dynamic ROI. A dynamic
%                         ROI frame of reference adjusts other ROI
%                         positions. This is done linearly (e.g.,
%                         Center ROI selected as dynamic and shifts
%                         from (320,240) on trial 1 to (300,260) on
%                         trial 2. Other ROI locations are then shifted
%                         by -20 x-units and +20 y-units.). A dynamic
%                         Frame of Reference only meaningful if more
%                         than one ROI is selected.
%   roi.dynam{4}          [0] Statistic for combining multiple
%                         points/fixations (0=mean, 1=median) for
%                         determining the dynamic ROI location.
%   roi.dynam{5}          Adjustments by trial (n x 3). Column 1 = x
%                         adjustments; Column 2 = y adjustments;
%                         Column 3 = #points/fixations used. This cell
%                         is set by ilabCalcROIStatsCB after the
%                         adjustments have been calculated for each
%                         trial.
%   roi.roi               Structure of ROI descriptions. (18 x 1).
%                         Returned by ilabGetROI(AP).
%   roi.list              List of ROI statistics results. Added to roi just
%                         As the fixation list is part of fix.
%   roi.table             Formatted table of ROI statistics results
%
%
%   -------------------------------
%   SACCADE PARAMETERS
%   -------------------------------
%   saccade.method           Method used to calculate saccades
%   saccade.velThresh        Minimum velocity ( ILAB pixels/samplingInterval )
%   saccade.window           Maximum width of search window (in ms) from onset of velThresh
%   saccade.pctPeak          Percent of peak velocity for final saccade cut
%   saccade.minSaccDuration  Minimum duration of saccade (ms)
%   saccade.onset            Calculation of saccadic RT and ttpeak w.r.t.
%                            trial=1 or target=2.
%   saccade.ROI              optional ROI used to establish min fixation response
%   saccade.minFixDuration   optional min fixation duration in ROI
%   saccade.list             List of saccade results. 
%   saccade.table            Formatted table of calculation results.
%
%
%   -------------------------------
%   SCREEN PARAMETERS
%   -------------------------------
%   Computer Screen parameters (Used in specifing ROI's by angle and
%   perhaps elsewhere)
%   screen.distance    Subject to screen distance (cm)
%   screen.width       Screen width (cm)
%   screen.height      Screen height(cm)
%
%
%   -------------------------------
%   TIME CONSTRAINTS
%   -------------------------------
%
%   Designates a portion of the trial(s) to analyze. Must use same
%   constraints for all trials.
%
%   time.startMark  Start analysis at trial start [+ intvl], trial end [- intvl], target [+/- intvl]
%   time.startIntvl Optional interval (ms) used relative to start,marker
%   time.startROI   Optional ROI number. When specified, the first starting data coords
%                   must lie within the ROI.
%   time.endMark    End analysis at trial end [- intvl], trial [+ intvl], target [+/- intvl]
%   time.endIntvl   Optional interval (ms) used with end.marker
%   time.index      Array of beginning/end indices for each trial that corresponds to
%                   the constraints specified in start and end parms above.
%
%   -------------------------------
%   TRIALCODES
%   -------------------------------
%   Values in the data file that mark trial start, end and target appearance
%     (The individual markers can be multi-valued.)
%   To designate a value as empty use NaN. Do not simply leave a value empty.
%   CORRECT -> trialCodes.target = NaN;   INCORRECT -> trialCodes.target = [];
%
%   trialCodes.start  = start codes
%   trialCodes.target = target codes
%   trialCodes.end    = end codes
%
%   -------------------------------
%   WARNINGS
%   -------------------------------
%   Warning choices and display states (returned by ilabWarnings
%   warning.msgid   ID of warning message.
%   warning.state   Warning state for this message

% Authors: Darren Gitelman
% $Id: ilabDefaultAnalysisParms.m 116 2010-06-08 21:42:20Z drg $

% GENERAL FIELDS
% --------------------------------------------------------            
basis   = 0;
targets = 0;

%   COORDINATE SYSTEM
% --------------------------------------------------------            
ilabdir  = ilabGetILABDirs;
coordSys = [];
try
    load(fullfile(ilabdir.ilab,'coordSys.mat'));
catch 
    coordSys.name     = '';
    coordSys.data     = []
    coordSys.params.h = [];
    coordSys.params.v = [];
    coordSys.screen   = [];
    coordSys.eyetrack = [];
end


%  FILE EXTENSIONS
% --------------------------------------------------------
file = [];
file.Ext = {'*.eyd;*.bin;*.tda;*.dat','ASL, ISCAN, or IVIEW files (*.eyd, *.bin, *.tda, *.dat)';...
        '*.eyd', 'ASL binary files (*.eyd)';...
        '*.bin;*.tda', 'ISCAN binary files (*.bin, *.tda)';...
        '*.dat', 'IVIEW ascii files (*.dat)';...
        '*.*',   'All other file types (*.*)'};


%  BLINK PARAMETERS
% --------------------------------------------------------   
blink = [];
blink.filter     = [1 1];
% nominally set to 640 x 480 but adjusted once a coordinate system is
% loaded.
blink.limits     = [-120 760 0 480];
blink.list       = [];
blink.method     = 0;
blink.replace    = 5;
blink.vertThresh = 20;
blink.window     = 5;


%  FILTER PARAMETERS
% --------------------------------------------------------            
%  Added through ilabRegisterFilters
filter           = [];


%  FIXATION PARAMETERS
% --------------------------------------------------------            
%  fixation parameters are saved as pixels.
%  The values saved as defaults represent 0.5 and 1 degree 
%  respectively of a subject approximate 42 inches from the screen.
fix = [];
fix.params.vel.hMax         = 14;
fix.params.vel.vMax         = 14;
fix.params.vel.minDuration  = 100;
fix.params.disp.Disp        = 28;
fix.params.disp.minDuration = 100;
fix.params.disp.NaNDur      = inf;
fix.type                    = 'vel';
fix.list                    = [];
fix.table                   = [];


%  FONT PARAMETERS
% --------------------------------------------------------
 font.name = 'FixedWidth';
 font.size = 10;


%  GAP PARAMETERS
% --------------------------------------------------------
gap = [];
gap.min    = 10;
gap.maxPct = 20;
gap.method = 0;
gap.calc   = 0;


%  GAZE PARAMETERS
% --------------------------------------------------------
gaze = [];
gaze.ROI.name    = [];
gaze.ROI.x       = [];
gaze.ROI.y       = [];
gaze.ROI.enabled = 0;
gaze.ROI.calc    = 0;
gaze.list        = [];
gaze.table       = [];
gaze.DataOutpts  = {};


%  REGION OF INTEREST
% --------------------------------------------------------
roi = [];
roi.dataType        = 0;
roi.calcType        = 0;
roi.dynam{1}        = 1;    % ROI choice
roi.dynam{2}        = 1;    % number pts/fix
roi.dynam{3}        = 0;    % static=0 or dynamic=1 F.O.R.
roi.dynam{4}        = 0;    % mean=0 or median=1.
roi.dynam{5}        = [];   % adjustments by trial
roi.roi             = ilabGetROI('reset');  % added through ilabGetROI.
roi.list            = [];
roi.table           = [];


%  SACCADE PARAMETERS
% --------------------------------------------------------
saccade = [];
saccade.method           = 1;
saccade.velThresh        = 30;
saccade.window           = 100;
saccade.pctPeak          = 15;
saccade.minSaccDuration  = 35;
saccade.onset            = 1;
saccade.ROI.name         = [];
saccade.ROI.x            = [];
saccade.ROI.y            = [];
saccade.ROI.enabled      = 0;
saccade.minFixDuration   = 100;
saccade.list             = [];
saccade.table            = [];


%  SCREEN PARAMETERS
% --------------------------------------------------------
screen = [];
screen.distance =  60;
screen.width    =  25;
screen.height   =  18.75;


%  Time Constraints
% --------------------------------------------------------
time = [];
time.startMark  = 1;
time.startIntvl = 0;
time.startROI   = 7;
time.endMark    = 1;
time.endIntvl   = 0;
time.index      = [];

%  TRIAL CODES
% --------------------------------------------------------
trialCodes = [];
trialCodes.start   = [20,30,40,50,60];
trialCodes.target = [121:126,131:136,141:146,151:156,160];
trialCodes.end    = 250;

%  VERSION
% --------------------------------------------------------
vers = ilabVersion;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
AP = [];
AP.basis      = basis;
AP.coordSys   = coordSys;
AP.file       = file;
AP.blink      = blink;
AP.filter     = filter;
AP.fix        = fix;
AP.font       = font;
AP.gap        = gap;
AP.gaze       = gaze;
AP.roi        = roi;
AP.screen     = screen;
AP.saccade    = saccade;
AP.targets    = targets;
AP.time       = time;
AP.trialCodes = trialCodes;
AP.vers       = vers;