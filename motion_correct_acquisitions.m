%% Using the Acuisition2P class:
%
%% -----Setup-------
% All software in the acq2P package has been extensively tested on Matlab
% 2014b. Using earlier versions may cause bugs and will certainly degrade
% appearance.

% You will need a number of functions from the harveylab helper functions
% repository, so I suggest you add the full repository to your path.

% In addition to these functions, you need to add certain folders from
% within the 'Acquisition2P_class' repository to your path. Specifically,
% the classes folder (without the @ subdirectories) and the common folder
% (with all subdirectories). You may choose to add folders from
% 'personal' as appropriate, and place custom initialization / scripts
% there.

%% Overview
% In a typical imaging experiment, we image activity at one field-of-view for some 
% duration. This FOV may be subdivided into multiple axial slices, each of which 
% consist of an arbitrary number of channels, and the data corresponding to the entire 
% 'acquisition' is a list of TIFF files named according to the user's convention, which 
% may or may not have been acquired with pauses between certain movies. If we later 
% move the sample or microscope to a new position, in this terminology we start a 
% new 'acquisition'.
% 
% For data capture within one acquisition, we almost always want to motion correct 
% all frames for each slice with respect to each other, select appropriate ROIs, and 
% extract corresponding fluorescence traces. The Acquisition2P class is designed 
% to completely manage this pipeline from raw acquisitions to traces, and nothing 
% more (i.e. no thresholding, analysis...).
% 
% The general idea is that the processing pipeline is hard-coded into the class 
% properties/methods, but particulars (e.g. naming formats, initializations, the specific algorithm for 
% motion correction used) are flexible and user-modifiable outside the class structure.  
% Hopefully this allows easy sharing of code and data and provides a standard for 
% long-term storage of metadata, without being overly fascistic about particular details 
% of how a user names, organizes, or processes their data.
% 
% The code below is a simple step-by-step script illustrating how you can use the class 
% on a group of raw files stored on a local hard drive. Moving Acquisition2P objects, 
% from a rig to a server or a server to an analysis computer is straightforward, but 
% involves functions not mentioned in this overview script. Look at the method newDir, and an 
% example of the function 'acq2server' (in selmaan's personal folder) using this method, 
% if you want to see an eample of my typical workflow, or use newDir and matlab's copyfile
% function to build your own. Alternately the acq2pJobProcessor is a class
% designed to handle automated processing of acq2p objects, very useful if
% you have masses of data to deal with. It has a readme file documenting
% usage in the @acq2pJobProcessor.

%% Initialize an Acquisition2P object

% Acquisitions can be constructed a number of ways, fully documented in the
% .m file. The most typical way is to pass a handle to an initialization
% function. Here, I use the SC2Pinit initialization function, which is provided 
% as an example for what initialization is supposed to do. Once you
% understand how it works, you can design your own initialization function
% to match whatever naming/organizing convention you already use.

% The function is commented in detail, but basically it allows graphical 
% user selection of a group of files, uses the filenames to name a new
% acquisition2P object, adds the selected files to the object as raw data,
% and fills in properties of the object necessary for motion correction
% (e.g. the function/algorithm to use, the channel to use as reference for 
% motion correction). If this succeeds, it assigns the object to a variable in the base 
% workspace with the name created by the automatic procedure. The function also
% outputs the object if you prefer that syntax, but having the
% initialization automatically assign the variable ensures that the
% object's internal name matches its matlab variable name. 


%myObj = Acquisition2P([],@SC2Pinit);

%myObj.motionRefChannel = 2;
%myObj.motionRefMovNum = 1; %10;

%myObj.motionCorrect;

% The Acquisition2P constructer has a series of error checks to ensure that
% necessary properties are not left blank by accident. Practically, this
% means that with whatever custom initialization function you use, the code
% will automatically check to see if fields are provided. If they are not,
% it will issue a warning, and either fill in the field with a default
% value or alert the user to manually fill the field. (For hardcore users,
% you can bypass these error checks using a different constructer syntax)

%% Run MC for multiple acquisitiosn without UI:
clear all;
clc;
addpath(genpath('~/Repositories/Acquisition2P_class'))
addpath(genpath('~/Repositories/helperFunctions'))
addpath(genpath('~/Repositories/12k2p-software'))
addpath(genpath('~/Repositories/2p-tester-scripts'))

gcp;

run_multi_acquisitions=0;

crossref = false %true;
processed = true; %false % true


%acquisition_dir = '/nas/volume1/2photon/RESDATA/20161222_JR030W/gratings1';
%acquisition_dir = '/nas/volume1/2photon/RESDATA/20161221_JR030W/test_crossref';
%acquisition_dir = '/nas/volume1/2photon/RESDATA/20161222_JR030W/gratings2/DATA';
%acquisition_dir = '/nas/volume1/2photon/RESDATA/test_motion_correction';
acquisition_dir = '/nas/volume1/2photon/RESDATA/test_motion_correction_3D/DATA';

%if run_multi_acquisitions == 1
% acquisition_dirs = dir(acquisition_dir);
% isub = [acquisition_dirs(:).isdir]; %# returns logical vector
% acquisitions= {acquisition_dirs(isub).name}';
%else
%tiffs = dir(fullfile(acquisition_dir, '*.tif'));
%tiffs = {tiffs(:).name}';
%end

%tiffs(ismember(tiffs,{'.','..'})) = [];
mc_ref_channel = 2; %1; %2;
mc_ref_movie = 2;

%fprintf('Correcting %i movies: \n', length(tiffs));
%display(tiffs);

%for tiffidx=1:length(tiffs)
    
    % ---------------------------------------------------------------------
    % 1. Move each "acquisition" to be processed for M.C. into its own
    % directory:
%    currTiffName = tiffs{tiffidx};

%    currTiff = fullfile(acquisition_dir, currTiffName); 
    
%     if run_multi_acquisitions == 1
%         for tiff_idx = 1:length(currTiff)
%         curr_tiff_fn = currTiff{tiff_idx};
%         [pathstr,name,ext] = fileparts(curr_tiff_fn);
%         if ~exist(fullfile(curr_acquisition_dir, name), 'dir')
%             mkdir(fullfile(curr_acquisition_dir, name));
%             movefile(fullfile(curr_acquisition_dir, curr_tiff_fn), fullfile(curr_acquisition_dir, name, curr_tiff_fn));
%         end
%         end
%     end
    
fprintf('Processing acquisition %s...\n', acquisition_dir);
    % ---------------------------------------------------------------------
    % Walk through each acquisition-directory and run motion correction:
%     tiff_dirs = dir(curr_acquisition_dir);
%     tmp_isub = [tiff_dirs(:).isdir]; %# returns logical vector
%     tiffs = {tiff_dirs(tmp_isub).name}';
%     tiffs(ismember(tiffs,{'.','..'})) = [];
%     
%     for tiff_idx = 1:length(tiffs)
%     curr_mov = fullfile(curr_acquisition_dir, tiffs{tiff_idx});

if crossref
    myObj = Acquisition2P([],{@SC2Pinit_noUI_crossref,[],acquisition_dir,crossref});
    myObj.motionRefChannel = mc_ref_channel; %2;
    myObj.motionRefMovNum = mc_ref_movie;
    myObj.motionCorrectCrossref;
    %end
    myObj.save;
elseif processed
    myObj = Acquisition2P([],{@SC2Pinit_noUI,[],acquisition_dir});
    myObj.motionCorrectionFunction = @lucasKanade_plus_nonrigid;
    myObj.motionRefChannel = mc_ref_channel; %2;
    myObj.motionRefMovNum = mc_ref_movie;
    myObj.motionCorrectProcessed;
    %end
    myObj.save;
else
    myObj = Acquisition2P([],{@SC2Pinit_noUI,[],acquisition_dir});
    myObj.motionCorrectionFunction = @lucasKanade_plus_nonrigid;
    myObj.motionRefChannel = mc_ref_channel; %2;
    myObj.motionRefMovNum = mc_ref_movie;
    myObj.motionCorrect;
    %end
    myObj.save;
end
    
% ---------------------------------------------------------------------
% If using (and including) 2 channels for MC, separate them into their
% own dirs:
% if mc_ref_channel == 2
% %     for tiff_idx = 1:length(tiffs)
%     corrected_path = fullfile(acquisition_dir, 'Corrected');
%     corrected_tiff_fns = dir(fullfile(corrected_path, '*.tif'));
%     corrected_tiff_fns = {corrected_tiff_fns(:).name};
%     corrected_ch1_path = fullfile(corrected_path, 'Channel01');
%     corrected_ch2_path = fullfile(corrected_path, 'Channel02');
%     if ~exist(corrected_ch1_path, 'dir')
%         mkdir(corrected_ch1_path);
%         mkdir(corrected_ch2_path);
%     end
%     for tiff_idx=1:length(corrected_tiff_fns)
%         if strfind(corrected_tiff_fns{tiff_idx}, 'Channel01')
%             movefile(fullfile(corrected_path, corrected_tiff_fns{tiff_idx}), fullfile(corrected_ch1_path, corrected_tiff_fns{tiff_idx}));
%         else
%             movefile(fullfile(corrected_path, corrected_tiff_fns{tiff_idx}), fullfile(corrected_ch2_path, corrected_tiff_fns{tiff_idx}));
%         end
%     end
% %     end
% end
% 






