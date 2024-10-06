#!/usr/bin/env bash

# Shell script to check IP contry code from various sources
# curl and jq are required to run this script
# 
# Currently supported sources:
#   - https://rdap.db.ripe.net
#   - https://ipinfo.io
#   - https://ipregistry.co
#   - https://ipapi.com
#   - https://db-ip.com
#   - https://ipdata.co
#   - https://ipwhois.io
#   - https://ifconfig.co
#   - https://whoer.net

ripe_rdap_lookup() {
  ip="$1"
  curl -s https://rdap.db.ripe.net/ip/"$ip" | jq -r ".country"
}

ipinfo_io_lookup() {
  ip="$1"
  curl -s https://ipinfo.io/widget/demo/"$ip" | jq -r ".data.country"
}

ipregistry_co_lookup() {
  ip="$1"
  # TODO: Add automatic API key parsing
  api_key="sb69ksjcajfs4c"
  curl -s "https://api.ipregistry.co/$ip?hostname=true&key=$api_key" -H "Origin: https://ipregistry.co" | jq -r ".location.country.code"
}

ipapi_com_lookup() {
  ip="$1"
  curl -s "https://ipapi.com/ip_api.php?ip=$ip" | jq -r ".country_code"
}

db_ip_com_lookup() {
  ip="$1"
  # TODO: Add success check
  curl -s "https://db-ip.com/demo/home.php?s=$ip" | jq -r ".demoInfo.countryCode"
}

ipdata_co_lookup() {
  ip="$1"
  html=$(curl -s "https://ipdata.co")
  api_key=$(echo "$html" | grep -oP '(?<=api-key=)[a-zA-Z0-9]+')
  response=$(curl -s -H "Referer: https://ipdata.co" "https://api.ipdata.co/$ip?api-key=$api_key")
  error_message=$(echo "$response" | jq -r ".message")

  if [ "$error_message" = "IP or domain not in whitelist." ]; then
    echo "Rate limit exceeded"
  else
    echo "$response" | jq -r ".country.code"
  fi
}

ipwhois_io_lookup() {
  ip="$1"
  curl -s -H "Referer: https://ipwhois.io" "https://ipwhois.io/widget?ip=$ip&lang=en" | jq -r ".country_code"
}

ifconfig_co_lookup() {
  ip="$1"
  curl -s "https://ifconfig.co/country-iso?ip=$ip"
}

whoer_net_lookup() {
  ip="$1"
  curl -s "https://whoer.net/whois?host=$ip" | grep "country" | awk '{print $2}'
}

ripe_rdap_lookup "$1"
ipinfo_io_lookup "$1"
ipregistry_co_lookup "$1"
ipapi_com_lookup "$1"
db_ip_com_lookup "$1"
ipdata_co_lookup "$1"
ipwhois_io_lookup "$1"
ifconfig_co_lookup "$1"
whoer_net_lookup "$1"
