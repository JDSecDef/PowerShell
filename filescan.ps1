# This script scans for file names using different search criteria. 
# NOTE - Scanning a large amount of files can take a long time.

$usersearch = @()
$defaultsearch =@("*password*","*protected*","*.mp4","*.exe","*dvd*","*secret*","*.bat","*.kbdx","*.ps1")

Write-Host "`nThis script scans file shares searching filenames" -Foregroundcolor Yellow

$scanlocation = Read-Host -Prompt "`nEnter the folder path to scan"

# Test if $scanlocation is a valid path, if it is continue, if not exit. 
if (Test-Path $scanlocation) {
    Write-Host "`nTarget folder exists: $scanlocation `n" -ForegroundColor Green
} else {
    Write-Host "`nFolder path does not exist:" $scanlocation -ForegroundColor Red
  exit
}

# Display menu options. 
do {
$menuresponse = Read-Host ("1. Show default search criteria`n2. Use default search criteria`n3. Enter custom search criteria`n4. Exit`n`nChoose an option")
    if ($menuresponse -eq '1') {Write-Host "`nDefault search terms: $defaultsearch `n" -ForegroundColor Green}
    if ($menuresponse -eq '2') {break}
    if ($menuresponse -eq '3') {break}
    if ($menuresponse -eq '4') {exit}
} until ($menuresponse -eq '2','3')

# Build $usersearch array with search criteria.
If ($menuresponse -eq '3') {
    do {
        $searchterms = Read-Host ('Enter search terms including wild cards one at a time. Enter Q when done') 
    if ($searchterms -ne 'q') {$usersearch += $searchterms}
    Write-Host "Current search criteria:" $usersearch -ForegroundColor Green
    } until ($searchterms -eq 'q')
}

# Use default search criteria to search folder path. 
if ($menuresponse -eq '2') {
    Write-Host "`nScanning the following location: $scanlocation for filenames containing: $defaultsearch" -ForegroundColor Yellow
    $searchresults = Get-ChildItem $scanlocation -ErrorAction SilentlyContinue -Recurse -include $defaultsearch | Foreach-Object {$_.FullName}
}

# Use custom search criteria to search folder path. 
if ($menuresponse -eq '3'){ 
$searchresults = Get-ChildItem $scanlocation -ErrorAction SilentlyContinue -Recurse -include $usersearch | Foreach-Object {$_.FullName} 
}

# Show search results. 
if ($searchresults -eq $null) {
    Write-Host "`nNo Search Results" -ForegroundColor Red
} else {
    Write-Host "`nSearch Results`n" -ForegroundColor Red
    $searchresults | Write-Output
}

# Prompt user to save results to file. 
$saveresponse = Read-Host -Prompt "`nSave results to file? [Y/N]"
do {
    if ($saveresponse -eq 'y') { 
        $savelocation = Read-Host -Prompt "`n Enter the save location" 
    } else {
        Write-Host "`nExiting" -ForegroundColor Red
        exit
    }
    if ($saveresponse -eq 'y') {
        if (Test-Path $savelocation) {
        Write-Host "`nFolder path exists: $savelocation" -ForegroundColor Green
        $savename = Read-Host -Prompt "`n Enter the filename and extension"
        $savelocation += $savename
        $Searchresults | Out-File $savelocation -append
        Write-Host "`nSaving file to " $savelocation -ForegroundColor Green
        exit 
    } else {Write-Host "`nFolder path does not exist: $savelocation" -ForegroundColor Red}
    } 
}until ($saveresponse -eq 'n')
