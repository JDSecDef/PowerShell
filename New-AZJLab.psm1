function New-AZJLab {
<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
.INPUTS
    Inputs to this cmdlet (if any)
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
.COMPONENT
    The component this cmdlet belongs to
.ROLE
    The role this cmdlet belongs to
.FUNCTIONALITY
    The functionality that best describes this cmdlet
#>

    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true,
        Mandatory = $true,
        HelpMessage = 'Please provide a JSON file')]
        [String]$FilePathJson
    )
    
    BEGIN {
        $InformationPreference = "Continue"
        $JsonFile = Get-Content $FilePathJson | ConvertFrom-Json
        $SubnetParameters = $JsonFile.'JLab-Subnet' | ForEach-Object {
            $Key = $_ 
            [hashtable] @{Name = $Key.Name 
                AddressPrefix  = $Key.AddressPrefix
            }
        }
        $VNetParameters = $JsonFile.'JLab-VNet' | ForEach-Object {
            $Key = $_
            [hashtable] @{Name    = $Key.Name
                ResourceGroupName = $Key.ResourceGroupName
                Location          = $Key.Location
                AddressPrefix     = $Key.AddressPrefix
            }
        }
        $PublicIPParameters = $JsonFile.'JLab-PubIP' | ForEach-Object {
            $Key = $_
            [hashtable] @{Name    = $Key.Name
                ResourceGroupName = $Key.ResourceGroupName
                AllocationMethod  = $key.AllocationMethod
                Location          = $key.Location
            }
        }
        $VNICParameters = $JsonFile.'JLab-VNIC' | ForEach-Object {
            $Key = $_
            [hashtable] @{Name    = $Key.Name
                ResourceGroupName = $Key.ResourceGroupName
                Location          = $Key.Location
                SubnetID          = $Key.SubnetID
                PublicIPAddressID = $Key.PublicIPAddressID
            }
        }
        $StorageAccountParameters = $JsonFile.'JLab-StorageAccount' | ForEach-Object {
            $Key = $_
            [hashtable] @{Name    = $Key.name
                ResourceGroupName = $Key.ResourceGroupName
                Type              = $Key.Type
                Location          = $Key.Location
                #test
            }
        }
    } #BEGIN 

    PROCESS {
        # Check for connection to azure. 
        # Check to see if Resource Group already exists.
        # Only one VM should have a Public IP. 
        Write-Information '###$SubnetParameters##'
        $SubnetParameters
        Write-Information '###$VnetParamters###'
        $VNetParameters
        Write-Information '###$PublicIPParamters###'
        $PublicIPParameters  
        Write-Information '###$VNICParameters###'
        $VNICParameters
        Write-Information '###$StorageAccountParameters###'
        $StorageAccountParameters
    } #PROCESS
    END {}
} #Function

<## Create a Resource Group
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
New-AzVM -VM $VM -ResourceGroupName 'JLabTest-RG' -Location 'australiaeast' -Verbose#>