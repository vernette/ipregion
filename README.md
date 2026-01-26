# ipregion

[![Deploy to FTPS](https://github.com/vladon/ipregion/actions/workflows/deploy.yml/badge.svg)](https://github.com/vladon/ipregion/actions/workflows/deploy.yml)

## Usage

### Download and run locally

```bash
wget -O ipregion.sh https://ipregion.vladon.sh
chmod +x ipregion.sh
```

### Run directly from GitHub

```bash
bash <(wget -qO- https://ipregion.vladon.sh)
```

## Features

- Multiple GeoIP APIs and web services (YouTube, Google, etc.)
- IPv4/IPv6 support with SOCKS5 proxy and custom network interface
- JSON output and color-coded tables
- Parallel checks by default (auto-detected)

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
./ipregion.sh --parallel 6 # Run checks in parallel
```

> [!NOTE]
> Debug mode writes a local log file and may include sensitive data. If you choose to upload it, the script uses a redacted copy, but review the file before sharing.

All options can be combined.

## Country codes

The script outputs country codes in ISO 3166-1 alpha-2 format (e.g., RU, US, DE).

You can look up the meaning of any country code at the official ISO website: [https://www.iso.org/obp/ui/#search/code/](https://www.iso.org/obp/ui/#search/code/)

Just enter the code in the search box to get the full country name.

## Contributing

Contributions are welcome! Feel free to submit pull requests to add new services or improve the script’s functionality.

## Original repository

Based on the original repository, with high-quality improvements:
- Parallel checks by default with auto-detected worker count
- Safer legacy fallback for parallel waiting on older bash
- Clear startup status messages and dependency-check notice

Original: https://github.com/vernette/ipregion

![Star History Chart](https://api.star-history.com/svg?repos=vladon/ipregion&type=Date)
