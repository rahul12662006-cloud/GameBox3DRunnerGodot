# GameBox 3D Runner - Phase 5A.10.2 Hard Slide Visual Fix

This patch fixes the slide visual without touching image generation.

Changes:
- Disables unsafe slide/crouch skeleton retargeting.
- Hides the Quaternius humanoid only during slide.
- Shows a stable low-profile slide silhouette with speed streaks.
- Keeps slide gameplay hitbox active for gate obstacles.
- Restores the real character immediately after slide.

Test:
- Press Slide near gate obstacles.
- Character should not fold, stretch, or remain upright while sliding.
- Slide should look low and readable.
