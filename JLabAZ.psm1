$hash2 = $json.'JLabTest-Subnet' | ForEach-Object {
    >> $key = $_
    >> [hashtable]@{Name = $key.Name
    >> AddressPrefix = $key.AddressPrefix
    >> }
    >> }

    $json = Get-Content C:\Temp\Untitled-1.json | ConvertFrom-Json

    $hash3 = $json.'JLabTest-VNet' | ForEach-Object {
        >> $key = $_
        >> [hashtable]@{Name = $key.Name
        >> ResourceGroupName = $key.ResourceGroupName
        >> Location = $key.Location
        >> AddressPrefix = $key.AddressPrefix
        >> }
        >> }
        
        # Create Azure VM

# Create a Resource Group
New-AzResourceGroup -Name 'JLabTest-RG' -Location 'australiaeast'
    
# Create a Subnet
$NewSubnetParams = @{
    'Name' = 'JLabTest-Subnet'
    'AddressPrefix' = '10.0.0.0/24'
}
$subnet = New-AzVirtualNetworkSubnetConfig @NewSubnetParams

# Create a Virtual Network
$NewVNetParams = @{
    'Name' = 'JLabTest-vNet'
    'ResourceGroupName' = 'JLabTest-RG'
    'Location' = 'australiaeast'
    'AddressPrefix' = '10.0.0.0/24'
}
$vNet = New-AzVirtualNetwork @NewVNetParams

# Assign IP Address
$NewPublicIPParams = @{
    'Name' = 'JLabTest-PubIP'
    'ResourceGroupName' = 'JLabTest-RG'
    'AllocationMethod' = 'Dynamic' # Dynamic or Static
    'Location' = 'australiaeast'
}
$publicIP = New-AzPublicIpAddress @NewPublicIPParams

# Create Virtual Network Adapter
$NewVNicParams = @{
    'Name' = 'JLabTest-vNIC'
    'ResourceGroupName' = 'JLabTest-RG'
    'Location' = 'australiaeast'
    'SubnetId' = $vNet.Subnets[0].Id
    'PublicIpAddressId' = $publicIP.Id
}
$vNIC = New-AzNetworkInterface @NewVNicParams

# Create a Storage Account
$NewStorageAcctParams = @{
    'Name' = 'JLabTest'
    'ResourceGroupName' = 'JLabTest-RG'
    'Type' = 'Standard_LRS'
    'Location' = 'australiaeast'
}
$StorageAccount = New-AzStorageAccount @NewStorageAcctParams

# Create OS Image
$NewConfigParams = @{
    'VMName' = 'JLabTest-VM'
    'VMSize' = 'Standard_B1ms'
}
$VmConfig = New-AzVMConfig @NewConfigParams

$NewVMOsParams = @{
    'Windows' = $true
    'ComputerName' = 'AutoVM'
    'Credential' = (Get-Credential -Message 'Type the name and password of the local administrator account.')
    'EnableAutoUpdate' = $true
    'VM' = $VmConfig
}
$VM = Set-AzVMOperatingSystem @NewVMOsParams

# Get list of Publishers
Get-AzVMImagePublisher

$Offer = Get-AzVMImageOffer -Location 'australiaeast' -PublisherName 'MicrosoftWindowsServer' | Where-Object { $_.Offer -eq 'WindowsServer' }

$NewSourceImageParams = @{
    'PublisherName' = 'MicrosoftWindowsServer'
    'Version' = 'Latest'
    'Skus' = '2012-R2-Datacenter'
    'VM' = $VM
    'Offer' = $Offer.Offer
}
$VM = Set-AzVMSourceImage @NewSourceImageParams

$OSDiskName = 'JLabTest-Disk'
$OSDiskURI = '{0}vhds/JLabTest-VM{1}.vhd' -f $StorageAccount.PrimaryEndpoints.Blob.ToString(), $OSDiskName

$VM = Set-AzVMOSDisk -Name OSDisk -CreateOption 'fromimage' -VM $VM -VhdUri $OSDiskURI

# Attach vNIC
$VM = Add-AzVMNetworkInterface -VM $VM -Id $vNIC.Id

# Create VM
New-AzVM -VM $VM -ResourceGroupName 'JLabTest-RG' -Location 'australiaeast' -Verbose
