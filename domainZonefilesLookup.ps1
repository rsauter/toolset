# Requires the BIND package
# Install with: 
#   Windows: winget install ISC.BIND
#   macOS: brew install bind

param( [Parameter(Mandatory=$true)]
    [string]$Domain, [Parameter(Mandatory=$false)]
    [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'NS', 'TXT', 'SOA', 'PTR', 'ALL', 'HOSTING')]
    [string]$RecordType = 'A', [Parameter(Mandatory=$false)]
    [string]$DnsServer
)

# Cross-platform DNS lookup helper function
function Invoke-DnsLookup {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Type,
        [string]$Server
    )
    
    # For A and AAAA records, use .NET which works cross-platform
    if ($Type -eq 'A' -or $Type -eq 'AAAA') {
        try {
            if ($Type -eq 'A') {
                [System.Net.Dns]::GetHostAddresses($Name) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | ForEach-Object {
                    [pscustomobject]@{ Type = 'A'; IPAddress = $_.ToString() }
                }
            } else {
                [System.Net.Dns]::GetHostAddresses($Name) | Where-Object { $_.AddressFamily -eq 'InterNetworkV6' } | ForEach-Object {
                    [pscustomobject]@{ Type = 'AAAA'; IPAddress = $_.ToString() }
                }
            }
        } catch {
            return $null
        }
    } else {
        # For other record types, use dig/nslookup as fallback on macOS/Linux
        $digPath = (Get-Command dig -ErrorAction SilentlyContinue).Source
        if ($digPath) {
            $args = @($Name, $Type)
            if ($Server) { $args += "@$Server" }
            $digOutput = & dig $args +short 2>$null
            
            if ($digOutput -and $digOutput.Count -gt 0) {
                $digOutput | Where-Object { $_ -and $_ -notmatch "^;.*" } | ForEach-Object {
                    [pscustomobject]@{ Type = $Type; Data = $_ }
                }
            }
        } else {
            Write-Host "  Hinweis: 'dig' ist nicht installiert. Bitte 'dig' installieren für erweiterte DNS-Abfragen (brew install bind)" -ForegroundColor Yellow
            return $null
        }
    }
}

Write-Host "DNS Lookup für Domain: $Domain" -ForegroundColor Cyan
Write-Host "Record Type: $RecordType" -ForegroundColor Cyan

if ($DnsServer) {
    Write-Host "DNS Server: $DnsServer" -ForegroundColor Cyan
}

Write-Host "`n--- Ergebnisse ---`n" -ForegroundColor Green

try {
    if ($RecordType -eq 'HOSTING') {
        # Hosting-Informationen ermitteln
        Write-Host "=== HOSTING INFORMATIONEN ===" -ForegroundColor Yellow
        
        # 1. IP-Adresse(n) ermitteln
        Write-Host "`n--- IP-Adresse(n) ---" -ForegroundColor Cyan
        try {
            $ipAddresses = @()
            $ipResults = Invoke-DnsLookup -Name $Domain -Type 'A' -Server $DnsServer
            if ($ipResults) {
                $ipAddresses = $ipResults | Select-Object -ExpandProperty IPAddress
                $ipAddresses | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
            } else {
                Write-Host "  Keine A-Records gefunden" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  Keine A-Records gefunden" -ForegroundColor Gray
        }
        
        # 2. Nameserver ermitteln
        Write-Host "`n--- Nameserver ---" -ForegroundColor Cyan
        try {
            $nsResults = Invoke-DnsLookup -Name $Domain -Type 'NS' -Server $DnsServer
            if ($nsResults) {
                $nsResults | ForEach-Object { Write-Host "  $($_.Data)" -ForegroundColor White }
            } else {
                Write-Host "  Keine NS-Records gefunden" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  Keine NS-Records gefunden" -ForegroundColor Gray
        }
        
        # 3. IP-Informationen über externe API
        if ($ipAddresses) {
            Write-Host "`n--- IP-Informationen (Hosting Provider) ---" -ForegroundColor Cyan
            foreach ($ip in $ipAddresses) {
                Write-Host "`nIP: $ip" -ForegroundColor Yellow
                try {
                    # Nutze externe API für IP-Geolocation (ipinfo.io)
                    $ipInfo = Invoke-RestMethod -Uri "https://ipinfo.io/$ip/json" -ErrorAction SilentlyContinue
                    if ($ipInfo) {
                        Write-Host "  Organisation: $($ipInfo.org)" -ForegroundColor White
                        Write-Host "  Land: $($ipInfo.country)" -ForegroundColor White
                        Write-Host "  Region: $($ipInfo.region)" -ForegroundColor White
                        Write-Host "  Stadt: $($ipInfo.city)" -ForegroundColor White
                    }
                } catch {
                    Write-Host "  Keine zusätzlichen Informationen verfügbar" -ForegroundColor Gray
                }
            }
        }
        
        # 4. SOA Record (zeigt Primary Nameserver)
        Write-Host "`n--- SOA Record (Primary Nameserver) ---" -ForegroundColor Cyan
        try {
            $soaResult = Invoke-DnsLookup -Name $Domain -Type 'SOA' -Server $DnsServer
            if ($soaResult) {
                Write-Host "  $($soaResult.Data)" -ForegroundColor White
            } else {
                Write-Host "  Keine SOA-Records gefunden" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  Keine SOA-Records gefunden" -ForegroundColor Gray
        }
        
    } elseif ($RecordType -eq 'ALL') {
        # Alle gängigen Record-Typen abfragen
        $recordTypes = @('A', 'AAAA', 'MX', 'NS', 'TXT', 'SOA')
        
        foreach ($type in $recordTypes) {
            Write-Host "`n=== $type Records ===" -ForegroundColor Yellow
            try {
                $result = Invoke-DnsLookup -Name $Domain -Type $type -Server $DnsServer
                if ($result) {
                    $result | Format-Table -AutoSize
                } else {
                    Write-Host "Keine $type Records gefunden" -ForegroundColor Gray
                }
            } catch {
                Write-Host "Keine $type Records gefunden" -ForegroundColor Gray
            }
        }
    } else {
        # Spezifischen Record-Typ abfragen
        $result = Invoke-DnsLookup -Name $Domain -Type $RecordType -Server $DnsServer
        
        if ($result) {
            $result | Format-Table -AutoSize
            Write-Host "`n--- Details ---`n" -ForegroundColor Green
            $result | Format-List *
        } else {
            Write-Host "Keine $RecordType Records gefunden" -ForegroundColor Gray
        }
    }
    
    Write-Host "`nLookup erfolgreich abgeschlossen!" -ForegroundColor Green
    
} catch {
    Write-Host "`nFehler beim DNS Lookup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
