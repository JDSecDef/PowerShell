# Script to display badPwdCount and badPasswordTime

Import-Module ActiveDirectory
$date = Get-Date -Format dd-MM-yyyy

Get-ADUser -filter {Enabled -eq $True -and badPwdCount -gt 1} -Properties Name, badPwdCount, badPasswordTime | 
Select-Object -Property Name, badPwdCount, @{N='badPasswordTime'; E={[DateTime]::FromFileTime(($_.badPasswordTime))}} |
Export-Csv "C:\Temp\badpwd_$date.csv"