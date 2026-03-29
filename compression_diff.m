% COMPRESSION_DIFF  Estimate and compare compressed sizes for NTSS and EBMA.
%
% Compressed size model:
%   I-frames: H*W bytes (transmitted raw, no prediction)
%   P-frames: (motion vector bytes) + (DCT coefficient bytes)
%     Motion vectors : 2 bytes per block (1 byte each for dx, dy)
%     DCT residual   : 2 bytes per non-zero coefficient after quantization
%
% This gives a principled size estimate based on what actually needs to be
% transmitted, rather than a pixel-count proxy.
%
% Inputs:
%   original_frames    cell array of all frames (I + P, in sequence)
%   ntss_coeff_counts  vector of DCT coefficient counts per frame (0 for I-frames)
%   ebma_coeff_counts  same for EBMA
%   gop_size           frames per GOP (5 for IPPPP)
%   N                  block size — must match the value used in main.m

function compression_diff(original_frames, ntss_coeff_counts, ebma_coeff_counts, gop_size, N)

num_frames = numel(original_frames);
[H, W]     = size(original_frames{1});

i_mask = (mod((1:num_frames)-1, gop_size) == 0);
p_mask = ~i_mask;
num_i  = sum(i_mask);
num_p  = sum(p_mask);

% Uncompressed: 1 byte per pixel, every frame
total_raw = H * W * num_frames;

% I-frame bytes: full raw frame each
i_bytes = H * W * num_i;

% P-frame bytes: MV overhead + 2 bytes per surviving DCT coefficient
num_blocks    = floor(H/N) * floor(W/N);
mv_bytes      = num_blocks * 2 * num_p;

ntss_total = i_bytes + mv_bytes + sum(ntss_coeff_counts) * 2;
ebma_total = i_bytes + mv_bytes + sum(ebma_coeff_counts) * 2;

ntss_ratio = total_raw / max(ntss_total, 1);
ebma_ratio = total_raw / max(ebma_total, 1);

% Print summary
fprintf('\n--- Compression Summary (%d frames: %d I, %d P) ---\n', num_frames, num_i, num_p);
fprintf('%-22s  %12s  %8s\n', 'Method', 'Size (bytes)', 'Ratio');
fprintf('%-22s  %12d  %8.2fx\n', 'Uncompressed',  total_raw,  1.0);
fprintf('%-22s  %12d  %8.2fx\n', 'NTSS (MV+DCT)', ntss_total, ntss_ratio);
fprintf('%-22s  %12d  %8.2fx\n', 'EBMA (MV+DCT)', ebma_total, ebma_ratio);
fprintf('\nDCT coefficients — NTSS: %d  |  EBMA: %d\n\n', ...
    sum(ntss_coeff_counts), sum(ebma_coeff_counts));

% Bar chart
figure;
bar([total_raw, ntss_total, ebma_total]);
set(gca, 'XTickLabel', {'Uncompressed', 'NTSS', 'EBMA'});
ylabel('Total size (bytes)');
title('Compression: Uncompressed vs. NTSS vs. EBMA');
grid on;

hold on;
vals   = [total_raw, ntss_total, ebma_total];
ratios = [1.0, ntss_ratio, ebma_ratio];
for b = 1:3
    text(b, vals(b) * 1.02, sprintf('%.2fx', ratios(b)), 'HorizontalAlignment', 'center');
end
hold off;

end
