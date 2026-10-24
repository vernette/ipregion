#!/usr/bin/env bash

# Shows how GeoIP databases, popular platforms, CDNs and AI services see this host over IPv4 and IPv6.

set -euo pipefail
shopt -s extglob

readonly SCRIPT_NAME="ipregion.sh"
readonly SCRIPT_URL="https://github.com/vernette/ipregion"
readonly SERVICE_GROUPS=(platforms cdn availability ai geoip)
readonly ALL_GROUPS="all"
readonly DEFAULT_TIMEOUT=5
readonly TIMEOUT_PATTERN='^[1-9][0-9]*$'
readonly PROXY_PATTERN='^([^:/[:space:]]+|\[[0-9A-Fa-f:]+\]):[0-9]{1,5}$'
readonly COUNTRY_CODE_PATTERN='^[A-Z]{2}$'
readonly REGIONAL_INDICATOR_A=0x1F1E6
readonly ASCII_A=65

readonly STATUS_YES="yes"
readonly STATUS_NO="no"
readonly STATUS_IPBLOCK="ipblock"
readonly STATUS_NONE="none"
readonly SYMBOL_YES="✓"
readonly SYMBOL_NO="✗"
readonly SYMBOL_IPBLOCK="⊘"
readonly SYMBOL_UNKNOWN="?"
readonly SYMBOL_NONE="-"

readonly CURL_BASE_ARGS=(--disable --silent --compressed)
readonly CURL_WRITE_OUT='%{http_code}\n%{redirect_url}\n'
readonly CACHE_POLL_INTERVAL=0.1

readonly CURL_EXIT_OK=0
readonly CURL_EXIT_DNS=6
readonly CURL_EXIT_CONNECT=7
readonly CURL_EXIT_TIMEOUT=28
readonly CURL_EXIT_TLS_HANDSHAKE=35
readonly CURL_EXIT_TLS_CERTIFICATE=60
readonly CURL_EXIT_PROXY=97
readonly HTTP_FORBIDDEN=403
readonly HTTP_TOO_MANY_REQUESTS=429

readonly REASON_DNS="DNS error"
readonly REASON_CONNECT="connection failed"
readonly REASON_TIMEOUT="timeout"
readonly REASON_TLS="TLS error"
readonly REASON_PROXY="proxy error"
readonly REASON_NETWORK="network error"
readonly REASON_FORBIDDEN="access denied"
readonly REASON_RATE_LIMITED="rate limited"
readonly REASON_SERVER_ERROR="server error"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  readonly C_VALUE=$'\033[1m'
  readonly C_DIM=$'\033[0;90m'
  readonly C_YES=$'\033[1;32m'
  readonly C_NO=$'\033[1;31m'
  readonly C_WARN=$'\033[1;33m'
  readonly C_RESET=$'\033[0m'
else
  readonly C_VALUE=""
  readonly C_DIM=""
  readonly C_YES=""
  readonly C_NO=""
  readonly C_WARN=""
  readonly C_RESET=""
fi

VERBOSE=false
DEBUG=false
JSON_OUTPUT=false
SELECTED_GROUP="$ALL_GROUPS"
CURL_TIMEOUT="$DEFAULT_TIMEOUT"
IPV4_ONLY=false
IPV6_ONLY=false
PROXY_ADDR=""
INTERFACE_NAME=""
SHOW_EMOJI=false
GEOIP_BREAKDOWN=false
VERDICT=""
WORK_DIR=""

die() {
  local message="$1"

  printf 'Error: %s\n' "$message" >&2
  printf 'Run %s --help for usage\n' "$SCRIPT_NAME" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Shows how GeoIP databases, popular platforms, CDNs and AI services see this
host over IPv4 and IPv6.

Options:
  -h, --help             Show this help and exit
  -v, --verbose          Log every step to stderr
  -d, --debug            Save a full trace to a file and upload it to 0x0.st
  -j, --json             Print results as JSON
  -g, --group GROUP      Check one group: ${SERVICE_GROUPS[*]} (default: $ALL_GROUPS)
  -t, --timeout SEC      Request timeout in seconds (default: $DEFAULT_TIMEOUT)
  -4, --ipv4             Check IPv4 only
  -6, --ipv6             Check IPv6 only
  -p, --proxy HOST:PORT  Send requests through a SOCKS5 proxy
  -i, --interface IFACE  Send requests through a network interface
      --emoji            Show country flags next to country codes
      --geoip-breakdown  Show every GeoIP service instead of the summary

More: $SCRIPT_URL
EOF
}

require_option_value() {
  local option="$1"
  local remaining="$2"

  if ((remaining < 2)); then
    die "option $option requires a value"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --verbose)
        VERBOSE=true
        shift
        ;;
      -d | --debug)
        DEBUG=true
        shift
        ;;
      -j | --json)
        JSON_OUTPUT=true
        shift
        ;;
      -g | --group)
        require_option_value "$1" "$#"
        SELECTED_GROUP="$2"
        shift 2
        ;;
      -t | --timeout)
        require_option_value "$1" "$#"
        CURL_TIMEOUT="$2"
        shift 2
        ;;
      -4 | --ipv4)
        IPV4_ONLY=true
        shift
        ;;
      -6 | --ipv6)
        IPV6_ONLY=true
        shift
        ;;
      -p | --proxy)
        require_option_value "$1" "$#"
        PROXY_ADDR="$2"
        shift 2
        ;;
      -i | --interface)
        require_option_value "$1" "$#"
        INTERFACE_NAME="$2"
        shift 2
        ;;
      --emoji)
        SHOW_EMOJI=true
        shift
        ;;
      --geoip-breakdown)
        GEOIP_BREAKDOWN=true
        shift
        ;;
      *)
        die "unknown option $1"
        ;;
    esac
  done
}

is_known_group() {
  local group="$1"
  local known

  if [[ "$group" == "$ALL_GROUPS" ]]; then
    return 0
  fi

  for known in "${SERVICE_GROUPS[@]}"; do
    if [[ "$group" == "$known" ]]; then
      return 0
    fi
  done

  return 1
}

validate_args() {
  if ! is_known_group "$SELECTED_GROUP"; then
    die "unknown group $SELECTED_GROUP, expected one of: ${SERVICE_GROUPS[*]} $ALL_GROUPS"
  fi

  if [[ ! "$CURL_TIMEOUT" =~ $TIMEOUT_PATTERN ]]; then
    die "invalid timeout $CURL_TIMEOUT, expected a positive integer"
  fi

  if [[ "$IPV4_ONLY" == true && "$IPV6_ONLY" == true ]]; then
    die "options --ipv4 and --ipv6 cannot be used together"
  fi

  if [[ -n "$PROXY_ADDR" && ! "$PROXY_ADDR" =~ $PROXY_PATTERN ]]; then
    die "invalid proxy $PROXY_ADDR, expected HOST:PORT"
  fi
}

visible_length() {
  local text="$1"
  local plain="${text//$'\033'\[+([0-9;])m/}"

  printf '%d' "${#plain}"
}

pad() {
  local text="$1"
  local width="$2"
  local fill

  fill=$((width - $(visible_length "$text")))
  if ((fill < 0)); then
    fill=0
  fi

  printf '%s%*s' "$text" "$fill" ''
}

paint() {
  local color="$1"
  local text="$2"

  printf '%s%s%s' "$color" "$text" "$C_RESET"
}

format_flag() {
  local country="$1"
  local first=$((REGIONAL_INDICATOR_A + $(printf '%d' "'${country:0:1}") - ASCII_A))
  local second=$((REGIONAL_INDICATOR_A + $(printf '%d' "'${country:1:1}") - ASCII_A))

  printf '%b' "\\U$(printf '%08X' "$first")\\U$(printf '%08X' "$second")"
}

label_country() {
  local country="$1"

  if [[ "$SHOW_EMOJI" != true || ! "$country" =~ $COUNTRY_CODE_PATTERN ]]; then
    printf '%s' "$country"
    return
  fi

  printf '%s %s' "$(format_flag "$country")" "$country"
}

format_country() {
  local country="$1"
  local width="$2"

  if [[ -z "$country" ]]; then
    paint "$C_DIM" "$(pad "$SYMBOL_UNKNOWN" "$width")"
    return
  fi

  if [[ "$country" == "$VERDICT" ]]; then
    paint "$C_VALUE" "$(pad "$(label_country "$country")" "$width")"
    return
  fi

  paint "$C_WARN" "$(pad "$(label_country "$country")" "$width")"
}

format_status() {
  local status="$1"
  local width="$2"

  case "$status" in
    "$STATUS_YES") paint "$C_YES" "$(pad "$SYMBOL_YES" "$width")" ;;
    "$STATUS_NO") paint "$C_NO" "$(pad "$SYMBOL_NO" "$width")" ;;
    "$STATUS_IPBLOCK") paint "$C_NO" "$(pad "$SYMBOL_IPBLOCK" "$width")" ;;
    "$STATUS_NONE") paint "$C_DIM" "$(pad "$SYMBOL_NONE" "$width")" ;;
    *) paint "$C_DIM" "$(pad "$SYMBOL_UNKNOWN" "$width")" ;;
  esac
}

cleanup() {
  if [[ -n "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi
}

create_work_dir() {
  WORK_DIR=$(mktemp -d)
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

request_cache_entry() {
  local key

  key=$(printf '%s\0' "$@" | cksum)
  printf '%s/http-%s' "$WORK_DIR" "${key// /-}"
}

fetch_to_cache() {
  local entry="$1"
  local ip_version="$2"
  local url="$3"
  shift 3
  local curl_exit=0
  local curl_args=(
    "${CURL_BASE_ARGS[@]}"
    "-$ip_version"
    --max-time "$CURL_TIMEOUT"
    --output "$entry.body"
    --write-out "$CURL_WRITE_OUT"
  )

  if [[ -n "$PROXY_ADDR" ]]; then
    curl_args+=(--proxy "socks5h://$PROXY_ADDR")
  fi

  if [[ -n "$INTERFACE_NAME" ]]; then
    curl_args+=(--interface "$INTERFACE_NAME")
  fi

  curl "${curl_args[@]}" "$@" "$url" >"$entry.meta" || curl_exit=$?
  printf '%s\n' "$curl_exit" >>"$entry.meta"
  touch -- "$entry.body"
  : >"$entry.done"
}

wait_for_cache_entry() {
  local entry="$1"

  while [[ ! -e "$entry.done" ]]; do
    sleep "$CACHE_POLL_INTERVAL"
  done
}

read_cache_entry() {
  local entry="$1"

  {
    read -r HTTP_CODE
    read -r HTTP_REDIRECT_URL
    read -r HTTP_CURL_EXIT
  } <"$entry.meta"
  HTTP_BODY=$(<"$entry.body")
}

http_request() {
  local ip_version="$1"
  local url="$2"
  shift 2
  local entry

  entry=$(request_cache_entry "$ip_version" "$url" "$@")
  if mkdir -- "$entry.lock" 2>/dev/null; then
    fetch_to_cache "$entry" "$ip_version" "$url" "$@"
  fi

  wait_for_cache_entry "$entry"
  read_cache_entry "$entry"
}

curl_failure_reason() {
  case "$HTTP_CURL_EXIT" in
    "$CURL_EXIT_DNS") printf '%s' "$REASON_DNS" ;;
    "$CURL_EXIT_CONNECT") printf '%s' "$REASON_CONNECT" ;;
    "$CURL_EXIT_TIMEOUT") printf '%s' "$REASON_TIMEOUT" ;;
    "$CURL_EXIT_TLS_HANDSHAKE" | "$CURL_EXIT_TLS_CERTIFICATE") printf '%s' "$REASON_TLS" ;;
    "$CURL_EXIT_PROXY") printf '%s' "$REASON_PROXY" ;;
    *) printf '%s' "$REASON_NETWORK" ;;
  esac
}

http_failure_reason() {
  if [[ "$HTTP_CURL_EXIT" != "$CURL_EXIT_OK" ]]; then
    curl_failure_reason
    return
  fi

  case "$HTTP_CODE" in
    "$HTTP_FORBIDDEN") printf '%s (%s)' "$REASON_FORBIDDEN" "$HTTP_CODE" ;;
    "$HTTP_TOO_MANY_REQUESTS") printf '%s (%s)' "$REASON_RATE_LIMITED" "$HTTP_CODE" ;;
    5[0-9][0-9]) printf '%s (%s)' "$REASON_SERVER_ERROR" "$HTTP_CODE" ;;
  esac
}

main() {
  parse_args "$@"
  validate_args
  create_work_dir
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
  main "$@"
fi
