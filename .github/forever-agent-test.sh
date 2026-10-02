#!/usr/bin/env bash
# Fixture runs for forever-agent.sh. No network, no Cursor token, no CurseForge token.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
script="$script_dir/forever-agent.sh"

fail() {
  printf 'fail %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  [[ "$1" == "$2" ]] || fail "$3: expected [$2] got [$1]"
}

base_wiki() {
  cat <<'EOF'
	|standard|midnight|wow|_retail_={{mn-inline|size={{{{size|36}}}}}\!\!Midnight\!\!12.1.0\!\!120100\!\!69814\!\!2026-09-10
	|camelot-beta|forever-beta|wow_classic_beta|_classic_beta_={{forever-inline|size={{{{size|}}}}}\!\!Forever\!\!1.60.1\!\!16001\!\!69893\!\!2026-09-16
EOF
}

base_cf() {
  printf '%s\n' '[{"id":11101,"gameVersionTypeID":517,"name":"12.1.0"},{"id":17053,"gameVersionTypeID":88568,"name":"1.60.1"}]'
}

base_state() {
  cat <<'EOF'
gethe=9a789c074b8e73c5d604ef2d6af3bb5b3aefb348
interface=16001
game=1.60.1
cf=1.60.1
EOF
}

new_tree() {
  local root=$1
  mkdir -p "$root/.github"
  printf '%s\n' '## Interface: 16001' >"$root/LooseButtons.toc"
  printf '%s\n' '## Version: 0.1.3' >>"$root/LooseButtons.toc"
  base_state >"$root/.github/forever-agent-state"
  printf '%s\n' "$root"
}

decision_line() {
  printf '%s\n' "$1" | awk '/^decision / { line=$0 } END { print line }'
}

run_agent() {
  local src=$1 wiki=$2 cf=$3 sha=$4
  env -u GITHUB_ACTIONS -u CF_API_KEY -u CURSOR_API_KEY -u FOREVER_AGENT_SINK \
    FOREVER_REPO="$src" \
    FOREVER_WIKI_FILE="$wiki" \
    FOREVER_CF_FILE="$cf" \
    FOREVER_GETHE_TEXT='1.60.1.70170' \
    FOREVER_GETHE_SHA="$sha" \
    bash "$script"
}

seen=9a789c074b8e73c5d604ef2d6af3bb5b3aefb348
other=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

root=$(mktemp -d)
src=$(new_tree "$root/tree")
wiki="$root/wiki"
cf="$root/cf"
base_wiki >"$wiki"
base_cf >"$cf"

out=$(run_agent "$src" "$wiki" "$cf" "$seen")
assert_eq "$(decision_line "$out")" "decision noop" "same signal"

out=$(run_agent "$src" "$wiki" "$cf" "$other")
assert_eq "$(decision_line "$out")" "decision blocked" "kick without key"
cmp -s <(base_state) "$src/.github/forever-agent-state" || fail "blocked rewrote state"

set +e
out=$(env -u CF_API_KEY -u CURSOR_API_KEY -u FOREVER_AGENT_SINK \
  GITHUB_ACTIONS=true \
  FOREVER_REPO="$src" \
  FOREVER_WIKI_FILE="$wiki" \
  FOREVER_CF_FILE="$cf" \
  FOREVER_GETHE_TEXT='1.60.1.70170' \
  FOREVER_GETHE_SHA="$other" \
  bash "$script" 2>&1)
status=$?
set -e
assert_eq "$status" "0" "actions blocked exits 0"
assert_eq "$(decision_line "$out")" "decision blocked" "actions blocked line"
grep -F '::warning title=Forever agent::decision blocked' <<<"$out" >/dev/null || fail "actions blocked annotation"
cmp -s <(base_state) "$src/.github/forever-agent-state" || fail "actions blocked rewrote state"

sink="$root/body.json"
out=$(env -u GITHUB_ACTIONS -u CF_API_KEY \
  FOREVER_REPO="$src" \
  FOREVER_WIKI_FILE="$wiki" \
  FOREVER_CF_FILE="$cf" \
  FOREVER_GETHE_TEXT='1.60.1.70170' \
  FOREVER_GETHE_SHA="$other" \
  CURSOR_API_KEY='test-key' \
  FOREVER_AGENT_SINK="$sink" \
  bash "$script")
assert_eq "$(decision_line "$out")" "decision kick gethe" "gethe kick"
python3 - "$sink" "$other" <<'PY' || fail "body"
import json, sys
body = json.load(open(sys.argv[1]))
assert body["model"]["id"] == "grok-4.7-xhigh-fast", body["model"]
assert body["repos"] == [{"url": "https://github.com/zale00/LooseButtons", "startingRef": "main"}]
assert body["workOnCurrentBranch"] is False
assert body["autoCreatePR"] is True
assert body["agentId"].startswith("bc-")
text = body["prompt"]["text"]
assert "Forever only" in text
assert "120100" in text
assert sys.argv[2] in text
assert "CurseForge upload API" in text
PY
id1=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["agentId"])' "$sink")
cp "$src/.github/forever-agent-state" "$root/after-kick"
base_state >"$src/.github/forever-agent-state"
sink2="$root/body2.json"
env -u GITHUB_ACTIONS -u CF_API_KEY \
  FOREVER_REPO="$src" \
  FOREVER_WIKI_FILE="$wiki" \
  FOREVER_CF_FILE="$cf" \
  FOREVER_GETHE_TEXT='1.60.1.70170' \
  FOREVER_GETHE_SHA="$other" \
  CURSOR_API_KEY='test-key' \
  FOREVER_AGENT_SINK="$sink2" \
  bash "$script" >/dev/null
id2=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["agentId"])' "$sink2")
assert_eq "$id1" "$id2" "agent id stable"
cp "$root/after-kick" "$src/.github/forever-agent-state"

rm -f "$sink"
out=$(env -u GITHUB_ACTIONS -u CF_API_KEY \
  FOREVER_REPO="$src" \
  FOREVER_WIKI_FILE="$wiki" \
  FOREVER_CF_FILE="$cf" \
  FOREVER_GETHE_TEXT='1.60.1.70170' \
  FOREVER_GETHE_SHA="$other" \
  CURSOR_API_KEY='test-key' \
  FOREVER_AGENT_SINK="$sink" \
  bash "$script")
assert_eq "$(decision_line "$out")" "decision noop" "second run"
[[ ! -f $sink ]] || fail "noop posted"

printf '%s\n' '[{"id":11101,"gameVersionTypeID":517,"name":"12.1.0"},{"id":17100,"gameVersionTypeID":88568,"name":"1.61.0"}]' >"$root/renamed-cf"
out=$(env -u GITHUB_ACTIONS -u CF_API_KEY -u CURSOR_API_KEY -u FOREVER_AGENT_SINK \
  FOREVER_REPO="$src" \
  FOREVER_WIKI_FILE="$wiki" \
  FOREVER_CF_FILE="$root/renamed-cf" \
  FOREVER_GETHE_TEXT='1.60.1.70170' \
  FOREVER_GETHE_SHA="$other" \
  bash "$script")
assert_eq "$(decision_line "$out")" "decision blocked" "cf rename still needs a key"
cmp -s "$root/after-kick" "$src/.github/forever-agent-state" || fail "blocked cf rewrote state"
base_state >"$src/.github/forever-agent-state"
sink="$root/cf-body.json"
out=$(env -u GITHUB_ACTIONS -u CF_API_KEY \
  FOREVER_REPO="$src" \
  FOREVER_WIKI_FILE="$wiki" \
  FOREVER_CF_FILE="$root/renamed-cf" \
  FOREVER_GETHE_TEXT='1.60.1.70170' \
  FOREVER_GETHE_SHA="$seen" \
  CURSOR_API_KEY='test-key' \
  FOREVER_AGENT_SINK="$sink" \
  bash "$script")
assert_eq "$(decision_line "$out")" "decision kick cf" "cf rename"

base_state >"$src/.github/forever-agent-state"
cat >"$wiki" <<'EOF'
	|standard|midnight|wow|_retail_={{mn-inline|size={{{{size|36}}}}}\!\!Midnight\!\!12.1.0\!\!120100\!\!69814\!\!2026-09-10
	|camelot|forever|wow|_retail_={{mn-inline|size={{{{size|36}}}}}\!\!Midnight\!\!12.1.0\!\!120100\!\!69814\!\!2026-09-10
EOF
set +e
out=$(run_agent "$src" "$wiki" "$cf" "$seen")
status=$?
set -e
assert_eq "$status" "1" "retail exit"
assert_eq "$(decision_line "$out")" "decision refuse retail" "retail refuse"
base_wiki >"$wiki"
base_cf >"$cf"

touch "$src/.github/FOREVER_MONITOR_PAUSE"
out=$(run_agent "$src" "$wiki" "$cf" "$other")
assert_eq "$(decision_line "$out")" "decision paused" "pause file"
rm -f "$src/.github/FOREVER_MONITOR_PAUSE"
out=$(env FOREVER_MONITOR=off FOREVER_REPO="$src" FOREVER_WIKI_FILE="$wiki" \
  FOREVER_CF_FILE="$cf" FOREVER_GETHE_TEXT='1.60.1.70170' FOREVER_GETHE_SHA="$other" \
  bash "$script")
assert_eq "$(decision_line "$out")" "decision paused" "pause var"

gitroot=$(mktemp -d)
bare="$gitroot/origin.git"
gsrc="$gitroot/src"
git init --bare -q "$bare"
git init -q -b main "$gsrc"
git -C "$gsrc" config user.email "t@example.com"
git -C "$gsrc" config user.name "t"
mkdir -p "$gsrc/.github"
printf '%s\n' '## Interface: 16001' '## Version: 0.1.3' >"$gsrc/LooseButtons.toc"
base_state >"$gsrc/.github/forever-agent-state"
git -C "$gsrc" add LooseButtons.toc .github/forever-agent-state
git -C "$gsrc" commit -q -m init
git -C "$gsrc" remote add origin "$bare"
git -C "$gsrc" push -q -u origin main
base_wiki >"$wiki"
base_cf >"$cf"
psink="$gitroot/push.json"
env GITHUB_ACTIONS=1 \
  FOREVER_REPO="$gsrc" \
  FOREVER_WIKI_FILE="$wiki" \
  FOREVER_CF_FILE="$cf" \
  FOREVER_GETHE_TEXT='1.60.1.70170' \
  FOREVER_GETHE_SHA="$other" \
  CURSOR_API_KEY='test-key' \
  FOREVER_AGENT_SINK="$psink" \
  FOREVER_AGENT_SINK_CODE=409 \
  bash "$script" >/dev/null
assert_eq "$(sed -n 's/^gethe=//p' "$gsrc/.github/forever-agent-state")" "$other" "state sha"
assert_eq "$(sed -n 's/^## Version:[[:space:]]*//p' "$gsrc/LooseButtons.toc")" "0.1.3" "toc untouched"
git -C "$gsrc" fetch -q origin main
assert_eq "$(git -C "$gsrc" rev-parse HEAD)" "$(git -C "$gsrc" rev-parse origin/main)" "pushed"
rm -f "$psink"
out=$(env GITHUB_ACTIONS=1 \
  FOREVER_REPO="$gsrc" \
  FOREVER_WIKI_FILE="$wiki" \
  FOREVER_CF_FILE="$cf" \
  FOREVER_GETHE_TEXT='1.60.1.70170' \
  FOREVER_GETHE_SHA="$other" \
  CURSOR_API_KEY='test-key' \
  FOREVER_AGENT_SINK="$psink" \
  bash "$script")
assert_eq "$(decision_line "$out")" "decision noop" "pushed second run"
[[ ! -f $psink ]] || fail "second push posted"

err=$(mktemp -d)
esrc=$(new_tree "$err/tree")
ewiki="$err/wiki"
ecf="$err/cf"
base_wiki >"$ewiki"
base_cf >"$ecf"
esink="$err/body.json"
set +e
out=$(env -u GITHUB_ACTIONS -u CF_API_KEY \
  FOREVER_REPO="$esrc" \
  FOREVER_WIKI_FILE="$ewiki" \
  FOREVER_CF_FILE="$ecf" \
  FOREVER_GETHE_TEXT='1.60.1.70170' \
  FOREVER_GETHE_SHA="$other" \
  CURSOR_API_KEY='test-key' \
  FOREVER_AGENT_SINK="$esink" \
  FOREVER_AGENT_SINK_CODE=500 \
  bash "$script")
status=$?
set -e
assert_eq "$status" "1" "http 500 exit"
assert_eq "$(decision_line "$out")" "decision refuse agent-http" "http 500 line"
cmp -s <(base_state) "$esrc/.github/forever-agent-state" || fail "http 500 rewrote state"

iface=$(mktemp -d)
isrc=$(new_tree "$iface/tree")
iwiki="$iface/wiki"
icf="$iface/cf"
base_wiki | sed 's/1\.60\.1/1.61.0/; s/16001/16100/' >"$iwiki"
printf '%s\n' '[{"id":11101,"gameVersionTypeID":517,"name":"12.1.0"},{"id":17100,"gameVersionTypeID":88568,"name":"1.61.0"}]' >"$icf"
sed -i 's/^cf=.*/cf=1.61.0/' "$isrc/.github/forever-agent-state"
isink="$iface/body.json"
out=$(env -u GITHUB_ACTIONS -u CF_API_KEY \
  FOREVER_REPO="$isrc" \
  FOREVER_WIKI_FILE="$iwiki" \
  FOREVER_CF_FILE="$icf" \
  FOREVER_GETHE_TEXT='1.61.0.70180' \
  FOREVER_GETHE_SHA="$seen" \
  CURSOR_API_KEY='test-key' \
  FOREVER_AGENT_SINK="$isink" \
  bash "$script")
assert_eq "$(decision_line "$out")" "decision kick interface game" "interface and game"

printf 'ok\n'
