# Low Poly Cart — Spec

A starting point for demonstrating **spec-driven development** with a game.

This repo deliberately contains no code. It holds one artifact —
[`low-poly-cart-game-design-document.md`](low-poly-cart-game-design-document.md)
— a build specification complete enough that a working game can be written from
it alone, in any language, on any engine.

## The game

**LowPolyCartJS** is a single-player arcade go-kart time trial: an open green
field scattered with low-poly props, momentum-based handling, a chase camera, a
minimap, and a stopwatch. No opponents, no fail state. Load → countdown → drive
forever.

## The spec

- **Engine- and language-agnostic.** No framework, renderer, or library is named
  in the normative sections. Runtime facilities are described by their *effect*;
  the implementer picks the mechanism.
- **Behaviour as Gherkin.** 14 features, ~64 scenarios. These are the contract.
- **Numbers in one place.** Every constant is named and defined in a single table
  row; scenarios refer to constants by name rather than restating values.
- **Verifiable.** An acceptance checklist with real tolerances says what a
  finished port must demonstrate.

## How it's meant to be used

Read the spec, pick a stack, build the game, and check the result against the
acceptance checklist. The interesting question is how much of the game two
independent implementations agree on — and where the spec was quietly ambiguous.

## Provenance

The spec was reverse-engineered from a reference implementation
(`LowPolyCartJS`, Three.js). **The specification is normative, not the reference
build.** Where the two disagree, *Known Deviations in the Reference Build* lists
the differences so a porter comparing side by side is not surprised.

Optional features are listed at the end and should not be implemented unless
specifically requested.
