# Script to display the last logon time of enabled user accounts.

Import-Module ActiveDirectory
$date = Get-Date -Format dd-MM-yyyy

Get-ADUser -filter {Enabled -eq $True} -Properties Name, LastLogon | 
Select-Object -Property Name, @{N='LastLogon'; E={[DateTime]::FromFileTime(($_.LastLogon))}} |
Export-Csv "C:\Temp\lastlogon_$date.csv"