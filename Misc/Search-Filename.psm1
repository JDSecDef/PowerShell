function Search-Filename {
    <#
    .SYNOPSIS
    Search for files using multiple search words1.   
    
    .DESCRIPTION
    This command searches for files using one or more search words. It allows the use of wildcards (*)
    and stringing together multiple search words in a single search. The command must be run as a user
    who has access to the files being searched. 
    
    .PARAMETER SearchPath
    Provide a folder path or fileshare to search. 

    .PARAMETER SaveOutputPath
    Provide a folder path and filename to save the output to. 

    .PARAMETER SearchWord
    Provide one or more search words to use as the search criteria. If no search words are provided than
    the default search words will be used - "*password*","*protected*","*.mp4","*.exe","*dvd*","*secret*",
    "*.bat","*.kbdx","*.ps1".

    .EXAMPLE
    PS C:\> Search-Filename -Path C:\ -Keywords "*.txt","*.csv","*sensitive*"'
    This will recursively search the C:\ for filenames containing the provided keywords.     
    
    .NOTES
    Version     : 1.0.1
    Last Updated: 15 September 2021
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true, HelpMessage = 'Example - Search-Filename -FilePath C:\ -SavePath C:\Temp\output.csv -Keywords "*.txt","*.csv","*sensitive*"')]
        [Alias('SearchPath')]
        [String]$FilePath,
        [Alias('SaveOutputPath')]
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [String]$SavePath,
        [Alias('SearchWord')]
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
                Write-Verbose "Searching $FilePath for files matching $SearchWords"
                $SearchResults = Get-ChildItem $FilePath -Recurse -include $SearchWords | 
                Select-Object -Property @{Name = 'Directory'; expression = { $_.DirectoryName } },
                                        @{Name = 'Filename'; expression = { $_.Name } },
                                        @{Name = "Owner"; expression = { (Get-ACL $_.Fullname).Owner } },
                                        @{Name = 'Size(bytes)'; expression = { [Math]::Round($_.Length, 2) } }
            } # If
            Else {
                Write-Information "$FilePath does not exist"
            } # Else
        } # Try
        catch {
        } # Catch
        Finally {
            Write-Output $SearchResults
            $SearchResults | Out-File $SavePath -Append
        } # Finally 
    } # Process
    End {}
} # Function