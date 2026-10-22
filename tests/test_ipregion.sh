#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../ipregion.sh
source "$SCRIPT_DIR/../ipregion.sh"
rm -f "$SPINNER_SERVICE_FILE"

FAILURES=0

assert_eq() {
  local description="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$expected" == "$actual" ]]; then
    printf "ok   %s\n" "$description"
    return
  fi

  printf "FAIL %s\n     expected: %s\n     actual:   %s\n" "$description" "$expected" "$actual"
  FAILURES=$((FAILURES + 1))
}

gemini_match() {
  local code="$1"
  local md="$2"
  local cldr="$3"
  local api_name="$4"

  if jq -en --arg code "$code" --arg md "$md" --arg cldr_raw "$cldr" --arg api_name "$api_name" \
    "$GEMINI_MATCH_FILTER" >/dev/null; then
    echo "Yes"
  else
    echo "No"
  fi
}

test_mask_ipv4() {
  assert_eq "mask_ipv4" "203.0.*.*" "$(mask_ipv4 203.0.113.42)"
}

test_mask_ipv6() {
  assert_eq "mask_ipv6 full" "2001:db8:85a3::" "$(mask_ipv6 2001:db8:85a3:1:2:3:4:5)"
  assert_eq "mask_ipv6 compressed tail" "2001:db8:0::" "$(mask_ipv6 2001:db8::1)"
  assert_eq "mask_ipv6 compressed middle" "2001:0:0::" "$(mask_ipv6 2001::1:2:3)"
  assert_eq "mask_ipv6 loopback" "0:0:0::" "$(mask_ipv6 ::1)"
  assert_eq "mask_ipv6 trailing ::" "fe80:0:0::" "$(mask_ipv6 fe80::)"
}

test_status_from_http_code() {
  assert_eq "http 403" "$STATUS_DENIED" "$(status_from_http_code 403)"
  assert_eq "http 429" "$STATUS_RATE_LIMIT" "$(status_from_http_code 429)"
  assert_eq "http 404" "$STATUS_NA" "$(status_from_http_code 404)"
  assert_eq "http 502" "$STATUS_SERVER_ERROR" "$(status_from_http_code 502)"
  assert_eq "http 200" "" "$(status_from_http_code 200)"
}

test_process_response() {
  assert_eq "process_response json" "DE" \
    "$(process_response MAXMIND '{"country":{"iso_code":"DE"}}' MaxMind)"
  assert_eq "process_response plain" "NL" "$(process_response IFCONFIG_CO $'NL\r\n' ifconfig.co plain)"
  assert_eq "process_response html" "$STATUS_NA" "$(process_response RIPE '<html>blocked</html>' RIPE)"
  assert_eq "process_response empty" "$STATUS_NA" "$(process_response RIPE '' RIPE)"
  assert_eq "process_response status" "$STATUS_DENIED" "$(process_response RIPE "$STATUS_DENIED" RIPE)"
}

test_gemini_match() {
  local md=$'# Regions\n\n- Germany\n- The Bahamas\n- United States'
  local cldr='{"main":{"en":{"localeDisplayNames":{"territories":{"DE":"Germany","BS":"Bahamas","RU":"Russia","US":"United States","US-alt-short":"US"}}}}}'

  assert_eq "gemini supported" "Yes" "$(gemini_match DE "$md" "$cldr" "")"
  assert_eq "gemini stopwords ignored" "Yes" "$(gemini_match BS "$md" "$cldr" "")"
  assert_eq "gemini alt names" "Yes" "$(gemini_match US "$md" "$cldr" "")"
  assert_eq "gemini unsupported" "No" "$(gemini_match RU "$md" "$cldr" "")"
  assert_eq "gemini api name fallback" "Yes" "$(gemini_match XX "$md" "" "Germany")"
}

test_finalize_json() {
  ARR_PRIMARY=()
  ARR_CUSTOM=()
  ARR_CDN=()
  EXTERNAL_IPV4="203.0.113.42"
  EXTERNAL_IPV6=""

  add_result primary "MaxMind" "DE" ""
  add_result custom "Google" $'US\n' ""
  finalize_json

  assert_eq "json ipv4" "203.0.113.42" "$(jq -r '.ipv4' <<<"$RESULT_JSON")"
  assert_eq "json ipv6 null" "null" "$(jq -r '.ipv6' <<<"$RESULT_JSON")"
  assert_eq "json primary result" "MaxMind DE null" \
    "$(jq -r '.results.primary[0] | "\(.service) \(.ipv4) \(.ipv6)"' <<<"$RESULT_JSON")"
  assert_eq "json newline stripped" "US" "$(jq -r '.results.custom[0].ipv4' <<<"$RESULT_JSON")"
  assert_eq "json empty cdn" "0" "$(jq -r '.results.cdn | length' <<<"$RESULT_JSON")"
}

test_parse_arguments() {
  parse_arguments -j -4 -t 10 -g custom -p 127.0.0.1:1080

  assert_eq "args json" "true" "$JSON_OUTPUT"
  assert_eq "args ipv4" "true" "$IPV4_ONLY"
  assert_eq "args timeout" "10" "$CURL_TIMEOUT"
  assert_eq "args group" "custom" "$GROUPS_TO_SHOW"
  assert_eq "args proxy" "127.0.0.1:1080" "$PROXY_ADDR"

  (parse_arguments -t abc >/dev/null 2>&1)
  assert_eq "args invalid timeout exits" "1" "$?"
}

test_mask_ipv4
test_mask_ipv6
test_status_from_http_code
test_process_response
test_gemini_match
test_finalize_json
test_parse_arguments

if ((FAILURES > 0)); then
  printf "\n%d failed\n" "$FAILURES"
  exit 1
fi

printf "\nall passed\n"
