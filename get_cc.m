

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

%% Get CC images for each slice and run:

% tiff_path = '/nas/volume1/2photon/RESDATA/20161222_JR030W_gratings1/Corrected/';
tiff_path = '/nas/volume1/2photon/RESDATA/20161222_JR030W_rsvp1/Corrected/';

traces_path = '/nas/volume1/2photon/RESDATA/20161222_JR030W_rsvp1/CC/';
tiffs = dir(strcat(tiff_path, '*Channel01*'));

sframe=1;
for tiff=1:length(tiffs)
    curr_tiff = tiffs(tiff).name;
    curr_tiff_path = strcat(tiff_path, curr_tiff);

    Y = bigread2(curr_tiff_path,sframe);

    %Y = Y - min(Y(:)); 
    if ~isa(Y,'double');    Y = double(Y);  end         % convert to single

    [d1,d2,T] = size(Y);                                % dimensions of dataset
    d = d1*d2;                                          % total number of pixels

    [cc]=CrossCorrImage(Y);
    cc_fn = strcat(traces_path, 'cc_', curr_tiff(1:end-4), '.png');
    imwrite(cc, cc_fn);
end


%%
% 
% slice_path = '/nas/volume1/2photon/RESDATA/20161222_JR030W_gratings1/slice10/';
% avgimg_fn = 'AVG_fov1_gratings_10reps_run1_Slice10_Channel01_File001_scaled.tif';
% tseries_fn = 'fov1_gratings_10reps_run1_Slice10_Channel01_File001_scaled.tif';

slice_path = '/nas/volume1/2photon/RESDATA/20161222_JR030W_gratings1/fov1_gratings_10reps_run1_slice6_00009/'
avgimg_fn = 'AVG_fov1_gratings_10reps_run1_Slice06_Channel01_File009_scaled.tif';
corrected_path = '/nas/volume1/2photon/RESDATA/20161222_JR030W_gratings1/Corrected/';
tseries_fn = 'fov1_gratings_10reps_run1_Slice06_Channel01_File009_scaled.tif';

% get average:
avgimg = imread(strcat(slice_path, avgimg_fn));
avgimg = mat2gray(avgimg);
imshow(avgimg)

% choose ROIs:
masks=ROIselect_circle(avgimg);

% load movie:
sframe=1;
Y = bigread2(strcat(slice_path, tseries_fn),sframe);
if ~isa(Y,'double');    Y = double(Y);  end
nframes = size(Y,3);

% extract raw traces:
raw_traces = zeros(size(masks,3), size(Y,3));
for r=1:size(masks,3)
    curr_mask = masks(:,:,r);
    Y_masked = zeros(1,size(Y,3));
    for t=1:size(Y,3)
        t_masked = curr_mask.*Y(:,:,t);
        Y_masked(t) = sum(t_masked(:));
    end
    raw_traces(r,:,:) = Y_masked;
end

figure()
for rtrace=1:size(raw_traces,1)
    plot(raw_traces(rtrace,:), 'color', rand(1,3))
    hold on;
end

% high-pass filter traces:
winsize = 25;
traces = zeros(size(raw_traces));
for rtrace=1:size(raw_traces,1)
    
    curr_trace = raw_traces(rtrace,:);
    s1 = smooth(curr_trace, winsize, 'rlowess');
    t1 = curr_trace' - s1;
    
%     figure()
%     subplot(1,2,1)
%     plot(curr_trace, 'k')
%     hold on
%     plot(s1, 'r')
%     subplot(1,2,2)
%     plot(t1, 'b')

    baseline = mean(curr_trace);
    deltaF = (curr_trace - baseline)./baseline; 
    
    traces(rtrace,:) = deltaF;
end

active_cells = [];
figure()
for rtrace=1:size(traces,1)
    if (max(traces(rtrace,:)) > 0.04)
        active_cells = [active_cells rtrace];
    end
    plot(traces(rtrace,:), 'color', rand(1,3))
    hold on;
end

% Plot active traces:

% GET ard_file_duration for current file: _0000x.tif
file_no = 9;
y_sec = [0:nframes-1].*(ard_file_durs(file_no)/nframes); % y_sec = [0:nframes-1]./acquisition_rate;

% GET MW rel times from match_triggers.py: 'rel_times'
mw_rel_times = rel_times/1000000; % convert to sec

figure();
for cell=1:length(active_cells)
   subplot(length(active_cells), 1, cell)

  % plot trace:
   %plot(y_sec, traces(active_cells(cell), :).*100, 'LineWidth', 2)
   %y1=get(gca,'ylim');
   hold on;
   
   %plot(mw_rel_times, zeros(size(mw_rel_times)), 'r*'); 
   for stim=1:2:length(mw_rel_times)-1
       sx = [mw_rel_times(stim) mw_rel_times(stim+1) mw_rel_times(stim+1) mw_rel_times(stim)];
       %sy = [y1(1) y1(1) y1(2) y1(2)];
       sy = [-0.1 -0.1 0.1 0.1].*100;
       patch(sx, sy, 'k', 'FaceAlpha', 0.2, 'EdgeAlpha', 0)
       hold on;
   end
   
   % plot trace:
   plot(y_sec, traces(active_cells(cell), :).*100, 'LineWidth', 2)
   
   title(['ROI #: ' num2str(active_cells(cell))]);
   hold on;
end
xlabel('time (s)')
ylabel('delta F / F (%)')


% Plot ROIs and show active cells:
figure()
nparts = strsplit(tseries_fn, '_');
figname = strcat(nparts(1), nparts(2), nparts(3), nparts(4), nparts(5), nparts(7));

RGBimg = zeros([size(avgimg),3]);
RGBimg(:,:,1)=0;
RGBimg(:,:,2)=avgimg;
RGBimg(:,:,3)=0;

numcells=size(masks,3);
for c=1:numcells
    RGBimg(:,:,3)=RGBimg(:,:,3)+0.5*masks(:,:,c);
    if ismember(c, active_cells)
        RGBimg(:,:,1)=RGBimg(:,:,1)+0.3*masks(:,:,c);
    end
end
imshow(RGBimg);
title(figname);
hold on;
for ac=1:numcells
    if ismember(ac, active_cells)
        [x,y] = find(masks(:,:,ac)==1,1);
        hold on;
        text(y,x,num2str(ac))
    end
end

% save traces and RBG image with ROIs:
D = struct;
D.masks = masks;
D.RGB = RGBimg;
D.active = active_cells;
D.traces = traces;
D.raw_traces = raw_traces;


