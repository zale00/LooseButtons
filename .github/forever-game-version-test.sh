#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
script="${1:-$script_dir/upload-curseforge.sh}"

root="$(mktemp -d)"
bare="$root/origin.git"
src="$root/src"
git init --bare -q "$bare"
git init -q -b main "$src"
git -C "$src" config user.email "t@example.com"
git -C "$src" config user.name "t"
cat > "$src/LooseButtons.toc" << 'EOF'
## Interface: 120100
## Title: Loose Buttons
## Version: 0.1.1
## X-Flavor: Mainline
Logic.lua
EOF
printf 'return {}\n' > "$src/Logic.lua"
printf 'package-as: LooseButtons\n' > "$src/.pkgmeta"
printf '# LooseButtons\n\n## 0.1.1\n\n- Forever 1.60.1.\n' > "$src/CHANGELOG.md"
git -C "$src" add LooseButtons.toc Logic.lua .pkgmeta CHANGELOG.md
git -C "$src" commit -q -m "init"
git -C "$src" remote add origin "$bare"
git -C "$src" push -q -u origin main
git -C "$src" tag 0.1.1
git -C "$src" push -q origin refs/tags/0.1.1

cat > "$root/release.sh" << 'EOF'
#!/usr/bin/env bash
if [[ " $* " != *" -d "* ]]; then
  echo "release.sh uploaded using the TOC game version" >&2
  exit 3
fi
mkdir -p .release
printf 'zip' > .release/LooseButtons-0.1.1.zip
exit 0
EOF
chmod +x "$root/release.sh"

cat > "$root/curl" << 'EOF'
#!/usr/bin/env bash
url=""
outfile=""
write_out=""
meta_stdin=0
meta_file=""
prev=""
for arg in "$@"; do
  case "$prev" in
    -o) outfile="$arg" ;;
    -w) write_out="$arg" ;;
    -F)
      if [[ "$arg" == "metadata=<-" ]]; then
        meta_stdin=1
      elif [[ "$arg" == metadata=@* ]]; then
        meta_file="${arg#metadata=@}"
      elif [[ "$arg" == metadata=* ]]; then
        meta_file="${arg#metadata=}"
      fi
      ;;
  esac
  prev="$arg"
  case "$arg" in
    http*) url="$arg" ;;
  esac
done
body='[{"id":11101,"gameVersionTypeID":517,"name":"12.1.0"},{"id":99901,"gameVersionTypeID":88568,"name":"1.60.1"}]'
if [[ "$url" == *"/files"* && "$url" != *"/upload-file" ]]; then
  body='[]'
fi
if [[ "$url" == *"/upload-file" ]]; then
  if [[ "$meta_stdin" -eq 1 ]]; then
    cat > "${CAPTURE_METADATA:?}"
  elif [[ -n "$meta_file" && -f "$meta_file" ]]; then
    cp "$meta_file" "${CAPTURE_METADATA:?}"
  else
    echo "upload metadata missing" >&2
    exit 4
  fi
  body='{"id":4242}'
fi
if [[ -n "$outfile" && "$outfile" != "/dev/null" ]]; then
  printf '%s' "$body" > "$outfile"
fi
if [[ -n "$write_out" ]]; then
  printf '200'
elif [[ -z "$outfile" || "$outfile" == "/dev/null" ]]; then
  printf '%s' "$body"
fi
EOF
chmod +x "$root/curl"

capture="$root/metadata.json"
set +e
out="$(cd "$src" && PATH="$root:$PATH" CAPTURE_METADATA="$capture" CF_API_KEY=present CF_PROJECT_ID=1714504 PACKAGER_SH="$root/release.sh" bash "$script" 2>&1)"
status=$?
set -e
printf '%s\n' "$out"
if [[ "$status" -ne 0 ]]; then
  echo "fail status ${status}" >&2
  exit "$status"
fi
[[ -f "$capture" ]]
python3 - "$capture" << 'PY'
import json, sys
meta = json.load(open(sys.argv[1]))
assert meta["gameVersions"] == [99901], meta
assert meta["releaseType"] == "release"
print("gameVersions", meta["gameVersions"])
PY
echo ok
