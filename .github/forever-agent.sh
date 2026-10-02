#!/usr/bin/env bash
# Starts one Cursor cloud agent when Forever source, interface, or CurseForge name moves.
# Does not edit the TOC. Prints one "decision ..." line.
# Commits .github/forever-agent-state and pushes main only when GITHUB_ACTIONS is set.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
. "$here/forever-monitor.sh"

agent_repo='https://github.com/zale00/LooseButtons'
agent_model='grok-4.7-xhigh-fast'

state_get() {
  local key=$1 file=$2
  sed -n "s/^${key}=//p" "$file" | head -n 1 | tr -d '\r'
}

cf_signal_name() {
  local file=$1 wiki_game=$2 retail_game=$3
  local names_text name
  if [[ -z $file ]]; then
    printf 'unchecked\n'
    return 0
  fi
  names_text=$(load_cf_names "$file" "$retail_game") || return 1
  if [[ -n $names_text ]]; then
    while IFS= read -r name; do
      [[ $name == "$wiki_game" ]] && {
        printf '%s\n' "$wiki_game"
        return 0
      }
    done <<<"$names_text"
  fi
  printf 'missing\n'
}

decide_agent() {
  local seen_gethe=$1 seen_iface=$2 seen_game=$3 seen_cf=$4
  local wiki_game=$5 wiki_iface=$6 retail_iface=$7 gethe_game=$8 gethe_sha=$9 cf_name=${10}
  local major reasons=()

  major=${wiki_game%%.*}
  if (( major >= forever_major_limit )) || [[ $wiki_iface == "$retail_iface" ]]; then
    printf 'decision refuse retail\n'
    return 0
  fi
  if [[ $wiki_iface != "$(interface_of "$wiki_game")" ]]; then
    printf 'decision refuse wiki-interface\n'
    return 0
  fi
  if [[ $gethe_game != "$wiki_game" ]]; then
    printf 'decision refuse disagree\n'
    return 0
  fi
  [[ $seen_gethe =~ ^[0-9a-f]{40}$ ]] || {
    printf 'decision refuse state\n'
    return 0
  }
  [[ $seen_iface =~ ^[0-9]+$ ]] || {
    printf 'decision refuse state\n'
    return 0
  }
  [[ $gethe_sha =~ ^[0-9a-f]{40}$ ]] || {
    printf 'decision refuse gethe-sha\n'
    return 0
  }

  [[ $seen_gethe == "$gethe_sha" ]] || reasons+=(gethe)
  [[ $seen_iface == "$wiki_iface" ]] || reasons+=(interface)
  [[ $seen_game == "$wiki_game" ]] || reasons+=(game)
  if [[ $seen_cf != unchecked && $cf_name != unchecked && $seen_cf != "$cf_name" ]]; then
    reasons+=(cf)
  fi
  if [[ ${#reasons[@]} -eq 0 ]]; then
    printf 'decision noop\n'
    return 0
  fi
  printf 'decision kick'
  local reason
  for reason in "${reasons[@]}"; do
    printf ' %s' "$reason"
  done
  printf '\n'
}

prompt_text() {
  local seen_gethe=$1 seen_iface=$2 seen_game=$3 seen_cf=$4
  local gethe_sha=$5 wiki_iface=$6 wiki_game=$7 cf_name=$8 reasons=$9
  cat <<EOF
You are a poteto-mode cloud agent on LooseButtons. Forever only.

The model for this run is grok-4.7-xhigh-fast. If you delegate, use grok-4.7-xhigh-fast for code. Opus may be claude-opus-5-5-high at most. Do not use an OpenAI model. Do not use a model id that ends in -max.

LooseButtons is the Forever addon in github.com/zale00/LooseButtons. The client load path is the ## Interface line in LooseButtons.toc. Retail interface 120100 and CurseForge game version type 517 are not a fallback. If the wiki camelot row matches the retail row, stop.

The Forever monitor workflow already bumps ## Interface and forever_name in .github/upload-curseforge.sh when the camelot interface or the CurseForge Forever row name changes. Leave that edit alone when main already has it. Do not call the CurseForge upload API. Tag release on main uploads Forever only.

Signal ${reasons}.
Seen gethe ${seen_gethe}, interface ${seen_iface}, game ${seen_game}, cf ${seen_cf}.
Now gethe ${gethe_sha}, interface ${wiki_iface}, game ${wiki_game}, cf ${cf_name}.

Diff Gethe/wow-ui-source branch forever from the seen commit to the new commit. Read FrameXML secure templates, the Camelot spellbook (AddIconTab, PlayerSpellsFrame), Edit Mode, and the docs for C_Spell, C_SpellBook, C_Item, C_EncodingUtil, UnitHealth, and issecretvalue. Change LooseButtons.lua or Logic.lua only where that diff breaks this addon. Run luacheck and lua5.1 tools/check_loosebuttons.lua. Run wow-secret-lint when it is installed.

If nothing in this addon breaks, stop. Do not open a pull request. Do not bump ## Version.

If you change Lua, bump the patch component of ## Version, put that same version on the first ## heading in CHANGELOG.md, and open a pull request. Merge that pull request only after those checks pass. A merge to main runs Tag release.

Origin eric-r/wow-addons keeps the addon under LooseButtons/. This GitHub repo is the flat copy. Copy changed addon files back under Origin LooseButtons/ when you can push there. Do not replace this GitHub tree with the Origin tree. That deletes .github/.

If a pull request already names gethe ${gethe_sha}, stop.
EOF
}

agent_body() {
  local text=$1
  AGENT_PROMPT=$text AGENT_MODEL=$agent_model AGENT_REPO=$agent_repo python3 - <<'PY'
import json, os, uuid
signal = os.environ["AGENT_SIGNAL"]
agent_id = "bc-" + str(uuid.uuid5(uuid.NAMESPACE_URL, "loosebuttons-forever-agent:" + signal))
body = {
    "prompt": {"text": os.environ["AGENT_PROMPT"]},
    "model": {"id": os.environ["AGENT_MODEL"]},
    "name": "Forever compat",
    "repos": [{"url": os.environ["AGENT_REPO"], "startingRef": "main"}],
    "workOnCurrentBranch": False,
    "autoCreatePR": True,
    "mode": "agent",
    "agentId": agent_id,
}
print(json.dumps(body))
PY
}

post_agent() {
  local body=$1 resp code
  if [[ -n ${FOREVER_AGENT_SINK:-} ]]; then
    cp "$body" "$FOREVER_AGENT_SINK"
    printf '%s\n' "${FOREVER_AGENT_SINK_CODE:-201}"
    return 0
  fi
  resp=$(mktemp)
  code=$(curl -sS -o "$resp" -w '%{http_code}' \
    -u "${CURSOR_API_KEY}:" \
    -H 'Content-Type: application/json' \
    --data-binary @"$body" \
    https://api.cursor.com/v1/agents) || {
    rm -f "$resp"
    return 1
  }
  rm -f "$resp"
  printf '%s\n' "$code"
}

write_state() {
  local file=$1 gethe=$2 iface=$3 game=$4 cf=$5
  local tmp
  tmp=$(mktemp "${file}.XXXXXX")
  printf 'gethe=%s\ninterface=%s\ngame=%s\ncf=%s\n' "$gethe" "$iface" "$game" "$cf" >"$tmp"
  mv "$tmp" "$file"
}

commit_state() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  [[ $branch == main ]] || die "not-main"
  git add -- .github/forever-agent-state
  git diff --cached --quiet && return 0
  git -c user.name='github-actions[bot]' \
    -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
    commit -m "compat: note Forever agent signal"
  git pull --rebase -q origin main
  git push -q origin HEAD:main
}

agent_main() {
  local root pause state wiki cf gethe_text gethe_sha
  local camelot standard wiki_pair wiki_game wiki_iface retail_iface retail_game
  local gethe_game seen_gethe seen_iface seen_game seen_cf cf_name decision
  local reasons body_file code recorded_cf signal

  root=$(root_of)
  cd "$root"
  pause="$root/.github/FOREVER_MONITOR_PAUSE"
  if [[ ${FOREVER_MONITOR:-} == off || -f $pause ]]; then
    printf 'decision paused\n'
    exit 0
  fi

  state="$root/.github/forever-agent-state"
  [[ -f $state ]] || die "state"

  if [[ -n ${FOREVER_WIKI_FILE:-} ]]; then
    wiki=$FOREVER_WIKI_FILE
  else
    wiki=$(mktemp)
    curl -fsSL -A 'LooseButtons-agent/1.0' -o "$wiki" \
      'https://warcraft.wiki.gg/wiki/Template:LatestPatchInfo?action=raw' || die "wiki-fetch"
  fi
  camelot=$(wiki_line 'camelot' "$wiki" || true)
  if [[ -z $camelot ]]; then
    camelot=$(wiki_line 'camelot-beta' "$wiki" || true)
  fi
  [[ -n $camelot ]] || die "no-camelot"
  standard=$(wiki_line 'standard' "$wiki" || true)
  [[ -n $standard ]] || die "no-retail-row"
  wiki_pair=$(wiki_game_interface "$camelot") || die "wiki-parse"
  read -r wiki_game wiki_iface <<<"$wiki_pair"
  wiki_pair=$(wiki_game_interface "$standard") || die "wiki-parse"
  read -r retail_game retail_iface <<<"$wiki_pair"

  if [[ -n ${FOREVER_GETHE_TEXT:-} ]]; then
    gethe_text=$FOREVER_GETHE_TEXT
  else
    gethe_text=$(curl -fsSL 'https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/version.txt' | tr -d '\r\n') || die "gethe-fetch"
  fi
  gethe_game=$(game_of "$gethe_text") || die "gethe-parse"

  if [[ -n ${FOREVER_GETHE_SHA:-} ]]; then
    gethe_sha=$FOREVER_GETHE_SHA
  else
    gethe_sha=$(curl -fsSL -H 'Accept: application/vnd.github+json' \
      'https://api.github.com/repos/Gethe/wow-ui-source/commits/forever' |
      python3 -c 'import json,sys; print(json.load(sys.stdin)["sha"])') || die "gethe-sha"
  fi

  if [[ -n ${FOREVER_CF_FILE:-} ]]; then
    cf=$FOREVER_CF_FILE
  elif [[ -n ${CF_API_KEY:-} ]]; then
    cf=$(mktemp)
    code=$(curl -sS -o "$cf" -w '%{http_code}' \
      -H "x-api-token: ${CF_API_KEY}" \
      -H 'Accept: application/json' \
      'https://wow.curseforge.com/api/game/wow/versions' || true)
    [[ $code == 200 ]] || die "cf-http"
  else
    cf=""
  fi
  cf_name=$(cf_signal_name "$cf" "$wiki_game" "$retail_game") || die "cf-parse"

  seen_gethe=$(state_get gethe "$state")
  seen_iface=$(state_get interface "$state")
  seen_game=$(state_get game "$state")
  seen_cf=$(state_get cf "$state")
  printf 'signal wiki %s %s gethe %s %s cf %s seen %s %s %s %s\n' \
    "$wiki_game" "$wiki_iface" "$gethe_text" "$gethe_sha" "$cf_name" \
    "$seen_gethe" "$seen_iface" "$seen_game" "$seen_cf"

  decision=$(decide_agent "$seen_gethe" "$seen_iface" "$seen_game" "$seen_cf" \
    "$wiki_game" "$wiki_iface" "$retail_iface" "$gethe_game" "$gethe_sha" "$cf_name")
  if [[ $decision == decision\ refuse\ * || $decision == 'decision noop' ]]; then
    printf '%s\n' "$decision"
    [[ $decision == 'decision noop' ]] && exit 0
    exit 1
  fi
  [[ $decision == decision\ kick\ * ]] || die "decision"
  if [[ -z ${CURSOR_API_KEY:-} && -z ${FOREVER_AGENT_SINK:-} ]]; then
    printf 'decision blocked\n'
    if [[ -n ${GITHUB_ACTIONS:-} ]]; then
      printf '::warning title=Forever agent::decision blocked\n'
    fi
    exit 0
  fi
  if [[ -n ${GITHUB_ACTIONS:-} ]]; then
    branch=$(git rev-parse --abbrev-ref HEAD)
    [[ $branch == main ]] || die "not-main"
  fi

  reasons=${decision#decision kick }
  if [[ $cf_name == unchecked ]]; then
    recorded_cf=$seen_cf
  else
    recorded_cf=$cf_name
  fi
  signal="gethe=${gethe_sha} interface=${wiki_iface} game=${wiki_game} cf=${recorded_cf}"
  body_file=$(mktemp)
  AGENT_SIGNAL=$signal agent_body "$(prompt_text "$seen_gethe" "$seen_iface" "$seen_game" "$seen_cf" \
    "$gethe_sha" "$wiki_iface" "$wiki_game" "$cf_name" "$reasons")" >"$body_file"
  code=$(post_agent "$body_file") || die "agent-post"
  rm -f "$body_file"
  if [[ $code != 200 && $code != 201 && $code != 409 ]]; then
    printf 'decision refuse agent-http\n'
    exit 1
  fi
  printf '%s\n' "$decision"
  printf 'notice agent http %s\n' "$code"

  write_state "$state" "$gethe_sha" "$wiki_iface" "$wiki_game" "$recorded_cf"
  [[ -n ${GITHUB_ACTIONS:-} ]] || exit 0
  commit_state
}

main() {
  agent_main "$@"
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
