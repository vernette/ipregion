#!/usr/bin/env bash

# Stands in for curl in tests (setup links it as curl into PATH): serves saved responses from $FAKE_CURL_FIXTURES/ipv4|ipv6/<url without scheme, unsafe chars as _>
# with optional <name>.code, <name>.redirect, <name>.exit and <name>.delay next to the body.
# Without -4 / -6 (requests through a proxy) ipv6 fixtures win, like a dual-stack proxy that prefers IPv6.

set -euo pipefail

readonly DEFAULT_CODE=200
readonly FAILED_CODE="000"
readonly CURL_EXIT_CONNECT=7

: "${FAKE_CURL_FIXTURES:?FAKE_CURL_FIXTURES is not set}"

ip_version=""
output="/dev/null"
write_out=""
url="${!#}"

if [[ -n "${FAKE_CURL_LOG:-}" ]]; then
  printf '%s\n' "$*" >>"$FAKE_CURL_LOG"
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -4 | -6)
      ip_version="${1#-}"
      shift
      ;;
    --output)
      output="$2"
      shift 2
      ;;
    --write-out)
      write_out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

name="${url#*://}"
name="${name//[^A-Za-z0-9._-]/_}"

if [[ -z "$ip_version" ]]; then
  ip_version=4
  if [[ -e "$FAKE_CURL_FIXTURES/ipv6/$name" || -e "$FAKE_CURL_FIXTURES/ipv6/$name.exit" ]]; then
    ip_version=6
  fi
fi

fixture="$FAKE_CURL_FIXTURES/ipv$ip_version/$name"
delay="${FAKE_CURL_DELAY:-0}"
code="$DEFAULT_CODE"
redirect=""
exit_code=0

if [[ -f "$fixture.delay" ]]; then
  delay=$(<"$fixture.delay")
fi

sleep "$delay"

if [[ -f "$fixture.code" ]]; then
  code=$(<"$fixture.code")
fi

if [[ -f "$fixture.redirect" ]]; then
  redirect=$(<"$fixture.redirect")
fi

if [[ -f "$fixture.exit" ]]; then
  exit_code=$(<"$fixture.exit")
fi

if [[ ! -f "$fixture" && ! -f "$fixture.exit" ]]; then
  printf 'fake curl: no fixture %s\n' "$fixture" >&2
  exit_code="$CURL_EXIT_CONNECT"
fi

if [[ "$exit_code" -ne 0 ]]; then
  code="$FAILED_CODE"
fi

if [[ -f "$fixture" && "$exit_code" -eq 0 ]]; then
  cp -- "$fixture" "$output"
fi

write_out="${write_out//'%{http_code}'/$code}"
printf '%b' "${write_out//'%{redirect_url}'/$redirect}"
exit "$exit_code"
