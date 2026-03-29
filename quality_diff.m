% PSNR comparison between NTSS and EBMA decoded frames

function quality_diff(current_frames, ntss_predicted, ebma_predicted)

num_frames = numel(current_frames);
ntss_psnr  = zeros(1, num_frames);
ebma_psnr  = zeros(1, num_frames);

for k = 1:num_frames
    orig         = current_frames{k};
    ntss_psnr(k) = 10 * log10(255^2 / mean(mean((orig - ntss_predicted{k}).^2)));
    ebma_psnr(k) = 10 * log10(255^2 / mean(mean((orig - ebma_predicted{k}).^2)));
end

fprintf('\n--- PSNR Summary (%d frame(s)) ---\n', num_frames);
fprintf('%-6s  %10s  %10s  %10s\n', 'Method', 'Mean (dB)', 'Min (dB)', 'Max (dB)');
fprintf('%-6s  %10.2f  %10.2f  %10.2f\n', 'NTSS', mean(ntss_psnr), min(ntss_psnr), max(ntss_psnr));
fprintf('%-6s  %10.2f  %10.2f  %10.2f\n', 'EBMA', mean(ebma_psnr), min(ebma_psnr), max(ebma_psnr));

delta = mean(ebma_psnr) - mean(ntss_psnr);
if delta >= 0
    fprintf('\nEBMA is %.2f dB higher than NTSS on average.\n\n', delta);
else
    fprintf('\nWarning: NTSS is %.2f dB higher than EBMA — check results.\n\n', -delta);
end

figure;
plot(1:num_frames, ntss_psnr, 'b-o', 'DisplayName', 'NTSS'); hold on;
plot(1:num_frames, ebma_psnr, 'r-s', 'DisplayName', 'EBMA'); hold off;
xlabel('Frame index');
ylabel('PSNR (dB)');
title('Reconstruction Quality: NTSS vs. EBMA');
legend('Location', 'best');
grid on;
xticks(1:num_frames);

end
