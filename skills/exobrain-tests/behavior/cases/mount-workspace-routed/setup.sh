#!/usr/bin/env bash
# Plant the fx mount (lib/seed-mount.sh) so the agent has a mounted project to route into.
set -uo pipefail
source "$HARNESS_LIB/seed-mount.sh"
seed_mount "$1"
