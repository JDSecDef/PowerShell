# Script to display recently created user accounts and groups.

Import-Module ActiveDirectory
$date = Get-Date -Format dd-MM-yyyy
$when = ((Get-Date).AddDays(-1)).Date

Get-ADUser -Filter {WhenCreated -ge $when} -Properties WhenCreated, Name, objectClass |
Select-Object -Property Name, objectClass, WhenCreated | Export-Csv "C:\Temp\creationdate_$date.csv"

Get-ADGroup -Filter {WhenCreated -ge $when} -Properties WhenCreated, Name, objectClass |
Select-Object -Property Name, objectClass, WhenCreated | Export-Csv "C:\Temp\creationdate_$date.csv" -Append -noType -Force