# Phase 5A.10.3 — Slide Visual Neutral Fix

This patch removes the hard purple slide silhouette. During slide, the real locked character remains visible. No skeleton crouch retargeting is attempted, so the model should not fold, flip, or turn into the old capsule fallback.

Gameplay slide hitbox remains active for passing under gates.
