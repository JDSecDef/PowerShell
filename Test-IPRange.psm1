function Test-IPRange {
    <#
 .SYNOPSIS
    Ping IP addresses to check if hosts are responsive. 
.DESCRIPTION
    Long description
.PARAMETER IPAddress
    Provide an IP Address.
.EXAMPLE
    PS C:\> pingscan.ps1 10.0.0.[1-255]
    This will ping this host range. Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    Version     : 1.0.0
    Last Updated: 9 November 2019
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeLine = $true,
            Mandatory = $true,
            HelpMessage = "Example - 10.0.0.[1-255], 10.0.0.1 or 10.0.0.0/24")]
        [Alias('Ping')]
        [String]$IPAddress,
        [Int]$Timeout = 100
        # CIDR input parameter
        # Computer Name parameter
        # TODO
    )
    BEGIN {
        $InformationPreference = "Continue"
        $Ping = New-Object system.net.networkinformation.ping
        $IPSeperator = "[""-""]"
        #[switch]$resolve = $true
        #[int]$TTL = 128
        #[switch]$DontFragment = $false
        #[int]$buffersize = 32
        #$options = new-object system.net.networkinformation.pingoptions
        #$options.TTL = $TTL
        #$options.DontFragment = $DontFragment
        #$buffer=([system.text.encoding]::ASCII).getbytes("a"*$buffersize)	
    }
    PROCESS {
        $IPAddress | ForEach-Object {
            $IPSplit = $_.split($IPSeperator)
        }
        [string]$FormatIPAddress = $IPSplit[0]
        [int]$IPRangeStart = $IPSplit[1]
        [int]$IPRangeEnd = $IPSplit[2] 
        Write-Host ("`nPinging IP Range $FormatIPAddress" + "$IPRangeStart" + ("-") + "$IPRangeEnd")
        while ($IPRangeStart -le $IPRangeEnd) {
            $IP = $FormatIPAddress + $IPRangeStart
            $PingIP = $Ping.Send($IP, $Timeout)
            switch ($PingIP.Status) {
                "Success" { $Status = "Host is UP" }
                "TimedOut" { $Status = "Host is Unreachable" }
                Default { $Status = "Host is Unreachable" }
            }
            $Props = [PSCustomObject]@{
                'ComputerHost'   = $IP
                'Response'       = $Status
                "ResponseTimeMS" = $PingIP.RoundtripTime
            }
            $IPRangeStart++
            $Obj = [PSCustomObject]$Props
            Write-Output $Obj
        } 
    }
    END { }
}
