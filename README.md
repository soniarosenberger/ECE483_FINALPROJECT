# ECE483 Final Project — Block-Based Video Encoder

**Charlie Wilton & Sonia Rosenberger**

MATLAB implementation of a simplified block-based video encoder. The project demonstrates how inter-frame redundancy is exploited for compression and compares two motion estimation algorithms — NTSS (New Three-Step Search) and EBMA (Exhaustive Block Matching) — in terms of computational cost (SAD operations), DCT coefficient count, and reconstruction quality (PSNR).

---

## How to Run

Place your input file in the project folder, open MATLAB, navigate to the folder, and call `main`:

```matlab
cd '/path/to/ECE483_FINALPROJECT'

main('flower.mpg', 'both')    % run both algorithms and compare
main('flower.mpg', 'ntss')    % NTSS only (much faster)
main('flower.mpg', 'ebma')    % EBMA only
main('train01.tif', 'both')   % two-image test (train02.tif loaded automatically)
```

**Supported input formats:** `.mp4`, `.avi`, `.mov`, `.mpg`, `.mpeg`, `.tif`, `.png`, `.jpg`, `.bmp`, or a folder of images.

**Output:** decoded video files saved as `<input_name>_ntss.mp4` and/or `<input_name>_ebma.mp4` in the working directory.

---

## Encoder Architecture

```
main.m
  ├── io_processing.m       load input / save output video
  ├── ntss.m                New Three-Step Search motion estimator
  ├── ebma.m                Exhaustive Block Matching motion estimator
  ├── quantize_residual.m   DCT quantization of the prediction residual
  ├── compression_diff.m    compressed size comparison and bar chart
  ├── quality_diff.m        PSNR comparison plot and table
  └── visual_diff.m         side-by-side decoded frame display
```

---

## How the Encoder Works

### GOP Structure: IPPPP

Frames are grouped in a repeating pattern of one I-frame followed by four P-frames (group size = 5, set by `gop_size` in `main.m`):

```
Frame:   1    2    3    4    5    6    7    8    9    10  ...
Type:    I    P    P    P    P    I    P    P    P    P   ...
```

- **I-frame (Intra):** transmitted raw with no prediction. Resets the reference.
- **P-frame (Predicted):** predicted from the previous *decoded* frame using block matching. Only the motion vectors and quantized residual are transmitted.

### P-frame Encoding Pipeline

For each P-frame, the encoder does the following per 16×16 block:

```
1. Motion estimation
   Search the reference frame for the best-matching 16x16 block
   within a +-7 pixel window. Record the offset (dx, dy).

2. Motion compensation
   Copy the best-matching reference block → predicted frame.

3. Residual
   residual = original frame - predicted frame

4. DCT quantization (quantize_residual.m)
   Split residual into 8x8 blocks.
   Apply 2D DCT to each block.
   Divide coefficients element-wise by the scaled JPEG luminance
   quantization matrix (sf * QM / 16) and round → small values become zero.
   High-frequency coefficients use larger divisors and zero out more easily.
   Count non-zero coefficients (these are what gets transmitted).
   Reconstruct via dequantization + inverse DCT.

5. Decoded frame
   decoded = predicted frame + reconstructed residual
   (clipped to [0, 255])

6. Update reference
   The decoded frame becomes the reference for the next P-frame.
```

`sf = 10` by default (set in `main.m`). The base quantization matrix is the standard JPEG luminance matrix, scaled by `sf / 16`. Increasing `sf` reduces the coefficient count and file size but lowers PSNR.

---

## Motion Estimation Algorithms

Both algorithms use **SAD (Sum of Absolute Differences)** as the block similarity metric. Lower SAD = better match.

### EBMA — Exhaustive Block Matching

Checks all (2×7+1)² = **225 candidates** per block. Guaranteed to find the global minimum SAD. Slow but optimal — used as the quality and efficiency baseline.

### NTSS — New Three-Step Search

Exploits the observation that for most video content the true motion is small. Uses three stages with early-exit conditions to avoid unnecessary SAD computations.

**Stage 1 — 17-point coarse search** (always performed):
- Center (0, 0)
- 8 immediate neighbors at step S=1
- 8 coarse-grid points at step S=4

**Decision after Stage 1:**

| Result | Action | Max SAD ops |
|--------|--------|-------------|
| Best is at center (0,0) | **First-step stop** — done | 17 |
| Best is an S=1 neighbor | **Half-way stop** — Stage 2 | ~22 |
| Best is an S=4 point | **Full TSS** — Stages 3a + 3b | 33 |

**Stage 2 (half-way stop):** S=1 refinement around Stage-1 best, skipping already-visited points.

**Stage 3 (full TSS):** S=2 search then S=1 search, both centered on the Stage-1 best.

Worst case is **33 SAD ops vs. EBMA's 225** — roughly 7× fewer computations. The first-step stop is particularly effective for static regions and frames with little motion (zero motion vectors).

---

## Output and Analysis

For every run, the following figures are produced for the first P-frame:

| Figure | What it shows |
|--------|--------------|
| Motion vector overlay | Decoded frame with motion vectors drawn as arrows (one per block) |
| Residual | `original - predicted` before quantization, scaled to full display range. Bright = prediction error; dark/gray = well-predicted regions |

When run with `'both'`, three additional comparison functions are called automatically:

| Function | What it shows |
|----------|--------------|
| `quality_diff` | PSNR per P-frame for NTSS and EBMA, plotted and printed. Computed on the fully decoded frame (prediction + reconstructed residual). |
| `compression_diff` | Estimated compressed size vs. uncompressed, as a bar chart. Size = I-frame bytes (raw) + P-frame bytes (motion vectors + 2 bytes per non-zero DCT coefficient). |
| `visual_diff` | Side-by-side figure: Original / NTSS decoded / EBMA decoded. |

A summary is also printed to the console showing total SAD ops, mean PSNR, and total DCT coefficients for each algorithm.

---

## Key Parameters

All three parameters are set near the top of `main.m`:

| Parameter | Default | Effect |
|-----------|---------|--------|
| `N` | 16 | Block size in pixels (16×16 macroblocks) |
| `sf` | 10 | Scaling factor applied to the JPEG luminance quantization matrix (`sf/16 * QM`) — larger reduces coefficients but lowers PSNR |
| `gop_size` | 5 | Frames per GOP (1 I-frame + 4 P-frames) |

---

## File Summary

| File | Description |
|------|-------------|
| `main.m` | Top-level encoder: loads input, GOP loop, prints summary, saves output |
| `ntss.m` | New Three-Step Search — fast motion estimator with early-exit |
| `ebma.m` | Exhaustive Block Matching — full search, quality baseline |
| `quantize_residual.m` | 8×8 DCT quantization of prediction residual; returns reconstructed residual and coefficient count |
| `io_processing.m` | Frame I/O — loads video/images/directories, saves mp4 output |
| `quality_diff.m` | Per-frame PSNR comparison plot and table (P-frames only) |
| `compression_diff.m` | Compressed size estimate and bar chart using actual DCT coefficient counts |
| `visual_diff.m` | Side-by-side decoded frame display |
| `IMPLEMENTATION.md` | Full algorithm reference and original development to-do list |
