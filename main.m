% MAIN  Video encoder — runs NTSS and/or EBMA on an input video or image pair.
%
% Usage:
%   main(input_path, search_type)
%
%   input_path   path to a video (.mp4 .avi .mov .mpg), a single image
%                (.tif .png .jpg .bmp), or a folder of images.
%                For a single image, the next sequentially numbered image
%                in the same folder is automatically used as frame 2.
%
%   search_type  'ntss'  — New Three-Step Search only
%                'ebma'  — Exhaustive Block Matching only
%                'both'  — run both and compare
%
% Examples:
%   main('flower.mpg', 'ntss')
%   main('train01.tif', 'both')
%   main('frames/', 'ebma')
%
% GOP structure: IPPPP repeating — one I-frame every 5 frames.
%   I-frames are transmitted raw (no prediction).
%   P-frames are predicted from the previous decoded frame.
%   The residual of each P-frame is DCT-quantized before transmission.

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

N        = 16;  % block size in pixels
Q        = 10;  % DCT quantization step for residual (larger = more compression)
gop_size = 5;   % IPPPP: I-frame at positions 1, 6, 11, ...

% --- Load frames -----------------------------------------------------------

all_frames = io_processing(input_path, 'load');

if numel(all_frames) == 1
    second = find_next_image(input_path);
    if ~isempty(second)
        fprintf('Single image input — loading "%s" as frame 2.\n', second);
        all_frames = [all_frames, io_processing(second, 'load')];
    end
end

if numel(all_frames) < 2
    error('Need at least 2 frames. Got %d from: %s', numel(all_frames), input_path);
end

num_frames = numel(all_frames);
fprintf('Loaded %d frame(s) from "%s".\n\n', num_frames, input_path);

% --- Allocate result arrays (indexed over all frames) ----------------------

ntss_decoded      = cell(1, num_frames);
ebma_decoded      = cell(1, num_frames);
ntss_psnr         = zeros(1, num_frames);   % Inf for I-frames (perfect)
ebma_psnr         = zeros(1, num_frames);
ntss_sad          = zeros(1, num_frames);   % 0 for I-frames
ebma_sad          = zeros(1, num_frames);
ntss_coeff_counts = zeros(1, num_frames);   % 0 for I-frames
ebma_coeff_counts = zeros(1, num_frames);
ntss_mvs          = cell(1, num_frames);
ebma_mvs          = cell(1, num_frames);
ntss_predicted    = cell(1, num_frames);
ebma_predicted    = cell(1, num_frames);

ntss_ref = [];  % reference frame for NTSS (updated each decoded frame)
ebma_ref = [];  % reference frame for EBMA (separate — decoded frames differ)

% --- Per-frame encoding loop -----------------------------------------------

for k = 1:num_frames
    curr = all_frames{k};

    if mod(k-1, gop_size) == 0
        % I-frame: transmit raw, reset the reference for both algorithms.
        % No motion estimation or quantization is performed.
        ntss_decoded{k} = curr;
        ebma_decoded{k} = curr;
        ntss_psnr(k)    = Inf;
        ebma_psnr(k)    = Inf;
        ntss_ref        = curr;
        ebma_ref        = curr;
        fprintf('Frame %d / %d  [I-frame]\n', k, num_frames);

    else
        % P-frame: find best-match blocks in reference, quantize residual.
        fprintf('Frame %d / %d  [P-frame]\n', k, num_frames);

        if strcmp(search_type, 'ntss') || strcmp(search_type, 'both')
            [predicted, ntss_mvs{k}, ~, ntss_sad(k)] = ntss(ntss_ref, curr, N);
            ntss_predicted{k} = predicted;

            % Quantize the residual and reconstruct
            [recon_res, ntss_coeff_counts(k)] = quantize_residual(curr - predicted, Q);
            ntss_decoded{k} = min(max(predicted + recon_res, 0), 255);

            % PSNR of the fully decoded frame (prediction + residual)
            ntss_psnr(k) = 10 * log10(255^2 / mean(mean((curr - ntss_decoded{k}).^2)));

            % Use the decoded frame as reference for the next frame
            ntss_ref = ntss_decoded{k};
        end

        if strcmp(search_type, 'ebma') || strcmp(search_type, 'both')
            [predicted, ebma_mvs{k}, ~, ebma_sad(k)] = ebma(ebma_ref, curr, N);
            ebma_predicted{k} = predicted;

            [recon_res, ebma_coeff_counts(k)] = quantize_residual(curr - predicted, Q);
            ebma_decoded{k} = min(max(predicted + recon_res, 0), 255);

            ebma_psnr(k) = 10 * log10(255^2 / mean(mean((curr - ebma_decoded{k}).^2)));
            ebma_ref     = ebma_decoded{k};
        end
    end
end

% --- Summary ---------------------------------------------------------------

p_mask = (mod((1:num_frames)-1, gop_size) ~= 0);  % true for P-frames
num_i  = sum(~p_mask);
num_p  = sum(p_mask);

fprintf('\n=== Encoder Summary ===\n');
fprintf('Input        : %s\n', input_path);
fprintf('Frames       : %d total (%d I-frames, %d P-frames)\n', num_frames, num_i, num_p);
fprintf('Settings     : block=%dx%d  Q=%d  GOP=IPPPP(%d)\n', N, N, Q, gop_size);

if strcmp(search_type, 'ntss') || strcmp(search_type, 'both')
    fprintf('\nNTSS  —  SAD ops: %d  |  Mean PSNR: %.2f dB  |  DCT coeffs: %d\n', ...
        sum(ntss_sad(p_mask)), mean(ntss_psnr(p_mask)), sum(ntss_coeff_counts));
end
if strcmp(search_type, 'ebma') || strcmp(search_type, 'both')
    fprintf('EBMA  —  SAD ops: %d  |  Mean PSNR: %.2f dB  |  DCT coeffs: %d\n', ...
        sum(ebma_sad(p_mask)), mean(ebma_psnr(p_mask)), sum(ebma_coeff_counts));
end
if strcmp(search_type, 'both')
    sad_red   = 100 * (1 - sum(ntss_sad(p_mask))      / sum(ebma_sad(p_mask)));
    coeff_red = 100 * (1 - sum(ntss_coeff_counts)      / max(sum(ebma_coeff_counts), 1));
    psnr_d    = mean(ebma_psnr(p_mask)) - mean(ntss_psnr(p_mask));
    fprintf('\nNTSS used %.1f%% fewer SAD ops and %.1f%% fewer DCT coefficients than EBMA.\n', ...
        sad_red, coeff_red);
    fprintf('PSNR difference (EBMA - NTSS): %.2f dB\n', psnr_d);
end
fprintf('========================\n\n');

% --- Motion vector plot for first P-frame ----------------------------------

first_p = find(p_mask, 1);

if strcmp(search_type, 'ntss') || strcmp(search_type, 'both')
    figure;
    imshow(uint8(ntss_decoded{first_p})); hold on;
    mv = ntss_mvs{first_p};
    quiver(mv(:,1), mv(:,2), mv(:,3), mv(:,4), 0, 'y');
    title(sprintf('NTSS — frame %d motion vectors', first_p)); hold off;
end

if strcmp(search_type, 'ebma') || strcmp(search_type, 'both')
    figure;
    imshow(uint8(ebma_decoded{first_p})); hold on;
    mv = ebma_mvs{first_p};
    quiver(mv(:,1), mv(:,2), mv(:,3), mv(:,4), 0, 'y');
    title(sprintf('EBMA — frame %d motion vectors', first_p)); hold off;
end

% --- Residual figures ------------------------------------------------------

if strcmp(search_type, 'ntss') || strcmp(search_type, 'both')
    residual = all_frames{first_p} - ntss_predicted{first_p};
    figure;
    imshow(residual, []);
    title(sprintf('NTSS — frame %d residual', first_p));
end

if strcmp(search_type, 'ebma') || strcmp(search_type, 'both')
    residual = all_frames{first_p} - ebma_predicted{first_p};
    figure;
    imshow(residual, []);
    title(sprintf('EBMA — frame %d residual', first_p));
end

% --- Comparison analysis (only when both algorithms ran) -------------------

if strcmp(search_type, 'both')
    p_orig = all_frames(p_mask);
    quality_diff(p_orig, ntss_decoded(p_mask), ebma_decoded(p_mask));
    compression_diff(all_frames, ntss_coeff_counts, ebma_coeff_counts, gop_size, N);
    visual_diff(p_orig{1}, ntss_decoded{first_p}, ebma_decoded{first_p}, first_p);
end

% --- Save output video(s) --------------------------------------------------

[~, base, ~] = fileparts(input_path);
if strcmp(search_type, 'ntss') || strcmp(search_type, 'both')
    io_processing([base '_ntss.mp4'], 'save', ntss_decoded);
end
if strcmp(search_type, 'ebma') || strcmp(search_type, 'both')
    io_processing([base '_ebma.mp4'], 'save', ebma_decoded);
end

end

% ---------------------------------------------------------------------------
% Find the next sequentially numbered image file.
% E.g. 'train01.tif' -> 'train02.tif'. Returns '' if none found.
% ---------------------------------------------------------------------------
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
