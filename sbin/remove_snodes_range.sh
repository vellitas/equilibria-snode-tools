#!/usr/bin/env bash
set -euo pipefail

# remove_snodes_range.sh
#
# Removes Equilibria service-node systemd units + linux users + home dirs for a numeric snode range.
#
# DEFAULT BEHAVIOR: DRY RUN (no changes).
#
# USAGE:
#   sudo /usr/local/sbin/remove_snodes_range.sh
#       - dry run with defaults START=82 END=90
#
#   sudo START=82 END=90 /usr/local/sbin/remove_snodes_range.sh
#       - dry run for a specific range
#
#   sudo APPLY=1 START=82 END=90 /usr/local/sbin/remove_snodes_range.sh
#       - actually delete for that range
#
# OPTIONAL SAFETY:
#   KEEP="82 83 90"   -> skip those numbers
#   KEEP_USERS="snode5 snode17" -> skip by explicit user name
#
# EXAMPLES:
#   sudo START=82 END=90 /usr/local/sbin/remove_snodes_range.sh
#   sudo APPLY=1 START=82 END=90 /usr/local/sbin/remove_snodes_range.sh
#   sudo APPLY=1 START=1 END=90 KEEP="1 2 3" /usr/local/sbin/remove_snodes_range.sh
#
# NOTES:
# - This script ONLY targets snode<N> (numeric). It will NOT touch "snode" (no number).
# - It assumes systemd unit name pattern: eqnode_snode<N>.service
# - It removes:
#     * systemd unit file /etc/systemd/system/eqnode_snode<N>.service (if present)
#     * drop-ins /etc/systemd/system/eqnode_snode<N>.service.d/ (if present)
#     * sudoers snippets /etc/sudoers.d/snode<N> and /etc/sudoers.d/snode<N>.conf (if present)
#     * linux user snode<N> (userdel -r)
#     * /home/snode<N> if still present
#
# CHECKING SUCCESS (after APPLY=1):
#   1) Units gone:
#      systemctl list-unit-files 'eqnode_snode*.service' --no-legend | egrep 'snode(8[2-9]|90)\.service' || echo "OK: units removed"
#   2) Users gone:
#      getent passwd snode82 snode83 snode84 snode85 snode86 snode87 snode88 snode89 snode90 || echo "OK: users removed"
#   3) Homes gone:
#      ls -ld /home/snode8* /home/snode90 2>/dev/null || echo "OK: home dirs removed"
#
# TIP: Capture output:
#   sudo APPLY=1 START=82 END=90 /usr/local/sbin/remove_snodes_range.sh | tee /root/remove_snodes_82_90.log

START="${START:-82}"
END="${END:-90}"
APPLY="${APPLY:-0}"
KEEP="${KEEP:-}"
KEEP_USERS="${KEEP_USERS:-}"

say() { echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"; }

die() { say "ERROR: $*"; exit 1; }

is_number() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }

in_list_num() {
  local needle="$1"; shift || true
  local x
  for x in $KEEP; do
    [[ "$x" == "$needle" ]] && return 0
  done
  return 1
}

in_list_user() {
  local needle="$1"
  local x
  for x in $KEEP_USERS; do
    [[ "$x" == "$needle" ]] && return 0
  done
  return 1
}

run() {
  if [[ "$APPLY" == "1" ]]; then
    say "RUN: $*"
    "$@"
  else
    say "DRY: $*"
  fi
}

unit_for() { echo "eqnode_${1}.service"; }   # snode82 -> eqnode_snode82.service

exists_user() { id "$1" &>/dev/null; }

# -------------------- banner / usage summary --------------------
say "remove_snodes_range: Starting"
say "  START=$START END=$END APPLY=$APPLY"
if [[ "$APPLY" != "1" ]]; then
  say "  Mode: DRY RUN (no changes). To delete, re-run with APPLY=1"
else
  say "  Mode: APPLY (will delete)."
fi
[[ -n "$KEEP" ]] && say "  KEEP numbers: $KEEP"
[[ -n "$KEEP_USERS" ]] && say "  KEEP users:   $KEEP_USERS"
say "  Targets are ONLY numeric users: snode<NUMBER> (e.g., snode82)."
say "  'snode' (no number) is never targeted."

# -------------------- validation --------------------
is_number "$START" || die "START must be numeric"
is_number "$END" || die "END must be numeric"
(( START >= 1 )) || die "START must be >= 1"
(( END >= START )) || die "END must be >= START"

say "Planned actions per node:"
say "  - disable --now eqnode_snode<N>.service (if present)"
say "  - remove unit file and drop-in directory (if present)"
say "  - kill remaining processes owned by snode<N> (if any)"
say "  - userdel -r snode<N> (removes home + mail spool)"
say "  - remove /home/snode<N> if still present"
say "  - daemon-reload + reset-failed at end"
echo

# -------------------- main loop --------------------
for n in $(seq "$START" "$END"); do
  if in_list_num "$n"; then
    say "---- snode${n} ----"
    say "SKIP: in KEEP list"
    continue
  fi

  u="snode${n}"
  if in_list_user "$u"; then
    say "---- ${u} ----"
    say "SKIP: in KEEP_USERS list"
    continue
  fi

  unit="$(unit_for "$u")"
  unit_path="/etc/systemd/system/${unit}"
  dropin_dir="/etc/systemd/system/${unit}.d"
  home_dir="/home/${u}"

  say "---- ${u} ----"
  say "unit=${unit}"

  # Stop/disable service if it exists (loaded or not)
  if systemctl list-units --all --no-legend "$unit" &>/dev/null; then
    run systemctl disable --now "$unit" || true
  else
    say "INFO: unit not loaded: $unit"
  fi

  # Remove systemd unit artifacts
  if [[ -f "$unit_path" ]]; then
    run rm -f "$unit_path"
  else
    say "INFO: no unit file: $unit_path"
  fi
  if [[ -d "$dropin_dir" ]]; then
    run rm -rf "$dropin_dir"
  else
    say "INFO: no drop-in dir: $dropin_dir"
  fi

  # Remove sudoers snippets if present
  [[ -f "/etc/sudoers.d/${u}" ]] && run rm -f "/etc/sudoers.d/${u}"
  [[ -f "/etc/sudoers.d/${u}.conf" ]] && run rm -f "/etc/sudoers.d/${u}.conf"

  # Kill any remaining processes owned by the user
  if exists_user "$u"; then
    if pgrep -u "$u" &>/dev/null; then
      run pkill -KILL -u "$u" || true
    else
      say "INFO: no processes for user $u"
    fi
  else
    say "INFO: user does not exist: $u"
  fi

  # Remove the user (and home)
  if exists_user "$u"; then
    run userdel -r "$u" || true
  fi

  # If the home dir still exists, remove it
  if [[ -d "$home_dir" ]]; then
    run rm -rf "$home_dir"
  else
    say "INFO: home dir not found: $home_dir"
  fi

  echo
done

# Reload systemd and clear failed units
run systemctl daemon-reload
run systemctl reset-failed

say "remove_snodes_range: Done."
echo
say "HOW TO CHECK FOR SUCCESS (after APPLY=1):"
say "  1) Units removed for the range:"
say "     systemctl list-unit-files 'eqnode_snode*.service' --no-legend | awk '{print \$1}' | egrep \"snode(${START}|${END}|[0-9]+)\""
say "     (or spot-check one): systemctl status eqnode_snode${START}.service"
say "  2) Users removed:"
say "     getent passwd snode${START} snode${END} || echo 'OK: no passwd entries'"
say "  3) Home dirs removed:"
say "     ls -ld /home/snode${START} /home/snode${END} 2>/dev/null || echo 'OK: no home dirs'"
say "  4) No processes left:"
say "     pgrep -a -u snode${START} 2>/dev/null || echo 'OK: no processes'"
