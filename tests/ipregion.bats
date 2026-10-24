#!/usr/bin/env bats

# shellcheck disable=SC2154 # BATS_TEST_DIRNAME and BATS_TEST_TMPDIR are set by bats
setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../ipregion.sh"
  # shellcheck source=../ipregion.sh
  source "$SCRIPT"

  mkdir "$BATS_TEST_TMPDIR/bin"
  ln -s "$BATS_TEST_DIRNAME/fake-curl.sh" "$BATS_TEST_TMPDIR/bin/curl"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  WORK_DIR="$BATS_TEST_TMPDIR/work"
  mkdir "$WORK_DIR"
  export FAKE_CURL_FIXTURES="$BATS_TEST_TMPDIR/fixtures"
  export FAKE_CURL_LOG="$BATS_TEST_TMPDIR/curl.log"
}

add_fixture() {
  local ip_version="$1"
  local name="$2"
  local body="$3"

  mkdir -p "$FAKE_CURL_FIXTURES/ipv$ip_version"
  printf '%s' "$body" >"$FAKE_CURL_FIXTURES/ipv$ip_version/$name"
}

set_fixture_field() {
  local ip_version="$1"
  local name="$2"
  local field="$3"
  local value="$4"

  mkdir -p "$FAKE_CURL_FIXTURES/ipv$ip_version"
  printf '%s' "$value" >"$FAKE_CURL_FIXTURES/ipv$ip_version/$name.$field"
}

add_identity_fixtures() {
  add_fixture 4 ipv4.icanhazip.com 203.0.113.7
  add_fixture 6 ipv6.icanhazip.com 2001:db8:85a3::8a2e:370:7334
}

curl_calls() {
  wc -l <"$FAKE_CURL_LOG"
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
  add_identity_fixtures
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
  add_identity_fixtures
  local proxy

  for proxy in localhost:1080 10.0.0.1:9050 '[2001:db8::1]:1080'; do
    run bash "$SCRIPT" --proxy "$proxy"
    [[ "$status" -eq 0 ]]
  done
}

print_yes_color() {
  # shellcheck source=../ipregion.sh
  source "$SCRIPT"
  printf '[%s]' "$C_YES"
}

@test "colors are on only on a terminal without NO_COLOR" {
  export SCRIPT
  export -f print_yes_color

  run bash -c print_yes_color
  [[ "$output" == "[]" ]]

  run script -qec "bash -c print_yes_color" /dev/null
  [[ "$output" == *$'[\033[1;32m]'* ]]

  run script -qec "NO_COLOR=1 bash -c print_yes_color" /dev/null
  [[ "$output" == *"[]"* ]]
}

@test "visible length ignores color codes" {
  [[ "$(visible_length $'\033[1;32m✓\033[0m')" -eq 1 ]]
  [[ "$(visible_length $'\033[0;90mDE\033[0m \033[1mFRA')" -eq 6 ]]
}

@test "pad fills to width and never cuts text" {
  [[ "$(pad DE 6)" == "DE    " ]]
  [[ "$(pad $'\033[1mDE\033[0m' 4)" == $'\033[1mDE\033[0m  ' ]]
  [[ "$(pad PlayStation 4)" == "PlayStation" ]]
}

@test "flag is built from regional indicators" {
  [[ "$(format_flag DE)" == "🇩🇪" ]]
  [[ "$(format_flag US)" == "🇺🇸" ]]
}

@test "country label gets a flag only with emoji" {
  [[ "$(label_country DE)" == "DE" ]]

  SHOW_EMOJI=true
  [[ "$(label_country DE)" == "🇩🇪 DE" ]]
  [[ "$(label_country Germany)" == "Germany" ]]
}

@test "country cells keep their width with and without emoji" {
  VERDICT=DE

  [[ "$(format_country DE 6)" == "DE    " ]]
  [[ "$(format_country NL 6)" == "NL    " ]]
  [[ "$(format_country "" 6)" == "?     " ]]

  SHOW_EMOJI=true
  [[ "$(format_country DE 9)" == "🇩🇪 DE    " ]]
  [[ "$(visible_length "$(format_country NL 9)")" -eq 9 ]]
}

@test "statuses map to symbols of the cell width" {
  [[ "$(format_status yes 5)" == "✓    " ]]
  [[ "$(format_status no 5)" == "✗    " ]]
  [[ "$(format_status ipblock 5)" == "⊘    " ]]
  [[ "$(format_status none 5)" == "-    " ]]
  [[ "$(format_status unknown 5)" == "?    " ]]
  [[ "$(format_status timeout 5)" == "?    " ]]
}

@test "request keeps code, body and redirect apart" {
  add_fixture 4 example.com_old "moved"
  set_fixture_field 4 example.com_old code 301
  set_fixture_field 4 example.com_old redirect "https://example.com/new"

  http_request 4 https://example.com/old

  [[ "$HTTP_CODE" == 301 ]]
  [[ "$HTTP_BODY" == moved ]]
  [[ "$HTTP_REDIRECT_URL" == "https://example.com/new" ]]
  [[ "$HTTP_CURL_EXIT" == 0 ]]
  [[ -z "$(http_failure_reason)" ]]
}

@test "request goes over the given protocol" {
  add_fixture 4 'example.com_ip_v_1' "203.0.113.1"
  add_fixture 6 'example.com_ip_v_1' "2001:db8::1"

  http_request 4 'https://example.com/ip?v=1'
  [[ "$HTTP_BODY" == 203.0.113.1 ]]

  http_request 6 'https://example.com/ip?v=1'
  [[ "$HTTP_BODY" == 2001:db8::1 ]]
  [[ "$(sed -n 2p "$FAKE_CURL_LOG")" == *" -6 "* ]]
}

@test "failed request has curl exit code and empty body" {
  set_fixture_field 4 example.com exit 28

  http_request 4 https://example.com

  [[ "$HTTP_CURL_EXIT" == 28 ]]
  [[ "$HTTP_CODE" == 000 ]]
  [[ -z "$HTTP_BODY" ]]
  [[ "$(http_failure_reason)" == timeout ]]
}

@test "proxy, interface, timeout and extra args reach curl" {
  add_fixture 4 example.com ok
  PROXY_ADDR=127.0.0.1:1080
  INTERFACE_NAME=wg0
  CURL_TIMEOUT=7

  http_request 4 https://example.com --header 'X-Test: 1'

  run cat "$FAKE_CURL_LOG"
  [[ "$output" == *"--proxy socks5h://127.0.0.1:1080"* ]]
  [[ "$output" != *" -4 "* ]]
  [[ "$output" == *"--interface wg0"* ]]
  [[ "$output" == *"--max-time 7"* ]]
  [[ "$output" == *"--header X-Test: 1 https://example.com" ]]
}

@test "identical requests hit the network once" {
  add_fixture 4 example.com ok

  http_request 4 https://example.com
  http_request 4 https://example.com
  [[ "$(curl_calls)" -eq 1 ]]

  http_request 4 https://example.com --header 'X-Test: 1'
  http_request 6 https://example.com
  [[ "$(curl_calls)" -eq 3 ]]
}

@test "parallel identical requests wait for the first one" {
  add_fixture 4 example.com ok
  export FAKE_CURL_DELAY=0.3

  http_request 4 https://example.com &
  http_request 4 https://example.com &
  http_request 4 https://example.com
  wait

  [[ "$HTTP_BODY" == ok ]]
  [[ "$(curl_calls)" -eq 1 ]]
}

@test "curl exit codes map to failure reasons" {
  local exit_code
  local -A reasons=(
    [6]="DNS error"
    [7]="connection failed"
    [28]="timeout"
    [35]="TLS error"
    [60]="TLS error"
    [97]="proxy error"
    [56]="network error"
  )

  for exit_code in "${!reasons[@]}"; do
    HTTP_CURL_EXIT="$exit_code"
    HTTP_CODE=000
    [[ "$(http_failure_reason)" == "${reasons[$exit_code]}" ]]
  done
}

@test "http codes map to failure reasons" {
  local code
  local -A reasons=(
    [200]=""
    [302]=""
    [404]=""
    [403]="access denied (403)"
    [429]="rate limited (429)"
    [500]="server error (500)"
    [503]="server error (503)"
  )

  HTTP_CURL_EXIT=0
  for code in "${!reasons[@]}"; do
    HTTP_CODE="$code"
    [[ "$(http_failure_reason)" == "${reasons[$code]}" ]]
  done
}

@test "work dir is removed on exit" {
  run bash -c 'source "$1"; create_work_dir; printf "%s" "$WORK_DIR"' _ "$SCRIPT"

  [[ "$status" -eq 0 ]]
  [[ -n "$output" && ! -e "$output" ]]
}

@test "external ips are detected over both protocols" {
  add_fixture 4 ipv4.icanhazip.com $'203.0.113.7\n'
  add_fixture 6 ipv6.icanhazip.com 2001:db8::1

  discover_external_ips

  [[ "$EXTERNAL_IPV4" == 203.0.113.7 ]]
  [[ "$EXTERNAL_IPV6" == 2001:db8::1 ]]
}

@test "next identity service is tried when one fails or answers garbage" {
  set_fixture_field 4 ipv4.icanhazip.com exit 7
  add_fixture 4 api.ipify.org "<html>captive portal</html>"
  add_fixture 4 ipv4.seeip.org 203.0.113.7
  IPV4_ONLY=true

  discover_external_ips

  [[ "$EXTERNAL_IPV4" == 203.0.113.7 ]]
  [[ -z "$EXTERNAL_IPV6" ]]
}

@test "timeout of one identity service falls back to the next" {
  add_fixture 4 ipv4.icanhazip.com 203.0.113.7
  set_fixture_field 6 ipv6.icanhazip.com exit 28
  add_fixture 6 api6.ipify.org 2001:db8::1

  discover_external_ips

  [[ "$EXTERNAL_IPV6" == 2001:db8::1 ]]
}

@test "first identity service to answer wins" {
  add_fixture 4 ipv4.icanhazip.com 203.0.113.1
  set_fixture_field 4 ipv4.icanhazip.com delay 3
  add_fixture 4 api.ipify.org 203.0.113.2
  IPV4_ONLY=true

  SECONDS=0
  discover_external_ips

  [[ "$EXTERNAL_IPV4" == 203.0.113.2 ]]
  ((SECONDS < 2))
}

@test "proxy picks the protocol by identity host, not by curl flags" {
  add_identity_fixtures
  PROXY_ADDR=127.0.0.1:1080

  discover_external_ips

  [[ "$EXTERNAL_IPV4" == 203.0.113.7 ]]
  [[ "$EXTERNAL_IPV6" == 2001:db8:85a3::8a2e:370:7334 ]]
  run grep -cE -- ' -[46] ' "$FAKE_CURL_LOG"
  [[ "$output" -eq 0 ]]
}

@test "only ipv4 or only ipv6 skips the other protocol" {
  add_identity_fixtures

  IPV4_ONLY=true
  discover_external_ips
  [[ -n "$EXTERNAL_IPV4" && -z "$EXTERNAL_IPV6" ]]
  run grep -c -- ' -6 ' "$FAKE_CURL_LOG"
  [[ "$output" -eq 0 ]]

  rm -- "$FAKE_CURL_LOG"
  IPV4_ONLY=false
  IPV6_ONLY=true
  discover_external_ips
  [[ -z "$EXTERNAL_IPV4" && -n "$EXTERNAL_IPV6" ]]
  run grep -c -- ' -4 ' "$FAKE_CURL_LOG"
  [[ "$output" -eq 0 ]]
}

@test "host without ipv6 keeps ipv4 only" {
  add_fixture 4 ipv4.icanhazip.com 203.0.113.7

  discover_external_ips

  [[ "$EXTERNAL_IPV4" == 203.0.113.7 ]]
  [[ -z "$EXTERNAL_IPV6" ]]
}

@test "no external ip fails" {
  run bash "$SCRIPT"

  [[ "$status" -eq 1 ]]
  [[ "$output" == *"Error: failed to detect an external IP address"* ]]
}

@test "ip addresses are masked" {
  [[ "$(mask_ipv4 203.0.113.7)" == "203.0.*.*" ]]
  [[ "$(mask_ipv6 2001:db8:85a3:1:2:3:4:5)" == "2001:db8:85a3::" ]]
  [[ "$(mask_ipv6 2001:db8::1)" == "2001:db8:0::" ]]
  [[ "$(mask_ipv6 2001::1:2:3:4:5:6)" == "2001:0:1::" ]]
  [[ "$(mask_ipv6 ::1)" == "0:0:0::" ]]
}

use_host_fixtures() {
  local host="$1"

  mkdir -p "$FAKE_CURL_FIXTURES"
  cp -r "$BATS_TEST_DIRNAME/fixtures/$host/." "$FAKE_CURL_FIXTURES"
}

set_dual_stack_ips() {
  EXTERNAL_IPV4=203.0.113.7
  EXTERNAL_IPV6=2001:db8:85a3::8a2e:370:7334
}

@test "registration comes from maxmind for each protocol" {
  use_host_fixtures dual-stack
  set_dual_stack_ips

  lookup_ip_registrations

  [[ "${REGISTRATION_ASN[4]}" == 64496 && "${REGISTRATION_ASN[6]}" == 64496 ]]
  [[ "${REGISTRATION_ORG[4]}" == "Example Hosting" ]]
  [[ "${REGISTRATION_COUNTRY[4]}" == NL && "${REGISTRATION_COUNTRY[6]}" == DE ]]
  [[ -z "${REGISTRATION_MAXMIND_FAILURE[4]:-}${REGISTRATION_MAXMIND_FAILURE[6]:-}" ]]
  grep -q -- '--header X-CSRF-Token: [0-9a-f]* ' "$FAKE_CURL_LOG"
  grep -q -- '-6 .*Authorization: Bearer v2.local.masked-demo-token .*city/2001:db8:85a3::8a2e:370:7334?demo=1' "$FAKE_CURL_LOG"
  run grep -c -e rdap.db.ripe.net -e stat.ripe.net "$FAKE_CURL_LOG"
  [[ "$output" -eq 0 ]]
}

@test "used up maxmind limit falls back to ripe" {
  use_host_fixtures dual-stack
  add_fixture 4 geoip.maxmind.com_geoip_v2.1_city_203.0.113.7_demo_1 \
    '{"code":"INSUFFICIENT_FUNDS","error":"You have used all 25 of your demo queries for the day."}'
  set_fixture_field 4 geoip.maxmind.com_geoip_v2.1_city_203.0.113.7_demo_1 code 402
  set_dual_stack_ips

  lookup_ip_registrations

  [[ "${REGISTRATION_MAXMIND_FAILURE[4]}" == "$REASON_DAILY_LIMIT" ]]
  [[ "${REGISTRATION_COUNTRY[4]}" == SE ]]
  [[ "${REGISTRATION_ASN[4]}" == 64496 && "${REGISTRATION_ORG[4]}" == "Example Hosting" ]]
  [[ "${REGISTRATION_COUNTRY[6]}" == DE ]]
}

@test "demo page without csrf token skips maxmind lookups" {
  use_host_fixtures dual-stack
  add_fixture 4 www.maxmind.com_en_geoip-web-services-demo '<html>maintenance</html>'
  set_dual_stack_ips

  lookup_ip_registrations

  [[ "${REGISTRATION_MAXMIND_FAILURE[4]}" == "$REASON_NO_DEMO_TOKEN" ]]
  [[ "${REGISTRATION_MAXMIND_FAILURE[6]}" == "$REASON_NO_DEMO_TOKEN" ]]
  [[ "${REGISTRATION_COUNTRY[4]}" == SE && "${REGISTRATION_COUNTRY[6]}" == SE ]]
  run grep -c -e geoip.maxmind.com -e demo/token "$FAKE_CURL_LOG"
  [[ "$output" -eq 0 ]]
}

@test "ripe holder loses its as-name prefix" {
  add_fixture 4 rdap.db.ripe.net_ip_203.0.113.7 '{"country":null}'
  add_fixture 4 stat.ripe.net_data_prefix-overview_data.json_resource_203.0.113.7 \
    '{"data":{"asns":[{"asn":15169,"holder":"GOOGLE - Google LLC"}]}}'

  lookup_ripe_registration 4 203.0.113.7

  [[ "${REGISTRATION_ORG[4]}" == "Google LLC" ]]
  [[ -z "${REGISTRATION_COUNTRY[4]}" ]]
}

@test "ipv6 only host requests the maxmind token over ipv6" {
  use_host_fixtures dual-stack
  mv "$FAKE_CURL_FIXTURES"/ipv4/www.maxmind.com_* "$FAKE_CURL_FIXTURES/ipv6/"
  EXTERNAL_IPV6=2001:db8:85a3::8a2e:370:7334

  lookup_ip_registrations

  [[ "${REGISTRATION_COUNTRY[6]}" == DE ]]
  grep -q -- '-6 .*demo/token' "$FAKE_CURL_LOG"
  run grep -c -- ' -4 ' "$FAKE_CURL_LOG"
  [[ "$output" -eq 0 ]]
}

print_delayed_number() {
  local delay="$1"
  local number="$2"

  sleep "$delay"
  printf '{"number":%d}\n' "$number"
}

print_active_job_count() {
  local active_dir="$1"
  local -a active

  touch "$active_dir/$BASHPID"
  active=("$active_dir"/*)
  sleep 0.2
  rm "$active_dir/$BASHPID"
  printf '%d\n' "${#active[@]}"
}

@test "result is one json object with every field" {
  run print_result geoip ipinfo 6 SE yes ""

  [[ "$output" == '{"group":"geoip","service":"ipinfo","ip_version":6,"country":"SE","status":"yes","reason":""}' ]]
}

@test "results come in start order, not finish order" {
  create_job_slots
  start_job print_delayed_number 0.3 1
  start_job print_delayed_number 0 2
  start_job print_delayed_number 0.1 3
  wait_for_jobs
  collect_results

  [[ "$(jq -c 'map(.number)' <<<"$RESULTS")" == "[1,2,3]" ]]
}

@test "no jobs give an empty result list" {
  collect_results

  [[ "$RESULTS" == "[]" ]]
}

@test "parallel jobs stay under the limit" {
  local active_dir="$BATS_TEST_TMPDIR/active"
  local index

  mkdir "$active_dir"
  create_job_slots
  for ((index = 0; index <= MAX_PARALLEL_JOBS; index++)); do
    start_job print_active_job_count "$active_dir"
  done
  wait_for_jobs
  collect_results

  [[ "$(jq 'length' <<<"$RESULTS")" -eq $((MAX_PARALLEL_JOBS + 1)) ]]
  [[ "$(jq 'max' <<<"$RESULTS")" -le "$MAX_PARALLEL_JOBS" ]]
}

@test "failed job gives its slot back" {
  local index

  create_job_slots
  for ((index = 0; index <= MAX_PARALLEL_JOBS; index++)); do
    start_job false
  done
  start_job print_delayed_number 0 1
  wait_for_jobs
  collect_results

  [[ "$RESULTS" == '[{"number":1}]' ]]
}

@test "terminated run removes the work dir and stops jobs" {
  local state="$BATS_TEST_TMPDIR/state"
  local runner work_dir job_pid attempt
  local runner_status=0

  bash -c 'source "$1"; create_work_dir; create_job_slots; start_job sleep 30; printf "%s %s\n" "$WORK_DIR" "$!" >"$2"; wait_for_jobs' _ "$SCRIPT" "$state" 3>&- &
  runner=$!
  until [[ -s "$state" ]]; do
    sleep 0.1
  done
  read -r work_dir job_pid <"$state"

  kill -TERM "$runner"
  wait "$runner" || runner_status=$?

  [[ "$runner_status" -eq 143 ]]
  [[ ! -e "$work_dir" ]]
  for ((attempt = 0; attempt < 10; attempt++)); do
    if ! kill -0 "$job_pid" 2>/dev/null; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}
