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
  find "${PLAYER_DIR}" -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} + 2>/dev/null || true
  mkdir -p "${PLAYER_DIR}/quaternius_extracted"

  # IMPORTANT:
  # Copy the full Godot glTF export folder, not random first files.
  # Quaternius glTF outfits depend on sibling folders/materials. Randomly copying 12 files caused fallback/parts only.
  gltf_root=""
  while IFS= read -r -d '' d; do
    if [[ "$d" == *"Exports/glTF (Godot-Unreal)"* ]]; then
      gltf_root="$d"
      break
    fi
  done < <(find "${CACHE_DIR}/quaternius_fantasy" -type d -print0)

  if [[ -n "${gltf_root}" && -d "${gltf_root}" ]]; then
    echo "Using Quaternius Godot glTF root: ${gltf_root}"
    cp -R "${gltf_root}/." "${PLAYER_DIR}/quaternius_extracted/"
    count=$(find "${PLAYER_DIR}/quaternius_extracted" -type f \( -iname '*.glb' -o -iname '*.gltf' \) | wc -l | tr -d ' ')
  else
    echo "Godot glTF root not found. Falling back to direct glTF extraction."
    while IFS= read -r -d '' file; do
      rel="${file#${CACHE_DIR}/quaternius_fantasy/}"
      mkdir -p "${PLAYER_DIR}/quaternius_extracted/$(dirname "$rel")"
      cp -f "$file" "${PLAYER_DIR}/quaternius_extracted/$rel"
      count=$((count + 1))
    done < <(find "${CACHE_DIR}/quaternius_fantasy" -type f \( -iname '*.glb' -o -iname '*.gltf' -o -iname '*.bin' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0)
  fi

  preferred=""
  for name in "Male_Ranger.gltf" "Male_Peasant.gltf" "Female_Ranger.gltf" "Female_Peasant.gltf"; do
    candidate=$(find "${PLAYER_DIR}/quaternius_extracted" -type f -iname "$name" | head -n 1 || true)
    if [[ -n "$candidate" ]]; then
      preferred="$candidate"
      break
    fi
  done
  if [[ -n "$preferred" ]]; then
    rel_pref="${preferred#${ROOT_DIR}/}"
    echo "Selected Quaternius player: ${rel_pref}"
    printf '%s\n' "$rel_pref" > "${PLAYER_DIR}/SELECTED_PLAYER_PATH.txt"
  else
    echo "No full outfit file found; expected Outfits/Male_Ranger.gltf etc."
  fi

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
  "phase": "5A.7B",
  "sourcePack": "${source_pack}",
  "playerModelsInstalled": ${count},
  "lockedPlayerFolder": "assets/gamebox_locked/player/quaternius_fantasy"
}
JSON

echo "Locked asset install complete. Player model count: ${count}"
