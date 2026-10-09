#!/bin/sh
# Run ShellCrash subscription retrieval in isolation; commit only after adapter validation.
set -e
umask 077
platform=${1:-ax5}
mode=${2:-direct}
case "$platform" in
 ax5) T=/data/ShellCrash-tool; R=/tmp/ShellCrash; input=$R/upload-source; output=$R/subscription.raw; proxy=http://127.0.0.1:7890;;
 k2p) T=/etc/storage/ShellCrash; R=/tmp/sc-admin; input=$R/native-source; output=$R/sub.raw; . "$T/starts/panel_env.sh"; proxy=http://$PANEL_LAN_IP:7890;;
 *) exit 2;;
esac
diagnostic(){
 tail -n 29 "$R/subscription-tool.log" > "$R/subscription-tool.log.new" 2>/dev/null || true
 printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$R/subscription-tool.log.new"
 mv "$R/subscription-tool.log.new" "$R/subscription-tool.log"
}
case "$mode" in direct|convert) ;; *) exit 2;; esac
servers=$T/configs/servers.list
[ -s "$servers" ] || servers=$T/servers.list
[ -f "$T/starts/core_config.sh" ] && [ -s "$servers" ] || exit 1
diagnostic "ShellCrash subscription: mode=$mode, staging"
work=$R/subscription-tool.$$
mkdir "$work" || exit 1
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$work/configs" "$work/starts" "$work/jsons" "$work/tmp"
cp "$T/configs/ShellCrash.cfg" "$work/configs/"
cp "$servers" "$work/configs/servers.list"
cp -r "$T/libs" "$work/libs"
export CRASHDIR=$work
TMPDIR=$work/tmp
. "$CRASHDIR/configs/ShellCrash.cfg"
crashcore=singbox
core_v=1.12.13
. "$T/starts/core_config.sh"
# The installed check_target is bridged to the live adapter: override for this sandbox.
target=singbox
format=json
core_config=$work/jsons/config.json
Url=''; Https=''
url=$(cat "$input")
case "$url" in http://*|https://*) ;; *) exit 2;; esac
if [ "$mode" = convert ];then Url=$url;else Https=$url;fi
logger(){ :; }
ckcmd(){ command -v "$1" >/dev/null 2>&1; }
# A failed request must not send private subscriptions to another converter automatically.
ca=''
if [ "$platform" = k2p ];then
 ca=$work/ca.pem
 cat /etc/ssl/certs/*.crt "$T/configs/subscription-ca.pem" > "$ca" 2>/dev/null || true
fi
webget(){
 curl -4 -fsSL ${ca:+--cacert "$ca"} --proxy "$proxy" --noproxy '' --connect-timeout 5 --max-time 18 --max-filesize 262144 "$2" -o "$1" 2>/dev/null ||
 curl -4 -fsSL ${ca:+--cacert "$ca"} --noproxy '*' --connect-timeout 5 --max-time 18 --max-filesize 262144 "$2" -o "$1" 2>/dev/null || { code=$?;diagnostic "ShellCrash subscription: curl=$code, live config retained, converter unchanged";exit 1; }
}
# Tool validates its output, while the adapter performs the final core compatibility check.
cat > "$work/starts/singbox_config_check.sh" <<'CHECK'
check_config(){
 [ -s "$core_config_new" ] && [ "$(wc -c < "$core_config_new")" -le 262144 ] || exit 1
 if [ "$SC_SUB_MODE" = convert ];then
  grep -q '"outbounds"' "$core_config_new" || { diagnostic 'ShellCrash conversion: missing outbounds, live config retained';exit 1; }
 fi
}
CHECK
export SC_SUB_MODE=$mode
# Upstream prints subscription URLs: never persist its diagnostic output.
if ! get_core_config >/dev/null 2>&1;then exit 1;fi
[ -s "$core_config" ] || exit 1
cp "$core_config" "$output.new"
mv "$output.new" "$output"
diagnostic "ShellCrash subscription: candidate retrieved; awaiting parser and core validation"
