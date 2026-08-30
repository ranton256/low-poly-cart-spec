# Tasks: add-render-pipeline-and-web-budget

- [x] 1. Capture determinism: post-draw grab in `drive_capture.gd` (and the
       shared capture path), a freshness guard, the settle floor measured by
       double-capture diff; the twice-bitten Backlog line retired with the
       measurement recorded.
- [x] 2. A11: the ground skirt in `world_builder.gd` (same albedo, past
       fog's end, no grid, no shadow casting, no collision); boundary
       capture through the chase camera; A11 moved to Resolved with the
       fourth-option rationale; the UNMET register entry gains its capture.
- [x] 3. Minimap fog: a fog-free Environment on the minimap camera;
       `minimap_test.gd` asserts it; Backlog line retired; the port decision
       recorded in the minimap capability spec via this delta.
- [x] 4. Filtering and density: anisotropic level pinned in project settings
       (and `check_settings.py`); the 2× DPI cap in `main.gd` with its
       arithmetic claimed as a verified scenario; the resize survival test
       claims its scenario; both register entries retired.
- [x] 5. Web: `export_presets.cfg` with a Web preset; release export built;
       compressed payload measured against 25 MB and recorded; cold-load
       split disclosed as an M8 Backlog line.
- [x] 6. `godot/tools/test.sh` green; `openspec validate --strict`; archive
       checklist run.

Notes: the payload measurement earned its keep instantly — 89.2 MB gzip-9
against the 25 MB budget on first export, all of it lossless 2048² extracted
textures. En route to 20.5 MB the change also caught a CONSTRAINTS drift:
the "kart textures 2048² retained" row misread the GDD, whose sentence sets
1024 as the kart's FLOOR ("do not go below that for the kart") and no floor
at all for props — so props ship at 512, the kart at 1024, Basis Universal
throughout, stamped by one committed tool the standing suite now checks.
A11's fourth option looks exactly as hoped through the chase camera: grass
into fog, no edge, every stated number untouched. The document now has zero
UNMET scenarios.
