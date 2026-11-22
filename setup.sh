#!/bin/sh
set -eu

cd "$(dirname "$0")"

if [ -e .env ] || [ -L .env ]; then
  echo "Error: .env already exists; remove it only if you want to regenerate it." >&2
  exit 1
fi

if ! render_group=$(getent group render); then
  echo "Error: could not find the render group." >&2
  exit 1
fi

render_gid=$(printf '%s\n' "$render_group" | cut -d: -f3)
case $render_gid in
  ''|*[!0-9]*)
    echo "Error: the render group has an invalid GID." >&2
    exit 1
    ;;
esac

printf 'RENDER_GID=%s\n' "$render_gid" > .env
echo "Created .env with RENDER_GID=$render_gid."
