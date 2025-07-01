#!/usr/bin/env bash

VERBOSE=false

DEPENDENCIES="jq curl"

# TODO: Make such constants readonly
COLOR_WHITE="\033[97m"
COLOR_RED="\033[31m"
COLOR_GREEN="\033[32m"
COLOR_BLUE="\033[36m"
COLOR_ORANGE="\033[33m"
COLOR_RESET="\033[0m"

LOG_INFO="INFO"
LOG_WARN="WARNING"
LOG_ERROR="ERROR"

USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"

EXCLUDED_SERVICES=(
  "IPINFO_IO"
  "IPREGISTRY"
  "IPAPI_CO"
  "DBIP"
)

# TODO: Add missing services
declare -A DOMAIN_MAP=(
  [MAXMIND]="geoip.maxmind.com|/geoip/v2.1/city/me"
  [RIPE]="rdap.db.ripe.net|/ip/{ip}"
  [IPINFO_IO]="ipinfo.io|/widget/demo/{ip}"
  [IPREGISTRY]="api.ipregistry.co|/{ip}?hostname=true&key=sb69ksjcajfs4c"
  [IPAPI_CO]="ipapi.co|/{ip}/json"
  [DBIP]="db-ip.com|/demo/home.php?s={ip}"
)

declare -A SERVICE_HEADERS=(
  [IPREGISTRY]='("Origin: https://ipregistry.co")'
  [MAXMIND]='("Referer: https://www.maxmind.com")'
)

IDENTITY_SERVICES=(
  "ident.me"
  "ifconfig.me"
  "api64.ipify.org"
  "ifconfig.co"
  "ifconfig.me"
)

get_timestamp() {
  local format="$1"
  date +"$format"
}

log() {
  local log_level="$1"
  local message="${*:2}"
  local timestamp

  if [[ "$VERBOSE" == true ]]; then
    timestamp=$(get_timestamp "%d.%m.%Y %H:%M:%S")
    echo "[$timestamp] [$log_level]: $message"
  fi
}

error_exit() {
  local message="$1"
  local exit_code="${2:-1}"
  printf "[%b%s%b] %b%s%b\n" "$COLOR_RED" "ERROR" "$COLOR_RESET" "$COLOR_WHITE" "$message" "$COLOR_RESET" >&2
  exit "$exit_code"
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v | --verbose)
        VERBOSE=true
        shift
        ;;
      *)
        error_exit "Unknown option: $1"
        ;;
    esac
  done
}

is_installed() {
  # NOTE: Works only for packages with the same name as command itself
  command -v "$1" >/dev/null 2>&1
}

check_missing_dependencies() {
  local missing_pkgs=()

  for pkg in $DEPENDENCIES; do
    if ! is_installed "$pkg"; then
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
  fi

  case "$pkg_manager" in
    *apt)
      $use_sudo "$pkg_manager" update
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

check_ipv6_support() {
  log "$LOG_INFO" "Checking for IPv6 support"

  if [[ -n $(ip -6 addr show scope global 2>/dev/null) ]]; then
    log "$LOG_INFO" "IPv6 is supported"
    return 0
  fi

  log "$LOG_WARN" "IPv6 is not supported on this system"
  return 1
}

get_external_ip() {
  local identity_service
  log "$LOG_INFO" "Getting external IPv4 address"

  identity_service=${IDENTITY_SERVICES[$RANDOM % ${#IDENTITY_SERVICES[@]}]}
  log "$LOG_INFO" "Using identity service: $identity_service"

  EXTERNAL_IPV4="$(make_request GET "https://$identity_service" --ip-version 4)"
  log "$LOG_INFO" "External IPv4: $EXTERNAL_IPV4"

  if [[ "$IPV6_SUPPORTED" -eq 0 ]]; then
    log "$LOG_INFO" "Getting external IPv6 address"
    EXTERNAL_IPV6="$(make_request GET "https://$identity_service" --ip-version 6)"
    log "$LOG_INFO" "External IPv6: $EXTERNAL_IPV6"
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

  # TODO: Process errors and add request timeout
  curl_command="curl --silent -X $method"

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

  if [[ -n "$proxy" ]]; then
    curl_command+=" --proxy $proxy --insecure"
  fi

  curl_command+=" '$url'"

  response=$(eval "$curl_command")
  echo "$response"
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

    "$func"
  done
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

process_response() {
  local service="$1"
  local response="$2"
  local jq_filter

  if ! is_valid_json "$response"; then
    log "$LOG_ERROR" "Invalid JSON response from $service: $response"
    return 1
  fi

  # TODO: Process rate-limits

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
    DBIP)
      jq_filter='.demoInfo.countryCode'
      ;;
    *)
      echo "$response"
      ;;
  esac

  process_json "$response" "$jq_filter"
}

process_service() {
  # TODO: Make service domain two-level and use it in log
  local service="$1"
  local service_config="${DOMAIN_MAP[$service]}"
  local domain url_template response

  IFS='|' read -r domain url_template <<<"$service_config"

  local request_params=(
    --user-agent "$USER_AGENT"
  )

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
  log "$LOG_INFO" "Checking $service via IPv4"
  response=$(make_request GET "$url_v4" "${request_params[@]}" --ip-version 4)
  process_response "$service" "$response"

  if [[ "$IPV6_SUPPORTED" -eq 0 && -n "$EXTERNAL_IPV6" ]]; then
    local url_v6="https://$domain${url_template/\{ip\}/$EXTERNAL_IPV6}"

    log "$LOG_INFO" "Checking $service via IPv6"
    response=$(make_request GET "$url_v6" "${request_params[@]}" --ip-version 6)
    process_response "$service" "$response"
  fi
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

lookup_dbip() {
  process_service "DBIP"
}

main() {
  parse_arguments "$@"

  install_dependencies

  check_ipv6_support
  IPV6_SUPPORTED=$?

  get_external_ip

  run_all_services
}

main "$@"
