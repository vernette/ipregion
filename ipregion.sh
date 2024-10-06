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

ripe_rdap_lookup() {
  ip="$1"
  curl -s https://rdap.db.ripe.net/ip/"$ip" | jq ".country"
}

ipinfo_io_lookup() {
  ip="$1"
  curl -s https://ipinfo.io/widget/demo/"$ip" | jq ".data.country"
}

ipregistry_co_lookup() {
  ip="$1"
  # TODO: Add automatic API key parsing
  api_key="sb69ksjcajfs4c"
  curl -s "https://api.ipregistry.co/$ip?hostname=true&key=$api_key" -H "Origin: https://ipregistry.co" | jq ".location.country.code"
}

ipapi_com_lookup() {
  ip="$1"
  curl -s "https://ipapi.com/ip_api.php?ip=$ip" | jq ".country_code"
}

db_ip_com_lookup() {
  ip="$1"
  curl -s "https://db-ip.com/demo/home.php?s=$ip" | jq ".demoInfo.countryCode"
}

ripe_rdap_lookup "$1"
ipinfo_io_lookup "$1"
ipregistry_co_lookup "$1"
ipapi_com_lookup "$1"
db_ip_com_lookup "$1"
