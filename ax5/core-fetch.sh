#!/bin/sh
set -e
export CRASHDIR=/data/ShellCrash-tool
. "$CRASHDIR/configs/ShellCrash.cfg"
. "$CRASHDIR/configs/command.env"
. "$CRASHDIR/libs/web_get_bin.sh"
. /data/ShellCrash/ax5/core-env.sh
wanted=$1
case "$wanted" in meta) path=bin/meta/clash-linux-armv7.tar.gz;; singbox) path=bin/singbox/singbox-linux-armv7.tar.gz;; *) echo 'AX5 currently supports sing-box and mihomo tar.gz.' >&2;exit 2;; esac
# Use ShellCrash's own small version file; no separate GitHub API or binary search.
latest=$("$C/ax5/core-source.sh" version "$wanted") || latest=''
if [ "$wanted" = "$KIND" ] && [ -n "$latest" ] && [ "${latest#v}" = "${VERSION#v}" ] && "$C/ax5/verify-core.sh"; then
 echo 'Current core already matches the ShellCrash source.'
 exit 0
fi
pinned=$("$C/ax5/core-source.sh" resolve "$wanted")
previous=$(lua -e 'local M=dofile("/data/ShellCrash/ax5/common.lua"); print(M.pid()>0 and 1 or 0)')
finish() {
 code=$?
 trap - EXIT INT TERM
 rm -f "$TMPDIR/Coretmp.tar.gz"
 if [ "$previous" = 1 ] && ! lua -e 'local M=dofile("/data/ShellCrash/ax5/common.lua");os.exit(M.pid()>0 and 0 or 1)';then /etc/init.d/shellcrash start || code=1;fi
 exit "$code"
}
trap finish EXIT
trap 'exit 1' INT TERM
# Stop before downloading into tmpfs and free the old executable. The verified local
# package remains available, so a failed download can restart the previous core.
"$C/ax5/verify-core.sh"
if [ "$previous" = 1 ];then
 /etc/init.d/shellcrash stop
 for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15;do
  if lua -e 'local M=dofile("/data/ShellCrash/ax5/common.lua");os.exit(M.pid()==0 and 0 or 1)';then break;fi
  sleep 1
 done
 lua -e 'local M=dofile("/data/ShellCrash/ax5/common.lua");os.exit(M.pid()==0 and 0 or 1)'
 rm -f "$R/CrashCore"
fi
SC_PINNED_SOURCE="$pinned" "$C/ax5/core-source.sh" fetch "$wanted" "$TMPDIR/Coretmp.tar.gz"
bin_url=$(cat "$TMPDIR/core-download-url")
SC_PREVIOUSLY_RUNNING="$previous" "$C/ax5/core-install.sh" "$TMPDIR/Coretmp.tar.gz" "$wanted" "$bin_url"
