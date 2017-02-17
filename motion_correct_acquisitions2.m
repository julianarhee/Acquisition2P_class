
%% Run MC for multiple acquisitiosn without UI:
run_multi_acquisitions=0
source_dir = '/nas/volume1/2photon/RESDATA/20161221_JR030W/retinotopy037Hz/test_resize2/';
%if run_multi_acquisitions == 1
acquisition_dirs = dir(source_dir);
isub = [acquisition_dirs(:).isdir]; %# returns logical vector
acquisitions= {acquisition_dirs(isub).name}';
%else
%acquisition_dirs = source_dir;  %dir(fullfile(source_dir, '*.tif'))
%acquisitions = {acquisition_dirs}';
%end

acquisitions(ismember(acquisitions,{'.','..'})) = [];
mc_ref_channel = 2;
fprintf('Correcting acquisitions: \n');
display(acquisitions);

for acquisition_idx=1:length(acquisitions)
    
    % ---------------------------------------------------------------------
    % 1. Move each "acquisition" to be processed for M.C. into its own
    % directory:
    curr_acquisition_name = acquisitions{acquisition_idx};
    if run_multi_acquisitions==1
        curr_acquisition_dir = fullfile(source_dir, curr_acquisition_name);
    else
        curr_acquisition_dir = source_dir;
    end
    curr_tiffs = dir(fullfile(curr_acquisition_dir, '*.tif'));
    curr_tiffs = {curr_tiffs(:).name};
 
 
    
    if run_multi_acquisitions == 1
        for tiff_idx = 1:length(curr_tiffs)
        curr_tiff_fn = curr_tiffs{tiff_idx};
        [pathstr,name,ext] = fileparts(curr_tiff_fn);
        if ~exist(fullfile(curr_acquisition_dir, name), 'dir')
            mkdir(fullfile(curr_acquisition_dir, name));
            movefile(fullfile(curr_acquisition_dir, curr_tiff_fn), fullfile(curr_acquisition_dir, name, curr_tiff_fn));
        end
        end
    end
    
    fprintf('Processing acquisition %s...\n', curr_acquisition_name);
    % ---------------------------------------------------------------------
    % Walk through each acquisition-directory and run motion correction:
    tiff_dirs = dir(curr_acquisition_dir);
    tmp_isub = [tiff_dirs(:).isdir]; %# returns logical vector
    tiffs = {tiff_dirs(tmp_isub).name}';
    tiffs(ismember(tiffs,{'.','..'})) = [];
    
    for tiff_idx = 1:length(tiffs)
        curr_mov = fullfile(curr_acquisition_dir, tiffs{tiff_idx});
        myObj = Acquisition2P([],{@SC2Pinit_noUI,[],curr_mov});
        myObj.motionRefChannel = 2;
        myObj.motionRefMovNum = 1;
        myObj.motionCorrect2;
    end
    
    
    % ---------------------------------------------------------------------
    % If using (and including) 2 channels for MC, separate them into their
    % own dirs:
    if mc_ref_channel == 2
    for tiff_idx = 1:length(tiffs)
        corrected_path = fullfile(curr_acquisition_dir, tiffs{tiff_idx}, 'Corrected');
        corrected_tiff_fns = dir(fullfile(corrected_path, '*.tif'));
        corrected_tiff_fns = {corrected_tiff_fns(:).name};
        corrected_ch1_path = fullfile(corrected_path, 'Channel01');
        corrected_ch2_path = fullfile(corrected_path, 'Channel02');
        if ~exist(corrected_ch1_path, 'dir')
            mkdir(corrected_ch1_path);
            mkdir(corrected_ch2_path);
        end
        for tiff_idx=1:length(corrected_tiff_fns)
            if strfind(corrected_tiff_fns{tiff_idx}, 'Channel01')
                movefile(fullfile(corrected_path, corrected_tiff_fns{tiff_idx}), fullfile(corrected_ch1_path, corrected_tiff_fns{tiff_idx}));
            else
                movefile(fullfile(corrected_path, corrected_tiff_fns{tiff_idx}), fullfile(corrected_ch2_path, corrected_tiff_fns{tiff_idx}));
            end
        end
    end
    end
    
    
    
                
end

