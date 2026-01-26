#!/usr/bin/env bash

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to run tests."
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT_DIR/ipregion.sh"

failures=0

assert_eq() {
  local expected="$1"
  local actual="$2"
  local name="$3"

  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $name (expected: '$expected', got: '$actual')"
    failures=$((failures + 1))
  else
    echo "OK: $name"
  fi
}

assert_true() {
  local name="$1"
  shift

  if ! "$@"; then
    echo "FAIL: $name"
    failures=$((failures + 1))
  else
    echo "OK: $name"
  fi
}

assert_false() {
  local name="$1"
  shift

  if "$@"; then
    echo "FAIL: $name"
    failures=$((failures + 1))
  else
    echo "OK: $name"
  fi
}

assert_empty() {
  local value="$1"
  local name="$2"

  if [[ -n "$value" ]]; then
    echo "FAIL: $name (expected empty, got: '$value')"
    failures=$((failures + 1))
  else
    echo "OK: $name"
  fi
}

assert_true "is_valid_ipv4 accepts valid value" is_valid_ipv4 "1.2.3.4"
assert_false "is_valid_ipv4 rejects invalid value" is_valid_ipv4 "256.1.1.1"
assert_false "is_valid_ipv4 rejects short value" is_valid_ipv4 "1.2.3"

assert_true "is_valid_ipv6 accepts valid value" is_valid_ipv6 "2001:db8::1"
assert_false "is_valid_ipv6 rejects invalid value" is_valid_ipv6 "not-an-ip"

assert_eq "1" "$(process_json '{"a":1}' '.a')" "process_json returns value from valid JSON"
assert_empty "$(process_json "" ".a")" "process_json returns empty on empty input"
assert_empty "$(process_json "{invalid-json}" ".a")" "process_json returns empty on invalid input"

if [[ "$failures" -gt 0 ]]; then
  echo "$failures test(s) failed."
  exit 1
fi

echo "All tests passed."
