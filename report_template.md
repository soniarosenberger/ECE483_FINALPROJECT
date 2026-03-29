# ECE 483 Final Project Report
# Block-Based Video Encoder: NTSS vs. EBMA Motion Estimation

**Authors:** Charlie Wilton & Sonia Rosenberger

---

## Abstract

_One paragraph: state the problem (block-based video compression using P-frame prediction),
the approach (NTSS and EBMA motion estimation with DCT-quantized residuals, IPPPP GOP structure),
and the key quantitative results (PSNR within X dB, NTSS used Y% fewer SAD operations,
compression ratio Z× vs. uncompressed). Fill in with your actual numbers._

---

## 1. Introduction (Problem Formulation)

- Define the problem: reducing video file size by exploiting inter-frame redundancy. Adjacent
  frames in natural video are highly correlated — most pixels change little between frames.

- Explain block-based motion estimation: the frame is divided into fixed-size macroblocks
  (16×16 pixels). For each block in the current frame, we search the reference frame for the
  best-matching block and record the offset (motion vector). Only the offset and the
  prediction error (residual) need to be transmitted, not the full pixel values.

- SAD (Sum of Absolute Differences): the block similarity metric. Lower SAD = better match.
  `SAD = Σ|current_block(i,j) - reference_block(i+dy, j+dx)|`

- State the research question: can NTSS match EBMA reconstruction quality (PSNR) while
  using significantly fewer SAD computations per frame?

- Scope: grayscale frames, 16×16 macroblocks, ±7 pixel search range, quantization step Q=10,
  IPPPP GOP structure (gop_size=5).

---

## 2. Theory and Analysis of the Solution

### 2.1 Exhaustive Block Matching Algorithm (EBMA)

- Full search over all (2·7+1)² = 225 candidate positions per block within the ±7 window.
- Guaranteed to find the global minimum SAD — serves as the quality upper bound.
- Computational cost per frame: `(H/N) × (W/N) × 225` SAD operations.
- No early-exit conditions; every candidate is evaluated regardless of intermediate results.

### 2.2 New Three-Step Search (NTSS)

Motivation: empirical observation that for natural video, the true motion vector tends to
cluster near the origin. NTSS exploits this with a 17-point Stage 1 and early-exit paths.

**Stage 1 — 17-point coarse search (always performed):**
- Center (0, 0)
- 8 immediate neighbors at step S=1: (±1, 0), (0, ±1), (±1, ±1)
- 8 coarse-grid points at step S=4: (±4, 0), (0, ±4), (±4, ±4)

**Decision after Stage 1:**

| Best point | Action | Max SAD ops |
|------------|--------|-------------|
| Center (0, 0) | First-step stop — done | 17 |
| S=1 neighbor | Half-way stop — S=1 refinement around best (Stage 2) | ~22 |
| S=4 point | Full TSS — S=2 ring then S=1 ring (Stages 3a + 3b) | 33 |

**Stage 2 (half-way stop):** S=1 ring around Stage-1 best, skipping already-visited points.

**Stage 3 (full TSS):** S=2 ring search, then S=1 ring search, both centered on Stage-1 best.

Worst case: 33 SAD ops vs. EBMA's 225 — roughly 7× fewer. The first-step stop is particularly
effective for static background regions.

### 2.3 DCT Quantization of the Prediction Residual

After motion compensation, the residual (original − predicted) still contains energy that
must be transmitted. The residual is compressed with block DCT quantization:

1. Split residual into 8×8 blocks.
2. Apply 2D DCT to each block: `D = dct2(block)`
3. Quantize: `D_q = round(D / Q)` — small coefficients round to zero.
4. Count non-zero coefficients — these are the bytes transmitted.
5. Reconstruct: `recon = idct2(D_q * Q)` — dequantize and inverse DCT.

Larger Q → more zeros → fewer bytes transmitted → lower PSNR. Default Q=10.

### 2.4 Quality Metric: PSNR

`PSNR = 10 · log₁₀(255² / MSE)` where `MSE = mean((original − decoded).²)`

Interpretation: >40 dB excellent, 30–40 dB acceptable, <30 dB poor.

PSNR is computed on the fully decoded frame (prediction + reconstructed residual), not just
the motion-compensated prediction.

### 2.5 Compression Model

- **Uncompressed:** H × W bytes per frame.
- **I-frames:** transmitted raw — H × W bytes each.
- **P-frames:**
  - Motion vector overhead: `floor(H/N) × floor(W/N) × 2` bytes (1 byte each for dx, dy).
  - Residual: 2 bytes per non-zero DCT coefficient after quantization.
- **Compression ratio:** `total_raw / (i_bytes + mv_bytes + coeff_bytes)`

---

## 3. Implementation

### 3.1 System Architecture

```
main.m
  ├── io_processing.m       load frames / save output .mp4
  ├── ntss.m                NTSS motion estimator
  ├── ebma.m                EBMA motion estimator
  ├── quantize_residual.m   8×8 DCT quantization of prediction residual
  ├── compression_diff.m    compressed size comparison and bar chart
  ├── quality_diff.m        per-frame PSNR comparison plot
  └── visual_diff.m         side-by-side decoded frame display
```

### 3.2 Function Signatures and Data Flow

| Function | Inputs | Outputs |
|----------|--------|---------|
| `main(input_path, search_type)` | path + `'ntss'/'ebma'/'both'` | figures, .mp4 files |
| `ntss(ref, curr, N)` | reference frame, current frame, block size | predicted frame, MVs, PSNR, SAD count |
| `ebma(ref, curr, N)` | reference frame, current frame, block size | predicted frame, MVs, PSNR, SAD count |
| `quantize_residual(residual, Q)` | residual frame, quantization step | reconstructed residual, non-zero coeff count |
| `io_processing(path, mode [, frames])` | path + `'load'`/`'save'` | cell array of frames (load) or void (save) |
| `quality_diff(orig_cell, ntss_cell, ebma_cell)` | P-frames only | PSNR plot + printed table |
| `compression_diff(all_frames, ntss_counts, ebma_counts, gop_size, N)` | all frames + coeff counts | size bar chart + printed summary |
| `visual_diff(orig, ntss_dec, ebma_dec, frame_idx)` | single frames or cell arrays | side-by-side figure |

### 3.3 Key Design Decisions

- **Separate reference frames:** NTSS and EBMA maintain independent decoded-frame references
  (`ntss_ref`, `ebma_ref`). Their decoded outputs differ because EBMA finds globally optimal
  MVs, so the two chains must not share a reference.

- **Visited matrix in NTSS:** A 15×15 logical matrix with +8 offset maps candidate offsets
  in [-7, +7] to array indices [1, 15], preventing redundant SAD evaluations.

- **Boundary clamping:** Candidate blocks that would extend outside the reference frame are
  clamped to valid ranges before SAD computation.

- **GOP structure (IPPPP):** `mod(k-1, gop_size) == 0` selects I-frames. The decoded frame
  (not the original) becomes the reference for the next P-frame, matching a real decoder.

- **P-frame PSNR:** Computed on `decoded = predicted + recon_residual`, not on the raw
  motion-compensated prediction. This is the correct metric for the full codec loop.

### 3.4 Command-Line Interface

```matlab
main('flower.mpg', 'both')    % run both and compare
main('flower.mpg', 'ntss')    % NTSS only
main('flower.mpg', 'ebma')    % EBMA only
main('train01.tif', 'both')   % two-image test (train02.tif loaded automatically)
```

Output videos saved as `<input_name>_ntss.mp4` and/or `<input_name>_ebma.mp4`.

Parameters (set in main.m): N=16, Q=10, gop_size=5.

---

## 4. Examples

### 4.1 Single-Frame / Image Pair Test

_Insert here:_
- Side-by-side output of `visual_diff.m`: Original | NTSS decoded | EBMA decoded
- Difference images (original − decoded) for NTSS and EBMA, showing residual energy
- Motion vector quiver plot overlaid on the predicted frame (generated automatically by main.m)

### 4.2 Multi-Frame Video Sequence

_Insert here:_
- Per-frame PSNR plot from `quality_diff.m` for the full test sequence
- Table of per-frame PSNR values for NTSS and EBMA (printed to console by quality_diff.m)
- Note any frames where NTSS and EBMA diverge noticeably in PSNR

### 4.3 Frequency / Residual Analysis

_Insert here:_
- 2D DCT or DFT magnitude of the residual for a representative P-frame
- Comparison between NTSS residual spectrum and EBMA residual spectrum
- Observation: well-predicted blocks produce low-energy, high-frequency residuals that
  quantize to zero; poorly-predicted blocks retain low-frequency energy

---

## 5. Discussion

- **SAD count comparison:** NTSS used X% fewer SAD operations than EBMA on the test sequence.
  Break down what fraction of blocks hit first-step stop / half-way stop / full TSS and explain
  why (e.g., static background → first-stop; fast motion → full TSS).

- **PSNR comparison:** PSNR difference was Y dB. Is this acceptable? At Q=10 the dominant
  quality loss comes from DCT quantization, not from NTSS's sub-optimal MVs, so the difference
  should be small (≤0.1 dB expected for typical video content).

- **Compression ratio:** Explain what drives the ratio. At Q=10 many DCT coefficients survive,
  keeping the compressed size relatively large. Increasing Q reduces coefficients but reduces
  PSNR. The MV overhead is fixed regardless of Q.

- **Limitations of this implementation:**
  - Fixed 16×16 block size — no variable block size (H.264/AVC uses 4×4 to 16×16)
  - No sub-pixel motion estimation — real codecs use half- or quarter-pixel accuracy
  - Grayscale only — no chroma (YCbCr) handling
  - Simple quantization matrix — real codecs use perceptually weighted matrices
  - No entropy coding — DCT coefficients counted, not Huffman/arithmetic coded

---

## 6. Conclusions

- NTSS achieved a X% reduction in SAD operations compared to EBMA (actual result from
  your test run).
- PSNR degradation was Y dB — within acceptable range for the computational saving.
- The first-step stop / half-way stop accounted for Z% of blocks, confirming the assumption
  that most motion in natural video is small.
- Future improvements: adaptive block size, sub-pixel accuracy, B-frames, entropy coding,
  chroma support.

---

## References

- [1] Li, R., Zeng, B., & Liou, M. L. (1994). A new three-step search algorithm for block
      motion estimation. *IEEE Transactions on Circuits and Systems for Video Technology*, 4(4), 438–442.

- [2] Wallace, G. K. (1991). The JPEG still picture compression standard.
      *IEEE Transactions on Consumer Electronics*, 38(1), xviii–xxxiv.
      _(Background on 8×8 DCT quantization.)_

- [3] Wiegand, T., Sullivan, G. J., Bjontegaard, G., & Luthra, A. (2003). Overview of the
      H.264/AVC video coding standard. *IEEE Transactions on Circuits and Systems for Video
      Technology*, 13(7), 560–576.
      _(Context for how a real codec extends block-based prediction.)_

- [4] _[Any course notes or textbook references used for PSNR, block matching, or video
      compression fundamentals.]_
