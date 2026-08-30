# Tasks: add-minimap-viewport

- [ ] 1. Data: marker geometry rows join `unnamed_in_spec` (disc radius
       2.4 wu, arrow dimensions).
- [ ] 2. `minimap_test.gd` (RED first): inset and size from data; ortho
       framing (altitude, half-extent, near/far); fixed basis under a turning
       kart; marker tracking and true-heading arrow; layer-mask isolation;
       main viewport untouched.
- [ ] 3. `minimap_view.gd`: the container + world-sharing SubViewport +
       fixed-basis ortho camera; markers built unshaded on layer 2 and
       attached to the world; chase camera's cull mask drops layer 2;
       tracking gated on RACING; wired from `main.tscn`/`main.gd`.
- [ ] 4. `godot/tools/test.sh` green (suite registered); `openspec validate
       --strict`; coverage: M5's deferred count reaches zero; archive
       checklist run.
