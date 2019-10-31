<#
.SYNOPSIS
    Ping hosts to check for response.
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> pingscan.ps1 10.0.0.[1-255]
    This will ping this host range. Explanation of what the example does
.EXAMPLE
    PS C:\> pingscan.ps1 10.0.0.1
    This will ping a single IP Address
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true,
    HelpMessage="Example - 10.0.0.[1-255] or 10.0.0.1")]
    $IPAddress
)

$InformationPreference = "Continue"

function PingIPRange {
    Measure-Command {
    Write-Information ("`nPinging IP Range $FormatIPAddress" + "$IPRangeStart" + ("-") + "$IPRangeEnd")
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
}

function PingIP {
    Measure-Command {
    $IP = $FormatIPAddress
    Write-Information ("`nPinging IP Address $FormatIPAddress")
    $PingIP = Test-Connection -ComputerName $IP -count 1 -Quiet -ErrorAction SilentlyContinue 
    if ($PingIP -eq $true) {
        Write-Information "$IP Host is UP" }
    else {
        Write-Information "$IP Host did not respond"
    }
    } | Select-Object -Property @{label='Seconds';expression={$_.TotalSeconds}}
}

# This needs commenting. Split takes a delimited string and makes an array from it. 
$Seperator = ".""[""-"
$IPAddress | ForEach-Object {
    $IPAddress = $_.split($Seperator)
}

if ($IPAddress -match "^\d{1,3}\]$") { 
    $FormatIPAddress = $IPAddress[0,1,2,3] -join '.'
    [int]$IPRangeStart = $IPAddress[4]
    [int]$IPRangeEnd = $IPAddress[5] -replace "]","" 
    PingIPRange
} if ($IPAddress[3] -match "^\d{1,3}$")  {
    $FormatIPAddress = $IPAddress[0,1,2,3] -join '.' 
    PingIP
}