# Tasks — add-seeded-world-scatter

Order is dependency order: the data before the generator, the generator before the
view, and the conformance check against the design document before the field is
trusted.

## 1. The data, and the sixth source

- [x] 1.1 Transcribe the prop counts and clearance radii from the design document's
      *Scattering the standard prop population* table into `data/tuning.json`.
      Closes `att` 6, whose target-heights half `add-asset-normalisation-contract`
      already closed
- [x] 1.2 Teach `tools/check_tuning_transcription.py` to parse that scenario's table
      — a **sixth** source, after the four Tuning Constants tables and §3's target
      heights. Guard the extraction count so a reworded table fails loudly rather
      than silently checking less
- [x] 1.3 **Verify 1.2 by breaking it**: change a count in `tuning.json`, then a
      clearance, and confirm each is named against the document's own figure

## 2. The generator

- [x] 2.1 `scripts/core/scatter.gd` — a seed in, an ordered array of placements out.
      No engine types; the boundary gate covers this directory, confirm it stays
      clean (design D1)
- [x] 2.2 Seed `rng.gd` at the start of each generation from the seed passed in, so
      a field cannot depend on what drew from the stream earlier (design D2)
- [x] 2.3 Candidates uniform over `±scatterExtent` on both axes; reject inside the
      asset's clearance radius of the origin, or within `minPropSeparation` of any
      already-placed prop **of any asset**
- [x] 2.4 Stop after `attemptBudget × N` attempts for an asset and report achieved
      versus requested
- [x] 2.5 Vary each instance: uniform yaw in [0, 360°), uniform scale within
      `scaleVariation`, applied on top of the target height and re-grounded through
      `scripts/core/normalise.gd`
- [x] 2.6 Emit placements asset by asset in the document's table order, and within
      an asset in acceptance order — the rule design D3 states, written where a
      reader finds it

## 3. Proving the generator

- [x] 3.1 `tests/scatter_test.gd`: the same seed reproduces the field **as a
      sequence**, not as a set — serialise and compare, because the next change
      resolves collisions by order
- [x] 3.2 Two different seeds produce different fields. A generator that ignores its
      seed satisfies every other assertion here
- [x] 3.3 Scattering twice from one seed agrees **even after unrelated draws** from
      the shared stream, which is what 2.2 buys
- [x] 3.4 No prop nearer the origin than its own clearance radius; the larger-radius
      asset held to the larger one
- [x] 3.5 No two props nearer each other than `minPropSeparation`, **across assets
      and not only within one**
- [x] 3.6 No placement outside `±scatterExtent`, so the outer ring is empty by
      construction
- [x] 3.7 The attempt budget ends an impossible request — driven with a request the
      rules cannot satisfy, so the budget is what stops it rather than success
- [x] 3.8 **Acceptance item 2, across the range and every asset**: every placed
      instance's lowest point is exactly at ground level, at the extremes of
      `scaleVariation` and in between, for all six scattered assets (design D5)
- [x] 3.9 Yaw and scale vary across instances and span their stated ranges
- [x] 3.10 **Verify 3.1 by breaking it.** The claim as written was inaccurate and
      review corrected it: a DETERMINISTIC reordering is caught by the table-order
      test, not by the sequence comparison, which compares two generations of one
      seed and cannot fail on any reordering both generations share. The sequence
      comparison does fire on a NON-deterministic reorder, which is what it is for.
      Both verified separately, and 3.11 covers the case neither did

- [x] 3.11 **The within-asset order**, which review reordered with every check in
      the project green. Placements carry the index they were accepted at, and both
      `scatter_test.gd` and `prop_field_test.gd` assert the array index matches it —
      so a shuffle inside one asset fails even though assets stay contiguous and in
      the document's table order
- [x] 3.12 **Both axes independently.** The extent check reduced the field to
      `max(|x|, |z|)`; review confined every candidate to a quarter of the Z range
      and the suite stayed green. Now a per-axis ceiling AND a floor
- [x] 3.13 **The X and Z offsets**, which nothing asserted: every synthetic box and
      all six real models are X/Z-symmetric, so `offset_x = 999.0` passed the whole
      project. One synthetic box is now off-centre on X and Z, and the instances are
      asserted to be centred on their own origin

## 4. Against the design document

- [x] 4.1 `tools/check_scatter_conformance.py`: parse the populations table and the
      rejection rules from the design document, generate a field, and assert it
      against **the document's** numbers rather than `tuning.json` (design D4)
- [x] 4.2 **Verify 4.1 by breaking it**: change a count in the design document and
      confirm the gate follows the document rather than our copy
- [x] 4.3 Register it in `tools/test.sh` — and confirm `check_suites_registered.py`
      is satisfied, which is the gate that exists because three suites once were not

## 5. The field in the world

- [x] 5.1 `scripts/world/prop_field.gd` — instantiate meshes from placements, apply
      each one's scale, yaw and ground offset, and register each as a collidable
      record. Props are meshes plus an AABB, never physics bodies
- [x] 5.2 The composition root generates a field at startup from a stated seed
- [x] 5.3 Regeneration: remove every prop, release its resources, scatter afresh, and
      leave the kart's position, heading, velocity and the running clock untouched
- [x] 5.4 Bind the **Regenerate World** action. The design document leaves the
      binding to the port; pin it in `check_settings.py` with the others
- [x] 5.5 `tests/scatter_test.gd` or a scene-tree suite: regeneration replaces the
      props and leaves the kart alone. Wait a frame before counting children —
      `queue_free` is deferred, and counting immediately sees the old ones

## 6. Proof

- [x] 6.1 Capture a seeded field from the chase camera
- [x] 6.2 Capture the empty outer ring — driven past `scatterExtent`, showing grass
      with no props, no grid and no wall
- [x] 6.3 Capture cottages as distant landmarks, which their larger clearance radius
      should produce without being asked
- [x] 6.4 Look at whether props at the extremes of the scale range read as the same
      asset or as a different one. The document asks for variation, not for a tree
      that could be a bush; if it looks wrong that is a finding with evidence
- [x] 6.5 Progress note: the seed, the achieved counts, the commands that reproduce
      the captures, and what the scale extremes look like

## 7. Documentation

- [x] 7.1 Move six scenarios to verified in `data/scenario_register.json`. Expect
      M3's deferred count to fall from 13 to 7
- [x] 7.2 Record `check_scatter_conformance.py` in `CONSTRAINTS.md` §10 and §13, and
      in `godot/CLAUDE.md`'s command list
- [x] 7.3 Record the registration-order rule in `CONSTRAINTS.md` — the next change
      depends on it, and a reader should not have to open a change's `design.md` to
      find a contract another change relies on
- [x] 7.4 Add any new term to `docs/GLOSSARY.md`
- [x] 7.5 Close `att` 6
- [x] 7.6 Check every governing document for drift
- [x] 7.7 The registration order did NOT turn out to need an ambiguity entry. The
      design document gives a table and no ordering rule, which is underspecified
      only if the port has to guess — and it does not: the table has an order, and
      using it is a reading rather than an invention. Recorded as a contract in
      `CONSTRAINTS.md` §4 instead, where the change that depends on it will find it.
      If `add-aabb-collision-response` needs the order pinned differently, that is
      when it becomes an ambiguity

## 8. Closing

- [x] 8.1 `./tools/test.sh` green
- [x] 8.2 `openspec validate add-seeded-world-scatter --strict` passes
- [x] 8.3 Confirm the coverage gate reports M3 at 7 deferred and the `UNMET` entry
      unchanged
- [x] 8.4 Raise an `att` task for anything found in passing
- [x] 8.5 Critic review against CONSTRAINTS §12 Review criteria R1–R8, by a reviewer
      who did not write the change. **Ask it to attack the order and the ranges**:
      whether the sequence is really asserted as a sequence, whether acceptance item
      2 is checked at more than one scale and more than one asset, and whether the
      separation rule is checked across assets rather than within one. Every recent
      review has found a check that passes because it was run at the one input where
      the bug is invisible — the kart's aim at yaw 0 being the last — so ask for that
      shape specifically. Also ask it to re-run every mutation this change claims

## 9. Found while building
       *Superseded: per-change Critic reviews were retired by
       `streamline-process`; this change was archived under its §12 archive
       checklist (gate green, validate --strict, docs current) instead.*
- [x] 9.1 **The prop counts collided with the target heights.** Adding `tree: 15`
      beside `asset_target_heights.tree` gave one key two meanings, which breaks
      `check_tuning_transcription.py`'s "each constant appears exactly once" rule
      AND `scripts/art_tuning.gd`'s flat lookup, which depends on that guarantee.
      The gate caught it on the first run. Keys are `treeCount` and so on, which
      keeps both invariants rather than weakening either
- [x] 9.2 **The generator sank every prop by half its authored height.**
      `Normalise.with_variation()` operates on an already-grounded box, so its own
      `offset.y` is always zero — it is not the authored-space offset a view needs.
      Caught by the acceptance-item-2 assertion at the extremes of the scale range,
      which is exactly the check design D5 argued for. A check at one scale would
      have found it too; a check on the grounded box alone would not
- [x] 9.3 **My own gate edit failed silently.** The prop-count checks appended to a
      list that had already been consumed two blocks earlier, so three mutations
      passed that should have failed. Found by running the mutations rather than
      trusting the edit — the same lesson as `20e61fa`
- [x] 9.4 **A capture came back with a pure-black sky.** Grabbed before the renderer
      caught up after 420 physics-only frames; two re-runs of the identical command
      were correct. `drive_capture.gd` now waits 12 rendered frames and refuses to
      write a frame more than 20% pure black — a capture tool that can silently emit
      a half-drawn frame can silently produce misleading proof. Both constants are
      guesses rather than measurements; `att` 17 tracks finding the real floor
- [x] 9.5 A test comment claimed the regeneration check would catch a change back to
      `queue_free()`. It does not — verified by trying it, since after one frame both
      are correct. The comment now says what is true and why the immediate free is
      still the better choice
- [x] 9.6 Two more tuning-literal exemptions, both value collisions with the new
      counts: a mulberry32 bit shift (`_state >> 15`) against `treeCount`, and the
      placeholder camera's look-at Z against `coneCount`. Adding data to
      `tuning.json` keeps failing gates in files the change never touched, because
      the scan matches magnitudes and not meanings

## 10. Review round 1

Critic pass: [REJECTED] on R2 and R7, and it found the shape this project keeps
producing — a check that passes at the one input where the bug is invisible. The
grounding defence held; the ordering defence did not.

- [x] 10.1 **F1 (HIGH, R2/R3) — the conformance gate compared the port against
      itself.** Its `document_order` was built from `field["order"]`, which
      `measure_scatter.gd` emitted as `Scatter.ASSET_ORDER` — the port's own
      constant. Any permutation of the six assets passed, and the gate REPORTED it
      as document-conformant while its docstring claimed the two sides shared no
      ancestor. `populations()` already returns the document's table order, so the
      fix is `list(wanted)`; the field's own key is renamed `emitted_order` so it
      cannot be mistaken for the document's again
- [x] 10.2 **F2 (HIGH, R2) — the within-asset order had no check anywhere.** Review
      reordered placements inside one asset — assets still contiguous, still in
      table order — and the entire project stayed green, in the generator AND in the
      view. That is precisely the value `add-aabb-collision-response` resolves
      against. Placements now carry the index they were accepted at, `prop_field`
      carries it through, and both suites assert the array index matches. Verified
      with review's own mutation in both files
- [x] 10.3 **F3 (HIGH, R2) — "uniformly distributed on both horizontal axes" had no
      test.** The extent check reduced the field to `max(|x|, |z|)`: one number, one
      side, both axes collapsed. Review confined every candidate to a quarter of the
      Z range — a 100 × 25 strip — and the suite stayed green. Now per-axis, with a
      floor as well as a ceiling
- [x] 10.4 **F4 (MEDIUM, R2) — `offset_x` and `offset_z` were asserted by nothing.**
      Every synthetic box AND all six real models are X/Z-symmetric about their
      origins, so both offsets were identically zero on every input either side ever
      saw, and `offset_x = 999.0` passed the whole project. One synthetic box is now
      off-centre on X and Z, and instances are asserted centred on their own origin.
      The `offset_z` mutation is caught by exactly that box
- [x] 10.5 **F5/F6 (MEDIUM, R7).** V26 claimed the gate checks registration order
      against the document (it did not), sat between V24 and V25, and V24 still said
      it was the "only" document-reading gate. §13's gate table had no entry for
      `check_scatter_conformance.py` despite task 7.2 claiming it did — nor, it
      turned out, for four other gates. All five added
- [x] 10.6 **F7/F8 (LOW, R7).** "seven assets" in six places: the scattered
      population is six, and the gate's own `EXPECTED_ASSETS = 6` contradicted its
      docstring twenty lines above. `target_height()`'s docstring had been displaced
      onto `prop_count()` when that was inserted above it
- [x] 10.7 **F9 (LOW).** The rejection-rule guard scanned the whole scenario section
      including the explanatory paragraph, so a rule row could be stripped while the
      gate still found the names in the prose below. It now reads only the table rows
- [x] 10.8 **F10 (LOW, pre-existing).** `check_suites_registered.py` counted a bare
      mention on any non-comment line, so `echo skipping   # tests/foo_test.gd` read
      as registration. It now requires the line to actually invoke `godot -s`
- [x] 10.9 **F11 (LOW, pre-existing, and this change is its first consumer).**
      `scaleVariation` is a RANGE in one table cell, which `table_values()` counts
      among the rows it cannot attribute — so neither end was ever checked, and this
      change's progress note asserted "0.8–1.2" as a document fact nothing held.
      Read explicitly now, both ends, verified by drifting `max` to 1.5
- [x] 10.10 **The 3.10 claim was inaccurate** and review corrected it: a
      deterministic reordering is caught by the table-order test, not by the sequence
      comparison, which compares two generations of one seed and cannot fail on a
      reordering they share. Recorded as it actually is
