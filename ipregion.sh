#!/usr/bin/env bash

# Shows how GeoIP databases, popular platforms, CDNs and AI services see this host over IPv4 and IPv6.

set -euo pipefail

readonly SCRIPT_NAME="ipregion.sh"
readonly SCRIPT_URL="https://github.com/vernette/ipregion"
readonly SERVICE_GROUPS=(platforms cdn availability ai geoip)
readonly ALL_GROUPS="all"
readonly DEFAULT_TIMEOUT=5
readonly TIMEOUT_PATTERN='^[1-9][0-9]*$'
readonly PROXY_PATTERN='^([^:/[:space:]]+|\[[0-9A-Fa-f:]+\]):[0-9]{1,5}$'

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

main() {
  parse_args "$@"
  validate_args
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
  main "$@"
fi
