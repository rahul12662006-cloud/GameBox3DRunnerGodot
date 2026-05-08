# GameBox 3D Runner — Phase 5A.15.3 Fresh Lane + Asset Alignment Fix

This patch fixes the problems introduced by over-tight lanes in 5A.15.2.

## Fixes
- Restores proper 3-lane movement so the character visibly reaches left/center/right lanes.
- Keeps camera X fixed, so the whole world/assets do not slide left-right.
- Widens/back-steps camera framing so all lanes remain visible.
- Moves lane divider lines between lanes instead of on top of lane centers.
- Pushes temple props/arches/banners farther from the playable road.
- Prevents near-camera banners/props from becoming huge and breaking framing.
- Keeps obstacle spin fix.
- Does not touch slide animation.

## Test points
- Left lane: character should be visible and clearly in the left lane.
- Right lane: character should be visible and clearly in the right lane.
- Obstacles/coins should line up with the three lane centers.
- Side props should not enter the road or dominate the camera.
