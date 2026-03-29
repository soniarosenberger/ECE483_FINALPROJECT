% IO_PROCESSING  Load or save frames for the video encoder.
%
% Load mode — returns a cell array of double grayscale frames:
%   frames = io_processing(input_path, 'load')
%
%   input_path can be:
%     a video file   (.mp4 .avi .mov .mpg .mpeg)
%     an image file  (.tif .png .jpg .bmp)
%     a directory    (loads all images inside, sorted by name)
%
% Save mode — writes frames to an mp4 or avi file:
%   io_processing(output_path, 'save', frames)

function frames = io_processing(input_path, mode, save_frames)

if strcmp(mode, 'load')
    frames = load_frames(input_path);

elseif strcmp(mode, 'save')
    if nargin < 3
        error('Save mode requires a frames cell array as the third argument.');
    end
    save_video(input_path, save_frames);
    frames = {};

else
    error('Unknown mode "%s". Use ''load'' or ''save''.', mode);
end

end

% ---------------------------------------------------------------------------

function frames = load_frames(input_path)

if ~exist(input_path, 'file') && ~exist(input_path, 'dir')
    error('Path not found: %s', input_path);
end

frames = {};

if exist(input_path, 'dir')
    % Load all images from the directory in sorted order
    exts  = {'*.tif','*.tiff','*.png','*.jpg','*.jpeg','*.bmp'};
    files = [];
    for e = 1:numel(exts)
        files = [files; dir(fullfile(input_path, exts{e}))]; %#ok<AGROW>
    end
    if isempty(files)
        error('No supported image files found in: %s', input_path);
    end
    [~, order] = sort({files.name});
    files = files(order);
    for k = 1:numel(files)
        frames{end+1} = to_gray_double(imread(fullfile(files(k).folder, files(k).name))); %#ok<AGROW>
    end

else
    [~, ~, ext] = fileparts(input_path);
    video_exts  = {'.avi', '.mp4', '.mov', '.m4v', '.mkv', '.mpg', '.mpeg'};

    if any(strcmp(lower(ext), video_exts))
        % Read all frames from the video file
        vr = VideoReader(input_path);
        while hasFrame(vr)
            frames{end+1} = to_gray_double(readFrame(vr)); %#ok<AGROW>
        end
        if isempty(frames)
            error('No frames read from: %s', input_path);
        end
    else
        % Single image
        frames{1} = to_gray_double(imread(input_path));
    end
end

end

% ---------------------------------------------------------------------------

function img = to_gray_double(img)
if size(img, 3) == 3
    img = rgb2gray(img);
end
img = double(img);
end

% ---------------------------------------------------------------------------

function save_video(output_path, frames)

if isempty(frames)
    error('Cannot save — frames cell array is empty.');
end

[~, ~, ext] = fileparts(output_path);
if strcmpi(ext, '.mp4')
    profile = 'MPEG-4';
else
    profile = 'Motion JPEG AVI';
end

vw = VideoWriter(output_path, profile);
vw.FrameRate = 25;
open(vw);
for k = 1:numel(frames)
    writeVideo(vw, uint8(frames{k}));
end
close(vw);

fprintf('Saved %d frames to %s\n', numel(frames), output_path);

end
