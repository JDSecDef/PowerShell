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

<#
    TODO
    * AutoConnect Switch: Once VM is created run RDP and connect. Start-Process mstsc.exe -ArgumentList "/v:10.10.10.10"
    * RecreateVM Switch: Public IP Address removal? 
    * Update VM output details to include IP addresses. 
    * Add password requirement details to Get-Credential. 
    * Investigate the $offer line in the script. 
    * Update help section. 
    * For storage context you have to check if the storage account exists first.
    * Investigate the storage not found error if the storage account was created in this function. 
        # ErrorMessage: Storage account 'jlabstorageaccount' not found. Ensure storage account is not deleted and belongs to the same Azure location as the VM.
#>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = 'Please provide a JSON file')]
        [string]$FilePathJson,
        [Parameter(Mandatory = $false)]
        [switch]$SetPublicIP,
        [Parameter(Mandatory = $false,
            HelpMessage = 'Set VM Powerstate to Stopped or Running')]
        [string]$VMPowerState = 'Running',
        [Parameter(Mandatory = $false,
            HelpMessage = 'This recreates a VM and its vhd if it already exists.')]
        [Switch]$RecreateVM
    )
    
    BEGIN {
        Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
        $InformationPreference = "Continue"
        $Connection = Get-AzContext 
        $JsonFile = Get-Content $FilePathJson | ConvertFrom-Json

        # Create hashtables from JSON file. 
        $RGandLocation = $JsonFile.'JLab-RGandLocation' | ForEach-Object {
            $Key = $_ 
            [hashtable] @{Name    = $Key.Name
                ResourceGroupName = $Key.ResourceGroupName
                Location          = $Key.Location 
            }
        }
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
            [hashtable] @{VMName = $Key.VMName
                VMSize           = $Key.VMSize
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

        # Check if user is authenticated to Azure, if not prompt user to login.
        if ($null -eq $Connection) {
            Write-Information "Please enter your Azure credentials"
            (Connect-AzAccount -ErrorAction Stop)
        } else {
            Write-Verbose "$($Connection.Account.ID) is authenticated to Azure." 
        }

        # Check if a VM already exists with the same name. 
        $CheckVM = Get-AzVM -Name $VMConfigParameters.VMName -ResourceGroupName $RGandLocation.ResourceGroupName -ErrorAction Ignore
        if ($CheckVM.Name -eq $VMConfigParameters.VMName -and $RecreateVM) {
            Write-Verbose "Recreating $($VMOSParameters.ComputerName) in Resource Group $($RGandLocation.ResourceGroupName)."
            $BuildVM = $true
        }
        elseif ($null -eq $CheckVM.Name -and $RecreateVM) {
            Write-Verbose "$($VMConfigParameters.VMName) does not exist and the RecreateVM Switch is set. Try running module without the RecreateVM Switch. Exiting."
            exit
        }
        elseif ($CheckVM.Name -eq $VMConfigParameters.VMName -and $RecreateVM -eq $false) {
            Write-Verbose "An Azure VM with the name $($VMOSParameters.ComputerName) in Resource Group $($RGandLocation.ResourceGroupName) already exists. Exiting."
            exit
        } else {
            Write-Verbose "A VM with the name $($VMConfigParameters.VMName) will be created in $($VMOSParameters.ComputerName) Resource Group."
        }

        $Offer = Get-AzVMImageOffer -Location $RGandLocation.Location -PublisherName 'MicrosoftWindowsServer' | Where-Object { $_.Offer -eq 'WindowsServer' }

        # Set URI for the VHD for the Set-AZVMOSDisk cmdlet. 
        $OSDiskName = $VMOSParameters.ComputerName + "Disk"

        # Check if the Virtual Network Interface is aready associated to another VM. 
        $CheckVMNIC = Get-AzNetworkInterface -Name $VNICParameters.Name | Select-Object -Property VirtualMachine -ErrorAction Ignore
        if ($null -ne $CheckVMNIC.VirtualMachine.Id -and $RecreateVM -eq $false) {
            Write-Verbose "$($VNICParameters.Name) is already associated to $($CheckVMNIC.VirtualMachine.Id). VM will not be created. Exiting."
            exit
        }

        # Check Public IP Address. 
        $PubIPCheck = Get-AzPublicIpAddress -Name $PublicIPParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName -ErrorAction Ignore
        if ($PubIPCheck.Name -eq $PublicIPParameters.Name -and $RecreateVM) {
            Write-Verbose "$($PubIPCheck.Name) will be recreated."
        }
        elseif ($null -eq $PubIPCheck -and $RecreateVM) {
            Write-Verbose "$($PubIPCheck.Name) does not exist and the RecreateVM Switch is set. Try running module without the RecreateVM Switch. Exiting."
            exit
        } 
        elseif ($SetPublicIP) {
            Write-Verbose "$($PubIPCheck.Name) Public IP Address will be created and associated to $($VMConfigParameters.VMName)."
        }

        # Retreive storage account key. 
        Write-Verbose "Retrieving Storage Account Key for $($StorageAccountParameters.Name)"
        $StorageKey = Get-AzStorageAccountKey -ResourceGroupName $RGandLocation.ResourceGroupName -AccountName $StorageAccountParameters.Name
        $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountParameters.Name -StorageAccountKey $StorageKey.Value[1]
        $StorageBlob = Get-AzStorageBlob -Context $StorageContext -Container vhds -ErrorAction Ignore
                            
        # Check if the OS Disk already exists.
        $CheckOSDisk = $OSDiskName + '.vhd'
        Write-Verbose "Checking if $CheckOSDisk already exists."
        if ($StorageBlob.Name -contains $CheckOSDisk -and $RecreateVM) {
            Write-Verbose "Recreating $CheckOSDisk."
            $BuildVM = $true
        }
        elseif ($StorageBlob.Name -contains $CheckOSDisk -and $RecreateVM -eq $false) {
            Write-Verbose "$CheckOSDisk already exists. Exiting."
            exit
        }
        elseif ($Null -eq $StorageBlob.Name -and $RecreateVM) {
            Write-Verbose "$($StorageBlob.Name) does not exist and the RecreateVM Switch is set. Try running module without the RecreateVM Switch. Exiting."
            exit
        } else {
            Write-Verbose "$CheckOSDisk will be created."
        }

} # BEGIN 

    PROCESS {
            Try {    

                if ($BuildVM) {
                    $GetVM = Get-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName

                    # Set VM powerstate to stopped. 
                    Write-Verbose "Stopping VM."
                    Stop-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName -Force -ErrorAction Ignore

                    # Remove network interface from VM. 
                    Write-Verbose "Removing VMNetwork Interface."
                    Remove-AzVMNetworkInterface -VM $GetVM -NetworkInterfaceIDs $VNICParameters.Name -ErrorAction Ignore

                    # Remove VM. 
                    Write-Verbose "Deleting VM $($VMConfigParameters.VMName) from Resource Group $($RGandLocation.ResourceGroupName)."
                    Remove-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName -Force
                    Write-Verbose "Waiting 120 Seconds for VM deletion to occur."
                    Start-Sleep -Seconds 120

                    # Remove OS Disk. 
                    Write-Verbose "Deleting $CheckOSDisk from container vhds."
                    Remove-AzStorageBlob -Context $StorageContext -Container vhds -Blob $CheckOSDisk -Force

                    # Remove Network Interface. 
                    Write-Verbose "Deleting $($VNICParameters.Name) VNIC from $($VMConfigParameters.VMName)"
                    Remove-AzNetworkInterface -Name $VNICParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName -Force

                    # Remove Public IP Address. 
                    Write-Verbose "Deleting Public IP $PubIPCheck.Name."
                    Remove-AzPublicIpAddress -Name $PubIPCheck.Name -ResourceGroupName $RGandLocation -Force -ErrorAction Ignore
                }

                # Check if Azure Resource Group already exists, if not create a new Azure Resource Group.
                if (-not (Get-AzResourceGroup -name $RGandLocation.ResourceGroupName -Location $RGandLocation.Location -ErrorAction Ignore)) {
                    Write-Verbose "Creating Azure Resource Group with the name $($RGandLocation.ResourceGroupName) in $($RGandLocation.Location)"
                    $null = New-AzResourceGroup -Name $RGandLocation.ResourceGroupName -Location $RGandLocation.Location
                } else {
                    Write-Verbose "$($RGandLocation.ResourceGroupName) Resource Group already exists."
                }
            
                # Check if Virtual Network already exists, if not create it.     
                if (-not ($NewVNet = Get-AzVirtualNetwork -Name $VNetParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName -ErrorAction Ignore)) {
                    Write-Verbose "Creating Subnet $($SubnetParameters.Name)"
                    $NewSubnet = New-AzVirtualNetworkSubnetConfig @SubnetParameters -Verbose
                    Write-Verbose "Creating Virtual Network Name $($VNetParameters.Name)"
                    $NewVNet = New-AzVirtualNetwork @VNetParameters -Subnet $NewSubnet
                } else {
                    Write-Verbose "$($VNetParameters.Name) Virtual Network already exists."
                }

                # Check if public IP address exists, if not create it. 
                if ($SetPublicIP) {
                    if (-not ($NewPublicIP = Get-AzPublicIpAddress -Name $PublicIPParameters.Name -ResourceGroupName $PublicIPParameters.ResourceGroupName -ErrorAction Ignore)) {
                        Write-Verbose "Creating public IP address $($PublicIPParameters.Name)"
                        $NewPublicIP = New-AzPublicIpAddress @PublicIPParameters
                    }
                    else {
                        Write-Verbose "$($PublicIPParameters.Name) Public IP Address already exists."
                    }
                }

                # Check if VNIC exists, if not create it. 
                if (-not ($NewVNIC = Get-AzNetworkInterface -Name $VNICParameters.Name -ResourceGroupName $VNICParameters.ResourceGroupName -ErrorAction Ignore)) {
                    Write-Verbose "Creating Virtual Network Interface $($VNICParameters.Name)"
                    $VNICParameters.SubnetId = $NewVNet.Subnets[0].Id
                    $VNICParameters.PublicIpAddressId = $NewPublicIP.Id
                    $NewVNIC = New-AzNetworkInterface @VNICParameters
                } else {
                    Write-Verbose "$($VNICParameters.Name) Virtual Network Interface already exists."
                }

                if ($SetPublicIP) {
                    # Attempting to associate public IP address with VM. 
                    $VNIC = Get-AzNetworkInterface -Name $VNICParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName
                    $PubIP = Get-AzPublicIpAddress -Name $PublicIPParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName
                    $SetIPConfig = $VNIC | Set-AzNetworkInterfaceIpConfig -Name $VNIC.IpConfigurations.Name -PublicIpAddress $PubIP -Subnet $NewSubnet
                    Write-Verbose "Assigning public IP address $($PublicIPParameters.Name) to virtual machine $($VMConfigParameters.VMName)."
                    $SetNIC = $VNIC | Set-AzNetworkInterface
                }
                
                # Check if storage account exists, if not create it.
                # -whatif currently not working. 
                # Storage account can take a while to be recgonised when creating VM. 5 minutes??
                if (-not ($NewStorageAccount = (Get-AzStorageAccount).where( { $_.StorageAccountName -eq $StorageAccountParameters.Name }))) {
                    Write-Verbose "Creating $($StorageAccountParameters.Name) storage account"
                    $NewStorageAccount = New-AzStorageAccount @StorageAccountParameters
                } else {
                    Write-Verbose "$($StorageAccountParameters.Name) Storage Account already exists."
                }

                # Create the VM object in Azure. 
                $NewVMConfig = New-AzVMConfig @VMConfigParameters

                # Get the username and password for the local administrator account. 
                $VMOSParameters.Credential = Get-Credential -Message 'Enter the name and password for the local administrator account.'
                
                # Set the operating system properties for the VM. 
                $VMOSParameters.VM = $NewVMConfig
                $NewVMOS = Set-AzVMOperatingSystem @VMOSParameters
                
                # Specify the platform image to use for the VM.
                $VMImageParameters.VM = $NewVMOS
                $VMImageParameters.Offer = $Offer.Offer
                $NewVM = Set-AzVMSourceImage @VMImageParameters

                Write-Verbose "Setting OSDISKURI"
                $OSDiskURI = '{0}vhds/{1}{2}.vhd' -f $NewStorageAccount.PrimaryEndpoints.Blob.ToString(), $VMConfigParameters.Name, $OSDiskName
            
                Write-Verbose "Setting OS Disk Properties for $($OSDiskName)"
                $NewVM = Set-AzVMOSDisk -Name $OSDiskName -CreateOption 'fromimage' -VM $NewVM -VhdUri $OSDiskURI
            
                # Add the Virtual Network Interface to the $NewVM variable. 
                Write-Verbose "Adding VNIC $($VNICParameters.Name) to virtual machine $($VMOSParameters.ComputerName)."
                $NewVM = Add-AzVMNetworkInterface -VM $NewVM -Id $NewVNIC.Id

                # Create VM
                Write-Verbose "Creating VM $($VMOSParameters.ComputerName)"
                $CreatVM = New-AzVM -VM $NewVM -ResourceGroupName $RGandLocation.ResourceGroupName -Location $RGandLocation.Location

                # If $VMPowerState is set to Stopped, change the powerstate of the VM to stopped. 
                if ($VMPowerState -eq 'Stopped') {
                    Write-Verbose "Setting powerstate for $($VMConfigParameters.VMName) to stopped"
                    Stop-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName -Force
                }

                # Retrieve VM Details
                $VMDetails = Get-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName -Status
                Write-Verbose "$($VMDetails.Statuses[0].DisplayStatus) for VM $($VMDetails.Name) and it's current status is $($VMDetails.Statuses[1].DisplayStatus)"

            } # try
            catch { 
                # [System.ApplicationException]
                "ERROR: $_"
                #[Microsoft.Azure.Commands.Profile.ConnectAzureRmAccountCommand]
                #[Microsoft.Azure.Commands.Compute.Models.PSVirtualMachine]
            } # catch
            finally {
            } # finally
        } #PROCESS
        END { }
} #Function