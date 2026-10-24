#!/usr/bin/env bats

setup() {
  # shellcheck disable=SC2154 # BATS_TEST_DIRNAME is set by bats
  SCRIPT="$BATS_TEST_DIRNAME/../ipregion.sh"
  # shellcheck source=../ipregion.sh
  source "$SCRIPT"
}

@test "help prints usage and exits with 0" {
  run bash "$SCRIPT" --help

  [[ "$status" -eq 0 ]]
  [[ "$output" == *"Usage: ipregion.sh"* ]]
  [[ "$output" == *"--geoip-breakdown"* ]]
}

@test "runs from process substitution and from a pipe" {
  run bash <(cat "$SCRIPT") --nope
  [[ "$output" == *"unknown option --nope"* ]]

  run bash -c 'bash -s -- --nope <"$1"' _ "$SCRIPT"
  [[ "$output" == *"unknown option --nope"* ]]
}

@test "no options keep defaults" {
  parse_args
  validate_args

  [[ "$SELECTED_GROUP" == all ]]
  [[ "$CURL_TIMEOUT" == "$DEFAULT_TIMEOUT" ]]
  [[ "$IPV4_ONLY" == false ]]
  [[ "$IPV6_ONLY" == false ]]
  [[ "$JSON_OUTPUT" == false ]]
  [[ -z "$PROXY_ADDR" ]]
}

@test "short options set every flag" {
  parse_args -v -d -j -g geoip -t 10 -4 -p 127.0.0.1:1080 -i eth1
  validate_args

  [[ "$VERBOSE" == true ]]
  [[ "$DEBUG" == true ]]
  [[ "$JSON_OUTPUT" == true ]]
  [[ "$SELECTED_GROUP" == geoip ]]
  [[ "$CURL_TIMEOUT" == 10 ]]
  [[ "$IPV4_ONLY" == true ]]
  [[ "$PROXY_ADDR" == 127.0.0.1:1080 ]]
  [[ "$INTERFACE_NAME" == eth1 ]]
}

@test "long options set every flag" {
  parse_args --verbose --debug --json --group ai --timeout 3 --ipv6 \
    --proxy '[::1]:1080' --interface wg0 --emoji --geoip-breakdown
  validate_args

  [[ "$VERBOSE" == true ]]
  [[ "$DEBUG" == true ]]
  [[ "$JSON_OUTPUT" == true ]]
  [[ "$SELECTED_GROUP" == ai ]]
  [[ "$CURL_TIMEOUT" == 3 ]]
  [[ "$IPV6_ONLY" == true ]]
  [[ "$PROXY_ADDR" == '[::1]:1080' ]]
  [[ "$INTERFACE_NAME" == wg0 ]]
  [[ "$SHOW_EMOJI" == true ]]
  [[ "$GEOIP_BREAKDOWN" == true ]]
}

@test "every group name is accepted" {
  local group

  for group in platforms cdn availability ai geoip all; do
    run bash "$SCRIPT" --group "$group"
    [[ "$status" -eq 0 ]]
  done
}

@test "unknown option fails with its name" {
  run bash "$SCRIPT" --nope

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Error: unknown option --nope"* ]]
}

@test "option without a value fails" {
  run bash "$SCRIPT" --timeout

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"option --timeout requires a value"* ]]
}

@test "old group names are rejected" {
  local group

  for group in primary custom; do
    run bash "$SCRIPT" --group "$group"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"unknown group $group"* ]]
  done
}

@test "invalid timeout values are rejected" {
  local timeout

  for timeout in 0 -1 abc 1.5 ""; do
    run bash "$SCRIPT" --timeout "$timeout"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"invalid timeout"* ]]
  done
}

@test "ipv4 and ipv6 only together are rejected" {
  run bash "$SCRIPT" -4 -6

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"cannot be used together"* ]]
}

@test "invalid proxy addresses are rejected" {
  local proxy

  for proxy in 127.0.0.1 socks5://127.0.0.1:1080 :1080 'host :1080'; do
    run bash "$SCRIPT" --proxy "$proxy"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"invalid proxy"* ]]
  done
}

@test "proxy accepts hostname, ipv4 and ipv6" {
  local proxy

  for proxy in localhost:1080 10.0.0.1:9050 '[2001:db8::1]:1080'; do
    run bash "$SCRIPT" --proxy "$proxy"
    [[ "$status" -eq 0 ]]
  done
}
