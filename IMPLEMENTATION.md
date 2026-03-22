# ECE483 Final Project — NTSS Video Encoder: Implementation Reference

This document serves two purposes:
1. A complete technical description of the current NTSS implementation in `ntss.m`
2. A detailed development to-do list for building the full video encoder system

---

## Part 1: Current NTSS Implementation

### 1.1 Algorithm Overview

**NTSS (New Three-Step Search)** is a block-based motion estimation algorithm designed for video compression. It is derived from the classic Three-Step Search (TSS) algorithm but introduces two early-exit conditions that dramatically reduce the number of Sum of Absolute Differences (SAD) computations required per frame.

The algorithm is described in the IEEE paper that this implementation follows. The core insight is that for most video content, the optimal motion vector is near the center of the search window — NTSS exploits this statistical property with structured early exits.

**Key parameters:**
- Block size: N = 16×16 pixels (macroblock)
- Search range: ±7 pixels (maximum displacement in any direction)
- Matching metric: SAD (Sum of Absolute Differences)

---

### 1.2 Data Flow (current `ntss.m`)

```
[Input]
  train01.tif  →  reference_frame (double)
  train02.tif  →  current_frame   (double)

[Block iteration]
  For each 16×16 block in current_frame:
    Run 3-stage NTSS search against reference_frame
    → best motion vector (diffx, diffy)
    → copy matching block from reference_frame into predicted_frame

[Output]
  predicted_frame  →  displayed via imshow (Figure 2)
  motion vectors   →  displayed via quiver overlay
  error image      →  current_frame - predicted_frame (Figure 3)
  PSNR             →  printed to console
  sad_counter      →  printed to console (total SAD operations)
```

---

### 1.3 Three-Stage Search Logic

The algorithm follows a decision flowchart with three possible outcomes per block:

#### Stage 1 — Coarse Search (17 candidate points)

Candidates checked simultaneously:
- Center: `(0, 0)`
- 8 immediate neighbors at step S=1: `(±1, 0)`, `(0, ±1)`, `(±1, ±1)`
- 8 coarse-grid points at step S=4: `(±4, 0)`, `(0, ±4)`, `(±4, ±4)`

```
search_loc1 = [0,0; -1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1;
               -4,-4; -4,0; -4,4; 0,-4; 0,4; 4,-4; 4,0; 4,4]
```

**Decision after Stage 1:**

| Condition | Action |
|-----------|--------|
| Minimum at `(0,0)` | **First-step stop** — assign block immediately, skip Stages 2 & 3 |
| Minimum at Manhattan distance ≤ 2 (i.e., at one of the S=1 neighbors) | **Half-way stop** — proceed to Stage 2 |
| Minimum at S=4 point | **Full TSS** — proceed to Stage 3 |

#### Stage 2 — S=1 Refinement (Half-way Stop)

Performs an S=1 neighborhood search around the Stage 1 minimum. Because center and its immediate neighbors were already checked in Stage 1, only unchecked points are computed (enforced by the `checked` matrix).

```
search_loc2 = [0,0; -1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1]
```

New points checked: at most 8 − (already visited) = up to ~5 additional SAD computations.

#### Stage 3 — Full TSS Continuation

Performs a two-step refinement from the Stage 1 minimum:

**Step A — S=2 search** around the Stage 1 best point:
```
search_loc3 = [0,0; -2,-2; -2,0; -2,2; 0,-2; 0,2; 2,-2; 2,0; 2,2]
```

**Step B — S=1 search** around the Stage A best point:
```
search_loc4 = [0,0; -1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1]
```

All Stage 3 candidates are bounds-checked against ±7 and against the `checked` matrix to avoid redundant computation.

---

### 1.4 Key Variables

| Variable | Type | Description |
|----------|------|-------------|
| `reference_frame` | double H×W | Previous frame (source of reference blocks) |
| `current_frame` | double H×W | Frame being encoded |
| `predicted_frame` | double H×W | Output: reconstructed frame from motion-compensated blocks |
| `N` | scalar | Block size (16) |
| `sad` | scalar | Current best SAD for a block (initialized to `inf`) |
| `diffx`, `diffy` | scalar | Best motion vector components for current block |
| `quiver_arr` | Nx4 array | Accumulated `[i, j, diffx, diffy]` per block for visualization |
| `sad_counter` | scalar | Total number of SAD computations (performance metric) |
| `checked` | 15×15 logical | Tracks which candidate offsets have already been evaluated. Index offset: `(q+8, p+8)` maps displacement range `[-7, +7]` to matrix indices `[1, 15]`. |
| `curr_fb` | N×N double | Current block extracted from `current_frame` |
| `ref_fb` | N×N double | Candidate reference block extracted from `reference_frame` |

---

### 1.5 SAD Computation

```matlab
temp_sad = sum(sum(abs(curr_fb - ref_fb)));
```

Lower SAD = better block match. The algorithm tracks the lowest SAD found per block and updates `diffx`/`diffy` accordingly.

---

### 1.6 Output Metrics

**PSNR (Peak Signal-to-Noise Ratio):**
```matlab
psnr = 10 * log10(255*255 / mean(mean((current_frame - predicted_frame).^2)))
```
Higher PSNR = better reconstruction quality. Typical values for good compression: >30 dB.

**Error image:** `err = current_frame - predicted_frame`
Displayed with `imshow(err, [])` — bright pixels indicate large prediction error.

**Motion field:** `quiver(X, Y, U, V, 0)` overlaid on predicted frame — shows direction and magnitude of block displacements.

---

### 1.7 Known Issues in Current `ntss.m`

| Issue | Location | Description |
|-------|----------|-------------|
| `quiver_arr` bug | Outer `for i` loop | `quiver_arr = [quiver_arr; i j diffx diffy]` is inside the outer loop but outside the inner loop, so it only records the last block of each column — most motion vectors are lost |
| Hardcoded I/O | Top of function | `imread("train01.tif")` / `imread("train02.tif")` prevents reuse as a callable function |
| No return values | Function signature | `function ntss` returns nothing; cannot be called from an orchestrator |
| Display logic mixed in | End of function | Figure generation, PSNR, and SAD print belong in the caller |
| Search range comment | `checked` matrix | Comment says 15×15 but search range is ±7 = 15 values; correct, but worth clarifying |

---

## Part 2: Planned Video Encoder Architecture

### System Overview

```
main.m
  ├── io_processing.m     (load frames / save output video)
  ├── ntss.m              (refactored: callable search function)
  ├── ebma.m              (exhaustive block matching, baseline)
  ├── compression_diff.m  (file size comparison)
  ├── quality_diff.m      (PSNR comparison)
  └── visual_diff.m       (side-by-side display)
```

`main.m` accepts a command-line argument specifying the search algorithm (`ntss` or `ebma`), loads input via `io_processing`, runs block-based motion estimation frame-by-frame, and then calls all three analysis/display functions.

### Planned Function Signatures

```matlab
% Main orchestrator
main(search_type)   % search_type = 'ntss' | 'ebma'

% Search algorithms (identical interface)
[predicted_frame, motion_vectors, psnr_val, sad_count] = ntss(reference_frame, current_frame, N)
[predicted_frame, motion_vectors, psnr_val, sad_count] = ebma(reference_frame, current_frame, N)

% I/O
frames = io_processing(input_path, 'load')
io_processing(output_path, 'save', frames)

% Analysis & display
compression_diff(original_frames, ntss_predicted, ebma_predicted)
quality_diff(current_frames, ntss_predicted, ebma_predicted)
visual_diff(original, ntss_decoded, ebma_decoded, frame_idx)
```

---

## Part 3: Development To-Do List

Tasks are ordered by dependency. Each phase should be completed and verified before moving to the next.

---

### Phase 0: Refactor `ntss.m` into a Callable Function

**Goal:** Transform the standalone script into a pure function that takes frames as input and returns results — no hardcoded paths, no figure generation.

- [ ] **0.1** Change function signature to:
  ```matlab
  function [predicted_frame, motion_vectors, psnr_val, sad_count] = ntss(reference_frame, current_frame, N)
  ```
- [ ] **0.2** Remove `close all`, `imread`, and `figure`/`imshow`/`quiver`/`disp`/`psnr` output statements from the function body
- [ ] **0.3** Fix `quiver_arr` bug: move the append statement `quiver_arr = [quiver_arr; i j diffx diffy]` inside the inner `for j` loop so every block's motion vector is recorded
- [ ] **0.4** Compute `psnr_val` inside the function and return it (do not print)
- [ ] **0.5** Return `motion_vectors` as a struct or Mx4 matrix with columns `[block_x, block_y, diffx, diffy]`
- [ ] **0.6** Return `sad_count` as a scalar
- [ ] **0.7** Verify: create a temporary test script that calls the new `ntss(ref, curr, 16)` with `train01.tif` / `train02.tif` and confirms PSNR matches the original standalone output

---

### Phase 1: Implement `ebma.m`

**Goal:** Implement exhaustive block matching as a comparison baseline. EBMA checks every candidate position in the ±7 search window — it is slower but guaranteed to find the global minimum SAD.

- [ ] **1.1** Create file `ebma.m` with signature:
  ```matlab
  function [predicted_frame, motion_vectors, psnr_val, sad_count] = ebma(reference_frame, current_frame, N)
  ```
- [ ] **1.2** Implement nested loop over all `(p, q)` with `p ∈ [-7, 7]`, `q ∈ [-7, 7]` — no early exit, no `checked` matrix needed
- [ ] **1.3** Use the same SAD computation as `ntss`:
  ```matlab
  temp_sad = sum(sum(abs(curr_fb - ref_fb)));
  ```
- [ ] **1.4** Apply the same boundary check:
  ```matlab
  ref_i >= 1 && ref_j >= 1 && ref_i+N-1 <= width && ref_j+N-1 <= height
  ```
- [ ] **1.5** Accumulate `motion_vectors` in the same format as `ntss`
- [ ] **1.6** Compute and return `psnr_val` and `sad_count`
- [ ] **1.7** Verify: EBMA `sad_count` should be substantially larger than NTSS `sad_count`; PSNR should be equal to or slightly better than NTSS

---

### Phase 2: Implement `io_processing.m`

**Goal:** Centralize all file I/O so that `main.m` does not contain any format-specific loading/saving logic.

- [ ] **2.1** Create file `io_processing.m` with two modes:

  **Load mode:**
  ```matlab
  frames = io_processing(input_path, 'load')
  % Returns: cell array of double matrices, one per frame
  ```
  - If `input_path` is a `.tif` / `.png` / `.jpg`: load single image, return as `{frame}`
  - If `input_path` is a directory: load all images in sorted order, return as cell array
  - If `input_path` is a video file (`.avi`, `.mp4`): use `VideoReader` to extract frames
  - Convert all frames to `double` and to grayscale if RGB (`rgb2gray`)

  **Save mode:**
  ```matlab
  io_processing(output_path, 'save', frames)
  % Writes frames cell array to output_path as an AVI video or frame sequence
  ```
  - Use `VideoWriter` to write frames as a playable AVI

- [ ] **2.2** Handle edge cases: file not found, unsupported format, empty frame list

- [ ] **2.3** Verify: load `train01.tif` and `train02.tif` via `io_processing` and confirm output matches `double(imread(...))` directly

---

### Phase 3: Implement `main.m`

**Goal:** Top-level orchestrator that wires together all components.

- [ ] **3.1** Parse command-line argument:
  ```matlab
  function main(search_type)
  % search_type: 'ntss' or 'ebma'
  ```

- [ ] **3.2** Call `io_processing` to load input frames:
  ```matlab
  frames = io_processing('input/', 'load');
  % or hardcode train01/train02 paths for initial testing
  ```

- [ ] **3.3** Implement I-frame / P-frame group logic:
  - Treat frame 1 as the I-frame (reference, passed through unmodified)
  - Frames 2..N are P-frames predicted from the previous I-frame
  - For initial 2-frame testing: frame 1 = reference, frame 2 = current

- [ ] **3.4** Loop over P-frames, calling the selected algorithm:
  ```matlab
  if strcmp(search_type, 'ntss')
      [predicted, mvs, psnr_val, sad_count] = ntss(reference_frame, current_frame, 16);
  elseif strcmp(search_type, 'ebma')
      [predicted, mvs, psnr_val, sad_count] = ebma(reference_frame, current_frame, 16);
  end
  ```

- [ ] **3.5** Accumulate results across all frames:
  - `all_predicted` — cell array of predicted frames
  - `all_psnr` — vector of PSNR values per frame
  - `all_sad` — vector of SAD counts per frame
  - `all_mvs` — cell array of motion vector arrays

- [ ] **3.6** Print summary: total SAD count, mean PSNR

- [ ] **3.7** Call display/analysis functions:
  ```matlab
  compression_diff(frames, ntss_predicted_all, ebma_predicted_all);
  quality_diff(frames, ntss_predicted_all, ebma_predicted_all);
  visual_diff(frames{k}, ntss_predicted_all{k}, ebma_predicted_all{k}, k);
  ```
  Note: for compression_diff and quality_diff, main.m will need to run both algorithms and pass both sets of results.

- [ ] **3.8** Call `io_processing` to save output frames

---

### Phase 4: Implement `compression_diff.m`

**Goal:** Quantify the compression benefit of motion-compensated prediction vs. storing raw frames.

- [ ] **4.1** Create file `compression_diff.m`:
  ```matlab
  function compression_diff(original_frames, ntss_predicted, ebma_predicted)
  ```

- [ ] **4.2** Compute uncompressed size per frame:
  ```matlab
  [H, W] = size(frame);
  uncompressed_bytes = H * W * 1;  % 8-bit grayscale = 1 byte/pixel
  ```

- [ ] **4.3** Compute residual (error) size — the data that must be transmitted in addition to motion vectors:
  ```matlab
  residual = original_frame - predicted_frame;
  % Approximate compressed residual size using entropy or just raw residual bytes
  residual_bytes = H * W * 1;  % worst case: same as uncompressed
  ```
  For a more meaningful metric: count non-zero residual pixels or compute entropy.

- [ ] **4.4** Compute motion vector overhead:
  ```matlab
  num_blocks = floor(H/N) * floor(W/N);
  mv_bytes = num_blocks * 2 * 1;  % 2 bytes per MV (1 byte each for dx, dy)
  ```

- [ ] **4.5** Display a comparison table and bar chart:
  - Rows: Uncompressed / NTSS (MV + residual) / EBMA (MV + residual)
  - Columns: Size (bytes), Compression Ratio

---

### Phase 5: Implement `quality_diff.m`

**Goal:** Compare reconstruction quality of NTSS vs. EBMA using PSNR.

- [ ] **5.1** Create file `quality_diff.m`:
  ```matlab
  function quality_diff(current_frames, ntss_predicted, ebma_predicted)
  ```

- [ ] **5.2** Compute PSNR per frame for both methods:
  ```matlab
  for k = 1:num_frames
      ntss_psnr(k) = 10*log10(255^2 / mean2((current_frames{k} - ntss_predicted{k}).^2));
      ebma_psnr(k) = 10*log10(255^2 / mean2((current_frames{k} - ebma_predicted{k}).^2));
  end
  ```

- [ ] **5.3** Plot PSNR vs. frame index for both methods on the same axes

- [ ] **5.4** Print summary table: mean PSNR, min PSNR, max PSNR for each method

- [ ] **5.5** Note in output whether NTSS PSNR is within acceptable margin of EBMA PSNR (expected: EBMA ≥ NTSS, but difference should be small)

---

### Phase 6: Implement `visual_diff.m`

**Goal:** Side-by-side visual comparison of uncompressed, NTSS-decoded, and EBMA-decoded frames.

- [ ] **6.1** Create file `visual_diff.m`:
  ```matlab
  function visual_diff(original, ntss_decoded, ebma_decoded, frame_idx)
  ```

- [ ] **6.2** Display three panels in one figure using `subplot(1, 3, k)`:
  - Panel 1: `imshow(uint8(original))`, title `'Uncompressed (Original)'`
  - Panel 2: `imshow(uint8(ntss_decoded))`, title `'NTSS, decoded'`
  - Panel 3: `imshow(uint8(ebma_decoded))`, title `'EBMA, decoded'`

- [ ] **6.3** Add figure title with frame index: `sgtitle(sprintf('Frame %d', frame_idx))`

- [ ] **6.4** Optional: if multiple frames are passed as cell arrays, loop through them with a pause to create a scrolling animation

---

### Phase 7: Integration & Regression Testing

**Goal:** Confirm all components work together correctly and produce expected results.

- [ ] **7.1** Run `main('ntss')` on `train01.tif` / `train02.tif` — confirm PSNR matches original standalone `ntss.m` output (regression test)
- [ ] **7.2** Run `main('ebma')` — confirm `sad_count` is substantially higher than NTSS
- [ ] **7.3** Confirm EBMA PSNR ≥ NTSS PSNR (EBMA finds global minimum, so it must be at least as good)
- [ ] **7.4** Confirm `visual_diff` renders three labeled panels correctly
- [ ] **7.5** Confirm `compression_diff` bar chart displays correctly with sensible ratios
- [ ] **7.6** Confirm `quality_diff` PSNR plot renders correctly
- [ ] **7.7** Test `main` with invalid `search_type` argument — should produce clear error message
- [ ] **7.8** (Optional) Test with a 3-frame sequence to validate multi-frame P-frame loop

---

### Phase 8: Report Template

**Goal:** Create a structured report skeleton that can be filled in with results from Phases 0–7.

- [ ] **8.1** Create `report_template.md` with the following sections (per course deliverable guidelines):

```
## Abstract
One paragraph: state the problem (block-based video compression), the approach (NTSS vs. EBMA
motion estimation), and the key quantitative results (PSNR, SAD count reduction, compression ratio).

## 1. Introduction (Problem Formulation)
- Define the problem: compressing video by predicting P-frames from reference I-frames
- Explain block-based motion estimation: why macroblocks, what SAD measures
- State the research question: can NTSS match EBMA quality with fewer SAD computations?
- Scope: grayscale frames, 16×16 blocks, ±7 pixel search range

## 2. Theory and Analysis of the Solution
### 2.1 Exhaustive Block Matching Algorithm (EBMA)
- Full search over all (2p+1)² candidate positions in search window
- Guaranteed to find global minimum SAD — quality upper bound
- Computational cost: O(W·H/N² · (2p+1)²) SAD operations per frame

### 2.2 New Three-Step Search (NTSS)
- Motivation: statistical observation that optimal MVs cluster near center
- Stage 1: 17-point coarse search (S=1 neighbors + S=4 coarse grid)
  - First-step stop: if minimum at (0,0), terminate early
- Stage 2: half-way stop — S=1 refinement if minimum is adjacent to center
- Stage 3: full TSS continuation — S=2 then S=1 refinement from coarse minimum
- Worst-case: 17 + 8 + 8 = 33 SAD ops; typical: 17 (first-stop) or 25 (half-stop)
- Derive expected SAD count reduction vs. EBMA for the test sequence

### 2.3 Quality Metric: PSNR
- Formula: PSNR = 10·log₁₀(255² / MSE)
- Interpretation scale: >40 dB excellent, 30–40 dB acceptable, <30 dB poor

### 2.4 Compression Model
- Uncompressed: H·W bytes per frame
- Motion-compensated: MV overhead (2 bytes/block) + residual energy
- Compression ratio = uncompressed size / (MV bytes + residual bytes)

## 3. Implementation
- System architecture: main.m → ntss.m / ebma.m → io_processing.m
- Function signatures and data flow table
- Key design decisions: checked matrix, boundary handling, quiver_arr fix
- Command-line interface: main('ntss') vs. main('ebma')
- I-frame / P-frame group structure

## 4. Examples
### 4.1 Images
- Side-by-side output of visual_diff.m: "Uncompressed (Original)" / "NTSS, decoded" / "EBMA, decoded"
- Error images for NTSS and EBMA (highlighting residual regions)
- Motion vector quiver field overlaid on predicted frame

### 4.2 Video Sequences
- Results on multi-frame test sequence (if available beyond train01/train02)
- Per-frame PSNR plot (output of quality_diff.m) for both methods

### 4.3 Frequency Analysis
- 2D DFT or DCT of the residual (error) images for NTSS and EBMA
- Show that well-predicted blocks produce low-energy, high-frequency residuals
- Compare residual energy spectrum between the two methods

## 5. Discussion
- Compare SAD count: NTSS vs. EBMA — actual percentage reduction achieved
- Compare PSNR: is the quality tradeoff acceptable?
- Analyze which blocks triggered first-stop / half-stop / full TSS and why
  (e.g., static background → first-stop; complex motion → full TSS)
- Discuss limitations: fixed block size, no sub-pixel accuracy, grayscale only
- Discuss compression ratio results and what drives the residual size

## 6. Conclusions
- Quantify NTSS efficiency gain over EBMA (e.g., "X% fewer SAD computations")
- State quality outcome (e.g., "PSNR within Y dB of EBMA")
- Identify which search path (first-stop / half-stop / full) dominated the test sequence
- Suggest future improvements: adaptive block size, sub-pixel motion, B-frames

## References
- [1] Li, R., Zeng, B., & Liou, M. L. (1994). A new three-step search algorithm for block
      motion estimation. IEEE Transactions on Circuits and Systems for Video Technology.
- [2] [Additional references for EBMA, PSNR, video compression fundamentals]
```

---

## Quick Reference: File Summary

| File | Status | Description |
|------|--------|-------------|
| `ntss.m` | Exists (needs refactor) | NTSS block matching search function |
| `ebma.m` | To create | Exhaustive block matching baseline |
| `main.m` | To create | Video encoder orchestrator |
| `io_processing.m` | To create | Frame I/O and format conversion |
| `compression_diff.m` | To create | File size comparison and display |
| `quality_diff.m` | To create | PSNR comparison and plot |
| `visual_diff.m` | To create | Side-by-side decoded frame display |
| `report_template.md` | To create | Report skeleton |
