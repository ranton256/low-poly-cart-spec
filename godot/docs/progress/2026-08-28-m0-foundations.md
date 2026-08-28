# M0 — Foundations

`2026-08-28-m0-foundations.png`

![M0 capture](2026-08-28-m0-foundations.png)

**A flat grey 1280×720 frame, and that is the correct result.** `scenes/main.tscn`
is a bare `Node3D` — no camera, no environment, no geometry. M0 delivers the
project's ability to verify itself, not anything to look at; the ROADMAP asks
this milestone for "an empty Godot window at the pinned renderer" and this is it.

What the capture actually proves:

- The project builds and renders at all, from `tools/capture.sh` rather than a
  dragged window, so it can be re-run.
- **The pinned renderer is live.** The capture log reports
  `OpenGL API 4.1 Metal - 90.5 - Compatibility`, confirming
  `renderer/rendering_method="gl_compatibility"` from `project.godot` is in
  effect and not an editor default.
- The frame is 1280×720, matching the configured viewport.

The shadow-quality comparison that would make this renderer choice *justified*
rather than merely *pinned* belongs to `spike-compatibility-renderer-shadows`,
which is tracked separately and may reverse the decision.

Regenerate with:

```sh
cd godot && ./tools/capture.sh res://scenes/main.tscn docs/progress/2026-08-28-m0-foundations.png
```
