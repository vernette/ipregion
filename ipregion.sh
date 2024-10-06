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

ripe_rdap_lookup "$1"
