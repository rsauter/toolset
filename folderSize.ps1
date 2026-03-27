
## This script retruns the size of all folders in a given path, including the number of files and the last modification date. The output is sorted by size in descending order.
$root = "C:\Application\CdrImporter"

function Convert-Size {
    param([long]$Bytes)
    $units = "B","KB","MB","GB","TB","PB"
    if ($null -eq $Bytes -or $Bytes -lt 1) { return "0 B" }
    $i = [math]::Floor([math]::Log([double]$Bytes,1024))
    $i = [math]::Min($i, $units.Count-1)
    "{0:N2} {1}" -f ($Bytes / [math]::Pow(1024,$i)), $units[$i]
}


$results = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $folder = $_.FullName
    $size = (Get-ChildItem -Path $folder -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Sum Length).Sum
    [pscustomobject]@{
        Ordner       = $folder
        Dateien      = (Get-ChildItem -Path $folder -Recurse -File -ErrorAction SilentlyContinue).Count
        Bytes        = $size
        Groesse      = (Convert-Size $size)
        LetzteAenderung = $_.LastWriteTime
    }
}

$results | Sort-Object Bytes -Descending | Format-Table -AutoSize
