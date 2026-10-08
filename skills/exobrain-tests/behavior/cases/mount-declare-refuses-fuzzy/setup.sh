#!/usr/bin/env bash
# The fx mount is declared already, so mounts.json exists with one entry the agent must leave alone.
set -uo pipefail
source "$HARNESS_LIB/seed-mount.sh"
seed_mount "$1"
