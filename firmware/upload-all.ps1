$FQBN = "esp32:esp32:esp32"

# ==========================================
# PORTS TO UPLOAD
# ==========================================

$Ports = @(
    "COM8",
    "COM9"
)

# ==========================================
# BUILD DIRECTORY
# ==========================================

$BuildDir = "G:\pathfinder\firmware\build"

# ==========================================
# CHECK BUILD
# ==========================================

$BinFile = Get-ChildItem $BuildDir -Filter "*.ino.bootloader.bin" |
    Select-Object -First 1

if ($null -eq $BinFile) {
    Write-Host ""
    Write-Host "ERROR: No compiled firmware found."
    Write-Host "Compile the firmware first."
    exit 1
}

Write-Host ""
Write-Host "========================================"
Write-Host "        ESP32 MASS UPLOADER"
Write-Host "========================================"
Write-Host ""

Write-Host "Firmware:"
Write-Host "  $($BinFile.FullName)"
Write-Host ""

Write-Host "Target ports:"
$Ports | ForEach-Object {
    Write-Host "  $_"
}

Write-Host ""
Write-Host "Starting parallel uploads..."
Write-Host ""

# ==========================================
# PARALLEL UPLOAD
# ==========================================

$Jobs = foreach ($Port in $Ports) {

    Start-Job -ArgumentList $FQBN, $Port, $BuildDir -ScriptBlock {

        param(
            $FQBN,
            $Port,
            $BuildDir
        )

        $Output = & arduino-cli upload `
            --fqbn $FQBN `
            --port $Port `
            --input-dir $BuildDir 2>&1

        if ($LASTEXITCODE -eq 0) {

            [PSCustomObject]@{
                Port   = $Port
                Status = "SUCCESS"
                Output = ($Output -join "`n")
            }

        }
        else {

            [PSCustomObject]@{
                Port   = $Port
                Status = "FAILED"
                Output = ($Output -join "`n")
            }
        }
    }
}

# ==========================================
# WAIT
# ==========================================

$Jobs | Wait-Job | Out-Null

# ==========================================
# RESULTS
# ==========================================

Write-Host ""
Write-Host "========================================"
Write-Host "              RESULTS"
Write-Host "========================================"
Write-Host ""

foreach ($Job in $Jobs) {

    $Result = Receive-Job $Job

    if ($Result.Status -eq "SUCCESS") {

        Write-Host "$($Result.Port)  ->  SUCCESS"

    }
    else {

        Write-Host "$($Result.Port)  ->  FAILED"

        Write-Host ""
        Write-Host "Error from $($Result.Port):"
        Write-Host $Result.Output
        Write-Host ""
    }

    Remove-Job $Job
}

Write-Host ""
Write-Host "========================================"
Write-Host "              DONE"
Write-Host "========================================"