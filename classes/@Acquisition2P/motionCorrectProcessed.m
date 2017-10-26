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
    %fieldnames(scanImageMetadata)

    %[~, scanImageMetadata] = tiffReadMeta(fullfile(parentDir, origMovies{movNum}));
    % but movie file comes from processed tiff:
    fprintf('Curr movie is: %s\n', obj.Movies{movNum});
    if strfind(scanImageMetadata.SI.VERSION_MAJOR, '2016')
        [mov, ~] = tiffRead(obj.Movies{movNum});
        %mov = read_file(obj.Movies{movNum});
    else
        mov = read_imgdata(obj.Movies{movNum});
    end

    fprintf('Mov size is: %s\n.', mat2str(size(mov)));
    fprintf('Mov type is: %s\n.', class(mov));

    fprintf('Pixels Per Line: %i\n', scanImageMetadata.SI.hRoiManager.pixelsPerLine)
    fprintf('Lines Per Frame: %i\n', scanImageMetadata.SI.hRoiManager.linesPerFrame)
%     if size(mov,2)~=scanImageMetadata.SI.hRoiManager.pixelsPerLine
%         fprintf('Cropping pixels per line to %i\n', size(mov,2));
%         scanImageMetadata.SI.hRoiManager.pixelsPerLine = size(mov,2);
%     end
%     if size(mov,1)~=scanImageMetadata.SI.hRoiManager.linesPerFrame
%         fprintf('Cropping lines per frame to %i\n', size(mov,1));
%         scanImageMetadata.SI.hRoiManager.linesPerFrame = size(mov,1);
%     end

    if obj.binFactor > 1
        mov = binSpatial(mov, obj.binFactor);
    end

    % Adjust SI meta to match true data:
    scanImageMetadata = adjust_si_metadata(scanImageMetadata, size(mov));


    % Apply line shift:
    fprintf('Line Shift Correcting Movie #%03.0f of #%03.0f\n', movNum, nMovies),
    mov = correctLineShift(mov);
    fprintf('Finished Line-Shift correction. Movie size is: %s\n', mat2str(size(mov)));
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
            catch
                % Sometimes, disk access fails due to intermittent
                % network problem. In that case, wait and re-try once:
                pause(60);
                tiffWrite(movStruct.slice(nSlice).channel(nChannel).mov, movFileName, writeDir, 'int16');
            end
        end
    end

    obj.metaDataSI{movNum} = scanImageMetadata; % Store adjusted SI metadata for EACH file
end

%Assign acquisition to a variable with its own name, and write to same directory
eval([obj.acqName ' = obj;']),

% Rename Acq2P object because want to create SI meta struct for processed TIFFs:
%newobjname = sprintf('Acq2p_%s.mat', obj.acqname);
[parentdir, outputfolder, ~] = fileparts(writeDir);
newobjname = sprintf('%s.mat', outputfolder);
save(fullfile(obj.defaultDir, newObjName), obj.acqName)

%movefile(fullfile(obj.defaultDir, [obj.acqName '.mat']), fullfile(obj.defaultDir, newObjName));
fprintf('Renamed Acq2P obj file to: %s\n', newObjName);
display('Motion Correction Completed!')

end

function movFileName = defaultNamingFunction(acqName, nSlice, nChannel, movNum)

movFileName = sprintf('%s_Slice%02.0f_Channel%02.0f_File%03.0f.tif',...
    acqName, nSlice, nChannel, movNum);
end                                                                                                                                
