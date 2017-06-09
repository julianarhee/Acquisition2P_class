function interleaveTiffs(obj, info)

    nslices = length(info.(obj.acqName).correctedMovies.slice);
    nchannels = length(info.(obj.acqName).correctedMovies.slice(1).channel);
    nfiles = length(info.(obj.acqName).correctedMovies.slice(1).channel(1).fileName);

    movsize = info.(obj.acqName).correctedMovies.slice(1).channel(1).size(1,:);
    nframes = nslices*movsize(3)*nchannels;


    for file=1:nfiles
        newtiff = zeros(movsize(1), movsize(2), nframes);
        for slice = 1:nslices
            currtiff = info.(obj.acqName).correctedMovies.slice(slice).channel(1).fileName{file};
            [newtiff(:,:,slice:(nslices*2):end), ~] = tiffRead(currtiff);
            currtiff = info.(obj.acqName).correctedMovies.slice(slice).channel(2).fileName{file};
            [newtiff(:,:,(slice+1):(nslices*2):end), ~] = tiffRead(currtiff);
        end
        [fpath, fname, fext] = fileparts(info.(obj.acqName).correctedMovies.slice(slice).channel(1).fileName{file});
        filename = strsplit(fname, '_');
        newtiffname = strcat(filename{end}, fext)
        tiffWrite(newtiff, newtiffname, obj.defaultDir, 'int16');
    end 
    

end
