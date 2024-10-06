#!/usr/bin/env bash

# Shell script to check IP contry code from various sources
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

RATE_LIMIT_EXCEEDED_MSG="Rate limit exceeded, try again later"

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
  response=$(curl -s "https://db-ip.com/demo/home.php?s=$ip")
  error_message=$(echo "$response" | jq -r ".demoInfo.error")

  if [ -n "$error_message" ]; then
    echo "$RATE_LIMIT_EXCEEDED_MSG"
  else
    echo "$response" | jq -r ".demoInfo.countryCode"
  fi
}

ipdata_co_lookup() {
  ip="$1"
  html=$(curl -s "https://ipdata.co")
  api_key=$(echo "$html" | grep -oP '(?<=api-key=)[a-zA-Z0-9]+')
  response=$(curl -s -H "Referer: https://ipdata.co" "https://api.ipdata.co/$ip?api-key=$api_key")
  error_message=$(echo "$response" | jq -r ".message")

  if [ -n "$error_message" ]; then
    echo "$RATE_LIMIT_EXCEEDED_MSG"
  else
    echo "$response" | jq -r ".country_code"
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
  curl -s "https://whoer.net/whois?host=$ip" | grep "country" | awk 'NR==1 {print $2}'
}

ipquery_io_lookup() {
  ip="$1"
  curl -s "https://api.ipquery.io/$ip" | jq -r ".location.country_code"
}

country_is_lookup() {
  ip="$1"
  curl -s "https://api.country.is/$ip" | jq -r ".country"
}

cleantalk_org_lookup() {
  ip="$1"
  curl -s "https://api.cleantalk.org/?method_name=ip_info&ip=$ip" | jq -r --arg ip "$ip" '.data[$ip | tostring].country_code'
}

ip_api_com_lookup() {
  ip="$1"
  curl -s "https://demo.ip-api.com/json/$ip" -H "Origin: https://ip-api.com" | jq -r ".countryCode"
}

ipgeolocation_io_lookup() {
  ip="$1"
  curl -s "https://api.ipgeolocation.io/ipgeo?ip=$ip" -H "Referer: https://ipgeolocation.io" | jq -r ".country_code2"
}

ip="$1"

echo "RIPE: $(ripe_rdap_lookup "$ip")"
echo "IPInfo: $(ipinfo_io_lookup "$ip")"
echo "IPRegistry: $(ipregistry_co_lookup "$ip")"
echo "IPAPI: $(ipapi_com_lookup "$ip")"
echo "DB-IP: $(db_ip_com_lookup "$ip")"
echo "IPData: $(ipdata_co_lookup "$ip")"
echo "IPWhois: $(ipwhois_io_lookup "$ip")"
echo "Ifconfig: $(ifconfig_co_lookup "$ip")"
echo "Whoer: $(whoer_net_lookup "$ip")"
echo "IPQuery: $(ipquery_io_lookup "$ip")"
echo "Country.Is: $(country_is_lookup "$ip")"
echo "CleanTalk: $(cleantalk_org_lookup "$ip")"
echo "IP-API: $(ip_api_com_lookup "$ip")"
echo "IPGeolocation: $(ipgeolocation_io_lookup "$ip")"
