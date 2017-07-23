function interleaveTiffs(obj, split_channels)
    if nargin<2
	split_channels = false;
    end
    if split_channels
	fprintf('Splitting channels bec big TIFF.\n');
    end
    nslices = length(obj.correctedMovies.slice);
    nchannels = length(obj.correctedMovies.slice(1).channel);
    fprintf('Interleaving %i channels and %i slices.\n', nchannels, nslices);
    nfiles = length(obj.correctedMovies.slice(1).channel(1).fileName);

    movsize = obj.correctedMovies.slice(1).channel(1).size(1,:);
    nframes = nslices*movsize(3)*nchannels;

    sliceidxs = 1:nchannels:nslices*nchannels;
    for file=1:nfiles
        newtiff = zeros(movsize(1), movsize(2), nframes);
        for slice = 1:nslices
            currtiff = obj.correctedMovies.slice(slice).channel(1).fileName{file};
            [tmp,~] = tiffRead(currtiff);
	    if nchannels==1
		newtiff(:,:,sliceidxs(slice):nslices:end) = tmp;
	    else % nchannels=2
                newtiff(:,:,sliceidxs(slice):(nslices*2):end) = tmp;
                currtiff = obj.correctedMovies.slice(slice).channel(2).fileName{file};
                [tmp,~] = tiffRead(currtiff); 
                newtiff(:,:,(sliceidxs(slice)+1):(nslices*2):end) = tmp;
	    end
        end
        [fpath, fname, fext] = fileparts(obj.correctedMovies.slice(slice).channel(1).fileName{file});
         filename = strsplit(fname, '_');
	if split_channels
	    for cidx=1:nchannels
	        newtiffname = strcat(filename{end}, sprintf('_Channel%02d', cidx), fext)
	       tiffWrite(newtiff(:,:,cidx:nchannels:end), newtiffname, obj.defaultDir);
	    end 
	else
            newtiffname = strcat(filename{end}, fext)
            tiffWrite(newtiff, newtiffname, obj.defaultDir); %, 'int16');
	end
    end 
    

end
