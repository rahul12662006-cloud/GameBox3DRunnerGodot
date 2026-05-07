# Phase 5A.14 — Gameplay Readability + Obstacle Stability

Code-only patch for GameBox3DRunnerGodot.

Changes:
- Fixed obstacle spin/rotation: crates, barriers, gates, spikes, and blocks now stay stable/readable while moving toward the player.
- Coins and powerups still spin/glow, since those should feel collectible.
- Added stable base rotation/height storage for each spawned item.
- Tightened camera framing to reduce empty upper-screen space.
- Moved HUD/pause slightly down for better Android status-bar safety.
- Slightly cleaned bottom control positioning.

Slide animation is intentionally not modified in this phase.
