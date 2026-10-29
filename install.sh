#!/bin/sh
# Install a verified, versioned Transit bundle without changing installation data.
set -eu

fail() { printf '%s\n' "error: $*" >&2; exit 1; }
version=
channel=
checksums_digest=
source_directory=
prefix=${HOME:?HOME is required}/.local
while [ "$#" -gt 0 ]; do
  case "$1" in
    --channel) [ "$#" -ge 2 ] || fail '--channel requires stable or nightly'; channel=$2; shift 2 ;;
    --version) [ "$#" -ge 2 ] || fail '--version requires a release version'; version=$2; shift 2 ;;
    --prefix) [ "$#" -ge 2 ] || fail '--prefix requires a directory'; prefix=$2; shift 2 ;;
    --from) [ "$#" -ge 2 ] || fail '--from requires a directory'; source_directory=$2; shift 2 ;;
    --help) printf '%s\n' 'Usage: install.sh [--channel stable|nightly | --version VERSION] [--prefix DIRECTORY] [--from DIRECTORY]'; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done
case "$(uname -s):$(uname -m)" in
  Linux:x86_64) platform=linux-x86_64 ;;
  Linux:aarch64|Linux:arm64) platform=linux-aarch64 ;;
  *) fail 'release executables support Linux x86_64 and ARM64; macOS and Windows require runtime portability work' ;;
esac
for tool in tar sha256sum awk mktemp readlink; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is required"
done
if [ -n "$source_directory" ]; then
  [ -n "$version" ] || fail '--from requires --version'
  [ -d "$source_directory" ] || fail '--from directory does not exist'
else
  command -v curl >/dev/null 2>&1 || fail 'curl is required'
fi
case "$channel" in ''|stable|nightly) ;; *) fail 'invalid release channel' ;; esac
[ -z "$channel" ] || [ -z "$version" ] || fail '--channel and --version are mutually exclusive'
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
trap 'exit 1' HUP INT TERM
base=https://github.com/spoke-sh/transit/releases
if [ "$channel" = nightly ]; then
  curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --output "$temporary/nightly.json" https://raw.githubusercontent.com/spoke-sh/transit/release-channels/nightly.json
  version=$(awk -F '\"' '$2 == "release" { print $4; count++ } END { if (count != 1) exit 1 }' "$temporary/nightly.json") || fail 'invalid nightly channel identity'
  checksums_digest=$(awk -F '\"' '$2 == "checksums_sha256" { print $4; count++ } END { if (count != 1) exit 1 }' "$temporary/nightly.json") || fail 'invalid nightly checksums identity'
  printf '%s\n' "$checksums_digest" | awk 'length($0) == 64 && $0 !~ /[^0-9a-f]/ { ok++ } END { exit !(NR == 1 && ok == 1) }' || fail 'invalid nightly checksums digest'
fi
if [ -z "$version" ]; then
  url=$(curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --output /dev/null --write-out '%{url_effective}' "$base/latest")
  case "$url" in "$base"/tag/v*) version=${url##*/v} ;; *) fail 'no published Transit release found' ;; esac
fi
printf '%s\n' "$version" | awk '/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-nightly\.[0-9]{8}\.g[0-9a-f]{12})?$/ { ok++ } END { exit !(NR == 1 && ok == 1) }' || fail 'invalid version'
case "$prefix" in /*) ;; *) fail '--prefix must be an absolute path' ;; esac
case "$version" in
  *-nightly.*) tag=$(printf '%s\n' "$version" | awk -F. '{ print "nightly-" $(NF-1) "-" $NF }') ;;
  *) [ "$channel" != nightly ] || fail 'nightly channel selected a stable version'; tag=v$version ;;
esac
asset=transit-$version-$platform.tar.gz
for file in "$asset" SHA256SUMS; do
  if [ -n "$source_directory" ]; then
    cp "$source_directory/$file" "$temporary/$file"
  else
    curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --tlsv1.2 \
      --output "$temporary/$file" "$base/download/$tag/$file"
  fi
done
if [ -n "$checksums_digest" ]; then
  printf '%s  SHA256SUMS\n' "$checksums_digest" > "$temporary/channel-checksum"
  (cd "$temporary" && sha256sum --check channel-checksum) || fail 'nightly channel checksum mismatch'
fi
awk -v asset="$asset" '$2 == asset { print; count++ } END { if (count != 1) exit 1 }' \
  "$temporary/SHA256SUMS" > "$temporary/checksum" || fail 'missing or duplicate archive checksum'
(cd "$temporary" && sha256sum --check checksum) || fail 'archive checksum mismatch'
directory=transit-$version-$platform
tar -tvzf "$temporary/$asset" | awk 'substr($0, 1, 1) != "-" && substr($0, 1, 1) != "d" { bad=1 } END { exit bad }' || fail 'archive contains links or special files'
tar -tzf "$temporary/$asset" > "$temporary/entries"
while IFS= read -r entry; do
  case "$entry" in *../*|*/..|/*) fail 'unsafe archive path' ;; esac
  case "$entry" in "$directory/"*) ;; *) fail 'unexpected archive layout' ;; esac
done < "$temporary/entries"
tar -xzf "$temporary/$asset" -C "$temporary" --no-same-owner --no-same-permissions
bundle=$temporary/$directory
[ -x "$bundle/bin/transit" ] || fail 'archive is missing transit'
identity=$("$bundle/bin/transit" --version)
case "$identity" in "Transit $version (git "*"; CLI contract 1)") ;; *) fail 'archive version mismatch' ;; esac
destination=$prefix/lib/transit/$version
[ ! -e "$destination" ] || fail "$destination already exists; choose another prefix or version"
mkdir -p "$prefix/bin" "$prefix/lib/transit"
for binary in "$bundle"/bin/*; do
  name=${binary##*/}
  [ -f "$binary" ] && [ ! -L "$binary" ] || fail 'unexpected executable entry'
  if [ -e "$prefix/bin/$name" ] || [ -L "$prefix/bin/$name" ]; then
    [ -L "$prefix/bin/$name" ] || fail "refusing to replace $prefix/bin/$name"
    case "$(readlink "$prefix/bin/$name")" in "$prefix/lib/transit/"*/bin/"$name") ;; *) fail "unrelated symlink: $prefix/bin/$name" ;; esac
  fi
done
# Stage on the destination filesystem, then publish a complete version directory.
stage=$(mktemp -d "$prefix/lib/transit/.install.XXXXXXXX")
trap 'rm -rf "$temporary" "${stage:-}"' EXIT
cp -R "$bundle/." "$stage/"
mv "$stage" "$destination"
stage=
for binary in "$destination"/bin/*; do
  name=${binary##*/}
  ln -s "$binary" "$prefix/bin/.$name.new.$$"
  mv -f "$prefix/bin/.$name.new.$$" "$prefix/bin/$name"
done
printf '%s\n' "Installed $identity" "Add $prefix/bin to PATH."
