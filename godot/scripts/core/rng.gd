# Seeded RNG — mulberry32.
#
# Why not randi(): the engine RNG is fine for cosmetics but useless as a
# regression tool. You want a generator you can seed, whose sequence is
# reproducible across runs and across machines, and whose STATE you can compare
# (see templates/rng_differential.template.gd).
#
# GDScript ints are 64-bit, so every operation is masked back to 32 bits. Get
# that wrong and the sequence silently diverges from every other implementation
# of the same algorithm — which is exactly the kind of bug a fixture test with
# known-good vectors is for.
#
# Deliberately NOT a class_name: global class names resolve from a cache the
# EDITOR writes, so a class added without opening the editor is invisible to
# `godot -s` on a fresh clone. Tests preload this by path instead.

const _MASK := 0xFFFFFFFF

static var _state: int = 0


static func seed_rng(seed_value: int) -> void:
	_state = seed_value & _MASK


## Current state — compare this between twin sims to prove a feature drew no
## randomness.
static func state() -> int:
	return _state


static func next_uint32() -> int:
	_state = (_state + 0x6D2B79F5) & _MASK
	var t: int = ((_state ^ (_state >> 15)) * ((1 | _state) & _MASK)) & _MASK
	t = ((t + (((t ^ (t >> 7)) * ((61 | t) & _MASK)) & _MASK)) ^ t) & _MASK
	return (t ^ (t >> 14)) & _MASK


## Uniform float in [0, 1).
static func randf01() -> float:
	return float(next_uint32()) / 4294967296.0


## Uniform integer in [min_v, max_v], inclusive.
static func between(min_v: int, max_v: int) -> int:
	return int(floor(randf01() * float(max_v - min_v + 1))) + min_v


## Uniform float in [min_v, max_v).
static func float_between(min_v: float, max_v: float) -> float:
	return min_v + randf01() * (max_v - min_v)


## Uniform pick from a non-empty array.
static func pick(items: Array) -> Variant:
	return items[between(0, items.size() - 1)]
