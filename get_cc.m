

slice_dir = '/nas/volume1/2photon/RESDATA/TEFO/20161219_JR030W/fov6_rsvp_nomask_test_10trials_00002/ch1_slices/';
slice_no = 14;

slices = dir(strcat(slice_dir, '/*.tif'));

for i=1:length(slices)
    if findstr(strcat('#',num2str(slice_no),'.tif'), slices(i).name)
        curr_slice = slices(i);
    end
end

curr_slice_path = strcat(slice_dir, curr_slice.name);

curr_slice_source = '/media/juliana/Seagate Backup Plus Drive/RESDATA/20161218_CE024_highres/posterior1/posterior1_4/CH1/';
curr_slice_name = 'posterior1_Slice19_Channel01_File001.tif';
curr_slice_path = strcat(curr_slice_source, curr_slice_name);

Y = bigread2(curr_slice_path,sframe);

%Y = Y - min(Y(:)); 
if ~isa(Y,'double');    Y = double(Y);  end         % convert to single

[d1,d2,T] = size(Y);                                % dimensions of dataset
d = d1*d2;                                          % total number of pixels

[cc]=CrossCorrImage(Y);