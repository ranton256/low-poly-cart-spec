# Tasks — add-world-presentation-layer

Specs describe what must hold; `design.md` describes how. Task order is dependency
order: the data exists before anything reads it, the scene exists before it can be
lit, and the lighting is measured before it is judged.

## 1. The constants and their reader

- [x] 1.1 Transcribe the design document's §5 *Environment art* values into
      `data/tuning.json` — sky and fog colour, fog start and end, ground size and
      material values, grid extent, divisions, height and both line colours, and the
      start/finish band's dimensions, height and opacity. Keep the set the document
      *names* separate from the set it does not, following the existing
      `unnamed_in_spec` precedent (design D5)
- [x] 1.2 Transcribe §6 *Lighting* — the three intensities as the document gives
      them, the hemisphere's two colours, the sun's position and colour, and the
      shadow configuration `spike-compatibility-renderer-shadows` settled. The
      intensities go in **unscaled**; the scale from §3 is a separate value
- [x] 1.3 Extend `tools/check_tuning_transcription.py` to cover the new values and
      re-run it — the gate must report the new total and attribute every added row
- [x] 1.4 **Verify 1.3 by breaking it**: change one transcribed value, confirm the
      gate names the file, the value found and the value expected, then restore
- [x] 1.5 Give the running game its first reader of `tuning.json`, and update
      `_meta.readers`, which still said "None yet".
      **Not via `tuning_loader.gd`, as this task assumed.** That loader builds the
      simulation's `Tuning`, which has no use for a sky colour; widening it would
      push presentation values through the object every view concern touches. A
      sibling `scripts/art_tuning.gd` reads the environment, lighting and
      port-decision groups from the same file, so "exactly one home" still holds —
      one file, two readers with different needs. `tuning_loader.gd` gains its
      first non-test caller in `add-kart-view-orientation-and-input`, and `att` 13
      stays open until it does

## 2. The environment scene

- [x] 2.1 Create `scenes/world.tscn` as a standalone scene that loads and renders
      with nothing stepping (design D8)
- [x] 2.2 Ground plane at the specified size and material, receiving shadows and
      casting none, reading every value from tuning
- [x] 2.3 Reference grid as line geometry with an unlit material, at the specified
      divisions, height and two line colours (design D6)
- [x] 2.4 Start/finish band — unlit, at the specified dimensions, height, opacity
      and visible from both sides
- [x] 2.5 Flat background colour and linear fog at the specified colour and
      distances, with the background left as a colour rather than a sky (design D2)
- [x] 2.6 Place the placeholder camera at a written-down transform and mark it in
      the scene as temporary, naming the change that replaces it (design D7)
- [x] 2.7 Confirm no environment value appears as a literal in any script — run the
      tuning-literal gate and expect the new values to be searchable

## 3. Lighting, and settling A9

- [x] 3.1 Configure the sun with the shadow settings A7 and A8 already fixed, at the
      specified position and aim
- [x] 3.2 Express the two fill terms as one ambient with a 0.40 sky contribution and
      a sky resource carrying the specified up and down colours (design D2).
      **Superseded by D2a**: that mapping makes Godot draw the sky and ignore the
      flat background, costing §5's flat sky. Implemented as the renderer spike's
      two non-shadowing directional lights instead, with the substitution recorded
- [x] 3.3 **Verify the sky-ambient mapping works under Compatibility before relying
      on it.** If it does not, stop and record the finding with evidence — do not
      substitute a different lighting model silently, and do not change renderer
- [x] 3.4 Write `tools/measure_exposure.py`: clipped-pixel fraction per channel and
      rendered colour of each named region, with every sample rectangle a named
      constant printed in the output (design D4)
- [x] 3.5 **Write the four criteria down and commit them before taking any capture
      that will be judged** (design D3). Compute the chroma bound in criterion 3
      from the document's own hemisphere ratio rather than choosing a number.
      **The ordering held and the criteria were still wrong** — C3 constrained hue
      but not lightness, so C4's "largest that clips nothing" returned 0.6882, a
      fluorescent field. Amended per D3a and re-run; both captures committed
- [x] 3.6 Run criterion 2 first — the unlit sky must render exactly its specified
      colour. If it does not, the pipeline is reshaping colour and every later
      measurement is void; fix that before continuing
- [x] 3.7 Find `k`: **originally "the largest single scale satisfying all four
      criteria", superseded by D3a** — that rule returns the brightest scale that
      saturates nothing, which is not the question the specification asks. `k` is now
      the scale minimising the ground's deviation from its specified albedo, found by
      ternary search. Record the measured values at the chosen `k` and at the
      neighbours either side, so the minimum is evidenced rather than asserted
- [x] 3.8 Store `k` in `data/tuning.json` as a stated port value, distinct from the
      document's intensities, so the ratios stay readable as the document's own
- [x] 3.9 **Verify 3.4 by breaking what it guards**: feed the tool an image known to
      clip and one with a shifted sky, and confirm it fails each criterion by name
      rather than passing quietly

## 4. Proof

- [x] 4.1 Capture the field at the settled exposure with `tools/capture.sh`, committed
      to `docs/progress/`
- [x] 4.2 Capture the same frame at the document's face-value intensities, as the
      before-image that justifies the A9 decision
- [x] 4.3 Capture the view outward from the boundary showing ground beyond it and no
      wall, fence or edge drawn
- [x] 4.4 Write the progress note recording what each capture shows, the criteria,
      the measured numbers, and the command that reproduces them
- [x] 4.5 Confirm the grid does not alias into moiré where fog does not cover it, and
      that ground, grid and band do not z-fight; a surprise here is a `GOTCHAS.md`
      entry

## 5. Documentation

- [x] 5.1 Move **A9** above the line in `docs/AMBIGUITIES.md` with the decision, the
      criteria, the measured result, and — stated plainly — the limit that preserving
      the ratios does not certify a match against a build we cannot run
- [x] 5.2 Update A9's row in `CONSTRAINTS.md` §5 from ❓ to its resolution
- [x] 5.3 Add any new term to `docs/GLOSSARY.md`
- [x] 5.4 Record `measure_exposure.py` in `CONSTRAINTS.md` with its enforcement
      status, and in `godot/CLAUDE.md`'s command list
- [x] 5.5 Check every governing document for drift: the link and section-reference
      gates catch structural rot, not stale prose

## 6. Closing

- [x] 6.1 `./tools/test.sh` green
- [x] 6.2 `openspec validate add-world-presentation-layer --strict` passes
- [x] 6.3 Raise an `att` task for anything found in passing that belongs to a later
      change — nothing leaves scope untracked
- [x] 6.4 Confirm the coverage gate's counts move only as intended. §5 and §6 carry
      no scenarios, so nothing is newly verified — but this change produces the first
      evidence about *Keeping the boundary invisible*, and it shows the scenario
      failing. The gate gained an `unmet` kind so that cannot be counted as coverage;
      it now reports `13 verified, 4 visual, 1 UNMET, 46 deferred`. **Treating an
      unchanged count as proof nothing was over-claimed is what this task originally
      did, and it was wrong**
- [x] 6.5 Critic review against CONSTRAINTS §12 Review criteria R1–R8 by a reviewer who did not write
      the change, with an explicit [APPROVED] or [REJECTED] verdict. **Ask it to
      attack the exposure result specifically**: whether the criteria were really
      fixed before the captures, whether `k` is reproducible from the committed tool,
      and whether every number in the A9 entry came from a named region

## 7. Found while building
       *Superseded: per-change Critic reviews were retired by
       `streamline-process`; this change was archived under its §12 archive
       checklist (gate green, validate --strict, docs current) instead.*
- [x] 7.1 Added `tests/world_test.gd` — the scene tree is headless-testable, so
      everything about §5 and §6 except the pixels is now checked on every run:
      element presence, ground material, derived grid geometry, band placement,
      fog, linear tonemapping, and the lighting RATIOS against the shared scale.
      Without it the only evidence the world was right was someone looking at a
      capture. Mutation-verified four ways — scaling the sun alone, restoring
      sky-sourced ambient, aiming both fills horizontally, and switching to ACES —
      each caught by name
- [x] 7.2 `fog_sky_affect` pinned to 0. Godot applies depth fog to the background
      by default, which put a gradient across the sky in this scene's first capture
      and would have made the "unlit sky renders exactly its colour" criterion
      unmeetable
- [x] 7.3 Captures no longer steal focus: `tests/capture_scene.gd` sets
      `WINDOW_FLAG_NO_FOCUS` before the first frame. Godot has no command-line flag
      for it, and the exposure search opens one window per candidate scale
- [x] 7.4 Recorded **A11** — a 200 wu ground, a ±90 drivable extent and fog
      starting at 50 wu cannot jointly hide the ground's edge from the boundary.
      Every resolution breaks one of the document's own numbers. Owned by M6,
      tracked as `att` 15, evidenced by the boundary capture
- [x] 7.5 **Withdrawn, and reversed.** This task claimed the design document never
      required the ground's edge to be hidden, and removed the clause from this
      change's boundary scenario on that basis. **The claim was false** — the
      document requires it at line 460, in *Keeping the boundary invisible*: "no
      wall, fence, or edge of the ground is drawn or visible". Review caught it.
      The requirement is restored, this change discloses that it does not satisfy
      it, and A11 records why the document's own numbers make it unreachable. A
      requirement the port cannot meet is disclosed, never edited down to fit
- [x] 7.6 Two tuning-literal exemptions, both value collisions with newly added
      data: `sim.gd`'s `TICKS_PER_SECOND = 60` against `shadowVolumeExtent`, and
      the fills' ±90° aiming against `fovMax`/`drivableExtent`. Worth noting that
      adding a value to `tuning.json` can fail a gate in a file the change never
      touched, because the scan matches magnitudes rather than meanings
- [x] 7.7 `GOTCHAS.md`: the PagedAllocator message a passing scene-tree suite
      prints at exit, and why it is the one error line to ignore

## 8. Review round 2

Second Critic pass: eight of eleven round-1 fixes HELD, one partially, one not, plus
seven fresh findings. All addressed.

- [x] 8.1 **F1 (Major, R4/R8) — a regression this change introduced.** `capture.sh`
      reported success on a FAILED capture whenever a file already sat at the output
      path: `open -g` does not carry Godot's exit status, so "a file exists" was the
      only failure signal and a stale file satisfied it. Reproduced by review — a
      capture of a non-existent scene exited 0 and left the old bytes. It mattered
      most where it was least visible: `find_light_scale.py` reuses ONE scratch path
      for ~35 captures, so a mid-search failure would have been measured as the
      previous scale, and `check_sky_ambient.sh` writes over a COMMITTED capture.
      Fixed by removing the target before launching; verified failing (exit 1, no
      file) and succeeding
- [x] 8.2 **F2 (Major, R3).** Nine specified §5/§6 properties were unguarded — grid
      extent, hemisphere colours swapped, both fills aimed down, ambient colour, sun
      colour, fog linearity, band X centre, ground at Y=0, and the placeholder camera
      removed entirely (its own spec scenario, with no test). All nine now fail by
      name. The fill test previously counted how many pointed vertically, which
      passes on an inverted hemisphere; it now checks which way each points AND which
      colour it carries. `world_test.gd`'s header claimed to check "everything except
      the pixels" and has been corrected to what it does
- [x] 8.3 **F3 (Moderate, R7).** The corrected `_meta.readers` was applied in one file
      of four. `tasks.md` 1.5, `proposal.md` and `ROADMAP.md` still said the tuning
      loader was wired; it was not — `art_tuning.gd` is a sibling reader. `att` 13
      stays open, which corroborates it
- [x] 8.4 **F4 (Minor, R7/D4).** `[31, 140, 31]` for the rejected sky band came from
      an unnamed pixel; the committed tool prints `[32, 139, 32]`. The band is
      dithered, so a single pixel was never a measurement. The tool now reports the
      row-230 MEDIAN across the full width, and the documents quote that
- [x] 8.5 **F5 (Minor).** Bulk-replace duplication in `ROADMAP.md` ("it parks the
      scene / the scene as bright as")
- [x] 8.6 **F6 (Minor, R7).** C1's frame-wide scope was not propagated: `CONSTRAINTS`
      said "of the ground", `design.md` restated the old criterion marked
      *(unchanged)* when it had changed, and the spec still said "ground or sky"
- [x] 8.7 **F7 (Minor, R7).** Re-measured the spike's two captures with the tool this
      change ships: 66.8% and 0.05%, against the spike's "67% / 0.0%" from a region
      measure. Both figures now say which scene they describe
- [x] 8.8 The proposal was staler than the finding named: it still described BOTH
      superseded decisions (sky-contribution ambient, largest-that-clips-nothing) and
      claimed acceptance item 7's edge clause was satisfied. Rewritten against D2a,
      D3a and A11

## 9. Review round 3

Third Critic pass. Seven of round 2's eight fixes held; one did not, and it was one
this project had claimed verified. Eight fresh findings.

- [x] 9.1 **F2 (Major, R4/R7) — a task marked done that was not done.** A9's entry
      was filed under `## Open` while its own footer, `CONSTRAINTS` §5 and §2 all
      called it resolved, and task 5.1 — "move A9 above the line" — was checked.
      Moved. The register's own rule says the settling change moves it
- [x] 9.2 **F1 (Major, R3) — round 1's fix creating a defect of the family it fixed.**
      The remediation restored the ground-edge requirement AND added a scenario
      asserting the edge IS visible, under the same requirement. One requirement,
      two scenarios that cannot both hold: a permanent capability spec that would
      REQUIRE the defect, and fail when M6 fixes it. Deleted. Disclosure belongs in
      `AMBIGUITIES.md`, the register and the progress note, which all carry it
- [x] 9.3 **F3 (Major, R3) — four holes, one of them a false round-2 claim.** Round 2
      reported the grid extent guarded; it was not. The check that "caught" it fired
      on the centre axis moving, so doubling extent AND step together passed — a
      grid twice the specified size with twice the cell. **The check itself was never
      in the file**: an unasserted `.replace()` silently no-opped against a line
      gdformat had already rewrapped. Extent and cell size are now both asserted, and
      both mutations fail. Also closed: the band's transparency MODE (without it the
      opacity checked is inert), the ground's orientation (a 200 wu plane can be a
      wall), and "receives shadows" (asserted in a comment, unchecked in code)
- [x] 9.4 **F4 (Moderate, R3/R7) — the widest hole.** `check_tuning_literals.py`
      collects only numbers, and colours are JSON strings, so **all ten specified
      colours could be hardcoded with the gate reporting "0 hits"** — while the spec
      required that no "dimension, colour, distance or intensity" appear as a literal
      and the proposal cited the gate as the enforcement. The numeric pass cuts each
      line at the first `#`, which is where a hex colour begins, so it could never
      have seen one. Added a separate colour pass; verified against the reviewer's
      own mutation. Recorded as V23
- [x] 9.5 **F5 (Moderate, R7).** Round 2 named `ROADMAP.md` as fixed and did not
      touch it — the phrase wrapped across a line break and the replace missed.
      Second silent no-op of the same kind in one round
- [x] 9.6 **F6 (Moderate, R8/R3).** The boundary capture was taken 28 wu inside the
      limit and 14 wu up, while the spec scenario, the register entry and A11 all
      described a view *from the boundary*. Re-shot from x = +90 at eye height. It
      changes the finding's character: from there the edge reads as a horizon, not as
      an obvious edge — recorded in A11, which had been more alarming than the
      evidence warranted
- [x] 9.7 **F7 (Minor).** "They arrive at the same scale" overstated: 8-bit
      quantisation makes the deviation a staircase, so the criteria select an
      interval and the search's arithmetic picks a point out of it. Spec and design
      now say so
- [x] 9.8 **F8 (Minor, R7/D4).** "8.7% of its ground blown out" had a denominator the
      tool does not compute, from a frame nobody can regenerate. Removed
- [x] 9.9 **F9 (Minor).** A check that could not fail (the camera was fetched by the
      name it then asserted — now found by type); the white-word guard pinned all
      three keys to §6 when the band's "white" is in §5; "fifty times" for 41.8; a
      stale Open Question; task 3.7 stating the superseded rule; `find_light_scale.py`
      and `check_sky_ambient.sh` missing from the gate table and the command list
- [x] 9.10 **F10 (Minor, R2/R7).** The register counted *Keeping the boundary
      invisible* as `visual` and covered, on a capture that shows it **failing**. The
      gate gained an `unmet` kind — it now prints `1 UNMET` on every run and requires
      the milestone and the capture. Task 6.4 had cited the unchanged count as proof
      nothing was over-claimed; that was the one place a green gate said something
      this change knew to be false
- [x] 9.11 **Part 3.** `albedo_tolerance()` was described as "computed, not chosen".
      Its chromatic term is; but `illuminant()` is also the model the scene builds, so
      C3 is a consistency check between tool and scene, not an independent oracle —
      and the quantisation allowance is a choice of form. Stated. The result survives
      the stricter single-channel form (0.0381 > 0.0309), so it does not depend on
      the looser one
- [x] 9.12 **Part 3.** A11 claimed three ways out and that each breaks something the
      document states. Review found a fourth that breaks nothing — a distant grass
      skirt beyond about ±240 leaves §5's Ground 200 × 200 and fog at 50 → 150 while
      putting every edge past fog's end. The entry no longer claims exhaustiveness
