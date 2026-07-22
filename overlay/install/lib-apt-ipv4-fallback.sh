#!/usr/bin/env bash
# Shared helper: run `apt-get update`, and if it fails with the signature of
# a broken/absent IPv6 route (very common on home networks, some VPS/NAT
# setups, and USB-boot hardware), persist an IPv4-only override for apt and
# retry.
#
# Why persistent (an /etc/apt/apt.conf.d drop-in) rather than a one-off
# `apt-get update -o Acquire::ForceIPv4=true`: the *update* step isn't the
# only thing that breaks on a broken-IPv6 host — the subsequent
# `apt-get install` (fetching .deb files) hits the exact same "Network is
# unreachable" errors independently, since it's a separate apt invocation.
# A one-off flag on just the update call doesn't cover that. Writing the
# drop-in once makes every apt-get call for the rest of this script (and any
# future run of install.sh) IPv4-only automatically.
#
# Sourced by install.sh and overlay/install/00-install-prereqs.sh — both do
# `sudo apt-get update` as their first apt action, so this must be sourced
# before either of them.

HPA_APT_IPV4_DROPIN="/etc/apt/apt.conf.d/99-hpa-force-ipv4"

hpa_apt_update_with_ipv4_fallback() {
  local log
  log="$(mktemp)"
  # shellcheck disable=SC2064 (intentional early expansion of $log)
  trap "rm -f '$log'" RETURN

  if [[ -f "$HPA_APT_IPV4_DROPIN" ]]; then
    # Already diagnosed and fixed on a previous run of this script.
    sudo apt-get update
    return
  fi

  local status
  sudo apt-get update 2>&1 | tee "$log"
  status="${PIPESTATUS[0]}"

  if [[ "$status" -eq 0 ]] && ! grep -qE "Network is unreachable|Could not connect|Could not resolve|Connection timed out" "$log"; then
    return 0
  fi

  # Either apt-get update exited non-zero, or it exited 0 but the log shows
  # the broken-IPv6 signature (apt often warns rather than hard-failing on a
  # partial index fetch failure).
  if grep -qE "Network is unreachable|Could not connect|Could not resolve|Connection timed out" "$log"; then
    echo "  ! apt-get update hit network errors (looks like a broken/absent IPv6" >&2
    echo "    route to Ubuntu's mirrors). Forcing IPv4 for apt and retrying..." >&2
    echo 'Acquire::ForceIPv4 "true";' | sudo tee "$HPA_APT_IPV4_DROPIN" >/dev/null
    sudo apt-get update
  else
    # Some other failure (bad sources.list, disk full, etc.) — propagate the
    # original non-zero exit under set -e rather than masking it.
    return "$status"
  fi
}
