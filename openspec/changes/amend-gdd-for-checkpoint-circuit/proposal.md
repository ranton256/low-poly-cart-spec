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

## The shape (owner's direction, 2026-08-30)

**The game is circuit-only.** There is no free-roam mode to preserve: the
game boots into the shipped circuit, and **Regenerate World becomes Restart
Circuit** — `G` rebuilds the authored world, returns the kart to the start,
resets gate progress, and restarts the clock, keeping the session best. The
`minLapTime` farming defence retires entirely; the ordered gates are the
better one and there is no mode left that needs the old one.

## What changes in the GDD (full text in `gdd-amendment.md`)

- A new **Feature: Checkpoint Circuit** in the GDD's own idiom.
- **Session Bootstrap** amended: the world is built by loading the shipped
  circuit layout; a load failure is the existing terminal LOADING state.
- **Procedural World Generation** amended: the scatter rules survive as the
  normative *authoring* machinery (they made the shipped field, and tools
  and tests pin them), but the player-facing action is re-bound — the
  *Regenerating the world on demand* scenario becomes *Restarting the
  circuit*.
- The Lap feature's *Completing a valid lap* and its rejection table are
  amended: all-gates-in-order replaces `minLapTime`, which retires from the
  tuning tables with a note.
- **Track Layout Persistence** grows layout **version 2**: `circuit`
  (name, ordered gates, medal targets) beside `props`. A loadable file must
  carry a circuit; version-1 files are refused with a named error and
  remain authoring artifacts.
- The **HUD** gains the gate counter and edge chevron; the hint line
  finally names the objective. The **Minimap** gains gate markers.
- **Tuning Constants** gains a Circuit table; **acceptance item 10** is
  amended, **item 15** added; Optional Feature 5 marked promoted.

## Decisions made here, on the record

1. **A gate is a directed ground segment** — centre (X, Z), yaw, width —
   tested exactly like the band: position inside a thin gate-local slab,
   |lateral| under half the width, and the tick's **step-5** displacement
   component along gate-forward above the threshold. Same stage, same
   observe-only ordering, same immunity to push-out and boundary shove.
2. **Out-of-order, repeated, and backwards passes are ignored** — only the
   next expected gate advances the cursor; nothing resets or voids a lap.
3. **Reset Kart does not touch circuit progress** — it stays "the start
   pose and NOTHING else"; `G` is the full restart, and the two now form a
   clean hierarchy (pose only / whole attempt).
4. **`G` = Restart Circuit**: props rebuilt from the circuit file, kart to
   the start pose, cursor to 1, clock from zero after the countdown-free
   restart; the session best is kept. (Owner's direction; replaces the
   earlier two-mode draft.)
5. **Best times are per circuit** — keyed by the circuit `name`, since
   other circuits remain loadable with `L` and times across courses are
   incomparable. Medal targets compare only within their own circuit.
6. **Gates are furniture, not obstacles** — non-colliding, like the band.
7. **Gate visuals are generated geometry** in the band's family (pylons,
   ground stripe, overhead chevron; state told by colour, animated on the
   sim clock) — no new models, no textures.
8. **The shipped circuit is a committed version-2 layout file**, authored
   by hand from a curated scatter; the file carrying props and gates
   together is the guarantee no prop blocks a gate mouth.

## Implementation ripple, stated honestly

Re-plumbing the boot (scatter-from-seed → load-shipped-circuit) touches
more of the port than any prior feature: every gallery baseline re-blesses
against the authored world, the suites that boot the real scene inherit the
circuit, and the conformance items that assumed a random field (props at
every random scale) need the authoring-machinery path instead. That cost is
real and is the implementation changes' problem to itemise — it does not
change what the document should say.

## What is deliberately excluded

- Implementation, sound (M10), session/end state and ghost (M11), any new
  input action, an in-game circuit editor, checkpoint time-splits.
