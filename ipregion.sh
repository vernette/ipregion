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
#   https://ipapi.co
#   https://findip.net
#   https://geojs.io
#   https://iplocation.com
#   https://geoapify.com
#   https://ipapi.is

RATE_LIMIT_EXCEEDED_MSG="Rate limit exceeded, try again later"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"

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

ipapi_co_lookup() {
  ip="$1"
  curl -s "https://ipapi.co/$ip/json" | jq -r ".country"
}

findip_net_lookup() {
  ip="$1"
  cookie_file=$(mktemp)
  html=$(curl -s -c "$cookie_file" "https://findip.net")
  request_verification_token=$(echo "$html" | grep "__RequestVerificationToken" | grep -oP 'value="\K[^"]+')
  response=$(curl -s -X POST "https://findip.net" \
    --data-urlencode "__RequestVerificationToken=$request_verification_token" \
    --data-urlencode "ip=$ip" \
    -b "$cookie_file")
  rm "$cookie_file"
  echo "$response" | grep -oP 'ISO Code: <span class="text-success">\K[^<]+'
}

geojs_io_lookup() {
  ip="$1"
  curl -s "https://get.geojs.io/v1/ip/country.json?ip=$ip" | jq -r ".[0].country"
}

iplocation_com_lookup() {
  ip="$1"
  curl -s -X POST "https://iplocation.com" -H "User-Agent: $USER_AGENT" --form "ip=$ip" | jq -r ".country_code"
}

geoapify_com_lookup() {
  ip="$1"
  # TODO: Add automatic API key parsing
  api_key="b8568cb9afc64fad861a69edbddb2658"
  curl -s "https://api.geoapify.com/v1/ipinfo?&ip=$ip&apiKey=$api_key" | jq -r ".country.iso_code"
}

ipapi_is_lookup() {
  ip="$1"
  curl -s "https://api.ipapi.is/?q=$ip" | jq -r ".location.country_code"
}

ip="$1"

echo "RIPE (rdap.db.ripe.net): $(ripe_rdap_lookup "$ip")"
echo "IPInfo (ipinfo.io): $(ipinfo_io_lookup "$ip")"
echo "IPRegistry (ipregistry.co): $(ipregistry_co_lookup "$ip")"
echo "IPAPI (ipapi.com): $(ipapi_com_lookup "$ip")"
echo "DB-IP (db-ip.com): $(db_ip_com_lookup "$ip")"
echo "IPData (ipdata.co): $(ipdata_co_lookup "$ip")"
echo "IPWhois (ipwhois.io): $(ipwhois_io_lookup "$ip")"
echo "Ifconfig (ifconfig.co): $(ifconfig_co_lookup "$ip")"
echo "Whoer (whoer.net): $(whoer_net_lookup "$ip")"
echo "IPQuery (ipquery.io): $(ipquery_io_lookup "$ip")"
echo "Country.Is (country.is): $(country_is_lookup "$ip")"
echo "CleanTalk (cleantalk.org): $(cleantalk_org_lookup "$ip")"
echo "IP-API (ip-api.com): $(ip_api_com_lookup "$ip")"
echo "IPGeolocation (ipgeolocation.io): $(ipgeolocation_io_lookup "$ip")"
echo "IPAPI (ipapi.co): $(ipapi_co_lookup "$ip")"
echo "FindIP (findip.net): $(findip_net_lookup "$ip")"
echo "GeoJS (geojs.io): $(geojs_io_lookup "$ip")"
echo "IPLocation (iplocation.com): $(iplocation_com_lookup "$ip")"
echo "Geoapify (geoapify.com): $(geoapify_com_lookup "$ip")"
echo "IPAPI (ipapi.is): $(ipapi_is_lookup "$ip")"
