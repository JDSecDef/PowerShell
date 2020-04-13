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
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(ValueFromPipeline = $true,
        Mandatory = $true,
        HelpMessage = 'Please provide a JSON file')]
        [String]$FilePathJson
    )
    
    BEGIN {
        Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
        $InformationPreference = "Continue"
        $Connection = Get-AzContext 
        $OSDiskName = 'DC1Disk'
        $JsonFile = Get-Content $FilePathJson | ConvertFrom-Json
        $RGandLocation = $JsonFile.'JLab-RGandLocation' | ForEach-Object {
            $Key = $_ 
            [hashtable] @{Name = $Key.Name
                ResourceGroupName = $Key.ResourceGroupName
                Location = $Key.Location 
            }
        }
        $SubnetParameters = $JsonFile.'JLab-Subnet' | ForEach-Object {
            $Key = $_ 
            [hashtable] @{Name    = $Key.Name 
                AddressPrefix     = $Key.AddressPrefix
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
            }
        }
        $StorageAccountParameters = $JsonFile.'JLab-StorageAccount' | ForEach-Object {
            $Key = $_
            [hashtable] @{Name    = $Key.Name
                ResourceGroupName = $Key.ResourceGroupName
                Type              = $Key.Type
                Location          = $Key.Location
            }
        }
        $VMConfigParameters = $JsonFile.'JLab-VMConfig' | ForEach-Object {
            $Key = $_
            [hashtable] @{VMName    = $Key.VMName
                VMSize              = $Key.VMSize
            }
        }
        $VMOSParameters = $JsonFile.'JLab-VMParameters' | ForEach-Object {
            $Key = $_
            [hashtable] @{Windows = [boolean]$Key.Windows
                ComputerName      = $Key.ComputerName
            }
        }
        $VMImageParameters = $JsonFile.'JLab-ImageParameters' | ForEach-Object {
            $Key = $_
            [hashtable] @{PublisherName = $Key.PublisherName
                Version                 = $Key.Version
                Skus                    = $Key.Skus
            }
        }
        $Offer = Get-AzVMImageOffer -Location $RGandLocation.Location -PublisherName 'MicrosoftWindowsServer' | Where-Object { $_.Offer -eq 'WindowsServer' }
    } # BEGIN 

    PROCESS {
        try {
            
            # Check if user is authenticated to Azure, if not prompt user to login.
            # Currently not working
            if ($null -eq $Connection) {
                Connect-AzAccount -ErrorAction Ignore
            } else {
                Write-Verbose "$($Connection.Account.ID) is authenticated to Azure." 
            }

            if (Get-AzVM -Name $VMConfigParameters.VMName -ResourceGroupName $RGandLocation.ResourceGroupName -ErrorAction Ignore) {
                Write-Verbose "The Azure VM $($VMOSParameters.ComputerName) already exists. Exiting"
            } else {

                # Check if Azure Resource Group already exists, if not create a new Azure Resource Group.
                if (-not (Get-AzResourceGroup -name $RGandLocation.ResourceGroupName -Location $RGandLocation.Location -ErrorAction Ignore)) {
                    Write-Verbose "Creating Azure Resource Group with the name $($RGandLocation.ResourceGroupName) in $($RGandLocation.Location)"
                    $null = New-AzResourceGroup -Name $RGandLocation.ResourceGroupName -Location $RGandLocation.Location
                } else {
                    Write-Verbose "$($RGandLocation.ResourceGroupName) already exists"
                }
            
                # Check if Virtual Network already exists, if not create it.     
                if (-not ($NewVNet = Get-AzVirtualNetwork -Name $VNetParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName -ErrorAction Ignore)) {
                    Write-Verbose "Creating Subnet $($SubnetParameters.Name)"
                    $NewSubnet = New-AzVirtualNetworkSubnetConfig @SubnetParameters -Verbose
                    Write-Verbose "Creating Virtual Network Name $($VNetParameters.Name)"
                    $NewVNet = New-AzVirtualNetwork @VNetParameters -Subnet $NewSubnet
                } else {
                    Write-Verbose "$($VNetParameters.Name) already exists"
                }

                # Check if public IP address exists, if not create it. 
                if (-not ($NewPublicIP = Get-AzPublicIpAddress -Name $PublicIPParameters.Name -ResourceGroupName $PublicIPParameters.ResourceGroupName -ErrorAction Ignore)) {
                    Write-Verbose "Creating public IP address $($PublicIPParameters.Name)"
                    $NewPublicIP = New-AzPublicIpAddress @PublicIPParameters
                } else {
                    Write-Verbose "Public IP address $($PublicIPParameters.Name) already exists"
                }

                # Check if VNIC exists, if not create it. 
                if (-not ($NewVNIC = Get-AzNetworkInterface -Name $VNICParameters.Name -ResourceGroupName $VNICParameters.ResourceGroupName -ErrorAction Ignore)) {
                    Write-Verbose "Creating $($VNICParameters.Name)"
                    $VNICParameters.SubnetId = $NewVNet.Subnets[0].Id
                    $VNICParameters.PublicIpAddressId = $NewPublicIP.Id
                    $NewVNIC = New-AzNetworkInterface @VNICParameters
                } else {
                    Write-Verbose "$($VNICParameters.Name) already exists"
                }  

                #if ($VNIC = Get-AzNetworkInterface -Name $VNICParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName) {
                #    $PubIP = Get-AzPublicIpAddress -Name $PublicIPParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName
                #    $VNIC | Set-AzNetworkInterfaceIpConfig -Name DC1  -PublicIpAddress $PubIP -Subnet $NewSubnet
                #    Write-Verbose "Assigning Public IP Address $($PublicIPParameters.Name) to $($VMConfigParameters.VMName)"
                #    $VNIC | Set-AzNetworkInterface
                #}
                # Test

                # Check if storage account exists, if not create it.
                # -whatif currently not working. 
                # Storage account can take a while to be recgonised when creating VM. 5 minutes??
                if (-not ($NewStorageAccount = (Get-AzStorageAccount).where( { $_.StorageAccountName -eq $StorageAccountParameters.Name }))) {
                    Write-Verbose "Creating $($StorageAccountParameters.Name) storage account"
                    $NewStorageAccount = New-AzStorageAccount @StorageAccountParameters
                } else {
                    Write-Verbose "$($StorageAccountParameters.Name) already exists"
                }

                $NewVMConfig = New-AzVMConfig @VMConfigParameters
                $VMOSParameters.Credential = Get-Credential -Message 'Enter the name and password the local administrator account:'
                $VMOSParameters.VM = $NewVMConfig
                $NewVMOS = Set-AzVMOperatingSystem @VMOSParameters
                $VMImageParameters.VM = $NewVMOS
                $VMImageParameters.Offer = $Offer.Offer
                $NewVM = Set-AzVMSourceImage @VMImageParameters

                # Check storage, will fail if storage already exists. ErrorCode: TargetDiskBlobAlreadyExists
                # New-AzVM : Long running operation failed with status 'Failed'. Additional Info:'Blob https://jlabstorageaccount.blob.core.windows.net/vhds/DC1Disk.vhd already exists. Please provide a different blob URI as 
                # target for disk 'DC1Disk'.
                Write-Verbose "Setting OSDISKURI"
                $OSDiskURI = '{0}vhds/{1}{2}.vhd' -f $NewStorageAccount.PrimaryEndpoints.Blob.ToString(), $VMConfigParameters.Name, $OSDiskName
            
                Write-Verbose "Setting OS Disk Properties for $($OSDiskName)"
                $NewVM = Set-AzVMOSDisk -Name $OSDiskName -CreateOption 'fromimage' -VM $NewVM -VhdUri $OSDiskURI
            
                Write-Verbose "Adding $($VNICParameters.Name) to $($VMOSParameters.ComputerName)"
                $NewVM = Add-AzVMNetworkInterface -VM $NewVM -Id $NewVNIC.Id

                # ErrorMessage: Storage account 'jlabstorageaccount' not found. Ensure storage account is not deleted and belongs to the same Azure location as the VM.
                # ErrorCode: StorageAccountNotFound
                Write-Verbose "Creating VM $($VMOSParameters.ComputerName)"
                New-AzVM -VM $NewVM -ResourceGroupName $RGandLocation.ResourceGroupName -Location $RGandLocation.Location
            }
            } # try
            catch { 
                [Microsoft.Azure.Commands.Profile.ConnectAzureRmAccountCommand]
                [Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]
                Write-Information "`nYou failed to authenticate to Azure."
            } # catch
            finally {
            } # finally
        } #PROCESS
        END { }
} #Function