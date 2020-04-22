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
    * AutoConnect Switch: Once VM is created run RDP and connect.
    * RecreateVM Switch: If VM already exists, delete it and create a new one.
    * Update VM output details to include IP addresses. 
    * Investigate the $offer line in the script. 
    * Update help section. 
    * Investigate the storage not found error if the storage account was created in this function. 
        # ErrorMessage: Storage account 'jlabstorageaccount' not found. Ensure storage account is not deleted and belongs to the same Azure location as the VM.
#>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ValueFromPipeline = $true,
            Mandatory = $true,
            HelpMessage = 'Please provide a JSON file')]
        [string]$FilePathJson,
        [Parameter(Mandatory = $false)]
        [switch]$SetPublicIP,
        [Parameter(ValueFromPipeline = $true,
            Mandatory = $false,
            HelpMessage = "Set VM Powerstate to Stopped or Running")]
        [string]$VMPowerState = 'Running'
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
        if (Get-AzVM -Name $VMConfigParameters.VMName -ResourceGroupName $RGandLocation.ResourceGroupName -ErrorAction Ignore) {
            Write-Verbose "An Azure VM with the name $($VMOSParameters.ComputerName) in Resource Group $($RGandLocation.ResourceGroupName) already exists. Exiting"
            exit
        }

        $Offer = Get-AzVMImageOffer -Location $RGandLocation.Location -PublisherName 'MicrosoftWindowsServer' | Where-Object { $_.Offer -eq 'WindowsServer' }

        # Set URI for the VHD for the Set-AZVMOSDisk cmdlet. 
        $OSDiskName = $VMOSParameters.ComputerName + "Disk"

        # Check if the Virtual Network Interface is aready associated to another VM. 
        $CheckVMNIC = Get-AzNetworkInterface -Name $VNICParameters.Name | Select-Object -Property VirtualMachine

        # Retreive storage account key. 
        Write-Verbose "Retrieving Storage Account Key for $($StorageAccountParameters.Name)"
        $StorageKey = Get-AzStorageAccountKey -ResourceGroupName $RGandLocation.ResourceGroupName -AccountName $StorageAccountParameters.Name
        $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountParameters.Name -StorageAccountKey $StorageKey.Value[1]
        $StorageBlob = Get-AzStorageBlob -Context $StorageContext -Container vhds -ErrorAction Ignore
                            
        # Check if the OS Disk already exists.
        $CheckOSDisk = $OSDiskName + '.vhd'
        Write-Verbose "Checking if $CheckOSDisk already exists."
        if ($StorageBlob.Name -contains $CheckOSDisk) {
            Write-Error "$CheckOSDisk already exists. Exiting."
            exit
        }
        else {
            Write-Verbose "$CheckOSDisk does not exist. Proceeding."
        }
} # BEGIN 

    PROCESS {
            Try {    

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

                # Check if VNIC already associated. 
                if ($null -ne $CheckVMNIC.VirtualMachine.Id) {
                        Write-Error "$($VNICParameters.Name) is already associated to $($CheckVMNIC.VirtualMachine.Id)"
                        return
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
                    Write-Verbose "Setting powerstate for $VMConfigParameters.VMName to stopped"
                    Stop-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName
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