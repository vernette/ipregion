#!/usr/bin/env bash

# Shell script to check IP country code from various sources
# curl and jq are required to run this script

# Currently supported sources:
#   https://rdap.db.ripe.net
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

RIPE_DOMAIN="rdap.db.ripe.net"
IPINFO_DOMAIN="ipinfo.io"
IPREGISTRY_DOMAIN="ipregistry.co"
IPAPI_DOMAIN="ipapi.com"
DB_IP_DOMAIN="db-ip.com"
IPDATA_DOMAIN="ipdata.co"
IPWHOIS_DOMAIN="ipwhois.io"
IFCONFIG_DOMAIN="ifconfig.co"
WHOER_DOMAIN="whoer.net"
IPQUERY_DOMAIN="ipquery.io"
COUNTRY_IS_DOMAIN="country.is"
CLEANTALK_DOMAIN="cleantalk.org"
IP_API_DOMAIN="ip-api.com"
IPGEOLOCATION_DOMAIN="ipgeolocation.io"
IPAPI_CO_DOMAIN="ipapi.co"
FINDIP_DOMAIN="findip.net"
GEOJS_DOMAIN="geojs.io"
IPLOCATION_DOMAIN="iplocation.com"
GEOAPIFY_DOMAIN="geoapify.com"
IPAPI_IS_DOMAIN="ipapi.is"
FREEIPAPI_DOMAIN="freeipapi.com"
IPBASE_DOMAIN="ipbase.com"
IP_SB_DOMAIN="ip.sb"

INDENTITY_SERVICES="https://ident.me https://ifconfig.co https://ifconfig.me https://icanhazip.com https://api64.ipify.org"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"

check_service() {
  local domain="$1"
  local lookup_function="$2"

  echo "Checking $domain"
  result="$($lookup_function)"
  results+=("$domain: $result")
}

get_random_identity_service() {
  echo "$INDENTITY_SERVICES" | tr ' ' '\n' | shuf -n 1
}

get_ipv4() {
  external_ip=$(curl -qs $(get_random_identity_service) 2>/dev/null)
}

ripe_rdap_lookup() {
  curl -s https://rdap.db.ripe.net/ip/"$external_ip" | jq -r ".country"
}

ipinfo_io_lookup() {
  curl -s https://ipinfo.io/widget/demo/"$external_ip" | jq -r ".data.country"
}

ipregistry_co_lookup() {
  # TODO: Add automatic API key parsing
  api_key="sb69ksjcajfs4c"
  curl -s "https://api.ipregistry.co/$external_ip?hostname=true&key=$api_key" -H "Origin: https://ipregistry.co" | jq -r ".location.country.code"
}

ipapi_com_lookup() {
  curl -s "https://ipapi.com/ip_api.php?ip=$external_ip" | jq -r ".country_code"
}

db_ip_com_lookup() {
  # TODO: Add automatic API key parsing
  # NOTE: Sometimes returns wrong country code
  api_key="p31e4d59ee6ad1a0b5cc80695a873e43a8fbca06"
  curl -s "https://api.db-ip.com/v2/$api_key/self" -H "Origin: https://db-ip.com" | jq -r ".countryCode"
}

ipdata_co_lookup() {
  html=$(curl -s "https://ipdata.co")
  api_key=$(echo "$html" | grep -oP '(?<=api-key=)[a-zA-Z0-9]+')
  curl -s -H "Referer: https://ipdata.co" "https://api.ipdata.co/?api-key=$api_key" | jq -r ".country_code"
}

ipwhois_io_lookup() {
  curl -s -H "Referer: https://ipwhois.io" "https://ipwhois.io/widget?ip=$external_ip&lang=en" | jq -r ".country_code"
}

ifconfig_co_lookup() {
  curl -s "https://ifconfig.co/country-iso?ip=$external_ip"
}

whoer_net_lookup() {
  curl -s "https://whoer.net/whois?host=$external_ip" | grep "country" | awk 'NR==1 {print $2}'
}

ipquery_io_lookup() {
  curl -s "https://api.ipquery.io/$external_ip" | jq -r ".location.country_code"
}

country_is_lookup() {
  curl -s "https://api.country.is/$external_ip" | jq -r ".country"
}

cleantalk_org_lookup() {
  curl -s "https://api.cleantalk.org/?method_name=ip_info&ip=$external_ip" | jq -r --arg ip "$external_ip" '.data[$ip | tostring].country_code'
}

ip_api_com_lookup() {
  curl -s "https://demo.ip-api.com/json/$external_ip" -H "Origin: https://ip-api.com" | jq -r ".countryCode"
}

ipgeolocation_io_lookup() {
  curl -s "https://api.ipgeolocation.io/ipgeo?ip=$external_ip" -H "Referer: https://ipgeolocation.io" | jq -r ".country_code2"
}

ipapi_co_lookup() {
  curl -s "https://ipapi.co/$external_ip/json" | jq -r ".country"
}

findip_net_lookup() {
  cookie_file=$(mktemp)
  html=$(curl -s -c "$cookie_file" "https://findip.net")
  request_verification_token=$(echo "$html" | grep "__RequestVerificationToken" | grep -oP 'value="\K[^"]+')
  response=$(curl -s -X POST "https://findip.net" \
    --data-urlencode "__RequestVerificationToken=$request_verification_token" \
    --data-urlencode "ip=$external_ip" \
    -b "$cookie_file")
  rm "$cookie_file"
  echo "$response" | grep -oP 'ISO Code: <span class="text-success">\K[^<]+'
}

geojs_io_lookup() {
  curl -s "https://get.geojs.io/v1/ip/country.json?ip=$external_ip" | jq -r ".[0].country"
}

iplocation_com_lookup() {
  curl -s -X POST "https://iplocation.com" -A "$USER_AGENT" --form "ip=$external_ip" | jq -r ".country_code"
}

geoapify_com_lookup() {
  # TODO: Add automatic API key parsing
  api_key="b8568cb9afc64fad861a69edbddb2658"
  curl -s "https://api.geoapify.com/v1/ipinfo?&ip=$external_ip&apiKey=$api_key" | jq -r ".country.iso_code"
}

ipapi_is_lookup() {
  curl -s "https://api.ipapi.is/?q=$external_ip" | jq -r ".location.country_code"
}

freeipapi_com_lookup() {
  curl -s "https://freeipapi.com/api/json/$external_ip" | jq -r ".countryCode"
}

ipbase_com_lookup() {
  curl -s "https://api.ipbase.com/v2/info?ip=$external_ip" | jq -r ".data.location.country.alpha2"
}

ip_sb_lookup() {
  curl -s "https://api.ip.sb/geoip/$external_ip" -A "$USER_AGENT" | jq -r ".country_code"
}

main() {
  declare -a results
  get_ipv4
  check_service "$RIPE_DOMAIN" ripe_rdap_lookup
  check_service "$IPINFO_DOMAIN" ipinfo_io_lookup
  check_service "$IPREGISTRY_DOMAIN" ipregistry_co_lookup
  check_service "$IPAPI_DOMAIN" ipapi_com_lookup
  check_service "$DB_IP_DOMAIN" db_ip_com_lookup
  check_service "$IPDATA_DOMAIN" ipdata_co_lookup
  check_service "$IPWHOIS_DOMAIN" ipwhois_io_lookup
  check_service "$IFCONFIG_DOMAIN" ifconfig_co_lookup
  check_service "$WHOER_DOMAIN" whoer_net_lookup
  check_service "$IPQUERY_DOMAIN" ipquery_io_lookup
  check_service "$COUNTRY_IS_DOMAIN" country_is_lookup
  check_service "$CLEANTALK_DOMAIN" cleantalk_org_lookup
  check_service "$IP_API_DOMAIN" ip_api_com_lookup
  check_service "$IPGEOLOCATION_DOMAIN" ipgeolocation_io_lookup
  check_service "$IPAPI_CO_DOMAIN" ipapi_co_lookup
  check_service "$FINDIP_DOMAIN" findip_net_lookup
  check_service "$GEOJS_DOMAIN" geojs_io_lookup
  check_service "$IPLOCATION_DOMAIN" iplocation_com_lookup
  check_service "$GEOAPIFY_DOMAIN" geoapify_com_lookup
  check_service "$IPAPI_IS_DOMAIN" ipapi_is_lookup
  check_service "$FREEIPAPI_DOMAIN" freeipapi_com_lookup
  check_service "$IPBASE_DOMAIN" ipbase_com_lookup
  check_service "$IP_SB_DOMAIN" ip_sb_lookup
  printf "\nResults:\n"
  printf "%s\n" "${results[@]}" | column -s ":" -t
}

main
