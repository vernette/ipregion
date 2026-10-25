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

readonly MAX_PARALLEL_JOBS=16
readonly JOB_POLL_INTERVAL=0.1
readonly RESULT_FILE_PREFIX="result-"
readonly CLEAR_LINE=$'\r\033[K'
readonly PROGRESS_LABEL="Checking services"
readonly PROGRESS_SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
readonly PROGRESS_BAR_WIDTH=24
readonly PROGRESS_BAR_DONE="━"
readonly PROGRESS_BAR_LEFT="─"

readonly IPV4_IDENTITY_URLS=(
  https://ipv4.icanhazip.com
  https://api.ipify.org
  https://ipv4.seeip.org
  https://ipv4.wtfismyip.com/text
)
readonly IPV6_IDENTITY_URLS=(
  https://ipv6.icanhazip.com
  https://api6.ipify.org
  https://ipv6.seeip.org
  https://ipv6.wtfismyip.com/text
)
readonly IPV4_PATTERN='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
readonly IPV6_PATTERN='^[0-9A-Fa-f]{0,4}(:[0-9A-Fa-f]{0,4}){2,7}$'
readonly IPV6_GROUP_COUNT=8

readonly MAXMIND_DEMO_PAGE_URL="https://www.maxmind.com/en/geoip-web-services-demo"
readonly MAXMIND_TOKEN_URL="https://www.maxmind.com/en/geoip2/demo/token"
readonly MAXMIND_CITY_URL="https://geoip.maxmind.com/geoip/v2.1/city"
readonly MAXMIND_CSRF_PATTERN='value="([0-9a-f]+)" name="csrf_token"'
readonly RIPE_RDAP_IP_URL="https://rdap.db.ripe.net/ip"
readonly RIPESTAT_PREFIX_OVERVIEW_URL="https://stat.ripe.net/data/prefix-overview/data.json"

readonly IPV4_TRANSPORT=4
readonly IPINFO_IPV4_URL="https://ipinfo.io/widget/demo"
readonly IPINFO_IPV6_URL="https://v6.ipinfo.io/widget/demo"
readonly CLOUDFLARE_TRACE_URL="https://www.cloudflare.com/cdn-cgi/trace"
readonly CLOUDFLARE_COUNTRY_PATTERN=$'(^|\n)loc=([A-Z]{2})(\n|$)'
readonly IPREGISTRY_URL="https://api.ipregistry.co"
readonly IPREGISTRY_KEY="sb69ksjcajfs4c"
readonly IPREGISTRY_ORIGIN="https://ipregistry.co"
readonly IPAPI_CO_URL="https://ipapi.co"
readonly IPAPI_CO_REFERER="https://ipapi.co/"
readonly IFCONFIG_CO_URL="https://ifconfig.co/country-iso"
readonly IP2LOCATION_URL="https://api.ip2location.io/"
readonly COUNTRY_IS_URL="https://api.country.is"
readonly GEOAPIFY_URL="https://api.geoapify.com/v1/ipinfo"
readonly GEOAPIFY_KEY="b8568cb9afc64fad861a69edbddb2658"
readonly GEOJS_URL="https://get.geojs.io/v1/ip/country.json"
readonly IPBASE_URL="https://api.ipbase.com/v2/info"
readonly IPQUERY_URL="https://api.ipquery.io"
readonly IPWHO_URL="https://ipwho.is"
readonly IP_API_URL="https://demo.ip-api.com/json"
readonly IP_API_ORIGIN="https://ip-api.com"

readonly USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"
readonly GOOGLE_URL="https://accounts.google.com/v3/signin/identifier?flowName=GlifSetupAndroid"
readonly GOOGLE_COUNTRY_PATTERN='name="region" value="([^"]*)"'
readonly YOUTUBE_URL="https://www.youtube.com/sw.js_data"
readonly YOUTUBE_JSON_PREFIX=")]}'"
readonly TWITCH_URL="https://gql.twitch.tv/gql"
readonly TWITCH_CLIENT_ID="kimne78kx3ncx6brgo4mv6wki5h1ko"
readonly TWITCH_QUERY='[{"operationName":"VerifyEmail_CurrentUser","variables":{},"extensions":{"persistedQuery":{"version":1,"sha256Hash":"f9e7dcdf7e99c314c82d8f7f725fab5f99d1df3d7359b53c9ae122deec590198"}}}]'
readonly CHATGPT_URL="https://ab.chatgpt.com/v1/initialize"
readonly CHATGPT_STATSIG_API_KEY="client-zUdXdSTygXJdzoE0sWTkP8GKTVsUMF2IRM7ShVO2JAG"
readonly CHATGPT_COUNTRY_PATTERN='"derived_fields":\{[^}]*"country":"([^"]*)"'
readonly NETFLIX_URL="https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=1"
readonly SPOTIFY_URL="https://spclient.wg.spotify.com/signup/public/v1/account/?validate=1&key=142b583129b2df829de3656f9eb484e6"
readonly SPOTIFY_CLIENT_ID="9a8d2f0ce77a4e248bb71fefcb557637"
readonly REDDIT_URL="https://www.reddit.com/api/v1/geo"
readonly REDDIT_COUNTRY_PATTERN='country code: ([A-Z]{2})'
readonly DISNEY_PLUS_URL="https://disney.api.edge.bamgrid.com/graph/v1/device/graphql"
readonly DISNEY_PLUS_API_KEY="ZGlzbmV5JmFuZHJvaWQmMS4wLjA.bkeb0m230uUhv8qrAXuNu39tbE_mD5EEhM_NAcohjyA"
# shellcheck disable=SC2016 # $registerDevice is a GraphQL variable, not a shell expansion
readonly DISNEY_PLUS_QUERY='{"query":"mutation registerDevice($registerDevice: RegisterDeviceInput!) { registerDevice(registerDevice: $registerDevice) { __typename } }","variables":{"registerDevice":{"applicationRuntime":"android","attributes":{"operatingSystem":"Android","operatingSystemVersion":"13"},"deviceFamily":"android","deviceLanguage":"en","deviceProfile":"phone","devicePlatformId":"android"}},"operationName":"registerDevice"}'
readonly TIKTOK_URL="https://www.tiktok.com/api/v1/web-cookie-privacy/config?appId=1988"
readonly APPLE_URL="https://gspe1-ssl.ls.apple.com/pep/gcc"
readonly STEAM_URL="https://store.steampowered.com"
readonly STEAM_COUNTRY_PATTERN='steamCountry=([^%;]*)'
readonly MICROSOFT_URL="https://login.live.com"
readonly MICROSOFT_COUNTRY_PATTERN='"sRequestCountry":"([^"]*)"'
readonly OOKLA_URL="https://www.speedtest.net/api/js/config-sdk"
readonly JETBRAINS_URL="https://data.services.jetbrains.com/geo"
readonly PLAYSTATION_URL="https://www.playstation.com"
readonly PLAYSTATION_COUNTRY_PATTERN='[Cc]ookie: country=([^;]*)'

readonly CLOUDFLARE_SPEED_META_URL="https://speed.cloudflare.com/meta"
readonly CLOUDFLARE_SPEED_REFERER="https://speed.cloudflare.com"
readonly YOUTUBE_CDN_MAPPING_URL="https://redirector.googlevideo.com/report_mapping?di=no"
readonly YOUTUBE_CDN_NODE_PATTERN='=> ([^ ]+)'
readonly GOOGLE_NODE_PATTERN='^([a-z]{3})[0-9]'
readonly ISP_NODE_PATTERN='^[a-z]+-([a-z]{3})[0-9]'
readonly GGC_NODE_PATTERN='^[a-z]{2}([a-z]{3})[a-z]-[a-z0-9]+$'
readonly NETFLIX_CDN_URL_PATTERN='^https://ipv[46]-([a-z0-9]+-([a-z]{3})[0-9]+[a-z0-9-]*)\.'
readonly AIRPORT_CODES_URL="https://www.air-port-codes.com/api/v1/single"
readonly AIRPORT_CODES_KEY="96dc04b3fb"
readonly AIRPORT_CODES_REFERER="https://www.air-port-codes.com/"

readonly GOOGLE_SOCS_COOKIE="Cookie: SOCS=CAI"
readonly ACCEPT_LANGUAGE_ENGLISH="Accept-Language: en-US,en;q=0.9"
readonly YOUTUBE_PREMIUM_URL="https://www.youtube.com/premium"
readonly YOUTUBE_PREMIUM_BLOCKED_MARKER="YouTube Premium is not available in your country"
readonly SPOTIFY_SIGNUP_BLOCKED_STATUS_PATTERN='^(120|320)$'
readonly DISNEY_PLUS_FORBIDDEN_MARKER="Forbidden location"
readonly REDDIT_GUEST_URL="https://www.reddit.com"
readonly GOOGLE_SEARCH_URL="https://www.google.com/search?q=cats"
readonly GOOGLE_SEARCH_CAPTCHA_PATH="/sorry/"
readonly GOOGLE_SEARCH_NO_JS_MARKER="enablejs"

readonly GEMINI_WEB_REGIONS_URL="https://support.google.com/gemini/answer/13575153?hl=en"
readonly GEMINI_WEB_REGIONS_FILTER='split("Supported countries &amp; territories")[1] // "" | [scan("<li>([^<]+)</li>")[0] | gsub("&[a-z]+;"; " ")]'
readonly GEMINI_API_REGIONS_URL="https://ai.google.dev/gemini-api/docs/available-regions.md.txt"
readonly GEMINI_API_REGIONS_FILTER='split("\n") | map(select(startswith("- ")) | .[2:])'
readonly CLDR_TERRITORIES_URL="https://cdn.jsdelivr.net/npm/cldr-localenames-full/main/en/territories.json"
# shellcheck disable=SC2016 # $code, $regions, $yes and $no are jq variables, not shell expansions
readonly GEMINI_MATCH_FILTER='
def stopwords: ["the", "of", "and", "republic", "island", "islands", "saint", "st"];
def words: ascii_downcase | [splits("[^\\p{L}]+")] | map(select(. != "" and (IN(stopwords[]) | not))) | unique;
def names_missing_in_cldr: {CD: ["Democratic Republic of the Congo"], MO: ["Macau"], UM: ["United States Minor Outlying Islands"]}[$code] // [];
(.main.en.localeDisplayNames.territories | to_entries | map(select(.key | startswith($code)) | .value)) + names_missing_in_cldr
| map(words)
| if any(IN($regions[] | words)) then $yes else $no end'
readonly OPENAI_API_URL="https://api.openai.com/v1/models"
readonly OPENAI_API_REGION_BLOCKED_MARKER="unsupported_country_region_territory"
readonly ANTHROPIC_API_URL="https://api.anthropic.com/v1/models"
readonly ANTHROPIC_API_REGION_BLOCKED_MARKER="Request not allowed"
readonly GROK_API_URL="https://api.x.ai/v1/models"
readonly GROK_API_REGION_BLOCKED_MARKER="not available in your region"
readonly QWEN_API_URL="https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models"
readonly KIMI_API_URL="https://api.moonshot.ai/v1/models"
readonly GLM_API_URL="https://api.z.ai/api/paas/v4/models"
readonly MINIMAX_API_URL="https://api.minimax.io/v1/models"
readonly DOUBAO_API_URL="https://ark.cn-beijing.volces.com/api/v3/models"
readonly SILICONFLOW_API_URL="https://api.siliconflow.cn/v1/models"
readonly DEEPSEEK_API_URL="https://api.deepseek.com/models"

readonly CURL_EXIT_OK=0
readonly CURL_EXIT_DNS=6
readonly CURL_EXIT_CONNECT=7
readonly CURL_EXIT_TIMEOUT=28
readonly CURL_EXIT_TLS_HANDSHAKE=35
readonly CURL_EXIT_TLS_CERTIFICATE=60
readonly CURL_EXIT_PROXY=97
readonly HTTP_OK=200
readonly HTTP_CREATED=201
readonly HTTP_UNAUTHORIZED=401
readonly HTTP_PAYMENT_REQUIRED=402
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
readonly REASON_UNEXPECTED_RESPONSE="unexpected response"
readonly REASON_DAILY_LIMIT="daily limit used up"
readonly REASON_NO_DEMO_TOKEN="no demo token"
readonly REASON_NO_IPV6="no IPv6"

readonly GROUP_PLATFORMS="platforms"
readonly PLATFORMS_CHECKS=(
  check_platforms_google
  check_platforms_youtube
  check_platforms_twitch
  check_platforms_chatgpt
  check_platforms_netflix
  check_platforms_spotify
  check_platforms_reddit
  check_platforms_disney_plus
  check_platforms_tiktok
  check_platforms_apple
  check_platforms_steam
  check_platforms_microsoft
  check_platforms_ookla
  check_platforms_jetbrains
  check_platforms_playstation
)

readonly GROUP_CDN="cdn"
readonly CDN_CHECKS=(
  check_cdn_cloudflare
  check_cdn_youtube
  check_cdn_netflix
)

readonly GROUP_AVAILABILITY="availability"
readonly AVAILABILITY_CHECKS=(
  check_availability_youtube_premium
  check_availability_spotify_signup
  check_availability_disney_plus
  check_availability_reddit_guest
  check_availability_google_search
)

readonly GROUP_AI="ai"
readonly AI_CHECKS=(
  check_ai_gemini_web
  check_ai_gemini_api
  check_ai_openai_api
  check_ai_anthropic_api
  check_ai_grok_api
  check_ai_qwen
  check_ai_kimi
  check_ai_glm
  check_ai_minimax
  check_ai_doubao
  check_ai_siliconflow
  check_ai_deepseek
)

readonly GROUP_GEOIP="geoip"
readonly GEOIP_CHECKS=(
  check_geoip_maxmind
  check_geoip_ripe
  check_geoip_ipinfo_io
  check_geoip_cloudflare
  check_geoip_ipregistry_co
  check_geoip_ipapi_co
  check_geoip_ifconfig_co
  check_geoip_ip2location_io
  check_geoip_country_is
  check_geoip_geoapify_com
  check_geoip_geojs_io
  check_geoip_ipbase_com
  check_geoip_ipquery_io
  check_geoip_ipwho_is
  check_geoip_ip_api_com
)

readonly REASON_DIFFERENT_COUNTRY="different country"
readonly ATTENTION_COLLAPSE_MIN=3
# shellcheck disable=SC2016 # $yes, $platforms and $geoip are jq variables, not shell expansions
readonly VERDICT_FILTER='
def country_counts: group_by(.country) | map({country: .[0].country, count: length});
map(select(.status == $yes and (.group == $platforms or .group == $geoip)))
| group_by(.group)
| (map(length) | reduce .[] as $total (1; . * $total)) as $common_total
| map(($common_total / length) as $scale | country_counts | map(.weight = .count * $scale))
| add // []
| group_by(.country)
| map({country: .[0].country, weight: (map(.weight) | add)})
| (map(.weight) | max) as $top_weight
| map(select(.weight == $top_weight) | .country)
| .[]'
# shellcheck disable=SC2016 # $verdict, $collapse_min and the other names are jq variables, not shell expansions
readonly ATTENTION_FILTER='
def needs_attention:
  if .group == $cdn or .status == $none or .reason == $daily_limit then false
  elif .status == "" then true
  elif .group == $geoip then false
  elif .country != "" then $verdict != "" and .country != $verdict
  else .status != $yes end;
def severity:
  if .status == "" then 3 elif .country != "" then 0 elif .status == $no then 1 else 2 end;
to_entries
| map(.value + {order: .key} | select(needs_attention))
| map(if .status == $yes then .reason = $different_country else . end)
| group_by([.group, .service, .country, .status, .reason])
| map(.[0] + {ip_version: (if length == 2 then "both" else .[0].ip_version | tostring end)})
| group_by([.country, .status, .reason, .ip_version])
| map(if length >= $collapse_min then sort_by(.order) | [.[0] + {services: map(.service)}] else map(. + {services: [.service]}) end)
| add // []
| sort_by([(.services | length) >= $collapse_min, severity, .order])
| map({services, ip_version, country, status, reason})'

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
VERDICT_TIED_COUNTRIES=()
ATTENTION="[]"
WORK_DIR=""
EXTERNAL_IPV4=""
EXTERNAL_IPV6=""
CURL_ARGS=()
MAXMIND_TOKEN=""
JOB_COUNT=0
JOB_SLOTS_FD=""
PROGRESS_FRAME=0
RESULTS=""
declare -gA REGISTRATION_ASN=()
declare -gA REGISTRATION_ORG=()
declare -gA REGISTRATION_COUNTRY=()
declare -gA REGISTRATION_MAXMIND_FAILURE=()

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

stop_jobs() {
  local pid

  for pid in $(jobs -pr); do
    kill "$pid" 2>/dev/null || true
  done
}

cleanup() {
  stop_jobs

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

build_curl_args() {
  local ip_version="$1"

  CURL_ARGS=("${CURL_BASE_ARGS[@]}" --max-time "$CURL_TIMEOUT")

  if [[ -n "$PROXY_ADDR" ]]; then
    CURL_ARGS+=(--proxy "socks5h://$PROXY_ADDR")
  else
    CURL_ARGS+=("-$ip_version")
  fi

  if [[ -n "$INTERFACE_NAME" ]]; then
    CURL_ARGS+=(--interface "$INTERFACE_NAME")
  fi
}

fetch_to_cache() {
  local entry="$1"
  local ip_version="$2"
  local url="$3"
  shift 3
  local curl_exit=0

  build_curl_args "$ip_version"
  curl "${CURL_ARGS[@]}" --output "$entry.body" --write-out "$CURL_WRITE_OUT" "$@" "$url" >"$entry.meta" || curl_exit=$?
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

  HTTP_IP_VERSION="$ip_version"
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

is_ip_address() {
  local ip_version="$1"
  local ip="$2"

  case "$ip_version" in
    4) [[ "$ip" =~ $IPV4_PATTERN ]] ;;
    6) [[ "$ip" =~ $IPV6_PATTERN ]] ;;
  esac
}

print_identity_answer() {
  local ip_version="$1"
  local answers_dir="$2"
  local answer_file
  local answer

  for answer_file in "$answers_dir"/*; do
    if [[ ! -f "$answer_file" ]]; then
      continue
    fi

    answer=$(<"$answer_file")
    if is_ip_address "$ip_version" "$answer"; then
      printf '%s' "$answer"
      return 0
    fi
  done

  return 1
}

fetch_external_ip() {
  local ip_version="$1"
  local answers_dir="$WORK_DIR/identity-ipv$ip_version"
  local -a urls
  local -a pids=()
  local index

  case "$ip_version" in
    4) urls=("${IPV4_IDENTITY_URLS[@]}") ;;
    6) urls=("${IPV6_IDENTITY_URLS[@]}") ;;
  esac

  mkdir -p -- "$answers_dir"
  build_curl_args "$ip_version"
  for index in "${!urls[@]}"; do
    # curl runs directly, not via http_request: killing a wrapper subshell would leave its curl running until the timeout
    curl "${CURL_ARGS[@]}" --output "$answers_dir/$index" "${urls[$index]}" &
    pids+=("$!")
  done

  for index in "${!urls[@]}"; do
    wait -n || true
    if print_identity_answer "$ip_version" "$answers_dir"; then
      break
    fi
  done

  kill "${pids[@]}" 2>/dev/null || true
  wait
}

discover_external_ips() {
  local ipv4_file="$WORK_DIR/external-ipv4"
  local ipv6_file="$WORK_DIR/external-ipv6"

  : >"$ipv4_file"
  : >"$ipv6_file"

  if [[ "$IPV6_ONLY" != true ]]; then
    fetch_external_ip 4 >"$ipv4_file" &
  fi

  if [[ "$IPV4_ONLY" != true ]]; then
    fetch_external_ip 6 >"$ipv6_file" &
  fi

  wait
  EXTERNAL_IPV4=$(<"$ipv4_file")
  EXTERNAL_IPV6=$(<"$ipv6_file")

  if [[ -z "$EXTERNAL_IPV4" && -z "$EXTERNAL_IPV6" ]]; then
    printf 'Error: failed to detect an external IP address, check the network connection\n' >&2
    exit 1
  fi
}

mask_ipv4() {
  local ip="$1"

  printf '%s.*.*' "${ip%.*.*}"
}

mask_ipv6() {
  local ip="$1"
  local head="${ip%%::*}"
  local tail=""
  local -a left right groups
  local missing

  if [[ "$ip" == *::* ]]; then
    tail="${ip#*::}"
  fi

  IFS=: read -ra left <<<"$head"
  IFS=: read -ra right <<<"$tail"
  missing=$((IPV6_GROUP_COUNT - ${#left[@]} - ${#right[@]}))
  groups=("${left[@]}")
  while ((missing-- > 0)); do
    groups+=(0)
  done
  groups+=("${right[@]}")

  printf '%s:%s:%s::' "${groups[@]:0:3}"
}

json_value() {
  local filter="$1"

  jq -r "$filter" <<<"$HTTP_BODY" 2>/dev/null || true
}

request_maxmind_token() {
  local ip_version="$1"
  local cookie_jar="$WORK_DIR/maxmind-cookies"
  local csrf_token

  http_request "$ip_version" "$MAXMIND_DEMO_PAGE_URL" --cookie-jar "$cookie_jar"
  if [[ ! "$HTTP_BODY" =~ $MAXMIND_CSRF_PATTERN ]]; then
    return
  fi
  csrf_token="${BASH_REMATCH[1]}"

  http_request "$ip_version" "$MAXMIND_TOKEN_URL" --request POST --cookie "$cookie_jar" --header "X-CSRF-Token: $csrf_token"
  if [[ "$HTTP_CODE" != "$HTTP_CREATED" ]]; then
    return
  fi

  MAXMIND_TOKEN=$(json_value '.token // empty')
}

fetch_maxmind_city() {
  local ip_version="$1"
  local ip="$2"

  http_request "$ip_version" "$MAXMIND_CITY_URL/$ip?demo=1" --header "Authorization: Bearer $MAXMIND_TOKEN"
}

maxmind_failure_reason() {
  local reason

  reason=$(http_failure_reason)
  if [[ -n "$reason" ]]; then
    printf '%s' "$reason"
    return
  fi

  case "$HTTP_CODE" in
    "$HTTP_OK") ;;
    "$HTTP_PAYMENT_REQUIRED") printf '%s' "$REASON_DAILY_LIMIT" ;;
    *) printf '%s (%s)' "$REASON_UNEXPECTED_RESPONSE" "$HTTP_CODE" ;;
  esac
}

lookup_maxmind_registration() {
  local ip_version="$1"
  local ip="$2"
  local failure

  if [[ -z "$MAXMIND_TOKEN" ]]; then
    REGISTRATION_MAXMIND_FAILURE[$ip_version]="$REASON_NO_DEMO_TOKEN"
    return 1
  fi

  fetch_maxmind_city "$ip_version" "$ip"
  failure=$(maxmind_failure_reason)
  if [[ -n "$failure" ]]; then
    REGISTRATION_MAXMIND_FAILURE[$ip_version]="$failure"
    return 1
  fi

  REGISTRATION_ASN[$ip_version]=$(json_value '.traits.autonomous_system_number // empty')
  REGISTRATION_ORG[$ip_version]=$(json_value '.traits.autonomous_system_organization // empty')
  REGISTRATION_COUNTRY[$ip_version]=$(json_value '.registered_country.iso_code // empty')
}

lookup_ripe_registration() {
  local ip_version="$1"
  local ip="$2"

  http_request "$ip_version" "$RIPE_RDAP_IP_URL/$ip" --location
  REGISTRATION_COUNTRY[$ip_version]=$(json_value '.country // empty')

  http_request "$ip_version" "$RIPESTAT_PREFIX_OVERVIEW_URL?resource=$ip"
  REGISTRATION_ASN[$ip_version]=$(json_value '.data.asns[0].asn // empty')
  REGISTRATION_ORG[$ip_version]=$(json_value '.data.asns[0].holder // empty | sub("^\\S+ (- )?"; "")')
}

lookup_ip_registration() {
  local ip_version="$1"
  local ip="$2"

  if lookup_maxmind_registration "$ip_version" "$ip"; then
    return
  fi

  lookup_ripe_registration "$ip_version" "$ip"
}

lookup_ip_registrations() {
  local token_ip_version=4

  if [[ -z "$EXTERNAL_IPV4" ]]; then
    token_ip_version=6
  fi

  request_maxmind_token "$token_ip_version"

  if [[ -n "$EXTERNAL_IPV4" ]]; then
    lookup_ip_registration 4 "$EXTERNAL_IPV4"
  fi

  if [[ -n "$EXTERNAL_IPV6" ]]; then
    lookup_ip_registration 6 "$EXTERNAL_IPV6"
  fi
}

print_result() {
  local group="$1"
  local service="$2"
  local ip_version="$3"
  local country="$4"
  local status="$5"
  local reason="$6"

  jq -cn \
    --arg group "$group" \
    --arg service "$service" \
    --argjson ip_version "$ip_version" \
    --arg country "$country" \
    --arg status "$status" \
    --arg reason "$reason" \
    '$ARGS.named'
}

count_running_jobs() {
  jobs -pr | wc -l
}

print_progress_bar() {
  local finished="$1"
  local done_width=$((PROGRESS_BAR_WIDTH * finished / JOB_COUNT))
  local done_part left_part

  printf -v done_part '%*s' "$done_width" ''
  printf -v left_part '%*s' "$((PROGRESS_BAR_WIDTH - done_width))" ''
  printf '%s%s%s%s' "${done_part// /$PROGRESS_BAR_DONE}" "$C_DIM" "${left_part// /$PROGRESS_BAR_LEFT}" "$C_RESET"
}

draw_progress() {
  local finished
  local spinner

  if [[ ! -t 2 ]]; then
    return
  fi

  finished=$((JOB_COUNT - $(count_running_jobs)))
  spinner="${PROGRESS_SPINNER_FRAMES[PROGRESS_FRAME % ${#PROGRESS_SPINNER_FRAMES[@]}]}"
  PROGRESS_FRAME=$((PROGRESS_FRAME + 1))
  printf '%s%s %s  %s  %s%d/%d%s' "$CLEAR_LINE" "$spinner" "$PROGRESS_LABEL" "$(print_progress_bar "$finished")" \
    "$C_DIM" "$finished" "$JOB_COUNT" "$C_RESET" >&2
}

clear_progress() {
  if [[ ! -t 2 ]]; then
    return
  fi

  printf '%s' "$CLEAR_LINE" >&2
}

create_job_slots() {
  local slots_fifo="$WORK_DIR/job-slots"
  local slots

  mkfifo -- "$slots_fifo"
  exec {JOB_SLOTS_FD}<>"$slots_fifo"
  printf -v slots '%*s' "$MAX_PARALLEL_JOBS" ''
  printf '%s' "$slots" >&"$JOB_SLOTS_FD"
}

take_job_slot() {
  local slot

  read -r -N 1 -u "$JOB_SLOTS_FD" slot
}

return_job_slot() {
  printf ' ' >&"$JOB_SLOTS_FD"
}

run_job() {
  local result_file="$1"
  shift

  take_job_slot
  trap return_job_slot EXIT
  "$@" >"$result_file"
}

start_job() {
  local result_file

  JOB_COUNT=$((JOB_COUNT + 1))
  printf -v result_file '%s/%s%04d' "$WORK_DIR" "$RESULT_FILE_PREFIX" "$JOB_COUNT"
  run_job "$result_file" "$@" &
}

start_check() {
  local check="$1"

  if [[ -n "$EXTERNAL_IPV4" ]]; then
    start_job "$check" 4
  fi

  if [[ -n "$EXTERNAL_IPV6" ]]; then
    start_job "$check" 6
  fi
}

is_check_selected() {
  local check="$1"
  local group="${check#check_}"

  group="${group%%_*}"
  [[ "$SELECTED_GROUP" == "$ALL_GROUPS" || "$SELECTED_GROUP" == "$group" ]]
}

external_ip() {
  local ip_version="$1"

  case "$ip_version" in
    4) printf '%s' "$EXTERNAL_IPV4" ;;
    6) printf '%s' "$EXTERNAL_IPV6" ;;
  esac
}

is_service_without_ipv6() {
  if [[ "$HTTP_IP_VERSION" != 6 || -n "$PROXY_ADDR" ]]; then
    return 1
  fi

  [[ "$HTTP_CURL_EXIT" == "$CURL_EXIT_DNS" || "$HTTP_CURL_EXIT" == "$CURL_EXIT_CONNECT" ]]
}

print_failure() {
  local group="$1"
  local service="$2"
  local ip_version="$3"
  local reason="$4"

  print_result "$group" "$service" "$ip_version" "" "" "$reason"
}

print_country() {
  local group="$1"
  local service="$2"
  local ip_version="$3"
  local country="$4"
  local reason

  if is_service_without_ipv6; then
    print_result "$group" "$service" "$ip_version" "" "$STATUS_NONE" "$REASON_NO_IPV6"
    return
  fi

  reason=$(http_failure_reason)
  if [[ -n "$reason" ]]; then
    print_failure "$group" "$service" "$ip_version" "$reason"
    return
  fi

  if [[ ! "$country" =~ $COUNTRY_CODE_PATTERN ]]; then
    print_failure "$group" "$service" "$ip_version" "$REASON_UNEXPECTED_RESPONSE"
    return
  fi

  print_result "$group" "$service" "$ip_version" "$country" "$STATUS_YES" ""
}

print_status() {
  local group="$1"
  local service="$2"
  local ip_version="$3"
  local status="$4"
  local reason

  if is_service_without_ipv6; then
    print_result "$group" "$service" "$ip_version" "" "$STATUS_NONE" "$REASON_NO_IPV6"
    return
  fi

  reason=$(http_failure_reason)
  if [[ -n "$status" ]]; then
    print_result "$group" "$service" "$ip_version" "" "$status" "$reason"
    return
  fi

  print_failure "$group" "$service" "$ip_version" "${reason:-$REASON_UNEXPECTED_RESPONSE}"
}

check_geoip_json() {
  local service="$1"
  local ip_version="$2"
  local transport="$3"
  local url="$4"
  local filter="$5"
  shift 5

  http_request "$transport" "$url" "$@"
  print_country "$GROUP_GEOIP" "$service" "$ip_version" "$(json_value "$filter")"
}

check_geoip_maxmind() {
  local ip_version="$1"
  local failure

  if [[ -z "$MAXMIND_TOKEN" ]]; then
    print_failure "$GROUP_GEOIP" MaxMind "$ip_version" "$REASON_NO_DEMO_TOKEN"
    return
  fi

  fetch_maxmind_city "$ip_version" "$(external_ip "$ip_version")"
  failure=$(maxmind_failure_reason)
  if [[ -n "$failure" ]]; then
    print_failure "$GROUP_GEOIP" MaxMind "$ip_version" "$failure"
    return
  fi

  print_country "$GROUP_GEOIP" MaxMind "$ip_version" "$(json_value '.country.iso_code // empty')"
}

check_geoip_ripe() {
  local ip_version="$1"

  check_geoip_json RIPE "$ip_version" "$ip_version" "$RIPE_RDAP_IP_URL/$(external_ip "$ip_version")" '.country // empty' --location
}

check_geoip_ipinfo_io() {
  local ip_version="$1"
  local url

  case "$ip_version" in
    4) url="$IPINFO_IPV4_URL" ;;
    6) url="$IPINFO_IPV6_URL" ;;
  esac

  check_geoip_json ipinfo.io "$ip_version" "$ip_version" "$url/$(external_ip "$ip_version")" '.data.country // empty'
}

check_geoip_cloudflare() {
  local ip_version="$1"
  local country=""

  http_request "$ip_version" "$CLOUDFLARE_TRACE_URL"
  if [[ "$HTTP_BODY" =~ $CLOUDFLARE_COUNTRY_PATTERN ]]; then
    country="${BASH_REMATCH[2]}"
  fi

  print_country "$GROUP_GEOIP" Cloudflare "$ip_version" "$country"
}

check_geoip_ipregistry_co() {
  local ip_version="$1"

  check_geoip_json ipregistry.co "$ip_version" "$ip_version" \
    "$IPREGISTRY_URL/$(external_ip "$ip_version")?hostname=true&key=$IPREGISTRY_KEY" '.location.country.code // empty' \
    --header "Origin: $IPREGISTRY_ORIGIN"
}

check_geoip_ipapi_co() {
  local ip_version="$1"

  check_geoip_json ipapi.co "$ip_version" "$ip_version" "$IPAPI_CO_URL/$(external_ip "$ip_version")/json" '.country // empty' \
    --header "Referer: $IPAPI_CO_REFERER"
}

check_geoip_ifconfig_co() {
  local ip_version="$1"

  http_request "$ip_version" "$IFCONFIG_CO_URL?ip=$(external_ip "$ip_version")"
  print_country "$GROUP_GEOIP" ifconfig.co "$ip_version" "$HTTP_BODY"
}

check_geoip_ip2location_io() {
  local ip_version="$1"

  check_geoip_json ip2location.io "$ip_version" "$ip_version" "$IP2LOCATION_URL?ip=$(external_ip "$ip_version")" '.country_code // empty'
}

check_geoip_country_is() {
  local ip_version="$1"

  check_geoip_json country.is "$ip_version" "$ip_version" "$COUNTRY_IS_URL/$(external_ip "$ip_version")" '.country // empty'
}

check_geoip_geoapify_com() {
  local ip_version="$1"

  check_geoip_json geoapify.com "$ip_version" "$ip_version" \
    "$GEOAPIFY_URL?ip=$(external_ip "$ip_version")&apiKey=$GEOAPIFY_KEY" '.country.iso_code // empty'
}

check_geoip_geojs_io() {
  local ip_version="$1"

  check_geoip_json geojs.io "$ip_version" "$ip_version" "$GEOJS_URL?ip=$(external_ip "$ip_version")" '.[0].country // empty'
}

check_geoip_ipbase_com() {
  local ip_version="$1"

  check_geoip_json ipbase.com "$ip_version" "$ip_version" "$IPBASE_URL?ip=$(external_ip "$ip_version")" '.data.location.country.alpha2 // empty'
}

check_geoip_ipquery_io() {
  local ip_version="$1"

  check_geoip_json ipquery.io "$ip_version" "$ip_version" "$IPQUERY_URL/$(external_ip "$ip_version")" '.location.country_code // empty'
}

check_geoip_ipwho_is() {
  local ip_version="$1"

  check_geoip_json ipwho.is "$ip_version" "$ip_version" "$IPWHO_URL/$(external_ip "$ip_version")" '.country_code // empty'
}

check_geoip_ip_api_com() {
  local ip_version="$1"

  check_geoip_json ip-api.com "$ip_version" "$IPV4_TRANSPORT" "$IP_API_URL/$(external_ip "$ip_version")?fields=countryCode" '.countryCode // empty' \
    --header "Origin: $IP_API_ORIGIN"
}

check_platforms_json() {
  local service="$1"
  local ip_version="$2"
  local url="$3"
  local filter="$4"
  shift 4

  http_request "$ip_version" "$url" "$@"
  print_country "$GROUP_PLATFORMS" "$service" "$ip_version" "$(json_value "$filter")"
}

check_platforms_pattern() {
  local service="$1"
  local ip_version="$2"
  local url="$3"
  local pattern="$4"
  shift 4
  local country=""

  http_request "$ip_version" "$url" "$@"
  if [[ "$HTTP_BODY" =~ $pattern ]]; then
    country="${BASH_REMATCH[1]}"
  fi

  print_country "$GROUP_PLATFORMS" "$service" "$ip_version" "$country"
}

check_platforms_google() {
  local ip_version="$1"

  check_platforms_pattern Google "$ip_version" "$GOOGLE_URL" "$GOOGLE_COUNTRY_PATTERN" --user-agent "$USER_AGENT"
}

check_platforms_youtube() {
  local ip_version="$1"
  local country

  http_request "$ip_version" "$YOUTUBE_URL"
  country=$(jq -r '.[0][2][0][0][1] // empty' <<<"${HTTP_BODY#"$YOUTUBE_JSON_PREFIX"}" 2>/dev/null || true)
  print_country "$GROUP_PLATFORMS" YouTube "$ip_version" "$country"
}

check_platforms_twitch() {
  local ip_version="$1"

  check_platforms_json Twitch "$ip_version" "$TWITCH_URL" '.[0].data.requestInfo.countryCode // empty' \
    --header "Client-Id: $TWITCH_CLIENT_ID" --json "$TWITCH_QUERY"
}

check_platforms_chatgpt() {
  local ip_version="$1"

  check_platforms_pattern ChatGPT "$ip_version" "$CHATGPT_URL" "$CHATGPT_COUNTRY_PATTERN" \
    --request POST --header "Statsig-Api-Key: $CHATGPT_STATSIG_API_KEY"
}

check_platforms_netflix() {
  local ip_version="$1"

  check_platforms_json Netflix "$ip_version" "$NETFLIX_URL" '.client.location.country // empty'
}

check_platforms_spotify() {
  local ip_version="$1"

  check_platforms_json Spotify "$ip_version" "$SPOTIFY_URL" '.country // empty' --header "X-Client-Id: $SPOTIFY_CLIENT_ID"
}

check_platforms_reddit() {
  local ip_version="$1"

  check_platforms_pattern Reddit "$ip_version" "$REDDIT_URL" "$REDDIT_COUNTRY_PATTERN" --user-agent "$USER_AGENT"
}

check_platforms_disney_plus() {
  local ip_version="$1"

  check_platforms_json Disney+ "$ip_version" "$DISNEY_PLUS_URL" '.extensions.sdk.session.location.countryCode // empty' \
    --header "Authorization: Bearer $DISNEY_PLUS_API_KEY" --json "$DISNEY_PLUS_QUERY"
}

check_platforms_tiktok() {
  local ip_version="$1"

  check_platforms_json TikTok "$ip_version" "$TIKTOK_URL" '.body.appProps.region // empty'
}

check_platforms_apple() {
  local ip_version="$1"

  http_request "$ip_version" "$APPLE_URL"
  print_country "$GROUP_PLATFORMS" Apple "$ip_version" "$HTTP_BODY"
}

check_platforms_steam() {
  local ip_version="$1"

  check_platforms_pattern Steam "$ip_version" "$STEAM_URL" "$STEAM_COUNTRY_PATTERN" --head
}

check_platforms_microsoft() {
  local ip_version="$1"

  check_platforms_pattern Microsoft "$ip_version" "$MICROSOFT_URL" "$MICROSOFT_COUNTRY_PATTERN"
}

check_platforms_ookla() {
  local ip_version="$1"

  check_platforms_json Ookla "$ip_version" "$OOKLA_URL" '.location.countryCode // empty'
}

check_platforms_jetbrains() {
  local ip_version="$1"

  check_platforms_json JetBrains "$ip_version" "$JETBRAINS_URL" '.code // empty'
}

check_platforms_playstation() {
  local ip_version="$1"

  check_platforms_pattern PlayStation "$ip_version" "$PLAYSTATION_URL" "$PLAYSTATION_COUNTRY_PATTERN" --head
}

print_edge() {
  local service="$1"
  local ip_version="$2"
  local country="$3"
  local iata="$4"
  local node="$5"

  print_country "$GROUP_CDN" "$service" "$ip_version" "$country" |
    jq -c --arg iata "$iata" --arg node "$node" '. + {iata: $iata, node: $node}'
}

iata_country() {
  local iata="$1"

  if [[ -z "$iata" ]]; then
    return
  fi

  http_request "$IPV4_TRANSPORT" "$AIRPORT_CODES_URL" \
    --header "APC-Auth: $AIRPORT_CODES_KEY" --header "Referer: $AIRPORT_CODES_REFERER" --data "iata=$iata"
  json_value '.airport.country.iso // empty'
}

youtube_node_iata() {
  local node="$1"

  if [[ "$node" =~ $GOOGLE_NODE_PATTERN || "$node" =~ $ISP_NODE_PATTERN || "$node" =~ $GGC_NODE_PATTERN ]]; then
    printf '%s' "${BASH_REMATCH[1]^^}"
  fi
}

check_cdn_cloudflare() {
  local ip_version="$1"

  http_request "$ip_version" "$CLOUDFLARE_SPEED_META_URL" --header "Referer: $CLOUDFLARE_SPEED_REFERER"
  print_edge Cloudflare "$ip_version" "$(json_value '.colo.cca2 // empty')" "$(json_value '.colo.iata // empty')" ""
}

check_cdn_youtube() {
  local ip_version="$1"
  local node=""
  local iata

  http_request "$ip_version" "$YOUTUBE_CDN_MAPPING_URL"
  if [[ "$HTTP_BODY" =~ $YOUTUBE_CDN_NODE_PATTERN ]]; then
    node="${BASH_REMATCH[1]}"
  fi

  iata=$(youtube_node_iata "$node")
  print_edge YouTube "$ip_version" "$(iata_country "$iata")" "$iata" "$node"
}

check_cdn_netflix() {
  local ip_version="$1"
  local node=""
  local iata=""

  http_request "$ip_version" "$NETFLIX_URL"
  if [[ "$(json_value '.targets[0].url // empty')" =~ $NETFLIX_CDN_URL_PATTERN ]]; then
    node="${BASH_REMATCH[1]}"
    iata="${BASH_REMATCH[2]^^}"
  fi

  print_edge Netflix "$ip_version" "$(json_value '.targets[0].location.country // empty')" "$iata" "$node"
}

youtube_premium_status() {
  if [[ "$HTTP_CODE" != "$HTTP_OK" ]]; then
    return
  fi

  if [[ "$HTTP_BODY" == *"$YOUTUBE_PREMIUM_BLOCKED_MARKER"* ]]; then
    printf '%s' "$STATUS_NO"
    return
  fi

  printf '%s' "$STATUS_YES"
}

check_availability_youtube_premium() {
  local ip_version="$1"

  http_request "$ip_version" "$YOUTUBE_PREMIUM_URL" \
    --user-agent "$USER_AGENT" --header "$GOOGLE_SOCS_COOKIE" --header "$ACCEPT_LANGUAGE_ENGLISH"
  print_status "$GROUP_AVAILABILITY" "YouTube Premium" "$ip_version" "$(youtube_premium_status)"
}

spotify_signup_status() {
  if [[ "$(json_value '.status')" =~ $SPOTIFY_SIGNUP_BLOCKED_STATUS_PATTERN ]]; then
    printf '%s' "$STATUS_NO"
    return
  fi

  case "$(json_value '.is_country_launched')" in
    true) printf '%s' "$STATUS_YES" ;;
    false) printf '%s' "$STATUS_NO" ;;
  esac
}

check_availability_spotify_signup() {
  local ip_version="$1"

  http_request "$ip_version" "$SPOTIFY_URL" --header "X-Client-Id: $SPOTIFY_CLIENT_ID"
  print_status "$GROUP_AVAILABILITY" "Spotify Signup" "$ip_version" "$(spotify_signup_status)"
}

disney_plus_status() {
  case "$(json_value '.extensions.sdk.session.inSupportedLocation')" in
    true)
      printf '%s' "$STATUS_YES"
      return
      ;;
    false)
      printf '%s' "$STATUS_NO"
      return
      ;;
  esac

  if [[ "$(json_value '.errors[0].message // empty')" == *"$DISNEY_PLUS_FORBIDDEN_MARKER"* ]]; then
    printf '%s' "$STATUS_NO"
  fi
}

check_availability_disney_plus() {
  local ip_version="$1"

  http_request "$ip_version" "$DISNEY_PLUS_URL" \
    --header "Authorization: Bearer $DISNEY_PLUS_API_KEY" --json "$DISNEY_PLUS_QUERY"
  print_status "$GROUP_AVAILABILITY" Disney+ "$ip_version" "$(disney_plus_status)"
}

reddit_guest_status() {
  case "$HTTP_CODE" in
    "$HTTP_OK") printf '%s' "$STATUS_YES" ;;
    "$HTTP_FORBIDDEN") printf '%s' "$STATUS_IPBLOCK" ;;
  esac
}

check_availability_reddit_guest() {
  local ip_version="$1"

  http_request "$ip_version" "$REDDIT_GUEST_URL" --user-agent "$USER_AGENT"
  print_status "$GROUP_AVAILABILITY" "Reddit Guest" "$ip_version" "$(reddit_guest_status)"
}

google_search_status() {
  if [[ "$HTTP_REDIRECT_URL" == *"$GOOGLE_SEARCH_CAPTCHA_PATH"* || "$HTTP_CODE" == "$HTTP_TOO_MANY_REQUESTS" ]]; then
    printf '%s' "$STATUS_NO"
    return
  fi

  if [[ "$HTTP_CODE" == "$HTTP_OK" && "$HTTP_BODY" == *"$GOOGLE_SEARCH_NO_JS_MARKER"* ]]; then
    printf '%s' "$STATUS_YES"
  fi
}

check_availability_google_search() {
  local ip_version="$1"

  http_request "$ip_version" "$GOOGLE_SEARCH_URL" \
    --user-agent "$USER_AGENT" --header "$GOOGLE_SOCS_COOKIE" --header "$ACCEPT_LANGUAGE_ENGLISH"
  print_status "$GROUP_AVAILABILITY" "Google Search" "$ip_version" "$(google_search_status)"
}

gemini_status() {
  local country="$1"
  local regions="$2"

  jq -r --arg code "$country" --argjson regions "$regions" --arg yes "$STATUS_YES" --arg no "$STATUS_NO" \
    "$GEMINI_MATCH_FILTER" <<<"$HTTP_BODY" 2>/dev/null || true
}

check_ai_gemini() {
  local service="$1"
  local ip_version="$2"
  local regions_url="$3"
  local regions_filter="$4"
  local regions
  local country=""

  http_request "$ip_version" "$regions_url"
  regions=$(jq -Rsc "$regions_filter | select(length > 0)" <<<"$HTTP_BODY" 2>/dev/null || true)
  if [[ -z "$regions" ]]; then
    print_status "$GROUP_AI" "$service" "$ip_version" ""
    return
  fi

  http_request "$ip_version" "$GOOGLE_URL" --user-agent "$USER_AGENT"
  if [[ "$HTTP_BODY" =~ $GOOGLE_COUNTRY_PATTERN ]]; then
    country="${BASH_REMATCH[1]}"
  fi

  if [[ ! "$country" =~ $COUNTRY_CODE_PATTERN ]]; then
    print_status "$GROUP_AI" "$service" "$ip_version" ""
    return
  fi

  http_request "$ip_version" "$CLDR_TERRITORIES_URL"
  print_status "$GROUP_AI" "$service" "$ip_version" "$(gemini_status "$country" "$regions")"
}

check_ai_gemini_web() {
  local ip_version="$1"

  check_ai_gemini "Gemini Web" "$ip_version" "$GEMINI_WEB_REGIONS_URL" "$GEMINI_WEB_REGIONS_FILTER"
}

check_ai_gemini_api() {
  local ip_version="$1"

  check_ai_gemini "Gemini API" "$ip_version" "$GEMINI_API_REGIONS_URL" "$GEMINI_API_REGIONS_FILTER"
}

ai_api_status() {
  local region_blocked_marker="$1"

  if [[ "$HTTP_CODE" == "$HTTP_UNAUTHORIZED" ]]; then
    printf '%s' "$STATUS_YES"
    return
  fi

  if [[ "$HTTP_CODE" != "$HTTP_FORBIDDEN" ]]; then
    return
  fi

  if [[ "$HTTP_BODY" == *"$region_blocked_marker"* ]]; then
    printf '%s' "$STATUS_NO"
    return
  fi

  printf '%s' "$STATUS_IPBLOCK"
}

check_ai_api() {
  local service="$1"
  local ip_version="$2"
  local url="$3"
  local region_blocked_marker="$4"

  http_request "$ip_version" "$url"
  print_status "$GROUP_AI" "$service" "$ip_version" "$(ai_api_status "$region_blocked_marker")"
}

check_ai_openai_api() {
  local ip_version="$1"

  check_ai_api "OpenAI API" "$ip_version" "$OPENAI_API_URL" "$OPENAI_API_REGION_BLOCKED_MARKER"
}

check_ai_anthropic_api() {
  local ip_version="$1"

  check_ai_api "Anthropic API" "$ip_version" "$ANTHROPIC_API_URL" "$ANTHROPIC_API_REGION_BLOCKED_MARKER"
}

check_ai_grok_api() {
  local ip_version="$1"

  check_ai_api "Grok API" "$ip_version" "$GROK_API_URL" "$GROK_API_REGION_BLOCKED_MARKER"
}

reachability_status() {
  if [[ "$HTTP_CODE" == "$HTTP_UNAUTHORIZED" ]]; then
    printf '%s' "$STATUS_YES"
  fi
}

check_ai_reachability() {
  local service="$1"
  local ip_version="$2"
  local url="$3"

  http_request "$ip_version" "$url"
  print_status "$GROUP_AI" "$service" "$ip_version" "$(reachability_status)"
}

check_ai_qwen() {
  local ip_version="$1"

  check_ai_reachability Qwen "$ip_version" "$QWEN_API_URL"
}

check_ai_kimi() {
  local ip_version="$1"

  check_ai_reachability Kimi "$ip_version" "$KIMI_API_URL"
}

check_ai_glm() {
  local ip_version="$1"

  check_ai_reachability GLM "$ip_version" "$GLM_API_URL"
}

check_ai_minimax() {
  local ip_version="$1"

  check_ai_reachability MiniMax "$ip_version" "$MINIMAX_API_URL"
}

check_ai_doubao() {
  local ip_version="$1"

  check_ai_reachability Doubao "$ip_version" "$DOUBAO_API_URL"
}

check_ai_siliconflow() {
  local ip_version="$1"

  check_ai_reachability SiliconFlow "$ip_version" "$SILICONFLOW_API_URL"
}

check_ai_deepseek() {
  local ip_version="$1"

  check_ai_reachability DeepSeek "$ip_version" "$DEEPSEEK_API_URL"
}

start_checks() {
  local check

  for check in "$@"; do
    if is_check_selected "$check"; then
      start_check "$check"
    fi
  done
}

wait_for_jobs() {
  while (($(count_running_jobs) > 0)); do
    draw_progress
    sleep "$JOB_POLL_INTERVAL"
  done

  clear_progress
}

collect_results() {
  if ((JOB_COUNT == 0)); then
    RESULTS="[]"
    return
  fi

  RESULTS=$(jq -cs . "$WORK_DIR/$RESULT_FILE_PREFIX"*)
}

compute_verdict() {
  local -a leaders

  mapfile -t leaders < <(
    jq -r \
      --arg yes "$STATUS_YES" \
      --arg platforms "$GROUP_PLATFORMS" \
      --arg geoip "$GROUP_GEOIP" \
      "$VERDICT_FILTER" <<<"$RESULTS"
  )

  VERDICT=""
  VERDICT_TIED_COUNTRIES=()
  if ((${#leaders[@]} > 1)); then
    VERDICT_TIED_COUNTRIES=("${leaders[@]}")
    return
  fi

  VERDICT="${leaders[0]:-}"
}

collect_attention() {
  ATTENTION=$(
    jq -c \
      --arg verdict "$VERDICT" \
      --arg yes "$STATUS_YES" \
      --arg no "$STATUS_NO" \
      --arg none "$STATUS_NONE" \
      --arg cdn "$GROUP_CDN" \
      --arg geoip "$GROUP_GEOIP" \
      --arg different_country "$REASON_DIFFERENT_COUNTRY" \
      --arg daily_limit "$REASON_DAILY_LIMIT" \
      --argjson collapse_min "$ATTENTION_COLLAPSE_MIN" \
      "$ATTENTION_FILTER" <<<"$RESULTS"
  )
}

main() {
  parse_args "$@"
  validate_args
  create_work_dir
  create_job_slots
  discover_external_ips
  lookup_ip_registrations
  start_checks "${PLATFORMS_CHECKS[@]}"
  start_checks "${CDN_CHECKS[@]}"
  start_checks "${AVAILABILITY_CHECKS[@]}"
  start_checks "${AI_CHECKS[@]}"
  start_checks "${GEOIP_CHECKS[@]}"
  wait_for_jobs
  collect_results
  compute_verdict
  collect_attention
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
  main "$@"
fi
