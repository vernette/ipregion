# AGENTS.md

## Project Overview

IPRegion is a Bash-based network diagnostic tool that determines IP geolocation using multiple GeoIP APIs and popular websites. It supports both IPv4 and IPv6, parallel processing, SOCKS5 proxy, and custom network interfaces.

## Essential Commands

### Testing
```bash
bash tests/run.sh
```
Runs unit tests for core validation functions. Uses a simple test framework built with bash.

### Manual Testing
```bash
./ipregion.sh              # Check all services
./ipregion.sh --help        # Show all options
./ipregion.sh -g primary   # GeoIP services only
./ipregion.sh -g custom    # Popular websites only
./ipregion.sh -j           # JSON output
./ipregion.sh -v           # Verbose mode
./ipregion.sh -d           # Debug mode (logs to file, offers upload)
./ipregion.sh -P 6         # Run with 6 parallel jobs
./ipregion.sh -p 127.0.0.1:1080  # Use SOCKS5 proxy
./ipregion.sh -4           # IPv4 only
./ipregion.sh -6           # IPv6 only
```

## Project Structure

```
ipregion/
├── ipregion.sh       # Main script (~2500 lines)
├── index.php        # Simple PHP wrapper that outputs the script
├── tests/
│   └── run.sh       # Unit tests
└── .github/
    └── workflows/
        └── deploy.yml  # CI/CD: tests and deploys via FTPS
```

## Code Organization

### Main Script Architecture

The `ipregion.sh` script is organized into these logical sections:

1. **Configuration (lines 1-180)**
   - Constants and global variables
   - Color codes for terminal output
   - Service definitions (associative arrays)
   - Dependency mappings

2. **Utility Functions (lines 184-463)**
   - `color()` - Color-coded output
   - `log()` - Logging function
   - `error_exit()` - Error handling with help display
   - `setup_debug()` - Debug mode initialization
   - HTML decoding, ASCII normalization

3. **Parallel Processing (lines 465-515)**
   - `supports_wait_n()` - Checks bash version for parallel support
   - `wait_for_parallel_slot()` - Manages parallel job slots
   - `prune_parallel_pids()` - Cleans up finished background jobs
   - `detect_parallel_jobs()` - Auto-detects CPU count

4. **Dependency Management (lines 517-736)**
   - `detect_distro()` - Detects Linux distribution
   - `detect_package_manager()` - Returns apt/pacman/dnf/yum/etc.
   - `install_dependencies()` - Auto-installs missing packages
   - `get_package_name()` - Maps commands to package names

5. **Validation Functions (lines 871-977)**
   - `is_valid_ipv4()`, `is_valid_ipv6()`
   - `is_valid_proxy_addr()`, `is_valid_interface_name()`
   - `is_valid_json()`, `is_valid_package_name()`

6. **IP Detection (lines 1126-1380)**
   - `check_ip_support()` - Comprehensive IP support check (interfaces, connectivity, DNS)
   - `fetch_external_ip()` - Gets external IP from multiple identity services
   - `discover_external_ips()` - Main IP discovery function
   - `get_asn()` - Retrieves ASN information

7. **HTTP Client (lines 1474-1604)**
   - `curl_wrapper()` - Wrapper around curl with retry logic, proxy support, etc.
   - `service_build_request()` - Builds HTTP requests for services
   - `probe_service()` - Executes HTTP requests for services

8. **Service Processing (lines 1656-1952)**
   - `process_response()` - Parses service responses (JSON/plain)
   - `process_service()` - Main service processing entry point
   - `process_custom_service()` - Handles custom website checks
   - `run_service_group()` / `run_service_group_parallel()` - Group execution

9. **Output Formatting (lines 1954-2216)**
   - `finalize_json()` - Builds JSON output
   - `print_table_group()` - Formats table output with `column`
   - `print_header()` - Prints IP/ASN information
   - `print_results()` - Main output function

10. **Service Handlers (lines 2218-2406)**
    - Individual `lookup_*` functions for each service
    - Each takes `ip_version` parameter (4 or 6)
    - Return country code or feature availability

11. **Main Entry Point (lines 2407-2511)**
    - `main()` - Orchestrates the entire workflow
    - Parses arguments, checks dependencies, runs checks, prints results

## Naming Conventions

### Variables
- Global constants: UPPERCASE with underscores (e.g., `COLOR_HEADER`, `STATUS_NA`)
- Global variables: UPPERCASE (e.g., `VERBOSE`, `JSON_OUTPUT`, `EXTERNAL_IPV4`)
- Local variables: lowercase with underscores (e.g., `ip_version`, `service_name`)

### Functions
- Snake_case naming: `process_json`, `spinner_start`, `fetch_external_ip`
- Prefix patterns:
  - `is_*` - Validation functions (return boolean)
  - `get_*` - Retrieval functions
  - `check_*` - Verification functions
  - `print_*` - Output functions
  - `lookup_*` - Service-specific lookup functions
  - `process_*` - Processing/transformation functions

### Constants
- Service names: UPPERCASE (e.g., `MAXMIND`, `GOOGLE`, `YOUTUBE`)
- Status values: UPPERCASE (e.g., `STATUS_DENIED`, `STATUS_RATE_LIMIT`)

## Code Style Patterns

### Arrays and Associative Arrays
```bash
# Associative array for service definitions
declare -A PRIMARY_SERVICES=(
  [MAXMIND]="maxmind.com|geoip.maxmind.com|/geoip/v2.1/city/me"
  [RIPE]="rdap.db.ripe.net|rdap.db.ripe.net|/ip/{ip}"
)

# Ordered array for consistent output
PRIMARY_SERVICES_ORDER=("MAXMIND" "RIPE" "IPINFO_IO" ...)

# Regular array
ARR_PRIMARY=()
```

### String Manipulation
```bash
# Replace characters
ipv4=${ipv4//$'\n'/}  # Remove newlines

# Remove patterns from string
rest="${line#*|||}"   # Remove prefix up to first |||
value="${rest%%|||*}"  # Remove suffix from first |||
```

### Conditional Output
```bash
# Check JSON output flag before printing
if [[ "$JSON_OUTPUT" == true ]]; then
  echo "$value"
  return
fi

# Color-coded output
color INFO "message"
color ERROR "error"
```

### Error Handling
```bash
# Exit with error and show help
error_exit "Invalid proxy address" 1

# Log warnings without exiting
log "$LOG_WARN" "Invalid IPv4 from $service: $ip"
```

### Function Parameter Parsing
```bash
# Parse pipe-delimited configuration
IFS='|' read -r display_name domain url_template response_format <<<"$service_config"

# Parse associative arrays
if [[ -n "${CUSTOM_SERVICES[$service]}" ]]; then
  display_name="${CUSTOM_SERVICES[$service]}"
fi
```

## Testing Approach

The project uses a simple bash test framework in `tests/run.sh`:

### Test Assertions
- `assert_eq "expected" "$actual" "test name"` - Equality test
- `assert_true "test name" function args...` - Boolean true test
- `assert_false "test name" function args...` - Boolean false test
- `assert_empty "$value" "test name"` - Empty string test

### Test Coverage
Tests cover:
- IPv4/IPv6 validation functions
- JSON processing
- Input validation

Tests run via source: `source "$ROOT_DIR/ipregion.sh"` and call functions directly.

## Important Gotchas

### Bash Version Requirements
- Script requires **Bash 4.3+** for `wait -n` support (parallel processing)
- Falls back to legacy loop for Bash < 4.3 (see `supports_wait_n()`)
- Associative arrays require Bash 4.0+

### ShellCheck Directives
The script uses `shellcheck disable` comments in specific places:
- Line 1003: SC1003 (literal backslash in spin character)
- Line 12 in tests: SC1091 (source following variable)

These are intentional and should not be removed.

### Parallel Processing
- Default parallel job count is auto-detected (CPU cores)
- Each parallel job runs in a subshell with environment isolation
- Results are written to temp files and collected at the end
- Parallel mode disables spinner by default (use `--force-spinner` to override)

### HTTP Error Handling
- HTTP 403 → returns `STATUS_DENIED`
- HTTP 429 → returns `STATUS_RATE_LIMIT`
- HTTP 5xx → returns `STATUS_SERVER_ERROR`
- Other 4xx → returns `STATUS_NA`
- The `curl_wrapper` function handles retries and timeouts

### JSON Processing
- Always check if response is valid JSON with `is_valid_json()`
- Use `process_json()` which handles invalid input gracefully
- Services with custom handlers bypass JSON processing

### Service Configuration Format
Primary services use pipe-delimited format:
```
[SERVICE_NAME]="display_name|domain|url_template|response_format"
```

Where `{ip}` in `url_template` gets replaced with the actual IP address.

### IPv6-over-IPv4 Services
Some services (like IPAPI_IS) don't support IPv6 transport but have IPv6 addresses. These are listed in `IPV6_OVER_IPV4_SERVICES` array and automatically switch to IPv4 transport when requested.

### Debug Mode Security
- Debug logs contain sensitive data (IPs, headers)
- Upload uses redacted copy (`redact_debug_log()` function)
- Temp files use `mktemp` with restrictive permissions (`umask 077`)
- Upload prompt is shown at end of execution

### Colors and Formatting
- Colors are defined as constants at the top (lines 32-43)
- Use `color COLOR_NAME "text"` for colored output
- Use `bold "text"` for bold output
- Always reset colors with `color RESET` or let `color` function handle it

## Adding New Services

### Primary GeoIP Services
1. Add to `PRIMARY_SERVICES` associative array
2. Add to `PRIMARY_SERVICES_ORDER` array
3. Add jq filter in `process_response()` function
4. Optional: Add to `SERVICE_HEADERS` if special headers needed
5. Optional: Add custom handler to `PRIMARY_SERVICES_CUSTOM_HANDLERS` if non-JSON

### Custom Website Services
1. Add to `CUSTOM_SERVICES` associative array (display name)
2. Add to `CUSTOM_SERVICES_ORDER` array
3. Add handler to `CUSTOM_SERVICES_HANDLERS` associative array
4. Implement `lookup_service_name()` function that accepts `ip_version` (4 or 6)
5. The handler should return the result (country code or feature availability)

### Example Custom Handler
```bash
lookup_example() {
  local ip_version="$1"
  local response

  response=$(curl_wrapper GET "https://example.com/geo" \
    --ip-version "$ip_version")

  process_json "$response" ".countryCode"
}
```

## Dependencies

### Required Commands
- `bash` - Script execution
- `curl` - HTTP requests
- `jq` - JSON parsing
- `column` - Table formatting (optional, fallback if missing)
- `nslookup` - DNS checks (optional)

### Optional Commands
- `python3` - Used for IPv6 validation if available, fallback to bash regex
- `perl` - Used for HTML decoding if available
- `php` - Used for HTML decoding if available
- `iconv` - Used for ASCII normalization if available

### Installation
The script auto-detects the package manager and offers to install missing dependencies:
- Debian/Ubuntu/Termux → `apt`
- Arch/Manjaro → `pacman`
- Fedora → `dnf`
- CentOS/RHEL → `yum` or `dnf`
- openSUSE → `zypper`
- Alpine → `apk`

## CI/CD

GitHub Actions workflow (`.github/workflows/deploy.yml`):
1. Runs tests on every push to `master`
2. Only runs when `ipregion.sh` or `index.php` changes
3. Installs `jq` and `lftp`
4. Uploads files via FTPS to production server

## Deployment

The script is distributed via:
- Direct download: `https://ipregion.vladon.sh`
- GitHub releases

Deployment is automated via GitHub Actions when merging to master.

## Country Code Format

All country codes are in **ISO 3166-1 alpha-2** format (e.g., RU, US, DE).
Lookup codes at: https://www.iso.org/obp/ui/#search/code/

## Common Workflows

### Adding a New Primary Service
1. Add service definition to `PRIMARY_SERVICES`
2. Add to `PRIMARY_SERVICES_ORDER`
3. Add jq filter in `process_response()` case statement
4. Test with `./ipregion.sh -g primary`
5. Add unit test if adding new validation logic

### Debugging a Failing Service
1. Run with `./ipregion.sh -v -d`
2. Review debug log (path shown at end)
3. Check if it's a JSON parsing issue (look at `process_json` output)
4. Verify the service URL is still valid
5. Check if service is in `EXCLUDED_SERVICES`

### Testing Parallel Processing
```bash
./ipregion.sh -P 10                    # Run 10 parallel jobs
./ipregion.sh -P 10 --force-spinner   # Parallel with spinner
./ipregion.sh -P 10 --progress-log     # Progress lines instead of spinner
```

### Adding Validation Function
1. Add `is_valid_*` function following existing patterns
2. Return 0 for valid, 1 for invalid
3. Add unit test in `tests/run.sh`
4. Run tests: `bash tests/run.sh`
