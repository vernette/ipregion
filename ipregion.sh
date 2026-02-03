#!/usr/bin/env bash

SCRIPT_NAME="ipregion.sh"
SCRIPT_URL="https://github.com/vladon/ipregion"
SCRIPT_VERSION=$(stat -c "%y" "$0" 2>/dev/null | cut -d'.' -f1 || stat -f "%Sm" "$0" 2>/dev/null || echo "unknown")
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"
SPINNER_SERVICE_FILE=$(mktemp "${TMPDIR:-/tmp}/ipregion_spinner_XXXXXX")
DEBUG_LOG_FILE=""

VERBOSE=false
JSON_OUTPUT=false
GROUPS_TO_SHOW="all"
CURL_TIMEOUT=5
CURL_RETRIES=1
IPV4_ONLY=false
IPV6_ONLY=false
PROXY_ADDR=""
INTERFACE_NAME=""
DEBUG=false
IPV4_SUPPORTED=0
IPV6_SUPPORTED=0
PARALLEL_JOBS=0
PARALLEL_PIDS=()
FORCE_SPINNER=false
PROGRESS_LOG=false
LAST_PROGRESS_MSG=""
HEADER_PRINTED=false

RESULT_JSON=""
ARR_PRIMARY=()
ARR_CUSTOM=()

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

STATUS_NA="N/A"
STATUS_DENIED="Denied"
STATUS_RATE_LIMIT="Rate-limit"
STATUS_SERVER_ERROR="Server error"

declare -A DEPENDENCIES=(
  [jq]="jq"
  [curl]="curl"
  [column]="util-linux"
  [nslookup]="bind-utils"
)

declare -A PACKAGE_MAPPING=(
  ["apt:nslookup"]="dnsutils"
  ["apt:column"]="bsdmainutils"
  ["pacman:nslookup"]="bind"
  ["dnf:nslookup"]="bind-utils"
  ["yum:nslookup"]="bind-utils"
  ["termux:column"]="util-linux"
)

declare -A PRIMARY_SERVICES=(
  [MAXMIND]="maxmind.com|geoip.maxmind.com|/geoip/v2.1/city/me"
  [RIPE]="rdap.db.ripe.net|rdap.db.ripe.net|/ip/{ip}"
  [IPINFO_IO]="ipinfo.io|ipinfo.io|/widget/demo/{ip}"
  [IPAPI_CO]="ipapi.co|ipapi.co|/{ip}/json"
  [CLOUDFLARE]="cloudflare.com|speed.cloudflare.com|/meta"
  [IFCONFIG_CO]="ifconfig.co|ifconfig.co|/country-iso?ip={ip}|plain"
  [IP2LOCATION_IO]="ip2location.io|api.ip2location.io|/?ip={ip}"
  [IPLOCATION_COM]="iplocation.com|iplocation.com"
  [COUNTRY_IS]="country.is|api.country.is|/{ip}"
  [GEOJS_IO]="geojs.io|get.geojs.io|/v1/ip/country.json?ip={ip}"
  [IPAPI_IS]="ipapi.is|api.ipapi.is|/?q={ip}"
  [IPBASE_COM]="ipbase.com|api.ipbase.com|/v2/info?ip={ip}"
  [IPQUERY_IO]="ipquery.io|api.ipquery.io|/{ip}"
  [IPWHOIS_IO]="ipwhois.io|ipwho.is|/{ip}"
  [IPWHO_IS]="ipwho.is|ipwho.is|/{ip}"
  [IPAPI_COM]="ip-api.com|ip-api.com|/json/{ip}?fields=countryCode"
  [DETECTOR404]="Detector404|geoip.detector404.ru|/api/v1/ip/{ip}"
)

PRIMARY_SERVICES_ORDER=(
  "MAXMIND"
  "RIPE"
  "IPINFO_IO"
  "CLOUDFLARE"
  "IPAPI_CO"
  "IFCONFIG_CO"
  "IP2LOCATION_IO"
  "IPLOCATION_COM"
  "COUNTRY_IS"
  "GEOJS_IO"
  "IPAPI_IS"
  "IPBASE_COM"
  "IPQUERY_IO"
  "IPWHOIS_IO"
  "IPWHO_IS"
  "IPAPI_COM"
  "DETECTOR404"
)

declare -A PRIMARY_SERVICES_CUSTOM_HANDLERS=(
  [IPLOCATION_COM]="lookup_iplocation_com"
)

declare -A SERVICE_HEADERS=(
  [MAXMIND]="Referer: https://www.maxmind.com"
  [IPAPI_COM]="Origin: https://ip-api.com"
  [CLOUDFLARE]="Referer: https://speed.cloudflare.com"
)

declare -A CUSTOM_SERVICES=(
  [GOOGLE]="Google"
  [YOUTUBE]="YouTube"
  [YOUTUBE_PREMIUM]="YouTube Premium"
  [GOOGLE_SEARCH_CAPTCHA]="Google Search Captcha"
  [APPLE]="Apple"
  [STEAM]="Steam"
  [TIKTOK]="Tiktok"
  [OOKLA_SPEEDTEST]="Ookla Speedtest"
  [JETBRAINS]="JetBrains"
  [PLAYSTATION]="PlayStation"
  [MICROSOFT]="Microsoft"
)

CUSTOM_SERVICES_ORDER=(
  "GOOGLE"
  "YOUTUBE"
  "YOUTUBE_PREMIUM"
  "GOOGLE_SEARCH_CAPTCHA"
  "APPLE"
  "STEAM"
  "TIKTOK"
  "OOKLA_SPEEDTEST"
  "JETBRAINS"
  "PLAYSTATION"
  "MICROSOFT"
)

declare -A CUSTOM_SERVICES_HANDLERS=(
  [GOOGLE]="lookup_google"
  [YOUTUBE]="lookup_youtube"
  [YOUTUBE_PREMIUM]="lookup_youtube_premium"
  [GOOGLE_SEARCH_CAPTCHA]="lookup_google_search_captcha"
  [APPLE]="lookup_apple"
  [STEAM]="lookup_steam"
  [TIKTOK]="lookup_tiktok"
  [OOKLA_SPEEDTEST]="lookup_ookla_speedtest"
  [JETBRAINS]="lookup_jetbrains"
  [PLAYSTATION]="lookup_playstation"
  [MICROSOFT]="lookup_microsoft"
)

declare -A SERVICE_GROUPS=(
  [primary]="${PRIMARY_SERVICES_ORDER[*]}"
  [custom]="${CUSTOM_SERVICES_ORDER[*]}"
)

EXCLUDED_SERVICES=(
  # "IPINFO_IO"
  # "IPAPI_CO"
  "GOOGLE_SEARCH_CAPTCHA"
)

IDENTITY_SERVICES=(
  "ident.me"
  "ifconfig.me"
  "api64.ipify.org"
  "ifconfig.co"
)

IPV6_OVER_IPV4_SERVICES=(
  "IPINFO_IO"
  "IPAPI_IS"
  "IPLOCATION_COM"
  "IPWHO_IS"
  "IPAPI_COM"
)

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

Usage: $SCRIPT_NAME [OPTIONS]

IPRegion — determines your IP geolocation using various GeoIP services and popular websites

Options:
  -h, --help           Show this help message and exit
  -v, --verbose        Enable verbose logging
  -d, --debug          Enable debug trace; log may contain sensitive data (uploads use redacted copy)
  -j, --json           Output results in JSON format
  -g, --group GROUP    Run only one group: 'primary', 'custom', or 'all' (default: all)
  -t, --timeout SEC    Set curl request timeout in seconds (default: $CURL_TIMEOUT)
  -P, --parallel N     Run up to N services in parallel (default: auto)
  -S, --force-spinner  Always show spinner (even in parallel mode)
  --force-spinner      Always show spinner (even in parallel mode)
  --progress-log       Print progress lines instead of spinner
  -4, --ipv4           Test only IPv4
  -6, --ipv6           Test only IPv6
  -p, --proxy ADDR     Use SOCKS5 proxy (format: host:port)
  -i, --interface IF   Use specified network interface (e.g. eth1)

Examples:
  $SCRIPT_NAME                       # Check all services with default settings
  $SCRIPT_NAME -g primary            # Check only GeoIP services
  $SCRIPT_NAME -g custom             # Check only popular websites
  $SCRIPT_NAME -4                    # Test only IPv4
  $SCRIPT_NAME -6                    # Test only IPv6
  $SCRIPT_NAME -p 127.0.0.1:1080     # Use SOCKS5 proxy
  $SCRIPT_NAME -i eth1               # Use network interface eth1
  $SCRIPT_NAME -j                    # Output result as JSON
  $SCRIPT_NAME -v                    # Enable verbose logging
  $SCRIPT_NAME -d                    # Enable debug and save full trace to file (upload on consent)
  $SCRIPT_NAME -P 6                  # Check services using 6 parallel jobs
  $SCRIPT_NAME --force-spinner       # Force spinner even with parallel checks
  $SCRIPT_NAME --progress-log        # Print progress lines instead of spinner

EOF
}

print_startup_message() {
  local parallel_display="$PARALLEL_JOBS"
  local ipv4="auto" ipv6="auto"
  local proxy="${PROXY_ADDR:-none}"
  local iface="${INTERFACE_NAME:-auto}"

  if (( PARALLEL_JOBS <= 0 )); then
    parallel_display="unknown"
  fi

  if [[ "$IPV4_ONLY" == true ]]; then
    ipv4="only"
    ipv6="off"
  elif [[ "$IPV6_ONLY" == true ]]; then
    ipv4="off"
    ipv6="only"
  fi

  if [[ "$JSON_OUTPUT" == true ]]; then
    return
  fi

  printf "%s %s: %s\n" \
    "$(color INFO '[INFO]')" \
    "$(color HEADER 'Version')" \
    "$SCRIPT_VERSION" >&2

  printf "%s %s\n" \
    "$(color INFO '[INFO]')" \
    "Starting with group=$GROUPS_TO_SHOW timeout=${CURL_TIMEOUT}s parallel=$parallel_display ipv4=$ipv4 ipv6=$ipv6 proxy=$proxy interface=$iface verbose=$VERBOSE debug=$DEBUG" >&2
}

setup_debug() {
  if [[ "$DEBUG" != true ]]; then
    return 1
  fi

  umask 077
  DEBUG_LOG_FILE=$(mktemp "${TMPDIR:-/tmp}/ipregion_debug_XXXXXX.log")

  exec 3>&1 4>&2

  exec 1> >(tee -a "$DEBUG_LOG_FILE" >&3)
  exec 2> >(tee -a "$DEBUG_LOG_FILE" >&4)

  set -x
  return 0
}

grep_wrapper() {
  local grep_args=()

  if [[ "$1" == "--perl" ]]; then
    grep_args+=("-oP")
    shift
  fi

  grep "${grep_args[@]}" "$@"
}

normalize_ascii() {
  local value="$1"

  if command -v iconv >/dev/null 2>&1; then
    printf "%s" "$value" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null
    return
  fi

  printf "%s" "$value"
}

html_decode() {
  local value="$1"

  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import html,sys; sys.stdout.write(html.unescape(sys.stdin.read()))' <<<"$value"
    return
  fi

  if command -v perl >/dev/null 2>&1; then
    perl -MHTML::Entities -pe 'decode_entities($_)' <<<"$value"
    return
  fi

  if command -v php >/dev/null 2>&1; then
    php -r 'echo html_entity_decode(stream_get_contents(STDIN), ENT_QUOTES | ENT_HTML5);' <<<"$value"
    return
  fi

  if command -v sed >/dev/null 2>&1; then
    printf "%s" "$value" | sed -E \
      -e 's/&amp;/\&/g' \
      -e 's/&lt;/</g' \
      -e 's/&gt;/>/g' \
      -e 's/&quot;/"/g' \
      -e "s/&#39;/'/g"
    return
  fi

  printf "%s" "$value"
}

redact_debug_log() {
  local source_file="$1"
  local redacted_file
  redacted_file=$(mktemp "${TMPDIR:-/tmp}/ipregion_debug_redacted_XXXXXX.log")

  sed -E \
    -e 's/([A-Fa-f0-9]{0,4}:){2,}[A-Fa-f0-9]{0,4}/[REDACTED_IPV6]/g' \
    -e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/[REDACTED_IPV4]/g' \
    -e 's/(Authorization:)[^[:cntrl:]]*/\1 [REDACTED]/I' \
    -e 's/(Proxy-Authorization:)[^[:cntrl:]]*/\1 [REDACTED]/I' \
    -e 's/(X-Api-Key:)[^[:cntrl:]]*/\1 [REDACTED]/I' \
    -e 's/(X-Auth-Token:)[^[:cntrl:]]*/\1 [REDACTED]/I' \
    -e 's/(Cookie:)[^[:cntrl:]]*/\1 [REDACTED]/I' \
    -e 's/(Set-Cookie:)[^[:cntrl:]]*/\1 [REDACTED]/I' \
    -e 's/([?&](token|access_token|refresh_token|api_key|apikey|password)=)[^&#[:space:]]+/\1[REDACTED]/Ig' \
    "$source_file" >"$redacted_file"

  printf "%s" "$redacted_file"
}

upload_debug() {
  local ip_version
  local user_agent="ipregion-script/1.0 (github.com/vernette/ipregion)"
  local upload_file

  ip_version=$(preferred_ip_version)
  upload_file=$(redact_debug_log "$DEBUG_LOG_FILE")

  curl_wrapper POST "https://0x0.st" \
    --user-agent "$user_agent" \
    --form "file=@$upload_file" \
    --form "secret=" \
    --form "expires=24" \
    --ip-version "$ip_version"

  rm -f "$upload_file"
}

cleanup_debug() {
  local debug_url

  if [[ ! -f "$DEBUG_LOG_FILE" ]]; then
    return 1
  fi

  set +x
  exec 1>&3 2>&4 3>&- 4>&-

  printf "\n%s\n  %s\n" \
    "$(color WARN 'Debug information:')" \
    "Local file: $DEBUG_LOG_FILE"
  printf "%s\n" \
    "$(color WARN 'Privacy notice: the debug log may contain sensitive data. Upload uses a redacted copy, but review it before sharing.')"

  if [[ -t 0 ]] && prompt_for_debug_upload </dev/tty; then
    debug_url="$(upload_debug)"
    printf "  %s\n\n%s\n%s\n\n%s\n" \
      "Remote URL: $debug_url" \
      "$(color INFO 'PRIVACY NOTICE: This file is uploaded to 0x0.st - a public file hoster.')" \
      "$(color INFO 'The file will be automatically deleted in 24 hours.')" \
      "$(color INFO 'If you open a GitHub Issue, please download the log and attach it')"
  else
    printf "\n%s\n" \
      "$(color INFO 'Upload skipped. You can share the local file manually if needed.')"
  fi
}

is_command_available() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

supports_wait_n() {
  local major minor
  major=${BASH_VERSINFO[0]:-0}
  minor=${BASH_VERSINFO[1]:-0}

  (( major > 4 || (major == 4 && minor >= 3) ))
}

prune_parallel_pids() {
  local pid
  local -a remaining=()

  for pid in "${PARALLEL_PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      remaining+=("$pid")
    else
      wait "$pid" 2>/dev/null
    fi
  done

  PARALLEL_PIDS=("${remaining[@]}")
}

wait_for_parallel_slot() {
  while (( ${#PARALLEL_PIDS[@]} >= PARALLEL_JOBS )); do
    if supports_wait_n; then
      wait -n 2>/dev/null || true
      prune_parallel_pids
    else
      log "$LOG_INFO" "Bash < 4.3 detected; using legacy parallel wait loop"
      prune_parallel_pids
      if (( ${#PARALLEL_PIDS[@]} < PARALLEL_JOBS )); then
        break
      fi
      sleep 0.1
    fi
  done
}

register_parallel_pid() {
  local pid="$1"
  PARALLEL_PIDS+=("$pid")
}

detect_parallel_jobs() {
  local cpus=""

  if is_command_available "nproc"; then
    cpus=$(nproc 2>/dev/null)
  elif is_command_available "getconf"; then
    cpus=$(getconf _NPROCESSORS_ONLN 2>/dev/null)
  fi

  if [[ "$cpus" =~ ^[0-9]+$ ]] && ((10#$cpus >= 1)); then
    echo "$cpus"
  else
    echo 4
  fi
}

detect_distro() {
  if [[ -f /etc/os-release ]]; then
    distro=$(sed -n 's/^ID=//p' /etc/os-release | head -n 1 | tr -d '"')
  elif [[ -f /etc/redhat-release ]]; then
    distro="rhel"
  elif [[ -d /data/data/com.termux ]]; then
    distro="termux"
  fi
}

detect_package_manager() {
  local pkg_manager

  case "$distro" in
    ubuntu | debian | termux)
      pkg_manager="apt"
      ;;
    arch | manjaro)
      pkg_manager="pacman"
      ;;
    fedora)
      pkg_manager="dnf"
      ;;
    centos | rhel)
      if is_command_available "dnf"; then
        pkg_manager="dnf"
      else
        pkg_manager="yum"
      fi
      ;;
    opensuse*)
      pkg_manager="zypper"
      ;;
    alpine)
      pkg_manager="apk"
      ;;
    *)
      error_exit "Unknown distro: $distro"
      ;;
  esac

  echo "$pkg_manager"
}

get_missing_commands() {
  local missing=()

  for cmd in "${!DEPENDENCIES[@]}"; do
    if ! is_command_available "$cmd"; then
      missing+=("$cmd")
    fi
  done

  printf '%s\n' "${missing[@]}"
}

get_package_name() {
  local pkg_manager="$1"
  local command="$2"
  local mapping_key="${pkg_manager}:${command}"

  if [[ -n "${PACKAGE_MAPPING[$mapping_key]}" ]]; then
    echo "${PACKAGE_MAPPING[$mapping_key]}"
    return
  fi

  echo "${DEPENDENCIES[$command]:-$command}"
}

is_sudo_required() {
  if [[ "${EUID:-$(id -u)}" -eq 0 || "$distro" == "termux" ]]; then
    return 1
  fi

  return 0
}

get_install_args() {
  local pkg_manager="$1"
  local install_args

  case "$pkg_manager" in
    apt)
      install_args=("install" "-y")
      ;;
    pacman)
      install_args=("-Sy" "--noconfirm")
      ;;
    dnf | yum | zypper)
      install_args=("install" "-y")
      ;;
    apk)
      install_args=("add" "--no-cache")
      ;;
  esac

  echo "${install_args[@]}"
}

install_packages() {
  local pkg_manager="$1"
  shift
  local packages=("$@")
  local cmd_prefix=()
  local install_cmd=()

  if is_sudo_required; then
    cmd_prefix=("sudo")
    log "$LOG_INFO" "Running as non-root user, using sudo"
  fi

  cmd_prefix+=("$pkg_manager")

  if [[ "$pkg_manager" == "apt" ]]; then
    log "$LOG_INFO" "Updating package lists"
    if ! "${cmd_prefix[@]}" update; then
      error_exit "Error occurred while updating package lists"
    fi
  fi

  for pkg in "${packages[@]}"; do
    if ! is_valid_package_name "$pkg"; then
      error_exit "Invalid package name: $pkg"
    fi
  done

  read -ra install_args <<<"$(get_install_args "$pkg_manager")"
  if ((${#install_args[@]} == 0)); then
    error_exit "No install arguments available for package manager: $pkg_manager"
  fi
  install_cmd+=("${cmd_prefix[@]}" "${install_args[@]}" "${packages[@]}")

  log "$LOG_INFO" "Running: ${install_cmd[*]}"

  if ! "${install_cmd[@]}"; then
    error_exit "Error occurred while installing packages"
  fi
}

prompt_for_installation() {
  local missing=("$@")
  local response
  local formatted_deps=""

  for dep in "${missing[@]}"; do
    formatted_deps+="  $dep\n"
  done

  printf "\n%s\n%b\n%s " \
    "$(color WARN 'Missing dependencies:')" \
    "$formatted_deps" \
    "$(color INFO 'Do you want to install them? [y/N]:')"

  read -r response
  response=${response,,}

  case "$response" in
    y | yes)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

prompt_for_debug_upload() {
  local response

  printf "\n%s %s " \
    "$(color WARN 'Debug log upload?')" \
    "$(color INFO 'This will upload to 0x0.st (public). Proceed? [y/N]:')"

  read -r response
  response=${response,,}

  case "$response" in
    y | yes)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

install_dependencies() {
  local missing_dependencies=()
  local missing_commands pkg_manager package_name

  log "$LOG_INFO" "Checking dependencies"

  mapfile -t missing_commands < <(get_missing_commands)

  if [[ "${missing_commands[*]}" =~ ^[[:space:]]*$ ]]; then
    log "$LOG_INFO" "All dependencies are installed"
    return 0
  fi

  log "$LOG_INFO" "Missing commands: ${missing_commands[*]}"

  pkg_manager=$(detect_package_manager)

  log "$LOG_INFO" "Detected package manager: $pkg_manager"

  for cmd in "${missing_commands[@]}"; do
    package_name=$(get_package_name "$pkg_manager" "$cmd")
    missing_dependencies+=("$package_name")
  done

  log "$LOG_INFO" "Missing dependencies: ${missing_dependencies[*]}"

  if ! prompt_for_installation "${missing_dependencies[@]}" </dev/tty; then
    printf "%s\n" "$(color WARN 'Installation canceled by user')"
    exit 1
  fi

  log "$LOG_INFO" "Installing missing dependencies"
  install_packages "$pkg_manager" "${missing_dependencies[@]}"
}

is_valid_json() {
  local json="$1"
  jq -e . >/dev/null 2>&1 <<<"$json"
}

process_json() {
  local json="$1"
  local jq_filter="$2"

  if is_status_string "$json"; then
    echo "$json"
    return
  fi

  if [[ -z "$json" ]]; then
    echo ""
    return
  fi

  if ! is_valid_json "$json"; then
    log "$LOG_WARN" "Invalid JSON input for filter: $jq_filter"
    echo ""
    return
  fi

  jq -r "$jq_filter" <<<"$json"
}

format_value() {
  local value="$1"

  case "$value" in
    "$STATUS_NA")
      color NULL "$value"
      ;;
    "$STATUS_DENIED" | "$STATUS_SERVER_ERROR")
      color ERROR "$value"
      ;;
    "$STATUS_RATE_LIMIT")
      color WARN "$value"
      ;;
    *)
      bold "$value"
      ;;
  esac
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
  local left_part right_part
  local -a left_arr right_arr expanded
  local h total missing=0

  if [[ -z "$ip" || "$ip" == "null" ]]; then
    echo "$ip"
    return
  fi

  if [[ "$ip" == *"."* || ! "$ip" =~ ^[0-9A-Fa-f:]+$ ]]; then
    echo "$ip"
    return
  fi

  if [[ "$ip" == *"::"* ]]; then
    if [[ "${ip#*::}" == *"::"* ]]; then
      echo "$ip"
      return
    fi
    left_part="${ip%%::*}"
    right_part="${ip##*::}"
  else
    left_part="$ip"
    right_part=""
  fi

  if [[ -n "$left_part" ]]; then
    IFS=':' read -r -a left_arr <<<"$left_part"
  fi

  if [[ -n "$right_part" ]]; then
    IFS=':' read -r -a right_arr <<<"$right_part"
  fi

  for h in "${left_arr[@]}" "${right_arr[@]}"; do
    if [[ -z "$h" || ! "$h" =~ ^[0-9A-Fa-f]{1,4}$ ]]; then
      echo "$ip"
      return
    fi
  done

  total=$(( ${#left_arr[@]} + ${#right_arr[@]} ))
  if [[ "$ip" == *"::"* ]]; then
    missing=$(( 8 - total ))
    if (( missing < 1 )); then
      echo "$ip"
      return
    fi
  elif (( total != 8 )); then
    echo "$ip"
    return
  fi

  expanded=( "${left_arr[@]}" )
  for ((h = 0; h < missing; h++)); do
    expanded+=("0")
  done
  expanded+=( "${right_arr[@]}" )

  if (( ${#expanded[@]} < 3 )); then
    echo "$ip"
    return
  fi

  printf "%s:%s:%s::\n" "${expanded[0]}" "${expanded[1]}" "${expanded[2]}"
}

is_valid_port() {
  local port="$1"

  if [[ ! "$port" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  ((10#$port >= 1 && 10#$port <= 65535))
}

is_valid_proxy_addr() {
  local addr="$1"
  local host port

  if [[ "$addr" =~ ^\[(.+)\]:([0-9]+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    port="${BASH_REMATCH[2]}"
    [[ "$host" =~ ^[0-9A-Fa-f:]+$ ]] || return 1
  elif [[ "$addr" =~ ^([^:]+):([0-9]+)$ ]]; then
    host="${BASH_REMATCH[1]}"
    port="${BASH_REMATCH[2]}"
    [[ "$host" =~ ^[A-Za-z0-9.-]+$ ]] || return 1
  else
    return 1
  fi

  is_valid_port "$port"
}

is_valid_interface_name() {
  local name="$1"
  [[ "$name" =~ ^[A-Za-z0-9._:@-]+$ ]]
}

is_valid_ipv4() {
  local ip="$1"
  local IFS=.
  local -a parts
  local part

  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  read -r -a parts <<<"$ip"
  for part in "${parts[@]}"; do
    [[ "$part" =~ ^[0-9]+$ ]] || return 1
    ((10#$part >= 0 && 10#$part <= 255)) || return 1
  done
  return 0
}

is_valid_ipv6() {
  local ip="$1"
  local part
  local -a parts
  local group_count=0
  local double_colon_count=0
  local tmp

  [[ -n "$ip" && "$ip" == *:* ]] || return 1

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$ip" <<'PY'
import ipaddress
import sys
try:
    ipaddress.IPv6Address(sys.argv[1])
    sys.exit(0)
except Exception:
    sys.exit(1)
PY
    return $?
  fi

  [[ "$ip" =~ ^[0-9A-Fa-f:]+$ ]] || return 1

  tmp="$ip"
  while [[ "$tmp" == *"::"* ]]; do
    double_colon_count=$((double_colon_count + 1))
    tmp="${tmp#*::}"
  done

  ((double_colon_count <= 1)) || return 1

  if [[ "$ip" == *"::"* ]]; then
    ip="${ip#::}"
    ip="${ip%::}"
  fi

  IFS=':' read -r -a parts <<<"$ip"
  for part in "${parts[@]}"; do
    [[ -z "$part" ]] && continue
    [[ "$part" =~ ^[0-9A-Fa-f]{1,4}$ ]] || return 1
    group_count=$((group_count + 1))
  done

  if ((double_colon_count == 1)); then
    ((group_count <= 8)) || return 1
  else
    ((group_count == 8)) || return 1
  fi

  return 0
}

is_valid_package_name() {
  local name="$1"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9+._-]*$ ]]
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
      -d | --debug)
        DEBUG=true
        shift
        ;;
      -j | --json)
        JSON_OUTPUT=true
        shift
        ;;
      -g | --group)
        case "$2" in
          primary | custom | all)
            GROUPS_TO_SHOW="$2"
            ;;
          "")
            error_exit "Missing value for --group. Expected: primary, custom, or all"
            ;;
          *)
            error_exit "Invalid group: $2. Expected: primary, custom, or all"
            ;;
        esac
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
      -P | --parallel)
        if [[ "$2" =~ ^[0-9]+$ ]] && ((10#$2 >= 1)); then
          PARALLEL_JOBS="$2"
        else
          error_exit "Invalid parallel value: $2. Parallel jobs must be a positive integer"
        fi
        shift 2
        ;;
      -S | --force-spinner)
        FORCE_SPINNER=true
        shift
        ;;
      --progress-log)
        PROGRESS_LOG=true
        shift
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
        if ! is_valid_proxy_addr "$2"; then
          error_exit "Invalid proxy address: $2. Expected host:port or [ipv6]:port"
        fi
        PROXY_ADDR="$2"
        log "$LOG_INFO" "Using SOCKS5 proxy: $PROXY_ADDR"
        shift 2
        ;;
      -i | --interface)
        if ! is_valid_interface_name "$2"; then
          error_exit "Invalid interface name: $2"
        fi
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

is_status_string() {
  local value="$1"

  case "$value" in
    "$STATUS_DENIED" | "$STATUS_SERVER_ERROR" | "$STATUS_RATE_LIMIT" | "$STATUS_NA")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

status_from_http_code() {
  local code="$1"

  case "$code" in
    403)
      echo "$STATUS_DENIED"
      ;;
    429)
      echo "$STATUS_RATE_LIMIT"
      ;;
    5*)
      echo "$STATUS_SERVER_ERROR"
      ;;
    4*)
      echo "$STATUS_NA"
      ;;
    *)
      echo ""
      ;;
  esac
}

get_ping_command() {
  local version="$1"
  local ping_cmd

  if [[ "$version" == "4" ]]; then
    if is_command_available "ping"; then
      ping_cmd="ping"
    fi
  else
    if is_command_available "ping6"; then
      ping_cmd="ping6"
    elif is_command_available "ping"; then
      ping_cmd="ping -6"
    fi
  fi

  if [[ -n "$ping_cmd" ]]; then
    echo "$ping_cmd"
    return 0
  else
    return 1
  fi
}

check_ip_interfaces() {
  local version="$1"
  local ifconfig_output

  log "$LOG_INFO" "Checking for IPv${version} interfaces"

  if is_command_available "ip"; then
    if [[ -n $(ip -"${version}" addr show scope global 2>/dev/null) ]]; then
      log "$LOG_INFO" "IPv${version} global interfaces found"
      return 0
    fi
  elif is_command_available "ifconfig"; then
    ifconfig_output=$(ifconfig -a 2>/dev/null)
    if [[ "$version" == "4" ]]; then
      if echo "$ifconfig_output" | grep -E '\binet [0-9]+' | grep -Ev '\binet 127\.' >/dev/null; then
        log "$LOG_INFO" "IPv${version} global interfaces found (ifconfig)"
        return 0
      fi
    else
      if echo "$ifconfig_output" | grep -E '\binet6 [0-9A-Fa-f:]+' | grep -Ev '\binet6 (fe80:|::1)' >/dev/null; then
        log "$LOG_INFO" "IPv${version} global interfaces found (ifconfig)"
        return 0
      fi
    fi
  else
    log "$LOG_WARN" "Neither ip nor ifconfig is available to check IPv${version} interfaces"
    return 1
  fi

  log "$LOG_ERROR" "No global IPv${version} addresses found on interfaces"
  return 1
}

check_ip_connectivity() {
  local version="$1"
  local test_hosts_v4=("8.8.8.8" "8.8.4.4" "1.1.1.1" "1.0.0.1" "9.9.9.9")
  local test_hosts_v6=("2001:4860:4860::8888" "2001:4860:4860::8844" "2606:4700:4700::1111" "2606:4700:4700::1001" "2620:fe::9")
  local timeout=3
  local count=1
  local test_hosts ping_cmd

  log "$LOG_INFO" "Checking IPv${version} connectivity"

  ping_cmd=($(get_ping_command "$version"))

  if [[ ${#ping_cmd[@]} -eq 0 ]]; then
    log "$LOG_ERROR" "Ping command for IPv${version} is not available"
    return 1
  fi

  if [[ "$version" == "4" ]]; then
    test_hosts=("${test_hosts_v4[@]}")
  else
    test_hosts=("${test_hosts_v6[@]}")
  fi

  for host in "${test_hosts[@]}"; do
    if "${ping_cmd[@]}" -c "$count" -W "$timeout" "$host" >/dev/null 2>&1; then
      log "$LOG_INFO" "IPv${version} connectivity confirmed via $host"
      return 0
    fi
  done

  log "$LOG_ERROR" "IPv${version} connectivity test failed"
  return 1
}

check_ip_dns() {
  local version="$1"
  local test_domain="google.com"
  local record_type
  local dig_result

  log "$LOG_INFO" "Checking IPv${version} DNS resolution"

  if [[ "$version" == "4" ]]; then
    record_type="A"
  else
    record_type="AAAA"
  fi

  if is_command_available "nslookup"; then
    if nslookup -type="$record_type" "$test_domain" >/dev/null 2>&1; then
      log "$LOG_INFO" "IPv${version} DNS resolution works via nslookup"
      return 0
    fi
  elif is_command_available "dig"; then
    dig_result=$(dig +short -t "$record_type" "$test_domain" 2>/dev/null)
    if [[ -n "$dig_result" ]]; then
      log "$LOG_INFO" "IPv${version} DNS resolution works via dig"
      return 0
    fi
  elif is_command_available "host"; then
    if host -t "$record_type" "$test_domain" >/dev/null 2>&1; then
      log "$LOG_INFO" "IPv${version} DNS resolution works via host"
      return 0
    fi
  else
    log "$LOG_WARN" "Neither nslookup, dig, nor host is available to check IPv${version} DNS resolution"
    return 1
  fi

  log "$LOG_ERROR" "IPv${version} DNS resolution failed"
  return 1
}

check_ip_support() {
  local version="$1"
  local -a checks=("interfaces" "connectivity" "dns")
  local -a failed=()

  spinner_update "IPv$version support"
  log "$LOG_INFO" "Starting comprehensive IPv${version} support check"

  for check in "${checks[@]}"; do
    if ! "check_ip_${check}" "$version"; then
      failed+=("$check")
    fi
  done

  if [[ ${#failed[@]} -eq 0 ]]; then
    log "$LOG_INFO" "IPv${version} is fully supported (${checks[*]})"
    return 0
  else
    log "$LOG_ERROR" "IPv${version} is not fully supported. Failed checks: ${failed[*]}"
    return 1
  fi
}

ipv4_enabled() {
  [[ "$IPV6_ONLY" != true ]] && [[ "$IPV4_SUPPORTED" -eq 0 ]]
}

ipv6_enabled() {
  [[ "$IPV4_ONLY" != true ]] && [[ "$IPV6_SUPPORTED" -eq 0 ]]
}

can_use_ipv4() {
  ipv4_enabled && [[ -n "$EXTERNAL_IPV4" ]]
}

can_use_ipv6() {
  ipv6_enabled && [[ "$IPV6_SUPPORTED" -eq 0 ]] && [[ -n "$EXTERNAL_IPV6" ]]
}

preferred_ip_version() {
  can_use_ipv4 && echo 4 || echo 6
}

preferred_ip() {
  can_use_ipv4 && echo "$EXTERNAL_IPV4" || echo "$EXTERNAL_IPV6"
}

shuffle_identity_services() {
  local i tmp size rand_idx
  size=${#IDENTITY_SERVICES[@]}

  for ((i = size - 1; i > 0; i--)); do
    rand_idx=$((RANDOM % (i + 1)))

    if ((rand_idx != i)); then
      tmp=${IDENTITY_SERVICES[i]}
      IDENTITY_SERVICES[i]=${IDENTITY_SERVICES[rand_idx]}
      IDENTITY_SERVICES[rand_idx]=$tmp
    fi
  done
}

fetch_ip_from_service() {
  local service="$1"
  local ip_version="$2"
  local response

  response=$(curl_wrapper GET "https://$service" --ip-version "$ip_version")

  if [[ -n "$response" ]]; then
    echo "$response"
  fi
}

fetch_external_ip() {
  local ip_version="$1"
  local service ip

  spinner_update "External IPv$ip_version address"
  log "$LOG_INFO" "Getting external IPv${ip_version} address"

  shuffle_identity_services

  for service in "${IDENTITY_SERVICES[@]}"; do
    ip=$(fetch_ip_from_service "$service" "$ip_version")
    ip=${ip//$'\r'/}
    ip=${ip//$'\n'/}
    ip=${ip//[[:space:]]/}

    if [[ "$ip_version" == "4" ]]; then
      if ! is_valid_ipv4 "$ip"; then
        log "$LOG_WARN" "Invalid IPv4 from $service: $ip"
        continue
      fi
    else
      if ! is_valid_ipv6 "$ip"; then
        log "$LOG_WARN" "Invalid IPv6 from $service: $ip"
        continue
      fi
    fi

    if [[ -n "$ip" ]]; then
      log "$LOG_INFO" "Successfully obtained IPv${ip_version} address from $service: $ip"
      echo "$ip"
      return
    else
      log "$LOG_WARN" "No response from $service for IPv${ip_version}"
    fi
  done

  log "$LOG_ERROR" "Failed to obtain IPv${ip_version} address from any service"
}

discover_external_ips() {
  if ipv4_enabled; then
    EXTERNAL_IPV4=$(fetch_external_ip 4)
  fi

  if ipv6_enabled; then
    EXTERNAL_IPV6=$(fetch_external_ip 6)
  fi

  if [[ -z "$EXTERNAL_IPV4" ]] && [[ -z "$EXTERNAL_IPV6" ]]; then
    error_exit "Failed to obtain external IPv4 and IPv6 address. Check network connectivity, DNS settings, proxy configuration, and firewall rules."
  fi
}

get_asn() {
  local ip_version
  local ip
  local response traits

  ip_version=$(preferred_ip_version)
  ip=$(preferred_ip)

  spinner_update "ASN info"
  log "$LOG_INFO" "Getting ASN info for IP $ip"
  asn=""
  asn_name=""

  response=$(curl_wrapper GET "https://geoip.maxmind.com/geoip/v2.1/city/me" \
    --header "Referer: https://www.maxmind.com" \
    --ip-version "$ip_version")
  traits=$(process_json "$response" ".traits")
  asn=$(process_json "$traits" ".autonomous_system_number")
  asn_name=$(process_json "$traits" ".autonomous_system_organization")

  log "$LOG_INFO" "ASN info: AS$asn $asn_name"
}

get_registered_country() {
  local ip_version="$1"
  local response

  response=$(curl_wrapper GET "https://geoip.maxmind.com/geoip/v2.1/city/me" \
    --header "Referer: https://www.maxmind.com" \
    --ip-version "$ip_version")

  process_json "$response" ".registered_country.names.en"
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
    if kill -0 "$spinner_pid" 2>/dev/null; then
      kill "$spinner_pid" 2>/dev/null
    fi
    wait "$spinner_pid" 2>/dev/null
    spinner_pid=""
    printf "\\r%*s\\r" 40 " "
  fi

  if [[ -f "$SPINNER_SERVICE_FILE" ]]; then
    rm -f "$SPINNER_SERVICE_FILE"
    unset SPINNER_SERVICE_FILE
  fi
}

spinner_update() {
  local value="$1"

  if [[ -n "$SPINNER_SERVICE_FILE" ]]; then
    echo "$value" >"$SPINNER_SERVICE_FILE"
  fi

  if [[ "$PROGRESS_LOG" == true && "$JSON_OUTPUT" != "true" ]]; then
    if [[ "$value" != "$LAST_PROGRESS_MSG" ]]; then
      LAST_PROGRESS_MSG="$value"
      printf "%s %s\n" \
        "$(color INFO '[INFO]')" \
        "Checking: $value" >&2
    fi
  fi
}

spinner_cleanup() {
  spinner_stop
  if [[ "$DEBUG" == true ]]; then
    cleanup_debug
  fi
  exit 130
}

curl_wrapper() {
  local method="$1"
  local url="$2"
  shift 2
  local ip_version user_agent json data data_urlencode file forms headers
  local response_with_code response http_code curl_exit
  local curl_args=(
    --silent
    --compressed
    --location
    --retry-connrefused
    --retry-all-errors
    --retry "$CURL_RETRIES"
    --max-time "$CURL_TIMEOUT"
    -w '\n%{http_code}'
  )

  case "$method" in
    HEAD)
      curl_args+=(--head)
      ;;
    *)
      curl_args+=(--request "$method")
      ;;
  esac

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
      --data-urlencode)
        data_urlencode="$2"
        shift 2
        ;;
      --file)
        file="$2"
        shift 2
        ;;
      --form)
        forms+=("$2")
        shift 2
        ;;
    esac
  done

  if [[ "$ip_version" == "4" ]]; then
    curl_args+=(-4)
  else
    curl_args+=(-6)
  fi

  for h in "${headers[@]}"; do
    curl_args+=(-H "$h")
  done

  if [[ -n "$user_agent" ]]; then
    curl_args+=(-A "$user_agent")
  fi

  if [[ -n "$json" ]]; then
    curl_args+=(--json "$json")
  fi

  if [[ -n "$data" ]]; then
    curl_args+=(--data "$data")
  fi

  if [[ -n "$data_urlencode" ]]; then
    curl_args+=(--data-urlencode "$data_urlencode")
  fi

  if [[ -n "$file" ]]; then
    curl_args+=(--upload-file "$file")
  fi

  for f in "${forms[@]}"; do
    curl_args+=(-F "$f")
  done

  if [[ -n "$PROXY_ADDR" ]]; then
    curl_args+=(--proxy "socks5://$PROXY_ADDR")
  fi

  if [[ -n "$INTERFACE_NAME" ]]; then
    curl_args+=(--interface "$INTERFACE_NAME")
  fi

  curl_args+=("$url")

  response_with_code=$(curl "${curl_args[@]}")
  curl_exit=$?
  if [[ $curl_exit -ne 0 || -z "$response_with_code" ]]; then
    log "$LOG_WARN" "curl request failed for $url"
    echo ""
    return
  fi

  http_code=$(printf '%s\n' "$response_with_code" | tail -n 1)
  response=$(printf '%s\n' "$response_with_code" | sed '$d')

  if [[ ! "$http_code" =~ ^[0-9]{3}$ ]]; then
    log "$LOG_WARN" "Unexpected HTTP code for $url"
    echo "$response"
    return
  fi

  if [[ "$http_code" =~ ^[45][0-9]{2}$ ]]; then
    status_from_http_code "$http_code"
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

  # ip-api.com free tier only supports HTTP, not HTTPS
  if [[ "$service" == "IPAPI_COM" ]]; then
    url="http://$domain${url_template//\{ip\}/$ip}"
  else
    url="https://$domain${url_template//\{ip\}/$ip}"
  fi

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

  response=$(curl_wrapper GET "$url" "${request_params[@]}" --ip-version "$ip_version")

  process_response "$service" "$response" "$display_name" "$response_format"
}

process_response() {
  local service="$1"
  local response="$2"
  local display_name="$3"
  local response_format="${4:-json}"
  local jq_filter

  if is_status_string "$response"; then
    echo "$response"
    return
  fi

  if [[ -z "$response" || "$response" == *"<html"* ]]; then
    echo "$STATUS_NA"
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
    IP2LOCATION_IO)
      jq_filter='.country_code'
      ;;
    IPINFO_IO)
      jq_filter='.data.country'
      ;;
    IPAPI_CO)
      jq_filter='.country'
      ;;
    CLOUDFLARE)
      jq_filter='.country'
      ;;
    COUNTRY_IS)
      jq_filter='.country'
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
    IPWHOIS_IO)
      jq_filter='.country_code'
      ;;
    IPWHO_IS)
      jq_filter='.country_code'
      ;;
    IPAPI_COM)
      jq_filter='.countryCode'
      ;;
    DETECTOR404)
      jq_filter='.data.country.ccode'
      ;;
    *)
      echo "$response"
      ;;
  esac

  process_json "$response" "$jq_filter"
}

process_with_custom_handler() {
  local service="$1"
  local display_name="$2"
  local handler_func="${PRIMARY_SERVICES_CUSTOM_HANDLERS[$service]}"
  local ipv4_result=""
  local ipv6_result=""

  if can_use_ipv4; then
    log "$LOG_INFO" "Checking $display_name via IPv4 (custom handler)"
    ipv4_result=$("$handler_func" 4 4)
  fi

  if can_use_ipv6; then
    local transport=6
    local log_msg="Checking $display_name via IPv6 (custom handler)"

    if is_ipv6_over_ipv4_service "$service"; then
      transport=4
      log_msg="Checking $display_name (IPv6 address, IPv4 transport) (custom handler)"
    fi

    log "$LOG_INFO" "$log_msg"
    ipv6_result=$("$handler_func" "$transport" 6)
  fi

  add_result "primary" "$display_name" "$ipv4_result" "$ipv6_result"
}

process_with_probe() {
  local service="$1"
  local display_name="$2"
  local ipv4_result=""
  local ipv6_result=""

  if can_use_ipv4; then
    log "$LOG_INFO" "Checking $display_name via IPv4"
    ipv4_result=$(probe_service "$service" 4 "$EXTERNAL_IPV4")
  fi

  if can_use_ipv6; then
    local log_msg="Checking $display_name via IPv6"

    if is_ipv6_over_ipv4_service "$service"; then
      log_msg="Checking $display_name (IPv6 address, IPv4 transport)"
    fi

    log "$LOG_INFO" "$log_msg"
    ipv6_result=$(probe_service "$service" 6 "$EXTERNAL_IPV6")
  fi

  add_result "primary" "$display_name" "$ipv4_result" "$ipv6_result"
}

process_service() {
  local service="$1"
  local custom="${2:-false}"
  local service_config="${PRIMARY_SERVICES[$service]}"
  local display_name domain url_template response_format handler_func

  IFS='|' read -r display_name domain url_template response_format <<<"$service_config"
  display_name="${display_name:-$service}"

  if [[ "$custom" == true ]]; then
    process_custom_service "$service"
    return
  fi

  spinner_update "$display_name"

  if [[ -n "${PRIMARY_SERVICES_CUSTOM_HANDLERS[$service]}" ]]; then
    process_with_custom_handler "$service" "$display_name"
    return
  fi

  process_with_probe "$service" "$display_name"
}

process_custom_service() {
  local service="$1"
  local ipv4_result=""
  local ipv6_result=""
  local display_name handler_func group

  if [[ -n "${CUSTOM_SERVICES[$service]}" ]]; then
    display_name="${CUSTOM_SERVICES[$service]}"
    handler_func="${CUSTOM_SERVICES_HANDLERS[$service]}"
    group="custom"
  else
    display_name="$service"
    handler_func="${CUSTOM_SERVICES_HANDLERS[$service]}"
    group="custom"
  fi

  spinner_update "$display_name"

  if [[ -z "$handler_func" ]]; then
    log "$LOG_WARN" "Unknown service handler: $service"
    return
  fi

  if can_use_ipv4; then
    log "$LOG_INFO" "Checking $display_name via IPv4"
    ipv4_result=$("$handler_func" 4)
  fi

  if can_use_ipv6; then
    log "$LOG_INFO" "Checking $display_name via IPv6"
    ipv6_result=$("$handler_func" 6)
  fi

  add_result "$group" "$display_name" "$ipv4_result" "$ipv6_result"
}

run_service_group() {
  local group="$1"
  local services_string="${SERVICE_GROUPS[$group]}"
  local is_custom=false
  local services_array service_name handler_func display_name result

  read -ra services_array <<<"$services_string"

  log "$LOG_INFO" "Running $group group services"

  for service_name in "${services_array[@]}"; do
    if printf "%s\n" "${EXCLUDED_SERVICES[@]}" | grep_wrapper -Fxq "$service_name"; then
      log "$LOG_INFO" "Skipping service: $service_name"
      continue
    fi

    case "$group" in
      custom)
        is_custom=true
        ;;
    esac

    if [[ "$is_custom" == true ]]; then
      process_service "$service_name" true
    else
      process_service "$service_name"
    fi
  done
}

run_service_group_parallel() {
  local group="$1"
  local services_string="${SERVICE_GROUPS[$group]}"
  local is_custom=false
  local services_array service_name temp_dir result_file

  read -ra services_array <<<"$services_string"

  if [[ "$group" == "custom" ]]; then
    is_custom=true
  fi

  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/ipregion_parallel_XXXXXX")

  for service_name in "${services_array[@]}"; do
    if printf "%s\n" "${EXCLUDED_SERVICES[@]}" | grep_wrapper -Fxq "$service_name"; then
      log "$LOG_INFO" "Skipping service: $service_name"
      continue
    fi

    result_file="$temp_dir/$service_name"
    (
      RESULT_FILE="$result_file"
      if [[ "$is_custom" == true ]]; then
        process_service "$service_name" true
      else
        process_service "$service_name"
      fi
    ) &

    register_parallel_pid "$!"
    wait_for_parallel_slot
  done

  if [[ "$PROGRESS_LOG" == true && "$JSON_OUTPUT" != "true" ]]; then
    printf "%s %s\n" \
      "$(color INFO '[INFO]')" \
      "Waiting for remaining $group checks..." >&2
  fi

  wait
  PARALLEL_PIDS=()

  for service_name in "${services_array[@]}"; do
    if printf "%s\n" "${EXCLUDED_SERVICES[@]}" | grep_wrapper -Fxq "$service_name"; then
      continue
    fi

    result_file="$temp_dir/$service_name"
    if [[ -f "$result_file" ]]; then
      while IFS= read -r line; do
        [[ -n "$line" ]] && add_result_line "$line"
      done <"$result_file"
    fi
  done

  rm -rf "$temp_dir"
}

run_all_services() {
  local service_name

  for func in $(declare -F | awk '{print $3}' | grep_wrapper '^lookup_'); do
    service_name=${func#lookup_}
    service_name_uppercase=${service_name^^}

    if printf "%s\n" "${EXCLUDED_SERVICES[@]}" | grep_wrapper -Fxq "$service_name_uppercase"; then
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
  local t_primary t_custom
  local IFS=$'\n'

  if ((${#ARR_PRIMARY[@]} > 0)); then
    t_primary=$(printf '%s\n' "${ARR_PRIMARY[@]//|||/$'\t'}")
  fi

  if ((${#ARR_CUSTOM[@]} > 0)); then
    t_custom=$(printf '%s\n' "${ARR_CUSTOM[@]//|||/$'\t'}")
  fi

  # TODO: Add registered country to the JSON output
  RESULT_JSON=$(
    jq -n \
      --rawfile p <(printf "%s" "$t_primary") \
      --rawfile c <(printf "%s" "$t_custom") \
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
            custom:  lines_to_array($c)
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

  if [[ "$PROGRESS_LOG" == true && "$JSON_OUTPUT" != "true" ]]; then
    printf "%s %s\n" \
      "$(color INFO '[INFO]')" \
      "Done: $service" >&2
  fi

  if [[ -n "$RESULT_FILE" ]]; then
    printf "%s|||%s|||%s|||%s\n" "$group" "$service" "$ipv4" "$ipv6" >>"$RESULT_FILE"
    return
  fi

  case "$group" in
    primary) ARR_PRIMARY+=("$service|||$ipv4|||$ipv6") ;;
    custom) ARR_CUSTOM+=("$service|||$ipv4|||$ipv6") ;;
  esac
}

add_result_line() {
  local line="$1"
  local group rest service ipv4 ipv6

  group="${line%%|||*}"
  rest="${line#*|||}"
  service="${rest%%|||*}"
  rest="${rest#*|||}"
  ipv4="${rest%%|||*}"
  ipv6="${rest#*|||}"

  case "$group" in
    primary) ARR_PRIMARY+=("$service|||$ipv4|||$ipv6") ;;
    custom) ARR_CUSTOM+=("$service|||$ipv4|||$ipv6") ;;
  esac
}

print_table_group() {
  local group="$1"
  local group_title="$2"
  local na="N/A"
  local show_ipv4=0
  local show_ipv6=0
  local separator=$'\t'

  if can_use_ipv4; then
    show_ipv4=1
  fi

  if can_use_ipv6; then
    show_ipv6=1
  fi

  printf "%s\n\n" "$(color HEADER "$group_title")"

  if is_command_available "column"; then
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
          printf "%s%s" "$separator" "$(format_value "$v4")"
        fi

        if [[ $show_ipv6 -eq 1 ]]; then
          if [[ "$v6" == "null" || -z "$v6" ]]; then
            v6="$na"
          fi
          printf "%s%s" "$separator" "$(format_value "$v6")"
        fi

        printf "\n"
      done
    } | column -t -s "$separator"
  else
    log "$LOG_WARN" "column is not available; displaying unaligned output"
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
          printf "%s%s" "$separator" "$(format_value "$v4")"
        fi

        if [[ $show_ipv6 -eq 1 ]]; then
          if [[ "$v6" == "null" || -z "$v6" ]]; then
            v6="$na"
          fi
          printf "%s%s" "$separator" "$(format_value "$v6")"
        fi

        printf "\n"
      done
    }
  fi
}

print_header() {
  local ipv4 ipv6
  local na="N/A"
  local asn_value asn_name_value asn_display

  ipv4=$(process_json "$RESULT_JSON" ".ipv4")
  ipv6=$(process_json "$RESULT_JSON" ".ipv6")

  # TODO: Get registered country while initializing
  if [[ "$ipv4" != "null" ]]; then
    printf "%s: %s, %s %s\n" "$(color HEADER 'IPv4')" "$(bold "$(mask_ipv4 "$ipv4")")" "registered in" "$(bold "$(get_registered_country 4)")"
  fi

  if [[ "$ipv6" != "null" ]]; then
    printf "%s: %s, %s %s\n" "$(color HEADER 'IPv6')" "$(bold "$(mask_ipv6 "$ipv6")")" "registered in" "$(bold "$(get_registered_country 6)")"
  fi

  asn_value="$asn"
  asn_name_value="$asn_name"

  if [[ -z "$asn_value" || "$asn_value" == "null" ]]; then
    asn_display="$na"
  elif [[ -z "$asn_name_value" || "$asn_name_value" == "null" ]]; then
    asn_display="AS$asn_value"
  else
    asn_display="AS$asn_value $asn_name_value"
  fi

  printf "%s: %s\n\n" "$(color HEADER 'ASN')" "$(bold "$asn_display")"
}

print_results() {
  finalize_json

  if [[ "$JSON_OUTPUT" == true ]]; then
    echo "$RESULT_JSON" | jq
    return
  fi

  local restart_spinner=false
  if [[ "$spinner_running" == true ]]; then
    restart_spinner=true
    spinner_stop
  fi

  if [[ "$HEADER_PRINTED" != true ]]; then
    print_header
  fi

  case "$GROUPS_TO_SHOW" in
    primary)
      print_table_group "primary" "GeoIP services"
      ;;
    custom)
      print_table_group "custom" "Popular services"
      ;;
    *)
      print_table_group "custom" "Popular services"
      printf "\n"
      print_table_group "primary" "GeoIP services"
      ;;
  esac

  if [[ "$restart_spinner" == true ]]; then
    spinner_start
  fi
}

lookup_maxmind() {
  process_service "MAXMIND"
}

lookup_ripe() {
  process_service "RIPE"
}

lookup_ip2location_io() {
  process_service "IP2LOCATION_IO"
}

lookup_ipinfo_io() {
  process_service "IPINFO_IO"
}

lookup_ipapi_co() {
  process_service "IPAPI_CO"
}

lookup_cloudflare() {
  process_service "CLOUDFLARE"
}

lookup_ifconfig_co() {
  process_service "IFCONFIG_CO"
}

lookup_detector404() {
  process_service "DETECTOR404"
}

lookup_iplocation_com() {
  local ip_version="$1"
  local response ip

  if [[ "$ip_version" -eq 4 ]]; then
    ip="$EXTERNAL_IPV4"
  else
    ip="$EXTERNAL_IPV6"
  fi

  if [[ -z "$ip" ]]; then
    log "$LOG_WARN" "Skipping iplocation.com lookup: empty IP for IPv${ip_version}"
    echo ""
    return
  fi

  if [[ "$ip_version" -eq 4 ]]; then
    if ! is_valid_ipv4 "$ip"; then
      log "$LOG_WARN" "Skipping iplocation.com lookup: invalid IPv4 address"
      echo ""
      return
    fi
  else
    if ! is_valid_ipv6 "$ip"; then
      log "$LOG_WARN" "Skipping iplocation.com lookup: invalid IPv6 address"
      echo ""
      return
    fi
  fi

  response=$(curl_wrapper POST "https://iplocation.com" --ip-version "$ip_version" --user-agent "$USER_AGENT" --data-urlencode "ip=$ip")
  process_json "$response" ".country_code"
}

lookup_google() {
  local ip_version="$1"
  local response

  response=$(curl_wrapper GET "https://www.google.com" \
    --user-agent "$USER_AGENT" \
    --ip-version "$ip_version")

  grep_wrapper --perl '"MgUcDb":"\K[^"]*' <<<"$response"
}

lookup_youtube() {
  local ip_version="$1"
  local response json_result

  response=$(curl_wrapper GET "https://www.youtube.com/sw.js_data" --ip-version "$ip_version")

  json_result=$(tail -n +3 <<<"$response")
  process_json "$json_result" ".[0][2][0][0][1]"
}

lookup_youtube_premium() {
  local ip_version="$1"
  local response is_available

  response=$(curl_wrapper GET "https://www.youtube.com/premium" \
    --ip-version "$ip_version" \
    --user-agent "$USER_AGENT" \
    --header "Accept-Language: en-US,en;q=0.9")

  if [[ -z "$response" ]]; then
    echo ""
    return
  fi

  is_available=$(grep_wrapper -io "youtube premium is not available in your country" <<<"$response")

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

  response=$(curl_wrapper GET "https://www.google.com/search?q=cats" --ip-version "$ip_version" \
    --user-agent "$USER_AGENT" \
    --header "Accept-Language: en-US,en;q=0.9")

  if [[ -z "$response" ]]; then
    echo ""
    return
  fi

  is_captcha=$(grep_wrapper -iE "unusual traffic from|is blocked|unaddressed abuse" <<<"$response")

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
  curl_wrapper GET "https://gspe1-ssl.ls.apple.com/pep/gcc" --ip-version "$ip_version"
}

lookup_steam() {
  local ip_version="$1"
  local response

  response=$(curl_wrapper HEAD "https://store.steampowered.com" --ip-version "$ip_version")
  grep_wrapper --perl 'steamCountry=\K[^%;]*' <<<"$response"
}

lookup_tiktok() {
  local ip_version="$1"
  local response

  response=$(curl_wrapper GET "https://www.tiktok.com/api/v1/web-cookie-privacy/config?appId=1988" --ip-version "$ip_version")
  process_json "$response" ".body.appProps.region"
}

lookup_ookla_speedtest() {
  local ip_version="$1"
  local response

  response=$(curl_wrapper GET "https://www.speedtest.net/api/js/config-sdk" --ip-version "$ip_version")
  process_json "$response" ".location.countryCode"
}

lookup_jetbrains() {
  local ip_version="$1"
  local response

  response=$(curl_wrapper GET "https://data.services.jetbrains.com/geo" --ip-version "$ip_version")
  process_json "$response" ".code"
}

lookup_playstation() {
  local ip_version="$1"
  local response

  response=$(curl_wrapper HEAD "https://www.playstation.com" --ip-version "$ip_version")
  grep_wrapper --perl 'country=\K[^;]*' <<<"$response" | head -n1
}

lookup_microsoft() {
  local ip_version="$1"
  local response

  response=$(curl_wrapper GET "https://login.live.com" --ip-version "$ip_version")
  grep_wrapper --perl '"sRequestCountry":"\K[^"]*' <<<"$response"
}

main() {
  parse_arguments "$@"

  setup_debug

  trap spinner_cleanup EXIT INT TERM

  if (( PARALLEL_JOBS <= 0 )); then
    PARALLEL_JOBS=$(detect_parallel_jobs)
  fi

  print_startup_message

  if [[ "$JSON_OUTPUT" != true ]]; then
    printf "%s %s\n" \
      "$(color INFO '[INFO]')" \
      "Checking dependencies..." >&2
  fi

  detect_distro
  install_dependencies

  if [[ "$JSON_OUTPUT" != "true" && "$VERBOSE" != "true" && "$PROGRESS_LOG" != true && ( "$PARALLEL_JOBS" -le 1 || "$FORCE_SPINNER" == true ) ]]; then
    spinner_start
  fi

  if ipv4_enabled; then
    check_ip_support 4
    IPV4_SUPPORTED=$?
  fi

  if ipv6_enabled; then
    check_ip_support 6
    IPV6_SUPPORTED=$?
  fi

  if [[ "$IPV6_ONLY" == true && "$IPV6_SUPPORTED" -ne 0 ]]; then
    error_exit "IPv6 is not supported on this system"
  fi

  discover_external_ips
  get_asn

  if [[ "$JSON_OUTPUT" != "true" ]]; then
    local restart_spinner=false
    if [[ "$spinner_running" == true ]]; then
      restart_spinner=true
      spinner_stop
    fi

    finalize_json
    print_header
    HEADER_PRINTED=true

    if [[ "$restart_spinner" == true ]]; then
      spinner_start
    fi
  fi

  case "$GROUPS_TO_SHOW" in
    primary)
      if (( PARALLEL_JOBS > 1 )); then
        run_service_group_parallel "primary"
      else
        run_service_group "primary"
      fi
      ;;
    custom)
      if (( PARALLEL_JOBS > 1 )); then
        run_service_group_parallel "custom"
      else
        run_service_group "custom"
      fi
      ;;
    *)
      if (( PARALLEL_JOBS > 1 )); then
        run_service_group_parallel "primary"
        run_service_group_parallel "custom"
      else
        run_service_group "primary"
        run_service_group "custom"
      fi
      ;;
  esac

  if [[ "$PROGRESS_LOG" == true && "$JSON_OUTPUT" != "true" ]]; then
    printf "%s %s\n" \
      "$(color INFO '[INFO]')" \
      "Rendering results..." >&2
  fi

  if [[ "$JSON_OUTPUT" != "true" && "$VERBOSE" != "true" && "$PROGRESS_LOG" != true && ( "$PARALLEL_JOBS" -le 1 || "$FORCE_SPINNER" == true ) ]]; then
    spinner_stop
  fi

  print_results

  cleanup_debug

  trap - EXIT INT TERM
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
