function Search-Filename {
    <#
    .SYNOPSIS
    Search files for matching key words. 
    
    .DESCRIPTION
    Long description
    
    .PARAMETER Path
    Provide a filepath to search.

    .PARAMETER Keyword
    Provide one or more keywords to use as the search criteria. 

    .EXAMPLE
    PS C:\> Search-Filename -Path C:\ -Keywords "*.txt","*.csv","*sensitive*"'
    This will recursively search the C:\ for filenames containing the provided keywords.     
    
    .NOTES
    Version     : 1.0.0
    Last Updated: 15 November 2019
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true,
                   Mandatory = $true,
                   HelpMessage = 'Example - Search-Filename -Path C:\ -Keywords "*.txt","*.csv","*sensitive*"')]
        [Alias('Path')]
        [String]$FilePath,
        [Alias('Keyword')]
        [String[]]$SearchWords = ("*password*","*protected*","*.mp4","*.exe","*dvd*","*secret*","*.bat","*.kbdx","*.ps1")
    )
    
    BEGIN {
        $InformationPreference = "Continue"
    }

    PROCESS {
        try {
            Write-Verbose "Testing $FilePath is accessible"
            If (Test-Path $FilePath) {
                Write-Verbose "$FilePath accessible"
                $SearchResults = Get-ChildItem $FilePath -Recurse -include $SearchWords | 
                Select-Object -Property @{Name='Directory';expression={$_.DirectoryName}},
                                        @{Name='Filename';expression={$_.Name}},
                                        @{Name="Owner";expression={(Get-ACL $_.Fullname).Owner}},
                                        @{Name='Size(bytes)';expression={[Math]::Round($_.Length,2)}}
            } Else {
                Write-Information "$FilePath does not exist"
            } # If
        } catch {
            # Nothing
        } Finally {
            Write-Output $SearchResults
        }
    } # Process
    End {}
} # Function
