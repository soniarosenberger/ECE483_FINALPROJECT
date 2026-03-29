% estimates compressed size for NTSS vs EBMA and plots a comparison
%
% size model:
%   I-frames : H*W bytes (raw)
%   P-frames : 2 bytes/block (motion vectors) + 2 bytes/non-zero DCT coefficient

function compression_diff(original_frames, ntss_coeff_counts, ebma_coeff_counts, gop_size, N)

num_frames = numel(original_frames);
[H, W]     = size(original_frames{1});

i_mask = (mod((1:num_frames)-1, gop_size) == 0);
p_mask = ~i_mask;
num_i  = sum(i_mask);
num_p  = sum(p_mask);

total_raw  = H * W * num_frames;
i_bytes    = H * W * num_i;
mv_bytes   = floor(H/N) * floor(W/N) * 2 * num_p;

ntss_total = i_bytes + mv_bytes + sum(ntss_coeff_counts) * 2;
ebma_total = i_bytes + mv_bytes + sum(ebma_coeff_counts) * 2;
ntss_ratio = total_raw / max(ntss_total, 1);
ebma_ratio = total_raw / max(ebma_total, 1);

fprintf('\n--- Compression Summary (%d frames: %d I, %d P) ---\n', num_frames, num_i, num_p);
fprintf('%-22s  %12s  %8s\n', 'Method', 'Size (bytes)', 'Ratio');
fprintf('%-22s  %12d  %8.2fx\n', 'Uncompressed',  total_raw,  1.0);
fprintf('%-22s  %12d  %8.2fx\n', 'NTSS (MV+DCT)', ntss_total, ntss_ratio);
fprintf('%-22s  %12d  %8.2fx\n', 'EBMA (MV+DCT)', ebma_total, ebma_ratio);
fprintf('\nDCT coefficients — NTSS: %d  |  EBMA: %d\n\n', sum(ntss_coeff_counts), sum(ebma_coeff_counts));

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
