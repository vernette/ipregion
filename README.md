
<div align="right">
  <details>
    <summary >🌐 Language</summary>
    <div>
      <div align="center">
        <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=en">English</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=zh-CN">简体中文</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=zh-TW">繁體中文</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=ja">日本語</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=ko">한국어</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=hi">हिन्दी</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=th">ไทย</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=fr">Français</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=de">Deutsch</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=es">Español</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=it">Italiano</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=ru">Русский</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=pt">Português</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=nl">Nederlands</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=pl">Polski</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=ar">العربية</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=fa">فارسی</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=tr">Türkçe</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=vi">Tiếng Việt</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=id">Bahasa Indonesia</a>
        | <a href="https://openaitx.github.io/view.html?user=vernette&project=ipregion&lang=as">অসমীয়া</
      </div>
    </div>
  </details>
</div>

# ipregion

![image](https://i.imgur.com/CRxBuVR.gif)

## Usage

### Download and run locally

```bash
wget -O ipregion.sh https://ipregion.vrnt.xyz
chmod +x ipregion.sh
```

### Run directly from GitHub

```bash
bash <(wget -qO- https://ipregion.vrnt.xyz)
```

### Docker

#### Run the container for IPv4 (default Docker bridge network)

This runs your IP geolocation check using IPv4 only, without requiring host network mode:

```bash
docker run --rm vernette/ipregion:latest
```

You can append additional script options as needed, for example:

```
docker run --rm vernette/ipregion:latest --group geoip
```

#### Run the container with host networking (for IPv4 & IPv6 or custom interface)

To access both IPv4 and IPv6 on the host real network interfaces, or to specify a custom network interface (e.g., eth1), use Docker host network mode:

```bash
docker run --rm --network=host vernette/ipregion:latest
```

```bash
docker run --rm --network=host vernette/ipregion:latest --interface eth1
```

> [!NOTE]
> When using `--network=host`, the container shares the host network stack, which reduces network isolation but enables full access to interfaces. Without `--network=host`, the container uses Docker bridge network, which may not expose IPv6 or allow interface selection

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
