#!/usr/bin/env bash
# Exercise the publisher with local release fixtures and a disposable signing key.
set -euo pipefail
source_dir=$(cd "$(dirname "$0")" && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
mkdir -p "$temp_dir/releases" "$temp_dir/tools" "$temp_dir/gnupg"
chmod 0700 "$temp_dir/gnupg"
export GNUPGHOME="$temp_dir/gnupg"
export FLAKY_TEST_ASSETS="$temp_dir/releases"
export PATH="$temp_dir/tools:$PATH"
gpg --batch --passphrase '' --quick-generate-key 'APT fixture <fixture@example.test>' ed25519 sign 1d
gpg --export > "$temp_dir/public.gpg"

make_package() {
  local name=$1 arch=$2 filename=$3 root
  root=$(mktemp -d "$temp_dir/package.XXXXXX")
  mkdir -p "$root/DEBIAN" "$root/usr/bin"
  printf 'Package: %s\nVersion: 0.1.1\nArchitecture: %s\nMaintainer: Fixture <fixture@example.test>\nDescription: Package fixture\n' "$name" "$arch" > "$root/DEBIAN/control"
  printf '#!/bin/sh\nexit 0\n' > "$root/usr/bin/$name"
  chmod 0755 "$root/usr/bin/$name"
  dpkg-deb --root-owner-group --build "$root" "$temp_dir/releases/$filename" >/dev/null
}
make_package flaky amd64 flaky_0.1.1_amd64.deb
make_package flaky arm64 flaky_0.1.1_arm64.deb
make_package yonder amd64 yonder_0.1.1_amd64.deb
(cd "$temp_dir/releases" && sha256sum flaky_*.deb > checksums.txt)
cat > "$temp_dir/tools/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=
url=
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--retry) option=$1; value=$2; shift 2; [[ "$option" != -o ]] || output=$value ;;
    -*) shift ;;
    *) url=$1; shift ;;
  esac
done
case "$url" in
  https://api.github.com/repos/dpologdvinity/flaky/releases/latest) printf '{"tag_name":"v0.1.1"}\n' ;;
  https://github.com/dpologdvinity/flaky/releases/download/v0.1.1/*) cp "$FLAKY_TEST_ASSETS/${url##*/}" "$output" ;;
  *) exit 22 ;;
esac
EOF
chmod +x "$temp_dir/tools/curl"
prepare_work() {
  mkdir -p "$1/apt"
  cp "$source_dir/update-flaky.sh" "$source_dir/build-apt.sh" "$1/"
  cp "$temp_dir/releases/yonder_0.1.1_amd64.deb" "$1/apt/"
}
work="$temp_dir/success"
prepare_work "$work"
result=$(cd "$work" && ./update-flaky.sh)
test "$result" = 0.1.1
test "$(cat "$work/.flaky-version")" = 0.1.1
grep -q '^Package: flaky$' "$work/apt/Packages"
grep -q '^Package: yonder$' "$work/apt/Packages"
cmp "$temp_dir/releases/yonder_0.1.1_amd64.deb" "$work/apt/yonder_0.1.1_amd64.deb"
gpgv --keyring "$temp_dir/public.gpg" "$work/apt/InRelease"
cp "$work/apt/InRelease" "$temp_dir/previous-index"
result=$(cd "$work" && ./update-flaky.sh)
test "$result" = unchanged
cmp "$temp_dir/previous-index" "$work/apt/InRelease"

printf '%064d  flaky_0.1.1_amd64.deb\n' 0 > "$temp_dir/releases/checksums.txt"
failed="$temp_dir/checksum-failure"
prepare_work "$failed"
if (cd "$failed" && ./update-flaky.sh); then echo 'Accepted bad checksum' >&2; exit 1; fi
test ! -e "$failed/.flaky-version"
test ! -e "$failed/apt/flaky_0.1.1_amd64.deb"
test ! -e "$failed/apt/InRelease"

make_package flaky amd64 flaky_0.1.1_arm64.deb
(cd "$temp_dir/releases" && sha256sum flaky_*.deb > checksums.txt)
failed="$temp_dir/architecture-failure"
prepare_work "$failed"
if (cd "$failed" && ./update-flaky.sh); then echo 'Accepted wrong architecture' >&2; exit 1; fi
test ! -e "$failed/.flaky-version"
test ! -e "$failed/apt/flaky_0.1.1_amd64.deb"
echo 'PASS: signed APT index, preserved packages, idempotence, checksum and architecture failures'
