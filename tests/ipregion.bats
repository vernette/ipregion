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
      break
    fi
    sleep 0.1
  done
  run kill -0 "$job_pid"
  [[ "$status" -ne 0 ]]
}

run_geoip_checks() {
  create_job_slots
  start_checks "${GEOIP_CHECKS[@]}"
  wait_for_jobs
  collect_results
}

result_rows() {
  jq -r '.[] | [.service, .ip_version, .country, .status, .reason] | join(" ")' <<<"$RESULTS"
}

@test "geoip checks give a country or a reason per service and protocol" {
  local expected

  use_host_fixtures dual-stack
  set_dual_stack_ips
  lookup_ip_registrations

  run_geoip_checks

  expected=$(
    cat <<'ROWS'
MaxMind 4 SE yes 
MaxMind 6 SE yes 
RIPE 4 SE yes 
RIPE 6 SE yes 
ipinfo.io 4 SE yes 
ipinfo.io 6 SE yes 
Cloudflare 4 SE yes 
Cloudflare 6 SE yes 
ipregistry.co 4 SE yes 
ipregistry.co 6 SE yes 
ipapi.co 4 SE yes 
ipapi.co 6 SE yes 
ifconfig.co 4 RU yes 
ifconfig.co 6 DE yes 
ip2location.io 4 SE yes 
ip2location.io 6 SE yes 
country.is 4 SE yes 
country.is 6 SE yes 
geoapify.com 4 SE yes 
geoapify.com 6 SE yes 
geojs.io 4 SE yes 
geojs.io 6 SE yes 
ipbase.com 4 SE yes 
ipbase.com 6 SE yes 
ipquery.io 4 RU yes 
ipquery.io 6 DE yes 
ipwho.is 4 SE yes 
ipwho.is 6 SE yes 
ip-api.com 4 SE yes 
ip-api.com 6 SE yes 
ROWS
  )
  run result_rows
  [[ "$output" == "$expected" ]]
  grep -q -- '--header Referer: https://ipapi.co/ https://ipapi.co/203.0.113.7/json$' "$FAKE_CURL_LOG"
}

@test "geoip looks up the ipv6 address over ipv6 unless the service has no ipv6" {
  use_host_fixtures dual-stack
  set_dual_stack_ips
  lookup_ip_registrations

  run_geoip_checks

  grep -q -- '-4 .*demo.ip-api.com/json/2001:db8:85a3::8a2e:370:7334' "$FAKE_CURL_LOG"
  grep -q -- '-6 .*api.country.is/2001:db8:85a3::8a2e:370:7334$' "$FAKE_CURL_LOG"
  grep -q -- '-6 .*https://v6.ipinfo.io/widget/demo/2001:db8:85a3::8a2e:370:7334$' "$FAKE_CURL_LOG"
}

@test "geoip maxmind reuses the header lookup" {
  use_host_fixtures dual-stack
  set_dual_stack_ips
  lookup_ip_registrations
  : >"$FAKE_CURL_LOG"

  run_geoip_checks

  run grep -c geoip.maxmind.com "$FAKE_CURL_LOG"
  [[ "$output" -eq 0 ]]
}

@test "geoip runs only for the protocols that were detected" {
  use_host_fixtures dual-stack
  EXTERNAL_IPV4=203.0.113.7
  lookup_ip_registrations

  run_geoip_checks

  [[ "$(jq 'length' <<<"$RESULTS")" -eq 15 ]]
  [[ "$(jq '[.[].ip_version] | unique' -c <<<"$RESULTS")" == "[4]" ]]
}

@test "geoip is skipped when another group is selected" {
  use_host_fixtures dual-stack
  set_dual_stack_ips
  SELECTED_GROUP=platforms

  run_geoip_checks

  [[ "$RESULTS" == "[]" ]]
}

@test "geoip failures carry a reason and no country" {
  use_host_fixtures dual-stack
  EXTERNAL_IPV4=203.0.113.7
  set_fixture_field 4 api.country.is_203.0.113.7 exit 28
  add_fixture 4 get.geojs.io_v1_ip_country.json_ip_203.0.113.7 '<html>busy</html>'
  add_fixture 4 www.cloudflare.com_cdn-cgi_trace $'ip=203.0.113.7\nloc=T1'

  run_geoip_checks

  run result_rows
  [[ "$output" == *"MaxMind 4   no demo token"* ]]
  [[ "$output" == *"country.is 4   timeout"* ]]
  [[ "$output" == *"geojs.io 4   unexpected response"* ]]
  [[ "$output" == *"Cloudflare 4   unexpected response"* ]]
}

run_platforms_checks() {
  create_job_slots
  start_checks "${PLATFORMS_CHECKS[@]}"
  wait_for_jobs
  collect_results
}

@test "platforms checks give a country, no ipv6 or a reason per service and protocol" {
  local expected

  use_host_fixtures dual-stack
  set_dual_stack_ips

  run_platforms_checks

  expected=$(
    cat <<'ROWS'
Google 4 SE yes 
Google 6 SE yes 
YouTube 4 SE yes 
YouTube 6 SE yes 
Twitch 4 SE yes 
Twitch 6  none no IPv6
ChatGPT 4 SE yes 
ChatGPT 6 SE yes 
Netflix 4 SE yes 
Netflix 6 SE yes 
Spotify 4 SE yes 
Spotify 6 SE yes 
Reddit 4 SE yes 
Reddit 6  none no IPv6
Disney+ 4 SE yes 
Disney+ 6   unexpected response
TikTok 4 SE yes 
TikTok 6  none no IPv6
Apple 4 SE yes 
Apple 6 SE yes 
Steam 4 SE yes 
Steam 6  none no IPv6
Microsoft 4 SE yes 
Microsoft 6  none no IPv6
Ookla 4 SE yes 
Ookla 6  none no IPv6
JetBrains 4 SI yes 
JetBrains 6 SE yes 
PlayStation 4 SE yes 
PlayStation 6 SE yes 
ROWS
  )
  run result_rows
  [[ "$output" == "$expected" ]]
  grep -q -- '--user-agent Mozilla/5.0 .* https://www.reddit.com/api/v1/geo$' "$FAKE_CURL_LOG"
  grep -q -- '--head https://store.steampowered.com$' "$FAKE_CURL_LOG"
}

@test "ipv6 connection failure means the service has no ipv6" {
  set_fixture_field 6 gql.twitch.tv_gql exit 7
  EXTERNAL_IPV6=2001:db8:85a3::8a2e:370:7334

  run_platforms_checks

  [[ "$(jq -r '.[] | select(.service == "Twitch") | [.status, .reason] | join(" ")' <<<"$RESULTS")" == "none no IPv6" ]]
}

@test "ipv6 connection failure through a proxy is a reason, not no ipv6" {
  set_fixture_field 6 gql.twitch.tv_gql exit 7
  EXTERNAL_IPV6=2001:db8:85a3::8a2e:370:7334
  PROXY_ADDR=127.0.0.1:1080

  run_platforms_checks

  [[ "$(jq -r '.[] | select(.service == "Twitch") | [.status, .reason] | join(" ")' <<<"$RESULTS")" == " connection failed" ]]
}

@test "ipv4 connection failure is a reason, not no ipv6" {
  set_fixture_field 4 gql.twitch.tv_gql exit 7
  EXTERNAL_IPV4=203.0.113.7

  run_platforms_checks

  [[ "$(jq -r '.[] | select(.service == "Twitch") | [.status, .reason] | join(" ")' <<<"$RESULTS")" == " connection failed" ]]
}

run_cdn_checks() {
  create_job_slots
  start_checks "${CDN_CHECKS[@]}"
  wait_for_jobs
  collect_results
}

cdn_rows() {
  jq -r '.[] | [.service, .ip_version, .country, .iata, .node, .reason] | join(" ")' <<<"$RESULTS"
}

@test "cdn checks give the edge country, iata and node per protocol" {
  local expected

  use_host_fixtures dual-stack
  set_dual_stack_ips

  run_cdn_checks

  expected=$(
    cat <<'ROWS'
Cloudflare 4 SE ARN  
Cloudflare 6 SE ARN  
YouTube 4 DE MUC muc11s18 
YouTube 6 DE FRA tzfraa-cd 
Netflix 4 DE FRA c002-fra001-ix 
Netflix 6 DE FRA c002-fra001-ix 
ROWS
  )
  run cdn_rows
  [[ "$output" == "$expected" ]]
  grep -q -- '-4 .*--data iata=FRA https://www.air-port-codes.com/api/v1/single$' "$FAKE_CURL_LOG"
}

@test "youtube node without an iata code keeps the node and has no country" {
  use_host_fixtures dual-stack
  add_fixture 4 redirector.googlevideo.com_report_mapping_di_no '203.0.113.7 => unknownnode (203.0.113.0/24)'
  EXTERNAL_IPV4=203.0.113.7

  run_cdn_checks

  [[ "$(jq -r '.[] | select(.service == "YouTube") | [.node, .iata, .reason] | join(" ")' <<<"$RESULTS")" == "unknownnode  unexpected response" ]]
  run grep -c air-port-codes "$FAKE_CURL_LOG"
  [[ "$output" -eq 0 ]]
}

@test "blocked netflix cdn is a failure reason" {
  use_host_fixtures dual-stack
  add_fixture 4 api.fast.com_netflix_speedtest_v2_https_true_token_YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm_urlCount_1 'Not Available'
  set_fixture_field 4 api.fast.com_netflix_speedtest_v2_https_true_token_YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm_urlCount_1 code 403
  EXTERNAL_IPV4=203.0.113.7

  run_cdn_checks

  [[ "$(jq -r '.[] | select(.service == "Netflix") | .reason' <<<"$RESULTS")" == "access denied (403)" ]]
}

run_availability_checks() {
  create_job_slots
  start_checks "${AVAILABILITY_CHECKS[@]}"
  wait_for_jobs
  collect_results
}

availability_row() {
  local service="$1"

  jq -r --arg service "$service" '.[] | select(.service == $service) | [.status, .reason] | join(" ")' <<<"$RESULTS"
}

@test "availability checks give a status, no ipv6 or a reason per service and protocol" {
  local expected

  use_host_fixtures dual-stack
  set_dual_stack_ips

  run_availability_checks

  expected=$(
    cat <<'ROWS'
YouTube Premium 4  yes 
YouTube Premium 6  yes 
Spotify Signup 4  yes 
Spotify Signup 6  yes 
Disney+ 4  yes 
Disney+ 6  no 
Reddit Guest 4  yes 
Reddit Guest 6  none no IPv6
Google Search 4  yes 
Google Search 6  yes 
ROWS
  )
  run result_rows
  [[ "$output" == "$expected" ]]
  run grep -c -- '--location' "$FAKE_CURL_LOG"
  [[ "$output" -eq 0 ]]
}

@test "region blocked services are no" {
  use_host_fixtures dual-stack
  add_fixture 4 www.youtube.com_premium '<p>YouTube Premium is not available in your country</p>'
  add_fixture 4 spclient.wg.spotify.com_signup_public_v1_account__validate_1_key_142b583129b2df829de3656f9eb484e6 \
    '{"status":120,"country":"RU","is_country_launched":false}'
  add_fixture 4 disney.api.edge.bamgrid.com_graph_v1_device_graphql \
    '{"extensions":{"sdk":{"session":{"inSupportedLocation":false,"location":{"countryCode":"RU"}}}}}'
  EXTERNAL_IPV4=203.0.113.7

  run_availability_checks

  [[ "$(availability_row "YouTube Premium")" == "no " ]]
  [[ "$(availability_row "Spotify Signup")" == "no " ]]
  [[ "$(availability_row Disney+)" == "no " ]]
}

@test "reddit guest 403 is an ip block with the reason" {
  use_host_fixtures dual-stack
  set_fixture_field 4 www.reddit.com code 403
  EXTERNAL_IPV4=203.0.113.7

  run_availability_checks

  [[ "$(availability_row "Reddit Guest")" == "ipblock access denied (403)" ]]
}

@test "google search captcha redirect or 429 is no" {
  use_host_fixtures dual-stack
  set_fixture_field 4 www.google.com_search_q_cats code 302
  set_fixture_field 4 www.google.com_search_q_cats redirect 'https://www.google.com/sorry/index?continue=x'
  set_fixture_field 6 www.google.com_search_q_cats code 429
  set_dual_stack_ips

  run_availability_checks

  [[ "$(jq -r '.[] | select(.service == "Google Search") | .status' <<<"$RESULTS")" == $'no\nno' ]]
}

@test "unknown availability response is a failure reason" {
  use_host_fixtures dual-stack
  add_fixture 4 www.google.com_search_q_cats '<html>results</html>'
  set_fixture_field 4 www.youtube.com_premium exit 28
  EXTERNAL_IPV4=203.0.113.7

  run_availability_checks

  [[ "$(availability_row "Google Search")" == " unexpected response" ]]
  [[ "$(availability_row "YouTube Premium")" == " timeout" ]]
}

run_ai_checks() {
  create_job_slots
  start_checks "${AI_CHECKS[@]}"
  wait_for_jobs
  collect_results
}

ai_row() {
  local service="$1"

  jq -r --arg service "$service" '.[] | select(.service == $service) | [.status, .reason] | join(" ")' <<<"$RESULTS"
}

@test "ai checks give a status, no ipv6 or a reason per service and protocol" {
  local expected

  use_host_fixtures dual-stack
  set_dual_stack_ips

  run_ai_checks

  expected=$(
    cat <<'ROWS'
Gemini Web 4  yes 
Gemini Web 6  yes 
Gemini API 4  yes 
Gemini API 6  yes 
OpenAI API 4  yes 
OpenAI API 6  yes 
Anthropic API 4  yes 
Anthropic API 6  yes 
Grok API 4  yes 
Grok API 6  yes 
Qwen 4  yes 
Qwen 6  none no IPv6
Kimi 4  yes 
Kimi 6  yes 
GLM 4  yes 
GLM 6  yes 
MiniMax 4  yes 
MiniMax 6  yes 
Doubao 4  yes 
Doubao 6  yes 
SiliconFlow 4  yes 
SiliconFlow 6  yes 
DeepSeek 4  yes 
DeepSeek 6  none no IPv6
ROWS
  )
  run result_rows
  [[ "$output" == "$expected" ]]
}

@test "gemini matches the google country against the web and api region lists" {
  use_host_fixtures dual-stack
  add_fixture 4 accounts.google.com_v3_signin_identifier_flowName_GlifSetupAndroid '<input type="hidden" name="region" value="HK">'
  add_fixture 6 accounts.google.com_v3_signin_identifier_flowName_GlifSetupAndroid '<input type="hidden" name="region" value="ID">'
  set_dual_stack_ips

  run_ai_checks

  [[ "$(jq -r '.[] | select(.service | startswith("Gemini")) | .status' <<<"$RESULTS")" == $'yes\nyes\nno\nno' ]]
}

@test "gemini without a region list or a google country is a failure reason" {
  use_host_fixtures dual-stack
  set_fixture_field 4 support.google.com_gemini_answer_13575153_hl_en exit 28
  add_fixture 4 accounts.google.com_v3_signin_identifier_flowName_GlifSetupAndroid '<html></html>'
  EXTERNAL_IPV4=203.0.113.7

  run_ai_checks

  [[ "$(ai_row "Gemini Web")" == " timeout" ]]
  [[ "$(ai_row "Gemini API")" == " unexpected response" ]]
}

@test "ai api 403 with the region marker is no, without it an ip block" {
  use_host_fixtures dual-stack
  add_fixture 4 api.openai.com_v1_models '{"error":{"code":"unsupported_country_region_territory","message":"Country, region, or territory not supported","param":null,"type":"request_forbidden"}}'
  add_fixture 4 api.anthropic.com_v1_models '{"error":{"type":"forbidden","message":"Request not allowed"}}'
  add_fixture 4 api.x.ai_v1_models '<!doctype html><html><body><p>Access denied</p></body></html>'
  for name in api.openai.com_v1_models api.anthropic.com_v1_models api.x.ai_v1_models; do
    set_fixture_field 4 "$name" code 403
  done
  EXTERNAL_IPV4=203.0.113.7

  run_ai_checks

  [[ "$(ai_row "OpenAI API")" == "no access denied (403)" ]]
  [[ "$(ai_row "Anthropic API")" == "no access denied (403)" ]]
  [[ "$(ai_row "Grok API")" == "ipblock access denied (403)" ]]
}

@test "ai reachability without the provider auth error is a failure reason" {
  use_host_fixtures dual-stack
  set_fixture_field 4 api.z.ai_api_paas_v4_models exit 28
  set_fixture_field 4 api.moonshot.ai_v1_models code 200
  EXTERNAL_IPV4=203.0.113.7

  run_ai_checks

  [[ "$(ai_row GLM)" == " timeout" ]]
  [[ "$(ai_row Kimi)" == " unexpected response" ]]
}

results_of() {
  jq -cs . <<<"$1"
}

verdict_of_results() {
  compute_verdict
  printf '%s' "$VERDICT"
}

attention_rows() {
  jq -r '.[] | [(.services | join(",")), .ip_version, .country, .status, .reason] | join(" ")' <<<"$ATTENTION"
}

@test "verdict gives platforms and geoip equal weight" {
  RESULTS=$(results_of "$(
    print_result platforms Google 4 DE yes ""
    print_result platforms YouTube 4 DE yes ""
    print_result geoip RIPE 4 NL yes ""
    print_result geoip MaxMind 4 NL yes ""
    print_result geoip ipinfo.io 4 NL yes ""
    print_result geoip ipwho.is 4 DE yes ""
  )")

  [[ "$(verdict_of_results)" == DE ]]
}

@test "verdict tie leaves no verdict and names the tied countries" {
  RESULTS=$(results_of "$(
    print_result platforms Google 4 NL yes ""
    print_result platforms YouTube 4 DE yes ""
    print_result geoip RIPE 4 NL yes ""
    print_result geoip MaxMind 4 DE yes ""
    print_result geoip ipinfo.io 4 SE yes ""
  )")

  compute_verdict

  [[ -z "$VERDICT" ]]
  [[ "${VERDICT_TIED_COUNTRIES[*]}" == "DE NL" ]]
}

@test "verdict ignores cdn, failures and groups without countries" {
  RESULTS=$(results_of "$(
    print_result platforms Google 4 SE yes ""
    print_result platforms YouTube 4 "" "" timeout
    print_result cdn Cloudflare 4 DE yes ""
    print_result cdn YouTube 6 DE yes ""
    print_result availability Disney+ 4 "" yes ""
  )")
  [[ "$(verdict_of_results)" == SE ]]

  RESULTS=$(results_of "$(
    print_result availability Disney+ 4 "" yes ""
    print_result ai Kimi 6 "" yes ""
  )")
  [[ -z "$(verdict_of_results)" ]]
}

@test "attention lists differences and failures, not geoip countries, cdn or the maxmind limit" {
  VERDICT=DE
  RESULTS=$(results_of "$(
    print_result platforms Google 4 DE yes ""
    print_result platforms Disney+ 6 "" "" timeout
    print_result platforms ChatGPT 6 NL yes ""
    print_result platforms Steam 6 "" none "no IPv6"
    print_result cdn Netflix 6 NL yes ""
    print_result cdn YouTube 4 "" "" timeout
    print_result availability "Reddit Guest" 6 "" ipblock "access denied (403)"
    print_result availability Disney+ 4 "" yes ""
    print_result ai "Gemini Web" 4 "" no ""
    print_result geoip RIPE 6 NL yes ""
    print_result geoip ipquery.io 6 "" "" timeout
    print_result geoip MaxMind 4 "" "" "daily limit used up"
  )")

  collect_attention

  expected=$(
    cat <<'ROWS'
ChatGPT 6 NL yes different country
Gemini Web 4  no 
Reddit Guest 6  ipblock access denied (403)
Disney+ 6   timeout
ipquery.io 6   timeout
ROWS
  )
  run attention_rows
  [[ "$output" == "$expected" ]]
}

@test "attention without a verdict lists only failures" {
  VERDICT=""
  RESULTS=$(results_of "$(
    print_result platforms Google 4 DE yes ""
    print_result platforms YouTube 4 NL yes ""
    print_result platforms Twitch 4 "" "" timeout
  )")

  collect_attention

  run attention_rows
  [[ "$output" == "Twitch 4   timeout" ]]
}

@test "attention merges protocols and collapses three alike rows" {
  VERDICT=DE
  RESULTS=$(results_of "$(
    print_result ai "Grok API" 4 "" "" "TLS error"
    print_result ai "Grok API" 6 "" "" "TLS error"
    print_result platforms Google 6 "" "" timeout
    print_result platforms YouTube 6 "" "" timeout
    print_result platforms Twitch 6 "" "" timeout
    print_result platforms Netflix 4 "" "" timeout
    print_result platforms Spotify 4 "" "" timeout
    print_result platforms Reddit 4 NL yes ""
  )")

  collect_attention

  expected=$(
    cat <<'ROWS'
Reddit 4 NL yes different country
Grok API both   TLS error
Netflix 4   timeout
Spotify 4   timeout
Google,YouTube,Twitch 6   timeout
ROWS
  )
  run attention_rows
  [[ "$output" == "$expected" ]]
}
