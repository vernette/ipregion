# ipregion

A bash script for determining your IP geolocation using various GeoIP services and popular websites.

![image](https://i.imgur.com/FHlXO8a.png)

## Features

- Checks your IP geolocation using multiple public GeoIP APIs
- Results from both "primary" GeoIP services and popular web services (YouTube, Netflix, Twitch, etc.)
- Supports both IPv4 and IPv6 (can test separately)
- SOCKS5 proxy and custom network interface support
- JSON output for automation and integration
- Color-coded, easy-to-read table output

## Dependencies

- bash
- curl
- jq
- util-linux or bsdmainutils (for `column`)

## Usage

For local usage, download the script:

```bash
wget https://github.com/vernette/ipregion/raw/master/ipregion.sh
chmod +x ipregion.sh
```

Or run directly from GitHub:

```bash
bash <(wget -qO- https://github.com/vernette/ipregion/raw/master/ipregion.sh)
```

### Common Use Cases

```bash
# Show help message
./ipregion.sh --help

# Check all services with default settings
./ipregion.sh

# Check only GeoIP services
./ipregion.sh --group primary

# Check only CDN services
./ipregion.sh --group cdn

# Check only popular web services
./ipregion.sh --group custom

# Test only IPv4
./ipregion.sh --ipv4

# Test only IPv6
./ipregion.sh --ipv6

# Use SOCKS5 proxy
./ipregion.sh --proxy 127.0.0.1:1080

# Use a specific network interface
./ipregion.sh --interface eth1

# Set custom curl request timeout in seconds
./ipregion.sh --timeout 20

# Output result as JSON
./ipregion.sh --json

# Enable verbose logging
./ipregion.sh --verbose
```

All options available in the help message (`-h, --help`) can be used and combined.

## Options

```
Usage: ipregion.sh [OPTIONS]

IPRegion — determines your IP geolocation using various GeoIP services and popular websites

Options:
  -h, --help           Show this help message and exit
  -v, --verbose        Enable verbose logging
  -j, --json           Output results in JSON format
  -g, --group GROUP    Run only one group: 'primary', 'custom', 'cdn' or 'all' (default: all)
  -t, --timeout SEC    Set curl request timeout in seconds (default: 10)
  -4, --ipv4           Test only IPv4
  -6, --ipv6           Test only IPv6
  -p, --proxy ADDR     Use SOCKS5 proxy (format: host:port)
  -i, --interface IF   Use specified network interface (e.g. eth1)

Examples:
  ipregion.sh                       # Check all services with default settings
  ipregion.sh -g primary            # Check only GeoIP services
  ipregion.sh -g custom             # Check only popular websites
  ipregion.sh -g cdn                # Check only CDN
  ipregion.sh -4                    # Test only IPv4
  ipregion.sh -6                    # Test only IPv6
  ipregion.sh -p 127.0.0.1:1080     # Use SOCKS5 proxy
  ipregion.sh -i eth1               # Use network interface eth1
  ipregion.sh -j                    # Output result as JSON
  ipregion.sh -v                    # Enable verbose logging
```

## Output

- **Color-coded table**: Shows results for each service and protocol (IPv4/IPv6)
- **JSON**: Use `--json` for machine-readable output

## Contributing

Contributions are welcome! Feel free to submit pull requests to add new services or improve the script’s functionality.

![Star History Chart](https://api.star-history.com/svg?repos=vernette/ipregion&type=Date)
