function Test-IPRange {
    <#
 .SYNOPSIS
    Ping IP addresses to check if hosts are responsive. 
.DESCRIPTION
    Long description
.PARAMETER IPRange
    Provide an IP Address.
.PARAMETER Timeout
    Provide a ping response timeout. 
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
        [String]$IPRange,
        [Int]$Timeout = 100
        # Validate parameters
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
    } # Begin

    PROCESS {
        Write-Verbose 'Splitting IP address into array'
        $IPRange | ForEach-Object {
            $IPSplit = $_.split($IPSeperator)
        } # Foreach
        [string]$FormatIPRange = $IPSplit[0]
        [int]$IPRangeStart = $IPSplit[1]
        [int]$IPRangeEnd = $IPSplit[2] 
        Write-Information ("`nPinging IP Range $FormatIPRange" + "$IPRangeStart" + ("-") + "$IPRangeEnd")
        while ($IPRangeStart -le $IPRangeEnd) {
            $IP = $FormatIPRange + $IPRangeStart
            Write-Verbose "Sending Ping to $IP"
            $PingIP = $Ping.Send($IP, $Timeout)
            switch ($PingIP.Status) {
                'Success' { $Status = 'Host is UP' }
                'TimedOut' { $Status = 'Host is Unreachable' }
                Default { $Status = 'Host is Unreachable' }
            } # Switch
            $Props = [PSCustomObject]@{
                'TargetHost'     = $IP
                'Response'       = $Status
                'ResponseTimeMS' = $PingIP.RoundtripTime
            } # PSCustomObject
            $IPRangeStart++
            $Obj = [PSCustomObject]$Props
            Write-Output $Obj
        } # While  
    } # Process 
    END { }
} # Function