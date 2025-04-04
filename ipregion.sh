#!/usr/bin/env bash

DEPENDENCIES="jq curl"

LOG_INFO="INFO"
LOG_WARN="WARNING"
LOG_ERROR="ERROR"

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
  echo "Do you want to install them?? [y/N]: "

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
}

install_dependencies() {
  local missing_packages
  local pkg_manager

  read -r -a missing_packages <<<"$(check_missing_dependencies)"

  if [[ ${#missing_packages[@]} -eq 0 ]]; then
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

main() {
  install_dependencies

  check_ipv6_support
  IPV6_SUPPORTED=$?
}

main
