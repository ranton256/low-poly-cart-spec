# Headless Godot and visual verification: things that cost real time

Each entry leads with the **symptom**, because that is how you will arrive here.
Every one of these was paid for once already.

---

## Headless harnesses

### "My seed is ignored — runs differ every time"

**Cause.** Autoloads *do* load under `godot -s`. If one of them randomises the
RNG in `_ready`, it runs on a **deferred first frame** — after your script's
`_init` has already seeded. Your seed is set, then overwritten.

**Fix.** `await process_frame` before seeding, always:

```gdscript
func _init() -> void:
    await process_frame     # let autoloads finish _ready
    MyRng.seed_rng(12345)   # now it sticks
```

---

### "I configured the autoload but the game ignores it"

**Cause.** You added your own instance of the autoload script. Godot renames the
new node on name collision, and the scenes are talking to the original at
`/root/Config`. You configured a node nothing reads.

**Fix.** Fetch the real one: `root.get_node("/root/Config")`.

---

### "Scene changes hang in headless, but work when I play the game"

**Cause.** A scene-transition autoload animating on **wall-clock** time (a wipe,
a fade). Headless frames arrive far faster than the tween expects, so the
transition never finishes and the next scene never loads.

**Fix.** Free that autoload in headless drivers. Route scene changes through a
helper that falls back to a direct change when the transition node is absent, so
harnesses need no special-casing beyond the free.

---

### "Identifier <MyClass> not declared" — but the class file exists

**Cause.** `class_name` registrations live in a cache the **editor** writes. A
class added without opening the editor is invisible to `godot -s`, and every
suite that references it dies at parse time. It works on your machine (stale
cache) and fails on a fresh clone.

**Fix.** In test/tool scripts, `preload` instead of relying on the global name:

```gdscript
const RVTest := preload("res://tests/harness.gd")
```

---

### "My test run wiped my actual save file"

**Cause.** The suite used the real save path. This is not hypothetical: a suite
ran during a playtest and destroyed a fully-equipped campaign.

**Fix.** Make the save path overridable by environment variable, and set it in
*every* harness, including capture scripts:

```gdscript
static func save_path() -> String:
    var override := OS.get_environment("MY_SAVE_FILE")
    return override if override != "" else SAVE_PATH
```

---

### "The RNG stream desynced and I changed nothing"

**Cause.** A synthesized confirm press arrived twice, re-entering the next scene.
Its setup ran again — and consumed RNG. In the case that was debugged, a stray
Enter re-instantiated the game scene and silently burned **300 starfield draws**.

**Fix.** One confirm per screen. When a driver asserts a transition, assert
arrival before sending the next key rather than firing keys on a timer.

---

### "Screenshots come out blank"

**Cause.** Headless has no renderer. `get_viewport().get_texture()` gives you
nothing.

**Fix.** Captures need a **windowed** run. Accept the split: a headless standing
suite that runs anywhere, and a separate windowed visual gate. Do not try to put
the visual gate on a headless machine without a virtual framebuffer.

---

## Determinism

### "The same capture differs between identical runs"

Work through these in order — they are ranked by how often they are the cause.

1. **Animation driven by wall-clock time.** Anything using frame `delta` for a
   position or a frame index is unreproducible by construction. Drive view
   animation from the **simulation clock**. This single change is what makes
   both screenshot diffing and renderer-free motion tests possible.
2. **Unseeded particle systems.** Set a fixed seed.
3. **Effects drawn from the engine RNG.** See the next entry.

---

### "I seeded the engine RNG and the capture STILL differs"

**Cause, and this one is worth internalising: a non-deterministic *call count*
cannot be fixed by a seed.**

Camera shake drew from the engine RNG — deliberately, so that cosmetic
randomness could never perturb the gameplay stream. But how many times the view
synced before the capture depended on physics/render interleaving, which is
wall-clock dependent. Same seed, different number of draws, different offset.
The state measured 6.6–9.1/255 between identical runs.

**Fix.** Settle the effect before capturing, rather than trying to seed it:

```gdscript
func _settle(view) -> void:
    view.sim.shake_until_ms = 0.0   # end the effect
    view._sync()
```

0.0000 after. A still frame cannot convey shake anyway — it just reads as
off-centre — so nothing of value was lost.

**The general form:** for any effect whose *number of random draws* depends on
timing, seeding is not enough. Either make the effect a pure function of the sim
clock, or settle it before you measure.

---

### "Reference images generate .import files and bloat my export"

**Cause.** Godot imports everything under `res://`, including your baseline
screenshots — a sidecar each, all shipped in every export.

**Fix.** Put a `.gdignore` file in that directory. Godot skips the directory
entirely.

---

## Verifying the verification

### "The gate is green but the screen is visibly wrong"

**Cause.** A whole-frame **mean** difference dilutes localised change. A band
covering 3% of the screen, shifted by 40/255 — obvious to any reviewer — averages
to about 0.4 and slips under a 0.5 mean-only threshold.

**Fix.** Use three criteria, not one: mean, percentage of pixels changed at all,
and percentage changed *strongly*. A local change fails on area even when it
passes on mean.

---

### "What should my threshold be?"

**Measure it; do not guess.** Capture the same states twice without changing
anything and diff. That is your noise floor. Set the limit a small multiple
above it and **write the measurement down next to the number**, so the next
person knows whether it is evidence or a guess.

If the noise floor is not near zero, something is non-deterministic — fix the
harness rather than raising the threshold. A state that cannot be reproduced is
a harness bug, not a tuning problem.

Beware borrowing numbers from a different comparison. Thresholds calibrated for
*cross-implementation* differences (port A vs port B) are wildly loose for
*same-machine* baselines, where the honest floor is usually zero.

---

### "The test refactor is green, so it works"

**No.** Green after a test refactor is not evidence — a `check()` accidentally
turned into a no-op leaves every suite green and verifying nothing.

**Fix.** Record suite output *before* the refactor and require it byte-identical
after. Then deliberately break what each tool guards and confirm the right tool
fails with the right message. Keep that mutation script; run it whenever the
harness itself changes.

---

### "My new gate passes, so it works"

The same trap one level up, and it catches the person who just wrote the gate.

`tools/check_section_refs.py` was written to catch exactly one bug: a roadmap
still pointing at section ten of the constraints document after an inserted
section had renumbered the real target to eleven. Version one checked that the
referenced section number *existed*. It passed the clean tree — and when the
break was reintroduced deliberately, **it passed that too.** After a renumber,
the stale number still names a real section. Just the wrong one.

An existence check cannot detect a reference that has quietly moved to a
different valid target. The fix was not a cleverer check but a better *reference
format*: carry the section title next to the number, so the reference describes
what it expects and a bare number is itself an error.

**Fix, and this is the general form:** a gate is not finished when it passes. It
is finished when you have watched it fail on the exact defect it exists to catch.
If you cannot construct that failure, you do not yet know what your gate does.

---

### "The docs say it is pinned / required / enforced"

Claims about enforcement rot faster than code, and nothing complains. Two found
in a single review, both in the commit that introduced the rules they broke:

- a `requirements.txt` with no version specifiers, under a document heading
  asserting that versions were pinned
- a `.venv` guard that checked whether the *interpreter* existed but never
  whether the packages were installed — so an empty venv passed and the suite
  reported success, right up until the first tool needed Pillow

**Fix.** When a document claims something is enforced, run the thing that
enforces it and watch it fail. Mark every constraint with its real status —
enforced, planned, or convention — and treat an over-claim as a defect. A gate
everyone believes in and nobody has tested is worse than an acknowledged gap,
because the gap at least gets scheduled.

---

### "We verified this months ago but nobody can reproduce how"

**Cause.** The verification ran from a scratchpad and was never committed. This
happened **three times** in the project this kit came from: the gallery
comparison, a motion check, and a palette audit — all used to sign off shipped
work, all gone. One tool had to have its parameters recovered by grid-fitting
against its own committed output.

**Fix, and make it a rule: if you verify something to sign off work, commit the
method as a tool before calling the work done.** A number in a commit message is
not a verification; it is a memory of one.
