% QUANTIZE_RESIDUAL  Apply 8x8 block DCT quantization to a residual frame.
%
% Each 8x8 block of the residual is transformed with a 2D DCT, then
% quantized by dividing by Q and rounding. Small coefficients round to zero
% and do not need to be transmitted. The remaining non-zero coefficients are
% dequantized and inverse-DCT'd to reconstruct the residual at the decoder.
%
% This models the core of Assignment 3 quantization, applied per-block to
% the motion-compensated residual instead of to raw frame data.
%
% Inputs:
%   residual  double H x W  (original frame - predicted frame)
%   Q         quantization step size (larger Q = fewer coefficients = lower quality)
%
% Outputs:
%   recon_residual  double H x W  reconstructed residual after dequantization
%   coeff_count     number of non-zero DCT coefficients (the data to transmit)

function [recon_residual, coeff_count] = quantize_residual(residual, Q)

[H, W]         = size(residual);
recon_residual = zeros(H, W);
coeff_count    = 0;
B              = 8;  % DCT block size (standard 8x8)

for i = 1:B:W-B+1
    for j = 1:B:H-B+1
        block = residual(j:j+B-1, i:i+B-1);

        D   = dct2(block);       % forward 2D DCT
        D_q = round(D / Q);      % quantize: small values become zero

        coeff_count = coeff_count + nnz(D_q);  % count surviving coefficients

        % Reconstruct: dequantize then inverse DCT
        recon_residual(j:j+B-1, i:i+B-1) = idct2(D_q * Q);
    end
end

end
