#!/usr/bin/env bash
# Verifies and installs (or updates) monerod on x86_64 or aarch64 Linux using official
# getmonero.org archives verified against binaryfate's GPG key and SHA-256 hashes.txt.

set -euo pipefail

BINARYFATE_FPR="81AC591FE9C4B65C5806AFC3F0AF4D462A0BDF92"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)
    PLATFORM="linux64"
    ;;
  aarch64|arm64)
    PLATFORM="linuxarm8"
    ;;
  *)
    echo "Unsupported architecture: $ARCH (expected x86_64 or aarch64)" >&2
    exit 1
    ;;
esac

echo "[1/5] Fetching binaryfate release signing key and hashes.txt ..."
curl -fsSL "https://raw.githubusercontent.com/monero-project/monero/master/utils/gpg_keys/binaryfate.asc" -o "$WORK_DIR/binaryfate.asc"
gpg --batch --import "$WORK_DIR/binaryfate.asc"

curl -fsSL "https://www.getmonero.org/downloads/hashes.txt" -o "$WORK_DIR/hashes.txt"
gpg --batch --verify "$WORK_DIR/hashes.txt"

echo "[2/5] Downloading official Monero CLI archive for $PLATFORM ..."
curl -fL "https://downloads.getmonero.org/cli/${PLATFORM}" -o "$WORK_DIR/monero.tar.bz2"

ARCHIVE_SHA256="$(sha256sum "$WORK_DIR/monero.tar.bz2" | awk '{print $1}')"
if ! grep -qi "$ARCHIVE_SHA256" "$WORK_DIR/hashes.txt"; then
  echo "ERROR: SHA-256 hash ($ARCHIVE_SHA256) not found in GPG-verified hashes.txt! Aborting." >&2
  exit 1
fi
echo "Verified SHA-256: $ARCHIVE_SHA256"

echo "[3/5] Extracting monerod binary to /usr/local/bin/monerod ..."
tar -xjf "$WORK_DIR/monero.tar.bz2" -C "$WORK_DIR"
MONEROD_BIN="$(find "$WORK_DIR" -type f -name monerod | head -n 1)"
install -m 0755 -o root -g root "$MONEROD_BIN" /usr/local/bin/monerod

echo "[4/5] Ensuring unprivileged monero user and directories exist ..."
if ! id -u monero >/dev/null 2>&1; then
  useradd --system --home-dir /var/lib/monero --shell /usr/sbin/nologin monero
fi

install -d -m 0750 -o monero -g monero /var/lib/monero /var/log/monero
install -d -m 0755 -o root -g root /etc/monero

echo "[5/5] Done. Copy config/monerod-pruned.conf to /etc/monero/monerod.conf and systemd/monerod.service to /etc/systemd/system/."
