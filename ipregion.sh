#!/usr/bin/env bash

# Shell script to check IP contry code from various sources
# curl and jq are required to run this script
# 
# Currently supported sources:
#   - https://rdap.db.ripe.net
#   - https://ipinfo.io
#   - https://ipregistry.co
#   - https://ipapi.com

ripe_rdap_lookup() {
  ip="$1"
  curl -s https://rdap.db.ripe.net/ip/"$ip" | jq ".country"
}

ipinfo_io_lookup() {
  ip="$1"
  curl -s https://ipinfo.io/widget/demo/"$ip" | jq ".data.country"
}

ripe_rdap_lookup "$1"
ipinfo_io_lookup "$1"
