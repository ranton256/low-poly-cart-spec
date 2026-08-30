# Proposal: add-circuit-world-and-presentation

## Why

With the core landed, the game still boots a gateless field and shows the
player nothing new. This change makes the circuit the game: the shipped
circuit becomes the boot world, `G` becomes Restart Circuit, the gates
become visible and findable, and every interim recorded by the two changes
before it is paid off — the gateless-file refusal, the `minLapTime`
deletion, the G2 re-pointing, and the gallery. It is the biggest visual
change since M2, and the proposal says so rather than discovering it.

## What Changes

- **The shipped circuit**: `data/circuits/first-light.json` (name
  provisional) — a version-2 layout authored by hand from a curated scatter:
  6–8 gates using the field's clearings, targets set by playtest and
  recorded the way the M4 probe tunings were. Committed content, validated
  by a test (gates inside the boundary, no curated prop in any gate mouth,
  targets ordered bronze > silver > gold).
- **Boot from the circuit**: `main.gd` loads the shipped file instead of
  scattering; a load failure is the existing terminal LOADING verdict. The
  scatter path remains for the authoring tools and suites (the GDD keeps it
  normative for authoring).
- **Restart Circuit**: the `regenerate` action re-bound — rebuild the
  authored world, kart to start pose, cursor to 1, clock from zero, keyed
  best kept, no countdown, never leaving RACING.
- **Gateless files refused** on load with a named error (the interim
  acceptance recorded in the core change ends here); `minLapTime` deleted —
  the `port_decisions` key and the loader read, as the bridge note promised.
- **Gate presentation** (`scripts/view/gate_view.gd`): generated pylons,
  ground stripe, overhead chevron and billboard numeral per gate; state
  colours from the data layer (`gateNextColour` / `gatePassedColour` /
  `gateIdleColour`), the next-gate pulse on the SIM clock; non-colliding;
  main-view/minimap layering per the mask rules.
- **Wayfinding**: `GATE n/N` in the timer block; the screen-edge chevron
  toward an off-screen next gate; minimap gate markers with the next gate
  emphasised — all pure consumers of the core cursor.
- **Medal display**: the held TIME readout joined by the earned medal name
  in its colour for the hold window, from the core's bank-time verdict.
- **G2 re-pointed**: `_item_01` (boots into the shipped circuit),
  `_item_02` (grounding via the authoring machinery, since the boot field
  is no longer random), `_item_10` (threaded-lap banking, no minimum),
  `_item_15` (new: gates, wayfinding, refusal to bank unthreaded, restart
  semantics). The §5 G2 row returns to ✅.
- **Gallery**: re-blessed once against the authored world — every state
  changes (new boot field) and a `gate_next` state joins the set
  (the next gate under its pulse, at a sim-exact tick); noise floor
  re-measured and recorded, as at M8.
- **Coverage**: the remaining M9 deferrals claimed (Restarting the circuit,
  Medal targets, What a gate looks like, Finding the next gate, the
  refusal half of A layout is a circuit); the register's M9 count returns
  to zero. Hint line updated to the amended GDD text.

## The milestone close

After this archives, M9's Critic pass runs as always — a fresh subagent,
verdict on the record — plus the thing no suite can do: a playtest, because
the targets are tuning and the course is content. The proposal plans for
one round of target adjustment after the owner drives it.

## What is deliberately excluded

- Sound (M10) — the gate-pass and medal cues have reserved slots only.
- Session flow, ghost, persistence (M11); a circuit editor; more circuits.
