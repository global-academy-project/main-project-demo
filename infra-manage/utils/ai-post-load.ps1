param(
    [ValidateRange(1, 2147483647)]
    [int]$RequestCount = 10,
    [ValidateRange(1, 1000)]
    [int]$Concurrency = 2,
    [ValidateRange(1, 86400)]
    [int]$TimeoutSeconds = 300,
    [string]$RequestFile,
    [string]$LogPath
)

$ErrorActionPreference = "Stop"
$composeFile = Join-Path (Split-Path -Parent $PSScriptRoot) "docker\docker-compose.yml"
if (-not $LogPath) {
    $logDirectory = Join-Path $PSScriptRoot "logs"
    $null = New-Item -ItemType Directory -Force -Path $logDirectory
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
    $identifier = [guid]::NewGuid().ToString("N").Substring(0, 8)
    $LogPath = Join-Path $logDirectory "ai-post-c$Concurrency-$timestamp-$identifier.log"
}
$LogPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($LogPath)
if (Test-Path -LiteralPath $LogPath) {
    throw "Log path already exists: $LogPath"
}

if ($RequestFile) {
    $requests = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $RequestFile).Path)
    $null = ConvertFrom-Json -InputObject $requests
} else {
    $requests = @'
[
  {"path":"/api/v1/agent/near-miss-tag","body":{"runId":1,"siteId":1,"nearMissId":1,"title":"Near miss","description":"A worker nearly slipped on a wet floor."}},
  {"path":"/api/v1/extract/rule-input","body":{"text":"Oxygen is 20.9 percent before entering the confined space."}}
]
'@
}

$encodedRequests = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($requests))
$program = @'
import base64
import json
import sys
import threading
import time
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

requests = json.loads(base64.b64decode(sys.argv[1]))
request_count, concurrency, timeout = map(int, sys.argv[2:5])
if not isinstance(requests, list) or not requests:
    sys.exit("Request file must contain a non-empty JSON array.")
for item in requests:
    if not isinstance(item, dict) or not isinstance(item.get("path"), str) or not item["path"].startswith("/") or "body" not in item:
        sys.exit("Each request must have a path starting with / and a JSON body.")

lock = threading.Lock()
next_index = 0
results = defaultdict(Counter)
completed = 0
duration_sum = 0.0
duration_min = float("inf")
duration_max = 0.0
started = time.perf_counter()

def worker():
    global next_index, completed, duration_sum, duration_min, duration_max
    while True:
        with lock:
            if next_index >= request_count:
                return
            index = next_index
            next_index += 1
        item = requests[index % len(requests)]
        request = Request(
            "http://127.0.0.1:60100" + item["path"],
            data=json.dumps(item["body"]).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        request_started = time.perf_counter()
        try:
            with urlopen(request, timeout=timeout) as response:
                status = str(response.status)
                response.read()
        except HTTPError as error:
            status = str(error.code)
            error.close()
        except (URLError, OSError) as error:
            status = "ERROR: " + str(error)
        elapsed = time.perf_counter() - request_started
        with lock:
            results[item["path"]][status] += 1
            completed += 1
            duration_sum += elapsed
            duration_min = min(duration_min, elapsed)
            duration_max = max(duration_max, elapsed)
            print(f"{index + 1}/{request_count} {item['path']} {status} {elapsed:.2f}s", flush=True)

with ThreadPoolExecutor(max_workers=min(concurrency, request_count)) as executor:
    futures = [executor.submit(worker) for _ in range(min(concurrency, request_count))]
    for future in futures:
        future.result()

elapsed = time.perf_counter() - started
print(f"\nCompleted {completed} requests in {elapsed:.2f}s ({completed / elapsed:.2f} requests/s)")
print(f"Latency: min {duration_min:.2f}s, mean {duration_sum / completed:.2f}s, max {duration_max:.2f}s")
for path, statuses in sorted(results.items()):
    print(f"{path}: " + ", ".join(f"{status}={count}" for status, count in sorted(statuses.items())))
if any(not status.startswith("2") for statuses in results.values() for status in statuses):
    sys.exit(1)
'@

"Started: $((Get-Date).ToString('o')) Requests: $RequestCount Concurrency: $Concurrency TimeoutSeconds: $TimeoutSeconds" | Tee-Object -FilePath $LogPath
"Log: $LogPath" | Write-Output
try {
    $ErrorActionPreference = "Continue"
    $program | docker compose -f $composeFile exec -T python-ai-model python - $encodedRequests $RequestCount $Concurrency $TimeoutSeconds 2>&1 | Tee-Object -FilePath $LogPath -Append
    $exitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = "Stop"
}
"Finished: $((Get-Date).ToString('o')) Exit: $exitCode" | Tee-Object -FilePath $LogPath -Append
if ($exitCode -ne 0) {
    throw "Request run failed (exit $exitCode). See $LogPath"
}