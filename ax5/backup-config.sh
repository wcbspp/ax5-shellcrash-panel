#!/bin/sh
set -eu
C=/data/ShellCrash
R=/tmp/ShellCrash
umask 077
file="$R/config-backup.tar.gz"
trap 'rm -f "$file"' EXIT
# Private receiver path only; no configuration or identity is published over HTTP.
tar -czf "$file" -C "$C" configs ruleset cache/core.env cache/core.sha256
if "$C/ax5/mirror-upload.sh" backup "$file" tar.gz > "$R/backup-sha"; then
 date +%s > "$C/configs/backup-time"
 rm -f "$C/configs/backup-pending"
else
 date +%s > "$C/configs/backup-pending"
 exit 1
fi
