## 1. Target heights as data

- [x] 1.1 Add the seven per-asset target heights to `godot/data/tuning.json` under the asset names the design document's §3 table uses (design D6; spec: *Target heights are data, not literals*)
- [x] 1.2 Teach `check_tuning_transcription.py` to parse the §3 table as a fourth source of named constants, so the new values are verified against the document rather than silently ignored (spec: *The tuning gate covers the added values*)
- [x] 1.3 **Mutation check** — drift one target height in `tuning.json`; confirm the gate fails naming the asset; restore. If teaching the gate proves disproportionate, mark the values ungated in `CONSTRAINTS.md` and say so plainly — do not leave the gate reading as coverage it does not give (design D6)

## 2. The contract

- [x] 2.1 Add `godot/scripts/core/normalise.gd` taking an authored box supplied by the caller — never read from an engine (design D1)
- [x] 2.2 Implement the four steps in order, computing the **scaled box as a distinct value** and deriving the offset from it, so the two orderings cannot be collapsed into one expression by accident (design D2; spec: *Normalisation follows the specified order*)
- [x] 2.3 Scale uniformly on all three axes (spec: *Scaling is uniform*)
- [x] 2.4 Offset so the lowest point is exactly at zero and the box is centred on both horizontal axes (spec: *An instance rests exactly on the ground*)
- [x] 2.5 Implement scale variation as a factor applied **after** target-height normalisation, with a fresh grounding offset afterwards (design D4; spec: *Scale variation is applied on top, and re-grounded*)
- [x] 2.6 Implement the world-axis-aligned box for a normalised instance at a given yaw, as a pure function rather than stored state — the design document requires it recomputed as the instance turns (design D5)

## 3. Proving the contract

- [x] 3.1 Add `godot/tests/normalise_test.gd`
- [x] 3.2 **The case that matters**: an authored box whose height differs from its target **and** whose box is offset from its own origin, so offset-from-authored and offset-from-scaled give measurably different answers (design D3; spec: *The offset is computed from the scaled box, not the authored one*)
- [x] 3.3 **Mutation check** — compute the offset from the pre-scale box; confirm 3.2 fails; restore. If it still passes, the test is worthless and must be rebuilt before anything else here is marked done
- [x] 3.4 Assert the lowest point is exactly zero across all seven target heights, within a stated tolerance far tighter than any visible error
- [x] 3.5 Assert an authored box offset from its own origin still grounds and centres, with the authored offset not leaking through (spec: *An authored box that is not centred on its origin still grounds*)
- [x] 3.6 Assert a varied instance rests on the ground at **both extremes** of the permitted range, and that final height is target × factor (spec: *A varied instance still rests on the ground*, *Variation compounds with the target height*)
- [x] 3.7 **Mutation check** — apply variation before grounding rather than after; confirm 3.6 fails; restore (design D4). **Took three mutants to isolate.** Removing the re-ground alone survives: after normalisation the box already sits at y=0, so scaling its position by a factor leaves 0×factor=0 and the re-ground is a no-op for this formulation. Scaling about the box centre alone also survives — the re-ground *corrects* it, which is the robustness property that makes the scaling formulation irrelevant. The real error is both together, and it fails loudly: a cottage at ×1.2 sits at **y = −0.300**, precisely the 0.3 wu D4 predicted
- [x] 3.8 Assert repeated normalisation is idempotent — no progressive shrink or growth (spec: *Repeated normalisation does not drift*)

## 4. The world box

- [x] 4.1 Assert the box grows when the instance is turned off the world axes, and that this is accepted rather than corrected (spec: *The box grows when the instance is turned off-axis*)
- [x] 4.2 **Known answer from the design document**: the kart at its start-line heading measures 2.20 wu across world X and 2.36 wu along world Z, and contracting by `hitboxContraction` per side yields the 1.80 × 1.96 the collision feature cites. Both figures come from the document, not from this implementation (design D5; spec: *The box matches the design document at a known heading*)
- [x] 4.3 Assert height is unchanged by heading and the lowest point stays at ground level (spec: *Vertical extent is unaffected by heading*)
- [x] 4.4 Sample a spread of headings and assert the box is never smaller than the axis-aligned case

## 5. Close-out

- [x] 5.1 Add the suite to `godot/tools/test.sh`
- [x] 5.2 Confirm `check_boundaries.py` passes — the new core file must reference no engine type
- [x] 5.3 Confirm `check_tuning_literals.py` passes — no target height may appear as a literal in `godot/scripts/`
- [x] 5.4 Close the asset-normalisation half of `att` 6, leaving the prop population counts open for M3
- [x] 5.5 Re-measure suite wall time and update `CONSTRAINTS §8 Performance and size budgets` if it moved
- [x] 5.6 Run `openspec validate add-asset-normalisation-contract --strict`
- [x] 5.7 `godot/tools/test.sh` green
- [x] 5.9 Critic pass: rebuild the kart known-answer test. It was **tautological** — the input box was already 1.20 tall at yaw 0, making both functions the identity, so it asserted 2.2 comes back as 2.2 and could not fail. Now starts from §1's authored 2.000 × 1.019 × 1.868 through the real §3 + §4 chain, and fails if the yaw is dropped
- [x] 5.10 Critic pass: assert the X/Z footprint after variation against §3's *Final footprint range* column. Variation applied to the vertical axis **only** passed the entire suite, and M3's collision tests exactly those footprints
- [x] 5.11 Critic pass: assert `Normalised.scale` compounds, and add degenerate cases. Both were unverified — dropping the scale multiplication and deleting the guard each passed
- [x] 5.12 Critic pass: close the tuning gate's scope hole. Renaming the §4 heading broke the §3 section's terminator, letting it run to the end of the document and silently report a phantom eighth asset. Now splits on the next heading and asserts the count
- [x] 5.13 Critic pass: give `asset_target_heights` a reader — `Tuning.target_height()` — and assert the shipped values in `tuning_loader_test.gd`. The spec required the value come from the tuning data, and nothing read it
- [x] 5.14 Critic pass: separate `CENTRE_TOLERANCE` from `GROUND_TOLERANCE`. Horizontal centring is not a cancelling subtraction and measured 8.94e-8 on a non-dyadic box, ~90× the grounding bound — the first real `.glb` AABB would have turned it red for a representational reason
- [x] 5.15 Critic pass: flip the two `CONSTRAINTS §9 Assets` rows this change delivered from 📋 to ✅, correct `tuning.json`'s `_meta` (which still said M3 would add the target heights sitting twelve lines below it), and correct design D5 and the proposal's degenerate-case claim
- [x] 5.8 Critic review against CONSTRAINTS §12 Review criteria R1–R8 — **one pass, [REJECTED]**. It did re-derive the kart hitbox independently and found the test tautological: the input was already the expected output, so neither function did anything. It also killed three surviving mutants, a tuning-gate scope hole, and a tolerance that would have failed on the first real `.glb`. All addressed in 5.9–5.15; all nine mutants now die. **[APPROVED]** by the repository owner
