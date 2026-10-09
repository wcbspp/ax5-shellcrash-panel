#!/bin/sh
set -eu
C=/data/ShellCrash
base=$(sed -n 's/^base=//p' "$C/configs/mirror.conf" 2>/dev/null | head -1)
target=$(sed -n 's/^target=//p' "$C/configs/mirror.conf" 2>/dev/null | head -1)
[ -n "$base" ] && [ -n "$target" ] || { echo 'Mirror upload not configured' >&2;exit 2; }
printf '%s' "$target" | grep -Eq '^[a-z_][a-z0-9_-]{0,31}@[A-Za-z0-9.-]+:[0-9]{1,5}$' || exit 2
peer=${target%:*};port=${target##*:};[ "$port" -ge 1 ] && [ "$port" -le 65535 ] || exit 2
[ -s "$C/configs/mirror-id" ] && [ -s "$C/configs/mirror_known_hosts" ] || exit 2
mkdir -p /root/.ssh;chmod 700 /root/.ssh
touch /root/.ssh/known_hosts;chmod 600 /root/.ssh/known_hosts
while IFS= read -r line;do grep -Fxq "$line" /root/.ssh/known_hosts || printf '%s\n' "$line" >> /root/.ssh/known_hosts;done < "$C/configs/mirror_known_hosts"
hash=$(openssl dgst -sha256 "$2" | awk '{print $NF}')
reply=$(timeout -t 45 ssh -K 10 -I 20 -i "$C/configs/mirror-id" -p "$port" "$peer" "put $1 $hash $3" < "$2")
[ "$reply" = "$hash" ] || exit 1
if [ "$1" != backup ];then
 curl -4 --noproxy '*' -fsSL --connect-timeout 4 --max-time 45 --max-filesize "$(wc -c < "$2")" "$base/$1-$hash.$3" | openssl dgst -sha256 | grep -q "$hash$" || exit 1
fi
printf '%s\n' "$hash"
