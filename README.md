# GameBox 3D Runner Godot - Phase 5A.4

Real 3D runner prototype for GameBox Builder.

Includes fixes through Phase 5A.4:
- Android export preset fix.
- Android black-screen fix using compatibility renderer.
- Visual/camera cleanup.
- Runner motion-feel upgrade: animated limbs, body bob, lane-change lean, camera bob/FOV, road dash motion, side environment parallax.
- Procedural low-poly polish: segmented road, better rails/lane glow, cleaner buildings/windows/street lights, improved player model details, polished obstacles, transparent rounded controls, feedback text, small screen shake.

Build via GitHub Actions and download the Android APK artifact.

## Phase 5A.5 - Auto CC0 Asset Pipeline

This build adds an automated asset pipeline. During GitHub Actions, `tools/install_cc0_assets.sh` tries to download Kenney CC0 3D Road Tiles and places compatible model files under `assets/vendor/kenney_3d_road_tiles/`.

If the download fails or the pack structure changes, the APK still builds using built-in fallback models.

Manual asset option:

1. Place `.glb`, `.gltf`, `.obj`, `.tscn`, or `.scn` files under `assets/imported/`.
2. Push to GitHub.
3. Re-run the APK workflow.

The runtime scans these folders and uses matching models for barriers, cones, crates, lamps, buildings, and environment props when available.
