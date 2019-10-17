# This script pings an IP Range to check if hosts are up 

$ipaddress = @()
$enterip = Read-Host "`nEnter IP Address Range to scan"
$seperator = ".""[""-"
$enterip | foreach {
    $ipaddress = $_.split($seperator)
    }

$ipaddress1 = $ipaddress[0,1,2,3] -join '.'
[int]$iprangestart = $ipaddress[4]
[int]$iprangeend = $ipaddress[5] -replace '[[\]"]' 

Write-Host ("`nPinging IP Range $ipaddress1" + "$iprangestart" + ("-") + "$iprangeend") -ForegroundColor Yellow

Measure-Command {
while ($iprangestart -le $iprangeend) {
$ip = $ipaddress1 + $iprangestart
$test = Test-Connection -ComputerName $ip -count 1 -Quiet -ErrorAction SilentlyContinue 
    if ($test -eq $true) {
    write-host "$ip Host is UP" -ForegroundColor Green }
    else {
    write-host "$ip Host did not respond" -ForegroundColor Red
    }
$iprangestart++
} 
} | select -Property TotalMinutes, TotalSeconds
