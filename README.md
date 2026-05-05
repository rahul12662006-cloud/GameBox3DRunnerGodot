# GameBox 3D Runner — Phase 5A.1 Black Screen Fix

This patch switches the Godot project to the compatibility renderer and replaces `scripts/Main.gd` with an Android-safe runner scene that shows a boot UI before creating the 3D world.

Apply over the existing `GameBox3DRunnerGodot` repo, commit, push, then rebuild the APK in GitHub Actions.
