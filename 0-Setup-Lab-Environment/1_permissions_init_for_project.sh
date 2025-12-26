#!/bin/bash
#================================================================
# Docker Compose Permission Init Script
#
# Purpose: Set up proper permissions for Traefik and Loki
# - Traefik acme.json must be 600 (read/write owner only)
# - Loki data directory must be owned by UID/GID 10001
#
# Note: Does not require running as root. Uses sudo only for
# the chown operation to set ownership to UID 10001.
#================================================================

#================================================================
# Configuration
#================================================================
ACME_FILE="./traefik/acme.json"
LOKI_DATA_DIR="./loki/data"
LOKI_UID=10001
LOKI_GID=10001

echo "=========================================="
echo "Docker Compose Permission Init Script"
echo "=========================================="

#================================================================
# 1. TRAEFIK - acme.json must be 600
#================================================================
echo ""
echo "[1/2] Checking Traefik acme.json..."

# Remove directory if it exists where the file should be
if [ -d "$ACME_FILE" ]; then
  echo "$ACME_FILE is a directory. Removing it..."
  rmdir "$ACME_FILE" 2>/dev/null || rm -rf "$ACME_FILE"
fi

# Check if acme.json exists
if [ -f "$ACME_FILE" ]; then
  echo "$ACME_FILE exists."

  # Check current permissions
  PERMISSIONS=$(stat -c %a "$ACME_FILE")

  # Set to 600 if not already
  if [ "$PERMISSIONS" -ne 600 ]; then
    echo "Setting permissions to 600..."
    chmod 600 "$ACME_FILE"
    echo "Done."
  else
    echo "Permissions already 600."
  fi
else
  # Create acme.json with proper permissions
  echo "Creating $ACME_FILE..."
  mkdir -p "$(dirname "$ACME_FILE")"
  touch "$ACME_FILE"
  chmod 600 "$ACME_FILE"
  echo "Done."
fi

#================================================================
# 2. LOKI - data directory must be owned by UID 10001
#================================================================
echo ""
echo "[2/2] Checking Loki data directory..."

# Create main data directory if it doesn't exist
if [ -d "$LOKI_DATA_DIR" ]; then
    echo "$LOKI_DATA_DIR exists."
else
    echo "Creating $LOKI_DATA_DIR..."
    mkdir -p "$LOKI_DATA_DIR"
fi

# Create required subdirectories for Loki
echo "Creating Loki subdirectories..."
mkdir -p "$LOKI_DATA_DIR/rules"
mkdir -p "$LOKI_DATA_DIR/chunks"
mkdir -p "$LOKI_DATA_DIR/wal"

# Get current ownership
CURRENT_UID=$(stat -c %u "$LOKI_DATA_DIR")
CURRENT_GID=$(stat -c %g "$LOKI_DATA_DIR")

# Change ownership to Loki UID/GID if needed
# Loki container runs as UID 10001 and needs to write to this directory
if [ "$CURRENT_UID" -ne "$LOKI_UID" ] || [ "$CURRENT_GID" -ne "$LOKI_GID" ]; then
    echo "Setting ownership to $LOKI_UID:$LOKI_GID..."
    sudo chown -R "$LOKI_UID:$LOKI_GID" "$LOKI_DATA_DIR"
    sudo chmod -R 755 "$LOKI_DATA_DIR"
    echo "Done."
else
    echo "Ownership already correct."
fi

#================================================================
# Complete
#================================================================
echo ""
echo "All permissions configured."
echo ""
