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
#
# INSTANTIABLE, because one process-global stream stopped being enough.
# add-seeded-world-scatter drew from the static state and re-seeded it at every
# generation; the camera shake is the second gameplay consumer, and with one
# stream the shake sequence would depend on how many props were scattered and
# would reset whenever the player regenerated the world. That change's design D2
# named this as the trigger and this as the answer.
#
# `Rng.new()` gives an independent stream. The static functions remain and share
# one default stream — they are what tests/smoke_test.gd's known-answer vectors
# exercise, and those vectors are the fixture proving this really is mulberry32
# and not merely something that looks random. Both paths run the SAME arithmetic
# below, so a divergence between them is a bug in this file rather than a choice.

extends RefCounted

const _MASK := 0xFFFFFFFF

## The default stream the static functions share. It exists so the known-answer
## fixture and any caller that does not care about isolation keep working; a
## caller that DOES care constructs its own with Rng.new().
static var _default: RefCounted = null

## This stream's state. Every instance carries its own.
var _state: int = 0

# --- one stream ---------------------------------------------------------------


func seed_stream(seed_value: int) -> void:
	_state = seed_value & _MASK


## Current state — compare this between twin sims to prove a feature drew no
## randomness.
func stream_state() -> int:
	return _state


## THE ARITHMETIC. mulberry32, and the only copy of it: the static functions below
## delegate here rather than repeating it, so the two paths cannot diverge.
func next() -> int:
	_state = (_state + 0x6D2B79F5) & _MASK
	var t: int = ((_state ^ (_state >> 15)) * ((1 | _state) & _MASK)) & _MASK
	t = ((t + (((t ^ (t >> 7)) * ((61 | t) & _MASK)) & _MASK)) ^ t) & _MASK
	return (t ^ (t >> 14)) & _MASK


## Uniform float in [0, 1).
func unit() -> float:
	return float(next()) / 4294967296.0


## Uniform integer in [min_v, max_v], inclusive.
func integer_between(min_v: int, max_v: int) -> int:
	return int(floor(unit() * float(max_v - min_v + 1))) + min_v


## Uniform float in [min_v, max_v).
func range_between(min_v: float, max_v: float) -> float:
	return min_v + unit() * (max_v - min_v)


# --- the shared default stream ------------------------------------------------
#
# Identical behaviour to a constructed stream, because these delegate to one.


static func default_stream() -> RefCounted:
	if _default == null:
		_default = load("res://scripts/core/rng.gd").new()
	return _default


static func seed_rng(seed_value: int) -> void:
	default_stream().seed_stream(seed_value)


static func state() -> int:
	return default_stream().stream_state()


static func next_uint32() -> int:
	return default_stream().next()


static func randf01() -> float:
	return default_stream().unit()


static func between(min_v: int, max_v: int) -> int:
	return default_stream().integer_between(min_v, max_v)


static func float_between(min_v: float, max_v: float) -> float:
	return default_stream().range_between(min_v, max_v)


## Uniform pick from a non-empty array.
static func pick(items: Array) -> Variant:
	return items[between(0, items.size() - 1)]
