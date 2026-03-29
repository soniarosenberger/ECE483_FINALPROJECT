% DCT quantization of a residual frame using the JPEG luminance matrix.
% sf is a scaling factor — larger sf = more zeroed coefficients = smaller file

function [recon_residual, coeff_count] = quantize_residual(residual, sf)

% standard JPEG luminance quantization matrix
QM = [16 11 10 16  24  40  51  61;
      12 12 14 19  26  58  60  55;
      14 13 16 24  40  57  69  56;
      14 17 22 29  51  87  80  62;
      18 22 37 56  68 109 103  77;
      24 35 55 64  81 104 113  92;
      49 64 78 87 103 121 120 101;
      72 92 95 98 112 100 103  99];

scaled_QM = sf * QM;

[H, W]         = size(residual);
recon_residual = zeros(H, W);
coeff_count    = 0;
B              = 8;

for i = 1:B:W-B+1
    for j = 1:B:H-B+1
        block = residual(j:j+B-1, i:i+B-1);
        D_q   = round(dct2(block) ./ scaled_QM);

        coeff_count = coeff_count + nnz(D_q);
        recon_residual(j:j+B-1, i:i+B-1) = idct2(D_q .* scaled_QM);
    end
end

end
