#!/usr/bin/env bash
# Sparse checkout of Gethe/wow-ui-source branch forever, for grep.
# Measured 2026-10-01 at 966519cf (1.60.1.70124): about 2s, 12MB tree, 2.6MB .git.
# Does not change the addon TOC. Blizzard's dump stays in the cache, not in git.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
dest=${FOREVER_UI_SOURCE:-$root/.cache/wow-ui-source}
repo=https://github.com/Gethe/wow-ui-source.git
branch=forever

git_c() {
  git -c core.longpaths=true "$@"
}

if [[ ! -d $dest/.git ]]; then
  git_c clone --depth 1 --filter=blob:none --sparse --branch "$branch" "$repo" "$dest"
fi

git_c -C "$dest" sparse-checkout set --skip-checks \
  version.txt \
  Interface/AddOns/Blizzard_APIDocumentation \
  Interface/AddOns/Blizzard_APIDocumentationGenerated \
  Interface/AddOns/Blizzard_EditMode \
  Interface/AddOns/Blizzard_PlayerSpells \
  Interface/AddOns/Blizzard_DeprecatedSpellBook \
  Interface/AddOns/Blizzard_ActionBar \
  Interface/AddOns/Blizzard_QuickKeybind \
  Interface/AddOns/Blizzard_FrameXML \
  Interface/AddOns/Blizzard_SharedXML \
  Interface/AddOns/Blizzard_RestrictedAddOnEnvironment \
  Interface/AddOns/Blizzard_GameMenu

git_c -C "$dest" fetch --depth 1 origin "$branch"
git_c -C "$dest" reset --hard "origin/$branch"

printf '%s\n' "$dest"
git_c -C "$dest" log -1 --format='%H %s'
cat "$dest/version.txt"
