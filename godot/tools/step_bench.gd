# The simulation step-cost budget, as a standing check (CONSTRAINTS §8 Performance
# and size budgets): the full 8-stage tick over 54 registered
# props must fit a 60 Hz slice at 144 fps — ≤ 2.3 ms for 2–3 steps, so
# ≤ 0.77 ms per step. Headless, deterministic work, wall-clock only at the
# measurement boundary; fails the suite if the budget is blown.
#
#   godot --headless -s tools/step_bench.gd
extends SceneTree

const Sim := preload("res://scripts/core/sim.gd")
const InputState := preload("res://scripts/core/input_state.gd")
const TuningLoader := preload("res://scripts/tuning_loader.gd")
const Normalise := preload("res://scripts/core/normalise.gd")
const Collision := preload("res://scripts/core/collision.gd")

const STEPS := 60000
const BUDGET_MS_PER_STEP := 0.77


func _init() -> void:
	var s := Sim.new()
	s.tuning = TuningLoader.load_tuning()
	s.input = InputState.new()
	s.race.start_racing_immediately()
	s.kart_normalised = Normalise.to_target_height(
		AABB(Vector3(-1.1, 0.0, -1.18), Vector3(2.2, 1.2, 2.36)), 1.2
	)
	var props: Array = []
	for i in range(54):
		var prop := Collision.Prop.new()
		prop.asset = "bench"
		var x := float((i % 9) - 4) * 18.0
		var z := float(int(i / 9.0) - 2) * 25.0 + 8.0
		prop.box = AABB(Vector3(x - 1.0, 0.0, z - 1.0), Vector3(2.0, 2.0, 2.0))
		props.append(prop)
	s.props = props
	s.input.forward = true
	var t0 := Time.get_ticks_usec()
	for _i in range(STEPS):
		s.step()
	var ms_per_step := (Time.get_ticks_usec() - t0) / 1000.0 / STEPS
	print(
		(
			"step bench: %d props, %d steps, %.5f ms/step (budget %.2f)"
			% [props.size(), STEPS, ms_per_step, BUDGET_MS_PER_STEP]
		)
	)
	if ms_per_step > BUDGET_MS_PER_STEP:
		printerr("step bench: OVER BUDGET — CONSTRAINTS §8 Performance and size budgets")
		quit(1)
		return
	quit(0)
