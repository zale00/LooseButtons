#!/usr/bin/env bash
# Fixture runs for forever-monitor.sh. No network, no push, no CurseForge token.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
script="$script_dir/forever-monitor.sh"
if [[ -f $script_dir/forever-monitor-entry.sh && -f $script_dir/forever-monitor-rest.sh ]]; then
  script="$script_dir/forever-monitor-entry.sh"
fi

fail() {
  printf 'fail %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  [[ "$1" == "$2" ]] || fail "$3: expected [$2] got [$1]"
}

base_wiki() {
  cat <<'EOF'
	|standard|midnight|wow|_retail_={{mn-inline|size={{{size|36}}}}}\!\!Midnight\!\!12.1.0\!\!120100\!\!69814\!\!2026-09-10
	|camelot-beta|forever-beta|wow_classic_beta|_classic_beta_={{forever-inline|size={{{size|}}}}}\!\!Forever\!\!1.60.1\!\!16001\!\!69893\!\!2026-09-16
	|vanilla|wow_classic_era|_classic_era_={{wow-inline|classic=|size={{{size|}}}}}\!\!World of Warcraft Classic\!\!1.15.9\!\!11509\!\!69722\!\!2026-09-04
EOF
}

new_repo() {
  local root=$1 bare src
  bare="$root/origin.git"
  src="$root/src"
  git init --bare -q "$bare"
  git init -q -b main "$src"
  git -C "$src" config user.email "t@example.com"
  git -C "$src" config user.name "t"
  mkdir -p "$src/.github"
  cat >"$src/LooseButtons.toc" <<'EOF'
## Interface: 16001
## Title: Loose Buttons
## Version: 0.1.3
## X-Flavor: Mainline

# 16001 is Forever beta 1.60.1. The client marks 120100 incompatible. The upload sends the Forever game-version row and does not let the packager upload.

Logic.lua
EOF
  printf 'return {}\n' >"$src/Logic.lua"
  cat >"$src/CHANGELOG.md" <<'EOF'
# LooseButtons

## 0.1.3

- The TOC interface is 16001, Forever beta 1.60.1.
EOF
  printf 'forever_name=1.60.1\nforever_type=88568\nretail_name=12.1.0\n' >"$src/.github/upload-curseforge.sh"
  git -C "$src" add LooseButtons.toc Logic.lua CHANGELOG.md .github/upload-curseforge.sh
  git -C "$src" commit -q -m init
  git -C "$src" remote add origin "$bare"
  git -C "$src" push -q -u origin main
  git -C "$src" tag cf-0.1.3
  git -C "$src" push -q origin refs/tags/cf-0.1.3
  printf '%s\n' "$src"
}

decision_line() {
  printf '%s\n' "$1" | awk '/^decision / { line=$0 } END { print line }'
}

run_monitor() {
  local src=$1 wiki=$2 cf=$3 gethe=$4 mode=$5
  env -u GITHUB_ACTIONS -u CF_API_KEY \
    FOREVER_REPO="$src" \
    FOREVER_WIKI_FILE="$wiki" \
    FOREVER_CF_FILE="$cf" \
    FOREVER_GETHE_TEXT="$gethe" \
    bash "$script" "$mode"
}

toc_version() {
  sed -n 's/^## Version:[[:space:]]*//p' "$1/LooseButtons.toc" | head -n 1
}

toc_interface() {
  sed -n 's/^## Interface:[[:space:]]*//p' "$1/LooseButtons.toc" | head -n 1
}

root=$(mktemp -d)
src=$(new_repo "$root")
wiki="$root/wiki.txt"
cf="$root/cf.json"
base_wiki >"$wiki"
printf '%s\n' '[{"id":11101,"gameVersionTypeID":517,"name":"12.1.0"},{"id":17053,"gameVersionTypeID":88568,"name":"1.60.1"}]' >"$cf"

out=$(run_monitor "$src" "$wiki" "$cf" '1.60.1.70170' --check)
assert_eq "$(decision_line "$out")" "decision noop" "current 16001"
assert_eq "$(toc_version "$src")" "0.1.3" "noop leaves version"

# Planted Forever interface 16100. CurseForge already has that game version.
sed -i 's/1\.60\.1\\!\\!16001/1.61.0\\!\\!16100/' "$wiki"
printf '%s\n' '[{"id":11101,"gameVersionTypeID":517,"name":"12.1.0"},{"id":17053,"gameVersionTypeID":88568,"name":"1.60.1"},{"id":17100,"gameVersionTypeID":88568,"name":"1.61.0"}]' >"$cf"
out=$(run_monitor "$src" "$wiki" "$cf" '1.61.0.71000' --apply)
assert_eq "$(decision_line "$out")" "decision bump 16100 0.1.4 1.61.0 upload" "planted bump"
assert_eq "$(toc_interface "$src")" "16100" "bumped interface"
assert_eq "$(toc_version "$src")" "0.1.4" "bumped version"
assert_eq "$(sed -n 's/^## \([^[:space:]]*\).*/\1/p' "$src/CHANGELOG.md" | head -n 1)" "0.1.4" "changelog heading"
grep -q 'The TOC interface is 16100, Forever beta 1.61.0.' "$src/CHANGELOG.md" || fail "changelog body"
grep -q '^forever_name=1.61.0$' "$src/.github/upload-curseforge.sh" || fail "upload target"
grep -q '^## 0.1.3$' "$src/CHANGELOG.md" || fail "old changelog heading"

out=$(run_monitor "$src" "$wiki" "$cf" '1.61.0.71000' --apply)
assert_eq "$(decision_line "$out")" "decision retry-upload 1.61.0" "second run retries upload"
assert_eq "$(toc_version "$src")" "0.1.4" "second run does not bump again"

git -C "$src" tag cf-0.1.4
git -C "$src" push -q origin refs/tags/cf-0.1.4
out=$(run_monitor "$src" "$wiki" "$cf" '1.61.0.71000' --check)
assert_eq "$(decision_line "$out")" "decision noop" "same interface after the tag"

# Interface moves, CurseForge does not have the new name yet.
root2=$(mktemp -d)
src2=$(new_repo "$root2")
wiki2="$root2/wiki.txt"
cf2="$root2/cf.json"
base_wiki >"$wiki2"
sed -i 's/1\.60\.1\\!\\!16001/1.61.0\\!\\!16100/' "$wiki2"
printf '%s\n' '[{"id":11101,"gameVersionTypeID":517,"name":"12.1.0"},{"id":17053,"gameVersionTypeID":88568,"name":"1.60.1"}]' >"$cf2"
out=$(run_monitor "$src2" "$wiki2" "$cf2" '1.61.0.71000' --apply)
assert_eq "$(decision_line "$out")" "decision bump 16100 0.1.4 1.61.0 hold" "hold without cf row"
assert_eq "$(toc_version "$src2")" "0.1.4" "hold still bumps toc"
grep -q '^forever_name=1.60.1$' "$src2/.github/upload-curseforge.sh" || fail "hold keeps target"
out=$(run_monitor "$src2" "$wiki2" "$cf2" '1.61.0.71000' --apply)
assert_eq "$(decision_line "$out")" "decision noop" "hold does not upload the old row"
assert_eq "$(toc_version "$src2")" "0.1.4" "hold rerun stays"
printf '%s\n' '[{"id":11101,"gameVersionTypeID":517,"name":"12.1.0"},{"id":17053,"gameVersionTypeID":88568,"name":"1.60.1"},{"id":17100,"gameVersionTypeID":88568,"name":"1.61.0"}]' >"$cf2"
out=$(run_monitor "$src2" "$wiki2" "$cf2" '1.61.0.71000' --apply)
assert_eq "$(decision_line "$out")" "decision retarget 1.61.0 upload" "cf row arrives later"
grep -q '^forever_name=1.61.0$' "$src2/.github/upload-curseforge.sh" || fail "later retarget"
assert_eq "$(toc_version "$src2")" "0.1.4" "later retarget keeps version"

# Retail Midnight on the camelot row.
root3=$(mktemp -d)
src3=$(new_repo "$root3")
wiki3="$root3/wiki.txt"
base_wiki >"$wiki3"
sed -i 's/Forever\\!\\!1.60.1\\!\\!16001/Midnight\\!\\!12.1.0\\!\\!120100/' "$wiki3"
set +e
out=$(run_monitor "$src3" "$wiki3" "$cf" '12.1.0.69814' --apply 2>&1)
status=$?
set -e
[[ $status -ne 0 ]] || fail "retail should refuse"
assert_eq "$(decision_line "$out")" "decision refuse retail" "retail signal"
assert_eq "$(toc_interface "$src3")" "16001" "retail writes nothing"

# Wiki and Gethe disagree.
root4=$(mktemp -d)
src4=$(new_repo "$root4")
wiki4="$root4/wiki.txt"
base_wiki >"$wiki4"
sed -i 's/1\.60\.1\\!\\!16001/1.61.0\\!\\!16100/' "$wiki4"
set +e
out=$(run_monitor "$src4" "$wiki4" "$cf" '1.60.1.70170' --apply 2>&1)
status=$?
set -e
[[ $status -ne 0 ]] || fail "disagree should refuse"
assert_eq "$(decision_line "$out")" "decision refuse disagree" "disagree"
assert_eq "$(toc_version "$src4")" "0.1.3" "disagree writes nothing"

# Wiki interface does not match the game-version formula.
root5=$(mktemp -d)
src5=$(new_repo "$root5")
wiki5="$root5/wiki.txt"
base_wiki >"$wiki5"
sed -i 's/16001/16002/' "$wiki5"
set +e
out=$(run_monitor "$src5" "$wiki5" "$cf" '1.60.1.70170' --apply 2>&1)
status=$?
set -e
[[ $status -ne 0 ]] || fail "formula should refuse"
assert_eq "$(decision_line "$out")" "decision refuse wiki-interface" "formula"
assert_eq "$(toc_interface "$src5")" "16001" "formula writes nothing"

# The targeted Forever name disappeared and one other Forever row remains.
root6=$(mktemp -d)
src6=$(new_repo "$root6")
wiki6="$root6/wiki.txt"
cf6="$root6/cf.json"
base_wiki >"$wiki6"
printf '%s\n' '[{"id":11101,"gameVersionTypeID":517,"name":"12.1.0"},{"id":17099,"gameVersionTypeID":88568,"name":"1.60.2"}]' >"$cf6"
out=$(run_monitor "$src6" "$wiki6" "$cf6" '1.60.1.70170' --apply)
assert_eq "$(decision_line "$out")" "decision retarget 1.60.2" "single row rename"
assert_eq "$(toc_version "$src6")" "0.1.3" "rename does not bump"
grep -q '^forever_name=1.60.2$' "$src6/.github/upload-curseforge.sh" || fail "renamed target"
out=$(run_monitor "$src6" "$wiki6" "$cf6" '1.60.1.70170' --check)
assert_eq "$(decision_line "$out")" "decision noop" "rename rerun"

# Two Forever rows and neither is the one we ship. Do not guess.
root7=$(mktemp -d)
src7=$(new_repo "$root7")
wiki7="$root7/wiki.txt"
cf7="$root7/cf.json"
base_wiki >"$wiki7"
printf '%s\n' '[{"id":1,"gameVersionTypeID":88568,"name":"1.70.0"},{"id":2,"gameVersionTypeID":88568,"name":"1.80.0"}]' >"$cf7"
set +e
out=$(run_monitor "$src7" "$wiki7" "$cf7" '1.60.1.70170' --apply 2>&1)
status=$?
set -e
[[ $status -ne 0 ]] || fail "ambiguous cf should refuse"
assert_eq "$(decision_line "$out")" "decision refuse cf-target" "ambiguous cf"
grep -q '^forever_name=1.60.1$' "$src7/.github/upload-curseforge.sh" || fail "ambiguous keeps target"

# A live camelot row wins over a stale camelot-beta row.
root8=$(mktemp -d)
src8=$(new_repo "$root8")
wiki8="$root8/wiki.txt"
cf8="$root8/cf.json"
{
  base_wiki
  printf '\t|camelot|forever|wow_classic_beta|_classic_beta_={{forever-inline|size={{{size|}}}}}\\!\\!Forever\\!\\!1.61.0\\!\\!16100\\!\\!71000\\!\\!2026-10-02\n'
} >"$wiki8"
printf '%s\n' '[{"id":11101,"gameVersionTypeID":517,"name":"12.1.0"},{"id":17100,"gameVersionTypeID":88568,"name":"1.61.0"}]' >"$cf8"
out=$(run_monitor "$src8" "$wiki8" "$cf8" '1.61.0.71000' --apply)
assert_eq "$(decision_line "$out")" "decision bump 16100 0.1.4 1.61.0 upload" "live camelot row"
assert_eq "$(toc_interface "$src8")" "16100" "live row interface"

root9=$(mktemp -d)
src9=$(new_repo "$root9")
wiki9="$root9/wiki.txt"
base_wiki >"$wiki9"
set +e
out=$(env -u CF_API_KEY -u FOREVER_CF_FILE \
  GITHUB_ACTIONS=true \
  FOREVER_REPO="$src9" \
  FOREVER_WIKI_FILE="$wiki9" \
  FOREVER_GETHE_TEXT='1.60.1.70170' \
  bash "$script" 2>&1)
status=$?
set -e
assert_eq "$status" "0" "actions noop without cf exits 0"
assert_eq "$(decision_line "$out")" "decision noop" "actions noop without cf"
grep -F 'notice cf unchecked' <<<"$out" >/dev/null || fail "actions noop notice"
grep -F '::warning title=Forever monitor::cf unchecked, decision noop' <<<"$out" >/dev/null || fail "actions noop annotation"
assert_eq "$(toc_version "$src9")" "0.1.3" "actions noop leaves version"

root10=$(mktemp -d)
src10=$(new_repo "$root10")
wiki10="$root10/wiki.txt"
base_wiki >"$wiki10"
sed -i 's/1\.60\.1\\!\\!16001/1.61.0\\!\\!16100/' "$wiki10"
set +e
out=$(env -u CF_API_KEY -u FOREVER_CF_FILE \
  GITHUB_ACTIONS=true \
  FOREVER_REPO="$src10" \
  FOREVER_WIKI_FILE="$wiki10" \
  FOREVER_GETHE_TEXT='1.61.0.71000' \
  bash "$script" 2>&1)
status=$?
set -e
assert_eq "$status" "1" "actions bump without cf exits 1"
assert_eq "$(decision_line "$out")" "decision refuse no-cf" "actions bump without cf"
assert_eq "$(toc_version "$src10")" "0.1.3" "actions bump without cf writes nothing"

# Pause file.
touch "$src/.github/FOREVER_MONITOR_PAUSE"
out=$(run_monitor "$src" "$wiki" "$cf" '1.61.0.71000' --apply)
assert_eq "$(decision_line "$out")" "decision paused" "pause file"
assert_eq "$(toc_interface "$src")" "16100" "pause writes nothing"

printf 'forever-monitor-test ok\n'
