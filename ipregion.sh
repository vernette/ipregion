#!/usr/bin/env bash

SCRIPT_URL="https://github.com/vernette/ipregion"
DEPENDENCIES=("jq" "curl" "util-linux")
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
SPINNER_SERVICE_FILE=$(mktemp "${TMPDIR:-/tmp}/ipregion_spinner_XXXXXX")
CURRENT_SERVICE=""

VERBOSE=false
JSON_OUTPUT=false
GROUPS_TO_SHOW="all"
CURL_TIMEOUT=10
CURL_RETRIES=1
IPV4_ONLY=false
IPV6_ONLY=false
PROXY_ADDR=""
INTERFACE_NAME=""

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
  [WHOER_NET]="whoer.net|whoer.net|/cdn-cgi/trace"
  [IPLOCATION_COM]="iplocation.com|iplocation.com"
  [COUNTRY_IS]="country.is|api.country.is|/{ip}"
  [GEOAPIFY_COM]="geoapify.com|api.geoapify.com|/v1/ipinfo?&ip={ip}&apiKey=b8568cb9afc64fad861a69edbddb2658"
  [GEOJS_IO]="geojs.io|get.geojs.io|/v1/ip/country.json?ip={ip}"
  [IPAPI_IS]="ipapi.is|api.ipapi.is|/?q={ip}"
  [IPBASE_COM]="ipbase.com|api.ipbase.com|/v2/info?ip={ip}"
  [IPQUERY_IO]="ipquery.io|api.ipquery.io|/{ip}"
  [IP_SB]="ip.sb|api.ip.sb|/geoip/{ip}"
  [IPDATA_CO]="ipdata.co|api.ipdata.co"
)

PRIMARY_SERVICES_ORDER=(
  "MAXMIND"
  "RIPE"
  "IPINFO_IO"
  "CLOUDFLARE"
  "IPREGISTRY"
  "IPAPI_CO"
  "IFCONFIG_CO"
  "WHOER_NET"
  "IPLOCATION_COM"
  "COUNTRY_IS"
  "GEOAPIFY_COM"
  "GEOJS_IO"
  "IPAPI_IS"
  "IPBASE_COM"
  "IPQUERY_IO"
  "IP_SB"
  "IPDATA_CO"
)

declare -A PRIMARY_SERVICES_CUSTOM_HANDLERS=(
  [CLOUDFLARE]="lookup_cloudflare"
  [WHOER_NET]="lookup_whoer_net"
  [IPLOCATION_COM]="lookup_iplocation_com"
  [IPDATA_CO]="lookup_ipdata_co"
)

declare -A SERVICE_HEADERS=(
  [IPREGISTRY]='("Origin: https://ipregistry.co")'
  [MAXMIND]='("Referer: https://www.maxmind.com")'
  [IP_SB]='("User-Agent: $USER_AGENT")'
)

declare -A CUSTOM_SERVICES=(
  [GOOGLE]="Google"
  [TWITCH]="Twitch"
  [CHATGPT]="ChatGPT"
  [NETFLIX]="Netflix"
  [SPOTIFY]="Spotify"
  [APPLE]="Apple"
  [STEAM]="Steam"
  [TIKTOK]="Tiktok"
  [CLOUDFLARE_CDN]="Cloudflare CDN"
  [YOUTUBE_CDN]="YouTube CDN"
  [OOKLA_SPEEDTEST]="Ookla Speedtest"
  [JETBRAINS]="JetBrains"
  [EPIC_GAMES]="Epic Games"
)

CUSTOM_SERVICES_ORDER=(
  "GOOGLE"
  "TWITCH"
  "CHATGPT"
  "NETFLIX"
  "SPOTIFY"
  "APPLE"
  "STEAM"
  "TIKTOK"
  "OOKLA_SPEEDTEST"
  "JETBRAINS"
  "EPIC_GAMES"
)

declare -A CUSTOM_SERVICES_HANDLERS=(
  [GOOGLE]="lookup_google"
  [TWITCH]="lookup_twitch"
  [CHATGPT]="lookup_chatgpt"
  [NETFLIX]="lookup_netflix"
  [SPOTIFY]="lookup_spotify"
  [APPLE]="lookup_apple"
  [STEAM]="lookup_steam"
  [TIKTOK]="lookup_tiktok"
  [CLOUDFLARE_CDN]="lookup_cloudflare_cdn"
  [YOUTUBE_CDN]="lookup_youtube_cdn"
  [OOKLA_SPEEDTEST]="lookup_ookla_speedtest"
  [JETBRAINS]="lookup_jetbrains"
  [EPIC_GAMES]="lookup_epic_games"
)

declare -A CDN_SERVICES=(
  [CLOUDFLARE_CDN]="Cloudflare CDN"
  [YOUTUBE_CDN]="YouTube CDN"
)

CDN_SERVICES_ORDER=(
  "CLOUDFLARE_CDN"
  "YOUTUBE_CDN"
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

  if [[ -n $(ip -${version} addr show scope global 2>/dev/null) ]]; then
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

  if [[ "$IPV6_ONLY" == true ]] || ([[ "$IPV6_SUPPORTED" -eq 0 ]] && [[ "$IPV4_ONLY" != true ]]); then
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
  local response city country

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

  CURRENT_SERVICE=""

  if [[ -f "$SPINNER_SERVICE_FILE" ]]; then
    rm -f "$SPINNER_SERVICE_FILE"
    unset SPINNER_SERVICE_FILE
  fi
}

make_request() {
  local curl_command
  local method="$1"
  local url="$2"
  shift 2
  local ip_version=""
  local user_agent=""
  local headers=()
  local json=""
  local data=""
  local proxy=""
  local response

  while (("$#")); do
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
      --proxy)
        proxy="$2"
        shift 2
        ;;
    esac
  done

  curl_command="curl --silent --retry-connrefused --retry-all-errors --retry $CURL_RETRIES --max-time $CURL_TIMEOUT --request $method"

  if [[ "$ip_version" == "4" ]]; then
    curl_command+=" -4"
  else
    curl_command+=" -6"
  fi

  if [[ -n "$user_agent" ]]; then
    curl_command+=" -A '$user_agent'"
  fi

  for header in "${headers[@]}"; do
    curl_command+=" -H '$header'"
  done

  if [[ -n "$json" ]]; then
    curl_command+=" --data '$json'"
    if ! [[ "${headers[*]}" =~ "Content-Type" ]]; then
      curl_command+=" -H 'Content-Type: application/json'"
    fi
  fi

  if [[ -n "$data" ]]; then
    curl_command+=" --data '$data'"
    if ! [[ "${headers[*]}" =~ "Content-Type" ]]; then
      curl_command+=" -H 'Content-Type: application/x-www-form-urlencoded'"
    fi
  fi

  if [[ -n "$PROXY_ADDR" ]]; then
    curl_command+=" --proxy socks5://$PROXY_ADDR"
  fi

  if [[ -n "$INTERFACE_NAME" ]]; then
    curl_command+=" --interface $INTERFACE_NAME"
  fi

  curl_command+=" '$url'"

  response=$(eval "$curl_command")
  echo "$response"
}

process_response() {
  local service="$1"
  local response="$2"
  local display_name="$3"
  local response_format="${4:-json}"
  local jq_filter

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

    if [[ "$IPV6_ONLY" == true ]] || ([[ "$IPV6_SUPPORTED" -eq 0 && -n "$EXTERNAL_IPV6" ]] && [[ "$IPV4_ONLY" != true ]]); then
      log "$LOG_INFO" "Checking $display_name via IPv6 (custom handler)"
      ipv6_result=$("$handler_func" 6)
    else
      ipv6_result=""
    fi

    add_result "primary" "$display_name" "$ipv4_result" "$ipv6_result"
    return
  fi

  local request_params=()

  # TODO: Refactor this
  if [[ -n "${SERVICE_HEADERS[$service]}" ]]; then
    eval "local headers=${SERVICE_HEADERS[$service]}"
    for header in "${headers[@]}"; do
      request_params+=(--header "$header")
    done
  fi

  # TODO: Make function to get url
  local url_v4="https://$domain${url_template/\{ip\}/$EXTERNAL_IPV4}"

  # TODO: Make single check for both IPv4 and IPv6
  if [[ "$IPV6_ONLY" != true ]]; then
    log "$LOG_INFO" "Checking $display_name via IPv4"
    ipv4_result=$(make_request GET "$url_v4" "${request_params[@]}" --ip-version 4)
    ipv4_result=$(process_response "$service" "$ipv4_result" "$display_name" "$response_format")
  else
    ipv4_result=""
  fi

  if [[ "$IPV4_ONLY" != true ]]; then
    if is_ipv6_over_ipv4_service "$service" && [[ "$IPV6_SUPPORTED" -eq 0 && -n "$EXTERNAL_IPV6" ]]; then
      local url_v6="https://$domain${url_template/\{ip\}/$EXTERNAL_IPV6}"
      log "$LOG_INFO" "Checking $display_name (IPv6 address, IPv4 transport)"
      ipv6_result=$(make_request GET "$url_v6" "${request_params[@]}" --ip-version 4)
      ipv6_result=$(process_response "$service" "$ipv6_result" "$display_name" "$response_format")
    else
      if [[ "$IPV6_SUPPORTED" -eq 0 && -n "$EXTERNAL_IPV6" ]]; then
        local url_v6="https://$domain${url_template/\{ip\}/$EXTERNAL_IPV6}"
        log "$LOG_INFO" "Checking $display_name via IPv6"
        ipv6_result=$(make_request GET "$url_v6" "${request_params[@]}" --ip-version 6)
        ipv6_result=$(process_response "$service" "$ipv6_result" "$display_name" "$response_format")
      else
        ipv6_result=""
      fi
    fi
  else
    ipv6_result=""
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

init_json_output() {
  RESULT_JSON=$(jq -n \
    --arg version "1" \
    --arg ipv4 "$EXTERNAL_IPV4" \
    --arg ipv6 "$EXTERNAL_IPV6" \
    '{version: ($version|tonumber), ipv4: ($ipv4 | select(length > 0) // null), ipv6: ($ipv6 | select(length > 0) // null), results: {primary: [], custom: [], cdn: []}}')
}

add_result() {
  local group="$1"
  local service="$2"
  local ipv4="$3"
  local ipv6="$4"

  RESULT_JSON=$(jq \
    --arg group "$group" \
    --arg service "$service" \
    --arg ipv4 "$ipv4" \
    --arg ipv6 "$ipv6" \
    '.results[$group] += [{
      service: $service,
      ipv4: ($ipv4 | select(length > 0) // null),
      ipv6: ($ipv6 | select(length > 0) // null)
    }]' \
    <<<"$RESULT_JSON")
}

print_table_group() {
  local group="$1"
  local group_title="$2"
  local separator="|||"
  local not_available="N/A"
  local show_ipv4=0
  local show_ipv6=0
  local header row ipv4_res ipv6_res

  if [[ "$IPV6_ONLY" != true ]]; then
    [[ -n "$EXTERNAL_IPV4" ]] && show_ipv4=1
  fi

  if [[ "$IPV4_ONLY" != true ]]; then
    [[ -n "$EXTERNAL_IPV6" ]] && show_ipv6=1
  fi

  printf "%s\n\n" "$(color HEADER "$group_title")"

  {
    header=("$(color TABLE_HEADER 'Service')")
    [[ $show_ipv4 -eq 1 ]] && header+=("$(color TABLE_HEADER 'IPv4')")
    [[ $show_ipv6 -eq 1 ]] && header+=("$(color TABLE_HEADER 'IPv6')")
    printf "%s\n" "$(
      IFS="$separator"
      echo "${header[*]}"
    )"

    jq -c ".results.$group[]" <<<"$RESULT_JSON" | while read -r item; do
      row=()
      service=$(process_json "$item" ".service")
      row+=("$(color SERVICE "$service")")

      if [[ $show_ipv4 -eq 1 ]]; then
        ipv4_res=$(process_json "$item" ".ipv4 // \"$not_available\"")
        [[ "$ipv4_res" == "null" ]] && ipv4_res="$not_available"
        row+=("$(format_value "$ipv4_res" "$not_available")")
      fi

      if [[ $show_ipv6 -eq 1 ]]; then
        ipv6_res=$(process_json "$item" ".ipv6 // \"$not_available\"")
        [[ "$ipv6_res" == "null" ]] && ipv6_res="$not_available"
        row+=("$(format_value "$ipv6_res" "$not_available")")
      fi

      printf "%s\n" "$(
        IFS="$separator"
        echo "${row[*]}"
      )"
    done
  } | column -t -s "$separator"
}

print_table() {
  print_table_group "custom" "Popular services"
  printf "\n"
  print_table_group "primary" "GeoIP services"
}

print_header() {
  local ipv4 ipv6

  ipv4=$(process_json "$RESULT_JSON" ".ipv4")
  ipv6=$(process_json "$RESULT_JSON" ".ipv6")

  printf "%s\n\n" "$(color URL "Made with ")$(color HEART '<3')$(color URL " by vernette — $SCRIPT_URL")"

  if [[ -n "$EXTERNAL_IPV4" ]]; then
    printf "%s: %s\n" "$(color HEADER 'IPv4')" "$(bold "$(mask_ipv4 "$ipv4")")"
  fi

  if [[ -n "$EXTERNAL_IPV6" ]]; then
    printf "%s: %s\n" "$(color HEADER 'IPv6')" "$(bold "$(mask_ipv6 "$ipv6")")"
  fi

  printf "%s: %s\n\n" "$(color HEADER 'ASN')" "$(bold "AS$asn $asn_name")"
}

print_results() {
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

lookup_whoer_net() {
  local ip_version="$1"
  local response

  response=$(make_request GET "https://whoer.net/cdn-cgi/trace" --ip-version "$ip_version")
  while IFS='=' read -r key value; do
    if [[ "$key" == "loc" ]]; then
      echo "$value"
      break
    fi
  done <<<"$response"
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

  response=$(make_request GET "https://chatgpt.com/cdn-cgi/trace" --ip-version "$ip_version")
  while IFS='=' read -r key value; do
    if [[ "$key" == "loc" ]]; then
      echo "$value"
      break
    fi
  done <<<"$response"
}

lookup_netflix() {
  local ip_version="$1"
  local response

  response=$(make_request GET "https://api.fast.com/netflix/speedtest/v2?token=YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm" --ip-version "$ip_version")

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

lookup_ipdata_co() {
  local ip_version="$1"
  local html api_key response

  html=$(make_request GET "https://ipdata.co" --ip-version "$ip_version")
  api_key=$(sed -n 's/.*api-key=\([a-zA-Z0-9]\+\).*/\1/p' <<<"$html")

  if [[ -z "$api_key" ]]; then
    echo ""
    return
  fi

  response=$(make_request GET "https://api.ipdata.co/?api-key=$api_key" \
    --ip-version "$ip_version" \
    --header "Referer: https://ipdata.co")

  process_json "$response" ".country_code"
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
  iata=$(echo "$response" | awk '{print $3}' | cut -f2 -d'-' | cut -c1-3 | tr a-z A-Z)

  if [[ -z "$iata" ]]; then
    echo ""
    return
  fi

  location=$(get_iata_location "$iata")
  echo "$location ($iata)"
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

lookup_epic_games() {
  local ip_version="$1"
  local response

  response=$(make_request GET "https://www.epicgames.com/cdn-cgi/trace" --ip-version "$ip_version")
  log "$LOG_INFO" "$response"
  while IFS='=' read -r key value; do
    if [[ "$key" == "loc" ]]; then
      echo "$value"
      break
    fi
  done <<<"$response"
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

  init_json_output

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
