% New Three-Step Search motion estimator
% uses early exit to avoid unnecessary SAD computations
%
% stage 1: check center + 8 neighbors at S=1 + 8 points at S=4 (17 total)
%   - if best is center: done
%   - if best is S=1 neighbor: one more S=1 refinement (stage 2)
%   - if best is S=4 point: full S=2 then S=1 search (stage 3)

function [predicted_frame, motion_vectors, psnr_val, sad_count] = ntss(reference_frame, current_frame, N)

[height, width] = size(current_frame);
predicted_frame = zeros(height, width);
motion_vectors  = [];
sad_count       = 0;

stage1  = [ 0,0; -1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1; -4,-4; -4,0; -4,4; 0,-4; 0,4; 4,-4; 4,0; 4,4];
stage2  = [ 0,0; -1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1];
stage3a = [ 0,0; -2,-2; -2,0; -2,2; 0,-2; 0,2; 2,-2; 2,0; 2,2];
stage3b = [ 0,0; -1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1];

for i = 1:N:width-N+1
    for j = 1:N:height-N+1

        best_sad   = inf;
        dx         = 0;
        dy         = 0;
        curr_block = current_frame(j:j+N-1, i:i+N-1);
        visited    = false(15, 15);

        for k = 1:size(stage1, 1)
            [best_sad, dx, dy, sad_count, visited] = ...
                evaluate(reference_frame, curr_block, i, j, stage1(k,1), stage1(k,2), N, width, height, best_sad, dx, dy, sad_count, visited);
        end

        if dx == 0 && dy == 0
            % center was best, no further search needed

        elseif abs(dx) + abs(dy) <= 2
            % S=1 neighbor was best, refine around it
            for k = 1:size(stage2, 1)
                p = stage2(k,1); q = stage2(k,2);
                if ~visited(q+8, p+8)
                    [best_sad, dx, dy, sad_count, visited] = ...
                        evaluate(reference_frame, curr_block, i, j, p, q, N, width, height, best_sad, dx, dy, sad_count, visited);
                end
            end

        else
            % S=4 point was best, run full TSS from there
            for k = 1:size(stage3a, 1)
                p = dx + stage3a(k,1); q = dy + stage3a(k,2);
                if p >= -7 && p <= 7 && q >= -7 && q <= 7 && ~visited(q+8, p+8)
                    [best_sad, dx, dy, sad_count, visited] = ...
                        evaluate(reference_frame, curr_block, i, j, p, q, N, width, height, best_sad, dx, dy, sad_count, visited);
                end
            end

            for k = 1:size(stage3b, 1)
                p = dx + stage3b(k,1); q = dy + stage3b(k,2);
                if p >= -7 && p <= 7 && q >= -7 && q <= 7 && ~visited(q+8, p+8)
                    [best_sad, dx, dy, sad_count, visited] = ...
                        evaluate(reference_frame, curr_block, i, j, p, q, N, width, height, best_sad, dx, dy, sad_count, visited);
                end
            end
        end

        predicted_frame(j:j+N-1, i:i+N-1) = reference_frame(j+dy:j+dy+N-1, i+dx:i+dx+N-1);
        motion_vectors = [motion_vectors; i j dx dy]; %#ok<AGROW>
    end
end

psnr_val = 10 * log10(255^2 / mean(mean((current_frame - predicted_frame).^2)));

end

function [best_sad, dx, dy, sad_count, visited] = ...
    evaluate(ref_frame, curr_block, i, j, p, q, N, W, H, best_sad, dx, dy, sad_count, visited)

ri = i + p;
rj = j + q;

if ri >= 1 && rj >= 1 && ri+N-1 <= W && rj+N-1 <= H
    sad       = sum(sum(abs(curr_block - ref_frame(rj:rj+N-1, ri:ri+N-1))));
    sad_count = sad_count + 1;
    visited(q+8, p+8) = true;
    if sad < best_sad
        best_sad = sad;
        dx = p;
        dy = q;
    end
end

end
