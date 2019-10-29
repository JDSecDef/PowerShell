<#
.SYNOPSIS
    Ping hosts to check for response.
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> pingscan.ps1 10.0.0.[1-255]
    This will ping this host range. Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [array]$IPAddress
)

$InformationPreference = "Continue"
$Seperator = ".""[""-"

$IPAddress | ForEach-Object {
    $IPAddress = $_.split($Seperator)
    }

$FormatIPAddress = $IPAddress[0,1,2,3] -join '.'
[int]$IPRangeStart = $IPAddress[4]
[int]$IPRangeEnd = $IPAddress[5] -replace '[[\]"]' 

Write-Information ("`nPinging IP Range $FormatIPAddress" + "$IPRangeStart" + ("-") + "$IPRangeEnd")

Measure-Command {
while ($IPRangeStart -le $IPRangeEnd) {
$IP = $FormatIPAddress + $IPRangeStart
$PingIP = Test-Connection -ComputerName $IP -count 1 -Quiet -ErrorAction SilentlyContinue 
    if ($PingIP -eq $true) {
    Write-Information "$IP Host is UP" }
    else {
    Write-Information "$IP Host did not respond"
    }
$IPRangeStart++
} 
} | Select-Object -Property TotalMinutes, TotalSeconds
