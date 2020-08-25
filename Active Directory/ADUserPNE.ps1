# Script to list enabled user accounts with passwords set never to expire.

Import-Module ActiveDirectory
$date = Get-Date -Format dd-MM-yyyy

Get-ADUser -filter {Enabled -eq $True -and PasswordNeverExpires -eq $True} -Properties Name, PasswordNeverExpires | 
Select-Object -Property Name, PasswordNeverExpires | Export-Csv "C:\Temp\PNE_$date.csv"