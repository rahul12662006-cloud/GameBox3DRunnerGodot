#!/usr/bin/env bash
set -euo pipefail

# GameBox 3D Runner - locked asset installer.
# Phase 5A.7A
# This does NOT random-scan the internet during builds. It prepares a clean pipeline.
# Optional: place a downloaded Quaternius character zip at:
#   assets/imported_packs/quaternius_fantasy.zip
# The workflow will extract compatible .glb/.gltf files into:
#   assets/gamebox_locked/player/quaternius_fantasy/

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${ROOT_DIR}/.asset_cache"
PACK_DIR="${ROOT_DIR}/assets/imported_packs"
LOCKED_ROOT="${ROOT_DIR}/assets/gamebox_locked"
PLAYER_DIR="${LOCKED_ROOT}/player/quaternius_fantasy"
ROAD_DIR="${LOCKED_ROOT}/road"
OBSTACLE_DIR="${LOCKED_ROOT}/obstacles"
ENV_DIR="${LOCKED_ROOT}/environment"
UI_DIR="${LOCKED_ROOT}/ui"
MANIFEST="${LOCKED_ROOT}/asset_status.json"

mkdir -p "${CACHE_DIR}" "${PACK_DIR}" "${PLAYER_DIR}" "${ROAD_DIR}" "${OBSTACLE_DIR}" "${ENV_DIR}" "${UI_DIR}"

cat > "${LOCKED_ROOT}/README_LOCKED_ASSETS.md" <<'TXT'
# GameBox Locked Assets

Use this folder for hand-picked, predictable assets.

Recommended player pack:
- Quaternius Modular Character Outfits Fantasy
- Put downloaded zip here before build: `assets/imported_packs/quaternius_fantasy.zip`

The GitHub Action will extract compatible `.glb` and `.gltf` files into:
`assets/gamebox_locked/player/quaternius_fantasy/`

Why this exists:
- Random OBJ/MTL imports caused ugly or broken visuals.
- Locked assets make the game predictable and easier to polish.
TXT

for d in "${PACK_DIR}" "${PLAYER_DIR}" "${ROAD_DIR}" "${OBSTACLE_DIR}" "${ENV_DIR}" "${UI_DIR}"; do
  touch "${d}/.gitkeep"
done

count=0
source_pack="none"
zip_path="${PACK_DIR}/quaternius_fantasy.zip"
if [[ -f "${zip_path}" ]]; then
  echo "Found Quaternius fantasy character pack: ${zip_path}"
  rm -rf "${CACHE_DIR}/quaternius_fantasy"
  mkdir -p "${CACHE_DIR}/quaternius_fantasy"
  unzip -q -o "${zip_path}" -d "${CACHE_DIR}/quaternius_fantasy"

  # Clean previously extracted dynamic files but keep README/.gitkeep.
  find "${PLAYER_DIR}" -maxdepth 1 -type f \( -iname '*.glb' -o -iname '*.gltf' -o -iname '*.bin' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -delete

  # Copy a limited stable set to keep APK size reasonable.
  while IFS= read -r -d '' file; do
    base="$(basename "$file")"
    lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
    # Prefer real model-looking files and avoid huge preview/sample files when names expose that.
    if [[ "$lower" == *preview* || "$lower" == *thumbnail* ]]; then
      continue
    fi
    safe_name="$(printf '%s' "$base" | tr ' ' '_' | tr -cd '[:alnum:]_.-')"
    cp -f "$file" "${PLAYER_DIR}/${safe_name}"
    count=$((count + 1))
    if [[ "$count" -ge 12 ]]; then
      break
    fi
  done < <(find "${CACHE_DIR}/quaternius_fantasy" -type f \( -iname '*.glb' -o -iname '*.gltf' \) -print0)

  # If glTF files reference .bin/textures next to them, copy nearby support files too.
  while IFS= read -r -d '' file; do
    cp -f "$file" "${PLAYER_DIR}/$(basename "$file")" || true
  done < <(find "${CACHE_DIR}/quaternius_fantasy" -type f \( -iname '*.bin' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0 | head -z -n 60)
  source_pack="quaternius_fantasy_zip"
else
  echo "No assets/imported_packs/quaternius_fantasy.zip found. Build will use GameBox starter/fallback player."
  cat > "${PACK_DIR}/README_DROP_QUATERNIUS_ZIP_HERE.md" <<'TXT'
# Drop Quaternius Pack Here

Put the downloaded character pack ZIP here and rename it exactly:

`quaternius_fantasy.zip`

Then run GitHub Actions again.
TXT
fi

cat > "${MANIFEST}" <<JSON
{
  "phase": "5A.7A",
  "sourcePack": "${source_pack}",
  "playerModelsInstalled": ${count},
  "lockedPlayerFolder": "assets/gamebox_locked/player/quaternius_fantasy"
}
JSON

echo "Locked asset install complete. Player model count: ${count}"
