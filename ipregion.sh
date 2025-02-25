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
#   https://maxmind.com
#   https://cloudflare.com
#   https://youtube.com
#   https://ipbase.com
#   https://apple.com
#   https://netflix.com
#   https://store.steampowered.com
#   https://spotify.com

DEPENDENCIES="jq curl"

SOCKS_PORT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --socks|--socks-port|-s)
      SOCKS_PORT="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -n "$SOCKS_PORT" ]; then
  # Устанавливаем прокси для всех запросов curl
  export ALL_PROXY="socks5://127.0.0.1:$SOCKS_PORT"
  echo "Using SOCKS 127.0.0.1:$SOCKS_PORT"
fi



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
MAXMIND_COM_DOMAIN="maxmind.com"
CLOUDFLARE_DOMAIN="cloudflare.com"
YOUTUBE_DOMAIN="youtube.com"
IPWHODE4_DOMAIN="4.ipwho.de"
CHATGPT="chatgpt.com"
APPLE_DOMAIN="apple.com"
NETFLIX_DOMAIN="netflix.com"
STEAM_DOMAIN="store.steampowered.com"
SPOTIFY_DOMAIN="spotify.com"

IDENTITY_SERVICES="https://ident.me https://ifconfig.me https://api64.ipify.org https://4.ipwho.de/ip"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"

COLOR_BOLD_GREEN="\033[1;32;40m"
COLOR_BOLD_CYAN="\033[1;36;40m"
COLOR_BOLD_ORANGE="\033[38;5;214;40m"
COLOR_BOLD_RED="\033[38;5;196;40m"
COLOR_BOLD_GRAY="\033[38;5;238;40m"
COLOR_BOLD_WHITE="\033[38;5;15;40m"
COLOR_RESET="\033[0m"


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

is_installed() {
  command -v "$1" >/dev/null 2>&1
}

install_dependencies() {
  local use_sudo=""
  local missing_packages=()

  if [ "$(id -u)" -ne 0 ]; then
    use_sudo="sudo"
  fi

  for pkg in $DEPENDENCIES; do
    if ! is_installed "$pkg"; then
      missing_packages+=("$pkg")
    fi
  done

  if [ ${#missing_packages[@]} -eq 0 ]; then
    return 0
  fi

  log_message "INFO" "Missing dependencies: ${missing_packages[*]}. Do you want to install them?"
  select option in "Yes" "No"; do
    case "$option" in
      "Yes")
        log_message "INFO" "Installing missing dependencies"
        break
        ;;
      "No")
        log_message "INFO" "Exiting script"
        exit 0
        ;;
    esac
  done </dev/tty

  # Check if the script is running in Termux
  if [ -d /data/data/com.termux ]; then
    log_message "INFO" "Detected Termux environment"
    apt update
    apt install -y "${missing_packages[@]}"
    clear_screen
    return
  fi

  if [ -f /etc/os-release ]; then
    . /etc/os-release

    case "$ID" in
      debian | ubuntu)
        $use_sudo apt update
        NEEDRESTART_MODE=a $use_sudo apt install -y "${missing_packages[@]}"
        ;;
      arch)
        $use_sudo pacman -Syy --noconfirm "${missing_packages[@]}"
        ;;
      fedora)
        $use_sudo dnf install -y "${missing_packages[@]}"
        ;;
      *)
        log_message "" "Unknown or unsupported distribution: $ID"
        exit 1
        ;;
    esac

    clear_screen
  else
    log_message "" "File /etc/os-release not found, unable to determine distribution"
    exit 1
  fi
}

get_random_identity_service() {
  printf "%s" "$IDENTITY_SERVICES" | tr ' ' '\n' | shuf -n 1
}

get_ipv4() {
  external_ip=$(curl -4 -qs "$(get_random_identity_service)" 2>/dev/null)
  hidden_ip="$(printf "%s" "$external_ip" | cut -d'.' -f1-2).***.***"
}

get_ipv6() {
  external_ipv6=$(curl -6 -s https://6.ipwho.de/ip)
  hidden_ipv6=$(mask_ipv6 "$external_ipv6")
}

mask_ipv6() {
    local ipv6="$1"
    
    IFS=":" read -ra segments <<< "$ipv6"
    for i in "${!segments[@]}"; do
        if (( i > 1 && i < ${#segments[@]} - 2 )); then
            segments[i]="****"
        fi
    done

    echo "${segments[*]}" | sed 's/ /:/g'
}

check_service() {
  local domain="$1"
  local lookup_function="$2"  
  local lookup_function_v6="${3:-null}"  # По умолчанию null, если аргумент не передан

  printf "\r\033[KChecking: %s" "[$domain]"
  result="$($lookup_function)"

  # Обработка результата в зависимости от домена
    if [[ -n "$result" ]]; then
      domain_str="$COLOR_BOLD_GREEN$domain$COLOR_RESET${COLOR_RESET}"


    # Рассчитываем, сколько пробелов нужно добавить, чтобы длина строки была 29
    padding_length=$((29 - ${#domain} - ${#result} - 2))  # 2 — это для ": " между domain и result
    padding=$(printf '%*s' "$padding_length" | tr ' ' '.')
    padding="${COLOR_BOLD_GRAY}${padding}${COLOR_RESET}"
  
    result="${COLOR_BOLD_WHITE}${result}${COLOR_RESET}"
  
    if [[ "$lookup_function_v6" == "null" || "$lookup_function_v6" == "" ]]; then
      results+=("$domain_str$padding$result")
	else
      result_v6="$($lookup_function_v6)"
      if [[ "$result_v6" == "null" || "$result_v6" == "" ]]; then
          results+=("$domain_str$padding$result")
      else
          results+=("$domain_str$padding$result${COLOR_BOLD_GRAY}........${COLOR_RESET}${COLOR_BOLD_WHITE}$result_v6${COLOR_RESET}")
      fi
	fi
	
  fi
}

print_results() {
  
if IPV6_ADDR=$(ip -o -6 addr show scope global | awk '{split($4, a, "/"); print a[1]; exit}'); [ -n "$IPV6_ADDR" ]; then
    printf "\n\n%bResults for IP %b%s %s %s%b\n\n" \
        "${COLOR_BOLD_GREEN}" "${COLOR_BOLD_CYAN}" "$hidden_ip" "and" "$hidden_ipv6" "${COLOR_RESET}"
    printf "                        IPv4      IPv6\n\n"
else
    printf "\n\n%bResults for IP %b%s%b\n\n" \
        "${COLOR_BOLD_GREEN}" "${COLOR_BOLD_CYAN}" "$hidden_ip" "${COLOR_RESET}"
    printf "                        IPv4\n\n"
fi
  for result in "${results[@]}"; do
    printf "%b\n" "$result"
  done
  printf "\n"
}

ripe_rdap_lookup() {
  result=$(timeout 3 curl -4 -s https://rdap.db.ripe.net/ip/"$external_ip" | jq -r ".country" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ripe_rdap_lookup_v6() {
  result=$(timeout 3 curl -4 -s https://rdap.db.ripe.net/ip/"$external_ipv6" | jq -r ".country" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipinfo_io_lookup() {
  result=$(timeout 3 curl -4 -s https://ipinfo.io/widget/demo/"$external_ip" | jq -r ".data.country" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipinfo_io_lookup_v6() {
  sleep 2
  result=$(timeout 3 curl -4 -s https://ipinfo.io/widget/demo/""$external_ipv6"" | jq -r ".data.country" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}


ipregistry_co_lookup() {
  # TODO: Add automatic API key parsing
  api_key="sb69ksjcajfs4c"
  result=$(timeout 3 curl -4 -s "https://api.ipregistry.co/$external_ip?hostname=true&key=$api_key" -H "Origin: https://ipregistry.co" | jq -r ".location.country.code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipregistry_co_lookup_v6() {
  # TODO: Add automatic API key parsing
  api_key="sb69ksjcajfs4c"
  result=$(timeout 3 curl -4 -s "https://api.ipregistry.co/$external_ipv6?hostname=true&key=$api_key" -H "Origin: https://ipregistry.co" | jq -r ".location.country.code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

cloudflare_lookup() {
  result=$(timeout 3 curl -4 -s "https://www.cloudflare.com/cdn-cgi/trace" | grep loc | cut -d= -f2)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

cloudflare_lookup_v6() {
  result=$(timeout 3 curl -6 -s "https://www.cloudflare.com/cdn-cgi/trace" | grep loc | cut -d= -f2)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

spotify_lookup() {
  result=$(curl -4 -s 'https://spclient.wg.spotify.com/signup/public/v1/account' -d "birth_day=11&birth_month=11&birth_year=2000&collect_personal_info=undefined&creation_flow=&creation_point=https%3A%2F%2Fwww.spotify.com%2Fhk-en%2F&displayname=Gay%20Lord&gender=male&iagree=1&key=a1e486e2729f46d6bb368d6b2bcda326&platform=www&referrer=&send-email=0&thirdpartyemail=0&identifier_token=AgE6YTvEzkReHNfJpO114514" -X POST -H "Accept-Language: en" --user-agent "${USER_AGENT}" | jq -r ".country")
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

spotify_lookup_v6() {
  result=$(curl -6 -s 'https://spclient.wg.spotify.com/signup/public/v1/account' -d "birth_day=11&birth_month=11&birth_year=2000&collect_personal_info=undefined&creation_flow=&creation_point=https%3A%2F%2Fwww.spotify.com%2Fhk-en%2F&displayname=Gay%20Lord&gender=male&iagree=1&key=a1e486e2729f46d6bb368d6b2bcda326&platform=www&referrer=&send-email=0&thirdpartyemail=0&identifier_token=AgE6YTvEzkReHNfJpO114514" -X POST -H "Accept-Language: en" --user-agent "${USER_AGENT}" | jq -r ".country")
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}


steam_lookup() {
  result=$(timeout 3 curl -4 -s "https://store.steampowered.com/" | grep -o '"countrycode":"[^"]*"' | sed -E 's/.*:"([^"]*)"/\1/')
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

steam_lookup_v6() {
  result=$(timeout 3 curl -6 -s "https://store.steampowered.com/" | grep -o '"countrycode":"[^"]*"' | sed -E 's/.*:"([^"]*)"/\1/')
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

get_country_code() {
    local country="$1"
    curl --max-time 5 -s "https://restcountries.com/v3.1/all" | jq -r --arg COUNTRY "$country" '.[] | select(.name.common == $COUNTRY) | .cca2'
}

youtube_lookup() {
  result=$(timeout 3 curl -4 -sL 'https://play.google.com/'   -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'   -H 'accept-language: en-US;q=0.9'   -H 'priority: u=0, i'   -H 'sec-ch-ua: "Chromium";v="131", "Not_A Brand";v="24", "Google Chrome";v="131"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-platform: "Windows"'   -H 'sec-fetch-dest: document'   -H 'sec-fetch-mode: navigate'   -H 'sec-fetch-site: none'   -H 'sec-fetch-user: ?1'   -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36' | grep -oP '<div class="yVZQTb">\K[^<(]+')
  result=$(echo "$result" | xargs)
  result=$(get_country_code "$result")

  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

youtube_lookup_v6() {
  result=$(timeout 3 curl -6 -sL 'https://play.google.com/'   -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7'   -H 'accept-language: en-US;q=0.9'   -H 'priority: u=0, i'   -H 'sec-ch-ua: "Chromium";v="131", "Not_A Brand";v="24", "Google Chrome";v="131"'   -H 'sec-ch-ua-mobile: ?0'   -H 'sec-ch-ua-platform: "Windows"'   -H 'sec-fetch-dest: document'   -H 'sec-fetch-mode: navigate'   -H 'sec-fetch-site: none'   -H 'sec-fetch-user: ?1'   -H 'upgrade-insecure-requests: 1' -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36' | grep -oP '<div class="yVZQTb">\K[^<(]+')
  result=$(echo "$result" | xargs)
  result=$(get_country_code "$result")
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

netflix_lookup() {
	# LEGO Ninjago
	local result1=$(timeout 3 curl -4 -fsL 'https://www.netflix.com/title/81280792' -w %{http_code} -o /dev/null -H 'host: www.netflix.com' -H 'accept-language: en-US,en;q=0.9' -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-site: none' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-user: ?1' -H 'sec-fetch-dest: document' --user-agent "${USER_AGENT}")
	# Breaking bad
	local result2=$(timeout 3 curl -4 -fsL 'https://www.netflix.com/title/70143836' -w %{http_code} -o /dev/null -H 'host: www.netflix.com' -H 'accept-language: en-US,en;q=0.9' -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-site: none' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-user: ?1' -H 'sec-fetch-dest: document' --user-agent "${USER_AGENT}")

	if [ "$result1" == '200' ] || [ "$result2" == '200' ]; then
        local tmpresult=$(timeout 3 curl -4 -sL 'https://www.netflix.com/' -H 'accept-language: en-US,en;q=0.9' -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-site: none' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-user: ?1' -H 'sec-fetch-dest: document' --user-agent "${USER_AGENT}")
        result=$(echo "$tmpresult" | grep -oP '"id":"\K[^"]+' | grep -E '^[A-Z]{2}$' | head -n 1)
    else 
	  echo ""
	fi
	
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

netflix_lookup_v6() {
	# LEGO Ninjago
	local result1=$(timeout 3 curl -6 -fsL 'https://www.netflix.com/title/81280792' -w %{http_code} -o /dev/null -H 'host: www.netflix.com' -H 'accept-language: en-US,en;q=0.9' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-site: none' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-user: ?1' -H 'sec-fetch-dest: document' --user-agent "${USER_AGENT}")
	# Breaking bad
	local result2=$(timeout 3 curl -6 -fsL 'https://www.netflix.com/title/70143836' -w %{http_code} -o /dev/null -H 'host: www.netflix.com' -H 'accept-language: en-US,en;q=0.9' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-site: none' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-user: ?1' -H 'sec-fetch-dest: document' --user-agent "${USER_AGENT}")

	if [ "$result1" == '200' ] || [ "$result2" == '200' ]; then
        local tmpresult=$(timeout 3 curl -6 -sL 'https://www.netflix.com/' -H 'accept-language: en-US,en;q=0.9' -H "sec-ch-ua: ${UA_SEC_CH_UA}" -H 'sec-ch-ua-mobile: ?0' -H 'sec-ch-ua-platform: "Windows"' -H 'sec-fetch-site: none' -H 'sec-fetch-mode: navigate' -H 'sec-fetch-user: ?1' -H 'sec-fetch-dest: document' --user-agent "${USER_AGENT}")
        result=$(echo "$tmpresult" | grep -oP '"id":"\K[^"]+' | grep -E '^[A-Z]{2}$' | head -n 1)
    else 
	  echo ""
	fi
	
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

apple_lookup() {
  result=$(timeout 3 curl -4 -sL 'https://gspe1-ssl.ls.apple.com/pep/gcc')
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

apple_lookup_v6() {
  result=$(timeout 3 curl -6 -sL 'https://gspe1-ssl.ls.apple.com/pep/gcc')
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipapi_com_lookup() {
  result=$(timeout 3 curl -4 -s "https://ipapi.com/ip_api.php?ip=$external_ip" | jq -r ".country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipapi_com_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://ipapi.com/ip_api.php?ip=$external_ipv6" | jq -r ".country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

db_ip_com_lookup() {
  result=$(timeout 3 curl -4 -s "https://db-ip.com/demo/home.php?s=$external_ip" | jq -r ".demoInfo.countryCode" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

db_ip_com_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://db-ip.com/demo/home.php?s=$external_ipv6" | jq -r ".demoInfo.countryCode" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipdata_co_lookup() {
  html=$(timeout 3 curl -4 -s "https://ipdata.co")
  api_key=$(printf "%s" "$html" | grep -oP '(?<=api-key=)[a-zA-Z0-9]+')
  result=$(timeout 3 curl -4 -s -H "Referer: https://ipdata.co" "https://api.ipdata.co/?api-key=$api_key" | jq -r ".country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipdata_co_lookup_v6() {
  html=$(timeout 3 curl -6 -s "https://ipdata.co")
  api_key=$(printf "%s" "$html" | grep -oP '(?<=api-key=)[a-zA-Z0-9]+')
  result=$(timeout 3 curl -6 -s -H "Referer: https://ipdata.co" "https://api.ipdata.co/?api-key=$api_key" | jq -r ".country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipwhois_io_lookup() {
	result=$(timeout 3 curl -4 -s -H "Referer: https://ipwhois.io" "https://ipwhois.io/widget?ip=$external_ip&lang=en" | jq -r ".country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipwhois_io_lookup_v6() {
	result=$(timeout 3 curl -4 -s -H "Referer: https://ipwhois.io" "https://ipwhois.io/widget?ip=$external_ipv6&lang=en" | jq -r ".country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ifconfig_co_lookup() {
  result=$(timeout 3 curl -4 -s "https://ifconfig.co/country-iso?ip=$external_ip")
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ifconfig_co_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://ifconfig.co/country-iso?ip=$external_ipv6")
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

whoer_net_lookup() { 
  result=$(timeout 3 curl -4 -s "https://whoer.net/whois?host=$external_ip" | grep "country" | awk 'NR==1 {print $2}')
	if [ $? -eq 124 ]; then
		echo ""
	elif [ "$result" == "null" ] || [ "$result" == "ZZ" ]; then
		echo ""
	elif [ ${#result} -gt 7 ]; then
		echo ""
	else
		echo "$result"
	fi
}

whoer_net_lookup_v6() { 
  result=$(timeout 3 curl -4 -s "https://whoer.net/whois?host=$external_ipv6" | grep "country" | awk 'NR==1 {print $2}')
  	if [ $? -eq 124 ]; then
		echo ""
	elif [ "$result" == "null" ] || [ "$result" == "ZZ" ]; then
		echo ""
	elif [ ${#result} -gt 7 ]; then
		echo ""
	else
		echo "$result"
	fi
}

ipquery_io_lookup() {
  result=$(timeout 3 curl -4 -s "https://api.ipquery.io/$external_ip" | jq -r ".location.country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipquery_io_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://api.ipquery.io/$external_ipv6" | jq -r ".location.country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

country_is_lookup() {
  result=$(timeout 3 curl -4 -s "https://api.country.is/$external_ip" | jq -r ".country" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

country_is_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://api.country.is/$external_ipv6" | jq -r ".country" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

cleantalk_org_lookup() {
  result=$(timeout 3 curl -4 -s "https://api.cleantalk.org/?method_name=ip_info&ip=$external_ip" | jq -r --arg ip "$external_ip" '.data[$ip | tostring].country_code' 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

cleantalk_org_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://api.cleantalk.org/?method_name=ip_info&ip=$external_ipv6" | jq -r --arg ip "$external_ip" '.data[$ip | tostring].country_code' 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ip_api_com_lookup() {
  result=$(timeout 3 curl -4 -s "https://demo.ip-api.com/json/$external_ip" -H "Origin: https://ip-api.com" | jq -r ".countryCode" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ip_api_com_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://demo.ip-api.com/json/$external_ipv6" -H "Origin: https://ip-api.com" | jq -r ".countryCode" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipgeolocation_io_lookup() {
  result=$(timeout 3 curl -4 -s "https://api.ipgeolocation.io/ipgeo?ip=$external_ip" -H "Referer: https://ipgeolocation.io" | jq -r ".country_code2" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipapi_co_lookup() {
  result=$(timeout 3 curl -4 -s "https://ipapi.co/$external_ip/json" | jq -r ".country" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipapi_co_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://ipapi.co/$external_ipv6/json" | jq -r ".country" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

findip_net_lookup() {
  cookie_file=$(mktemp)
  html=$(curl -s -c "$cookie_file" "https://findip.net")
  request_verification_token=$(printf "%s" "$html" | grep "__RequestVerificationToken" | grep -oP 'value="\K[^"]+')
  response=$(timeout 3 curl -s -X POST "https://findip.net" \
    --data-urlencode "__RequestVerificationToken=$request_verification_token" \
    --data-urlencode "ip=$external_ip" \
    -b "$cookie_file")
  rm "$cookie_file"
      if [ $? -eq 124 ]; then
        echo ""
    else
        printf "%s" "$response" | grep -oP 'ISO Code: <span class="text-success">\K[^<]+'
    fi
}

geojs_io_lookup() { 
  result=$(timeout 3 curl -4 -s "https://get.geojs.io/v1/ip/country.json?ip=$external_ip" | jq -r ".[0].country" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

geojs_io_lookup_v6() { 
  result=$(timeout 3 curl -4 -s "https://get.geojs.io/v1/ip/country.json?ip=$external_ipv6" | jq -r ".[0].country" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

iplocation_com_lookup() {
  result=$(timeout 3 curl -4 -s -X POST "https://iplocation.com" -A "$USER_AGENT" --form "ip=$external_ip" | jq -r ".country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

iplocation_com_lookup_v6() {
  result=$(timeout 3 curl -4 -s -X POST "https://iplocation.com" -A "$USER_AGENT" --form "ip=$external_ipv6" | jq -r ".country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

geoapify_com_lookup() {
  # TODO: Add automatic API key parsing
  api_key="b8568cb9afc64fad861a69edbddb2658"
  result=$(timeout 3 curl -4 -s "https://api.geoapify.com/v1/ipinfo?&ip=$external_ip&apiKey=$api_key" | jq -r ".country.iso_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

geoapify_com_lookup_v6() {
  # TODO: Add automatic API key parsing
  api_key="b8568cb9afc64fad861a69edbddb2658"
  result=$(timeout 3 curl -4 -s "https://api.geoapify.com/v1/ipinfo?&ip=$external_ipv6&apiKey=$api_key" | jq -r ".country.iso_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipapi_is_lookup() {
  result=$(timeout 3 curl -4 -s "https://api.ipapi.is/?q=$external_ip" | jq -r ".location.country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipapi_is_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://api.ipapi.is/?q=$external_ipv6" | jq -r ".location.country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

freeipapi_com_lookup() {
  result=$(timeout 3 curl -4 -s "https://freeipapi.com/api/json/$external_ip" | jq -r ".countryCode" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

freeipapi_com_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://freeipapi.com/api/json/$external_ipv6" | jq -r ".countryCode" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

4_ipwho_de_lookup() {
  result=$(timeout 3 curl -4 -s ipwho.de/json | jq -r '.country_code' 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipbase_com_lookup() {
  result=$(timeout 3 curl -4 -s "https://api.ipbase.com/v2/info?ip=$external_ip" | jq -r ".data.location.country.alpha2" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ipbase_com_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://api.ipbase.com/v2/info?ip=$external_ipv6" | jq -r ".data.location.country.alpha2" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ip_sb_lookup() {
  result=$(timeout 3 curl -4 -s "https://api.ip.sb/geoip/$external_ip" -A "$USER_AGENT" | jq -r ".country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

ip_sb_lookup_v6() {
  result=$(timeout 3 curl -4 -s "https://api.ip.sb/geoip/$external_ipv6" -A "$USER_AGENT" | jq -r ".country_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

maxmind_com_lookup() {
  result=$(timeout 3 curl -4 -s "https://geoip.maxmind.com/geoip/v2.1/city/me" -H "Referer: https://www.maxmind.com" | jq -r ".country.iso_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

maxmind_com_lookup_v6() {
  result=$(timeout 3 curl -6 -s "https://geoip.maxmind.com/geoip/v2.1/city/me" -H "Referer: https://www.maxmind.com" | jq -r ".country.iso_code" 2>/dev/null)
  if [ $? -eq 124 ]; then
      echo ""
  elif [ "$result" == "null" ]; then
      echo ""
  elif [ ${#result} -gt 7 ]; then
      echo ""
  else
      echo "$result"
  fi
}

main() {
  install_dependencies

  declare -a results

  get_ipv4
 
  if IPV6_ADDR=$(ip -o -6 addr show scope global | awk '{split($4, a, "/"); print a[1]; exit}'); [ -n "$IPV6_ADDR" ]; then
    get_ipv6
    check_service "$CLOUDFLARE_DOMAIN" cloudflare_lookup cloudflare_lookup_v6
    check_service "$COUNTRY_IS_DOMAIN" country_is_lookup country_is_lookup_v6
    check_service "$DB_IP_DOMAIN" db_ip_com_lookup db_ip_com_lookup_v6
    check_service "$FREEIPAPI_DOMAIN" freeipapi_com_lookup freeipapi_com_lookup_v6
    check_service "$GEOAPIFY_DOMAIN" geoapify_com_lookup geoapify_com_lookup_v6
    check_service "$GEOJS_DOMAIN" geojs_io_lookup geojs_io_lookup_v6
    check_service "$IFCONFIG_DOMAIN" ifconfig_co_lookup ifconfig_co_lookup_v6
    check_service "$IPAPI_DOMAIN" ipapi_com_lookup ipapi_com_lookup_v6
    check_service "$IPAPI_CO_DOMAIN" ipapi_co_lookup ipapi_co_lookup_v6
    check_service "$IPAPI_IS_DOMAIN" ipapi_is_lookup ipapi_is_lookup_v6
    check_service "$IPBASE_DOMAIN" ipbase_com_lookup ipbase_com_lookup_v6
    check_service "$IPDATA_DOMAIN" ipdata_co_lookup ipdata_co_lookup_v6
    check_service "$IPINFO_DOMAIN" ipinfo_io_lookup ipinfo_io_lookup_v6
    check_service "$IPLOCATION_DOMAIN" iplocation_com_lookup iplocation_com_lookup_v6
    check_service "$IPQUERY_DOMAIN" ipquery_io_lookup ipquery_io_lookup_v6
    check_service "$IPREGISTRY_DOMAIN" ipregistry_co_lookup ipregistry_co_lookup_v6
    check_service "$IPWHOIS_DOMAIN" ipwhois_io_lookup ipwhois_io_lookup_v6
    check_service "$IP_SB_DOMAIN" ip_sb_lookup ip_sb_lookup_v6
    check_service "$MAXMIND_COM_DOMAIN" maxmind_com_lookup maxmind_com_lookup_v6
    check_service "$RIPE_DOMAIN" ripe_rdap_lookup ripe_rdap_lookup_v6
    check_service "$WHOER_DOMAIN" whoer_net_lookup whoer_net_lookup_v6
	check_service "$STEAM_DOMAIN" steam_lookup steam_lookup_v6
	check_service "$APPLE_DOMAIN" apple_lookup apple_lookup_v6
	check_service "$SPOTIFY_DOMAIN" spotify_lookup spotify_lookup_v6
	check_service "$NETFLIX_DOMAIN" netflix_lookup netflix_lookup_v6
    check_service "$YOUTUBE_DOMAIN" youtube_lookup youtube_lookup_v6
else
    check_service "$CLOUDFLARE_DOMAIN" cloudflare_lookup
    check_service "$COUNTRY_IS_DOMAIN" country_is_lookup
    check_service "$DB_IP_DOMAIN" db_ip_com_lookup
    check_service "$FREEIPAPI_DOMAIN" freeipapi_com_lookup
    check_service "$GEOAPIFY_DOMAIN" geoapify_com_lookup
    check_service "$GEOJS_DOMAIN" geojs_io_lookup
    check_service "$IFCONFIG_DOMAIN" ifconfig_co_lookup
    check_service "$IPAPI_DOMAIN" ipapi_com_lookup
    check_service "$IPAPI_CO_DOMAIN" ipapi_co_lookup
    check_service "$IPAPI_IS_DOMAIN" ipapi_is_lookup
    check_service "$IPBASE_DOMAIN" ipbase_com_lookup
    check_service "$IPDATA_DOMAIN" ipdata_co_lookup
    check_service "$IPINFO_DOMAIN" ipinfo_io_lookup
    check_service "$IPLOCATION_DOMAIN" iplocation_com_lookup
    check_service "$IPQUERY_DOMAIN" ipquery_io_lookup
    check_service "$IPREGISTRY_DOMAIN" ipregistry_co_lookup
    check_service "$IPWHOIS_DOMAIN" ipwhois_io_lookup
    check_service "$IP_SB_DOMAIN" ip_sb_lookup
    check_service "$MAXMIND_COM_DOMAIN" maxmind_com_lookup
    check_service "$RIPE_DOMAIN" ripe_rdap_lookup
    check_service "$WHOER_DOMAIN" whoer_net_lookup
	check_service "$STEAM_DOMAIN" steam_lookup
	check_service "$APPLE_DOMAIN" apple_lookup
	check_service "$SPOTIFY_DOMAIN" spotify_lookup
	check_service "$NETFLIX_DOMAIN" netflix_lookup
    check_service "$YOUTUBE_DOMAIN" youtube_lookup
fi

  clear_screen
  clear_screen
  
  print_results
}

main
