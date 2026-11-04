#!/usr/bin/env bash

# Shows how GeoIP databases, popular platforms, CDNs and AI services see this host over IPv4 and IPv6.

set -euo pipefail
shopt -s extglob

readonly MIN_BASH_MAJOR=4
readonly MIN_BASH_MINOR=4

# Runs before the other constants: bash 3.2 (macOS) fails on readonly -A below.
require_bash_version() {
  local major="$1"
  local minor="$2"

  if ((major > MIN_BASH_MAJOR || (major == MIN_BASH_MAJOR && minor >= MIN_BASH_MINOR))); then
    return
  fi

  printf 'Error: bash %s.%s+ is required, this is bash %s.%s\n' "$MIN_BASH_MAJOR" "$MIN_BASH_MINOR" "$major" "$minor" >&2
  if [[ "$OSTYPE" == darwin* ]]; then
    printf 'Install a newer one with: brew install bash, then run the script again in a new terminal\n' >&2
  fi
  exit 1
}

require_bash_version "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"

readonly SCRIPT_NAME="ipregion.sh"
readonly SCRIPT_URL="https://github.com/vernette/ipregion"
readonly REQUIRED_COMMANDS=(curl jq)
readonly PACKAGE_MANAGERS=(apt-get dnf yum pacman zypper apk xbps-install)
readonly SERVICE_GROUPS=(platforms cdn availability ai geoip)
readonly ALL_GROUPS="all"
readonly DEFAULT_TIMEOUT=5
readonly TIMEOUT_PATTERN='^[1-9][0-9]*$'
readonly DEFAULT_YOUTUBE_LANG="ru"
readonly YOUTUBE_LANG_PATTERN='^[a-z]{2,3}(-[A-Za-z0-9]{2,4})?$'
readonly PROXY_PATTERN='^([^:/[:space:]]+|\[[0-9A-Fa-f:]+\]):[0-9]{1,5}$'
readonly COUNTRY_CODE_PATTERN='^[A-Z]{2}$'
readonly REGIONAL_INDICATOR_A=0x1F1E6
readonly ASCII_A=65
readonly UTF8_LOCALE="C.UTF-8"
# A bracket range like [🌀-🫿] follows the locale collation and misses emoji under en_US.UTF-8 on glibc 2.36
readonly WIDE_EMOJI_PATTERN='[🚨📱🌍🔓🤖📡✅]'
readonly FLAG_WIDTH=3
readonly -A GROUP_EMOJI=(
  ["Attention"]=🚨
  ["Platforms"]=📱
  ["GeoIP"]=🌍
  ["Availability"]=🔓
  ["AI"]=🤖
  ["CDN"]=📡
)

readonly ANSI_SEQUENCE=$'\033\[+([0-9;])m'
readonly CARD_GAP=1
readonly WIDE_LEFT_CARD_WIDTH=40
readonly WIDE_RIGHT_CARD_WIDTH=39
readonly CARD_CONTENT_INDENT=1
readonly LEGEND_INDENT=3
readonly CARD_SIDES_WIDTH=2
readonly CARD_TRAILING_GAP=1
readonly CARD_TITLE_OFFSET=1
readonly LEFT_GRID_NAME=19
readonly LEFT_GRID_CELL=8
readonly RIGHT_GRID_NAME=18
readonly RIGHT_GRID_CELL=8
readonly CARD_TOP_LEFT="╭"
readonly CARD_TOP_RIGHT="╮"
readonly CARD_BOTTOM_LEFT="╰"
readonly CARD_BOTTOM_RIGHT="╯"
readonly CARD_SIDE="│"
readonly CARD_HORIZONTAL="─"
readonly NAME_GAP=2
readonly GEOIP_COUNTRY_WIDTH=4
readonly HEADER_LABEL_WIDTH=6
readonly CHECKS_BAR_MARGIN=26
readonly SUMMARY_BAR_CHAR="━"
readonly SUMMARY_BAR_REST_CHAR="─"
readonly ATTENTION_LIST_LINES=2
readonly ATTENTION_EMPTY_CELL="·"
readonly GROUP_ROW_FIELDS=3
readonly CDN_ROW_FIELDS=9
readonly ATTENTION_ENTRY_FIELDS=5
readonly GEOIP_DEVIATION_FIELDS=3
readonly HEADER_MARK="┃"
readonly AUTHOR="vernette"
readonly VERDICT_NOTE="seen by most services"
readonly TIE_NOTE="services split evenly"
readonly CHECKS_PASSED_NOTE="checks passed"
readonly CHECKS_GOOD_PERCENT=85
readonly CHECKS_FAIR_PERCENT=65
readonly CHECKS_GOOD="good"
readonly CHECKS_FAIR="fair"
readonly CHECKS_POOR="poor"
readonly REGISTERED_NOTE="registered in"
readonly MAXMIND_LIMIT_HEADER_NOTE="MaxMind daily limit used up · ASN from RIPE"
readonly MAXMIND_FAILURE_HEADER_NOTE="MaxMind unavailable · ASN from RIPE"
readonly MAXMIND_LIMIT_SUMMARY_NOTE="MaxMind limit used up"
readonly GEOIP_AGREEMENT_NOTE="every service agrees"
readonly GEOIP_AGREEMENT_EMOJI="✅"
readonly MAXMIND_LIMIT_CELL="limit"
readonly EXITS_NOTE="exits over"
readonly DUAL_STACK_EXITS="IPv4 and IPv6"
readonly PROXY_CHECKED_ONCE_NOTE="Each service is checked once, the proxy picks the protocol"
readonly PROXY_IGNORES_IP_VERSION_WARNING="--ipv4 and --ipv6 are ignored with --proxy, the proxy picks the protocol"
readonly PROXY_IP_VERSION="proxy"
readonly BOTH_IP_VERSION="both"

readonly STATUS_YES="yes"
readonly STATUS_NO="no"
readonly STATUS_IPBLOCK="ipblock"
readonly STATUS_NONE="none"
readonly SYMBOL_YES="✓"
readonly SYMBOL_NO="✗"
readonly SYMBOL_IPBLOCK="⊘"
readonly SYMBOL_UNKNOWN="?"
readonly SYMBOL_NONE="-"
readonly STATUS_UNKNOWN="unknown"

readonly CURL_BASE_ARGS=(--disable --silent --compressed --retry 1 --retry-connrefused)
readonly CURL_WRITE_OUT='%{http_code}\n%{redirect_url}\n'
readonly CACHE_POLL_INTERVAL=0.1

readonly MAX_PARALLEL_JOBS=16
readonly JOB_POLL_INTERVAL=0.1
readonly RESULT_FILE_PREFIX="result-"
readonly CLEAR_LINE=$'\r\033[K'
readonly PROGRESS_LABEL="Checking services"
readonly PREPARATION_LABEL="Detecting IP addresses"
readonly PROGRESS_SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
readonly PROGRESS_BAR_WIDTH=24
readonly PROGRESS_BAR_DONE="━"
readonly PROGRESS_BAR_LEFT="─"

readonly VERBOSE_TIME_FORMAT='%H:%M:%S'
# shellcheck disable=SC2016 # expanded by bash on every trace line, not here
readonly DEBUG_TRACE_PS4='+ [${BASHPID}] ${FUNCNAME[0]:-main}:${LINENO} '
readonly DEBUG_LOG_TEMPLATE="ipregion-debug.XXXXXX"
readonly DEBUG_RECORD_LIMIT=4096
readonly DEBUG_UPLOAD_TIMEOUT=60
readonly UPLOAD_SPEED_LIMIT=1024
readonly UPLOAD_SPEED_TIME=10
readonly X0_AT_NAME="x0.at"
readonly X0_AT_UPLOAD_URL="https://x0.at"
readonly LITTERBOX_NAME="litterbox"
readonly LITTERBOX_UPLOAD_URL="https://litterbox.catbox.moe/resources/internals/api.php"
readonly LITTERBOX_RETENTION="72h"
readonly UPLOADED_URL_PATTERN='^https://[^[:space:]]+$'
readonly UPLOAD_RESPONSE_NAME="upload-response"
readonly UPLOAD_WRITE_OUT='%{http_code}'
readonly MASKED_VALUE="masked"
readonly MASKED_ASN="AS64496"
readonly MASKED_ORG="Example Hosting"
readonly MASKED_HOME="~"
# shellcheck disable=SC2016 # awk program, $0 belongs to awk
readonly DEBUG_LOG_FILTER='
function replace_literal(text, from_text, to_text,    result, position) {
  result = ""
  while ((position = index(text, from_text)) > 0) {
    result = result substr(text, 1, position - 1) to_text
    text = substr(text, position + length(from_text))
  }
  return result text
}

function mask_keys(text,    result, matched, colon) {
  result = ""
  while (match(text, key_pattern)) {
    matched = substr(text, RSTART, RLENGTH)
    colon = index(matched, ":")
    result = result substr(text, 1, RSTART - 1) substr(matched, 1, colon) "\"" masked "\""
    text = substr(text, RSTART + RLENGTH)
  }
  return result text
}

function print_truncated() {
  if (truncated > 0) {
    printf "[... %d bytes truncated]\n", truncated
  }
  truncated = 0
}

BEGIN {
  for (i = 1; i < ARGC; i += 2) {
    from[++pairs] = ARGV[i]
    to[pairs] = ARGV[i + 1]
    delete ARGV[i]
    delete ARGV[i + 1]
  }
  key_pattern = "\"(ip|query|ip_address|network|hostname|host|domain|org|isp|isp_name|ispName|as|asn|" \
    "asname|organization|company|name|sponsor|autonomous_system_number|autonomous_system_organization|" \
    "city|city_name|cityName|region|region_name|regionName|" \
    "region_code|state|district|postal|zip|postal_code|latitude|longitude|lat|lon|loc|names|" \
    "metro_code|accuracy_radius|timezone|time_zone)\" *: *(\"[^\"]*\"|-?[0-9.]+|[{][^}]*[}])"
}

/^\++ \[[0-9]+\] / {
  print_truncated()
  record_size = 0
}

{
  line = $0
  for (i = 1; i <= pairs; i++) {
    line = replace_literal(line, from[i], to[i])
  }
  line = mask_keys(line)

  if (record_size >= limit) {
    truncated += length(line) + 1
    next
  }
  if (record_size + length(line) > limit) {
    truncated += record_size + length(line) - limit
    line = substr(line, 1, limit - record_size)
  }
  record_size += length(line) + 1
  print line
}

END {
  print_truncated()
}'

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
readonly PROC_NET_DIR="${IPREGION_PROC_NET_DIR:-/proc/net}"
readonly IPV4_ROUTE_TABLE="$PROC_NET_DIR/route"
readonly IPV6_ROUTE_TABLE="$PROC_NET_DIR/ipv6_route"
readonly IPV4_DEFAULT_ROUTE="00000000"
readonly IPV6_DEFAULT_ROUTE="00000000000000000000000000000000"
readonly IPV6_DEFAULT_PREFIX_LENGTH="00"
readonly ROUTE_FLAG_UP=1
readonly ROUTE_FLAG_GATEWAY=2
readonly IPV4_PATTERN='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
readonly IPV6_PATTERN='^[0-9A-Fa-f]{0,4}(:[0-9A-Fa-f]{0,4}){2,7}$'
readonly IPV6_GROUP_COUNT=8

readonly MAXMIND_DEMO_PAGE_URL="https://www.maxmind.com/en/geoip-web-services-demo"
readonly MAXMIND_TOKEN_URL="https://www.maxmind.com/en/geoip2/demo/token"
readonly MAXMIND_CITY_URL="https://geoip.maxmind.com/geoip/v2.1/city"
readonly MAXMIND_CSRF_PATTERN='value="([0-9a-f]+)" name="csrf_token"'
readonly RIPE_RDAP_IP_URL="https://rdap.db.ripe.net/ip"
readonly RIPESTAT_PREFIX_OVERVIEW_URL="https://stat.ripe.net/data/prefix-overview/data.json"
readonly RIPESTAT_RIR_STATS_COUNTRY_URL="https://stat.ripe.net/data/rir-stats-country/data.json"

readonly IPV4_TRANSPORT=4
readonly ANY_TRANSPORT=""
readonly IPINFO_IPV4_URL="https://ipinfo.io/widget/demo"
readonly IPINFO_IPV6_URL="https://v6.ipinfo.io/widget/demo"
readonly CLOUDFLARE_TRACE_URL="https://www.cloudflare.com/cdn-cgi/trace"
readonly CLOUDFLARE_COUNTRY_PATTERN=$'(^|\n)loc=([A-Z]{2})(\n|$)'
readonly CLOUDFLARE_IP_PATTERN=$'(^|\n)ip=([^\n]+)(\n|$)'
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
readonly CLAUDE_URL="https://claude.ai/api/bootstrap"
readonly CLAUDE_USER_AGENT="Claude com.anthropic.claude/1.261023.20 (Android 30) Claude/1.261023.20"
readonly CLAUDE_PLATFORM_HEADER="Anthropic-Client-Platform: android"
readonly NETFLIX_URL="https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=1"
readonly SPOTIFY_URL="https://spclient.wg.spotify.com/signup/public/v1/account/?validate=1&key=142b583129b2df829de3656f9eb484e6"
readonly SPOTIFY_CLIENT_ID="9a8d2f0ce77a4e248bb71fefcb557637"
readonly REDDIT_NOT_FOUND_URL="https://www.reddit.com/api/v1/not-found"
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
readonly YOUTUBE_INNERTUBE_BROWSE_URL="https://www.youtube.com/youtubei/v1/browse"
readonly YOUTUBE_PREMIUM_QUERY='{"context":{"client":{"clientName":"MWEB","clientVersion":"2.20261020.00.00","hl":"en","gl":"US"}},"browseId":"SPunlimited"}'
readonly YOUTUBE_PREMIUM_PURCHASE_MARKER="premiumPurchaseButtonRenderer"
readonly YOUTUBE_WATCH_URL="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
readonly YOUTUBE_VIEWER_COOKIE_PREFIX="Cookie: SOCS=CAI; PREF=hl="
readonly ACCEPT_LANGUAGE_PREFIX="Accept-Language: "
readonly YOUTUBE_NO_ADS_SERVICE_PREFIX="YouTube No Ads"
readonly YOUTUBE_PLAYER_RESPONSE_MARKER="ytInitialPlayerResponse"
readonly YOUTUBE_VIDEO_AD_MARKER="SLOT_TYPE_PLAYER_BYTES"
readonly YOUTUBE_COOKIE_JAR_PREFIX="youtube-cookies-"
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
readonly QWEN_CN_API_URL="https://dashscope.aliyuncs.com/compatible-mode/v1/models"
readonly KIMI_API_URL="https://api.moonshot.ai/v1/models"
readonly KIMI_CN_API_URL="https://api.moonshot.cn/v1/models"
readonly GLM_API_URL="https://api.z.ai/api/paas/v4/models"
readonly GLM_CN_API_URL="https://open.bigmodel.cn/api/paas/v4/models"
readonly MINIMAX_API_URL="https://api.minimax.io/v1/models"
readonly MINIMAX_CN_API_URL="https://api.minimaxi.com/v1/models"
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
readonly REASON_CAPTCHA="captcha"
readonly REASON_PROXY_PICKED="proxy picked IPv"
readonly REASON_NETWORK="network error"
readonly REASON_FORBIDDEN="access denied"
readonly REASON_RATE_LIMITED="rate limited"
readonly REASON_SERVER_ERROR="server error"
readonly REASON_UNEXPECTED_RESPONSE="unexpected response"
readonly REASON_DAILY_LIMIT="daily limit used up"
readonly REASON_NO_DEMO_TOKEN="no demo token"
readonly REASON_NO_IPV6="no IPv6"
readonly REASON_VIDEO_ADS="video ads"

readonly GROUP_PLATFORMS="platforms"
readonly PLATFORMS_CHECKS=(
  check_platforms_google
  check_platforms_youtube
  check_platforms_twitch
  check_platforms_chatgpt
  check_platforms_claude
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
  check_availability_youtube_no_ads
  check_availability_google_search
  check_availability_spotify_signup
  check_availability_disney_plus
  check_availability_reddit_guest
)

readonly GROUP_AI="ai"
readonly AI_CHECKS=(
  check_ai_gemini_web
  check_ai_gemini_api
  check_ai_openai_api
  check_ai_anthropic_api
  check_ai_grok_api
  check_ai_qwen_api
  check_ai_qwen_cn_api
  check_ai_kimi_api
  check_ai_kimi_cn_api
  check_ai_glm_api
  check_ai_glm_cn_api
  check_ai_minimax_api
  check_ai_minimax_cn_api
  check_ai_doubao_api
  check_ai_siliconflow_api
  check_ai_deepseek_api
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

readonly ALL_CHECKS=(
  "${PLATFORMS_CHECKS[@]}"
  "${CDN_CHECKS[@]}"
  "${AVAILABILITY_CHECKS[@]}"
  "${AI_CHECKS[@]}"
  "${GEOIP_CHECKS[@]}"
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
# shellcheck disable=SC2016 # $daily_limit, $limit, $unknown and the other names are jq variables, not shell expansions
readonly GROUP_ROWS_FILTER='
def cell:
  if .reason == $daily_limit then $limit
  elif .status == $yes and .country != "" then .country
  elif .status == "" then $unknown
  else .status end;
def result_of($ip_version): (map(select(.ip_version == $ip_version)) | first) // first;
map(select(.group == $group)) as $rows
| reduce ($rows[].service) as $service ([]; if any(.[]; . == $service) then . else . + [$service] end)
| .[] as $service
| ($rows | map(select(.service == $service))) as $results
| $service, ($results | result_of("4") | cell), ($results | result_of("6") | cell)'
# shellcheck disable=SC2016 # $cdn, $unknown and $service are jq variables, not shell expansions
readonly CDN_ROWS_FILTER='
def result_of($ip_version): (map(select(.ip_version == $ip_version)) | first) // first;
def edge: (if .status == "" then $unknown else .status end), .country, .iata, .node;
map(select(.group == $cdn)) as $rows
| reduce ($rows[].service) as $service ([]; if any(.[]; . == $service) then . else . + [$service] end)
| .[] as $service
| ($rows | map(select(.service == $service))) as $results
| $service, ($results | result_of("4") | edge), ($results | result_of("6") | edge)'
# shellcheck disable=SC2016 # $geoip and $yes are jq variables, not shell expansions
readonly GEOIP_MAJORITY_FILTER='
map(select(.group == $geoip and .status == $yes and .country != ""))
| group_by(.country)
| max_by(length)
| .[0].country // empty'
# shellcheck disable=SC2016 # $geoip, $reference and the other names are jq variables, not shell expansions
readonly GEOIP_AGREEMENT_FILTER='
map(select(.group == $geoip))
| group_by(.service)
| map(select(all(.[]; .reason == $daily_limit) | not)) as $counted
| ($counted | map(map(select(.status == $yes and .country != "") | .country) | select(length > 0 and all(. == $reference))) | length),
  ($counted | length),
  (length > ($counted | length))'
# shellcheck disable=SC2016 # $geoip, $reference and $yes are jq variables, not shell expansions
readonly GEOIP_DEVIATIONS_FILTER='
map(select(.group == $geoip and .status == $yes and .country != "" and .country != $reference))
| reduce .[] as $result ([];
    (map(.country == $result.country and .ip_version == $result.ip_version) | index(true)) as $index
    | if $index == null then . + [{country: $result.country, ip_version: $result.ip_version, services: [$result.service]}]
      else .[$index].services += [$result.service] end)
| .[]
| .country, .ip_version, (.services | length), .services[]'
# shellcheck disable=SC2016 # $verdict, $geoip and the other names are jq variables, not shell expansions
readonly NEEDS_ATTENTION_DEFINITION='
def is_failed:
  if .group == $cdn or .status == $none or .reason == $daily_limit or .reason == $video_ads then false
  elif .status == "" then true
  elif .group == $geoip then false
  elif .country != "" then $verdict != "" and .country != $verdict
  else .status != $yes end;
def needs_attention:
  is_failed and (.status == "" or .country != "");'
# shellcheck disable=SC2016 # $verdict and $geoip are jq variables, not shell expansions
readonly ABNORMAL_CHECKS_FILTER="$NEEDS_ATTENTION_DEFINITION"'
def differs_from_verdict:
  .group == $geoip and .country != "" and $verdict != "" and .country != $verdict;
[.[] | select(is_failed or differs_from_verdict) | [.group, .service]] | unique | length'
# shellcheck disable=SC2016 # $collapse_min, $different_country and the other names are jq variables, not shell expansions
readonly ATTENTION_FILTER="$NEEDS_ATTENTION_DEFINITION"'
def severity:
  if .country != "" then 0 else 1 end;
to_entries
| map(.value + {order: .key} | select(needs_attention))
| map(if .status == $yes then .reason = $different_country else . end)
| group_by([.group, .service, .country, .status, .reason])
| map(.[0] + {ip_version: (if length == 2 then "both" else .[0].ip_version end)})
| group_by([.country, .status, .reason, .ip_version])
| map(if length >= $collapse_min then sort_by(.order) | [.[0] + {services: map(.service)}] else map(. + {services: [.service]}) end)
| add // []
| sort_by([(.services | length) >= $collapse_min, severity, .order])
| map({services, ip_version, country, status, reason})'
readonly JSON_VERSION=2
readonly JSON_SCHEMA_URL="https://raw.githubusercontent.com/vernette/ipregion/master/schema/ipregion-v2.schema.json"
# shellcheck disable=SC2016 # $ip, $asn and the other names are jq variables, not shell expansions
readonly JSON_ADDRESS_FILTER='
def nullable: if . == "" then null else . end;
{
  ip: $ip,
  asn: ($asn | if . == "" then null else tonumber end),
  org: ($org | nullable),
  registered: ($registered | nullable),
  maxmind_failure: ($maxmind_failure | nullable)
}'
# shellcheck disable=SC2016 # $schema, $version, $availability and the other names are jq variables, not shell expansions
readonly JSON_REPORT_FILTER='
def nullable: if . == "" then null else . end;
def access:
  if (.group == $availability or .group == $ai) and .status != $none then .status | nullable else null end;
def protocol_result:
  {country: (.country | nullable), access: access, reason: (.reason | nullable)}
  + if has("iata") then {iata: (.iata | nullable), node: (.node | nullable)} else {} end;
def protocol_entry($rows; $ip_version):
  first($rows[] | select(.ip_version == $ip_version) | protocol_result) // null;
def service_entries($results; $group):
  [$results[] | select(.group == $group)] as $rows
  | reduce $rows[].id as $id ([]; if any(.[]; . == $id) then . else . + [$id] end)
  | map(. as $id | [$rows[] | select(.id == $id)] as $service_rows | {
      id: $id,
      service: $service_rows[0].service,
      ipv4: protocol_entry($service_rows; "4"),
      ipv6: protocol_entry($service_rows; "6"),
      proxy: protocol_entry($service_rows; $proxy)
    });
. as $results
| {
    "$schema": $schema,
    version: $version,
    ipv4: $ipv4,
    ipv6: $ipv6,
    verdict: {country: ($verdict | nullable), tied: $tied},
    attention: ($attention | map({
      services,
      ip_version,
      country: (.country | nullable),
      access: (if .status == $yes or .status == $none then null else .status | nullable end),
      reason: (.reason | nullable)
    })),
    results: (reduce $groups[] as $group ({}; .[$group] = service_entries($results; $group)))
  }'

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  readonly C_TITLE=$'\033[1;36m'
  readonly C_BADGE=$'\033[1;30;46m'
  readonly C_BADGE_FAIR=$'\033[1;30;43m'
  readonly C_BADGE_POOR=$'\033[1;30;41m'
  readonly C_BAR=$'\033[0;36m'
  readonly C_BAR_FAIR=$'\033[0;33m'
  readonly C_BAR_POOR=$'\033[0;31m'
  readonly C_VALUE=$'\033[1m'
  readonly C_DIM=$'\033[0;90m'
  readonly C_YES=$'\033[1;32m'
  readonly C_NO=$'\033[1;31m'
  readonly C_WARN=$'\033[1;33m'
  readonly C_RESET=$'\033[0m'
else
  readonly C_TITLE=""
  readonly C_BADGE=""
  readonly C_BADGE_FAIR=""
  readonly C_BADGE_POOR=""
  readonly C_BAR=""
  readonly C_BAR_FAIR=""
  readonly C_BAR_POOR=""
  readonly C_VALUE=""
  readonly C_DIM=""
  readonly C_YES=""
  readonly C_NO=""
  readonly C_WARN=""
  readonly C_RESET=""
fi

if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  readonly M_ERROR=$'\033[1;31m'
  readonly M_WARN=$'\033[1;33m'
  readonly M_ASK=$'\033[1;36m'
  readonly M_ACCENT=$'\033[0;36m'
  readonly M_VALUE=$'\033[1m'
  readonly M_DIM=$'\033[0;90m'
  readonly M_RESET=$'\033[0m'
else
  readonly M_ERROR=""
  readonly M_WARN=""
  readonly M_ASK=""
  readonly M_ACCENT=""
  readonly M_VALUE=""
  readonly M_DIM=""
  readonly M_RESET=""
fi

VERBOSE=false
DEBUG=false
ASSUME_YES=false
MISSING_COMMANDS=()
PACKAGE_MANAGER=""
ROOT_COMMAND=()
JSON_OUTPUT=false
REQUESTED_GROUPS=()
SELECTED_GROUPS=("${SERVICE_GROUPS[@]}")
REQUESTED_SERVICES=()
SELECTED_CHECKS=()
CURL_TIMEOUT="$DEFAULT_TIMEOUT"
YOUTUBE_LANG="$DEFAULT_YOUTUBE_LANG"
IPV4_ONLY=false
IPV6_ONLY=false
PROXY_ADDR=""
INTERFACE_NAME=""
MAIN_INTERFACE=""
SHOW_EMOJI=false
COUNTRY_EXTRA=0
GEOIP_BREAKDOWN=false
SHOW_ATTENTION=true
VERDICT=""
VERDICT_TIED_COUNTRIES=()
ATTENTION="[]"
CHECKS_TOTAL=0
CHECKS_NORMAL=0
WORK_DIR=""
EXTERNAL_IPV4=""
EXTERNAL_IPV6=""
CURL_ARGS=()
MAXMIND_TOKEN=""
MAXMIND_TOKEN_FAILURE=""
JOB_COUNT=0
JOB_SLOTS_FD=""
PROGRESS_FRAME=0
RESULTS=""
DEBUG_TRACE_FILE=""
DEBUG_TRACE_DIR=""
DEBUG_LOG_FILE=""
DEBUG_MASKS=()
HEADER_IP_VERSIONS=()
HEADER_IP_VALUES=()
HEADER_NETWORKS=()
HEADER_EXIT_LABEL=""
HEADER_VALUE_WIDTH=0
HEADER_NETWORK_WIDTH=0
LEFT_CARD_WIDTH=0
RIGHT_CARD_WIDTH=0
FULL_CARD_WIDTH=0
RIGHT_COLUMN_START=0
RIGHT_COLUMN_WIDTH=0
GEOIP_LINE_WIDTH=0
CHECKS_BAR_WIDTH=0
declare -gA REGISTRATION_ASN=()
declare -gA REGISTRATION_ORG=()
declare -gA REGISTRATION_COUNTRY=()
declare -gA REGISTRATION_MAXMIND_FAILURE=()

use_utf8_locale() {
  local probe="$SYMBOL_YES"

  if ((${#probe} == 1)); then
    return
  fi

  export LC_ALL="$UTF8_LOCALE" 2>/dev/null || true
}

print_error() {
  local message="$1"

  printf '%sError:%s %s\n' "$M_ERROR" "$M_RESET" "$message" >&2
}

print_warning() {
  local message="$1"

  printf '%sWarning:%s %s\n' "$M_WARN" "$M_RESET" "$message" >&2
}

print_note() {
  local message="$1"

  printf '%s%s%s\n' "$M_DIM" "$message" "$M_RESET" >&2
}

ask_yes_no() {
  local question="$1"
  local answer

  printf '%s%s%s %s[y/N]%s ' "$M_ASK" "$question" "$M_RESET" "$M_DIM" "$M_RESET" >/dev/tty
  read -r answer </dev/tty
  case "$answer" in
    y | Y | yes) return ;;
  esac

  return 1
}

die() {
  local message="$1"

  print_error "$message"
  printf '\n' >&2
  print_note "Run $SCRIPT_NAME --help for usage"
  exit 1
}

log_verbose() {
  local message="$1"

  if [[ "$VERBOSE" != true ]]; then
    return
  fi

  if [[ -n "$EXTERNAL_IPV4" ]]; then
    message="${message//"$EXTERNAL_IPV4"/"$(mask_ipv4 "$EXTERNAL_IPV4")"}"
  fi
  if [[ -n "$EXTERNAL_IPV6" ]]; then
    message="${message//"$EXTERNAL_IPV6"/"$(mask_ipv6 "$EXTERNAL_IPV6")"}"
  fi
  printf "[%($VERBOSE_TIME_FORMAT)T] %s\n" -1 "$message" >&2
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Shows how GeoIP databases, popular platforms, CDNs and AI services see this
host over IPv4 and IPv6.

Options:
  -h, --help             Show this help and exit
  -v, --verbose          Log every step to stderr
  -d, --debug            Save a masked trace to a file and offer to upload it
  -y, --yes              Install missing curl and jq and upload the debug
                         log without asking
  -j, --json             Print results as JSON
  -g, --group GROUPS     Check only these groups, comma-separated or repeated:
                         ${SERVICE_GROUPS[*]} (default: $ALL_GROUPS)
  -s, --service NAMES    Check only these services, comma-separated or repeated:
                         [GROUP/]SERVICE, names from --list-services
      --list-services    List service names and exit
  -t, --timeout SEC      Request timeout in seconds (default: $DEFAULT_TIMEOUT)
  -4, --ipv4             Check IPv4 only
  -6, --ipv6             Check IPv6 only
  -p, --proxy HOST:PORT  Send requests through a SOCKS5 proxy
  -i, --interface IFACE  Send requests through a network interface
      --emoji            Show country flags and group icons
      --geoip-breakdown  Show every GeoIP service instead of the summary
      --no-attention     Hide the Attention card
      --youtube-lang LANG
                         Viewer's YouTube language for YouTube No Ads
                         (default: $DEFAULT_YOUTUBE_LANG)

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

check_group() {
  local check="$1"
  local group="${check#check_}"

  printf '%s' "${group%%_*}"
}

check_id() {
  local check="$1"
  local group

  group=$(check_group "$check")
  printf '%s' "${check#check_"$group"_}"
}

service_name() {
  local check="$1"

  printf '%s/%s' "$(check_group "$check")" "$(check_id "$check")"
}

print_service_list() {
  local check

  for check in "${ALL_CHECKS[@]}"; do
    printf '%s\n' "$(service_name "$check")"
  done
}

parse_args() {
  local -a groups services

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
      -y | --yes)
        ASSUME_YES=true
        shift
        ;;
      -j | --json)
        JSON_OUTPUT=true
        shift
        ;;
      -g | --group)
        require_option_value "$1" "$#"
        IFS=, read -ra groups <<<"$2"
        REQUESTED_GROUPS+=("${groups[@]}")
        shift 2
        ;;
      -s | --service)
        require_option_value "$1" "$#"
        IFS=, read -ra services <<<"$2"
        REQUESTED_SERVICES+=("${services[@]}")
        shift 2
        ;;
      --list-services)
        print_service_list
        exit 0
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
        COUNTRY_EXTRA="$FLAG_WIDTH"
        shift
        ;;
      --geoip-breakdown)
        GEOIP_BREAKDOWN=true
        shift
        ;;
      --no-attention)
        SHOW_ATTENTION=false
        shift
        ;;
      --youtube-lang)
        require_option_value "$1" "$#"
        YOUTUBE_LANG="$2"
        shift 2
        ;;
      *)
        die "unknown option $1"
        ;;
    esac
  done
}

is_in_list() {
  local needle="$1"
  shift
  local item

  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

is_group_selected() {
  local group="$1"

  is_in_list "$group" "${SELECTED_GROUPS[@]}"
}

is_known_group() {
  local group="$1"

  [[ "$group" == "$ALL_GROUPS" ]] || is_in_list "$group" "${SERVICE_GROUPS[@]}"
}

validate_args() {
  local group

  for group in "${REQUESTED_GROUPS[@]}"; do
    if ! is_known_group "$group"; then
      die "unknown group $group, expected one of: ${SERVICE_GROUPS[*]} $ALL_GROUPS"
    fi
  done

  if [[ ! "$CURL_TIMEOUT" =~ $TIMEOUT_PATTERN ]]; then
    die "invalid timeout $CURL_TIMEOUT, expected a positive integer"
  fi

  if [[ "$IPV4_ONLY" == true && "$IPV6_ONLY" == true ]]; then
    die "options --ipv4 and --ipv6 cannot be used together"
  fi

  if [[ -n "$PROXY_ADDR" && ! "$PROXY_ADDR" =~ $PROXY_PATTERN ]]; then
    die "invalid proxy $PROXY_ADDR, expected HOST:PORT"
  fi

  if [[ ! "$YOUTUBE_LANG" =~ $YOUTUBE_LANG_PATTERN ]]; then
    die "invalid YouTube language $YOUTUBE_LANG, expected a language code like ru, en or pt-BR"
  fi
}

ignore_ip_version_with_proxy() {
  if [[ -z "$PROXY_ADDR" || ("$IPV4_ONLY" == false && "$IPV6_ONLY" == false) ]]; then
    return
  fi

  print_warning "$PROXY_IGNORES_IP_VERSION_WARNING"
  IPV4_ONLY=false
  IPV6_ONLY=false
}

print_ipv4_default_routes() {
  local iface destination flags mask

  if [[ ! -r "$IPV4_ROUTE_TABLE" ]]; then
    return
  fi

  while read -r iface destination _ flags _ _ _ mask _; do
    if [[ "$destination" == "$IPV4_DEFAULT_ROUTE" && "$mask" == "$IPV4_DEFAULT_ROUTE" ]]; then
      printf '%s %s\n' "$iface" "$flags"
    fi
  done <"$IPV4_ROUTE_TABLE"
}

print_ipv6_default_routes() {
  local destination prefix_length flags iface

  if [[ ! -r "$IPV6_ROUTE_TABLE" ]]; then
    return
  fi

  while read -r destination prefix_length _ _ _ _ _ _ flags iface; do
    if [[ "$destination" == "$IPV6_DEFAULT_ROUTE" && "$prefix_length" == "$IPV6_DEFAULT_PREFIX_LENGTH" ]]; then
      printf '%s %s\n' "$iface" "$flags"
    fi
  done <"$IPV6_ROUTE_TABLE"
}

print_bsd_default_route() {
  local ip_version="$1"
  local -a family=()
  local key value iface=""
  local flags="$ROUTE_FLAG_UP"

  if [[ "$ip_version" == 6 ]]; then
    family=(-inet6)
  fi

  while read -r key value _; do
    case "$key" in
      interface:) iface="$value" ;;
      gateway:) flags=$((ROUTE_FLAG_UP | ROUTE_FLAG_GATEWAY)) ;;
    esac
  done < <(route -n get "${family[@]}" default 2>/dev/null)

  if [[ -z "$iface" ]]; then
    return
  fi

  printf '%s %x\n' "$iface" "$flags"
}

print_default_routes() {
  local ip_version="$1"

  if [[ ! -d "$PROC_NET_DIR" ]]; then
    print_bsd_default_route "$ip_version"
    return
  fi

  case "$ip_version" in
    4) print_ipv4_default_routes ;;
    6) print_ipv6_default_routes ;;
  esac
}

has_route_flag() {
  local flags="$1"
  local flag="$2"

  ((16#$flags & flag))
}

print_gateway_interface() {
  local ip_version="$1"
  local iface flags

  while read -r iface flags; do
    if has_route_flag "$flags" "$ROUTE_FLAG_UP" && has_route_flag "$flags" "$ROUTE_FLAG_GATEWAY"; then
      printf '%s' "$iface"
      return
    fi
  done < <(print_default_routes "$ip_version")
}

has_default_route_through() {
  local ip_version="$1"
  local interface="$2"
  local iface flags

  while read -r iface flags; do
    if [[ "$iface" == "$interface" ]] && has_route_flag "$flags" "$ROUTE_FLAG_UP"; then
      return 0
    fi
  done < <(print_default_routes "$ip_version")

  return 1
}

has_default_route() {
  local ip_version="$1"
  local iface flags

  while read -r iface flags; do
    if has_route_flag "$flags" "$ROUTE_FLAG_UP"; then
      return 0
    fi
  done < <(print_default_routes "$ip_version")

  return 1
}

detect_main_interface() {
  if [[ -n "$INTERFACE_NAME" ]]; then
    return
  fi

  MAIN_INTERFACE=$(print_gateway_interface 4)
  if [[ -z "$MAIN_INTERFACE" ]]; then
    MAIN_INTERFACE=$(print_gateway_interface 6)
  fi
}

log_interface() {
  if [[ -n "$INTERFACE_NAME" ]]; then
    log_verbose "Interface: $INTERFACE_NAME (--interface)"
    return
  fi

  if [[ -n "$MAIN_INTERFACE" ]]; then
    log_verbose "Interface: $MAIN_INTERFACE (main, carries the default route)"
    return
  fi

  log_verbose "Interface: not detected, the system routing picks it"
}

log_proxy() {
  if [[ -z "$PROXY_ADDR" ]]; then
    return
  fi

  log_verbose "Proxy: socks5h://$PROXY_ADDR"
}

limit_ip_versions_to_main_interface() {
  if [[ -z "$MAIN_INTERFACE" || -n "$PROXY_ADDR" || "$IPV4_ONLY" == true || "$IPV6_ONLY" == true ]]; then
    return
  fi

  if ! has_default_route_through 6 "$MAIN_INTERFACE"; then
    IPV4_ONLY=true
    if has_default_route 6; then
      print_note "IPv6 goes out through another interface than the main one $MAIN_INTERFACE, checking IPv4 only (-6 or -i IFACE to check IPv6)"
    fi
    return
  fi

  if ! has_default_route_through 4 "$MAIN_INTERFACE"; then
    IPV6_ONLY=true
    if has_default_route 4; then
      print_note "IPv4 goes out through another interface than the main one $MAIN_INTERFACE, checking IPv6 only (-4 or -i IFACE to check IPv4)"
    fi
  fi
}

detect_missing_commands() {
  local command_name

  for command_name in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      MISSING_COMMANDS+=("$command_name")
    fi
  done
}

missing_commands_list() {
  local list

  printf -v list '%s, ' "${MISSING_COMMANDS[@]}"
  printf '%s' "${list%, }"
}

detect_package_manager() {
  local manager

  for manager in "${PACKAGE_MANAGERS[@]}"; do
    if command -v "$manager" >/dev/null 2>&1; then
      PACKAGE_MANAGER="$manager"
      return
    fi
  done

  print_error "missing dependencies ($(missing_commands_list)) and no supported package manager found, install them manually"
  exit 1
}

resolve_root_command() {
  if ((EUID == 0)) || [[ -n "${TERMUX_VERSION:-}" ]]; then
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    ROOT_COMMAND=(sudo)
    return
  fi

  print_error "missing dependencies ($(missing_commands_list)), installing them with $PACKAGE_MANAGER needs root or sudo"
  exit 1
}

has_terminal() {
  : 2>/dev/null </dev/tty
}

confirm_install() {
  if [[ "$ASSUME_YES" == true ]]; then
    return
  fi

  if ! has_terminal; then
    print_error "missing dependencies ($(missing_commands_list)), run with --yes to install them with $PACKAGE_MANAGER"
    exit 1
  fi

  printf '%sMissing dependencies:%s %s%s%s\n' "$M_WARN" "$M_RESET" "$M_VALUE" "$(missing_commands_list)" "$M_RESET" >/dev/tty
  if ask_yes_no "Install them with $PACKAGE_MANAGER?"; then
    return
  fi

  print_error "missing dependencies ($(missing_commands_list)), installation cancelled"
  exit 1
}

install_packages() {
  local -a manager=("${ROOT_COMMAND[@]}" "$PACKAGE_MANAGER")

  case "$PACKAGE_MANAGER" in
    apt-get)
      "${manager[@]}" update
      "${manager[@]}" install -y "${MISSING_COMMANDS[@]}"
      ;;
    dnf | yum) "${manager[@]}" install -y "${MISSING_COMMANDS[@]}" ;;
    pacman) "${manager[@]}" -Sy --needed --noconfirm "${MISSING_COMMANDS[@]}" ;;
    zypper) "${manager[@]}" --non-interactive install "${MISSING_COMMANDS[@]}" ;;
    apk) "${manager[@]}" add --no-cache "${MISSING_COMMANDS[@]}" ;;
    xbps-install) "${manager[@]}" -Sy "${MISSING_COMMANDS[@]}" ;;
  esac >&2
}

require_installed_commands() {
  local command_name

  for command_name in "${MISSING_COMMANDS[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      print_error "$command_name is still missing after installing it with $PACKAGE_MANAGER"
      exit 1
    fi
  done
}

install_missing_dependencies() {
  detect_missing_commands
  if ((${#MISSING_COMMANDS[@]} == 0)); then
    return
  fi

  detect_package_manager
  resolve_root_command
  confirm_install
  install_packages
  require_installed_commands
}

resolve_selected_groups() {
  local group

  if is_in_list "$ALL_GROUPS" "${REQUESTED_GROUPS[@]}"; then
    return
  fi

  if ((${#REQUESTED_GROUPS[@]} + ${#REQUESTED_SERVICES[@]} == 0)); then
    return
  fi

  SELECTED_GROUPS=()
  for group in "${SERVICE_GROUPS[@]}"; do
    if is_in_list "$group" "${REQUESTED_GROUPS[@]}"; then
      SELECTED_GROUPS+=("$group")
    fi
  done
}

normalize_service_name() {
  local name="${1,,}"

  name="${name//+/_plus}"
  printf '%s' "${name//[. -]/_}"
}

matching_checks() {
  local request="$1"
  local group=""
  local name="$request"
  local -a exact=() shortened=()
  local check id

  if [[ "$request" == */* ]]; then
    group="${request%%/*}"
    group="${group,,}"
    name="${request#*/}"
  fi
  name=$(normalize_service_name "$name")

  for check in "${ALL_CHECKS[@]}"; do
    if [[ -n "$group" && "$(check_group "$check")" != "$group" ]]; then
      continue
    fi
    id=$(check_id "$check")
    if [[ "$id" == "$name" ]]; then
      exact+=("$check")
    elif [[ "${id%_*}" == "$name" ]]; then
      shortened+=("$check")
    fi
  done

  if ((${#exact[@]} > 0)); then
    printf '%s\n' "${exact[@]}"
    return
  fi
  printf '%s\n' "${shortened[@]}"
}

resolve_selected_checks() {
  local -a matches candidates
  local request check

  for request in "${REQUESTED_SERVICES[@]}"; do
    mapfile -t matches < <(matching_checks "$request")
    if [[ -z "${matches[0]:-}" ]]; then
      die "unknown service $request, see --list-services"
    fi
    if ((${#matches[@]} > 1)); then
      candidates=()
      for check in "${matches[@]}"; do
        candidates+=("$(service_name "$check")")
      done
      die "ambiguous service $request, expected one of: ${candidates[*]}"
    fi
    SELECTED_CHECKS+=("${matches[0]}")
  done
}

visible_length() {
  local text="$1"
  local plain="${text//$ANSI_SEQUENCE/}"
  local narrow="${plain//$WIDE_EMOJI_PATTERN/}"

  printf '%d' $((2 * ${#plain} - ${#narrow}))
}

repeat_char() {
  local char="$1"
  local count="$2"
  local line

  if ((count <= 0)); then
    return
  fi

  printf -v line '%*s' "$count" ''
  printf '%s' "${line// /$char}"
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

pad_cell() {
  local color="$1"
  local text="$2"
  local width="$3"
  local fill

  fill=$((width - $(visible_length "$text")))
  if ((fill < 1)); then
    fill=1
  fi

  printf '%s%s%s%*s' "$color" "$text" "$C_RESET" "$fill" ''
}

max_length() {
  local max=0
  local text length

  for text in "$@"; do
    length=$(visible_length "$text")
    if ((length > max)); then
      max="$length"
    fi
  done

  printf '%d' "$max"
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

label_group() {
  local title="$1"

  if [[ "$SHOW_EMOJI" != true || -z "$title" ]]; then
    printf '%s' "$title"
    return
  fi

  printf '%s %s' "${GROUP_EMOJI[$title]}" "$title"
}

is_verdict_country() {
  local country="$1"

  [[ "$country" == "$VERDICT" ]] || is_in_list "$country" "${VERDICT_TIED_COUNTRIES[@]}"
}

format_country() {
  local country="$1"
  local width="$2"

  if [[ -z "$country" ]]; then
    paint "$C_DIM" "$(pad "$SYMBOL_UNKNOWN" "$width")"
    return
  fi

  if is_verdict_country "$country"; then
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
    "$MAXMIND_LIMIT_CELL") paint "$C_DIM" "$(pad "$MAXMIND_LIMIT_CELL" "$width")" ;;
    *) paint "$C_DIM" "$(pad "$SYMBOL_UNKNOWN" "$width")" ;;
  esac
}

format_cell() {
  local value="$1"
  local width="$2"

  if [[ "$value" =~ $COUNTRY_CODE_PATTERN ]]; then
    format_country "$value" "$width"
    return
  fi

  format_status "$value" "$width"
}

print_card_top() {
  local title_color="$1"
  local title="$2"
  local width="$3"
  local summary="${4:-}"
  local label

  label="$(paint "$title_color" " $(label_group "$title") ")"
  if [[ -n "$summary" ]]; then
    label="$(paint "$title_color" " $(label_group "$title")") $(paint "$C_DIM" "·") $summary "
  fi
  printf '%s%s%s%s%s%s%s%s\n' "$C_DIM" "$CARD_TOP_LEFT" "$(repeat_char "$CARD_HORIZONTAL" "$CARD_TITLE_OFFSET")" \
    "$label" "$C_DIM" \
    "$(repeat_char "$CARD_HORIZONTAL" $((width - CARD_SIDES_WIDTH - CARD_TITLE_OFFSET - $(visible_length "$label"))))" \
    "$CARD_TOP_RIGHT" "$C_RESET"
}

print_card_line() {
  local line="$1"
  local width="$2"
  local fill

  line="${line%%+( )}"
  fill=$((width - CARD_SIDES_WIDTH - CARD_CONTENT_INDENT - CARD_TRAILING_GAP - $(visible_length "$line")))
  if ((fill < 0)); then
    fill=0
  fi

  printf '%s%s%s%*s%s%*s%s%s%s\n' "$C_DIM" "$CARD_SIDE" "$C_RESET" "$CARD_CONTENT_INDENT" '' "$line" \
    $((fill + CARD_TRAILING_GAP)) '' "$C_DIM" "$CARD_SIDE" "$C_RESET"
}

print_card_bottom() {
  local width="$1"

  printf '%s%s%s%s%s\n' "$C_DIM" "$CARD_BOTTOM_LEFT" "$(repeat_char "$CARD_HORIZONTAL" $((width - CARD_SIDES_WIDTH)))" "$CARD_BOTTOM_RIGHT" "$C_RESET"
}

print_titled_card() {
  local title_color="$1"
  local title="$2"
  local width="$3"
  local height="$4"
  local summary="${5:-}"
  local -a content_lines=()
  local index

  mapfile -t content_lines
  while ((${#content_lines[@]} > 0)) && [[ -z "${content_lines[-1]}" ]]; do
    unset 'content_lines[-1]'
  done
  if ((${#content_lines[@]} > height)); then
    height="${#content_lines[@]}"
  fi

  print_card_top "$title_color" "$title" "$width" "$summary"
  for ((index = 0; index < height; index++)); do
    print_card_line "${content_lines[index]:-}" "$width"
  done
  print_card_bottom "$width"
}

print_titled_card_pair() {
  local left_title="$1"
  local right_title="$2"
  local left_text="$3"
  local right_text="$4"
  local -a left_card=() right_card=()
  local height index

  mapfile -t left_card <<<"$left_text"
  mapfile -t right_card <<<"$right_text"
  height="${#left_card[@]}"
  if ((${#right_card[@]} > height)); then
    height="${#right_card[@]}"
  fi

  mapfile -t left_card < <(printf '%s\n' "${left_card[@]}" | print_titled_card "$C_TITLE" "$left_title" "$LEFT_CARD_WIDTH" "$height")
  mapfile -t right_card < <(printf '%s\n' "${right_card[@]}" | print_titled_card "$C_TITLE" "$right_title" "$RIGHT_CARD_WIDTH" "$height")
  for ((index = 0; index < ${#left_card[@]}; index++)); do
    printf '%s%*s%s\n' "${left_card[index]}" "$CARD_GAP" '' "${right_card[index]:-}"
  done
}

print_bar_block() {
  local -a block_lines=()
  local line

  mapfile -t block_lines
  for line in "${block_lines[@]}"; do
    line="${line%%+( )}"
    if [[ -z "$line" ]]; then
      printf '%s%s%s\n' "$C_BAR" "$HEADER_MARK" "$C_RESET"
      continue
    fi
    printf '%s%s%s%*s%s\n' "$C_BAR" "$HEADER_MARK" "$C_RESET" "$CARD_CONTENT_INDENT" '' "$line"
  done
  printf '\n'
}

stop_jobs() {
  local pid

  for pid in $(jobs -pr); do
    kill "$pid" 2>/dev/null || true
  done
}

print_debug_environment() {
  local curl_version

  curl_version=$(curl --version)
  printf 'Arguments: %s\n' "$*"
  printf 'Bash: %s\n' "$BASH_VERSION"
  printf 'System: %s\n' "$(uname -srm)"
  printf 'Locale: %s\n' "${LC_ALL:-${LANG:-}}"
  printf 'Curl: %s\n' "${curl_version%%$'\n'*}"
  printf 'Jq: %s\n\n' "$(jq --version)"
}

add_debug_mask() {
  local value="$1"
  local replacement="$2"

  if [[ -n "$value" ]]; then
    DEBUG_MASKS+=("$value" "$replacement")
  fi
}

collect_debug_masks() {
  local ip_version

  DEBUG_MASKS=()
  if [[ -n "$EXTERNAL_IPV4" ]]; then
    add_debug_mask "$EXTERNAL_IPV4" "$(mask_ipv4 "$EXTERNAL_IPV4")"
    add_debug_mask "${EXTERNAL_IPV4%.*}." "${EXTERNAL_IPV4%.*.*}.*."
  fi
  if [[ -n "$EXTERNAL_IPV6" ]]; then
    add_debug_mask "$EXTERNAL_IPV6" "$(mask_ipv6 "$EXTERNAL_IPV6")"
  fi

  for ip_version in 4 6; do
    add_debug_mask "${REGISTRATION_ORG[$ip_version]:-}" "$MASKED_ORG"
    if [[ -n "${REGISTRATION_ASN[$ip_version]:-}" ]]; then
      add_debug_mask "AS${REGISTRATION_ASN[$ip_version]}" "$MASKED_ASN"
    fi
  done

  add_debug_mask "$PROXY_ADDR" "$MASKED_VALUE"
  add_debug_mask "$HOME" "$MASKED_HOME"
}

print_debug_traces() {
  local trace

  cat -- "$DEBUG_TRACE_FILE"
  for trace in "$DEBUG_TRACE_DIR"/*; do
    if [[ ! -e "$trace" ]]; then
      continue
    fi

    printf '\n=== job %s\n' "${trace##*/}"
    cat -- "$trace"
  done
}

save_debug_log() {
  collect_debug_masks
  DEBUG_LOG_FILE=$(mktemp "${TMPDIR:-/tmp}/$DEBUG_LOG_TEMPLATE")
  print_debug_traces | LC_ALL=C awk -v limit="$DEBUG_RECORD_LIMIT" -v masked="$MASKED_VALUE" \
    "$DEBUG_LOG_FILTER" "${DEBUG_MASKS[@]}" >"$DEBUG_LOG_FILE"
}

confirm_debug_log_upload() {
  if [[ "$ASSUME_YES" == true ]]; then
    return 0
  fi

  if ! has_terminal; then
    print_note "Run with --yes to upload it"
    return 1
  fi

  printf '%sIP addresses, ASN and location are masked, but the log is public for anyone with the link.%s\n' "$M_DIM" "$M_RESET" >/dev/tty
  ask_yes_no "Upload it and get a link for the issue?"
}

upload_request() {
  local url="$1"
  shift
  local response_file="$WORK_DIR/$UPLOAD_RESPONSE_NAME"

  rm -f -- "$response_file"
  HTTP_CURL_EXIT="$CURL_EXIT_OK"
  HTTP_CODE=$(curl "${CURL_ARGS[@]}" --output "$response_file" --write-out "$UPLOAD_WRITE_OUT" "$@" "$url") || HTTP_CURL_EXIT=$?
  HTTP_BODY=""
  if [[ -f "$response_file" ]]; then
    HTTP_BODY=$(<"$response_file")
  fi
}

upload_to_x0_at() {
  upload_request "$X0_AT_UPLOAD_URL" --form "file=@$DEBUG_LOG_FILE"
}

upload_to_litterbox() {
  upload_request "$LITTERBOX_UPLOAD_URL" --form reqtype=fileupload --form "time=$LITTERBOX_RETENTION" \
    --form "fileToUpload=@$DEBUG_LOG_FILE"
}

print_debug_log_url() {
  if [[ "$HTTP_CURL_EXIT" != "$CURL_EXIT_OK" || ! "$HTTP_BODY" =~ $UPLOADED_URL_PATTERN ]]; then
    return 1
  fi

  printf 'Debug log: %s%s%s\n' "$M_VALUE" "$HTTP_BODY" "$M_RESET" >&2
}

upload_debug_log() {
  build_curl_args ""
  CURL_ARGS+=(--max-time "$DEBUG_UPLOAD_TIMEOUT" --speed-limit "$UPLOAD_SPEED_LIMIT" --speed-time "$UPLOAD_SPEED_TIME")
  print_note "Uploading the debug log..."

  upload_to_x0_at
  if print_debug_log_url; then
    return 0
  fi
  print_warning "$X0_AT_NAME failed: $(response_failure_reason), trying $LITTERBOX_NAME"

  upload_to_litterbox
  if print_debug_log_url; then
    return 0
  fi
  print_warning "$LITTERBOX_NAME failed: $(response_failure_reason)"

  print_error "failed to upload the debug log, attach $DEBUG_LOG_FILE to the issue instead"
}

start_debug_trace() {
  local trace_fd

  if [[ "$DEBUG" != true ]]; then
    return
  fi

  DEBUG_TRACE_FILE="$WORK_DIR/debug-trace"
  DEBUG_TRACE_DIR="$WORK_DIR/debug-traces"
  mkdir -- "$DEBUG_TRACE_DIR"
  print_debug_environment "$@" >"$DEBUG_TRACE_FILE"
  exec {trace_fd}>>"$DEBUG_TRACE_FILE"
  BASH_XTRACEFD="$trace_fd"
  PS4="$DEBUG_TRACE_PS4"
  set -x
}

finish_debug_trace() {
  if [[ -z "$DEBUG_TRACE_FILE" ]]; then
    return 0
  fi

  set +x
  save_debug_log
  printf '\nDebug log saved to %s%s%s\n' "$M_VALUE" "$DEBUG_LOG_FILE" "$M_RESET" >&2
  if confirm_debug_log_upload; then
    upload_debug_log
  fi
}

cleanup() {
  stop_jobs
  finish_debug_trace

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

  CURL_ARGS=("${CURL_BASE_ARGS[@]}" --max-time "$CURL_TIMEOUT" --retry-max-time "$CURL_TIMEOUT")

  if [[ -n "$PROXY_ADDR" ]]; then
    CURL_ARGS+=(--proxy "socks5h://$PROXY_ADDR")
  elif [[ -n "$ip_version" ]]; then
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
  local http_code

  build_curl_args "$ip_version"
  curl "${CURL_ARGS[@]}" --output "$entry.body" --write-out "$CURL_WRITE_OUT" "$@" "$url" >"$entry.meta" || curl_exit=$?
  printf '%s\n' "$curl_exit" >>"$entry.meta"
  read -r http_code <"$entry.meta"
  log_verbose "IPv${ip_version:-4/6} $url: HTTP $http_code, curl exit $curl_exit"
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
  if (set -o noclobber && : >"$entry.lock") 2>/dev/null; then
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
    return 0
  fi

  case "$HTTP_CODE" in
    "$HTTP_FORBIDDEN") printf '%s (%s)' "$REASON_FORBIDDEN" "$HTTP_CODE" ;;
    "$HTTP_TOO_MANY_REQUESTS") printf '%s (%s)' "$REASON_RATE_LIMITED" "$HTTP_CODE" ;;
    5[0-9][0-9]) printf '%s (%s)' "$REASON_SERVER_ERROR" "$HTTP_CODE" ;;
  esac
}

response_failure_reason() {
  local reason

  reason=$(http_failure_reason)
  if [[ -n "$reason" ]]; then
    printf '%s' "$reason"
    return 0
  fi

  printf '%s (%s)' "$REASON_UNEXPECTED_RESPONSE" "$HTTP_CODE"
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
  wait 2>/dev/null
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
  local cookie_jar="$WORK_DIR/maxmind-cookies"
  local csrf_token

  http_request "$ANY_TRANSPORT" "$MAXMIND_DEMO_PAGE_URL" --cookie-jar "$cookie_jar"
  if [[ ! "$HTTP_BODY" =~ $MAXMIND_CSRF_PATTERN ]]; then
    MAXMIND_TOKEN_FAILURE=$(response_failure_reason)
    return
  fi
  csrf_token="${BASH_REMATCH[1]}"

  http_request "$ANY_TRANSPORT" "$MAXMIND_TOKEN_URL" --request POST --cookie "$cookie_jar" --header "X-CSRF-Token: $csrf_token"
  if [[ "$HTTP_CODE" != "$HTTP_CREATED" ]]; then
    MAXMIND_TOKEN_FAILURE=$(response_failure_reason)
    return
  fi

  MAXMIND_TOKEN=$(json_value '.token // empty')
}

no_demo_token_reason() {
  if [[ -z "$MAXMIND_TOKEN_FAILURE" ]]; then
    printf '%s' "$REASON_NO_DEMO_TOKEN"
    return
  fi

  printf '%s: %s' "$REASON_NO_DEMO_TOKEN" "$MAXMIND_TOKEN_FAILURE"
}

fetch_maxmind_city() {
  local ip_version="$1"
  local ip="$2"
  local other_ip_version=4

  if [[ "$ip_version" == 4 ]]; then
    other_ip_version=6
  fi

  http_request "$ip_version" "$MAXMIND_CITY_URL/$ip?demo=1" --header "Authorization: Bearer $MAXMIND_TOKEN"
  if [[ "$HTTP_CODE" != "$HTTP_PAYMENT_REQUIRED" || -n "$PROXY_ADDR" || -z "$(external_ip "$other_ip_version")" ]]; then
    return
  fi

  http_request "$other_ip_version" "$MAXMIND_CITY_URL/$ip?demo=1" --header "Authorization: Bearer $MAXMIND_TOKEN"
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
    REGISTRATION_MAXMIND_FAILURE[$ip_version]=$(no_demo_token_reason)
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
}

lookup_ripe_registration() {
  local ip_version="$1"
  local ip="$2"

  http_request "$ip_version" "$RIPESTAT_PREFIX_OVERVIEW_URL?resource=$ip"
  REGISTRATION_ASN[$ip_version]=$(json_value '.data.asns[0].asn // empty')
  REGISTRATION_ORG[$ip_version]=$(json_value '.data.asns[0].holder // empty | sub("^\\S+ (- )?"; "")')
}

lookup_registration_country() {
  local ip_version="$1"
  local ip="$2"

  http_request "$ip_version" "$RIPESTAT_RIR_STATS_COUNTRY_URL?resource=$ip"
  REGISTRATION_COUNTRY[$ip_version]=$(json_value '.data.located_resources[0].location // empty')
}

lookup_ip_registration() {
  local ip_version="$1"
  local ip="$2"

  lookup_registration_country "$ip_version" "$ip"
  if lookup_maxmind_registration "$ip_version" "$ip"; then
    log_verbose "IPv$ip_version ASN from MaxMind"
    return
  fi

  log_verbose "IPv$ip_version ASN from RIPE, MaxMind: ${REGISTRATION_MAXMIND_FAILURE[$ip_version]}"
  lookup_ripe_registration "$ip_version" "$ip"
}

count_running_jobs() {
  jobs -pr | wc -l
}

is_progress_shown() {
  [[ -t 2 && "$VERBOSE" != true ]]
}

draw_spinner_line() {
  local text="$1"
  local spinner="${PROGRESS_SPINNER_FRAMES[PROGRESS_FRAME % ${#PROGRESS_SPINNER_FRAMES[@]}]}"

  PROGRESS_FRAME=$((PROGRESS_FRAME + 1))
  printf '%s%s%s%s  %s' "$CLEAR_LINE" "$M_ACCENT" "$spinner" "$M_RESET" "$text" >&2
}

clear_progress() {
  if ! is_progress_shown; then
    return
  fi

  printf '%s' "$CLEAR_LINE" >&2
}

prefetch_ip_registration() {
  local ip_version="$1"
  local ip="$2"

  lookup_registration_country "$ip_version" "$ip"
  request_maxmind_token
  if [[ -n "$MAXMIND_TOKEN" ]]; then
    fetch_maxmind_city "$ip_version" "$ip"
    if [[ -z "$(maxmind_failure_reason)" ]]; then
      return
    fi
  fi

  lookup_ripe_registration "$ip_version" "$ip"
}

fetch_external_ip_and_registration() {
  local ip_version="$1"
  local ip_file="$2"
  local ip

  fetch_external_ip "$ip_version" >"$ip_file"
  ip=$(<"$ip_file")
  if [[ -z "$ip" ]]; then
    return
  fi

  case "$ip_version" in
    4) EXTERNAL_IPV4="$ip" ;;
    6) EXTERNAL_IPV6="$ip" ;;
  esac
  prefetch_ip_registration "$ip_version" "$ip"
}

wait_for_preparation() {
  while (($(count_running_jobs) > 0)); do
    if is_progress_shown; then
      draw_spinner_line "$PREPARATION_LABEL"
    fi
    sleep "$JOB_POLL_INTERVAL"
  done

  clear_progress
}

discover_external_ips() {
  local ipv4_file="$WORK_DIR/external-ipv4"
  local ipv6_file="$WORK_DIR/external-ipv6"

  : >"$ipv4_file"
  : >"$ipv6_file"

  request_maxmind_token &

  if [[ "$IPV6_ONLY" != true ]]; then
    fetch_external_ip_and_registration 4 "$ipv4_file" &
  fi

  if [[ "$IPV4_ONLY" != true ]]; then
    fetch_external_ip_and_registration 6 "$ipv6_file" &
  fi

  wait_for_preparation
  EXTERNAL_IPV4=$(<"$ipv4_file")
  EXTERNAL_IPV6=$(<"$ipv6_file")

  log_verbose "External IPv4: ${EXTERNAL_IPV4:-not found}, IPv6: ${EXTERNAL_IPV6:-not found}"

  if [[ -n "$EXTERNAL_IPV4" || -n "$EXTERNAL_IPV6" ]]; then
    return
  fi

  if [[ -n "$INTERFACE_NAME" ]]; then
    print_error "failed to detect an external IP address through interface $INTERFACE_NAME, check that it exists and routes traffic out"
    exit 1
  fi

  print_error "failed to detect an external IP address, check the network connection"
  exit 1
}

lookup_ip_registrations() {
  request_maxmind_token

  if [[ -n "$EXTERNAL_IPV4" ]]; then
    lookup_ip_registration 4 "$EXTERNAL_IPV4"
  fi

  if [[ -n "$EXTERNAL_IPV6" ]]; then
    lookup_ip_registration 6 "$EXTERNAL_IPV6"
  fi
}

escape_json_string() {
  local -n json_value_ref=$1

  json_value_ref=${json_value_ref//\\/\\\\}
  json_value_ref=${json_value_ref//\"/\\\"}
  json_value_ref=${json_value_ref//$'\n'/\\n}
  json_value_ref=${json_value_ref//$'\r'/\\r}
  json_value_ref=${json_value_ref//$'\t'/\\t}
  json_value_ref=${json_value_ref//[$'\001'-$'\037']/}
}

print_result() {
  local group="$1"
  local service="$2"
  local ip_version="$3"
  local country="$4"
  local status="$5"
  local reason="$6"

  local field

  log_verbose "$group / $service IPv$ip_version: country ${country:--}, status ${status:--}, reason ${reason:--}"
  for field in group service ip_version country status reason; do
    escape_json_string "$field"
  done
  printf '{"group":"%s","service":"%s","ip_version":"%s","country":"%s","status":"%s","reason":"%s"}\n' \
    "$group" "$service" "$ip_version" "$country" "$status" "$reason"
}

print_progress_bar() {
  local finished="$1"
  local done_width=$((PROGRESS_BAR_WIDTH * finished / JOB_COUNT))
  local done_part left_part

  printf -v done_part '%*s' "$done_width" ''
  printf -v left_part '%*s' "$((PROGRESS_BAR_WIDTH - done_width))" ''
  printf '%s%s%s%s%s' "$M_ACCENT" "${done_part// /$PROGRESS_BAR_DONE}" "$M_DIM" "${left_part// /$PROGRESS_BAR_LEFT}" "$M_RESET"
}

draw_progress() {
  local finished

  if ! is_progress_shown; then
    return
  fi

  finished=$((JOB_COUNT - $(count_running_jobs)))
  draw_spinner_line "$PROGRESS_LABEL  $(print_progress_bar "$finished")  $M_DIM$finished/$JOB_COUNT$M_RESET"
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
  read -r -N 1 -u "$JOB_SLOTS_FD" _
}

return_job_slot() {
  printf ' ' >&"$JOB_SLOTS_FD"
}

run_job() {
  local result_file="$1"
  shift
  local trace_fd

  if [[ -n "$DEBUG_TRACE_DIR" ]]; then
    exec {trace_fd}>"$DEBUG_TRACE_DIR/${result_file##*/}"
    BASH_XTRACEFD="$trace_fd"
  fi

  take_job_slot
  trap return_job_slot EXIT
  "$@" >"$result_file"
  # bash 4.4 skips the EXIT trap of a background function that returns without exit
  exit
}

run_check() {
  local check="$1"
  local ip_version="$2"
  local id result

  id=$(check_id "$check")
  result=$("$check" "$ip_version")
  printf '{"id":"%s",%s\n' "$id" "${result#\{}"
}

start_job() {
  local result_file

  JOB_COUNT=$((JOB_COUNT + 1))
  printf -v result_file '%s/%s%04d' "$WORK_DIR" "$RESULT_FILE_PREFIX" "$JOB_COUNT"
  run_job "$result_file" "$@" &
}

start_check() {
  local check="$1"

  if is_checked_once "$(check_group "$check")"; then
    start_job run_check "$check" "$PROXY_IP_VERSION"
    return
  fi

  if [[ -n "$EXTERNAL_IPV4" ]]; then
    start_job run_check "$check" 4
  fi

  if [[ -n "$EXTERNAL_IPV6" ]]; then
    start_job run_check "$check" 6
  fi
}

is_dual_stack() {
  [[ -n "$EXTERNAL_IPV4" && -n "$EXTERNAL_IPV6" ]]
}

is_checked_once() {
  local group="$1"

  [[ -n "$PROXY_ADDR" && "$group" != "$GROUP_GEOIP" ]] && is_dual_stack
}

is_check_selected() {
  local check="$1"

  is_group_selected "$(check_group "$check")" || is_in_list "$check" "${SELECTED_CHECKS[@]}"
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
    print_failure "$GROUP_GEOIP" MaxMind "$ip_version" "$(no_demo_token_reason)"
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

cloudflare_trace_ip_version() {
  if [[ ! "$HTTP_BODY" =~ $CLOUDFLARE_IP_PATTERN ]]; then
    return
  fi

  case "${BASH_REMATCH[2]}" in
    "$EXTERNAL_IPV4") printf '4' ;;
    "$EXTERNAL_IPV6") printf '6' ;;
  esac
}

check_geoip_cloudflare() {
  local ip_version="$1"
  local country=""
  local used_ip_version

  http_request "$ip_version" "$CLOUDFLARE_TRACE_URL"
  used_ip_version=$(cloudflare_trace_ip_version)
  if [[ -n "$PROXY_ADDR" && -n "$used_ip_version" && "$used_ip_version" != "$ip_version" ]]; then
    print_result "$GROUP_GEOIP" Cloudflare "$ip_version" "" "$STATUS_NONE" "$REASON_PROXY_PICKED$used_ip_version"
    return
  fi

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

check_platforms_claude() {
  local ip_version="$1"

  check_platforms_json Claude "$ip_version" "$CLAUDE_URL" '.statsig.user.country // empty' \
    --user-agent "$CLAUDE_USER_AGENT" --header "$CLAUDE_PLATFORM_HEADER"
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

  http_request "$ip_version" "$REDDIT_NOT_FOUND_URL" --user-agent "$USER_AGENT"
  if [[ "$HTTP_CODE" == "$HTTP_FORBIDDEN" ]]; then
    print_result "$GROUP_PLATFORMS" Reddit "$ip_version" "" "$STATUS_IPBLOCK" "$(http_failure_reason)"
    return
  fi

  check_platforms_pattern Reddit "$ip_version" "$REDDIT_NOT_FOUND_URL" "$REDDIT_COUNTRY_PATTERN" --user-agent "$USER_AGENT"
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

  if [[ "$HTTP_BODY" == *"$YOUTUBE_PREMIUM_PURCHASE_MARKER"* ]]; then
    printf '%s' "$STATUS_YES"
    return
  fi

  printf '%s' "$STATUS_NO"
}

check_availability_youtube_premium() {
  local ip_version="$1"

  http_request "$ip_version" "$YOUTUBE_INNERTUBE_BROWSE_URL" --json "$YOUTUBE_PREMIUM_QUERY"
  print_status "$GROUP_AVAILABILITY" "YouTube Premium" "$ip_version" "$(youtube_premium_status)"
}

youtube_no_ads_status() {
  if [[ "$HTTP_CODE" != "$HTTP_OK" || "$HTTP_BODY" != *"$YOUTUBE_PLAYER_RESPONSE_MARKER"* ]]; then
    return
  fi

  if [[ "$HTTP_BODY" == *"$YOUTUBE_VIDEO_AD_MARKER"* ]]; then
    printf '%s' "$STATUS_NO"
    return
  fi

  printf '%s' "$STATUS_YES"
}

# YouTube serves ads only to a visitor with cookies, so the first load just collects them.
check_availability_youtube_no_ads() {
  local ip_version="$1"
  local cookie_jar="$WORK_DIR/$YOUTUBE_COOKIE_JAR_PREFIX$ip_version"
  local service="$YOUTUBE_NO_ADS_SERVICE_PREFIX ${YOUTUBE_LANG^^}"
  local viewer_cookie="$YOUTUBE_VIEWER_COOKIE_PREFIX$YOUTUBE_LANG"
  local accept_language="$ACCEPT_LANGUAGE_PREFIX$YOUTUBE_LANG"
  local status

  http_request "$ip_version" "$YOUTUBE_WATCH_URL" --user-agent "$USER_AGENT" \
    --header "$viewer_cookie" --header "$accept_language" --cookie-jar "$cookie_jar"
  http_request "$ip_version" "$YOUTUBE_WATCH_URL" --user-agent "$USER_AGENT" \
    --header "$viewer_cookie" --header "$accept_language" --cookie "$cookie_jar"
  status=$(youtube_no_ads_status)
  if [[ "$status" == "$STATUS_NO" ]]; then
    print_result "$GROUP_AVAILABILITY" "$service" "$ip_version" "" "$STATUS_NO" "$REASON_VIDEO_ADS"
    return
  fi

  print_status "$GROUP_AVAILABILITY" "$service" "$ip_version" "$status"
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

is_google_search_captcha() {
  [[ "$HTTP_REDIRECT_URL" == *"$GOOGLE_SEARCH_CAPTCHA_PATH"* || "$HTTP_CODE" == "$HTTP_TOO_MANY_REQUESTS" ]]
}

google_search_status() {
  if [[ "$HTTP_CODE" == "$HTTP_OK" && "$HTTP_BODY" == *"$GOOGLE_SEARCH_NO_JS_MARKER"* ]]; then
    printf '%s' "$STATUS_YES"
  fi
}

check_availability_google_search() {
  local ip_version="$1"

  http_request "$ip_version" "$GOOGLE_SEARCH_URL" \
    --user-agent "$USER_AGENT" --header "$GOOGLE_SOCS_COOKIE" --header "$ACCEPT_LANGUAGE_ENGLISH"
  if is_google_search_captcha; then
    print_result "$GROUP_AVAILABILITY" "Google Search" "$ip_version" "" "$STATUS_IPBLOCK" "$REASON_CAPTCHA"
    return
  fi

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

check_ai_qwen_api() {
  local ip_version="$1"

  check_ai_reachability "Qwen API" "$ip_version" "$QWEN_API_URL"
}

check_ai_qwen_cn_api() {
  local ip_version="$1"

  check_ai_reachability "Qwen CN API" "$ip_version" "$QWEN_CN_API_URL"
}

check_ai_kimi_api() {
  local ip_version="$1"

  check_ai_reachability "Kimi API" "$ip_version" "$KIMI_API_URL"
}

check_ai_kimi_cn_api() {
  local ip_version="$1"

  check_ai_reachability "Kimi CN API" "$ip_version" "$KIMI_CN_API_URL"
}

check_ai_glm_api() {
  local ip_version="$1"

  check_ai_reachability "GLM API" "$ip_version" "$GLM_API_URL"
}

check_ai_glm_cn_api() {
  local ip_version="$1"

  check_ai_reachability "GLM CN API" "$ip_version" "$GLM_CN_API_URL"
}

check_ai_minimax_api() {
  local ip_version="$1"

  check_ai_reachability "MiniMax API" "$ip_version" "$MINIMAX_API_URL"
}

check_ai_minimax_cn_api() {
  local ip_version="$1"

  check_ai_reachability "MiniMax CN API" "$ip_version" "$MINIMAX_CN_API_URL"
}

check_ai_doubao_api() {
  local ip_version="$1"

  check_ai_reachability "Doubao API" "$ip_version" "$DOUBAO_API_URL"
}

check_ai_siliconflow_api() {
  local ip_version="$1"

  check_ai_reachability "SiliconFlow API" "$ip_version" "$SILICONFLOW_API_URL"
}

check_ai_deepseek_api() {
  local ip_version="$1"

  check_ai_reachability "DeepSeek API" "$ip_version" "$DEEPSEEK_API_URL"
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
      --arg none "$STATUS_NONE" \
      --arg cdn "$GROUP_CDN" \
      --arg geoip "$GROUP_GEOIP" \
      --arg different_country "$REASON_DIFFERENT_COUNTRY" \
      --arg video_ads "$REASON_VIDEO_ADS" \
      --arg daily_limit "$REASON_DAILY_LIMIT" \
      --argjson collapse_min "$ATTENTION_COLLAPSE_MIN" \
      "$ATTENTION_FILTER" <<<"$RESULTS"
  )
}

first_ip_version() {
  if [[ -n "$EXTERNAL_IPV4" ]]; then
    printf '4'
    return
  fi

  printf '6'
}

count_abnormal_checks() {
  jq \
    --arg verdict "$VERDICT" \
    --arg yes "$STATUS_YES" \
    --arg none "$STATUS_NONE" \
    --arg cdn "$GROUP_CDN" \
    --arg geoip "$GROUP_GEOIP" \
    --arg video_ads "$REASON_VIDEO_ADS" \
    --arg daily_limit "$REASON_DAILY_LIMIT" \
    "$ABNORMAL_CHECKS_FILTER" <<<"$RESULTS"
}

count_checks() {
  CHECKS_TOTAL=$(jq --arg cdn "$GROUP_CDN" '[.[] | select(.group != $cdn) | [.group, .service]] | unique | length' <<<"$RESULTS")
  CHECKS_NORMAL=$((CHECKS_TOTAL - $(count_abnormal_checks)))
}

checks_health() {
  local percent

  if ((CHECKS_TOTAL == 0)); then
    printf '%s' "$CHECKS_GOOD"
    return
  fi

  percent=$((CHECKS_NORMAL * 100 / CHECKS_TOTAL))
  if ((percent >= CHECKS_GOOD_PERCENT)); then
    printf '%s' "$CHECKS_GOOD"
  elif ((percent >= CHECKS_FAIR_PERCENT)); then
    printf '%s' "$CHECKS_FAIR"
  else
    printf '%s' "$CHECKS_POOR"
  fi
}

checks_bar_color() {
  case "$(checks_health)" in
    "$CHECKS_GOOD") printf '%s' "$C_BAR" ;;
    "$CHECKS_FAIR") printf '%s' "$C_BAR_FAIR" ;;
    "$CHECKS_POOR") printf '%s' "$C_BAR_POOR" ;;
  esac
}

checks_badge_color() {
  case "$(checks_health)" in
    "$CHECKS_GOOD") printf '%s' "$C_BADGE" ;;
    "$CHECKS_FAIR") printf '%s' "$C_BADGE_FAIR" ;;
    "$CHECKS_POOR") printf '%s' "$C_BADGE_POOR" ;;
  esac
}

print_bar() {
  local color="$1"
  local filled_parts="$2"
  local total_parts="$3"
  local width="$4"
  local filled_width

  if ((total_parts == 0)); then
    return
  fi

  filled_width=$((width * filled_parts / total_parts))
  printf '%s%s%s%s%s' "$color" "$(repeat_char "$SUMMARY_BAR_CHAR" "$filled_width")" "$C_DIM" \
    "$(repeat_char "$SUMMARY_BAR_REST_CHAR" "$((width - filled_width))")" "$C_RESET"
}

has_protocol_columns() {
  local group="$1"

  is_dual_stack && ! is_checked_once "$group"
}

country_name() {
  local country="$1"

  http_request "$(first_ip_version)" "$CLDR_TERRITORIES_URL"
  json_value ".main.en.localeDisplayNames.territories.$country // empty"
}

group_rows() {
  local group="$1"

  jq -r \
    --arg group "$group" \
    --arg yes "$STATUS_YES" \
    --arg unknown "$STATUS_UNKNOWN" \
    --arg daily_limit "$REASON_DAILY_LIMIT" \
    --arg limit "$MAXMIND_LIMIT_CELL" \
    "$GROUP_ROWS_FILTER" <<<"$RESULTS"
}

cdn_edge_rows() {
  jq -r --arg cdn "$GROUP_CDN" --arg unknown "$STATUS_UNKNOWN" "$CDN_ROWS_FILTER" <<<"$RESULTS"
}

geoip_majority() {
  jq -r --arg geoip "$GROUP_GEOIP" --arg yes "$STATUS_YES" "$GEOIP_MAJORITY_FILTER" <<<"$RESULTS"
}

format_network() {
  local ip_version="$1"
  local asn="${REGISTRATION_ASN[$ip_version]:-}"
  local organization="${REGISTRATION_ORG[$ip_version]:-}"

  if [[ -z "$asn" ]]; then
    printf '%s' "$organization"
    return
  fi

  printf 'AS%s%s' "$asn" "${organization:+ $organization}"
}

build_header_columns() {
  HEADER_IP_VERSIONS=()
  HEADER_IP_VALUES=()
  HEADER_NETWORKS=()
  HEADER_EXIT_LABEL=""

  if [[ -n "$EXTERNAL_IPV4" ]]; then
    HEADER_IP_VERSIONS+=(4)
    HEADER_IP_VALUES+=("$(mask_ipv4 "$EXTERNAL_IPV4")")
    HEADER_NETWORKS+=("$(format_network 4)")
  fi

  if [[ -n "$EXTERNAL_IPV6" ]]; then
    HEADER_IP_VERSIONS+=(6)
    HEADER_IP_VALUES+=("$(mask_ipv6 "$EXTERNAL_IPV6")")
    HEADER_NETWORKS+=("$(format_network 6)")
  fi

  if [[ -n "$PROXY_ADDR" ]]; then
    HEADER_EXIT_LABEL="proxy"
  elif [[ -n "$INTERFACE_NAME" ]]; then
    HEADER_EXIT_LABEL="$INTERFACE_NAME interface"
  fi

  HEADER_VALUE_WIDTH=$(($(max_length "${HEADER_IP_VALUES[@]}" "$HEADER_EXIT_LABEL") + NAME_GAP))
  HEADER_NETWORK_WIDTH=$(($(max_length "${HEADER_NETWORKS[@]}") + NAME_GAP))
}

print_ip_line() {
  local ip_version="$1"
  local masked_ip="$2"
  local network="$3"
  local country="${REGISTRATION_COUNTRY[$ip_version]:-$SYMBOL_UNKNOWN}"

  printf ' '
  pad_cell "" "IPv$ip_version" "$HEADER_LABEL_WIDTH"
  pad_cell "$C_VALUE" "$masked_ip" "$HEADER_VALUE_WIDTH"
  pad_cell "" "$network" "$HEADER_NETWORK_WIDTH"
  printf '%s %s\n' "$(paint "$C_DIM" "$REGISTERED_NOTE")" "$(paint "$C_VALUE" "$(label_country "$country")")"
}

is_maxmind_limit_used_up() {
  local failure

  for failure in "${REGISTRATION_MAXMIND_FAILURE[@]}"; do
    if [[ "$failure" == "$REASON_DAILY_LIMIT" ]]; then
      return 0
    fi
  done

  return 1
}

has_maxmind_failure() {
  local failure

  for failure in "${REGISTRATION_MAXMIND_FAILURE[@]}"; do
    if [[ -n "$failure" ]]; then
      return 0
    fi
  done

  return 1
}

maxmind_header_note() {
  if is_maxmind_limit_used_up; then
    printf '%s' "$MAXMIND_LIMIT_HEADER_NOTE"
    return
  fi

  if has_maxmind_failure; then
    printf '%s' "$MAXMIND_FAILURE_HEADER_NOTE"
  fi
}

print_ip_lines() {
  local i note

  for i in "${!HEADER_IP_VERSIONS[@]}"; do
    print_ip_line "${HEADER_IP_VERSIONS[i]}" "${HEADER_IP_VALUES[i]}" "${HEADER_NETWORKS[i]}"
  done

  note=$(maxmind_header_note)
  if [[ -n "$note" ]]; then
    printf ' %s%s\n' "$(pad "" "$HEADER_LABEL_WIDTH")" "$(paint "$C_DIM" "$note")"
  fi
}

print_verdict_line() {
  local country="$1"
  local note="$2"
  local name

  name=$(country_name "$country")
  printf ' '
  pad_cell "" "$(paint "$(checks_badge_color)" " $country ")" "$HEADER_LABEL_WIDTH"
  pad_cell "$C_VALUE" "${name:-$country}" "$HEADER_VALUE_WIDTH"
  printf '%s\n' "${note:+$(paint "$C_DIM" "$note")}"
}

print_verdict_lines() {
  local -a countries=("${VERDICT_TIED_COUNTRIES[@]}")
  local note="$TIE_NOTE"
  local country

  if [[ -n "$VERDICT" ]]; then
    countries=("$VERDICT")
    note="$VERDICT_NOTE"
  fi

  if ((${#countries[@]} == 0)); then
    return
  fi

  printf '\n'
  for country in "${countries[@]}"; do
    print_verdict_line "$country" "$note"
    note=""
  done
}

print_checks_bar() {
  if ((CHECKS_TOTAL == 0)); then
    return
  fi

  printf ' %s  %s\n' "$(print_bar "$(checks_bar_color)" "$CHECKS_NORMAL" "$CHECKS_TOTAL" "$CHECKS_BAR_WIDTH")" \
    "$(paint "$C_DIM" "$CHECKS_NORMAL/$CHECKS_TOTAL $CHECKS_PASSED_NOTE")"
}

format_exits() {
  if is_dual_stack; then
    printf '%s' "$DUAL_STACK_EXITS"
    return
  fi

  printf 'IPv%s only' "$(first_ip_version)"
}

print_exits_line() {
  if [[ -z "$HEADER_EXIT_LABEL" ]]; then
    return
  fi

  printf ' '
  pad_cell "" "" "$HEADER_LABEL_WIDTH"
  pad_cell "$C_VALUE" "$HEADER_EXIT_LABEL" "$HEADER_VALUE_WIDTH"
  printf '%s %s\n' "$(paint "$C_DIM" "$EXITS_NOTE")" "$(paint "$C_VALUE" "$(format_exits)")"
}

print_host_lines() {
  printf ' %s\n' "$(paint "$C_DIM" "Made with $(paint "$C_NO" "<3")${C_DIM} by $AUTHOR ·") ${SCRIPT_URL#https://}"
  printf '\n'
  print_ip_lines
  print_exits_line
}

print_header() {
  build_header_columns
  {
    print_host_lines
    print_verdict_lines
    print_checks_bar
  } | print_bar_block
}

set_card_widths() {
  LEFT_CARD_WIDTH="$1"
  RIGHT_CARD_WIDTH="$2"
  FULL_CARD_WIDTH=$((LEFT_CARD_WIDTH + CARD_GAP + RIGHT_CARD_WIDTH))
  # The Issue / Node column of a full-width card starts where the paired right card's content starts
  RIGHT_COLUMN_START=$((LEFT_CARD_WIDTH + CARD_GAP + 1))
  RIGHT_COLUMN_WIDTH=$((FULL_CARD_WIDTH - CARD_SIDES_WIDTH - CARD_CONTENT_INDENT - CARD_TRAILING_GAP - RIGHT_COLUMN_START))
  GEOIP_LINE_WIDTH=$((FULL_CARD_WIDTH - CARD_SIDES_WIDTH - 2 * CARD_CONTENT_INDENT - 2 * CARD_TRAILING_GAP))
  CHECKS_BAR_WIDTH=$((FULL_CARD_WIDTH - CHECKS_BAR_MARGIN))
}

is_service_report() {
  ((${#SELECTED_GROUPS[@]} == 0))
}

has_group_results() {
  local group="$1"

  jq -e --arg group "$group" 'any(.group == $group)' <<<"$RESULTS" >/dev/null
}

is_geoip_list_shown() {
  [[ "$GEOIP_BREAKDOWN" == true || "${SELECTED_GROUPS[*]}" == "$GROUP_GEOIP" ]] || is_service_report
}

is_geoip_list_split_by_protocol() {
  has_group_results "$GROUP_GEOIP" && has_protocol_columns "$GROUP_GEOIP" && is_geoip_list_shown
}

set_report_widths() {
  if has_protocol_columns "$GROUP_PLATFORMS" || is_geoip_list_split_by_protocol; then
    set_card_widths "$WIDE_LEFT_CARD_WIDTH" "$WIDE_RIGHT_CARD_WIDTH"
    return
  fi

  set_card_widths $((WIDE_LEFT_CARD_WIDTH - LEFT_GRID_CELL)) $((WIDE_RIGHT_CARD_WIDTH - RIGHT_GRID_CELL))
}

report_columns() {
  local group="$1"

  if is_checked_once "$group"; then
    printf '%s\n' "$PROXY_IP_VERSION"
    return
  fi

  if is_dual_stack; then
    printf '4\n6\n'
    return
  fi

  printf '%s\n' "$(first_ip_version)"
}

column_title() {
  case "$1" in
    4) printf 'IPv4' ;;
    6) printf 'IPv6' ;;
    "$PROXY_IP_VERSION") printf 'Proxy' ;;
  esac
}

attention_value() {
  local country="$1"
  local status="$2"

  if [[ -n "$country" ]]; then
    printf '%s' "$country"
    return
  fi

  printf '%s' "${status:-$STATUS_UNKNOWN}"
}

attention_cell() {
  local value="$1"

  if [[ -z "$value" ]]; then
    paint "$C_DIM" "$(pad "$ATTENTION_EMPTY_CELL" "$LEFT_GRID_CELL")"
    return
  fi

  format_cell "$value" "$LEFT_GRID_CELL"
}

wrap_words() {
  local -n wrapped_words=$1
  local width="$2"
  local text="$3"
  local -a parts=()
  local part line=""

  read -ra parts <<<"$text"
  wrapped_words=()
  for part in "${parts[@]}"; do
    if [[ -n "$line" ]] && ((${#line} + 1 + ${#part} > width)); then
      wrapped_words+=("$line")
      line=""
    fi
    line+="${line:+ }$part"
  done
  wrapped_words+=("$line")
}

wrap_services() {
  local -n wrapped_services=$1
  local width="$2"
  shift 2
  local total=$#
  local reserved=$((3 + ${#total}))
  local line=""
  local shown=0
  local service budget

  wrapped_services=()
  for service in "$@"; do
    budget="$width"
    if ((${#wrapped_services[@]} == ATTENTION_LIST_LINES - 1)); then
      budget=$((width - reserved))
    fi
    if [[ -n "$line" ]] && ((${#line} + 3 + ${#service} > budget)); then
      wrapped_services+=("$line,")
      line=""
      if ((${#wrapped_services[@]} == ATTENTION_LIST_LINES)); then
        break
      fi
    fi
    line+="${line:+, }$service"
    shown=$((shown + 1))
  done

  if [[ -n "$line" ]] && ((${#wrapped_services[@]} < ATTENTION_LIST_LINES)); then
    wrapped_services+=("$line")
  fi

  if ((shown < total)); then
    wrapped_services[-1]="${wrapped_services[-1]%,}, +$((total - shown))"
  fi
}

append_card_titles() {
  local -n card_titles=$1
  local group="$2"
  local name_width="$3"
  local cell_width="$4"
  local -a columns=()
  local line column

  mapfile -t columns < <(report_columns "$group")
  line=" $(pad_cell "$C_DIM" Service "$name_width")"
  for column in "${columns[@]}"; do
    line+="$(pad_cell "$C_DIM" "$(column_title "$column")" "$cell_width")"
  done
  card_titles+=("$line")
}

append_attention_titles() {
  local -n titles=$1

  append_card_titles titles "$GROUP_PLATFORMS" "$LEFT_GRID_NAME" "$LEFT_GRID_CELL"
  titles[-1]="$(pad "${titles[-1]}" "$RIGHT_COLUMN_START")$(paint "$C_DIM" Issue)"
}

append_attention_row() {
  local -n attention_rows=$1
  local name="$2" ip_version="$3" value="$4" reason="$5"
  local -a columns=() issue_lines=()
  local line column issue

  mapfile -t columns < <(report_columns "$GROUP_PLATFORMS")
  line=" $(pad_cell "$C_VALUE" "$name" "$LEFT_GRID_NAME")"
  for column in "${columns[@]}"; do
    if ((${#columns[@]} == 1)) || [[ "$ip_version" == "$column" || "$ip_version" == "$BOTH_IP_VERSION" ]]; then
      line+="$(attention_cell "$value")"
    else
      line+="$(attention_cell "")"
    fi
  done

  wrap_words issue_lines "$RIGHT_COLUMN_WIDTH" "$reason"
  attention_rows+=("$(pad "$line" "$RIGHT_COLUMN_START")${issue_lines[0]}")
  for issue in "${issue_lines[@]:1}"; do
    attention_rows+=("$(printf '%*s' "$RIGHT_COLUMN_START" '')$issue")
  done
}

append_attention_services() {
  local -n attention_lines=$1
  shift
  local -a service_lines=()
  local line

  wrap_services service_lines "$RIGHT_COLUMN_WIDTH" "$@"
  for line in "${service_lines[@]}"; do
    attention_lines+=("$(printf '%*s' "$RIGHT_COLUMN_START" '')$(paint "$C_DIM" "$line")")
  done
}

print_attention() {
  local -a fields rows=() services=()
  local i count value

  if [[ "$SHOW_ATTENTION" == false ]] || is_service_report; then
    return
  fi

  mapfile -t fields < <(jq -r '.[] | .ip_version, .country, .status, .reason, (.services | length), .services[]' <<<"$ATTENTION")
  if ((${#fields[@]} == 0)); then
    return
  fi

  append_attention_titles rows
  for ((i = 0; i < ${#fields[@]}; i += ATTENTION_ENTRY_FIELDS + count)); do
    count="${fields[i + 4]}"
    services=("${fields[@]:i+ATTENTION_ENTRY_FIELDS:count}")
    value=$(attention_value "${fields[i + 1]}" "${fields[i + 2]}")
    if ((count == 1)); then
      append_attention_row rows "${services[0]}" "${fields[i]}" "$value" "${fields[i + 3]}"
      continue
    fi
    append_attention_row rows "$count services" "${fields[i]}" "$value" "${fields[i + 3]}:"
    append_attention_services rows "${services[@]}"
  done

  printf '%s\n' "${rows[@]}" | print_titled_card "$C_WARN" Attention "$FULL_CARD_WIDTH" 0
}

print_card_rows() {
  local group="$1"
  local name_width="$2"
  local cell_width="$3"
  shift 3
  local -a rows=("$@") card_lines=()
  local i line

  append_card_titles card_lines "$group" "$name_width" "$cell_width"
  for ((i = 0; i < ${#rows[@]}; i += GROUP_ROW_FIELDS)); do
    line=" $(pad_cell "" "${rows[i]}" "$name_width")$(format_cell "${rows[i + 1]}" "$cell_width")"
    if has_protocol_columns "$group"; then
      line+="$(format_cell "${rows[i + 2]}" "$cell_width")"
    fi
    card_lines+=("$line")
  done
  printf '%s\n' "${card_lines[@]}"
}

print_group_card_lines() {
  local group="$1"
  local name_width="$2"
  local cell_width="$3"
  local -a fields

  mapfile -t fields < <(group_rows "$group")
  if ((${#fields[@]} == 0)); then
    return
  fi

  print_card_rows "$group" "$name_width" "$cell_width" "${fields[@]}"
}

print_halves() {
  local group="$1"
  local -a fields left_half=() right_half=()
  local half i

  mapfile -t fields < <(group_rows "$group")
  if ((${#fields[@]} == 0)); then
    return
  fi

  half=$((${#fields[@]} / GROUP_ROW_FIELDS))
  half=$(((half + 1) / 2))
  half=$((half * GROUP_ROW_FIELDS))
  mapfile -t left_half < <(print_card_rows "$group" "$LEFT_GRID_NAME" "$LEFT_GRID_CELL" "${fields[@]:0:half}")
  if ((${#fields[@]} > half)); then
    mapfile -t right_half < <(print_card_rows "$group" "$RIGHT_GRID_NAME" "$RIGHT_GRID_CELL" "${fields[@]:half}")
  fi

  for i in "${!left_half[@]}"; do
    if [[ -z "${right_half[i]:-}" ]]; then
      printf '%s\n' "${left_half[i]}"
      continue
    fi
    printf '%s%s\n' "$(pad "${left_half[i]}" "$RIGHT_COLUMN_START")" "${right_half[i]# }"
  done
}

print_halves_card() {
  local group="$1"
  local title="$2"
  local halves

  halves=$(print_halves "$group")
  if [[ -z "$halves" ]]; then
    return
  fi

  printf '%s\n' "$halves" | print_titled_card "$C_TITLE" "$title" "$FULL_CARD_WIDTH" 0
}

print_availability() {
  print_halves_card "$GROUP_AVAILABILITY" Availability
}

print_platforms_and_ai() {
  local platforms ai

  platforms=$(print_group_card_lines "$GROUP_PLATFORMS" "$LEFT_GRID_NAME" "$LEFT_GRID_CELL")
  ai=$(print_group_card_lines "$GROUP_AI" "$RIGHT_GRID_NAME" "$RIGHT_GRID_CELL")
  if [[ -n "$platforms" && -n "$ai" ]]; then
    print_titled_card_pair Platforms AI "$platforms" "$ai"
    return
  fi

  print_halves_card "$GROUP_PLATFORMS" Platforms
  print_halves_card "$GROUP_AI" AI
}

append_geoip_deviation() {
  local -n deviation_lines=$1
  local country="$2"
  local ip_version="$3"
  shift 3
  local country_width=$((GEOIP_COUNTRY_WIDTH + COUNTRY_EXTRA))
  local protocol=""
  local service_list=""
  local -a service_lines=()
  local service line

  if has_protocol_columns "$GROUP_GEOIP"; then
    protocol="v$ip_version"
  fi

  for service in "$@"; do
    service_list+="${service_list:+, }$service"
  done
  wrap_words service_lines $((GEOIP_LINE_WIDTH - country_width - ${#protocol} - 1)) "$service_list"
  line="$(format_country "$country" "$country_width")$(pad "${service_lines[0]}" $((GEOIP_LINE_WIDTH - country_width - ${#protocol})))"
  deviation_lines+=(" $line$(paint "$C_DIM" "$protocol")")
  for line in "${service_lines[@]:1}"; do
    deviation_lines+=(" $(printf '%*s' "$country_width" '')$line")
  done
}

print_geoip_deviations() {
  local reference="$1"
  local -a fields lines=()
  local i count

  mapfile -t fields < <(jq -r --arg geoip "$GROUP_GEOIP" --arg yes "$STATUS_YES" --arg reference "$reference" "$GEOIP_DEVIATIONS_FILTER" <<<"$RESULTS")
  for ((i = 0; i < ${#fields[@]}; i += GEOIP_DEVIATION_FIELDS + count)); do
    count="${fields[i + 2]}"
    append_geoip_deviation lines "${fields[i]}" "${fields[i + 1]}" "${fields[@]:i+GEOIP_DEVIATION_FIELDS:count}"
  done

  if ((${#lines[@]} > 0)); then
    printf '%s\n' "${lines[@]}"
  fi
}

print_geoip_agreement() {
  local emoji=""

  if [[ "$SHOW_EMOJI" == true ]]; then
    emoji="$GEOIP_AGREEMENT_EMOJI "
  fi

  printf ' %s%s\n' "$emoji" "$(paint "$C_YES" "$GEOIP_AGREEMENT_NOTE")"
}

print_geoip_lines() {
  local reference="$1"
  local agree="$2"
  local total="$3"
  local limited="$4"

  printf ' %s\n' "$(print_bar "$C_BAR" "$agree" "$total" "$GEOIP_LINE_WIDTH")"
  if is_geoip_list_shown; then
    print_halves "$GROUP_GEOIP"
    return
  fi

  print_geoip_deviations "$reference"
  if ((agree == total)); then
    print_geoip_agreement
  fi
  if [[ "$limited" == true ]]; then
    printf ' %s\n' "$(paint "$C_DIM" "$MAXMIND_LIMIT_SUMMARY_NOTE")"
  fi
}

print_geoip() {
  local reference summary
  local -a agreement

  if is_service_report; then
    print_halves_card "$GROUP_GEOIP" GeoIP
    return
  fi

  reference="${VERDICT:-$(geoip_majority)}"
  mapfile -t agreement < <(jq -r --arg geoip "$GROUP_GEOIP" --arg yes "$STATUS_YES" --arg reference "$reference" \
    --arg daily_limit "$REASON_DAILY_LIMIT" "$GEOIP_AGREEMENT_FILTER" <<<"$RESULTS")
  if ((agreement[1] == 0)) && [[ "${agreement[2]}" != true ]]; then
    return
  fi

  summary="$(paint "$C_VALUE" "$(label_country "${reference:-$SYMBOL_UNKNOWN}")") $(paint "$C_DIM" "${agreement[0]}/${agreement[1]}")"
  print_geoip_lines "$reference" "${agreement[@]}" | print_titled_card "$C_TITLE" GeoIP "$FULL_CARD_WIDTH" 0 "$summary"
}

print_cards() {
  local cards

  cards=$(
    print_attention
    print_platforms_and_ai
    print_availability
    print_geoip
  )
  if [[ -z "$cards" ]]; then
    return
  fi

  printf '%s\n\n' "$cards"
}

cdn_cell() {
  local status="$1"
  local country="$2"

  if [[ "$status" != "$STATUS_YES" ]]; then
    format_status "$status" "$LEFT_GRID_CELL"
    return
  fi

  paint "$C_VALUE" "$(pad "$(label_country "$country")" "$LEFT_GRID_CELL")"
}

cdn_node() {
  local status="$1"
  local iata="$3"
  local node="$4"

  if [[ "$status" != "$STATUS_YES" ]]; then
    paint "$C_DIM" "$SYMBOL_UNKNOWN"
    return
  fi

  paint "$C_VALUE" "${node:-$iata}"
}

append_cdn_row() {
  local -n cdn_rows=$1
  local name="$2"
  local -a v4_edge=("${@:3:4}") v6_edge=("${@:7:4}")
  local cells nodes

  cells="$(cdn_cell "${v4_edge[@]:0:2}")"
  nodes="$(cdn_node "${v4_edge[@]}")"
  if has_protocol_columns "$GROUP_CDN"; then
    cells+="$(cdn_cell "${v6_edge[@]:0:2}")"
    nodes+=" $(paint "$C_DIM" "·") $(cdn_node "${v6_edge[@]}")"
  fi

  cdn_rows+=("$(pad " $(pad_cell "" "$name" "$LEFT_GRID_NAME")$cells" "$RIGHT_COLUMN_START")$nodes")
}

print_cdn() {
  local -a fields rows=()
  local i

  mapfile -t fields < <(cdn_edge_rows)
  if ((${#fields[@]} == 0)); then
    return
  fi

  rows+=(" $(paint "$C_TITLE" "$(label_group CDN)")")
  append_card_titles rows "$GROUP_CDN" "$LEFT_GRID_NAME" "$LEFT_GRID_CELL"
  rows[-1]="$(pad "${rows[-1]}" "$RIGHT_COLUMN_START")$(paint "$C_DIM" Node)"
  for ((i = 0; i < ${#fields[@]}; i += CDN_ROW_FIELDS)); do
    append_cdn_row rows "${fields[@]:i:CDN_ROW_FIELDS}"
  done

  printf '%s\n' "${rows[@]}" | print_bar_block
}

print_legend() {
  local separator legend

  if jq -e --arg cdn "$GROUP_CDN" 'all(.group == $cdn)' <<<"$RESULTS" >/dev/null; then
    return
  fi

  separator=" $(paint "$C_DIM" "·") "
  legend="$(paint "$C_YES" "$SYMBOL_YES") $(paint "$C_DIM" available)$separator"
  legend+="$(paint "$C_NO" "$SYMBOL_NO") $(paint "$C_DIM" "region blocked")$separator"
  legend+="$(paint "$C_NO" "$SYMBOL_IPBLOCK") $(paint "$C_DIM" "IP blocked")$separator"
  legend+="$(paint "$C_DIM" "$SYMBOL_UNKNOWN unknown")"
  if has_protocol_columns "$GROUP_PLATFORMS"; then
    legend+="$separator$(paint "$C_DIM" "$SYMBOL_NONE no IPv6")"
  fi

  printf '%*s%s\n' "$LEGEND_INDENT" '' "$legend"
  if is_checked_once "$GROUP_PLATFORMS"; then
    printf '%*s%s\n' "$LEGEND_INDENT" '' "$(paint "$C_DIM" "$PROXY_CHECKED_ONCE_NOTE")"
  fi
  printf '\n'
}

fetch_verdict_country_names() {
  if [[ -z "$VERDICT" ]] && ((${#VERDICT_TIED_COUNTRIES[@]} == 0)); then
    return
  fi

  http_request "$(first_ip_version)" "$CLDR_TERRITORIES_URL"
}

print_report() {
  set_report_widths
  fetch_verdict_country_names
  print_header
  print_cards
  print_cdn
  print_legend
}

print_service_report() {
  set_report_widths
  build_header_columns
  print_host_lines | print_bar_block
  print_cards
  print_cdn
  print_legend
}

print_json_array() {
  jq -cn '$ARGS.positional' --args "$@"
}

print_address_json() {
  local ip_version="$1"
  local ip

  ip=$(external_ip "$ip_version")
  if [[ -z "$ip" ]]; then
    printf 'null'
    return
  fi

  jq -cn \
    --arg ip "$ip" \
    --arg asn "${REGISTRATION_ASN[$ip_version]:-}" \
    --arg org "${REGISTRATION_ORG[$ip_version]:-}" \
    --arg registered "${REGISTRATION_COUNTRY[$ip_version]:-}" \
    --arg maxmind_failure "${REGISTRATION_MAXMIND_FAILURE[$ip_version]:-}" \
    "$JSON_ADDRESS_FILTER"
}

print_json() {
  jq \
    --arg schema "$JSON_SCHEMA_URL" \
    --argjson version "$JSON_VERSION" \
    --argjson ipv4 "$(print_address_json 4)" \
    --argjson ipv6 "$(print_address_json 6)" \
    --arg verdict "$VERDICT" \
    --argjson tied "$(print_json_array "${VERDICT_TIED_COUNTRIES[@]}")" \
    --argjson attention "$ATTENTION" \
    --argjson groups "$(print_json_array "${SERVICE_GROUPS[@]}")" \
    --arg availability "$GROUP_AVAILABILITY" \
    --arg ai "$GROUP_AI" \
    --arg yes "$STATUS_YES" \
    --arg none "$STATUS_NONE" \
    --arg proxy "$PROXY_IP_VERSION" \
    "$JSON_REPORT_FILTER" <<<"$RESULTS"
}

print_output() {
  if [[ "$JSON_OUTPUT" == true ]]; then
    print_json
    return
  fi

  if is_service_report; then
    print_service_report
    return
  fi

  print_report
}

main() {
  use_utf8_locale
  parse_args "$@"
  validate_args
  ignore_ip_version_with_proxy
  detect_main_interface
  log_interface
  log_proxy
  limit_ip_versions_to_main_interface
  install_missing_dependencies
  resolve_selected_groups
  resolve_selected_checks
  create_work_dir
  start_debug_trace "$@"
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
  count_checks
  print_output
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
  main "$@"
fi
