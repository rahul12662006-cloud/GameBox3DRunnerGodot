# GameBox Locked Assets

Phase 5A.7A uses a locked asset pipeline instead of random scanning.

Player pack target:
`assets/gamebox_locked/player/quaternius_fantasy/`

Easiest workflow:
1. Download the Quaternius Modular Character Outfits Fantasy pack.
2. Rename the zip to `quaternius_fantasy.zip`.
3. Upload it to `assets/imported_packs/`.
4. Run GitHub Actions again.

The build script will extract `.glb` / `.gltf` files into the locked player folder.
