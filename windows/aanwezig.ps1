# aanwezig.ps1
$ServerUrl = 'http://localhost:4000'
$HostName  = $env:COMPUTERNAME

$netsh = netsh wlan show interfaces
if ($LASTEXITCODE -ne 0 -or -not $netsh.Contains('State')) {
    Write-Host 'Geen actieve wifi-verbinding gevonden.'
    exit 1
}

$bssidLine = $netsh -split "`r?`n" | Where-Object { $_ -match '^\s*BSSID\s*:' } | Select-Object -First 1
if (-not $bssidLine) {
    Write-Host 'Geen actieve wifi-verbinding gevonden.'
    exit 1
}

$Bssid = ($bssidLine -split ':', 2)[1].Trim()

$encHost  = [uri]::EscapeDataString($HostName)
$encBssid = [uri]::EscapeDataString($Bssid)

Start-Process "$ServerUrl/login?hostname=$encHost&bssid=$encBssid"
