## Context

See `proposal.md` — *Why*. What shapes the approach:

- **The next change depends on the order.** `add-aabb-collision-response` resolves
  "the first intersecting prop in registration order only". Whatever order this
  change emits is the order collisions resolve by, and a field that is right as a
  set and wrong as a sequence produces collisions that are wrong and reproducible.
- **The document is unusually specific.** Counts, target heights, clearance radii,
  the distribution, the separation and the attempt budget are all stated. There is
  little to decide and a lot to check — which makes the checks, not the code, the
  interesting part.
- **`scripts/core/normalise.gd` already implements the variation path**, including
  the asymmetry that `with_variation()` re-grounds but does not re-centre. M1 proved
  it against synthetic boxes; this is its first real consumer.
- **`scripts/core/rng.gd` is a static, process-global stream** with `seed_rng()`,
  `state()` and `randf01()`.
- **Acceptance item 2 is "at every random scale"**, and `add-chase-camera` was
  rejected for asserting the kart's aim at the one heading where the bug was
  invisible. The same trap is here, twice: one scale, and one asset.

## Goals / Non-Goals

**Goals:**
- A field that is a pure function of its seed, sequence included.
- Every placement rule the document states, checked against the document.
- Acceptance item 2 held across the whole scale range and all six scattered assets.

**Non-Goals:**
- Collision of any kind. This change registers props as collidable and collides
  with nothing.
- The camera shake, the lap gate, the HUD.
- Deciding A11. The empty outer ring is this change's; the ground's far edge is M6's.

## Decisions

### D1 — Scatter is a pure module in `scripts/core/`, emitting placements, not nodes

`scripts/core/scatter.gd` turns a seed into an ordered array of placements, each a
position, a yaw, a scale and an asset name. A view instantiates meshes from them.

*Why.* Every rule the document states is arithmetic — a distance, a count, a range,
a budget — and the core is where arithmetic can be driven with no scene loaded. It
also keeps the boundary honest: the module cannot accidentally acquire a
`MeshInstance3D`, because the gate that polices this directory forbids it.

*Alternatives considered.* **A view-layer generator that instantiates as it
places** — fewer moving parts and no intermediate representation; rejected because
every placement assertion would then need a scene tree, and because the collision
change needs the placement list as data anyway.

### D2 — Scatter takes an explicit seed and does not share the global stream

`scatter.gd` seeds `rng.gd` at the start of a generation from the seed it is given,
and the caller passes one.

*Why this needs saying.* `rng.gd` is process-global and static. If scatter simply
drew from wherever the stream happened to be, a field would depend on how much
unrelated code had run first — and this change's own spec requires that scattering
twice from one seed agree "even if unrelated code ran in between". Seeding at the
start of each generation makes that true by construction.

*What it costs, stated:* seeding a global stream from inside scatter perturbs
anything else that shares it. Today nothing does — `rng.gd`'s header already
reserves it for gameplay and the view uses the engine RNG for cosmetics — so the
cost is a constraint on the future rather than a present defect. If a second
gameplay consumer appears, this becomes a real conflict and the answer is a stream
object rather than a global.

*Alternatives considered.* **A per-generation stream object** — no global to
perturb, and the obviously cleaner design; rejected for now because it widens
`rng.gd`, which the determinism harness and the replay test both depend on, for a
second consumer that does not exist. Recorded here so the trade is visible when it
does.

### D3 — Registration order is asset order, then placement order within an asset

Placements are emitted asset by asset in the order the design document's table
lists them — `tree`, `rock`, `cone`, `crate`, `tires`, `cottage` — and within each
asset in the order candidates were accepted.

*Why state it at all.* The document does not name an order; it gives a table, and a
table has one. Collision resolves the first intersecting prop in registration order,
so an unstated order would make collision outcomes depend on an implementation
detail nobody wrote down. This is the rule, and the spec carries it so the next
change can rely on it.

*Why not sort by position, or by distance from origin* — either would be stable and
neither is what the document's table implies. A sorted order would also make the
collision change's "first intersecting prop" mean something the document does not
say, which is a bigger decision than it looks.

*If the document turns out to constrain this* where collision needs it pinned
differently, that is an ambiguity and gets a register entry rather than a quiet
choice.

### D4 — The conformance check reads the design document, not `tuning.json`

`tools/check_scatter_conformance.py` parses the populations table out of the
*Scattering the standard prop population* scenario and the rules out of *Rejecting a
candidate placement*, and asserts a generated field against them.

*Why.* Exactly the reasoning that made `check_kart_conformance.py` worth having, and
the gap the third review of `add-world-presentation-layer` named: `scatter_test.gd`
will read `tuning.json`, the same file the generator reads, so it cannot catch a
transcription that misread the document. The counts and radii are the document's
numbers; the check should be too.

*Alternatives considered.* **Trust `check_tuning_transcription.py`** — it will
already compare the transcribed counts against the document's table once it gains
the sixth source; rejected as insufficient on its own, because it checks the DATA
and not the field. A generator that reads the right counts and places a different
number of props passes it.

### D5 — Acceptance item 2 is checked across the range and across every asset

The grounding assertion runs for all six scattered assets, at the extremes of
`scaleVariation` as well as at values in between, and over a generated field rather
than a hand-picked instance.

*Why it is a decision and not a detail.* `add-chase-camera` was rejected for
asserting the kart's aim at yaw 0, where the bug was invisible. "At every random
scale" has the same shape twice over — a check at one scale passes on a generator
that ignores scale, and a check on one asset passes on one that mishandles the
others. The document says "at every random scale"; the test says so too.

## Risks / Trade-offs

- **Order asserted as a set rather than a sequence.** The single most likely way
  this change looks correct and breaks the next one. → The spec says "compared as a
  sequence, not as a set" in as many words, and the test compares serialised
  sequences.
- **A generator that ignores its seed** satisfies every placement rule. → Asserted
  directly: two seeds must differ.
- **The budget test could pass vacuously.** A budget check on a field that places
  easily never exercises the budget. → Driven with a request the rules make
  impossible, so the budget is what ends it.
- **`minPropSeparation` between assets, not just within.** Placing each asset
  against only its own kind satisfies a naive test and produces overlapping props of
  different types. → Asserted across the whole field.
- **Regeneration leaking nodes.** Godot frees on `queue_free`, one frame later; a
  regeneration loop that counts children immediately sees the old ones. → The test
  waits a frame, and the count is asserted rather than assumed.

## Open Questions

- Whether the empty-outer-ring scenario needs its own capture or is adequately
  shown by the seeded-field capture from a viewpoint that includes the ring. Decided
  when the captures are taken; it changes neither the specs nor the tasks.
