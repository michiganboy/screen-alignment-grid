#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version="${1:-}"
if [[ -z "$version" ]]; then
  version="$(grep -m1 -oE 'v[0-9]+' README.md || true)"
fi
if [[ -z "$version" ]]; then
  echo "Usage: $0 <version>" >&2
  echo "Example: $0 v30" >&2
  exit 1
fi

app_name="ScreenAlignmentGrid"
dist_dir="$repo_root/dist"
stage_root="$repo_root/.release-stage"
portable_stage="$stage_root/${app_name}-${version}-Portable/ScreenAlignmentGrid"
installer_stage="$stage_root/${app_name}-${version}-Installer/ScreenAlignmentGrid"

rm -rf "$stage_root"
mkdir -p "$portable_stage/assets" "$installer_stage/assets" "$dist_dir"
rm -f "$dist_dir/${app_name}-${version}-Portable.zip" \
      "$dist_dir/${app_name}-${version}-Installer.zip" \
      "$dist_dir/SHA256SUMS.txt"

copy_common() {
  local target="$1"
  cp ScreenAlignmentGrid.ps1 "$target/"
  cp README.md "$target/"
  cp LICENSE "$target/"
  cp assets/ScreenAlignmentGrid.ico "$target/assets/"
  cp assets/ScreenAlignmentGrid.png "$target/assets/"
  cp assets/screen-alignment-grid-everquest-example.jpg "$target/assets/"
}

copy_common "$portable_stage"
cp 'Run Screen Alignment Grid.cmd' "$portable_stage/Run Portable.cmd"

copy_common "$installer_stage"
cp 'Run Screen Alignment Grid.cmd' "$installer_stage/"
cp 'Install Screen Alignment Grid.cmd' "$installer_stage/"
cp 'Install Screen Alignment Grid.ps1' "$installer_stage/"
cp 'Launch Screen Alignment Grid.vbs' "$installer_stage/"
cp 'Create Desktop Shortcut.cmd' "$installer_stage/"
cp 'Uninstall Screen Alignment Grid.cmd' "$installer_stage/"

(
  cd "$stage_root"
  zip -qr "$dist_dir/${app_name}-${version}-Portable.zip" "${app_name}-${version}-Portable"
  zip -qr "$dist_dir/${app_name}-${version}-Installer.zip" "${app_name}-${version}-Installer"
)

(
  cd "$dist_dir"
  sha256sum "${app_name}-${version}-Portable.zip" "${app_name}-${version}-Installer.zip" > SHA256SUMS.txt
)

rm -rf "$stage_root"

echo "Built release artifacts:"
echo "  $dist_dir/${app_name}-${version}-Portable.zip"
echo "  $dist_dir/${app_name}-${version}-Installer.zip"
echo "  $dist_dir/SHA256SUMS.txt"
