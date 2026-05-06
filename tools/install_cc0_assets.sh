#!/usr/bin/env bash
set -euo pipefail

# GameBox 3D Runner - deterministic locked asset installer.
# Phase 5A.7D: LFS ZIP verification + no-space active Quaternius path.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${ROOT_DIR}/.asset_cache"
PACK_DIR="${ROOT_DIR}/assets/imported_packs"
LOCKED_ROOT="${ROOT_DIR}/assets/gamebox_locked"
PLAYER_DIR="${LOCKED_ROOT}/player/quaternius_fantasy"
ACTIVE_DIR="${PLAYER_DIR}/active"
ROAD_DIR="${LOCKED_ROOT}/road"
OBSTACLE_DIR="${LOCKED_ROOT}/obstacles"
ENV_DIR="${LOCKED_ROOT}/environment"
UI_DIR="${LOCKED_ROOT}/ui"
MANIFEST="${LOCKED_ROOT}/asset_status.json"

mkdir -p "${CACHE_DIR}" "${PACK_DIR}" "${PLAYER_DIR}" "${ACTIVE_DIR}" "${ROAD_DIR}" "${OBSTACLE_DIR}" "${ENV_DIR}" "${UI_DIR}"
for d in "${PACK_DIR}" "${PLAYER_DIR}" "${ACTIVE_DIR}" "${ROAD_DIR}" "${OBSTACLE_DIR}" "${ENV_DIR}" "${UI_DIR}"; do
  touch "${d}/.gitkeep"
done

cat > "${LOCKED_ROOT}/README_LOCKED_ASSETS.md" <<'TXT'
# GameBox Locked Assets

Place Quaternius Modular Character Outfits Fantasy ZIP here:
`assets/imported_packs/quaternius_fantasy.zip`

GitHub Actions extracts it into:
`assets/gamebox_locked/player/quaternius_fantasy/active/`

The game loads the full outfit path written into SELECTED_PLAYER_PATH.txt.
TXT

count=0
source_pack="none"
selected_rel=""
zip_path="${PACK_DIR}/quaternius_fantasy.zip"

if [[ -f "${zip_path}" ]]; then
  echo "Found Quaternius fantasy character pack: ${zip_path}"
  echo "ZIP file info:"
  ls -lh "${zip_path}"
  file "${zip_path}" || true

  # Detect LFS pointer file early. Real ZIP starts with PK bytes, LFS pointer starts with text.
  if head -c 64 "${zip_path}" | grep -q "version https://git-lfs.github.com/spec"; then
    echo "ERROR: quaternius_fantasy.zip is still a Git LFS pointer, not the real ZIP."
    echo "Fix: checkout with lfs: true and run git lfs pull before this step."
    exit 42
  fi

  rm -rf "${CACHE_DIR}/quaternius_fantasy" "${ACTIVE_DIR}"
  mkdir -p "${CACHE_DIR}/quaternius_fantasy" "${ACTIVE_DIR}"
  unzip -q -o "${zip_path}" -d "${CACHE_DIR}/quaternius_fantasy"

  # Find the Quaternius Godot glTF export root. This folder contains Outfits/ and Modular Parts/.
  gltf_root=""
  while IFS= read -r -d '' d; do
    if [[ "${d}" == *"Exports/glTF (Godot-Unreal)"* ]]; then
      gltf_root="${d}"
      break
    fi
  done < <(find "${CACHE_DIR}/quaternius_fantasy" -type d -print0)

  if [[ -z "${gltf_root}" || ! -d "${gltf_root}" ]]; then
    echo "ERROR: Could not find Exports/glTF (Godot-Unreal) inside Quaternius ZIP."
    echo "Some ZIP contents:"
    find "${CACHE_DIR}/quaternius_fantasy" -maxdepth 4 -type f | head -80
    exit 43
  fi

  echo "Using Quaternius Godot glTF root: ${gltf_root}"
  # Copy the whole glTF root to a short no-space runtime path. This preserves relative dependencies.
  cp -R "${gltf_root}/." "${ACTIVE_DIR}/"

  preferred=""
  for name in "Male_Ranger.gltf" "Male_Peasant.gltf" "Female_Ranger.gltf" "Female_Peasant.gltf"; do
    candidate=$(find "${ACTIVE_DIR}" -type f -path "*/Outfits/${name}" | head -n 1 || true)
    if [[ -n "${candidate}" ]]; then
      preferred="${candidate}"
      break
    fi
  done

  if [[ -z "${preferred}" ]]; then
    echo "ERROR: No full outfit file found in active folder. Expected Outfits/Male_Ranger.gltf etc."
    find "${ACTIVE_DIR}" -type f | grep -Ei '/Outfits/.*\.gltf$' | head -80 || true
    exit 44
  fi

  selected_rel="${preferred#${ROOT_DIR}/}"
  echo "Selected Quaternius player: ${selected_rel}"
  printf '%s\n' "${selected_rel}" > "${PLAYER_DIR}/SELECTED_PLAYER_PATH.txt"
  printf '%s\n' "${selected_rel}" > "${ACTIVE_DIR}/SELECTED_PLAYER_PATH.txt"

  # Create a wrapper scene that directly instances the selected glTF.
  # This forces Godot to import/include the character and avoids runtime directory scans on Android.
  mkdir -p "${ROOT_DIR}/scenes"
  cat > "${ROOT_DIR}/scenes/LockedCharacter.tscn" <<TSCN
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://${selected_rel}" id="1_gbx_player"]

[node name="LockedCharacter" instance=ExtResource("1_gbx_player")]
TSCN
  echo "Generated wrapper scene: scenes/LockedCharacter.tscn -> res://${selected_rel}"

  count=$(find "${ACTIVE_DIR}" -type f \( -iname '*.glb' -o -iname '*.gltf' \) | wc -l | tr -d ' ')
  source_pack="quaternius_fantasy_zip"

  echo "Active player folder summary:"
  find "${ACTIVE_DIR}" -maxdepth 3 -type f | grep -Ei '(SELECTED|Outfits/.*\.gltf|\.bin$|\.png$|\.jpg$)' | head -120 || true
else
  echo "No assets/imported_packs/quaternius_fantasy.zip found. Build will use fallback player."
  cat > "${PACK_DIR}/README_DROP_QUATERNIUS_ZIP_HERE.md" <<'TXT'
Drop Quaternius character pack here and rename it exactly:
quaternius_fantasy.zip
TXT
fi

cat > "${MANIFEST}" <<JSON
{
  "phase": "5A.7E",
  "sourcePack": "${source_pack}",
  "playerModelsInstalled": ${count},
  "selectedPlayer": "${selected_rel}",
  "lockedPlayerFolder": "assets/gamebox_locked/player/quaternius_fantasy/active"
}
JSON

cat "${MANIFEST}"
echo "Locked asset install complete. Player model count: ${count}"
