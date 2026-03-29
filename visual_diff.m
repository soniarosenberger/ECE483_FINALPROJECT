% side-by-side comparison: original vs NTSS vs EBMA
% pass cell arrays to animate through multiple frames

function visual_diff(original, ntss_decoded, ebma_decoded, frame_idx)

if iscell(original)
    for k = 1:numel(original)
        show_frame(original{k}, ntss_decoded{k}, ebma_decoded{k}, k);
        if k < numel(original)
            pause(0.5);
        end
    end
else
    if nargin < 4 || isempty(frame_idx)
        frame_idx = 1;
    end
    show_frame(original, ntss_decoded, ebma_decoded, frame_idx);
end

end

function show_frame(orig, ntss_dec, ebma_dec, idx)

figure;
subplot(1,3,1); imshow(uint8(orig));     title('Original');
subplot(1,3,2); imshow(uint8(ntss_dec)); title('NTSS decoded');
subplot(1,3,3); imshow(uint8(ebma_dec)); title('EBMA decoded');
sgtitle(sprintf('Frame %d', idx));

end
