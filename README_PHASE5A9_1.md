# Phase 5A.9.1 — Run Animation Speed Fix

Fixes the Quaternius Universal Animation Library hook when the selected clip looks like a slow walk.

Changes:
- Prioritizes sprint/run/jog clips before walk clips.
- If only walk/locomotion is available, plays it as a faster runner clip.
- Adds HUD status like `Animation: UAL ... clips • run x2.3`.
- Keeps safe upright character mode; no unsafe bone pose editing.
