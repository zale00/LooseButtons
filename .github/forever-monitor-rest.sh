write_toc() {
  local iface=$1 version=$2 game=$3 retail=$4 file=$5
  sed -i "s/^## Interface:[[:space:]]*.*/## Interface: ${iface}/" "$file"
  sed -i "s/^## Version:[[:space:]]*.*/## Version: ${version}/" "$file"
  sed -i "s/^# .*Forever beta.*/# ${iface} is Forever beta ${game}. The client marks ${retail} incompatible. The upload sends the Forever game-version row and does not let the packager upload./" "$file"
}

write_changelog() {
  local version=$1 iface=$2 game=$3 file=$4 tmp
  tmp=$(mktemp)
  awk -v version="$version" -v iface="$iface" -v game="$game" '
    NR == 1 { print; next }
    NR == 2 && $0 == "" {
      print ""
      print "## " version
      print ""
      print "- The TOC interface is " iface ", Forever beta " game "."
      print ""
      next
    }
    { print }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

write_target() {
  local game=$1 file=$2
  sed -i "s/^forever_name=.*/forever_name=${game}/" "$file"
}

apply_decision() {
  local line=$1 retail=$2 toc=$3 changelog=$4 upload=$5
  local _ kind a b c flag
  read -r _ kind a b c flag <<<"$line"
  case $kind in
    bump)
      write_toc "$a" "$b" "$c" "$retail" "$toc"
      write_changelog "$b" "$a" "$c" "$changelog"
      if [[ $flag == upload ]]; then
        write_target "$c" "$upload"
      fi
      ;;
    retarget)
      write_target "$a" "$upload"
      ;;
    retry-upload) ;;
    *) die "apply" ;;
  esac
}

wants_dispatch() {
  [[ $1 == *' upload' || $1 == decision\ retry-upload\ * ]]
}

commit_and_push() {
  local line=$1
  local _ kind a b c
  read -r _ kind a b c <<<"$line"
  local branch msg
  branch=$(git rev-parse --abbrev-ref HEAD)
  [[ $branch == main ]] || die "not-main"
  git add -- LooseButtons.toc CHANGELOG.md .github/upload-curseforge.sh
  if git diff --cached --quiet; then
    :
  else
    if [[ $kind == bump ]]; then
      msg="compat: Forever interface ${a}"
    else
      msg="compat: CurseForge Forever game version ${a}"
    fi
    git -c user.name='github-actions[bot]' \
      -c user.email='41898282+github-actions[bot]@users.noreply.github.com' \
      commit -m "$msg"
    git push origin HEAD:main
  fi
  if wants_dispatch "$line"; then
    gh workflow run tag-release.yml --ref main
  fi
}

main() {
  local mode=check root pause wiki gethe_text cf toc changelog upload
  local camelot standard wiki_pair wiki_game wiki_iface retail_iface
  local gethe_game toc_iface toc_ver script tag_exists=0 decision
  local -a names=()

  if [[ ${1:-} == --apply ]]; then
    mode=apply
  elif [[ ${1:-} == --check ]]; then
    mode=check
  elif [[ -n ${GITHUB_ACTIONS:-} ]]; then
    mode=push
  fi

  root=$(root_of)
  cd "$root"
  pause="$root/.github/FOREVER_MONITOR_PAUSE"
  if [[ ${FOREVER_MONITOR:-} == off || -f $pause ]]; then
    printf 'decision paused\n'
    exit 0
  fi

  toc="$root/LooseButtons.toc"
  changelog="$root/CHANGELOG.md"
  upload="$root/.github/upload-curseforge.sh"
  [[ -f $toc && -f $changelog && -f $upload ]] || die "missing-files"

  if [[ -n ${FOREVER_WIKI_FILE:-} ]]; then
    wiki=$FOREVER_WIKI_FILE
  else
    wiki=$(mktemp)
    curl -fsSL -A 'LooseButtons-monitor/1.0' -o "$wiki" \
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
  local retail_game
  read -r retail_game retail_iface <<<"$wiki_pair"

  if [[ -n ${FOREVER_GETHE_TEXT:-} ]]; then
    gethe_text=$FOREVER_GETHE_TEXT
  else
    gethe_text=$(curl -fsSL 'https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/version.txt' | tr -d '\r\n') || die "gethe-fetch"
  fi
  gethe_game=$(game_of "$gethe_text") || die "gethe-parse"

  toc_iface=$(toc_field Interface "$toc")
  toc_ver=$(toc_field Version "$toc")
  script=$(script_game "$upload")
  [[ $toc_iface =~ ^[0-9]+$ ]] || die "toc-interface"
  [[ -n $script ]] || die "script-target"
  printf 'signal wiki %s %s gethe %s toc %s %s script %s\n' \
    "$wiki_game" "$wiki_iface" "$gethe_text" "$toc_iface" "$toc_ver" "$script"

  if [[ -n ${FOREVER_CF_FILE:-} ]]; then
    cf=$FOREVER_CF_FILE
  elif [[ -n ${CF_API_KEY:-} ]]; then
    cf=$(mktemp)
    local code
    code=$(curl -sS -o "$cf" -w '%{http_code}' \
      -H "x-api-token: ${CF_API_KEY}" \
      -H 'Accept: application/json' \
      'https://wow.curseforge.com/api/game/wow/versions' || true)
    [[ $code == 200 ]] || die "cf-http"
  else
    cf=""
  fi

  if [[ -z $cf ]]; then
    if [[ -n ${GITHUB_ACTIONS:-} ]]; then
      die "no-cf"
    fi
    if [[ $toc_iface == "$wiki_iface" && $gethe_game == "$wiki_game" && $wiki_iface != "$retail_iface" && $wiki_iface == "$(interface_of "$wiki_game")" && ${wiki_game%%.*} -lt $forever_major_limit ]]; then
      printf 'notice cf unchecked\n'
      printf 'decision noop\n'
      exit 0
    fi
    die "no-cf"
  fi

  local names_text
  names_text=$(load_cf_names "$cf" "$retail_game") || die "cf-parse"
  if [[ -n $names_text ]]; then
    mapfile -t names <<<"$names_text"
  fi

  if cf_tag_exists "$toc_ver"; then
    tag_exists=1
  fi

  decision=$(decide "$toc_iface" "$toc_ver" "$wiki_game" "$wiki_iface" "$retail_iface" "$gethe_game" "$script" "$tag_exists" "${names[@]+"${names[@]}"}")
  printf '%s\n' "$decision"
  [[ $decision == decision\ refuse\ * ]] && exit 1
  [[ $decision == 'decision noop' ]] && exit 0
  [[ $mode == check ]] && exit 0

  apply_decision "$decision" "$retail_iface" "$toc" "$changelog" "$upload"
  [[ $mode == push ]] || exit 0
  commit_and_push "$decision"
}
