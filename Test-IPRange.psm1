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
    [Parameter(ValueFromPipeline=$true,
        Mandatory=$true,
        HelpMessage = "Example - 10.0.0.[1-255], 10.0.0.1 or 10.0.0.0/24")]
    [Alias('ping')]
    [string]$IPAddress
    # CIDR input parameter
    # Computer Name parameter
    # TODO
)

$InformationPreference = "Continue"

    [int]$Timeout = 100
    #[switch]$resolve = $true
    #[int]$TTL = 128
    #[switch]$DontFragment = $false
    #[int]$buffersize = 32
    #$options = new-object system.net.networkinformation.pingoptions
    #$options.TTL = $TTL
    #$options.DontFragment = $DontFragment
    #$buffer=([system.text.encoding]::ASCII).getbytes("a"*$buffersize)	
    $Ping = New-Object system.net.networkinformation.ping

function PingIPRange {
    Write-Information ("`nPinging IP Range $FormatIPAddress" + "$IPRangeStart" + ("-") + "$IPRangeEnd")
    while ($IPRangeStart -le $IPRangeEnd) {
        $IP = $FormatIPAddress + $IPRangeStart
        $PingIP = $Ping.Send($IP,$Timeout)
        #$buffer,$options)
        switch ($PingIP.Status) {
            "Success" { $Status = "Host is UP" }
            "TimedOut" { $Status = "Host is Unreachable" }
            Default { $Status = "Host is Unreachable" }
        }
        $Props = [PSCustomObject]@{
            'ComputerHost' = $IP
            'Response'  = $Status
            "ResponseTimeMS" = $PingIP.RoundtripTime
        }
        $IPRangeStart++
        $Obj = [PSCustomObject]$Props
        Write-Output $Obj
    } 
}

function PingIP { 
    $PingIP = $Ping.Send($IPAddress,$Timeout)
    Write-Information ("`nPinging IP Address " + $PingIP.Address)
    switch ($PingIP.Status) {
        "Success" { $Status = "Host is UP" }
        "TimedOut" { $Status = "Host is Unreachable" }
        Default { $Status = "Host is Unreachable" }
     
    }
    $Props = [PSCustomObject]@{
        'Host' = $PingIP.Address
        'Response'  = $Status
        "ResponseTime" = $PingIP.RoundtripTime
    }
    $Obj = [PSCustomObject]$Props 
    Write-Output $Obj
} 

# This needs commenting. Split takes a delimited string and makes an array from it. 
$Seperator = "[""-""]"
if ($IPAddress -match "\]$") { 
    $IPAddress | ForEach-Object {
        $IPSeperate = $_.split($Seperator)
    }
    [string]$FormatIPAddress = $IPSeperate[0]
    [int]$IPRangeStart = $IPSeperate[1]
    [int]$IPRangeEnd = $IPSeperate[2] 
    PingIPRange
}
if ($IPAddress -match "\d{1,3}$")  {
    PingIP
}
