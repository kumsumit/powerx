#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${COLLABORA_REPO_URL:-https://github.com/CollaboraOnline/online.mirror.git}"
BRANCH="${COLLABORA_BRANCH:-distro/collabora/co-25.04}"
DEST="${COLLABORA_SOURCE_DIR:-$PWD/.engine/collabora-online}"

if [[ -d "$DEST/.git" ]]; then
  echo "Updating Collabora source in $DEST"
  git -C "$DEST" fetch --depth=1 origin "$BRANCH"
  git -C "$DEST" checkout FETCH_HEAD
else
  echo "Cloning Collabora source into $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --filter=blob:none --depth=1 --branch "$BRANCH" "$REPO_URL" "$DEST"
fi

echo
echo "Collabora source ready: $DEST"
echo "Branch/ref: $BRANCH"
