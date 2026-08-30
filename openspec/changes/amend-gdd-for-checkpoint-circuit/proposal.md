# Proposal: amend-gdd-for-checkpoint-circuit

## Why

The port is conformant and the game is not a game. The lap rule is invisible
(the hint line never mentions it) and degenerate (optimal play is a tight
5-second loop; best time converges on ~5.0x and stops measuring skill). The
GDD's own Optional Feature 5 names the fix — ordered checkpoint gates
"replacing the current 5-second minimum with genuine lap validation" — and
its own change process (§16 route, exercised twice at M8 for A12 and A14) is
how a normative document grows. This change drafts that amendment; the
implementation follows in separate changes with their own delta specs.

**This feature has no reference build.** Everything the GDD specifies so far
was reverse-engineered from LowPolyCartJS; the circuit is specified fresh.
The Known Deviations section is untouched — there is nothing to deviate from
— and every decision below is made on the record here instead.

## What changes in the GDD (full text in `gdd-amendment.md`)

- A new **Feature: Checkpoint Circuit** in the GDD's own idiom, after Lap
  Detection.
- The Lap feature's *Completing a valid lap* scenario and rejection table
  are amended: in circuit mode the `minLapTime` condition is **replaced** by
  all-gates-in-order; procedural mode keeps `minLapTime` unchanged.
- **Track Layout Persistence** grows layout **version 2**: an optional
  `circuit` object (name, ordered gates, medal targets) beside `props`, so a
  circuit always ships with its curated prop field and no cottage can block
  a gate mouth. Version-1 files stay valid and mean procedural mode.
- The **HUD feature** gains the gate counter, the off-screen next-gate
  chevron, and an amended hint line that finally names the objective.
- The **Minimap feature** gains gate markers with the next gate emphasised.
- **Tuning Constants** gains a Circuit table (gate depth, crossing
  threshold, visual dimensions and state colours).
- **Acceptance item 10 is amended** and an **item 15** added; the Optional
  Features list marks 5 as promoted by this amendment.

## Decisions made here, on the record

1. **A gate is a directed ground segment** — centre (X, Z), yaw, width —
   tested exactly like the band: position inside a thin gate-local slab,
   |lateral| under half the width, and the tick's **step-5** displacement
   component along gate-forward above the threshold. Same stage, same
   observe-only ordering, same immunity to push-out and boundary shove that
   the band's scenarios already argue for.
2. **Out-of-order, repeated, and backwards passes are ignored** — only the
   next expected gate advances progress; nothing resets or voids a lap.
   Forgiveness keeps the failure mode legible (you simply haven't passed
   gate N yet) and adds no punitive state a player can't see.
3. **Reset Kart does not touch circuit progress.** Reset's own spec says
   "the start pose and NOTHING else", and there is no shortcut to protect
   against: the band still refuses to bank until the remaining gates are
   passed.
4. **Regenerate World returns to procedural mode.** G discards the circuit
   with the world it decorated; loading a circuit layout arms circuit mode.
5. **Best times are per context.** A session best belongs to the circuit
   name that produced it (or to "procedural"); switching context switches
   which best is shown. Medal targets only compare within their own circuit.
6. **Gates are furniture, not obstacles** — non-colliding, like the band.
   A clipped pylon that stops the kart dead in the gate mouth punishes the
   exact line the game just asked the player to drive.
7. **Gate visuals are generated geometry** in the band's family (pylon
   pair, ground stripe, overhead chevron; state told by colour, animated on
   the sim clock) — no new models, no textures, distinctness from props
   guaranteed by vocabulary rather than asset budget.
8. **The game ships at least one authored circuit** as a committed
   version-2 layout file; authoring is by hand in JSON for now (no editor).

## What is deliberately excluded

- Implementation. This change amends the document; the sim module, views,
  file format code, the shipped circuit, and the conformance case arrive in
  follow-up changes with delta specs against godot/* capabilities.
- Sound (M10), session/end state and ghost (M11), any new input action.
- An in-game circuit editor, multiple shipped circuits, checkpoint
  time-splits — all future options, none required for the objective to work.
