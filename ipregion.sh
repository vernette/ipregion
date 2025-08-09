#!/usr/bin/env bash

SCRIPT_URL="https://github.com/vernette/ipregion"
DEPENDENCIES=("jq" "curl" "util-linux")
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
SPINNER_SERVICE_FILE=$(mktemp "${TMPDIR:-/tmp}/ipregion_spinner_XXXXXX")

VERBOSE=false
JSON_OUTPUT=false
GROUPS_TO_SHOW="all"
CURL_TIMEOUT=10
CURL_RETRIES=1
IPV4_ONLY=false
IPV6_ONLY=false
PROXY_ADDR=""
INTERFACE_NAME=""

RESULT_JSON=""
ARR_PRIMARY=()
ARR_CUSTOM=()
ARR_CDN=()

COLOR_HEADER="1;36"
COLOR_SERVICE="1;32"
COLOR_HEART="1;31"
COLOR_URL="1;90"
COLOR_ASN="1;33"
COLOR_TABLE_HEADER="1;97"
COLOR_TABLE_VALUE="1"
COLOR_NULL="0;90"
COLOR_ERROR="1;31"
COLOR_WARN="1;33"
COLOR_INFO="1;36"
COLOR_RESET="0"

LOG_INFO="INFO"
LOG_WARN="WARNING"
LOG_ERROR="ERROR"

declare -A DEPENDENCY_COMMANDS=(
  [jq]="jq"
  [curl]="curl"
  [util-linux]="column"
)

declare -A PRIMARY_SERVICES=(
  [MAXMIND]="maxmind.com|geoip.maxmind.com|/geoip/v2.1/city/me"
  [RIPE]="rdap.db.ripe.net|rdap.db.ripe.net|/ip/{ip}"
  [IPINFO_IO]="ipinfo.io|ipinfo.io|/widget/demo/{ip}"
  [IPREGISTRY]="ipregistry.co|api.ipregistry.co|/{ip}?hostname=true&key=sb69ksjcajfs4c"
  [IPAPI_CO]="ipapi.co|ipapi.co|/{ip}/json"
  [CLOUDFLARE]="cloudflare.com|www.cloudflare.com|/cdn-cgi/trace"
  [IFCONFIG_CO]="ifconfig.co|ifconfig.co|/country-iso?ip={ip}|plain"
  [IPLOCATION_COM]="iplocation.com|iplocation.com"
  [COUNTRY_IS]="country.is|api.country.is|/{ip}"
  [GEOAPIFY_COM]="geoapify.com|api.geoapify.com|/v1/ipinfo?&ip={ip}&apiKey=b8568cb9afc64fad861a69edbddb2658"
  [GEOJS_IO]="geojs.io|get.geojs.io|/v1/ip/country.json?ip={ip}"
  [IPAPI_IS]="ipapi.is|api.ipapi.is|/?q={ip}"
  [IPBASE_COM]="ipbase.com|api.ipbase.com|/v2/info?ip={ip}"
  [IPQUERY_IO]="ipquery.io|api.ipquery.io|/{ip}"
  [IP_SB]="ip.sb|api.ip.sb|/geoip/{ip}"
)

PRIMARY_SERVICES_ORDER=(
  "MAXMIND"
  "RIPE"
  "IPINFO_IO"
  "CLOUDFLARE"
  "IPREGISTRY"
  "IPAPI_CO"
  "IFCONFIG_CO"
  "IPLOCATION_COM"
  "COUNTRY_IS"
  "GEOAPIFY_COM"
  "GEOJS_IO"
  "IPAPI_IS"
  "IPBASE_COM"
  "IPQUERY_IO"
  "IP_SB"
)

declare -A PRIMARY_SERVICES_CUSTOM_HANDLERS=(
  [CLOUDFLARE]="lookup_cloudflare"
  [IPLOCATION_COM]="lookup_iplocation_com"
)

declare -A SERVICE_HEADERS=(
  [IPREGISTRY]="Origin: https://ipregistry.co"
  [MAXMIND]="Referer: https://www.maxmind.com"
  [IP_SB]="User-Agent: ${USER_AGENT}"
)

declare -A CUSTOM_SERVICES=(
  [GOOGLE]="Google"
  [TWITCH]="Twitch"
  [CHATGPT]="ChatGPT"
  [NETFLIX]="Netflix"
  [SPOTIFY]="Spotify"
  [REDDIT]="Reddit"
  [REDDIT_GUEST_ACCESS]="Reddit (Guest Access)"
  [YOUTUBE_PREMIUM]="YouTube Premium"
  [GOOGLE_SEARCH_CAPTCHA]="Google Search Captcha"
  [APPLE]="Apple"
  [STEAM]="Steam"
  [TIKTOK]="Tiktok"
  [CLOUDFLARE_CDN]="Cloudflare CDN"
  [YOUTUBE_CDN]="YouTube CDN"
  [OOKLA_SPEEDTEST]="Ookla Speedtest"
  [JETBRAINS]="JetBrains"
)

CUSTOM_SERVICES_ORDER=(
  "GOOGLE"
  "TWITCH"
  "CHATGPT"
  "NETFLIX"
  "SPOTIFY"
  "REDDIT"
  "REDDIT_GUEST_ACCESS"
  "YOUTUBE_PREMIUM"
  "GOOGLE_SEARCH_CAPTCHA"
  "APPLE"
  "STEAM"
  "TIKTOK"
  "OOKLA_SPEEDTEST"
  "JETBRAINS"
)

declare -A CUSTOM_SERVICES_HANDLERS=(
  [GOOGLE]="lookup_google"
  [TWITCH]="lookup_twitch"
  [CHATGPT]="lookup_chatgpt"
  [NETFLIX]="lookup_netflix"
  [SPOTIFY]="lookup_spotify"
  [REDDIT]="lookup_reddit"
  [REDDIT_GUEST_ACCESS]="lookup_reddit_guest_access"
  [YOUTUBE_PREMIUM]="lookup_youtube_premium"
  [GOOGLE_SEARCH_CAPTCHA]="lookup_google_search_captcha"
  [APPLE]="lookup_apple"
  [STEAM]="lookup_steam"
  [TIKTOK]="lookup_tiktok"
  [CLOUDFLARE_CDN]="lookup_cloudflare_cdn"
  [YOUTUBE_CDN]="lookup_youtube_cdn"
  [NETFLIX_CDN]="lookup_netflix_cdn"
  [OOKLA_SPEEDTEST]="lookup_ookla_speedtest"
  [JETBRAINS]="lookup_jetbrains"
)

declare -A CDN_SERVICES=(
  [CLOUDFLARE_CDN]="Cloudflare CDN"
  [YOUTUBE_CDN]="YouTube CDN"
  [NETFLIX_CDN]="Netflix CDN"
)

CDN_SERVICES_ORDER=(
  "CLOUDFLARE_CDN"
  "YOUTUBE_CDN"
  "NETFLIX_CDN"
)

declare -A SERVICE_GROUPS=(
  [primary]="${PRIMARY_SERVICES_ORDER[*]}"
  [custom]="${CUSTOM_SERVICES_ORDER[*]}"
  [cdn]="${CDN_SERVICES_ORDER[*]}"
)

EXCLUDED_SERVICES=(
  # "IPINFO_IO"
  # "IPREGISTRY"
  # "IPAPI_CO"
)

IDENTITY_SERVICES=(
  "ident.me"
  "ifconfig.me"
  "api64.ipify.org"
  "ifconfig.co"
  "ifconfig.me"
)

IPV6_OVER_IPV4_SERVICES=(
  "IPINFO_IO"
)

get_tmpdir() {
  if [[ -n "$TMPDIR" ]]; then
    echo "$TMPDIR"
  elif [[ -d /data/data/com.termux/files/usr/tmp ]]; then
    echo "/data/data/com.termux/files/usr/tmp"
  else
    echo "/tmp"
  fi
}

color() {
  local color_name="$1"
  local text="$2"
  local code

  case "$color_name" in
    HEADER) code="$COLOR_HEADER" ;;
    SERVICE) code="$COLOR_SERVICE" ;;
    HEART) code="$COLOR_HEART" ;;
    URL) code="$COLOR_URL" ;;
    ASN) code="$COLOR_ASN" ;;
    TABLE_HEADER) code="$COLOR_TABLE_HEADER" ;;
    TABLE_VALUE) code="$COLOR_TABLE_VALUE" ;;
    NULL) code="$COLOR_NULL" ;;
    ERROR) code="$COLOR_ERROR" ;;
    WARN) code="$COLOR_WARN" ;;
    INFO) code="$COLOR_INFO" ;;
    RESET) code="$COLOR_RESET" ;;
    *) code="$color_name" ;;
  esac

  printf "\033[%sm%s\033[0m" "$code" "$text"
}

bold() {
  local text="$1"
  printf "\033[1m%s\033[0m" "$text"
}

get_timestamp() {
  local format="$1"
  date +"$format"
}

log() {
  local log_level="$1"
  local message="${*:2}"
  local timestamp

  if [[ "$VERBOSE" == true ]]; then
    local color_code

    timestamp=$(get_timestamp "%d.%m.%Y %H:%M:%S")

    case "$log_level" in
      "$LOG_ERROR") color_code=ERROR ;;
      "$LOG_WARN") color_code=WARN ;;
      "$LOG_INFO") color_code=INFO ;;
      *) color_code=RESET ;;
    esac

    printf "[%s] [%s]: %s\n" "$timestamp" "$(color $color_code "$log_level")" "$message" >&2
  fi
}

error_exit() {
  local message="$1"
  local exit_code="${2:-1}"
  printf "%s %s\n" "$(color ERROR '[ERROR]')" "$(color TABLE_HEADER "$message")" >&2
  display_help
  exit "$exit_code"
}

display_help() {
  cat <<EOF

Usage: $0 [OPTIONS]

IPRegion — determines your IP geolocation using various GeoIP services and popular websites

Options:
  -h, --help           Show this help message and exit
  -v, --verbose        Enable verbose logging
  -j, --json           Output results in JSON format
  -g, --group GROUP    Run only one group: 'primary', 'custom', 'cdn', or 'all' (default: all)
  -t, --timeout SEC    Set curl request timeout in seconds (default: $CURL_TIMEOUT)
  -4, --ipv4           Test only IPv4
  -6, --ipv6           Test only IPv6
  -p, --proxy ADDR     Use SOCKS5 proxy (format: host:port)
  -i, --interface IF   Use specified network interface (e.g. eth1)

Examples:
  $0                       # Check all services with default settings
  $0 -g primary            # Check only GeoIP services
  $0 -g custom             # Check only popular websites
  $0 -g cdn                # Check only CDN endpoints
  $0 -4                    # Test only IPv4
  $0 -6                    # Test only IPv6
  $0 -p 127.0.0.1:1080     # Use SOCKS5 proxy
  $0 -i eth1               # Use network interface eth1
  $0 -j                    # Output result as JSON
  $0 -v                    # Enable verbose logging

EOF
}

is_installed() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

check_missing_dependencies() {
  local missing_pkgs=()
  local cmd

  for pkg in "${DEPENDENCIES[@]}"; do
    cmd="${DEPENDENCY_COMMANDS[$pkg]:-$pkg}"
    if ! is_installed "$cmd"; then
      missing_pkgs+=("$pkg")
    fi
  done

  echo "${missing_pkgs[@]}"
}

prompt_for_installation() {
  local missing_pkgs=("$@")

  echo "Missing dependencies: ${missing_pkgs[*]}"
  read -r -p "Do you want to install them? [y/N]: " answer
  answer=${answer,,}

  case "${answer,,}" in
    y | yes)
      return 0
      ;;
    *)
      exit 0
      ;;
  esac
}

get_package_manager() {
  # Check if the script is running in Termux
  if [[ -d /data/data/com.termux ]]; then
    echo "termux"
    return
  fi

  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
      debian | ubuntu)
        echo "apt"
        ;;
      arch)
        echo "pacman"
        ;;
      fedora)
        echo "dnf"
        ;;
      *)
        error_exit "Unknown distribution: $ID. Please install dependencies manually."
        ;;
    esac
  else
    error_exit "File /etc/os-release not found, unable to determine distribution. Please install dependencies manually."
  fi
}

install_with_package_manager() {
  local pkg_manager="$1"
  local packages=("${@:2}")
  local use_sudo=""

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    use_sudo="sudo"
    log "$LOG_INFO" "Running as non-root user, using sudo"
  fi

  case "$pkg_manager" in
    *apt)
      $use_sudo "$pkg_manager" update
      if [[ " ${packages[*]} " == *" util-linux "* ]]; then
        $use_sudo env NEEDRESTART_MODE=a "$pkg_manager" install -y util-linux bsdmainutils
      fi
      $use_sudo env NEEDRESTART_MODE=a "$pkg_manager" install -y "${packages[@]}"
      ;;
    *pacman)
      $use_sudo "$pkg_manager" -Syy --noconfirm "${packages[@]}"
      ;;
    *dnf)
      $use_sudo "$pkg_manager" install -y "${packages[@]}"
      ;;
    termux)
      apt update
      apt install -y "${packages[@]}"
      ;;
    *)
      error_exit "Unknown package manager: $pkg_manager"
      ;;
  esac
}

install_dependencies() {
  local missing_packages
  local pkg_manager

  log "$LOG_INFO" "Checking for dependencies"
  read -r -a missing_packages <<<"$(check_missing_dependencies)"

  if [[ ${#missing_packages[@]} -eq 0 ]]; then
    log "$LOG_INFO" "All dependencies are installed"
    return 0
  fi

  prompt_for_installation "${missing_packages[@]}" </dev/tty

  pkg_manager=$(get_package_manager)
  log "$LOG_INFO" "Detected package manager: $pkg_manager"

  log "$LOG_INFO" "Installing missing dependencies"
  install_with_package_manager "$pkg_manager" "${missing_packages[@]}"
}

is_valid_json() {
  local json="$1"
  jq -e . >/dev/null 2>&1 <<<"$json"
}

process_json() {
  local json="$1"
  local jq_filter="$2"
  jq -r "$jq_filter" <<<"$json"
}

format_value() {
  local value="$1"
  local not_available="$2"

  if [[ "$value" == "$not_available" ]]; then
    color NULL "$value"
  else
    bold "$value"
  fi
}

print_value_or_colored() {
  local value="$1"
  local color_name="$2"

  if [[ "$JSON_OUTPUT" == true ]]; then
    echo "$value"
    return
  fi

  color "$color_name" "$value"
}

mask_ipv4() {
  local ip="$1"
  echo "${ip%.*.*}.*.*"
}

mask_ipv6() {
  local ip="$1"
  echo "$ip" | awk -F: '{
    for(i=1;i<=NF;i++) if($i=="") $i="0";
    while(NF<8) for(i=1;i<=8;i++) if($i=="0"){NF++; break;}
    printf "%s:%s:%s::\n", $1, $2, $3
  }'
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help)
        display_help
        exit 0
        ;;
      -v | --verbose)
        VERBOSE=true
        shift
        ;;
      -j | --json)
        JSON_OUTPUT=true
        shift
        ;;
      -g | --group)
        GROUPS_TO_SHOW="$2"
        shift 2
        ;;
      -t | --timeout)
        if [[ "$2" =~ ^[0-9]+$ ]]; then
          CURL_TIMEOUT="$2"
        else
          error_exit "Invalid timeout value: $2. Timeout must be a positive integer"
        fi
        shift 2
        ;;
      -4 | --ipv4)
        IPV4_ONLY=true
        shift
        ;;
      -6 | --ipv6)
        if ! check_ip_support 6; then
          error_exit "IPv6 is not supported on this system"
        fi

        IPV6_ONLY=true
        shift
        ;;
      -p | --proxy)
        PROXY_ADDR="$2"
        log "$LOG_INFO" "Using SOCKS5 proxy: $PROXY_ADDR"
        shift 2
        ;;
      -i | --interface)
        INTERFACE_NAME="$2"
        log "$LOG_INFO" "Using interface: $INTERFACE_NAME"
        shift 2
        ;;
      *)
        error_exit "Unknown option: $1"
        ;;
    esac
  done
}

check_ip_support() {
  local version="$1"
  log "$LOG_INFO" "Checking for IPv${version} support"

  if [[ -n $(ip -"${version}" addr show scope global 2>/dev/null) ]]; then
    log "$LOG_INFO" "IPv${version} is supported"
    return 0
  fi

  log "$LOG_WARN" "IPv${version} is not supported on this system"
  return 1
}

get_external_ip() {
  local identity_service

  identity_service=${IDENTITY_SERVICES[$RANDOM % ${#IDENTITY_SERVICES[@]}]}
  log "$LOG_INFO" "Using identity service: $identity_service"

  if [[ "$IPV4_ONLY" == true ]] || [[ "$IPV6_ONLY" != true ]]; then
    log "$LOG_INFO" "Getting external IPv4 address"
    EXTERNAL_IPV4="$(make_request GET "https://$identity_service" --ip-version 4)"
    log "$LOG_INFO" "External IPv4: $EXTERNAL_IPV4"
  fi

  if [[ "$IPV6_ONLY" == true ]] || { [[ "$IPV6_SUPPORTED" -eq 0 ]] && [[ "$IPV4_ONLY" != true ]]; }; then
    log "$LOG_INFO" "Getting external IPv6 address"
    EXTERNAL_IPV6="$(make_request GET "https://$identity_service" --ip-version 6)"
    log "$LOG_INFO" "External IPv6: $EXTERNAL_IPV6"
  fi
}

get_asn() {
  local ip ip_version response

  if [[ -n "$EXTERNAL_IPV4" ]]; then
    ip="$EXTERNAL_IPV4"
    ip_version=4
  else
    ip="$EXTERNAL_IPV6"
    ip_version=6
  fi

  log "$LOG_INFO" "Getting ASN info for IP $ip"

  response=$(make_request GET "https://geoip.oxl.app/api/ip/$ip" --ip-version "$ip_version")
  asn=$(process_json "$response" ".asn")
  asn_name=$(process_json "$response" ".organization.name")

  log "$LOG_INFO" "ASN info: AS$asn $asn_name"
}

get_iata_location() {
  local iata_code="$1"
  local url="https://www.air-port-codes.com/api/v1/single"
  local payload="iata=$iata_code"
  local apc_auth="96dc04b3fb"
  local referer="https://www.air-port-codes.com/"
  local response

  response=$(make_request POST "$url" \
    --header "APC-Auth: $apc_auth" \
    --header "Referer: $referer" \
    --data "$payload" \
    --ip-version 4)

  process_json "$response" ".airport.country.iso"
}

is_ipv6_over_ipv4_service() {
  local service="$1"
  for s in "${IPV6_OVER_IPV4_SERVICES[@]}"; do
    [[ "$s" == "$service" ]] && return 0
  done
  return 1
}

spinner_start() {
  local delay=0.1
  # shellcheck disable=SC1003
  local spinstr='|/-\\'
  local current_service

  spinner_running=true

  (
    while $spinner_running; do
      for ((i = 0; i < ${#spinstr}; i++)); do
        current_service=""

        if [[ -f "$SPINNER_SERVICE_FILE" ]]; then
          current_service="$(cat "$SPINNER_SERVICE_FILE")"
        fi

        printf "\r\033[K%s %s %s" \
          "$(color HEADER "${spinstr:$i:1}")" \
          "$(color HEADER "Checking:")" \
          "$(color SERVICE "$current_service")"

        sleep $delay
      done
    done
  ) &

  spinner_pid=$!
}

spinner_stop() {
  spinner_running=false

  if [[ -n "$spinner_pid" ]]; then
    kill "$spinner_pid" 2>/dev/null
    wait "$spinner_pid" 2>/dev/null
    spinner_pid=""
    printf "\\r%*s\\r" 40 " "
  fi

  if [[ -f "$SPINNER_SERVICE_FILE" ]]; then
    rm -f "$SPINNER_SERVICE_FILE"
    unset SPINNER_SERVICE_FILE
  fi
}

make_request() {
  local method="$1"
  local url="$2"
  shift 2
  local ip_version user_agent json data headers response_with_code response http_code
  local curl_args=(
    --silent --compressed
    --retry-connrefused --retry-all-errors
    --retry "$CURL_RETRIES"
    --max-time "$CURL_TIMEOUT"
    --request "$method"
    -w '\n%{http_code}'
  )

  while (($#)); do
    case "$1" in
      --ip-version)
        ip_version="$2"
        shift 2
        ;;
      --user-agent)
        user_agent="$2"
        shift 2
        ;;
      --header)
        headers+=("$2")
        shift 2
        ;;
      --json)
        json="$2"
        shift 2
        ;;
      --data)
        data="$2"
        shift 2
        ;;
    esac
  done

  if [[ "$ip_version" == "4" ]]; then
    curl_args+=(-4)
  else
    curl_args+=(-6)
  fi

  headers+=("Accept-Encoding: gzip, deflate, br, zstd")
  for h in "${headers[@]}"; do
    curl_args+=(-H "$h")
  done

  if [[ -n "$user_agent" ]]; then
    curl_args+=(-A "$user_agent")
  fi

  if [[ -n "$json" ]]; then
    curl_args+=(--data "$json")
    curl_args+=(-H 'Content-Type: application/json')
  fi

  if [[ -n "$data" ]]; then
    curl_args+=(--data "$data")
    curl_args+=(-H 'Content-Type: application/x-www-form-urlencoded')
  fi

  if [[ -n "$PROXY_ADDR" ]]; then
    curl_args+=(--proxy "socks5://$PROXY_ADDR")
  fi

  if [[ -n "$INTERFACE_NAME" ]]; then
    curl_args+=(--interface "$INTERFACE_NAME")
  fi

  curl_args+=("$url")

  response_with_code=$(curl "${curl_args[@]}")
  http_code=$(tail -n1 <<<"$response_with_code")
  response=$(sed '$d' <<<"$response_with_code")

  if [[ "$http_code" == "403" || "$http_code" == "429" ]]; then
    echo ""
    return 0
  fi

  echo "$response"
}

service_build_request() {
  local service="$1" ip="$2" ip_version="$3"
  local cfg="${PRIMARY_SERVICES[$service]}"
  local display_name domain url_template url headers_str response_format

  IFS='|' read -r display_name domain url_template response_format <<<"$cfg"

  if [[ -z "$display_name" ]]; then
    display_name="$service"
  fi

  url="https://$domain${url_template//\{ip\}/$ip}"

  if [[ -n "${SERVICE_HEADERS[$service]}" ]]; then
    headers_str="${SERVICE_HEADERS[$service]}"
  fi

  printf "%s\n%s\n%s\n%s" "$display_name" "$url" "${response_format:-json}" "$headers_str"
}

probe_service() {
  local service="$1"
  local ip_version="$2"
  local ip="$3"
  local built display_name url response_format headers_line request_params response

  mapfile -t built < <(service_build_request "$service" "$ip" "$ip_version")
  display_name="${built[0]}"
  url="${built[1]}"
  response_format="${built[2]}"
  headers_line="${built[3]}"

  if [[ -n "$headers_line" ]]; then
    IFS='||' read -ra hs <<<"$headers_line"
    for h in "${hs[@]}"; do
      if [[ -n "$h" ]]; then
        request_params+=(--header "$h")
      fi
    done
  fi

  if [[ "$ip_version" == "6" ]] && is_ipv6_over_ipv4_service "$service"; then
    ip_version="4"
  fi

  response=$(make_request GET "$url" "${request_params[@]}" --ip-version "$ip_version")

  process_response "$service" "$response" "$display_name" "$response_format"
}

process_response() {
  local service="$1"
  local response="$2"
  local display_name="$3"
  local response_format="${4:-json}"
  local jq_filter

  if [[ -z "$response" || "$response" == *"<html"* ]]; then
    echo "N/A"
    return
  fi

  if [[ "$response_format" == "plain" ]]; then
    echo "$response" | tr -d '\r\n '
    return
  fi

  if ! is_valid_json "$response"; then
    log "$LOG_ERROR" "Invalid JSON response from $display_name: $response"
    return 1
  fi

  case "$service" in
    MAXMIND)
      jq_filter='.country.iso_code'
      ;;
    RIPE)
      jq_filter='.country'
      ;;
    IPINFO_IO)
      jq_filter='.data.country'
      ;;
    IPREGISTRY)
      jq_filter='.location.country.code'
      ;;
    IPAPI_CO)
      jq_filter='.country'
      ;;
    COUNTRY_IS)
      jq_filter='.country'
      ;;
    GEOAPIFY_COM)
      jq_filter='.country.iso_code'
      ;;
    GEOJS_IO)
      jq_filter='.[0].country'
      ;;
    IPAPI_IS)
      jq_filter='.location.country_code'
      ;;
    IPBASE_COM)
      jq_filter='.data.location.country.alpha2'
      ;;
    IPQUERY_IO)
      jq_filter='.location.country_code'
      ;;
    IP_SB)
      jq_filter='.country_code'
      ;;
    *)
      echo "$response"
      ;;
  esac

  process_json "$response" "$jq_filter"
}

process_service() {
  local service="$1"
  local custom="${2:-false}"
  local service_config="${PRIMARY_SERVICES[$service]}"
  local display_name domain url_template response_format ipv4_result ipv6_result handler_func

  IFS='|' read -r display_name domain url_template response_format <<<"$service_config"

  if [[ -z "$display_name" ]]; then
    display_name="$service"
  fi

  echo "$display_name" >"$SPINNER_SERVICE_FILE"

  if [[ "$custom" == true ]]; then
    process_custom_service "$service"
    return
  fi

  if [[ -n "${PRIMARY_SERVICES_CUSTOM_HANDLERS[$service]}" ]]; then
    handler_func="${PRIMARY_SERVICES_CUSTOM_HANDLERS[$service]}"

    log "$LOG_INFO" "Checking $display_name via IPv4 (custom handler)"

    ipv4_result=$("$handler_func" 4)

    if [[ "$IPV6_ONLY" == true ]] || { [[ "$IPV6_SUPPORTED" -eq 0 && -n "$EXTERNAL_IPV6" ]] && [[ "$IPV4_ONLY" != true ]]; }; then
      log "$LOG_INFO" "Checking $display_name via IPv6 (custom handler)"
      ipv6_result=$("$handler_func" 6)
    else
      ipv6_result=""
    fi

    add_result "primary" "$display_name" "$ipv4_result" "$ipv6_result"
    return
  fi

  if [[ "$IPV6_ONLY" != true ]]; then
    if [[ -n "$EXTERNAL_IPV4" ]]; then
      log "$LOG_INFO" "Checking $display_name via IPv4"
      ipv4_result=$(probe_service "$service" 4 "$EXTERNAL_IPV4")
    fi
  fi

  if [[ "$IPV4_ONLY" != true ]]; then
    if [[ "$IPV6_SUPPORTED" -eq 0 && -n "$EXTERNAL_IPV6" ]]; then
      if is_ipv6_over_ipv4_service "$service"; then
        log "$LOG_INFO" "Checking $display_name (IPv6 address, IPv4 transport)"
      else
        log "$LOG_INFO" "Checking $display_name via IPv6"
      fi
      ipv6_result=$(probe_service "$service" 6 "$EXTERNAL_IPV6")
    fi
  fi

  add_result "primary" "$display_name" "$ipv4_result" "$ipv6_result"
}

process_custom_service() {
  local service="$1"
  local ipv4_result ipv6_result
  local display_name="${CUSTOM_SERVICES[$service]:-$service}"
  local handler_func="${CUSTOM_SERVICES_HANDLERS[$service]}"

  if [[ -z "$display_name" ]]; then
    display_name="$service"
  fi

  echo "$display_name" >"$SPINNER_SERVICE_FILE"

  if [[ -z "$handler_func" ]]; then
    log "$LOG_WARN" "Unknown custom service: $service"
    return
  fi

  if [[ "$IPV6_ONLY" != true ]]; then
    log "$LOG_INFO" "Checking $display_name via IPv4"
    ipv4_result=$("$handler_func" 4)
  else
    ipv4_result=""
  fi

  if [[ "$IPV4_ONLY" != true ]] && [[ "$IPV6_SUPPORTED" -eq 0 && -n "$EXTERNAL_IPV6" ]]; then
    log "$LOG_INFO" "Checking $display_name via IPv6"
    ipv6_result=$("$handler_func" 6)
  else
    ipv6_result=""
  fi

  add_result "custom" "$display_name" "$ipv4_result" "$ipv6_result"
}

run_service_group() {
  local group="$1"
  local services_string="${SERVICE_GROUPS[$group]}"
  local is_custom=false
  local is_cdn=false
  local services_array service_name handler_func display_name result

  read -ra services_array <<<"$services_string"

  log "$LOG_INFO" "Running $group group services"

  for service_name in "${services_array[@]}"; do
    if printf "%s\n" "${EXCLUDED_SERVICES[@]}" | grep -Fxq "$service_name"; then
      log "$LOG_INFO" "Skipping service: $service_name"
      continue
    fi

    if [[ "$group" == "custom" ]]; then
      is_custom=true
    else
      is_custom=false
    fi

    if [[ "$group" == "cdn" ]]; then
      is_cdn=true
    else
      is_cdn=false
    fi

    if [[ "$is_custom" == true ]]; then
      process_service "$service_name" true
    elif [[ "$is_cdn" == true ]]; then
      handler_func="${CUSTOM_SERVICES_HANDLERS[$service_name]}"
      display_name="${CDN_SERVICES[$service_name]}"

      if [[ -n "$handler_func" ]]; then
        echo "$display_name" >"$SPINNER_SERVICE_FILE"
        result=$("$handler_func" 4)
        add_result "cdn" "$display_name" "$result" ""
      fi
    else
      process_service "$service_name"
    fi
  done
}

run_all_services() {
  local service_name

  for func in $(declare -F | awk '{print $3}' | grep '^lookup_'); do
    service_name=${func#lookup_}
    service_name_uppercase=${service_name^^}

    if printf "%s\n" "${EXCLUDED_SERVICES[@]}" | grep -Fxq "$service_name_uppercase"; then
      log "$LOG_INFO" "Skipping service: $service_name_uppercase"
      continue
    fi

    if [[ -n "${CUSTOM_SERVICES[$service_name_uppercase]}" ]]; then
      process_service "$service_name_uppercase" true
      continue
    fi

    "$func"
  done
}

finalize_json() {
  local t_primary t_custom t_cdn
  local IFS=$'\n'

  if ((${#ARR_PRIMARY[@]} > 0)); then
    t_primary=$(printf '%s\n' "${ARR_PRIMARY[@]//|||/$'\t'}")
  fi

  if ((${#ARR_CUSTOM[@]} > 0)); then
    t_custom=$(printf '%s\n' "${ARR_CUSTOM[@]//|||/$'\t'}")
  fi

  if ((${#ARR_CDN[@]} > 0)); then
    t_cdn=$(printf '%s\n' "${ARR_CDN[@]//|||/$'\t'}")
  fi

  RESULT_JSON=$(
    jq -n \
      --rawfile p <(printf "%s" "$t_primary") \
      --rawfile c <(printf "%s" "$t_custom") \
      --rawfile d <(printf "%s" "$t_cdn") \
      --arg ipv4 "$EXTERNAL_IPV4" \
      --arg ipv6 "$EXTERNAL_IPV6" \
      --arg version "1" '
        def lines_to_array($raw):
          if ($raw | length) == 0 then [] else
          ($raw | split("\n"))
          | map(select(length > 0))
          | map(
              (split("\t")) as $f
              | {
                  service: $f[0],
                  ipv4: ( ($f[1] // "") | if length>0 then . else null end ),
                  ipv6: ( ($f[2] // "") | if length>0 then . else null end )
                }
            )
          end;

        {
          version: ($version|tonumber),
          ipv4: ($ipv4 | select(length > 0) // null),
          ipv6: ($ipv6 | select(length > 0) // null),
          results: {
            primary: lines_to_array($p),
            custom:  lines_to_array($c),
            cdn:     lines_to_array($d)
          }
        }
      '
  )
}

add_result() {
  local group="$1"
  local service="$2"
  local ipv4="$3"
  local ipv6="$4"

  ipv4=${ipv4//$'\n'/}
  ipv4=${ipv4//$'\t'/ }
  ipv6=${ipv6//$'\n'/}
  ipv6=${ipv6//$'\t'/ }

  case "$group" in
    primary) ARR_PRIMARY+=("$service|||$ipv4|||$ipv6") ;;
    custom) ARR_CUSTOM+=("$service|||$ipv4|||$ipv6") ;;
    cdn) ARR_CDN+=("$service|||$ipv4|||$ipv6") ;;
  esac
}

print_table_group() {
  local group="$1"
  local group_title="$2"
  local na="N/A"
  local show_ipv4=0
  local show_ipv6=0
  local separator=$'\t'

  if [[ "$IPV6_ONLY" != true && -n "$EXTERNAL_IPV4" ]]; then
    show_ipv4=1
  fi

  if [[ "$IPV4_ONLY" != true && -n "$EXTERNAL_IPV6" ]]; then
    show_ipv6=1
  fi

  printf "%s\n\n" "$(color HEADER "$group_title")"

  {
    printf "%s" "$(color TABLE_HEADER 'Service')"

    if [[ $show_ipv4 -eq 1 ]]; then
      printf "%s%s" "$separator" "$(color TABLE_HEADER 'IPv4')"
    fi

    if [[ $show_ipv6 -eq 1 ]]; then
      printf "%s%s" "$separator" "$(color TABLE_HEADER 'IPv6')"
    fi

    printf "\n"

    jq -r --arg group "$group" '
      (.results // {}) as $r
      | ($r[$group] // [])
      | .[]
      | [ .service, (.ipv4 // "N/A"), (.ipv6 // "N/A") ]
      | @tsv
    ' <<<"$RESULT_JSON" | while IFS=$'\t' read -r s v4 v6; do

      printf "%s" "$(color SERVICE "$s")"

      if [[ $show_ipv4 -eq 1 ]]; then
        if [[ "$v4" == "null" || -z "$v4" ]]; then
          v4="$na"
        fi
        printf "%s%s" "$separator" "$(format_value "$v4" "$na")"
      fi

      if [[ $show_ipv6 -eq 1 ]]; then
        if [[ "$v6" == "null" || -z "$v6" ]]; then
          v6="$na"
        fi
        printf "%s%s" "$separator" "$(format_value "$v6" "$na")"
      fi

      printf "\n"
    done
  } | column -t -s "$separator"
}

print_header() {
  local ipv4 ipv6

  ipv4=$(process_json "$RESULT_JSON" ".ipv4")
  ipv6=$(process_json "$RESULT_JSON" ".ipv6")

  printf "%s\n%s\n\n" "$(color URL "Made with ")$(color HEART "<3")$(color URL " by vernette")" "$(color URL "$SCRIPT_URL")"

  if [[ -n "$EXTERNAL_IPV4" ]]; then
    printf "%s: %s\n" "$(color HEADER 'IPv4')" "$(bold "$(mask_ipv4 "$ipv4")")"
  fi

  if [[ -n "$EXTERNAL_IPV6" ]]; then
    printf "%s: %s\n" "$(color HEADER 'IPv6')" "$(bold "$(mask_ipv6 "$ipv6")")"
  fi

  printf "%s: %s\n\n" "$(color HEADER 'ASN')" "$(bold "AS$asn $asn_name")"
}

print_results() {
  finalize_json

  if [[ "$JSON_OUTPUT" == true ]]; then
    echo "$RESULT_JSON" | jq
    return
  fi

  print_header

  case "$GROUPS_TO_SHOW" in
    primary)
      print_table_group "primary" "GeoIP services"
      ;;
    custom)
      print_table_group "custom" "Popular services"
      ;;
    cdn)
      print_table_group "cdn" "CDN services"
      ;;
    *)
      print_table_group "custom" "Popular services"
      printf "\n"
      print_table_group "cdn" "CDN services"
      printf "\n"
      print_table_group "primary" "GeoIP services"
      ;;
  esac
}

lookup_maxmind() {
  process_service "MAXMIND"
}

lookup_ripe() {
  process_service "RIPE"
}

lookup_ipinfo_io() {
  process_service "IPINFO_IO"
}

lookup_ipregistry() {
  process_service "IPREGISTRY"
}

lookup_ipapi_co() {
  process_service "IPAPI_CO"
}

lookup_cloudflare() {
  local ip_version="$1"
  local response

  response=$(make_request GET "https://www.cloudflare.com/cdn-cgi/trace" --ip-version "$ip_version")
  while IFS='=' read -r key value; do
    if [[ "$key" == "loc" ]]; then
      echo "$value"
      break
    fi
  done <<<"$response"
}

lookup_ifconfig_co() {
  process_service "IFCONFIG_CO"
}

lookup_iplocation_com() {
  local ip_version="$1"
  local response ip

  if [[ -n "$EXTERNAL_IPV4" ]]; then
    ip="$EXTERNAL_IPV4"
  else
    ip="$EXTERNAL_IPV6"
  fi

  response=$(make_request POST "https://iplocation.com" --ip-version "$ip_version" --user-agent "$USER_AGENT" --data "ip=$ip")
  process_json "$response" ".country_code"
}

lookup_google() {
  local ip_version="$1"
  local sed_filter='s/.*"[a-z]\{2\}_\([A-Z]\{2\}\)".*/\1/p'
  local sed_fallback_filter='s/.*"[a-z]\{2\}-\([A-Z]\{2\}\)".*/\1/p'
  local response result

  response=$(make_request GET "https://www.google.com" \
    --user-agent "$USER_AGENT" \
    --ip-version "$ip_version")

  result=$(sed -n "$sed_filter" <<<"$response")

  if [[ -z "$result" ]]; then
    result=$(sed -n "$sed_fallback_filter" <<<"$response" | tail -n 1)
  fi

  echo "$result"
}

lookup_twitch() {
  local ip_version="$1"
  local response

  response=$(make_request POST "https://gql.twitch.tv/gql" \
    --header 'Client-Id: kimne78kx3ncx6brgo4mv6wki5h1ko' \
    --json '[{"operationName":"VerifyEmail_CurrentUser","variables":{},"extensions":{"persistedQuery":{"version":1,"sha256Hash":"f9e7dcdf7e99c314c82d8f7f725fab5f99d1df3d7359b53c9ae122deec590198"}}}]' \
    --ip-version "$ip_version")
  process_json "$response" ".[0].data.requestInfo.countryCode"
}

lookup_chatgpt() {
  local ip_version="$1"
  local response

  response=$(make_request POST "https://ab.chatgpt.com/v1/initialize" --ip-version "$ip_version" \
    --header "Statsig-Api-Key: client-zUdXdSTygXJdzoE0sWTkP8GKTVsUMF2IRM7ShVO2JAG")
  process_json "$response" ".derived_fields.country"
}

lookup_netflix() {
  local ip_version="$1"
  local response

  response=$(make_request GET "https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=1" --ip-version "$ip_version")

  if is_valid_json "$response"; then
    process_json "$response" ".client.location.country"
  else
    echo ""
  fi
}

lookup_spotify() {
  local ip_version="$1"
  local response

  response=$(make_request GET "https://accounts.spotify.com/en/login" --ip-version "$ip_version")

  sed -n 's/.*"geoLocationCountryCode":"\([^"]*\)".*/\1/p' <<<"$response"
}

lookup_reddit() {
  local ip_version="$1"
  local basic_access_token="Basic b2hYcG9xclpZdWIxa2c6"
  local user_agent="Reddit/Version 2025.29.0/Build 2529021/Android 13"
  local response access_token

  response=$(make_request POST "https://www.reddit.com/auth/v2/oauth/access-token/loid" \
    --ip-version "$ip_version" \
    --user-agent "$user_agent" \
    --header "Authorization: $basic_access_token" \
    --json '{"scopes":["email"]}')

  access_token=$(process_json "$response" ".access_token")

  response=$(make_request POST "https://gql-fed.reddit.com" \
    --ip-version "$ip_version" \
    --user-agent "$user_agent" \
    --header "Authorization: Bearer $access_token" \
    --json '{"operationName":"UserLocation","variables":{},"extensions":{"persistedQuery":{"version":1,"sha256Hash":"f07de258c54537e24d7856080f662c1b1268210251e5789c8c08f20d76cc8ab2"}}}')

  process_json "$response" ".data.userLocation.countryCode"
}

lookup_reddit_guest_access() {
  local ip_version="$1"
  local response is_available color_name

  response=$(make_request GET "https://www.reddit.com" --ip-version "$ip_version" --user-agent "$USER_AGENT")

  if [[ -n "$response" ]]; then
    is_available="Yes"
    color_name="SERVICE"
  else
    is_available="No"
    color_name="HEART"
  fi

  print_value_or_colored "$is_available" "$color_name"
}

lookup_youtube_premium() {
  local ip_version="$1"
  local response is_available

  response=$(make_request GET "https://www.youtube.com/premium" \
    --ip-version "$ip_version" \
    --user-agent "$USER_AGENT" \
    --header "Cookie: SOCS=CAISNQgDEitib3FfaWRlbnRpdHlmcm9udGVuZHVpc2VydmVyXzIwMjUwNzMwLjA1X3AwGgJlbiACGgYIgPC_xAY" \
    --header "Accept-Language: en-US,en;q=0.9")

  if [[ -z "$response" ]]; then
    echo ""
    return
  fi

  is_available=$(grep -io "youtube premium is not available in your country" <<<"$response")

  if [[ -z "$is_available" ]]; then
    is_available="Yes"
    color_name="SERVICE"
  else
    is_available="No"
    color_name="HEART"
  fi

  print_value_or_colored "$is_available" "$color_name"
}

lookup_google_search_captcha() {
  local ip_version="$1"
  local response is_captcha color_name

  response=$(make_request GET "https://www.google.com/search?q=cats" --ip-version "$ip_version" \
    --user-agent "$USER_AGENT" \
    --header "Accept-Language: en-US,en;q=0.9")

  if [[ -z "$response" ]]; then
    echo ""
    return
  fi

  is_captcha=$(grep -iE "unusual traffic from|is blocked|unaddressed abuse" <<<"$response")

  if [[ -z "$is_captcha" ]]; then
    is_captcha="No"
    color_name="SERVICE"
  else
    is_captcha="Yes"
    color_name="HEART"
  fi

  print_value_or_colored "$is_captcha" "$color_name"
}

lookup_apple() {
  local ip_version="$1"
  make_request GET "https://gspe1-ssl.ls.apple.com/pep/gcc" --ip-version "$ip_version"
}

lookup_steam() {
  local ip_version="$1"
  local response

  response=$(make_request GET "https://store.steampowered.com" --ip-version "$ip_version")
  sed -n 's/.*"countrycode":"\([^"]*\)".*/\1/p' <<<"$response"
}

lookup_tiktok() {
  local ip_version="$1"
  local response

  response=$(make_request GET "https://www.tiktok.com/api/v1/web-cookie-privacy/config?appId=1988" --ip-version "$ip_version")
  process_json "$response" ".body.appProps.region"
}

lookup_cloudflare_cdn() {
  local ip_version="$1"
  local response iata location

  response=$(make_request GET "https://www.cloudflare.com/cdn-cgi/trace" --ip-version "$ip_version")
  while IFS='=' read -r key value; do
    if [[ "$key" == "colo" ]]; then
      iata="$value"
      break
    fi
  done <<<"$response"

  location=$(get_iata_location "$iata")
  echo "$location ($iata)"
}

lookup_youtube_cdn() {
  local ip_version="$1"
  local response iata location

  response=$(make_request GET "https://redirector.googlevideo.com/report_mapping?di=no" --ip-version "$ip_version")
  iata=$(echo "$response" | awk '{print $3}' | cut -f2 -d'-' | cut -c1-3)
  iata=${iata^^}

  if [[ -z "$iata" ]]; then
    echo ""
    return
  fi

  location=$(get_iata_location "$iata")
  echo "$location ($iata)"
}

lookup_netflix_cdn() {
  local ip_version="$1"
  local response

  # TODO: Make contant
  response=$(make_request GET "https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm&urlCount=1" --ip-version "$ip_version")

  if is_valid_json "$response"; then
    process_json "$response" ".targets[0].location.country"
  else
    echo ""
  fi
}

lookup_ookla_speedtest() {
  local ip_version="$1"
  local response

  response=$(make_request GET "https://www.speedtest.net/api/js/config-sdk" --ip-version "$ip_version")
  process_json "$response" ".location.countryCode"
}

lookup_jetbrains() {
  local ip_version="$1"
  local response

  response=$(make_request GET "https://data.services.jetbrains.com/geo" --ip-version "$ip_version")
  process_json "$response" ".code"
}

main() {
  parse_arguments "$@"

  install_dependencies

  check_ip_support 4
  IPV4_SUPPORTED=$?

  check_ip_support 6
  IPV6_SUPPORTED=$?

  get_external_ip
  get_asn

  if [[ "$JSON_OUTPUT" != true && "$VERBOSE" != true ]]; then
    trap spinner_stop EXIT INT TERM
    spinner_start
  fi

  case "$GROUPS_TO_SHOW" in
    primary)
      run_service_group "primary"
      ;;
    custom)
      run_service_group "custom"
      ;;
    cdn)
      run_service_group "cdn"
      ;;
    *)
      run_service_group "primary"
      run_service_group "custom"
      run_service_group "cdn"
      ;;
  esac

  if [[ "$JSON_OUTPUT" != true && "$VERBOSE" != true ]]; then
    spinner_stop
    trap - EXIT INT TERM
  fi

  print_results
}

main "$@"
