# Tasks — add-kart-view-orientation-and-input

Order is dependency order: the simulation is driven before anything is drawn, the kart is
placed before it is asked to move, and the orientation's sign is settled before any test is
written that would agree with a wrong one.

## 1. The composition root

- [x] 1.1 `scripts/main.gd` on `scenes/main.tscn`: load tuning through
      `tuning_loader.gd`, construct the simulation, and refuse to run — with the missing
      value named — rather than starting on defaults. Closes `att` 13
- [x] 1.2 Step the simulation exactly once per `_physics_process`, and call
      `Sim.begin_frame()` exactly once per `_process` — Godot's fixed-rate loop IS the
      accumulator (design D2a). Correct `sim.gd`'s comment, which says `begin_frame()` is
      called "before that frame's ticks": with Godot's ordering it fires after them
- [x] 1.3 `tools/check_settings.py` gains the cross-check D2a buys: `project.godot`'s
      `physics_ticks_per_second` must equal the core's own `TICKS_PER_SECOND`. Two independent
      declarations of one rate, in two files, with nothing today noticing a divergence
- [x] 1.4 **Verify 1.3 by breaking it**: change one of the two and confirm the mismatch is
      named. Also assert in `tests/driver_test.gd` that the per-frame callback advances the
      simulation none, so steps are a function of elapsed time alone
- [x] 1.5 Confirm `scenes/world.tscn` still loads and renders with nothing stepping — the
      `world-presentation` requirement that made the composition root live in `main.tscn`

## 2. The kart, and the sign of its heading

- [x] 2.1 Import `kart.glb` through `sync_assets.sh` and confirm the authored bounding box
      matches §1's inventory figures
- [x] 2.2 Derive the yaw correction's **axis** from the imported bounds, and fail rather than
      guess if the bounds do not identify one. Hold it in a single named constant
- [x] 2.3 Measure the mesh's **vertex-centroid offset** along that axis, with a committed tool,
      and record which direction it indicates
- [x] 2.4 Capture the kart at the start line and **look at it**: the driver and steering wheel
      must face world forward. This capture, not any test, is what fixes the sign (design D3)
- [x] 2.5 Reconcile 2.3 and 2.4. If the centroid and the capture disagree, stop — the
      heuristic is wrong, or the capture is, and proceeding on either alone is what A6 warns
      against
- [x] 2.6 Place the kart: origin on both horizontal axes, lowest point exactly at ground level,
      facing world forward, velocity zero, normalised through `scripts/core/normalise.gd`

## 3. Conformance against the document

- [x] 3.1 `tools/check_kart_conformance.py`: extract the authored box from §1 and the final
      dimensions and footprint from §3, and assert the built kart against **the document's**
      numbers rather than `tuning.json` (design D4)
- [x] 3.2 **Verify 3.1 by breaking it**: perturb the scale, then the yaw, and confirm each is
      named
- [x] 3.3 Assert the world-axis-aligned extent at the start line is the document's footprint —
      the check that distinguishes a correct kart from one turned a quarter turn
- [x] 3.4 `tests/kart_test.gd`: travel matches facing across 16 headings, forward and reverse.
      **State in the test body that it proves consistency and not orientation**, and that a
      half-turn error passes it — the capture and the centroid are what settle that

## 4. Interpolation

- [x] 4.1 The kart view reads simulation state and draws between the previous and current step
      by `Engine.get_physics_interpolation_fraction()` (design D2)
- [x] 4.2 Assert the view writes nothing back: simulation state read after a frame is the
      stepped value, not the drawn one
- [x] 4.3 Confirm no engine node-level physics interpolation is enabled, so there is exactly one
      thing smoothing the kart's motion

## 5. Input

- [x] 5.1 Declare the document's control table in `project.godot`'s InputMap, both key sets
      equivalent, including `R` and `P` whose effects arrive in M7
- [x] 5.2 Extend `tools/check_settings.py` to pin every action and key, so an editor rewrite
      cannot drop one silently (design D5)
- [x] 5.3 **Verify 5.2 by breaking it**: remove a binding and confirm it is named
- [x] 5.4 Feed held state to the simulation each tick, independent of host key-repeat
- [x] 5.5 Clear every held input on focus loss, through the core's existing `InputState.clear()`.
      Closes `att` 11
- [x] 5.6 An unbound key changes no state and writes nothing to the log
- [x] 5.7 `tests/input_test.gd` covering held state across ticks, release, focus loss, and the
      unbound key — the last asserting the log stays empty, not merely that nothing moved

## 6. Proof

- [x] 6.1 Capture the kart at the start line, facing the band
- [x] 6.2 Capture the kart mid-turn at speed
- [x] 6.3 Look at the kart's **contact shadow** — the first time anything in this project casts
      one, and the cue the design document calls primary. A7 and A8 were settled on the spike's
      scene; if the shadow does not hold up here, that is a finding with evidence
- [x] 6.4 Progress note: what each capture shows, the centroid measurement, the sign it
      indicates, and the commands that reproduce them

## 7. Documentation

- [x] 7.1 Move **A6** above the line in `docs/AMBIGUITIES.md` with the derived axis, the
      measured centroid, the capture, and — stated plainly — that the 16-heading test does not
      establish the sign
- [x] 7.2 Update A6's row in `CONSTRAINTS.md` §5
- [x] 7.3 Move four scenarios from deferred to verified in `data/scenario_register.json`:
      *Placing the kart at the start line*, *Mapping the control scheme*, *Clearing stuck
      inputs on focus loss*, *Ignoring unbound keys*. Expect M2's deferred count to fall to 3
- [x] 7.4 Record `check_kart_conformance.py` in `CONSTRAINTS.md` §10 and §13, and in
      `godot/CLAUDE.md`'s command list
- [x] 7.5 Add any new term to `docs/GLOSSARY.md`
- [x] 7.6 Close `att` 11 and `att` 13; note on `att` 10 that the start pose is done and the
      Reset Kart action remains M7's
- [x] 7.7 Check every governing document for drift — the link and section-reference gates catch
      structural rot, not stale prose

## 8. Closing

- [x] 8.1 `./tools/test.sh` green
- [x] 8.2 `openspec validate add-kart-view-orientation-and-input --strict` passes
- [x] 8.3 Confirm the coverage gate's counts moved exactly as 7.3 predicts, and that the `UNMET`
      entry is unchanged
- [x] 8.4 Raise an `att` task for anything found in passing that belongs to a later change
- [x] 8.5 Critic review against CONSTRAINTS §12 Review criteria R1–R8, by a reviewer who did not
      write the change. **Ask it to attack the orientation specifically**: whether the sign
      rests on evidence or on assertion, whether any test claims more than it establishes, and
      whether the conformance check is genuinely reading the design document rather than our
      transcription of it. Three reviews of the previous change each found a false verification
      claim from the round before, so also ask it to re-run every mutation this change claims
      to have verified

## 9. Found while building
       *Superseded: per-change Critic reviews were retired by
       `streamline-process`; this change was archived under its §12 archive
       checklist (gate green, validate --strict, docs current) instead.*
- [x] 9.1 **`ProjectSettings.save()` drops pinned settings and every comment.** Used
      to generate the InputMap, it removed `physics_ticks_per_second` — Godot writes
      only settings that differ from its defaults, and 60 IS the default, which is
      why it is pinned — along with the whole comment block explaining why four
      settings are load-bearing. `check_settings.py` caught it on the next run.
      Recorded in `GOTCHAS.md`; the fix is to splice the generated section into the
      committed file rather than let Godot rewrite it
- [x] 9.2 **The rate cross-check D2a bought.** `project.godot`'s
      `physics_ticks_per_second` and the core's `TICKS_PER_SECOND` are two
      declarations of one rate in two files, and nothing noticed a divergence.
      Now checked, verified by breaking each side
- [x] 9.3 **A fourth witness for the nose sign, found while implementing.** The gate
      reads §4's stated "+90°" from the design document and compares it against the
      independently derived correction. That is checking the derivation, not
      transcribing the figure — and it is the only automated check besides the
      centroid that notices a half-turn error
- [x] 9.4 **The contact-shadow measurement was wrong, twice over.** A first pass took
      the median of a hand-picked box beneath the kart, measured −3%, and concluded
      the shadow was missing. It is 50.3% deep. At 49.7° sun elevation the shadow
      offset is ~1 wu against a kart 2.2 wu wide, so it falls under the kart's own
      footprint and any hand-pickable box is mostly lit ground — which is what
      `measure_shadow.py`'s comments already record the spike learning. Second time
      the project has paid for it; the rule now appears in two tools
- [x] 9.5 A8's decision helps less here than on the spike's scene: shadowed ground
      near the kart is 10.2% at normal bias 0.1 against 8.0% at Godot's 2.0, where
      the spike measured 27.2% against 6.5%. The decision stands and the margin does
      not reproduce. Reported by the tool, not gated — a threshold on a two-point
      gap would be brittle. A candidate for M6 to revisit
- [x] 9.6 The placeholder camera's field of view is Godot's default 75, which equals
      the document's `fovBase`. They coincide by accident, and a code comment claimed
      the opposite as though it were a safeguard. Corrected; what keeps the
      placeholder honest is its name and `add-chase-camera` replacing it
- [x] 9.7 Exempted `CENTROID_MIN_OFFSET` (0.02) in the tuning-literal allowlist —
      a genuine collision with `startFinishBandHeightY`
