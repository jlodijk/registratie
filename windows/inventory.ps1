# Save as Inventory.ps1 and run in PowerShell (Run as administrator recommended)

$now = Get-Date -Format "yyyy-MM-dd"
$hostname = $env:COMPUTERNAME
$bios = Get-WmiObject Win32_BIOS
$cpu = Get-WmiObject Win32_Processor
$ram_modules = Get-WmiObject Win32_PhysicalMemory
$ram = Get-WmiObject Win32_ComputerSystem
$ram_slots = Get-WmiObject Win32_PhysicalMemoryArray
$disk = Get-WmiObject Win32_DiskDrive | Select-Object -First 1
$os = Get-WmiObject Win32_OperatingSystem
$gpu = Get-WmiObject Win32_VideoController | Select-Object -First 1
$board = Get-WmiObject Win32_BaseBoard
$battery = Get-WmiObject Win32_Battery
$netAdapters = Get-WmiObject Win32_NetworkAdapter | Where-Object {$_.PhysicalAdapter -eq $true}
$wifi = $netAdapters | Where-Object {$_.Name -match "Wi-Fi|Wireless"} | Select-Object -First 1
$eth = $netAdapters | Where-Object {$_.Name -match "Ethernet"} | Select-Object -First 1
$bt = Get-WmiObject Win32_PnPEntity | Where-Object {$_.Name -match "Bluetooth"} | Select-Object -First 1
$display = Get-WmiObject WmiMonitorBasicDisplayParams -Namespace root\wmi | Select-Object -First 1
$monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorListedSupportedSourceModes | Select-Object -First 1
$audio = Get-WmiObject Win32_SoundDevice | Select-Object -First 1
$webcam = Get-WmiObject Win32_PnPEntity | Where-Object {$_.Name -match "Camera|Webcam"} | Select-Object -First 1
$storage = Get-Volume | Where-Object {$_.DriveLetter} | Select-Object DriveLetter,@{Name="SizeGB";Expression={[math]::Round($_.Size/1GB,2)}},@{Name="FreeGB";Expression={[math]::Round($_.SizeRemaining/1GB,2)}}

Write-Host "=== Laptop Hardware Inventarisatie ==="
Write-Host "Hostname: $hostname"
Write-Host "Datum: $now"
Write-Host "Laptopnummer / Serienummer: $($bios.SerialNumber)"
Write-Host "`n--- CPU ---"
Write-Host "Naam: $($cpu.Name)"
Write-Host "Cores: $($cpu.NumberOfCores)"
Write-Host "Threads: $($cpu.NumberOfLogicalProcessors)"
Write-Host "Kloksnelheid: $([math]::Round($cpu.MaxClockSpeed/1000,2)) GHz"

Write-Host "`n--- RAM ---"
$ramTotal = [math]::Round($ram.TotalPhysicalMemory / 1GB,2)
Write-Host "Totaal: $ramTotal GB"
if($ram_modules) {
    $types = ($ram_modules | ForEach-Object { $_.SMBIOSMemoryType })
    $speeds = ($ram_modules | ForEach-Object { $_.Speed })
    Write-Host "Type/Snelheid per module: $($types -join ', ') / $($speeds -join ', ') MHz"
}
if($ram_slots) {
    Write-Host "Slots: $($ram_slots.NumberOfMemoryDevices) beschikbare, $($ram_modules.Count) gebruikt"
}

Write-Host "`n--- Opslag ---"
if($disk){
    Write-Host "Type: $($disk.MediaType)"
    Write-Host "Model: $($disk.Model)"
    Write-Host "Capaciteit fysiek: $([math]::Round($disk.Size/1GB,2)) GB"
}
if($storage){
    foreach($vol in $storage){
        Write-Host "Drive $($vol.DriveLetter): totale $($vol.SizeGB) GB / vrij $($vol.FreeGB) GB"
    }
}

Write-Host "`n--- GPU ---"
if($gpu){
    Write-Host "Naam: $($gpu.Name)"
    Write-Host "VRAM: $([math]::Round($gpu.AdapterRAM/1GB,2)) GB"
    Write-Host "Type: $($gpu.VideoProcessor)"
}

Write-Host "`n--- Moederbord ---"
Write-Host "Fabrikant: $($board.Manufacturer)"
Write-Host "Model: $($board.Product)"
Write-Host "BIOS versie: $($bios.SMBIOSBIOSVersion)"

Write-Host "`n--- Accu ---"
if($battery){
    Write-Host "Capaciteit: $($battery.DesignCapacity)"
    Write-Host "Health (voltage): $($battery.DesignVoltage)"
    Write-Host "Laadcycli: $($battery.CycleCount)"
}else{
    Write-Host "Geen batterijinformatie gevonden."
}

Write-Host "`n--- Netwerk ---"
Write-Host "Wi-Fi kaart: $($wifi.Name)"
Write-Host "Ethernet kaart: $($eth.Name)"
Write-Host "Bluetooth: $($bt.Name)"

Write-Host "`n--- Scherm ---"
if($display){
    Write-Host "Formaat (inches approx): $([math]::Round([math]::Sqrt(($display.HorizontalImageSize/2.54)**2 + ($display.VerticalImageSize/2.54)**2),1))"
    Write-Host "Resolutie: $($display.MaxHorizontalImageSize) x $($display.MaxVerticalImageSize) mm (gebruik Instellingen voor exacte pixels)"
}
if($monitors){
    Write-Host "Paneeltype/Refresh: raadpleeg Instellingen"
}

Write-Host "`n--- Audio ---"
Write-Host "Geluidskaart: $($audio.Name)"
Write-Host "Speakers/Microfoon: Controleer Apparaatbeheer"

Write-Host "`n--- Webcam ---"
Write-Host "Webcam: $($webcam.Name)"

Write-Host "`n--- Besturingssysteem ---"
Write-Host "Editie: $($os.Caption)"
Write-Host "Versie: $($os.Version)"
Write-Host "Build: $($os.BuildNumber)"
Write-Host "Licentie geactiveerd: $([int]$os.OOBEInProgress -eq 0)"

Write-Host "`nScript klaar. Kopieer bovenstaande gegevens naar het formulier."
