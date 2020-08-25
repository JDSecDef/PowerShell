# Script to discover domain controllers

Import-Module Active Directory

$dc = Get-ADDomainController -filter * | Select-Object Hostname, Enabled, IPv4Address,
OperatingSystem, OperatingSystemVersion, OperationMasterRoles
$dc | Write-Output