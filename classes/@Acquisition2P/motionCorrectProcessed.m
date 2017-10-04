function motionCorrectProcessed(obj,writeDir,motionCorrectionFunction,namingFunction)
%Wrapper function managing motion correction of an acquisition object
%
%motionCorrect(obj,writeDir,motionCorrectionFunction,namingFunction)
%
%writeDir is an optional argument specifying location to write motion
%   corrected data to, defaults to obj.defaultDir\Corrected
%motionCorrectionFunction is a handle to a motion correction function,
%   and is optional only if acquisition already has a function handle
%   assigned to motionCorectionFunction field. If argument is provided,
%   function handle overwrites field in acq obj.
%namingFunction is a handle to a function for naming. If empty, uses
%   default naming function which is a local function of motionCorrect.
%   All naming functions must take in the following arguments (in
%   order): obj.acqName, nSlice, nChannel, movNum.

%% Error checking and input handling
if ~exist('motionCorrectionFunction', 'var')
    motionCorrectionFunction = [];
end

if nargin < 4 || isempty(namingFunction)
    namingFunction = @defaultNamingFunction;
end

if isempty(motionCorrectionFunction) && isempty(obj.motionCorrectionFunction)
    error('Function for correction not provided as argument or specified in acquisition object');
elseif isempty(motionCorrectionFunction)
    %If no argument but field present for object, use that function
    motionCorrectionFunction = obj.motionCorrectionFunction;
else
    %If using argument provided, assign to obj field
    obj.motionCorrectionFunction = motionCorrectionFunction;
end

if isempty(obj.acqName)
    error('Acquisition Name Unspecified'),
end

if ~exist('writeDir', 'var') || isempty(writeDir) %Use Corrected in Default Directory if non specified
    if isempty(obj.defaultDir)
        error('Default Directory unspecified'),
    else
        writeDir = [obj.defaultDir filesep 'Corrected'];
    end
end

if isempty(obj.defaultDir)
    obj.defaultDir = writeDir;
end

if isempty(obj.motionRefMovNum)
    if length(obj.Movies)==1
        obj.motionRefMovNum = 1;
    else
        error('Motion Correction Reference not identified');
    end
end

%% Load movies and motion correct
%Calculate Number of movies and arrange processing order so that
%reference is first
nMovies = length(obj.Movies);
if isempty(obj.motionRefMovNum)
    obj.motionRefMovNum = floor(nMovies/2);
end
movieOrder = 1:nMovies;
movieOrder([1 obj.motionRefMovNum]) = [obj.motionRefMovNum 1];


% meta source info comes from original tiffs:
%[parentDir, dataFolder, ~] = fileparts(obj.defaultDir);
pts = strsplit(obj.defaultDir, '/DATA');
parentDir = pts{1};
%origMovies = dir(fullfile(parentDir,'*.tif'));
%origMovies = {origMovies(:).name};

[acq_dir, func_folder, ~] = fileparts(parentDir);
fprintf('ACQ dir: %s\n', acq_dir);
simeta = load(fullfile(acq_dir, sprintf('SI_raw_%s.mat', func_folder))) 

%Load movies one at a time in order, apply correction, and save as
%split files (slice and channel)
for movNum = movieOrder
    fprintf('\nLoading Movie #%03.0f of #%03.0f\n',movNum,nMovies),
    %[mov, scanImageMetadata] = obj.readRaw(movNum,'single');
    %[mov, scanImageMetadata] = obj.readRaw(movNum,'double');
    
   
    % Don't read orig, too huge:
    currfile = sprintf('File%03d', movNum) 
    scanImageMetadata = simeta.(currfile);
    fieldnames(scanImageMetadata)

    %[~, scanImageMetadata] = tiffReadMeta(fullfile(parentDir, origMovies{movNum}));
    % but movie file comes from processed tiff:
    %[mov, ~] = tiffRead(fullfile(obj.defaultDir, obj.Movies{movNum}));
    fprintf('Curr movie is: %s\n', obj.Movies{movNum});
    %[mov, ~] = tiffRead(obj.Movies{movNum});
    mov = read_file(obj.Movies{movNum});

    fprintf('Mov size is: %s\n.', mat2str(size(mov)));
    fprintf('Mov type is: %s\n.', class(mov));

    fprintf('Pixels Per Line: %i\n', scanImageMetadata.SI.hRoiManager.pixelsPerLine)
    fprintf('Lines Per Frame: %i\n', scanImageMetadata.SI.hRoiManager.linesPerFrame)
    if size(mov,2)~=scanImageMetadata.SI.hRoiManager.pixelsPerLine
        fprintf('Cropping pixels per line to %i\n', size(mov,2));
        scanImageMetadata.SI.hRoiManager.pixelsPerLine = size(mov,2);
    end
    if size(mov,1)~=scanImageMetadata.SI.hRoiManager.linesPerFrame
        fprintf('Cropping lines per frame to %i\n', size(mov,1));
        scanImageMetadata.SI.hRoiManager.linesPerFrame = size(mov,1);
    end


    if obj.binFactor > 1
        mov = binSpatial(mov, obj.binFactor);
    end

    % Adjust SI meta to match true data:
    scanImageMetadata = adjust_si_metadata(scanImageMetadata, mov);
%    fprintf('Parsing processed SI tiff and getting adjusted meta data...\n');
%    fprintf('Size of movie: %s\n', mat2str(size(mov)));
%    nSlicesTmp = scanImageMetadata.SI.hStackManager.numSlices
%    nDiscardTmp = scanImageMetadata.SI.hFastZ.numDiscardFlybackFrames;
%    nVolumesTmp = scanImageMetadata.SI.hFastZ.numVolumes;
%    nChannelsTmp = numel(scanImageMetadata.SI.hChannels.channelSave);
%    desiredSlices = (size(mov, 3) / nChannelsTmp) / nVolumesTmp
%    nDiscardedExtra = nSlicesTmp - desiredSlices
%    if desiredSlices ~= nSlicesTmp  % input (processed) tiff does not have discard removed, or has extra flyback frames removed.
% 	if nDiscardTmp == 0
% 	    % This means discard frames were not specified and acquired, and flyback frames removed from top in processed tiff.
% 	    extra_flyback_top = true;
%             nDiscardTmp = nSlicesTmp - desiredSlices;
% 	    false_discard = true;
%         elseif nDiscardTmp > 0
% 	    % Discard frames were specified/acquired but extra flyback frames removed from top of stack
% 	    extra_flyback_top = true;   
% 	    false_discard = false;
% 	end
%     else
% 	extra_flyback_top = false;
% 	false_discard = false;
%     end
% 
%    nSlicesSelected = desiredSlices; %nSlicesTmp - nDiscardTmp;
% 
%    scanImageMetadata.SI.hStackManager.numSlices = nSlicesSelected;
%    scanImageMetadata.SI.hFastZ.numDiscardFlybackFrames = 0;
%    scanImageMetadata.SI.hFastZ.numFramesPerVolume = scanImageMetadata.SI.hStackManager.numSlices;
%    scanImageMetadata.SI.hStackManager.zs = scanImageMetadata.SI.hStackManager.zs(nDiscardedExtra+1:end);
%    scanImageMetadata.SI.hFastZ.discardFlybackFrames = 0;  % Need to disflag this so that parseScanimageTiff (from Acquisition2P) takes correct n slices
%    nFramesSelected = nChannelsTmp*nSlicesSelected*nVolumesTmp
% 
%    metanames = fieldnames(scanImageMetadata);
%    for field=1:length(metanames)
%        if strcmp(metanames{field}, 'SI')
%            continue;
%        else
%            currfield = scanImageMetadata.(metanames{field});
%             if extra_flyback_top && false_discard %falseDiscard
%                 % there are no additional empty flybacks at the end of volume, so just skip every nSlicesTmp, starting from corrected num nDiscard removed from top:
%                 startidxs = colon(nDiscardTmp*nChannelsTmp+1, nChannelsTmp*(nSlicesTmp), length(currfield)); 
%                 fprintf('N volumes based on start indices: %i\n', length(startidxs));
%             elseif extra_flyback_top && ~false_discard
% 		% There were specified num of empty flybacks at end of volume, so remove those indices, if necessary, while also removing the removed frames at top:
%                 startidxs = colon(nDiscardTmp*nChannelsTmp+1, nChannelsTmp*(nSlicesTmp+nDiscardTmp), length(currfield));
%             else
% 		% There were empty flyybacks at end of volume, but correctly executed, s.t. no additional flybacks removed from top:
% 		startidxs = colon(1:nChannelsTmp*(nSlicesTmp+nDiscardTmp), length(currfield)); 
% 	    end
%            if iscell(currfield)
%                tmpfield = cell(1, nFramesSelected);
%            else
%                tmpfield = zeros(1, nFramesSelected);
%            end
%            newidx = 1;
%            for startidx = startidxs
% 	       % Only grab info for those frames that are kept in processed tiff (i.e., remove indices related to any "top" flyback and any "true" discard frames:
%                tmpfield(newidx:newidx+(nSlicesSelected*nChannelsTmp - 1)) = currfield(startidx:startidx+(nSlicesSelected*nChannelsTmp - 1));
%                newidx = newidx + (nSlicesSelected*nChannelsTmp);
%            end
%            scanImageMetadata.(metanames{field}) = tmpfield;
%        end
%    end
% 


    % Apply line shift:
    fprintf('Line Shift Correcting Movie #%03.0f of #%03.0f\n', movNum, nMovies),
    mov = correctLineShift(mov);
    fprintf('Finished Line-Shift correction. Movie size is: %s', mat2str(size(mov)));
    try
        [movStruct, nSlices, nChannels] = parseScanimageTiff(mov, scanImageMetadata);
	fprintf('Parsed SI tiff. nSlices: %s', num2str(nSlices));
    catch
        error('parseScanimageTiff failed to parse metadata'),
    end
    clear mov

    % Find motion:
    fprintf('Identifying Motion Correction for Movie #%03.0f of #%03.0f\n', movNum, nMovies),
    obj.motionCorrectionFunction(obj, movStruct, scanImageMetadata, movNum, 'identify');

    % Apply motion correction and write separate file for each
    % slice\channel:
    fprintf('Applying Motion Correction for Movie #%03.0f of #%03.0f\n', movNum, nMovies),
    movStruct = obj.motionCorrectionFunction(obj, movStruct, scanImageMetadata, movNum, 'apply');
    for nSlice = 1:nSlices
        for nChannel = 1:nChannels
            % Create movie fileName and save in acq object
            movFileName = feval(namingFunction,obj.acqName, nSlice, nChannel, movNum);
            obj.correctedMovies.slice(nSlice).channel(nChannel).fileName{movNum} = fullfile(writeDir,movFileName);
            % Determine 3D-size of movie and store w/ fileNames
            obj.correctedMovies.slice(nSlice).channel(nChannel).size(movNum,:) = ...
                size(movStruct.slice(nSlice).channel(nChannel).mov);
            % Write corrected movie to disk
            fprintf('Writing Movie #%03.0f of #%03.0f\n',movNum,nMovies),
            try
                tiffWrite(movStruct.slice(nSlice).channel(nChannel).mov, movFileName, writeDir, 'int16');
                %tiffWrite(movStruct.slice(nSlice).channel(nChannel).mov, movFileName, writeDir, 'uint16');
            catch
                % Sometimes, disk access fails due to intermittent
                % network problem. In that case, wait and re-try once:
                pause(60);
                tiffWrite(movStruct.slice(nSlice).channel(nChannel).mov, movFileName, writeDir, 'int16');
                %tiffWrite(movStruct.slice(nSlice).channel(nChannel).mov, movFileName, writeDir, 'uint16');
            end
        end
    end

    obj.metaDataSI{movNum} = scanImageMetadata;
end

% Store SI metadata in acq object
%obj.metaDataSI = scanImageMetadata;

%Assign acquisition to a variable with its own name, and write to same
%directory
eval([obj.acqName ' = obj;']),
save(fullfile(obj.defaultDir, obj.acqName), obj.acqName)
% Rename Acq2P object because want to create SI meta struct for processed TIFFs:
newObjName = sprintf('Acq_%s.mat', obj.acqName);
movefile(fullfile(obj.defaultDir, [obj.acqName '.mat']), fullfile(obj.defaultDir, newObjName));
fprintf('Renamed file to: %s\n', newObjName);
display('Motion Correction Completed!')


if ~exist(fullfile(obj.defaultDir, 'Raw'), 'dir')
    mkdir(fullfile(obj.defaultDir, 'Raw'));
end

for movidx=1:length(obj.Movies)
    [datadir, fname, ext] = fileparts(obj.Movies{movidx});
    movefile(obj.Movies{movidx}, fullfile(obj.defaultDir, 'Raw', strcat(fname, ext)));
end

%movefile(fullfile(obj.defaultDir, strcat(obj.acqName, '.mat')), fullfile(obj.defaultDir, 'Corrected', strcat(obj.acqName, '.mat')));

%info = load(fullfile(obj.defaultDir, 'Corrected', strcat(obj.acqName, '.mat')))

%interleaveTiffs(obj, false); %, info);

end

function movFileName = defaultNamingFunction(acqName, nSlice, nChannel, movNum)

movFileName = sprintf('%s_Slice%02.0f_Channel%02.0f_File%03.0f.tif',...
    acqName, nSlice, nChannel, movNum);
end                                                                                                                                
