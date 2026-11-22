#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/ai-server-setup.XXXXXX")
trap 'rm -f "$work_dir/setup.sh" "$work_dir/getent" "$work_dir/.env"; rmdir "$work_dir"' EXIT

cp "$repo_root/setup.sh" "$work_dir/setup.sh"
cat > "$work_dir/getent" <<'EOF'
#!/bin/sh
[ "$#" -eq 2 ] && [ "$1" = group ] && [ "$2" = render ] || exit 1
case $GROUP_RESULT in
  valid) printf 'render:x:105:\n' ;;
  missing) exit 2 ;;
  empty) printf 'render:x::\n' ;;
  invalid) printf 'render:x:not-a-gid:\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$work_dir/getent"

run_setup() {
  (cd / && GROUP_RESULT=$1 PATH="$work_dir:$PATH" sh "$work_dir/setup.sh")
}

expect_failure() {
  if output=$(run_setup "$1" 2>&1); then
    echo "Expected setup to fail for $1." >&2
    exit 1
  fi
  case $output in
    *"$2"*) ;;
    *) echo "Unexpected error for $1: $output" >&2; exit 1 ;;
  esac
}

run_setup valid
printf 'RENDER_GID=105\n' | cmp - "$work_dir/.env"

printf 'RENDER_GID=777\nOTHER_SETTING=keep\n' > "$work_dir/.env"
expect_failure valid '.env already exists'
printf 'RENDER_GID=777\nOTHER_SETTING=keep\n' | cmp - "$work_dir/.env"
rm "$work_dir/.env"

for result in missing empty invalid; do
  case $result in
    missing) expected_error='could not find the render group' ;;
    *) expected_error='invalid GID' ;;
  esac
  expect_failure "$result" "$expected_error"
  if [ -e "$work_dir/.env" ] || [ -L "$work_dir/.env" ]; then
    echo "Setup created .env for $result." >&2
    exit 1
  fi
done

echo "Setup tests passed."
