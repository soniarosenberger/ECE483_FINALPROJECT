% NTSS  New Three-Step Search block motion estimation.
% Ref: Li, Zeng & Liou (1994), IEEE Trans. Circuits Syst. Video Technol.
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
%
% Algorithm overview:
%   Stage 1  — check 17 candidates: center + 8 S=1 neighbors + 8 S=4 points.
%   Decision — if best is at center:      first-step stop  (done).
%              if best is an S=1 neighbor: half-way stop   (Stage 2).
%              if best is an S=4 point:    full TSS        (Stage 3).
%   Stage 2  — S=1 neighborhood around Stage-1 best (skipping already-checked points).
%   Stage 3  — S=2 search then S=1 search, both from the Stage-1 best.

function [predicted_frame, motion_vectors, psnr_val, sad_count] = ntss(reference_frame, current_frame, N)

[height, width] = size(current_frame);
predicted_frame = zeros(height, width);
motion_vectors  = [];
sad_count       = 0;

% Candidate offsets for each stage.
% Rows are (dx, dy) pairs relative to the current search center.
stage1 = [ 0, 0;                                    % center
          -1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1;   % S=1 ring
          -4,-4; -4,0; -4,4; 0,-4; 0,4; 4,-4; 4,0; 4,4];  % S=4 ring

stage2 = [ 0, 0; -1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1];  % S=1 ring

stage3a = [ 0, 0; -2,-2; -2,0; -2,2; 0,-2; 0,2; 2,-2; 2,0; 2,2];  % S=2 ring
stage3b = [ 0, 0; -1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1];  % S=1 ring

for i = 1:N:width-N+1
    for j = 1:N:height-N+1

        best_sad = inf;
        dx = 0;
        dy = 0;

        curr_block = current_frame(j:j+N-1, i:i+N-1);

        % visited(q+8, p+8) tracks which offsets have been evaluated.
        % The +8 offset maps the search range [-7, +7] to indices [1, 15].
        visited = false(15, 15);

        % Stage 1: evaluate all 17 candidates
        for k = 1:size(stage1, 1)
            p = stage1(k, 1);
            q = stage1(k, 2);
            [best_sad, dx, dy, sad_count, visited] = ...
                evaluate(reference_frame, curr_block, i, j, p, q, N, width, height, ...
                         best_sad, dx, dy, sad_count, visited);
        end

        % Decision: which search path to take
        if dx == 0 && dy == 0
            % Best match is already at center — no further search needed.

        elseif abs(dx) + abs(dy) <= 2
            % Best is an S=1 neighbor — do one more S=1 refinement (Stage 2).
            for k = 1:size(stage2, 1)
                p = stage2(k, 1);
                q = stage2(k, 2);
                if ~visited(q+8, p+8)
                    [best_sad, dx, dy, sad_count, visited] = ...
                        evaluate(reference_frame, curr_block, i, j, p, q, N, width, height, ...
                                 best_sad, dx, dy, sad_count, visited);
                end
            end

        else
            % Best is an S=4 point — run full TSS: S=2 then S=1 from that point.

            % Stage 3a: S=2 search centered on Stage-1 best
            for k = 1:size(stage3a, 1)
                p = dx + stage3a(k, 1);
                q = dy + stage3a(k, 2);
                if p >= -7 && p <= 7 && q >= -7 && q <= 7 && ~visited(q+8, p+8)
                    [best_sad, dx, dy, sad_count, visited] = ...
                        evaluate(reference_frame, curr_block, i, j, p, q, N, width, height, ...
                                 best_sad, dx, dy, sad_count, visited);
                end
            end

            % Stage 3b: S=1 search centered on Stage-3a best
            for k = 1:size(stage3b, 1)
                p = dx + stage3b(k, 1);
                q = dy + stage3b(k, 2);
                if p >= -7 && p <= 7 && q >= -7 && q <= 7 && ~visited(q+8, p+8)
                    [best_sad, dx, dy, sad_count, visited] = ...
                        evaluate(reference_frame, curr_block, i, j, p, q, N, width, height, ...
                                 best_sad, dx, dy, sad_count, visited);
                end
            end
        end

        % Copy the best-matching reference block into the predicted frame
        predicted_frame(j:j+N-1, i:i+N-1) = ...
            reference_frame(j+dy:j+dy+N-1, i+dx:i+dx+N-1);

        motion_vectors = [motion_vectors; i j dx dy]; %#ok<AGROW>
    end
end

psnr_val = 10 * log10(255^2 / mean(mean((current_frame - predicted_frame).^2)));

end

% ---------------------------------------------------------------------------
% Evaluate one candidate offset (p, q) for block at (i, j).
% Updates best_sad, dx, dy, sad_count, and visited if the candidate is valid
% and within frame bounds.
% ---------------------------------------------------------------------------
function [best_sad, dx, dy, sad_count, visited] = ...
    evaluate(ref_frame, curr_block, i, j, p, q, N, W, H, best_sad, dx, dy, sad_count, visited)

ri = i + p;
rj = j + q;

if ri >= 1 && rj >= 1 && ri+N-1 <= W && rj+N-1 <= H
    ref_block = ref_frame(rj:rj+N-1, ri:ri+N-1);
    sad = sum(sum(abs(curr_block - ref_block)));
    sad_count = sad_count + 1;
    visited(q+8, p+8) = true;
    if sad < best_sad
        best_sad = sad;
        dx = p;
        dy = q;
    end
end

end
