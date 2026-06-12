# SplatViz Improvement Plan — 2026-06-11

Status: proposal. No code changed yet. Repo snapshot committed as `387c15d`.

---

## 1. Findings on the five reported issues

### Issue 5 — Frustum overlays don't match camera renders (ROOT CAUSE FOUND)

The visualization and the capture pipeline use **different FOVs**:

- Capture cameras (`_m66d_capture_vfov_deg`, Main.gd:3686): **33.09°** vfov landscape, **58.77°** portrait, `KEEP_HEIGHT`.
- Frustum overlay (`_make_frustum_mesh`, Main.gd:1946; `_add_frustum_segment`, Main.gd:2024): **hardcoded 36.0°** vfov, 16:9.
- Portrait frustums just swap width/height of the wrong 36° base instead of using the 58.77° portrait vfov.

So overlays show ~9% more vertical coverage than the render actually captures (worse for portrait). A subject that "fits" in the frustum can clip in the still.

**Fix:** make `_m66d_capture_intrinsics` the single source of truth; frustum geometry derives from it. Add a parity test: project the four image corners through the capture intrinsics and assert the frustum corner rays match.

### Issue 1 — Msplat splats cut in half

Can't be confirmed without a dataset run, but the suspects, in order:

1. **Seed visibility filter** (`_filter_seed_by_visibility_rgb_m61`) or capture-volume gating discarding half the seed cloud; Msplat may fail to densify into the missing half.
2. **COLMAP basis/quaternion error** for a subset of cameras — there are M58 `colmap_basis_debug` backups, so basis bugs have happened before. A half-space cut aligned with the rig is the classic symptom.
3. **Portrait camera intrinsics** (roll 90° + KEEP_HEIGHT): if cx/cy or fx/fy don't match the rotated image, those cameras pull splats apart.
4. **1080p downscale crop** — project history shows repeated "scale-only, no crop" policy fights.

**Diagnosis plan (before any fix):** build a parity harness extending `splatviz_projection_audit.py`:
- Reproject the seed PLY into every training still and write overlay images — a camera whose overlay is offset/mirrored is the culprit.
- Render holdout views from the trained PLY vs ground-truth stills; per-camera PSNR table. A spatially clean split (one side of the rig bad) ⇒ basis sign error; portrait-only failures ⇒ intrinsics.
- Compare seed diagnostics `bbox_span` against the capture volume to detect pre-training truncation.

### Issue 2 — No real visualizer for quality assessment

Current viewer (`_load_ply_point_cloud`, M66E) decodes DC color + opacity into camera-facing sprites — no anisotropic covariance, no SH view dependence, no proper depth-sorted alpha blending. Quality judgments made with it are unreliable.

**Short term:** stop judging by eye. Add a metric harness (Python, in `tools/`): PSNR / SSIM / LPIPS on held-out cameras rendered by the *training* renderer (gsplat/Msplat itself) — that's ground truth. Add an "Open in external viewer" button (SuperSplat or an antimatter15-style web viewer) for visual checks.

**Mid term:** in-app Gaussian renderer as its own module (depth-sorted quads + covariance-driven shader). Existing Godot 3DGS renderer projects can be evaluated before writing one.

### Issue 3 — 4DGS support + temporal coherence measures

References located:

- **Mango-GS** (ICLR 2026): multi-frame node-guided 4DGS; temporal Transformer over sparse control nodes for temporally consistent deformation; addresses per-frame overfitting. [arXiv:2603.11543](https://arxiv.org/abs/2603.11543)
- **TRiGS** (2026): SE(3) + hierarchical Bézier residuals per primitive; preserves long-term temporal identity, avoids Gaussian proliferation on long sequences. Evaluated with PSNR/SSIM/LPIPS on dynamic scenes. [arXiv:2604.00538](https://arxiv.org/abs/2604.00538)

What this means for SplatViz (a capture planner, not a trainer):

- **Dataset spec gains a time axis:** per-camera frame sequences, sync/genlock metadata, per-frame or shared transforms. Export both 3DGS (single-frame) and 4DGS (sequence) layouts.
- **Planning metrics for temporal coherence:** angular coverage maintained throughout the motion volume (the M67H motion-margin constants are the seed of this), not just at one pose.
- **Evaluation metrics to add to the harness:** per-frame PSNR/SSIM/LPIPS *stability* (variance over time), temporal flicker on known-static regions, tracked-point drift, and Gaussian-count growth across the sequence (the scalability failure TRiGS targets).
- Keep all evaluation in Python tools; Godot only plans, captures, and exports.

### Issue 4 — Report layer not functional

Report payload + HTML generation is inline in Main.gd (`_m67g_report_payload` ~line 8184 onward, several hundred lines). Recommendation: **move it out of Godot entirely.**

- Godot exports a versioned JSON **build manifest** (most of this payload already exists).
- A Python tool (`tools/splatviz_report.py`) renders the rigging-packet HTML/PDF from the manifest. Faster iteration, testable, no UI freezes, and report design changes never touch app code.
- Define the manifest as a small JSON schema so report and app can evolve independently.

---

## 2. Main.gd split (9,138 lines, 530 functions → 9 modules)

| Module | Contents (current function clusters) | Notes |
|---|---|---|
| `capture_math.gd` | aim targets, capture axes/transform, intrinsics, point→camera projection, frame-safe margins (M67H), COLMAP basis/quat conversion | **Pure static funcs. Extract first. Unit-test everything here.** |
| `frustum_overlay.gd` | frustum meshes, focus zones, centerlines | Must consume `capture_math` — fixes Issue 5 by construction |
| `stage_scene.gd` | stage/truss/floor geometry, robot model, height scale, materials | |
| `capture_renderer.gd` | SubViewport setup, capture cameras, stills export, parity checks | |
| `dataset_exporter.gd` | COLMAP sparse bridge, transforms.json, seed cloud + visibility filter, seed diagnostics | |
| `msplat_runner.gd` | command build, script generation, log polling, watchdog, progress | |
| `ply_viewer.gd` | PLY parse + preview; later the real splat renderer | |
| `report_manifest.gd` | JSON manifest export only (HTML moves to Python) | |
| `Main.gd` (thin) | panels, dialogs, mode switching, wiring via signals | Target < 1,500 lines |

**Migration rules**

1. One module per branch/commit; never a big-bang rewrite.
2. **Golden-file regression:** before extracting, capture current outputs (transforms.json, COLMAP files, seed PLY, manifest JSON) from a fixed test layout; after extracting, outputs must match byte-for-byte (except where a bug fix is intentional and documented).
3. Extract pure math first (lowest risk, enables tests), UI last.
4. Rename milestone-tagged identifiers (`_m67g_*`, `*_m67c`) to functional names as each module is extracted — not before, so diffs stay reviewable.
5. Tests: gdUnit4 for GDScript pure functions; Python pytest for the audit/report tools.

---

## 3. Sequencing

| Phase | Work | Why this order |
|---|---|---|
| 0 ✅ | Repo safety: lock cleared, snapshot committed, backups archived | done (`387c15d`) |
| 1 | Extract `capture_math.gd` + tests; fix frustum FOV mismatch (Issue 5) | Geometry trust is the foundation; cheapest big win |
| 2 | Parity/diagnosis harness; find and fix the cut-in-half cause (Issue 1) | Data must be correct before quality can be judged |
| 3 | Metric harness (PSNR/SSIM/LPIPS holdout) + external viewer hookup (Issue 2) | Objective quality signal replaces eyeballing |
| 4 | Manifest schema + Python report generator (Issue 4) | Independent of 1–3; can run in parallel if desired |
| 5 | 4DGS dataset spec + temporal coherence metrics (Issue 3) | Builds on a verified 3DGS pipeline and the Phase 3 harness |
| 6 | Remaining module extractions, identifier renames, docs consolidation | Continuous alongside 2–5 |

**References:** [Mango-GS (arXiv:2603.11543)](https://arxiv.org/abs/2603.11543) · [Mango-GS OpenReview](https://openreview.net/forum?id=N4VKlSxCLc) · [TRiGS (arXiv:2604.00538)](https://arxiv.org/abs/2604.00538)
