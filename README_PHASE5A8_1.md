# GameBox 3D Runner — Phase 5A.8.1 Upright Character Fix

This patch fixes the Quaternius character flipping upside-down after the Phase 5A.8 skeleton pose attempt.

## Changes
- Disables direct skeleton/bone pose edits for Quaternius outfit models.
- Keeps the real imported character upright.
- Adds safe root-level micro-bob only.
- HUD now shows `Character: LockedCharacter.tscn • safe upright`.

This is a stability patch. Proper run animation should be added later using a compatible animation library/rig workflow instead of guessing bone axes.
