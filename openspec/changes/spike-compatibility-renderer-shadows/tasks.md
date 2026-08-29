## 1. Fix the bar before looking at anything

- [x] 1.1 Write `godot/docs/progress/<date>-renderer-spike.md` containing the five pass criteria from design D1 **verbatim, before any capture is taken** — contact shadow reads as contact, soft edge not aliased staircase, no acne, no peter-panning that breaks contact, shadowed faces not black
- [x] 1.2 Record in the same note: the engine version from `godot/.godot-version`, the exact `tools/capture.sh` commands, and the design document's shadow settings being reproduced (design D5)
- [x] 1.3 Confirm the note is written and committed before proceeding — the ordering is the whole defence against grading the spike on the answer it already has (design D1)

## 2. The probe scene

- [x] 2.1 Build a throwaway probe scene with the design document's §6 lighting verbatim: ambient white 0.60, hemisphere sky→ground 0.40, directional white 1.00 at (30, 50, 30) aiming at the origin
- [x] 2.2 Configure the sun's shadow to the specified values — 2048 × 2048 map, soft/percentage-closer filtering, orthographic volume ±60 wu in X and Y, near 0.5 / far 200, depth bias ≈ −0.0001
- [x] 2.3 Add the ground plane at its specified colour and roughness, receiving shadows and not casting
- [x] 2.4 Place the **kart** and at least one tall prop (a tree) as casters — the design document names the kart's contact shadow as the primary cue, so a probe without it tests the wrong thing
- [x] 2.5 Frame a fixed camera close enough that a contact shadow and a penumbra are both legible at 1280×720

- [x] 2.6 **Audit the scene against §6 Lighting setting by setting before capturing** — dump the instantiated scene and verify each light's resolved aim direction, the shadow map size actually in effect, and each caster's lowest Y. The first run passed its criteria on a scene with a 4096² map, two sideways fill lights and a 4.68° sun error, none of which the criteria could see

## 3. Capture and judge

- [x] 3.1 Capture under **Compatibility** via `tools/capture.sh` with a fixed frame count
- [x] 3.2 Switch `renderer/rendering_method` to `forward_plus` and capture again from the identical scene and frame count (design D2)
- [x] 3.3 Restore `project.godot` to `gl_compatibility` and confirm the settings gate passes — this change must not leave the renderer altered
- [x] 3.4 Confirm both captures are reproducible: re-run each and compare, expecting pixel-identical results (design D5; spec: *The comparison can be re-run*)
- [x] 3.5 Judge the Compatibility capture against each of the five criteria in turn, recording pass or fail **per criterion**, not an overall impression
- [x] 3.6 Record the verdict in the note with both images referenced

## 4. Settle the decision

- [x] 4.1 **If every criterion passes**: change `CONSTRAINTS §2 Tech stack`'s renderer row from ❓ to ✅, citing the captures, and remove the "PROVISIONAL" comment from `godot/project.godot` (spec: *The choice is justified by a shadow comparison*)
- [~] 4.2 **If any criterion fails** — *not applicable: all five passed, so 4.1 was the branch taken. Recorded rather than deleted, so the alternative path stays visible.* Originally:: record the finding and its evidence, leave the renderer pinned and unchanged, and file an `att` task for the proposal that must decide between dropping the web target, accepting a degraded web look, or two renderers (design D4; spec: *An inadequate renderer is reported, not silently swapped*)
- [x] 4.3 **Keep** the probe scene committed at `scenes/renderer_probe.tscn`, headed as spike evidence superseded by M2, and verify re-capturing from it reproduces the committed image pixel for pixel. Design D3 originally said to delete it; that contradicted this change's own spec scenario *The comparison can be re-run*, and D3 is corrected rather than the scenario weakened (design D3)
- [x] 4.4 Update `ROADMAP.md` M0 — its visual proof requires "the renderer spike's shadow comparison", which now exists

## 5. Close-out

- [x] 5.1 Close `att` 2 — reopened during review after it was closed before the Critic ran, which inverts the order CONSTRAINTS §12 Review and CLAUDE.md rule 1 require. Closed again only after owner approval
- [x] 5.2 Confirm `CONSTRAINTS §2 Tech stack` has no ❓ remaining, and that the count of open items in the document has dropped by one
- [x] 5.3 Run `openspec validate spike-compatibility-renderer-shadows --strict`
- [x] 5.4 `godot/tools/test.sh` green — in particular the settings gate, which asserts the renderer is still `gl_compatibility`
- [x] 5.6 Second run after rejection: pin `directional_shadow/size = 2048` in `project.godot` (it was unset and resolving to Godot's 4096 desktop default), aim both hemisphere fills down and up (both were horizontal), compute the sun's aim rather than hand-building it (off by 4.68°), and set `shadow_normal_bias = 0.1` (the default 2.0 erased the kart's contact shadow — ambiguity A8)
- [x] 5.7 Second run: commit `tools/measure_shadow.py` so C3 and C5 name their sample regions, per CLAUDE.md rule 5. It finds the umbra by a stated rule rather than a hand-picked box, and reproduces the reviewer's 47–49% figure against the 60% first reported
- [x] 5.8 Second run: record ambiguities A8 (two bias parameters, one specified) and A9 (light intensities in the reference build's units — 67% of the frame clips under Compatibility), and correct A7, whose original reasoning was arithmetically impossible
- [x] 5.9 Second run: correct the false specifics that had propagated into CONSTRAINTS §2 Tech stack, `ROADMAP.md`, `godot/CLAUDE.md` and this change's own design Migration Plan
- [x] 5.10 Critic pass on the redo: name the under-kart region in `tools/measure_shadow.py` and re-derive A8's figures from it. The redo committed a tool for the numbers the *previous* review challenged and left the new, load-bearing one unnamed — the same defect relocated. Corrected 6.6%→31.5% to the measured **6.5%→27.2%**
- [x] 5.11 Critic pass: pin `soft_shadow_filter_quality`, the other half of "at the specified map and filtering", which had been left at an engine default while only the map was pinned
- [x] 5.12 Critic pass: gate `directional_shadow/size` and the filter quality in `check_settings.py`. The setting whose absence invalidated the first run had nothing watching it, in a file Godot rewrites on an editor save
- [x] 5.13 Critic pass: refile A9 under Open — it was under `## Resolved` while its own body said "has NOT decided", so a reader scanning the Open table would not have seen it
- [x] 5.14 Critic pass: correct the probe's kart transform to the §3 contract (scale 1.177625, not a hand-typed 1.18), which had it 1.2 mm under the grass
- [x] 5.5 Critic review against CONSTRAINTS §12 Review criteria R1–R8 — **two independent passes, both [REJECTED]**. Round 1 found a 4096² map where 2048² was specified, two sideways fill lights, a 4.68° sun error and an unreproducible C5. Round 2 confirmed all four fixes and found A8's own headline number measured from an unnamed region — the same defect relocated — plus `att` 2 closed before review, an unpinned filter quality, an ungated map pin, and A9 misfiled as resolved. All addressed. Both passes confirmed the criteria were fixed before the captures. **[APPROVED]** by the repository owner
