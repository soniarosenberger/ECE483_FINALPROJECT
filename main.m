% main(input_path, search_type)
% search_type: 'ntss', 'ebma', or 'both'
% input_path: video file, image file, or folder of images
%
% ex: main('flower.mpg', 'both')
%     main('train01.tif', 'ntss')

function main(input_path, search_type)

if nargin < 2
    error('Usage: main(input_path, search_type)');
end

if ~ismember(search_type, {'ntss', 'ebma', 'both'})
    error('search_type must be ''ntss'', ''ebma'', or ''both''.');
end

if ~exist(input_path, 'file') && ~exist(input_path, 'dir')
    error('Input not found: %s', input_path);
end

N        = 16;  % block size
sf       = 10;  % quantization scaling factor
gop_size = 5;   % I-frame every 5 frames (IPPPP)

all_frames = io_processing(input_path, 'load');

if numel(all_frames) == 1
    second = find_next_image(input_path);
    if ~isempty(second)
        fprintf('Single image — loading "%s" as frame 2.\n', second);
        all_frames = [all_frames, io_processing(second, 'load')];
    end
end

if numel(all_frames) < 2
    error('Need at least 2 frames. Got %d from: %s', numel(all_frames), input_path);
end

num_frames = numel(all_frames);
fprintf('Loaded %d frame(s) from "%s".\n\n', num_frames, input_path);

ntss_decoded      = cell(1, num_frames);
ebma_decoded      = cell(1, num_frames);
ntss_psnr         = zeros(1, num_frames);
ebma_psnr         = zeros(1, num_frames);
ntss_sad          = zeros(1, num_frames);
ebma_sad          = zeros(1, num_frames);
ntss_coeff_counts = zeros(1, num_frames);
ebma_coeff_counts = zeros(1, num_frames);
ntss_mvs          = cell(1, num_frames);
ebma_mvs          = cell(1, num_frames);
ntss_predicted    = cell(1, num_frames);
ebma_predicted    = cell(1, num_frames);

ntss_ref = [];
ebma_ref = [];

for k = 1:num_frames
    curr = all_frames{k};

    if mod(k-1, gop_size) == 0
        % I-frame: send raw, reset reference
        ntss_decoded{k} = curr;
        ebma_decoded{k} = curr;
        ntss_psnr(k)    = Inf;
        ebma_psnr(k)    = Inf;
        ntss_ref        = curr;
        ebma_ref        = curr;
        fprintf('Frame %d / %d  [I-frame]\n', k, num_frames);

    else
        fprintf('Frame %d / %d  [P-frame]\n', k, num_frames);

        if strcmp(search_type, 'ntss') || strcmp(search_type, 'both')
            [predicted, ntss_mvs{k}, ~, ntss_sad(k)] = ntss(ntss_ref, curr, N);
            ntss_predicted{k} = predicted;

            [recon_res, ntss_coeff_counts(k)] = quantize_residual(curr - predicted, sf);
            ntss_decoded{k} = min(max(predicted + recon_res, 0), 255);
            ntss_psnr(k)    = 10 * log10(255^2 / mean(mean((curr - ntss_decoded{k}).^2)));
            ntss_ref        = ntss_decoded{k};
        end

        if strcmp(search_type, 'ebma') || strcmp(search_type, 'both')
            [predicted, ebma_mvs{k}, ~, ebma_sad(k)] = ebma(ebma_ref, curr, N);
            ebma_predicted{k} = predicted;

            [recon_res, ebma_coeff_counts(k)] = quantize_residual(curr - predicted, sf);
            ebma_decoded{k} = min(max(predicted + recon_res, 0), 255);
            ebma_psnr(k)    = 10 * log10(255^2 / mean(mean((curr - ebma_decoded{k}).^2)));
            ebma_ref        = ebma_decoded{k};
        end
    end
end

p_mask = (mod((1:num_frames)-1, gop_size) ~= 0);
num_i  = sum(~p_mask);
num_p  = sum(p_mask);

fprintf('\n=== Encoder Summary ===\n');
fprintf('Input    : %s\n', input_path);
fprintf('Frames   : %d total (%d I, %d P)\n', num_frames, num_i, num_p);
fprintf('Settings : block=%dx%d  sf=%d  GOP=IPPPP(%d)\n', N, N, sf, gop_size);

if strcmp(search_type, 'ntss') || strcmp(search_type, 'both')
    fprintf('\nNTSS  —  SAD ops: %d  |  Mean PSNR: %.2f dB  |  DCT coeffs: %d\n', ...
        sum(ntss_sad(p_mask)), mean(ntss_psnr(p_mask)), sum(ntss_coeff_counts));
end
if strcmp(search_type, 'ebma') || strcmp(search_type, 'both')
    fprintf('EBMA  —  SAD ops: %d  |  Mean PSNR: %.2f dB  |  DCT coeffs: %d\n', ...
        sum(ebma_sad(p_mask)), mean(ebma_psnr(p_mask)), sum(ebma_coeff_counts));
end
if strcmp(search_type, 'both')
    sad_red   = 100 * (1 - sum(ntss_sad(p_mask)) / sum(ebma_sad(p_mask)));
    coeff_red = 100 * (1 - sum(ntss_coeff_counts) / max(sum(ebma_coeff_counts), 1));
    psnr_d    = mean(ebma_psnr(p_mask)) - mean(ntss_psnr(p_mask));
    fprintf('\nNTSS used %.1f%% fewer SAD ops and %.1f%% fewer DCT coefficients than EBMA.\n', sad_red, coeff_red);
    fprintf('PSNR difference (EBMA - NTSS): %.2f dB\n', psnr_d);
end
fprintf('========================\n\n');

% motion vector overlay and residual for first P-frame
first_p = find(p_mask, 1);

if strcmp(search_type, 'ntss') || strcmp(search_type, 'both')
    figure;
    imshow(uint8(ntss_decoded{first_p})); hold on;
    mv = ntss_mvs{first_p};
    quiver(mv(:,1), mv(:,2), mv(:,3), mv(:,4), 0, 'y');
    title(sprintf('NTSS — frame %d motion vectors', first_p)); hold off;

    figure;
    imshow(all_frames{first_p} - ntss_predicted{first_p}, []);
    title(sprintf('NTSS — frame %d residual', first_p));
end

if strcmp(search_type, 'ebma') || strcmp(search_type, 'both')
    figure;
    imshow(uint8(ebma_decoded{first_p})); hold on;
    mv = ebma_mvs{first_p};
    quiver(mv(:,1), mv(:,2), mv(:,3), mv(:,4), 0, 'y');
    title(sprintf('EBMA — frame %d motion vectors', first_p)); hold off;

    figure;
    imshow(all_frames{first_p} - ebma_predicted{first_p}, []);
    title(sprintf('EBMA — frame %d residual', first_p));
end

if strcmp(search_type, 'both')
    p_orig = all_frames(p_mask);
    quality_diff(p_orig, ntss_decoded(p_mask), ebma_decoded(p_mask));
    compression_diff(all_frames, ntss_coeff_counts, ebma_coeff_counts, gop_size, N);
    visual_diff(p_orig{1}, ntss_decoded{first_p}, ebma_decoded{first_p}, first_p);
end

[~, base, ~] = fileparts(input_path);
if strcmp(search_type, 'ntss') || strcmp(search_type, 'both')
    io_processing([base '_ntss.mp4'], 'save', ntss_decoded);
end
if strcmp(search_type, 'ebma') || strcmp(search_type, 'both')
    io_processing([base '_ebma.mp4'], 'save', ebma_decoded);
end

end

% given an image path like 'train01.tif', returns 'train02.tif' if it exists
function next = find_next_image(filepath)
next = '';
[folder, name, ext] = fileparts(filepath);

i = numel(name);
while i > 0 && name(i) >= '0' && name(i) <= '9'
    i = i - 1;
end
if i == numel(name); return; end

prefix    = name(1:i);
num_str   = name(i+1:end);
candidate = fullfile(folder, sprintf('%s%0*d%s', prefix, numel(num_str), str2double(num_str)+1, ext));

if exist(candidate, 'file')
    next = candidate;
end
end
