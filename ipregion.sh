#!/usr/bin/env bash

# Shell script to check IP country code from various sources
# curl and jq are required to run this script

# Currently supported sources:
#   https://rdap.db.ripe.net
#   https://maxmind.com
#   https://ipinfo.io
#   https://ipregistry.co
#   https://ipapi.com
#   https://db-ip.com
#   https://ipdata.co
#   https://ipwhois.io
#   https://ifconfig.co
#   https://whoer.net
#   https://ipquery.io
#   https://country.is
#   https://cleantalk.org
#   https://ip-api.com
#   https://ipgeolocation.io
#   https://ipapi.co
#   https://findip.net
#   https://geojs.io
#   https://iplocation.com
#   https://geoapify.com
#   https://ipapi.is
#   https://freeipapi.com
#   https://ipbase.com
#   https://ip.sb

DEPENDENCIES="jq curl"

declare -A IP_SERVICES=(
  [RIPE]="rdap.db.ripe.net"
  [MAXMIND]="maxmind.com"
  [IPINFO]="ipinfo.io"
  [IPREGISTRY]="ipregistry.co"
  [IPAPI]="ipapi.com"
  [DB_IP]="db-ip.com"
  [IPDATA]="ipdata.co"
  [IPWHOIS]="ipwhois.io"
  [IFCONFIG]="ifconfig.co"
  [WHOER]="whoer.net"
  [IPQUERY]="ipquery.io"
  [COUNTRY_IS]="country.is"
  [CLEANTALK]="cleantalk.org"
  [IP_API]="ip-api.com"
  [IPGEOLOCATION]="ipgeolocation.io"
  [IPAPI_CO]="ipapi.co"
  [FINDIP]="findip.net"
  [GEOJS]="geojs.io"
  [IPLOCATION]="iplocation.com"
  [GEOAPIFY]="geoapify.com"
  [IPAPI_IS]="ipapi.is"
  [FREEIPAPI]="freeipapi.com"
  [IPBASE]="ipbase.com"
  [IP_SB]="ip.sb"
)

declare -A IDENTITY_SERVICES=(
  [IDENT]="https://ident.me"
  [IFCONFIG_CO]="https://ifconfig.co"
  [IFCONFIG_ME]="https://ifconfig.me"
  [ICANHAZIP]="https://icanhazip.com"
  [IPIFY]="https://api64.ipify.org"
)

clear_screen() {
  clear
}

get_timestamp() {
  local format="$1"
  date +"$format"
}

log_message() {
  local log_level="$1"
  local message="${*:2}"
  local timestamp
  timestamp=$(get_timestamp "%d.%m.%Y %H:%M:%S")
  echo "[$timestamp] [$log_level]: $message"
}

# TODO: Dependencies installation function

get_domain() {
  local service_key=$1
  echo "${IP_SERVICES[$service_key]}"
}

get_random_identity_service() {
  local services=("${IDENTITY_SERVICES[@]}")
  echo "${services[RANDOM % ${#services[@]}]}"
}

get_external_ip() {
  # TODO: Add IPv6 support
  external_ip=$(curl -qs "$(get_random_identity_service)" 2>/dev/null)
  hidden_ip="$(printf "%s" "$external_ip" | cut -d'.' -f1-2).***.***"
}

# check_service() {
# }

main() {
  get_external_ip "-4"
  echo "External IP: $hidden_ip"
}

main
