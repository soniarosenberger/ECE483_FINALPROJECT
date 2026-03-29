% VISUAL_DIFF  Side-by-side display: original vs. NTSS vs. EBMA decoded frame.
%
% Single frame:
%   visual_diff(original, ntss_decoded, ebma_decoded, frame_idx)
%
% Multiple frames (animates with a 0.5 s pause between frames):
%   visual_diff(original_cell, ntss_cell, ebma_cell, [])
%
% Inputs:
%   original     double H x W frame  OR  cell array of frames
%   ntss_decoded double H x W frame  OR  cell array of frames
%   ebma_decoded double H x W frame  OR  cell array of frames
%   frame_idx    frame number shown in the title (use [] for cell array input)

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

% ---------------------------------------------------------------------------

function show_frame(orig, ntss_dec, ebma_dec, idx)

figure;

subplot(1, 3, 1);
imshow(uint8(orig));
title('Original');

subplot(1, 3, 2);
imshow(uint8(ntss_dec));
title('NTSS decoded');

subplot(1, 3, 3);
imshow(uint8(ebma_dec));
title('EBMA decoded');

sgtitle(sprintf('Frame %d', idx));

end
