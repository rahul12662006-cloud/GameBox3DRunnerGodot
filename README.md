# GameBox 3D Runner — Godot Real 3D Prototype

This is Phase 5A for the GameBox Builder project: a real 3D Android runner template made in Godot, separate from the Kotlin/Compose builder app.

## What is included

- Real 3D runner scene using Godot 4.6.x
- 3 lanes
- Lane left / lane right controls
- Jump and slide
- Obstacles, gates, coins, and powerups
- Score, best score, game over, restart
- Config-driven template via `configs/config.json`
- Android APK export preset
- GitHub Actions workflow for APK build

## Config file

Edit `configs/config.json`:

```json
{
  "gameName": "GameBox 3D Runner",
  "map": "city",
  "character": "runner_boy",
  "speed": 3,
  "difficulty": 2,
  "coinsEnabled": true,
  "powerupsEnabled": true,
  "obstaclePack": "mixed_starter_pack"
}
```

Supported map values: `city`, `jungle`, `desert`, `snow`, `cyber`.

## Android build with GitHub Actions

1. Create a new GitHub repo, for example `GameBox3DRunnerGodot`.
2. Upload/extract this project in the repo root.
3. Open **Actions**.
4. Run **Build Godot 3D Runner APK**.
5. Download the APK artifact.

## Termux upload commands

```bash
cd /sdcard/Download
unzip GameBox3DRunner_Godot_Phase5A.zip -d ~/GameBox3DRunnerGodot
cd ~/GameBox3DRunnerGodot/GameBox3DRunner_Godot

git init
git branch -M main
git add .
git commit -m "Add GameBox Godot 3D runner prototype"
git remote add origin https://github.com/YOUR_USERNAME/GameBox3DRunnerGodot.git
git push -u origin main
```

If GitHub asks for password, use a GitHub personal access token, not your normal password.

## Notes

- This is a separate real-3D runtime prototype. It does not replace the Kotlin builder app yet.
- Next step is Builder integration: GameBox Builder exports config, Godot reads it, GitHub Actions builds the final APK.


## Android export fix notes

This version keeps Godot Android export in non-Gradle template mode. Do not set `gradle_build/min_sdk` or `gradle_build/target_sdk` unless `gradle_build/use_gradle_build=true`; otherwise Godot will reject the export preset. The GitHub Actions workflow installs Android SDK platform 35 and Build Tools 35.0.1.
