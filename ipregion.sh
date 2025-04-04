#!/usr/bin/env bash

DEPENDENCIES="jq curl"

LOG_INFO="INFO"
LOG_WARN="WARNING"
LOG_ERROR="ERROR"

USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"

# TODO: Add missing services
declare -A DOMAIN_MAP=(
  [RIPE]="rdap.db.ripe.net"
  [IPINFO_IO]="ipinfo.io"
  [IPREGISTRY]="ipregistry.co"
  [IPAPI]="ipapi.com"
  [DBIP]="db-ip.com"
)

get_timestamp() {
  local format="$1"
  date +"$format"
}

log() {
  local log_level="$1"
  local message="${*:2}"
  local timestamp

  timestamp=$(get_timestamp "%d.%m.%Y %H:%M:%S")
  echo "[$timestamp] [$log_level]: $message"
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
  printf "Do you want to install them? [y/N]: "
  read -r answer

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
  local use_sudo=""

  # Check if the script is running in Termux
  if [[ -d /data/data/com.termux ]]; then
    echo "termux"
    return
  fi

  if [[ "$(id -u)" -ne 0 ]]; then
    use_sudo="sudo"
  fi

  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "$ID" in
      debian | ubuntu)
        echo "$use_sudo apt"
        ;;
      arch)
        echo "$use_sudo pacman"
        ;;
      fedora)
        echo "$use_sudo dnf"
        ;;
      *)
        log "$LOG_ERROR" "Unknown distribution: $ID. Please install dependencies manually."
        exit 1
        ;;
    esac
  else
    log "$LOG_ERROR" "File /etc/os-release not found, unable to determine distribution. Please install dependencies manually."
    exit 1
  fi
}

install_with_package_manager() {
  local pkg_manager="$1"
  local packages=("${@:2}")

  case "$pkg_manager" in
    *apt)
      $pkg_manager update
      NEEDRESTART_MODE=a $pkg_manager install -y "${packages[@]}"
      ;;
    *pacman)
      $pkg_manager -Syy --noconfirm "${packages[@]}"
      ;;
    *dnf)
      $pkg_manager install -y "${packages[@]}"
      ;;
    termux)
      apt update
      apt install -y "${packages[@]}"
      ;;
  esac
  clear
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

  log "$LOG_INFO" "Installing missing dependencies"
  install_with_package_manager "$pkg_manager" "${missing_packages[@]}"
}

check_ipv6_support() {
  log "$LOG_INFO" "Checking for IPv6 support"

  if [[ -n $(ip -6 addr show scope global 2>/dev/null) ]]; then
    log "$LOG_INFO" "IPv6 is supported"
    return 0
  else
    log "$LOG_WARN" "IPv6 is not supported"
    return 1
  fi
}

make_request() {
  local curl_command
  local method="$1"
  local url="$2"
  shift 2
  local user_agent=""
  local headers=()
  local json=""
  local proxy=""
  local response

  while (("$#")); do
    case "$1" in
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
  for func in $(declare -F | awk '{print $3}' | grep '^lookup_'); do
    "$func"
  done
}

main() {
  install_dependencies

  check_ipv6_support
  IPV6_SUPPORTED=$?
}

main
