# This script pings an IP Range to check if hosts are up 

$subnet = Read-Host -prompt "`nEnter IP block"
[int]$ipstart = Read-Host -Prompt "Enter the start IP address"
[int]$ipend = Read-Host -Prompt "Enter the End IP address"
[int]$delay = 500

Write-Host ("`nPinging IP Range $subnet" + (".") + "$ipstart" + ("-") + "$ipend") -ForegroundColor Yellow

Measure-Command {
while ($ipstart -le $ipend) {
$ip = $subnet + (".") + $ipstart
$test = Test-Connection -ComputerName $ip -count 1 -Quiet -ErrorAction SilentlyContinue 
    if ($test -eq $true) {
    write-host "$ip Host is UP" -ForegroundColor Green }
    else {
    write-host "$ip Host did not respond" -ForegroundColor Red
    }
$ipstart++
} 
} | select -Property TotalMinutes, TotalSeconds
