% EBMA  Exhaustive Block Matching Algorithm.
% Checks every candidate offset in the +-7 search window.
% Guaranteed to find the global minimum SAD — used as a quality baseline.
%
% Inputs:
%   reference_frame  double H x W  previous frame
%   current_frame    double H x W  frame to be predicted
%   N                block size in pixels (typically 16)
%
% Outputs:
%   predicted_frame  motion-compensated reconstruction of current_frame
%   motion_vectors   M x 4 matrix, one row per block: [x, y, dx, dy]
%   psnr_val         PSNR between current_frame and predicted_frame (dB)
%   sad_count        total number of SAD computations performed

function [predicted_frame, motion_vectors, psnr_val, sad_count] = ebma(reference_frame, current_frame, N)

[height, width] = size(current_frame);
predicted_frame = zeros(height, width);
motion_vectors  = [];
sad_count       = 0;

search_range = 7;

for i = 1:N:width-N+1
    for j = 1:N:height-N+1

        best_sad = inf;
        dx = 0;
        dy = 0;

        curr_block = current_frame(j:j+N-1, i:i+N-1);

        % Try every offset (p, q) in the search window
        for p = -search_range:search_range
            for q = -search_range:search_range
                ri = i + p;
                rj = j + q;
                if ri >= 1 && rj >= 1 && ri+N-1 <= width && rj+N-1 <= height
                    ref_block = reference_frame(rj:rj+N-1, ri:ri+N-1);
                    sad = sum(sum(abs(curr_block - ref_block)));
                    sad_count = sad_count + 1;
                    if sad < best_sad
                        best_sad = sad;
                        dx = p;
                        dy = q;
                    end
                end
            end
        end

        predicted_frame(j:j+N-1, i:i+N-1) = ...
            reference_frame(j+dy:j+dy+N-1, i+dx:i+dx+N-1);

        motion_vectors = [motion_vectors; i j dx dy]; %#ok<AGROW>
    end
end

psnr_val = 10 * log10(255^2 / mean(mean((current_frame - predicted_frame).^2)));

end
