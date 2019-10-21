# This script pings an IP Range to check if hosts are up 

$IPAddress = Read-Host "`nEnter IP Address Range to scan"
$Seperator = ".""[""-"
$IPAddress | ForEach-Object {
    $IPAddress = $_.split($Seperator)
    }

$FormatIPAddress = $IPAddress[0,1,2,3] -join '.'
[int]$IPRangeStart = $IPAddress[4]
[int]$IPRangeEnd = $IPAddress[5] -replace '[[\]"]' 

Write-Host ("`nPinging IP Range $FormatIPAddress" + "$IPRangeStart" + ("-") + "$IPRangeEnd") -ForegroundColor Yellow

Measure-Command {
while ($IPRangeStart -le $IPRangeEnd) {
$IP = $FormatIPAddress + $IPRangeStart
$PingIP = Test-Connection -ComputerName $IP -count 1 -Quiet -ErrorAction SilentlyContinue 
    if ($PingIP -eq $true) {
    write-host "$IP Host is UP" -ForegroundColor Green }
    else {
    write-host "$IP Host did not respond" -ForegroundColor Red
    }
$IPRangeStart++
} 
} | Select-Object -Property TotalMinutes, TotalSeconds
