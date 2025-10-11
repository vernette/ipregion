# ipregion

[![asciicast](https://asciinema.org/a/i92ClDWxWOFRlkIglRwAP43rI.svg)](https://asciinema.org/a/i92ClDWxWOFRlkIglRwAP43rI)

## Usage

Download and run locally:

```bash
wget -O ipregion.sh https://ipregion.vrnt.xyz
chmod +x ipregion.sh
```

Or run directly from GitHub:

```bash
bash <(wget -qO- https://ipregion.vrnt.xyz)
```
## Features

- Multiple GeoIP APIs and web services (YouTube, Netflix, ChatGPT, Spotify, etc.)
- IPv4/IPv6 support with SOCKS5 proxy and custom network interface
- JSON output and color-coded tables

## Dependencies

- bash
- curl
- jq
- util-linux/bsdmainutils

## Key Options

```bash
./ipregion.sh --help # Show all options
./ipregion.sh --group primary # GeoIP services only
./ipregion.sh --group custom # Popular websites only
./ipregion.sh --ipv4 # IPv4 only
./ipregion.sh --ipv6 # IPv6 only
./ipregion.sh --proxy 127.0.0.1:1080 # Use SOCKS5 proxy
./ipregion.sh --json # JSON output
./ipregion.sh --debug # Debug mode
```

All options can be combined.

## Country codes

The script outputs country codes in ISO 3166-1 alpha-2 format (e.g., RU, US, DE).

You can look up the meaning of any country code at the official ISO website: [https://www.iso.org/obp/ui/#search/code/](https://www.iso.org/obp/ui/#search/code/)

Just enter the code in the search box to get the full country name.

## Contributing

Contributions are welcome! Feel free to submit pull requests to add new services or improve the script’s functionality.

![Star History Chart](https://api.star-history.com/svg?repos=vernette/ipregion&type=Date)
