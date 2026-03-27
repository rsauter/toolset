param( [Parameter(Mandatory=$true)]
    [string]$Domain, [Parameter(Mandatory=$false)]
    [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'NS', 'TXT', 'SOA', 'PTR', 'ALL', 'HOSTING')]
    [string]$RecordType = 'A', [Parameter(Mandatory=$false)]
    [string]$DnsServer
)

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
            $ipResults = Resolve-DnsName -Name $Domain -Type A -ErrorAction Stop
            $ipAddresses = $ipResults | Where-Object { $_.Type -eq 'A' } | Select-Object -ExpandProperty IPAddress
            $ipAddresses | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
        } catch {
            Write-Host "  Keine A-Records gefunden" -ForegroundColor Gray
        }
        
        # 2. Nameserver ermitteln
        Write-Host "`n--- Nameserver ---" -ForegroundColor Cyan
        try {
            $nsResults = Resolve-DnsName -Name $Domain -Type NS -ErrorAction Stop
            $nameservers = $nsResults | Where-Object { $_.Type -eq 'NS' } | Select-Object -ExpandProperty NameHost
            $nameservers | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
        } catch {
            Write-Host "  Keine NS-Records gefunden" -ForegroundColor Gray
        }
        
        # 3. WHOIS-ähnliche Info über IP (ISP/Hosting Provider)
        if ($ipAddresses) {
            Write-Host "`n--- IP-Informationen (Hosting Provider) ---" -ForegroundColor Cyan
            foreach ($ip in $ipAddresses) {
                Write-Host "`nIP: $ip" -ForegroundColor Yellow
                try {
                    # Versuche Reverse DNS Lookup
                    $ptrRecord = Resolve-DnsName -Name $ip -Type PTR -ErrorAction SilentlyContinue
                    if ($ptrRecord) {
                        Write-Host "  PTR: $($ptrRecord.NameHost)" -ForegroundColor White
                    }
                    
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
            $soaResult = Resolve-DnsName -Name $Domain -Type SOA -ErrorAction Stop
            Write-Host "  Primary NS: $($soaResult.PrimaryServer)" -ForegroundColor White
            Write-Host "  Responsible: $($soaResult.NameAdministrator)" -ForegroundColor White
        } catch {
            Write-Host "  Keine SOA-Records gefunden" -ForegroundColor Gray
        }
        
    } elseif ($RecordType -eq 'ALL') {
        # Alle gängigen Record-Typen abfragen
        $recordTypes = @('A', 'AAAA', 'CNAME', 'MX', 'NS', 'TXT', 'SOA')
        
        foreach ($type in $recordTypes) {
            Write-Host "`n=== $type Records ===" -ForegroundColor Yellow
            try {
                if ($DnsServer) {
                    $result = Resolve-DnsName -Name $Domain -Type $type -Server $DnsServer -ErrorAction Stop
                } else {
                    $result = Resolve-DnsName -Name $Domain -Type $type -ErrorAction Stop
                }
                $result | Format-Table -AutoSize
            } catch {
                Write-Host "Keine $type Records gefunden" -ForegroundColor Gray
            }
        }
    } else {
        # Spezifischen Record-Typ abfragen
        if ($DnsServer) {
            $result = Resolve-DnsName -Name $Domain -Type $RecordType -Server $DnsServer -ErrorAction Stop
        } else {
            $result = Resolve-DnsName -Name $Domain -Type $RecordType -ErrorAction Stop
        }
        
        $result | Format-Table -AutoSize
        
        # Zusätzliche Details anzeigen
        Write-Host "`n--- Details ---`n" -ForegroundColor Green
        $result | Format-List *
    }
    
    Write-Host "`nLookup erfolgreich abgeschlossen!" -ForegroundColor Green
    
} catch {
    Write-Host "`nFehler beim DNS Lookup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
