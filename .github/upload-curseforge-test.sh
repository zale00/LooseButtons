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

echo ok
