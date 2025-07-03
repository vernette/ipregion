#!/usr/bin/env bash

SCRIPT_URL="https://github.com/vernette/ipregion"
DEPENDENCIES="jq curl util-linux"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"

VERBOSE=false
JSON_OUTPUT=false

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
DEPENDENCIES=("jq" "curl" "util-linux")

# TODO: Add missing services
declare -A PRIMARY_SERVICES=(
  [MAXMIND]="maxmind.com|geoip.maxmind.com|/geoip/v2.1/city/me"
  [RIPE]="rdap.db.ripe.net|rdap.db.ripe.net|/ip/{ip}"
  [IPINFO_IO]="ipinfo.io|ipinfo.io|/widget/demo/{ip}"
  [IPREGISTRY]="ipregistry.co|api.ipregistry.co|/{ip}?hostname=true&key=sb69ksjcajfs4c"
  [IPAPI_CO]="ipapi.co|ipapi.co|/{ip}/json"
)

PRIMARY_SERVICES_ORDER=(
  "MAXMIND"
  "RIPE"
  "IPINFO_IO"
  "IPREGISTRY"
  "IPAPI_CO"
)

declare -A SERVICE_HEADERS=(
  [IPREGISTRY]='("Origin: https://ipregistry.co")'
  [MAXMIND]='("Referer: https://www.maxmind.com")'
)

declare -A CUSTOM_SERVICES=(
  [YOUTUBE]="youtube.com"
)

CUSTOM_SERVICES_ORDER=(
  "YOUTUBE"
)

declare -A SERVICE_GROUPS=(
  [primary]="${PRIMARY_SERVICES_ORDER[*]}"
  [custom]="${CUSTOM_SERVICES_ORDER[*]}"
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
  exit "$exit_code"
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v | --verbose)
        VERBOSE=true
        shift
        ;;
      -j | --json)
        JSON_OUTPUT=true
        shift
        ;;
      *)
        error_exit "Unknown option: $1"
        ;;
    esac
  done
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
  asn=$(jq -r '.asn' <<<"$response")
  asn_name=$(jq -r '.organization.name' <<<"$response")

  log "$LOG_INFO" "ASN info: AS$asn $asn_name"
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
  local display_name="$3"
  local jq_filter

  if ! is_valid_json "$response"; then
    log "$LOG_ERROR" "Invalid JSON response from $display_name: $response"
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
    *)
      echo "$response"
      ;;
  esac

  process_json "$response" "$jq_filter"
}

is_ipv6_over_ipv4_service() {
  local service="$1"
  for s in "${IPV6_OVER_IPV4_SERVICES[@]}"; do
    [[ "$s" == "$service" ]] && return 0
  done
  return 1
}

process_service() {
  # TODO: Make service domain two-level and use it in log
  local service="$1"
  local custom="${2:-false}"
  local service_config="${PRIMARY_SERVICES[$service]}"
  local display_name domain url_template response ipv4_result ipv6_result

  if [[ "$custom" == true ]]; then
    process_custom_service "$service"
    return
  fi

  IFS='|' read -r display_name domain url_template <<<"$service_config"

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
  log "$LOG_INFO" "Checking $display_name via IPv4"
  ipv4_result=$(make_request GET "$url_v4" "${request_params[@]}" --ip-version 4)
  ipv4_result=$(process_response "$service" "$ipv4_result" "$display_name")

  if is_ipv6_over_ipv4_service "$service" && [[ "$IPV6_SUPPORTED" -eq 0 && -n "$EXTERNAL_IPV6" ]]; then
    local url_v6="https://$domain${url_template/\{ip\}/$EXTERNAL_IPV6}"
    log "$LOG_INFO" "Checking $display_name (IPv6 address, IPv4 transport)"
    ipv6_result=$(make_request GET "$url_v6" "${request_params[@]}" --ip-version 4)
    ipv6_result=$(process_response "$service" "$ipv6_result" "$display_name")
  else
    if [[ "$IPV6_SUPPORTED" -eq 0 && -n "$EXTERNAL_IPV6" ]]; then
      local url_v6="https://$domain${url_template/\{ip\}/$EXTERNAL_IPV6}"
      log "$LOG_INFO" "Checking $display_name via IPv6"
      ipv6_result=$(make_request GET "$url_v6" "${request_params[@]}" --ip-version 6)
      ipv6_result=$(process_response "$service" "$ipv6_result" "$display_name")
    else
      ipv6_result=""
    fi
  fi

  add_result "primary" "$display_name" "$ipv4_result" "$ipv6_result"
}

process_custom_service() {
  local service="$1"
  local ipv4_result ipv6_result
  local display_name="${CUSTOM_SERVICES[$service]:-$service}"

  case "$service" in
    YOUTUBE)
      log "$LOG_INFO" "Checking $display_name via IPv4"
      ipv4_result=$(lookup_youtube 4)
      if [[ "$IPV6_SUPPORTED" -eq 0 && -n "$EXTERNAL_IPV6" ]]; then
        log "$LOG_INFO" "Checking $display_name via IPv6"
        ipv6_result=$(lookup_youtube 6)
      else
        ipv6_result=""
      fi
      add_result "custom" "$display_name" "$ipv4_result" "$ipv6_result"
      ;;
    *)
      log "$LOG_WARN" "Unknown custom service: $service"
      ;;
  esac
}

run_service_group() {
  local group="$1"
  local services_string="${SERVICE_GROUPS[$group]}"
  local services_array service_name func_name

  read -ra services_array <<<"$services_string"

  log "$LOG_INFO" "Running $group group services"

  for service_name in "${services_array[@]}"; do
    if printf "%s\n" "${EXCLUDED_SERVICES[@]}" | grep -Fxq "$service_name"; then
      log "$LOG_INFO" "Skipping service: $service_name"
      continue
    fi

    if [[ -n "${CUSTOM_SERVICES[$service_name]}" ]]; then
      process_service "$service_name" true
      continue
    fi

    func_name="lookup_${service_name,,}"

    if declare -F "$func_name" >/dev/null 2>&1; then
      "$func_name"
    else
      log "$LOG_WARN" "Function $func_name not found for service $service_name"
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

lookup_youtube() {
  local ip_version="$1"
  local sed_filter='s/.*"[a-z]\{2\}_\([A-Z]\{2\}\)".*/\1/p'
  local sed_fallback_filter='s/.*"[a-z]\{2\}-\([A-Z]\{2\}\)".*/\1/p'
  local response result

  response=$(make_request GET "https://www.google.com" \
    --user-agent "$USER_AGENT" \
    --ip-version "$ip_version")

  result=$(sed -n "$sed_filter" <<<"$response")

  if [[ -z "$result" ]]; then
    result=$(sed -n "$sed_fallback_filter" <<<"$response")
  fi

  echo "$result"
}

init_json_output() {
  RESULT_JSON=$(jq -n \
    --arg version "1" \
    --arg ipv4 "$EXTERNAL_IPV4" \
    --arg ipv6 "$EXTERNAL_IPV6" \
    '{version: ($version|tonumber), ipv4: ($ipv4 | select(length > 0) // null), ipv6: ($ipv6 | select(length > 0) // null), results: {primary: [], custom: []}}')
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

format_value() {
  local value="$1"
  local not_available="$2"

  if [[ "$value" == "$not_available" ]]; then
    color NULL "$value"
  else
    bold "$value"
  fi
}

print_table_group() {
  local group="$1"
  local group_title="$2"
  local separator="|||"
  local not_available="N/A"
  local show_ipv4=0
  local show_ipv6=0
  local header row ipv4_res ipv6_res

  [[ -n "$EXTERNAL_IPV4" ]] && show_ipv4=1
  [[ -n "$EXTERNAL_IPV6" ]] && show_ipv6=1

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
      service=$(jq -r '.service' <<<"$item")
      row+=("$(color SERVICE "$service")")

      if [[ $show_ipv4 -eq 1 ]]; then
        ipv4_res=$(jq -r --arg na "$not_available" '.ipv4 // $na' <<<"$item")
        [[ "$ipv4_res" == "null" ]] && ipv4_res="$not_available"
        row+=("$(format_value "$ipv4_res" "$not_available")")
      fi

      if [[ $show_ipv6 -eq 1 ]]; then
        ipv6_res=$(jq -r --arg na "$not_available" '.ipv6 // $na' <<<"$item")
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
  print_table_group "primary" "Primary services"
  printf "\n"
  print_table_group "custom" "Custom services"
}

mask_ipv4() {
  local ip="$1"
  echo "${ip%.*}.*"
}

mask_ipv6() {
  local ip="$1"
  echo "$ip" | sed -E 's/^([^:]+:[^:]+:[^:]+:)[^:]+(.*)$/\1****\2/'
}

print_header() {
  local ipv4 ipv6

  ipv4=$(jq -r '.ipv4' <<<"$RESULT_JSON")
  ipv6=$(jq -r '.ipv6' <<<"$RESULT_JSON")

  printf "%s\n\n" "$(color URL "Made with ")$(color HEART '❤')$(color URL " by vernette — $SCRIPT_URL")"

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
  print_table
}

main() {
  parse_arguments "$@"

  install_dependencies

  check_ipv6_support
  IPV6_SUPPORTED=$?

  get_external_ip
  get_asn

  init_json_output

  run_service_group "primary"
  run_service_group "custom"

  print_results
}

main "$@"
