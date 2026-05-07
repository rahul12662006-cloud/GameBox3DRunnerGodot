# GameBox 3D Runner - Phase 5A.10.1

Slide animation safety patch.

Changes:
- Stops using unsafe generic slide/crouch retarget clips for the imported humanoid.
- Keeps the run animation active during slide to prevent folded/broken poses.
- Uses safe root lowering + forward lean for slide feel.
- Keeps the gameplay slide hitbox behavior so gates are still passable.
- Avoids crushing the full character model with Y-scale deformation.

Test checklist:
- Press Slide: character should not fold, flip, or shrink badly.
- Slide should pass gate obstacles.
- Run animation should continue smoothly after slide ends.
- Jump and lane change should still work.
