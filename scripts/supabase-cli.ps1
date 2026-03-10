param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$root = Split-Path -Parent $PSScriptRoot
$tokenFile = Join-Path $root "supabase/.env.local"

if (Test-Path $tokenFile) {
    Get-Content $tokenFile | ForEach-Object {
        if ($_ -match '^\s*([A-Z0-9_]+)\s*=\s*(.+)\s*$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            [System.Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }
}

if (-not $env:SUPABASE_ACCESS_TOKEN) {
    Write-Error "Missing SUPABASE_ACCESS_TOKEN. Add it to supabase/.env.local."
    exit 1
}

& npx.cmd supabase @Args
exit $LASTEXITCODE
