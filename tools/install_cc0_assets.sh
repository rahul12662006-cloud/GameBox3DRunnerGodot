#!/usr/bin/env bash
set -euo pipefail

# GameBox 3D Runner - optional CC0 asset auto-installer.
# This runs in GitHub Actions before Godot exports the APK.
# If the remote source is unavailable, the game still builds and falls back to built-in procedural models.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/.asset_cache"
VENDOR_DIR="${ROOT_DIR}/assets/vendor/kenney_3d_road_tiles"
MANIFEST="${ROOT_DIR}/assets/gamebox/asset_manifest.json"

mkdir -p "${WORK_DIR}" "${VENDOR_DIR}" "${ROOT_DIR}/assets/gamebox"

KENNEY_ROAD_TILES_URL="${KENNEY_ROAD_TILES_URL:-https://www.kenney.nl/media/pages/assets/3d-road-tiles/cc89145087-1677581262/kenney_3d-road-tiles.zip}"
ZIP_PATH="${WORK_DIR}/kenney_3d_road_tiles.zip"
UNPACK_DIR="${WORK_DIR}/kenney_3d_road_tiles"

cat > "${ROOT_DIR}/assets/README_ASSETS.md" <<'TXT'
# GameBox Asset Pipeline

This project can auto-install CC0 Kenney 3D Road Tiles during GitHub Actions builds.
If the download fails, the game falls back to its built-in procedural models, so APK builds should not break.

Optional manual assets can be placed under:

- assets/vendor/kenney_3d_road_tiles/
- assets/imported/

Godot will scan these folders and use compatible .glb, .gltf, .obj, .tscn, or .scn files when possible.
TXT

printf '{\n  "installed": false,\n  "source": "kenney_3d_road_tiles",\n  "modelCount": 0\n}\n' > "${MANIFEST}"

if [[ -n "${GAMEBOX_SKIP_ASSET_DOWNLOAD:-}" ]]; then
  echo "GAMEBOX_SKIP_ASSET_DOWNLOAD is set; skipping CC0 asset download."
  exit 0
fi

echo "Downloading CC0 Kenney 3D Road Tiles..."
if ! curl -L --fail --retry 3 --retry-delay 2 -o "${ZIP_PATH}" "${KENNEY_ROAD_TILES_URL}"; then
  echo "::warning::Could not download CC0 assets. Continuing with procedural fallback visuals."
  exit 0
fi

rm -rf "${UNPACK_DIR}"
mkdir -p "${UNPACK_DIR}"
unzip -q -o "${ZIP_PATH}" -d "${UNPACK_DIR}"

# Copy only Godot-friendly self-contained model files by default.
# We intentionally skip .obj here because many OBJ files reference separate .mtl files;
# missing MTL files caused noisy Godot import errors and the game fell back to procedural blocks.
count=0
while IFS= read -r -d '' file; do
  base="$(basename "$file")"
  lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lower" == *"road"* || "$lower" == *"barrier"* || "$lower" == *"cone"* || "$lower" == *"lamp"* || "$lower" == *"sign"* || "$lower" == *"street"* || "$lower" == *"light"* ]]; then
    safe_name="$(printf '%s' "$base" | tr ' ' '_' | tr -cd '[:alnum:]_.-')"
    cp -f "$file" "${VENDOR_DIR}/${safe_name}"
    count=$((count + 1))
  fi
  if [[ "$count" -ge 40 ]]; then
    break
  fi
done < <(find "${UNPACK_DIR}" -type f \( -iname '*.glb' -o -iname '*.gltf' \) -print0)

printf '{\n  "installed": true,\n  "source": "kenney_3d_road_tiles",\n  "modelCount": %d\n}\n' "$count" > "${MANIFEST}"

echo "Installed ${count} CC0 model files into assets/vendor/kenney_3d_road_tiles"
