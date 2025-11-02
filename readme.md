# API Health Check
A lightweight Bash script to monitor HTTP endpoints.

## Features
- Check URLs from command line, text file, or JSON config
- Logs only failures (with timestamp) to `health-check.log`
- Exit code = number of failed endpoints `(0 = all OK)`
- Supports named endpoints in JSON for clearer output
- Safe: 10-second timeout per request, skips comments/empty lines

## Usage
```bash
./health-check.sh https://api1.com https://api2.com
./health-check.sh --file urls.txt
./health-check.sh --config config.json
```

## Example `config.json`
```bash
{
  "endpoints": [
    { "name": "Auth API", "url": "https://api.example.com/auth" },
    { "url": "https://httpbin.org/status/500" }
  ]
}
```
- `url` is required.
- `name` is optional (used in output/logs for clarity).

## Requirements
- `bash`
- `curl`
- `jq` (only if using --config)