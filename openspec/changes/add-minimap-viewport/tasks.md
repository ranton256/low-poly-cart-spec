# Tasks: add-minimap-viewport

- [x] 1. Data: marker geometry rows join `unnamed_in_spec` (disc radius
       2.4 wu, arrow dimensions).
- [x] 2. `minimap_test.gd` (RED first): inset and size from data; ortho
       framing (altitude, half-extent, near/far); fixed basis under a turning
       kart; marker tracking and true-heading arrow; layer-mask isolation;
       main viewport untouched.
- [x] 3. `minimap_view.gd`: the container + world-sharing SubViewport +
       fixed-basis ortho camera; markers built unshaded on layer 2 and
       attached to the world; chase camera's cull mask drops layer 2;
       tracking gated on RACING; wired from `main.tscn`/`main.gd`.
- [x] 4. `godot/tools/test.sh` green (suite registered); `openspec validate
       --strict`; coverage: M5's deferred count reaches zero; archive
       checklist run.

Notes: task 2 ran RED first; the suite passed on the first wired run. Two
bonus claims landed beyond the plan: "Presenting a loading state" (the
overlay bound to a fresh LOADING sim — the healthy boot builds the world
inside one frame, so the state is only observable that way) and "Ordering
the work within a frame" (the chase camera and minimap read against the
post-physics snapshot through the running scene). Coverage: 57 verified,
M5's deferred count is zero; only M7's four and A11's UNMET remain.
