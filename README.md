# IPRegion 🌍

This is a shell script designed to check how your public IP address is identified by various IP databases. The script queries multiple sources to retrieve the country code associated with your IP, providing a comprehensive overview of how different services interpret your location.

![image](https://i.imgur.com/7Tj4Usc.png)

## Features

- **Multiple Sources**: Supports queries from over 20 different IP information services, including:
  - `ipinfo.io`
  - `ipapi.com`
  - `ipregistry.co`
  - `db-ip.com`
  - and [many](https://github.com/vernette/ipregion/blob/03793fddc68e118424c17469c24376e91e6b6a03/ipregion.sh#L6) more!

- **User-Friendly Output**: Displays the results in a clean and formatted manner, showing how each service identifies your IP.

- **Lightweight**: Written in Bash, the script has minimal dependencies, primarily requiring `curl` and `jq` for network requests and JSON parsing.

## Usage

With curl:

```bash
curl -s "https://raw.githubusercontent.com/vernette/ipregion/refs/heads/master/ipregion.sh" | bash
```

With wget:

```bash
wget -qO - "https://raw.githubusercontent.com/verrette/ipregion/refs/heads/master/ipregion.sh" | bash
```

Or clone the repository and run the script manually:

```bash
git clone https://github.com/vernette/ipregion.git
cd ipregion
chmod +x ipregion.sh
./ipregion.sh
```

## TODO

- [ ] Add more IP services
- [ ] Handle errors when doing network requests
- [ ] Handle service rate limit errors
- [ ] Add IP identification by various sites (Google, TikTok, OpenAI, etc.)
