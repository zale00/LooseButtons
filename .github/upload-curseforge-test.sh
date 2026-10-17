#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
script="${1:-$script_dir/upload-curseforge.sh}"

set +e
out="$(CF_API_KEY= bash "$script" 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 ]]
[[ "$out" == $'CF_API_KEY is missing\n::error::CF_API_KEY is missing' ]]

root="$(mktemp -d)"
bare="$root/origin.git"
src="$root/src"
git init --bare -q "$bare"
git init -q -b main "$src"
git -C "$src" config user.email "t@example.com"
git -C "$src" config user.name "t"
printf '## Version: 0.1.0\n' > "$src/LooseButtons.toc"
git -C "$src" add LooseButtons.toc
git -C "$src" commit -q -m "init"
git -C "$src" remote add origin "$bare"
git -C "$src" push -q -u origin main
git -C "$src" tag cf-0.1.0
git -C "$src" push -q origin refs/tags/cf-0.1.0

bin="$root/bin"
mkdir -p "$bin"
cat > "$bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl was called" >&2
exit 99
EOF
chmod +x "$bin/curl"

out="$(cd "$src" && PATH="$bin:$PATH" CF_API_KEY=present bash "$script")"
[[ "$out" == $'CF_API_KEY is set\n::notice::CF_API_KEY is set\nskip upload: cf-0.1.0 already exists\n::notice::skip upload: cf-0.1.0 already exists' ]]


# Duplicate check, offline. MOCK picks the public list responses.
dup="$root/dup"
mkdir -p "$dup"
cat > "$dup/curl" <<'EOF'
#!/usr/bin/env bash
url="" outfile="" prev=""
for arg in "$@"; do
  [[ "$prev" == "-o" ]] && outfile="$arg"
  prev="$arg"
  [[ "$arg" == http* ]] && url="$arg"
done
code=200
case "${MOCK:?}:$url" in
  found:https://www.curseforge.com/*) body='{"data":[{"id":9224985,"displayName":"0.1.9","fileName":"LooseButtons-0.1.9-forever.zip"}],"pagination":{"totalCount":1}}' ;;
  named:https://www.curseforge.com/*) body='{"data":[{"id":9140226,"displayName":"LooseButtons 0.1.8","fileName":"x.zip"}],"pagination":{"totalCount":1}}' ;;
  *:https://www.curseforge.com/*) code=403; body='<html>Just a moment</html>' ;;
  widgetonly:https://api.cfwidget.com/*) body='{"files":[{"id":9138000,"display":"0.1.7","name":"LooseButtons-0.1.7-forever.zip","version":"1.60.1"}]}' ;;
  found:https://api.cfwidget.com/*|named:https://api.cfwidget.com/*) body='{"files":[]}' ;;
  *:https://api.cfwidget.com/*) code=000; body='' ;;
  *) echo "unexpected curl $url" >&2; exit 98 ;;
esac
[[ -n "$outfile" ]] && printf '%s' "$body" > "$outfile"
printf '%s' "$code"
EOF
chmod +x "$dup/curl"
check() { PATH="$dup:$PATH" bash "$script" --check-duplicate 1714504 "$@" 2>&1; }

if out="$(MOCK=found check 0.1.9)"; then echo "check should refuse: MOCK=found check 0.1.9" >&2; exit 1; fi
[[ "$out" == *"refusing upload: CurseForge project 1714504 already has 0.1.9"* ]]
out="$(MOCK=found check 0.1.10)"
[[ "$out" == *"0.1.10 is not on project 1714504"* ]]
if out="$(MOCK=named check 0.1.8)"; then echo "check should refuse: MOCK=named check 0.1.8" >&2; exit 1; fi
[[ "$out" == *"already has 0.1.8"* ]]
if out="$(MOCK=widgetonly check 0.1.7)"; then echo "check should refuse: MOCK=widgetonly check 0.1.7" >&2; exit 1; fi
[[ "$out" == *"cfwidget: found 0.1.7"* ]]
# CFWidget version is the game version, so 1.60.1 is not an addon file.
out="$(MOCK=widgetonly check 1.60.1)"
[[ "$out" == *"1.60.1 is not on project 1714504"* ]]
if out="$(MOCK=down check 0.2.0)"; then echo "check should refuse: MOCK=down check 0.2.0" >&2; exit 1; fi
[[ "$out" == *"neither public file list could be read"* ]]
out="$(MOCK=down CF_ALLOW_UNVERIFIED_DUPLICATE_CHECK=1 check 0.2.0)"
[[ "$out" == *"continuing because CF_ALLOW_UNVERIFIED_DUPLICATE_CHECK=1"* ]]

echo ok
