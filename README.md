# IPRegion 🌍

This is a fork of [vernette/ipregion](https://github.com/vernette/ipregion). This shell script is designed to check how your public IP address is identified by various IP databases. The script queries multiple sources to retrieve the country code associated with your IP, providing a comprehensive overview of how different services interpret your location.

## Improvements in this fork
- **IPv6 support** added.
- **Graceful handling of unreachable services** – if a service fails to retrieve an IP, it is simply skipped without causing an error.
- **Additional services included**: YouTube and Cloudflare CDN.
- **Support for SOCKS proxy** – allows running the script through a local SOCKS proxy.
  
![image](https://github.com/Davoyan/ipregion/blob/master/test_example.jpg?raw=true)

## Features

- **Multiple Sources**: Supports queries from over 20 different IP information services, including:
  - `ipinfo.io`
  - `ipapi.com`
  - `ipregistry.co`
  - `db-ip.com`
  - and [many](https://github.com/Davoyan/ipregion/blob/master/ipregion.sh#L6) more!

- **User-Friendly Output**: Displays the results in a clean and formatted manner, showing how each service identifies your IP.

- **Lightweight**: Written in Bash, the script has minimal dependencies, primarily requiring `curl` and `jq` for network requests and JSON parsing.

## Dependencies

Currently script supports automatic installation for the following OSes:

- Debian/Ubuntu
- Arch Linux
- Fedora
- Termux

For other systems, please install `curl` and `jq` manually.

## Usage

> [!TIP]
> If you notice that any of the services have stopped working, please create an [issue](https://github.com/vernette/ipregion/issues)

```
bash <(wget -qO - https://github.com/Davoyan/ipregion/raw/master/ipregion.sh)
```

To run the script through a SOCKS5 proxy on port 40000:
```
bash <(wget -qO - https://github.com/Davoyan/ipregion/raw/master/ipregion.sh) --socks-port 40000
```

You can download the script and run it manually:

```bash
wget -O https://github.com/Davoyan/ipregion/raw/master/ipregion.sh
chmod +x ipregion.sh
./ipregion.sh
```



