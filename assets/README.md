# Art assets

The seven supplied models referenced by
[`../low-poly-cart-game-design-document.md`](../low-poly-cart-game-design-document.md).
Binary glTF (`.glb`), one mesh and one material each, ~39 MB total.

| File | Role |
|---|---|
| `kart.glb` | Player vehicle |
| `tree.glb` | Tall scenery |
| `rock.glb` | Boulder obstacle |
| `cone.glb` | Small traffic cone |
| `crate.glb` | Wooden box obstacle |
| `tires.glb` | Stacked tyre barrier |
| `cottage.glb` | Distant landmark building |

## Before you use these

These models arrive at arbitrary authored scale with their origin at the
**centre** of the bounding box, not the base. They are not usable as-is:
dropping one into a scene puts it half underground at the wrong size.

Run every instance through the normalisation contract in **§3** of the spec,
and note the **§4** kart orientation contract — the kart's nose is not aligned
with world forward as authored.

## Verified against the spec

Every file was checked against the spec's §1 and §2 tables when copied here.
Triangle counts and native bounding boxes match to three decimal places; each
model is single-mesh and single-material, carries three textures (base colour,
metallic-roughness, normal), and has a white base-colour factor with metallic
and roughness factors of 1.0, no emissive, and no transparency — so those
values come entirely from the textures.

To re-verify after any change, compare against the spec's §1 inventory table.

## Provenance and licence

Copied byte-identical from the reference implementation `LowPolyCartJS`.
Generated with [Meshy.ai](https://meshy.ai) using the prompt parameters recorded
in **§8** of the spec, which is also what to use if you need to produce
additional props that match the set.

MIT licence, Copyright (c) 2026 Richard Anton.
