# IP Cache Fallback Mechanism Architecture

## Overview

This document outlines the architecture for implementing a robust fallback mechanism for external IP detection in the IPRegion script. The new system prevents initialization failures caused by rate limiting or IP bans by implementing a multi-layered approach with service rotation, retry logic, and local caching.

## Current State Analysis

### Existing Implementation
- **Identity Services Array**: 4 services (ident.me, ifconfig.me, api64.ipify.org, ifconfig.co)
- **Retry Logic**: Basic curl retry (CURL_RETRIES=1, CURL_TIMEOUT=5)
- **Failure Handling**: Script halts with `error_exit()` when all services fail
- **No Caching**: No persistence of previously discovered IPs

### Limitations
1. Single attempt per service
2. Limited service pool
3. No fallback to previously known IPs
4. Script terminates completely on IP detection failure

## Proposed Architecture

### System Flow

```mermaid
flowchart TD
    A[discover_external_ips] --> B{IPv4 enabled?}
    B -->|Yes| C[fetch_external_ip 4]
    B -->|No| D{IPv6 enabled?}
    D -->|Yes| E[fetch_external_ip 6]
    D -->|No| F[Check cached IPs]

    C --> G{IP found?}
    E --> G
    G -->|Yes| H[Save to cache]
    G -->|No| I{Cache has valid IP?}

    F --> I
    I -->|Yes| J[Load from cache]
    I -->|No| K[Continue with available IPs]

    H --> L[Return IP]
    J --> L

    subgraph fetch_external_ip
        M[Shuffle services]
        N[For each service]
        O[Attempt with retry]
        P{Success?}
        P -->|Yes| Q[Return IP]
        P -->|No| R{More services?}
        R -->|Yes| N
        R -->|No| S[Return empty]
    end

    O --> T[Retry loop 1-3 attempts]
    T --> U{Response valid?}
    U -->|Yes| P
    U -->|No| V{Retry limit reached?}
    V -->|No| T
    V -->|Yes| P
    end
```

### Cache Management Flow

```mermaid
flowchart TD
    A[Cache Operations] --> B[Load Cache]
    A --> C[Save Cache]
    A --> D[Validate Cache]

    B --> E{Cache file exists?}
    E -->|Yes| F[Read cache file]
    E -->|No| G[Return empty]
    F --> H{Cache timestamp valid?}
    H -->|Yes| I[Parse IP values]
    H -->|No| G
    I --> J{IP format valid?}
    J -->|Yes| K[Return cached IPs]
    J -->|No| G

    C --> L[Create cache directory]
    L --> M[Write cache file]
    M --> N[Set restrictive permissions]

    D --> O{IP matches version?}
    O -->|Yes| P{Timestamp within TTL?}
    P -->|Yes| Q[Valid]
    P -->|No| R[Expired]
    O -->|No| S[Invalid]
    end
```

## Component Design

### 1. Configuration Variables

```bash
# Cache Configuration
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ipregion"
CACHE_FILE="$CACHE_DIR/ip_cache.json"
CACHE_TTL=3600  # Cache validity in seconds (default: 1 hour)
CACHE_ENABLED=true
IP_FETCH_MAX_RETRIES=3  # Max retries per service
IP_FETCH_RETRY_DELAY=1  # Initial delay in seconds (exponential backoff)
```

### 2. Expanded Identity Services

```bash
IDENTITY_SERVICES=(
  # Primary services
  "ident.me"
  "ifconfig.me"
  "api64.ipify.org"
  "ifconfig.co"

  # Secondary services (fallback pool)
  "icanhazip.com"
  "checkip.amazonaws.com"
  "ipinfo.io/ip"
  "api.ipify.org"
  "myip.dnsomatic.com"
  "ipecho.net/plain"
  "whatismyipaddress.com/plain"
)
```

### 3. Cache File Format

```json
{
  "version": 1,
  "ipv4": {
    "address": "203.0.113.42",
    "timestamp": 1738680000,
    "source": "ident.me"
  },
  "ipv6": {
    "address": "2001:db8::1",
    "timestamp": 1738680000,
    "source": "ifconfig.co"
  }
}
```

### 4. New Functions

#### `load_ip_cache()`
- Reads cache file if it exists
- Validates cache structure and timestamps
- Returns cached IPs if valid, empty otherwise

#### `save_ip_cache()`
- Creates cache directory if needed
- Writes current IPs to cache file
- Sets restrictive file permissions (0600)

#### `is_cache_valid()`
- Checks if cached IP is within TTL
- Validates IP format
- Returns true/false

#### `fetch_ip_with_retry()`
- Attempts to fetch IP from a service
- Implements exponential backoff retry logic
- Returns IP or empty string

#### `fetch_external_ip_enhanced()`
- Enhanced version of `fetch_external_ip()`
- Uses retry logic per service
- Falls back to cache if all services fail
- Returns IP or empty string

### 5. Modified Functions

#### `discover_external_ips()`
- Try to fetch fresh IPs first
- If fetch fails, attempt to load from cache
- Only call `error_exit()` if both fetch and cache fail
- Log cache usage appropriately

#### `fetch_external_ip()`
- Can be refactored to use `fetch_ip_with_retry()`
- Or replaced entirely with `fetch_external_ip_enhanced()`

## Retry Logic Specification

### Exponential Backoff Algorithm

```
Attempt 1: immediate
Attempt 2: delay = 1 second
Attempt 3: delay = 2 seconds
Attempt 4: delay = 4 seconds
...
```

### Retry Conditions

- HTTP 5xx errors
- Network timeouts
- Connection refused
- Empty response
- Invalid IP format

### Non-Retry Conditions

- HTTP 429 (Rate Limit) - skip to next service
- HTTP 403 (Forbidden) - skip to next service
- HTTP 404 (Not Found) - skip to next service

## Command-Line Options

```
--no-cache              Disable cache usage
--cache-ttl SECONDS     Set cache TTL (default: 3600)
--clear-cache           Clear the IP cache
--show-cache            Show cached IP addresses
```

## Security Considerations

1. **Cache File Permissions**: Set to 0600 (owner read/write only)
2. **Cache Directory**: Use XDG Base Directory specification
3. **Cache Validation**: Strict validation of IP format before use
4. **Cache Expiration**: Default TTL of 1 hour prevents stale data

## Error Handling Strategy

### Priority Order

1. Fresh IP from identity service (success)
2. Cached IP (if within TTL)
3. Warning and continue with available IP (one version found)
4. Warning and continue with cached IP (both versions cached)
5. Error exit only if no IP available at all

### Logging Levels

- **INFO**: Successful IP fetch, cache save/load
- **WARN**: Service failure, cache miss, using stale cache
- **ERROR**: All services failed, cache invalid

## Testing Scenarios

1. **Normal Operation**: Services respond correctly, cache updated
2. **Service Failure**: Primary services fail, fallback to secondary
3. **Rate Limiting**: Service returns 429, skip to next service
4. **Network Issues**: Retry logic handles timeouts
5. **Cache Fallback**: All services fail, use cached IP
6. **Cache Expiration**: Stale cache ignored, attempt fresh fetch
7. **No Cache File**: First run, no cache available
8. **Cache Disabled**: --no-cache flag bypasses cache

## Implementation Phases

### Phase 1: Core Infrastructure
- Add configuration variables
- Implement cache management functions
- Expand IDENTITY_SERVICES array

### Phase 2: Retry Logic
- Implement `fetch_ip_with_retry()`
- Add exponential backoff
- Integrate with existing `curl_wrapper()`

### Phase 3: Integration
- Modify `fetch_external_ip()`
- Update `discover_external_ips()`
- Add cache fallback logic

### Phase 4: User Interface
- Add command-line options
- Update help text
- Add cache status output

### Phase 5: Testing
- Unit tests for cache functions
- Integration tests for retry logic
- End-to-end testing with simulated failures

## Backward Compatibility

- Default behavior: Cache enabled but non-blocking
- Existing scripts continue to work without changes
- Cache file created on first successful run
- No breaking changes to existing options
