#!/usr/bin/env bash
# Installs signal-cli (https://github.com/AsamK/signal-cli), a commandline
# client for the Signal messenger.
#
# Scope note: this only gets the `signal-cli` binary present and on PATH.
# Hermes's own CLI (`hermes --help`) has no native `signal` gateway
# subcommand as of this writing (unlike telegram/whatsapp/whatsapp-cloud/
# slack), so installing this binary does NOT by itself wire Signal into
# Hermes's messaging gateway. signal-cli's own docs describe its primary
# use case as one-way admin notifications from a server (daemon mode /
# JSON-RPC) — the intended integration point here is a future custom skill
# or cron job shelling out to `signal-cli send`, not a two-way gateway
# platform. See docs/open-questions.md for the open question this leaves.
#
# Registering an account (a phone number plus an SMS/voice verification
# code) is a manual, interactive, one-time step that requires a live code
# from Signal — this script deliberately does not attempt it. Instructions
# are printed at the end.
set -euo pipefail

if command -v signal-cli >/dev/null 2>&1; then
  echo "  - signal-cli already installed ($(signal-cli --version 2>/dev/null || echo 'version unknown')); skipping"
else
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "  ! No apt-get on this host (not Debian/Ubuntu?). Install signal-cli" >&2
    echo "    manually: https://github.com/AsamK/signal-cli/wiki/Quickstart" >&2
    exit 0
  fi

  # shellcheck source=overlay/install/lib-apt-ipv4-fallback.sh
  source "$(dirname "${BASH_SOURCE[0]}")/lib-apt-ipv4-fallback.sh"

  # signal-cli's JVM build needs a real JRE (upstream states >=25). Debian/
  # Ubuntu package naming for very recent JDKs varies by release; try the
  # version-specific package first, then fall back to whatever the distro
  # currently calls "default".
  if ! command -v java >/dev/null 2>&1; then
    echo "  - Installing Java runtime (signal-cli dependency)"
    hpa_apt_update_with_ipv4_fallback
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-25-jre-headless 2>/dev/null; then
      echo "  ! openjdk-25-jre-headless not available via apt on this release;" >&2
      echo "    falling back to default-jre-headless (may be older than 25)." >&2
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y default-jre-headless
    fi
  fi
  JAVA_MAJOR="$(java -version 2>&1 | head -1 | grep -oE '"[0-9]+' | tr -d '"' || echo 0)"
  if [[ "$JAVA_MAJOR" -lt 25 ]]; then
    echo "  ! Warning: detected Java version ${JAVA_MAJOR:-unknown}; signal-cli wants >=25." >&2
    echo "    signal-cli may fail to run. See https://github.com/AsamK/signal-cli#installation" >&2
  fi

  echo "  - Installing signal-cli"
  SIGNAL_CLI_VERSION="${HPA_SIGNAL_CLI_VERSION:-}"
  if [[ -z "$SIGNAL_CLI_VERSION" ]]; then
    SIGNAL_CLI_VERSION="$(curl -Ls -o /dev/null -w '%{url_effective}' \
      https://github.com/AsamK/signal-cli/releases/latest | sed 's#.*/v##')"
  fi
  if [[ -z "$SIGNAL_CLI_VERSION" ]]; then
    echo "  ! Could not determine latest signal-cli version (network issue?)." >&2
    echo "    Retry, or set HPA_SIGNAL_CLI_VERSION=<version> to skip auto-detection." >&2
    exit 1
  fi

  TMP_TAR="$(mktemp --suffix=.tar.gz)"
  trap 'rm -f "$TMP_TAR"' EXIT
  curl -fL -o "$TMP_TAR" \
    "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}.tar.gz"
  sudo tar xf "$TMP_TAR" -C /opt
  sudo ln -sf "/opt/signal-cli-${SIGNAL_CLI_VERSION}/bin/signal-cli" /usr/local/bin/signal-cli
  echo "  - signal-cli ${SIGNAL_CLI_VERSION} installed ($(signal-cli --version 2>/dev/null || echo 'version unknown'))"
fi

echo "  - signal-cli is installed but NOT registered to an account yet (manual, one-time step):"
echo "      signal-cli -a +<COUNTRYCODE_AND_NUMBER> register"
echo "      signal-cli -a +<COUNTRYCODE_AND_NUMBER> verify <CODE_FROM_SMS_OR_CALL>"
echo "    See: https://github.com/AsamK/signal-cli/wiki/Quickstart"
