# Phase 5A.9 — Universal Animation Library Hook

Adds support for `assets/imported_packs/quaternius_animations.zip`.

The GitHub Actions asset installer extracts `UAL_Standard.glb`, generates `scenes/LockedAnimations.tscn`, and the runtime tries to retarget animation clips from the UAL source to the loaded Quaternius character skeleton.

If retargeting works, HUD will show `Animation: UAL ... clips`.
If it fails, character stays upright and safe; no upside-down bone guessing.
