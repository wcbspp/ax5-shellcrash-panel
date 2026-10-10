#!/bin/sh
set -e
umask 077
version=1.0.1
name=XiaoMiAX5-shellcrash-panel-$version
base=https://github.com/wcbspp/XiaoMiAX5-shellcrash-panel/releases/download/v$version
work=$(mktemp -d /tmp/ax5-panel.XXXXXX)
trap 'rm -rf "$work"' EXIT HUP INT TERM
fetch(){ curl -4 -fsSL --connect-timeout 8 --max-time 120 --max-filesize 3000000 "$1" -o "$2"; }
fetch "$base/$name.tar.gz" "$work/$name.tar.gz"
fetch "$base/SHA256SUMS" "$work/SHA256SUMS"
expected=$(awk -v n="$name.tar.gz" '$2==n{print $1}' "$work/SHA256SUMS")
actual=$(openssl dgst -sha256 "$work/$name.tar.gz" | awk '{print $NF}')
[ ${#expected} = 64 ] && [ "$actual" = "$expected" ] || { echo '发布包校验失败' >&2;exit 1; }
# Extract only this release directory, with traversal and link entries rejected.
tar -tzf "$work/$name.tar.gz" | awk -v root="$name/" 'index($0,root)!=1 || $0 ~ /(^|\/)\.\.(\/|$)/ {exit 1}'
tar -tvzf "$work/$name.tar.gz" | awk 'substr($0,1,1)!="-" && substr($0,1,1)!="d"{exit 1}'
tar -xzf "$work/$name.tar.gz" -C "$work"
sh "$work/$name/install.sh" "${1:-auto}"
