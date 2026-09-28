#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
script="$script_dir/sync-origin.sh"

root="$(mktemp -d)"
origin="$root/origin"
dest="$root/dest"
saved="$root/saved"
mkdir -p "$origin/LooseButtons" "$dest/.github" "$saved"

python3 - "$origin/LooseButtons/Logic.lua" << 'PY'
import sys
open(sys.argv[1], "wb").write(b"A" * 100000)
PY
printf '## Version: 0.1.1\n' > "$origin/LooseButtons/LooseButtons.toc"
printf '<Bindings></Bindings>\n' > "$origin/LooseButtons/Bindings.xml"
git init -q -b main "$origin"
git -C "$origin" config user.email "t@example.com"
git -C "$origin" config user.name "t"
git -C "$origin" add LooseButtons
git -C "$origin" commit -q -m "origin"

printf 'keep-bytes-7f3a\n' > "$dest/.github/keep.sh"
printf 'pkgmeta-bytes-91c2\n' > "$dest/.pkgmeta"
printf 'changelog-bytes-44de\n' > "$dest/CHANGELOG.md"
printf 'old\n' > "$dest/Logic.lua"
printf 'stale\n' > "$dest/Old.lua"
printf '## Version: 0.1.1\n' > "$dest/LooseButtons.toc"
cp "$dest/.github/keep.sh" "$saved/keep.sh"
cp "$dest/.pkgmeta" "$saved/.pkgmeta"
cp "$dest/CHANGELOG.md" "$saved/CHANGELOG.md"
git init -q -b main "$dest"
git -C "$dest" config user.email "t@example.com"
git -C "$dest" config user.name "t"
git -C "$dest" add .github/keep.sh .pkgmeta CHANGELOG.md Logic.lua Old.lua LooseButtons.toc
git -C "$dest" commit -q -m "dest"

set +e
first="$(bash "$script" --origin "$origin" --dest "$dest" --commit 2>&1)"
status=$?
set -e
if [[ $status -ne 0 ]]; then
  printf '%s\n' "$first" >&2
  exit "$status"
fi
cmp "$dest/Logic.lua" "$origin/LooseButtons/Logic.lua"
cmp "$dest/.github/keep.sh" "$saved/keep.sh"
cmp "$dest/.pkgmeta" "$saved/.pkgmeta"
cmp "$dest/CHANGELOG.md" "$saved/CHANGELOG.md"
if [[ -e "$dest/Old.lua" ]]; then
  echo "Old.lua still present" >&2
  exit 1
fi
if [[ -n "$(git -C "$dest" status --porcelain)" ]]; then
  printf 'dirty after commit:\n%s\n' "$(git -C "$dest" status --porcelain)" >&2
  exit 1
fi

origin_sha="$(git -C "$origin" rev-parse HEAD)"
subject="$(git -C "$dest" log -1 --format=%s)"
if [[ "$subject" != "Mirror LooseButtons from Origin ${origin_sha}" ]]; then
  printf 'commit subject %q\n' "$subject" >&2
  exit 1
fi

names="$(git -C "$dest" show --name-only --format= HEAD)"
found_logic=0
while IFS= read -r line; do
  [[ -z $line ]] && continue
  if [[ $line == "Logic.lua" ]]; then
    found_logic=1
  fi
  if [[ $line == "CHANGELOG.md" || $line == ".pkgmeta" || $line == ".github" || $line == .github/* ]]; then
    printf 'commit listed protected path %s\n%s\n' "$line" "$names" >&2
    exit 1
  fi
done <<< "$names"
if [[ $found_logic -ne 1 ]]; then
  printf 'commit missing Logic.lua:\n%s\n' "$names" >&2
  exit 1
fi

before="$(git -C "$dest" rev-list --count HEAD)"
set +e
second="$(bash "$script" --origin "$origin" --dest "$dest" --commit 2>&1)"
status=$?
set -e
if [[ $status -ne 0 ]]; then
  printf '%s\n' "$second" >&2
  exit "$status"
fi
if [[ "$second" != "sync clean" ]]; then
  printf 'expected sync clean, got %q\n' "$second" >&2
  exit 1
fi
after="$(git -C "$dest" rev-list --count HEAD)"
if [[ "$after" != "$before" ]]; then
  printf 'rev-list %s -> %s\n' "$before" "$after" >&2
  exit 1
fi
if [[ -n "$(git -C "$dest" status --porcelain)" ]]; then
  printf 'dirty after second run:\n%s\n' "$(git -C "$dest" status --porcelain)" >&2
  exit 1
fi

col="$(mktemp -d)"
col_origin="$col/origin"
col_dest="$col/dest"
mkdir -p "$col_origin/LooseButtons/.github" "$col_dest/.github"
printf 'evil\n' > "$col_origin/LooseButtons/.github/evil.yml"
printf 'NEW\n' > "$col_origin/LooseButtons/Logic.lua"
printf '## Version: 0.1.1\n' > "$col_origin/LooseButtons/LooseButtons.toc"
printf 'keep-bytes-7f3a\n' > "$col_dest/.github/keep.sh"
printf 'old\n' > "$col_dest/Logic.lua"
cp "$col_dest/.github/keep.sh" "$col/keep.sh"
cp "$col_dest/Logic.lua" "$col/logic.lua"
git init -q -b main "$col_dest"
git -C "$col_dest" config user.email "t@example.com"
git -C "$col_dest" config user.name "t"
set +e
col_out="$(bash "$script" --origin "$col_origin" --dest "$col_dest" 2>&1)"
status=$?
set -e
if [[ $status -eq 0 ]]; then
  printf 'collision exited 0\n%s\n' "$col_out" >&2
  exit 1
fi
if [[ "$col_out" != *".github/evil.yml"* ]]; then
  printf 'collision error did not name the path: %q\n' "$col_out" >&2
  exit 1
fi
cmp "$col_dest/.github/keep.sh" "$col/keep.sh"
cmp "$col_dest/Logic.lua" "$col/logic.lua"

down="$(mktemp -d)"
down_origin="$down/origin"
down_dest="$down/dest"
mkdir -p "$down_origin/LooseButtons" "$down_dest"
printf 'NEW\n' > "$down_origin/LooseButtons/Logic.lua"
printf '## Version: 0.1.0\n' > "$down_origin/LooseButtons/LooseButtons.toc"
printf '<Bindings></Bindings>\n' > "$down_origin/LooseButtons/Bindings.xml"
printf 'old\n' > "$down_dest/Logic.lua"
printf '## Version: 0.1.1\n' > "$down_dest/LooseButtons.toc"
cp "$down_dest/Logic.lua" "$down/logic.lua"
git init -q -b main "$down_dest"
git -C "$down_dest" config user.email "t@example.com"
git -C "$down_dest" config user.name "t"
set +e
down_out="$(bash "$script" --origin "$down_origin" --dest "$down_dest" 2>&1)"
status=$?
set -e
if [[ $status -eq 0 ]]; then
  printf 'downgrade exited 0\n%s\n' "$down_out" >&2
  exit 1
fi
if [[ "$down_out" != *"0.1.0"* || "$down_out" != *"0.1.1"* ]]; then
  printf 'downgrade error missing versions: %q\n' "$down_out" >&2
  exit 1
fi
cmp "$down_dest/Logic.lua" "$down/logic.lua"
if [[ -e "$down_dest/Bindings.xml" ]]; then
  echo "downgrade wrote Bindings.xml" >&2
  exit 1
fi

missing="$(mktemp -d)"
miss_origin="$missing/origin"
miss_dest="$missing/dest"
mkdir -p "$miss_origin/LooseButtons" "$miss_dest"
printf 'NEW\n' > "$miss_origin/LooseButtons/Logic.lua"
printf 'old\n' > "$miss_dest/Logic.lua"
printf '## Version: 0.1.1\n' > "$miss_dest/LooseButtons.toc"
cp "$miss_dest/Logic.lua" "$missing/logic.lua"
git init -q -b main "$miss_dest"
git -C "$miss_dest" config user.email "t@example.com"
git -C "$miss_dest" config user.name "t"
set +e
miss_out="$(bash "$script" --origin "$miss_origin" --dest "$miss_dest" 2>&1)"
status=$?
set -e
if [[ $status -eq 0 ]]; then
  printf 'missing toc exited 0\n%s\n' "$miss_out" >&2
  exit 1
fi
if [[ "$miss_out" != *"LooseButtons.toc is missing"* ]]; then
  printf 'missing toc error: %q\n' "$miss_out" >&2
  exit 1
fi
cmp "$miss_dest/Logic.lua" "$missing/logic.lua"

echo ok
