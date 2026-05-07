# GameBox 3D Runner - Phase 5A.15

Fresh patch: Camera Lane Framing + Player Visibility Fix

## Fixes
- Character should remain visible in left, center, and right lanes.
- Camera now follows the player's lane position smoothly instead of staying too centered.
- Lanes are slightly tightened for better mobile framing.
- FOV/camera distance adjusted to keep all 3 lanes readable.
- Existing obstacle stability from Phase 5A.14 is preserved.
- Slide animation is not modified in this patch.

## Test checklist
- Move to left lane: character must stay visible.
- Move to right lane: character must stay visible.
- Lane change should feel smooth, not a hard camera snap.
- Obstacles should still stay stable and not spin.
