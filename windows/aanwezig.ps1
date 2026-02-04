# aanwezig.ps1
$ServerUrl = 'https://116.203.242.75'
$HostName  = $env:COMPUTERNAME

$netsh = netsh wlan show interfaces
if ($LASTEXITCODE -ne 0 -or -not $netsh.Contains('State')) {
    Write-Host 'Geen actieve wifi-verbinding gevonden.'
    exit 1
}

$ssidLine = $netsh -split "`r?`n" | Where-Object { $_ -match '^\s*SSID\s*:' } | Select-Object -First 1
if (-not $ssidLine) {
    Write-Host 'Geen actieve wifi-verbinding gevonden.'
    exit 1
}

$Ssid = ($ssidLine -split ':', 2)[1].Trim()

$encHost  = [uri]::EscapeDataString($HostName)
$encSsid  = [uri]::EscapeDataString($Ssid)

Start-Process "$ServerUrl/login?hostname=$encHost&ssid=$encSsid"
