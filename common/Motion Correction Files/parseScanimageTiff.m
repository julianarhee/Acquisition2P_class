function [movStruct, nSlices, nChannels] = parseScanimageTiff(mov, siStruct)

% Check for scanimage version before extracting metainformation
if isfield(siStruct, 'SI4')
    siStruct = siStruct.SI4;
    % Nomenclature: frames and slices refer to the concepts used in
    % ScanImage.
    fZ              = siStruct.fastZEnable;
    nChannels       = numel(siStruct.channelsSave);
    nSlices         = siStruct.stackNumSlices + (fZ*siStruct.fastZDiscardFlybackFrames); % Slices are acquired at different locations (e.g. depths).
elseif isfield(siStruct,'SI5')
     siStruct = siStruct.SI5;
    % Nomenclature: frames and slices refer to the concepts used in
    % ScanImage.
    fZ              = siStruct.fastZEnable;
    nChannels       = numel(siStruct.channelsSave);
    nSlices         = siStruct.stackNumSlices + (fZ*siStruct.fastZDiscardFlybackFrames); % Slices are acquired at different locations (e.g. depths).

elseif isfield(siStruct,'SI') % JYR 01/04/2017 -- SI 2016 
     siStruct = siStruct.SI;
    % Nomenclature: frames and slices refer to the concepts used in
    % ScanImage.
    fZ              = siStruct.hFastZ.enable; %siStruct.fastZEnable;
    nChannels       = numel(siStruct.hChannels.channelSave); %numel(siStruct.channelsSave);
    nSlices         = siStruct.hStackManager.numSlices + (fZ*siStruct.hFastZ.numDiscardFlybackFrames); % Slices are acquired at different locations (e.g. depths).
    
elseif isfield(siStruct, 'software') && siStruct.software.version < 4 %ie it's a scanimage 3 file
    fZ = 0;
    nSlices = 1;
    nChannels = siStruct.acq.numberOfChannelsSave;
else
    error('Movie is from an unidentified scanimage version, or metadata is improperly formatted'),
end


% Copy data into structure:
if nSlices>1
    if strcmp(siStruct.VERSION_MAJOR, '2016') % need this if clause for 2016
        discard = (fZ*siStruct.hFastZ.numDiscardFlybackFrames);
    else
        discard = (fZ*siStruct.fastZDiscardFlybackFrames);
    end
    for sl = 1:nSlices-discard % Slices, removing flyback.
        for ch = 1:nChannels % Channels
            frameInd = ch + (sl-1)*nChannels;
            movStruct.slice(sl).channel(ch).mov = mov(:, :, frameInd:(nSlices*nChannels):end);
        end
    end
    nSlices = nSlices - discard; %nSlices-(fZ*siStruct.fastZDiscardFlybackFrames);
else
    for sl = 1;
        for ch = 1:nChannels % Channels
            frameInd = ch + (sl-1)*nChannels;
            movStruct.slice(sl).channel(ch).mov = mov(:, :, frameInd:(nSlices*nChannels):end);
        end
    end
end