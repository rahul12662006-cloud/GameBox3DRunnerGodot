# GameBox 3D Runner Godot

Phase 5A.7A focuses on a locked asset pipeline for proper visuals.

## Current state

- Real Godot 3D runner prototype
- Lane left/right, jump, slide
- Obstacles, coins, score, game over
- Android GitHub Actions APK build
- Locked asset loader for Quaternius player pack

## Add the Quaternius character pack

1. Download the Quaternius Modular Character Outfits Fantasy pack.
2. Rename the ZIP to:
   `quaternius_fantasy.zip`
3. Upload it into:
   `assets/imported_packs/`
4. Run GitHub Actions again.

The build script extracts `.glb` / `.gltf` files into:
`assets/gamebox_locked/player/quaternius_fantasy/`

The game loads locked assets first, then falls back to bundled GameBox starter GLBs, then procedural shapes.

## Why locked assets?

The earlier random auto asset scan created inconsistent visuals and missing `.mtl` import warnings. Locked assets keep the project predictable and easier to polish.
