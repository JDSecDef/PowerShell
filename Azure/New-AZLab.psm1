function New-AZJLab {
    <#
.SYNOPSIS
    Creates an Azure Virtual Machine and all the prerequisites including the Resource Group, Virtual Network, Public IP Address (optional), Virtual Network Interface, Storage Account and OS Disk. Retrieves the configuration details for the Azure environment from a JSON file.

.DESCRIPTION
    The New-AZLab function retrieves the contents of a JSON file and creates an Azure Virtual Machine and all of its prerequisites including, the Resource Group, Virtual Network, Virtual Network Interface, Storage Account and OS Disk. It can also create an optional Public IP address and has parameters for recreating existing virtual machines, creating a Public IP Address and automatically connecting to the Azure Virtual Machine when it has been created. 

.PARAMETER JSONFilePath
    The JSONFilePath Parameter is the filepath to the JSON file with the Azure lab configuration details. 

.PARAMETER SetPublicIP
    The SetPublicIP Switch configures the Azure Virtual Machine with a Public IP Address that is dynamically assigned. 

.PARAMETER PowerState
    The PowerState Parameter sets the state of the Azure Virtual Machine after it is created to either Running or Stopped, Running is the default value. 

.PARAMETER RecreateVM
    The RecreateVM Switch will recreate an existing Azure Virtual Machine if one already exists with the same name. It also recreates the Virtual Network Interface, Public IP Address (optional) and the storage disk assigned.
    
.PARAMETER AutoConnect
    The AutoConnect switch parameter will start mstsc.exe at the conclusion of the function and connect you to the new Azure Virtual Machine if the virtual machine has a Public IP Address associated to it. 

.EXAMPLE
    New-AZLab C:\Lab.json -Verbose
    Create an Azure Virtual Machine and all the prerequisites using the configuration settings from the json file. 
    This command will take the contents of the JSON file and create a new Azure Resource Group, Storage Account, Virtual Network, Virtual Network Interface, the OS disk and
    the virtual machine. 

.EXAMPLE 
    New-AZLab C:\Lab.json -RecreateVM -PowerState Stopped -Verbose 
    Recreate an existing Azure Virtual Machine and set its powerstate to stopped. 
    This command will recreate an existing Azure Virtual Machine and set its powerstate to stopped. 

.EXAMPLE
    New-AZLab C:\Lab.json -SetPublicIC -AutoConnect -Verbose
    Create an Azure Virtual Machine with a Public IP Address which is dynamically assigned and connect via mstsc.exe when the Azure Virtual Machine has been created. 

.NOTES
    Author:         JDSecDef
    Version:        1.0.0.0
    Last Updated:   26/04/2020
#>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = 'Please provide a JSON file')]
        [string]$JSONFilePath,
        [Parameter(Mandatory = $false)]
        [switch]$SetPublicIP,
        [Parameter(Mandatory = $false,
            HelpMessage = 'Set VM Powerstate to Stopped or Running')]
        [ValidateSet('Running','Stopped')]
        [string]$PowerState = 'Running',
        [Parameter(Mandatory = $false,
            HelpMessage = 'This recreates a VM and its vhd if it already exists.')]
        [Switch]$RecreateVM,
        [Parameter(Mandatory = $false,
            HelpMessage = "This will start RDP and connect you to the VM.")]
        [Switch]$AutoConnect
    )
    
    BEGIN {
        Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
        $InformationPreference = "Continue"
        $Connection = Get-AzContext 
        $JsonFile = Get-Content $JSONFilePath | ConvertFrom-Json

        # Create hashtables from JSON file. 
        $RGandLocation = $JsonFile.'JLab-RGandLocation' | ForEach-Object {
            $Key = $_ 
            [hashtable] @{Name    = $Key.Name
                ResourceGroupName = $Key.ResourceGroupName
                Location          = $Key.Location 
            }
        }
        $Offers = $JsonFile.'JLab-Offers' | ForEach-Object {
            $Key = $_
            [hashtable] @{PublisherName  = $Key.PublisherName
               Offer = $Key.Offer 
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
            [hashtable] @{Name          = $Key.Name
                ResourceGroupName       = $Key.ResourceGroupName
                Location                = $Key.Location
                PrivateIPaddress        = $Key.PrivateIPaddress
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

        # Check if user is authenticated to Azure, if not prompt the user to login.
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
            $RebuildVM = $true
        }
        elseif ($null -eq $CheckVM.Name -and $RecreateVM) {
            Write-Verbose "$($VMConfigParameters.VMName) does not exist and the RecreateVM Switch is set. Try running module without the RecreateVM Switch. Exiting."
            exit
        }
        elseif ($CheckVM.Name -eq $VMConfigParameters.VMName -and $RecreateVM -eq $false) {
            Write-Verbose "An Azure VM with the name $($VMConfigParameters.VMName) in Resource Group $($RGandLocation.ResourceGroupName) already exists. Exiting."
            exit
        } else {
            Write-Verbose "A VM with the name $($VMConfigParameters.VMName) will be created in $($RGandLocation.ResourceGroupName) Resource Group."
        }

        # Get the VMImage offer types. 
        $Offer = Get-AzVMImageOffer -Location $RGandLocation.Location -PublisherName $Offers.PublisherName | Where-Object { $_.Offer -eq $Offers.offer }

        # Check if the Virtual Network Interface is aready associated to another VM. 
        $CheckVMNIC = Get-AzNetworkInterface -Name $VNICParameters.Name | Select-Object -Property VirtualMachine -ErrorAction Ignore
        if ($null -ne $CheckVMNIC.VirtualMachine.Id -and $RecreateVM -eq $false) {
            Write-Verbose "$($VNICParameters.Name) is already associated to $($CheckVMNIC.VirtualMachine.Id). VM will not be created. Exiting."
            exit
        }

        # Check Public IP Address. 
        $PubIPCheck = Get-AzPublicIpAddress -Name $PublicIPParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName -ErrorAction Ignore
        if ($PubIPCheck.Name -eq $PublicIPParameters.Name -and $RecreateVM) {
            Write-Verbose "Public IP Address $($PubIPCheck.Name) will be recreated."
            $RecreatePublicIP = $true
        }
        #elseif ($null -eq $PubIPCheck -and $RecreateVM) {
        #    Write-Verbose "$($PubIPCheck.Name) does not exist and the RecreateVM Switch is set. Try running module without the RecreateVM Switch. Exiting."
        #    exit
        #} 
        elseif ($SetPublicIP) {
            Write-Verbose "$($PublicIPParameters.Name) Public IP Address will be created and associated to $($VMConfigParameters.VMName)."
        }   
        
        # Retreive storage account key if storage account exists.
        $CheckStorage = Get-AzStorageAccount -ResourceGroupName $RGandLocation.ResourceGroupName -Name $StorageAccountParameters.Name
        if ($CheckStorage) {
            Write-Verbose "Retrieving Storage Account Key for $($StorageAccountParameters.Name)."
            $StorageKey = Get-AzStorageAccountKey -ResourceGroupName $RGandLocation.ResourceGroupName -AccountName $StorageAccountParameters.Name
            $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountParameters.Name -StorageAccountKey $StorageKey.Value[1]
            $StorageBlob = Get-AzStorageBlob -Context $StorageContext -Container vhds -ErrorAction Ignore
        }
        
        # Check if the OS Disk already exists.
        $OSDiskName = $VMOSParameters.ComputerName + "Disk"     
        $CheckOSDisk = $OSDiskName + '.vhd'
        Write-Verbose "Checking if $CheckOSDisk already exists."
        if ($StorageBlob.Name -contains $CheckOSDisk -and $RecreateVM) {
            Write-Verbose "$CheckOSDisk will be recreated."
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

                if ($RebuildVM) {
                    $GetVM = Get-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName

                    # Set VM powerstate to stopped. 
                    Write-Verbose "Stopping VM $($VMConfigParameters.VMName)."
                    $StopVM = Stop-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName -Force -ErrorAction Ignore

                    # Remove network interface from VM. 
                    Write-Verbose "Removing VMNetwork Interface $($VNICParameters.Name)."
                    $RemoveVMNet = Remove-AzVMNetworkInterface -VM $GetVM -NetworkInterfaceIDs $VNICParameters.Name -ErrorAction Ignore

                    # Remove VM. 
                    Write-Verbose "Deleting VM $($VMConfigParameters.VMName) from Resource Group $($RGandLocation.ResourceGroupName)."
                    $RemoveVM = Remove-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName -Force
                    Write-Verbose "Waiting 60 Seconds for VM deletion to occur."
                    Start-Sleep -Seconds 60

                    # Remove OS Disk. 
                    Write-Verbose "Deleting $CheckOSDisk from container vhds."
                    Remove-AzStorageBlob -Context $StorageContext -Container vhds -Blob $CheckOSDisk -Force

                    # Remove Network Interface. 
                    Write-Verbose "Deleting $($VNICParameters.Name) VNIC from $($VMConfigParameters.VMName)"
                    Remove-AzNetworkInterface -Name $VNICParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName -Force

                    # Remove Public IP Address. 
                    if ($RecreatePublicIP) {
                        Write-Verbose "Deleting Public IP $($PubIPCheck.Name)."
                    Remove-AzPublicIpAddress -Name $PubIPCheck.Name -ResourceGroupName $RGandLocation -Force -ErrorAction Ignore
                    }
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
                    } else {
                        Write-Verbose "$($PublicIPParameters.Name) Public IP Address already exists."
                    }
                }

                # Check if VNIC exists, if not create it. 
                if (-not ($NewVNIC = Get-AzNetworkInterface -Name $VNICParameters.Name -ResourceGroupName $VNICParameters.ResourceGroupName -ErrorAction Ignore)) {
                    Write-Verbose "Creating Virtual Network Interface $($VNICParameters.Name)."
                    $VNICParameters.SubnetId = $NewVNet.Subnets[0].Id
                    $VNICParameters.PublicIpAddressId = $NewPublicIP.Id
                    $IPConfig = New-AzNetworkInterfaceIpConfig -Name "IPConfig1" -PrivateIpAddress $VNICParameters.PrivateIPaddress -SubnetID $NewVNet.Subnets[0].Id
                    $VNICParameters.PrivateIPaddress = $IPConfig.PrivateIpAddress
                    $NewVNIC = New-AzNetworkInterface @VNICParameters
                } else {
                    Write-Verbose "$($VNICParameters.Name) Virtual Network Interface already exists."
                }

                # Associate public IP address. 
                if ($SetPublicIP) {
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
                    Write-Verbose "Creating $($StorageAccountParameters.Name) storage account."
                    $NewStorageAccount = New-AzStorageAccount @StorageAccountParameters
                    Write-Verbose "Waiting 60 seconds for $($StorageAccountParameters.Name) to be created."
                    Start-Sleep -Seconds 60 
                } else {
                    Write-Verbose "$($StorageAccountParameters.Name) Storage Account already exists."
                }

                # Create the VM object in Azure. 
                $NewVMConfig = New-AzVMConfig @VMConfigParameters

                # Get the username and password for the local administrator account. 
                $VMOSParameters.Credential = Get-Credential -Message "Enter the name and password for the local administrator account.`nPassword must be between 12 and 72 characters long and must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character."
                
                # Set the operating system properties for the VM. 
                $VMOSParameters.VM = $NewVMConfig
                $NewVMOS = Set-AzVMOperatingSystem @VMOSParameters
                
                # Specify the platform image to use for the VM.
                $VMImageParameters.VM = $NewVMOS
                $VMImageParameters.Offer = $Offer.Offer
                $NewVM = Set-AzVMSourceImage @VMImageParameters

                # Setting OSDISKURI
                $OSDiskURI = '{0}vhds/{1}{2}.vhd' -f $NewStorageAccount.PrimaryEndpoints.Blob.ToString(), $VMConfigParameters.Name, $OSDiskName
            
                Write-Verbose "Setting OS Disk Properties for $($OSDiskName)."
                $NewVM = Set-AzVMOSDisk -Name $OSDiskName -CreateOption 'fromimage' -VM $NewVM -VhdUri $OSDiskURI
            
                # Add the Virtual Network Interface to the $NewVM variable. 
                Write-Verbose "Adding VNIC $($VNICParameters.Name) to virtual machine $($VMOSParameters.ComputerName)."
                $NewVM = Add-AzVMNetworkInterface -VM $NewVM -Id $NewVNIC.Id

                # Create VM
                Write-Verbose "Creating VM $($VMOSParameters.ComputerName)."
                $CreateVM = New-AzVM -VM $NewVM -ResourceGroupName $RGandLocation.ResourceGroupName -Location $RGandLocation.Location

                # If $PowerState is set to Stopped, change the powerstate of the VM to stopped. 
                if ($PowerState -eq 'Stopped') {
                    Write-Verbose "Setting powerstate for $($VMConfigParameters.VMName) to Stopped."
                    $StopVM = Stop-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName -Force
                }

                # Retrieve VM Details and output results.
                $VMDetails = Get-AzVM -ResourceGroupName $RGandLocation.ResourceGroupName -Name $VMConfigParameters.VMName -Status
                $GetVNIC = Get-AzNetworkInterface -Name $VNICParameters.Name
                If ($SetPublicIP) {
                    $GetPubIP = Get-AzPublicIpAddress -Name $PublicIPParameters.Name -ResourceGroupName $RGandLocation.ResourceGroupName
                    $VMProperties = [PSCustomObject]@{
                        'Result'                = $VMDetails.Statuses[0].DisplayStatus
                        'VMName'                = $VMDetails.Name
                        'Powerstate'            = $VMDetails.Statuses[1].DisplayStatus
                        'PrivateNetworkAddress' = $GetVNIC.IpConfigurations.PrivateIPaddress
                        'PublicIPAddress'       = $GetPubIP.IpAddress
                    }
                    Write-Information ($VMProperties | Format-List | Out-String)
                } else {
                        $VMProperties = [PSCustomObject]@{
                            'Result'                = $VMDetails.Statuses[0].DisplayStatus
                            'VMName'                = $VMDetails.Name
                            'Powerstate'            = $VMDetails.Statuses[1].DisplayStatus
                            'PrivateNetworkAddress' = $GetVNIC.IpConfigurations.PrivateIPaddress
                        }
                        Write-Information ($VMProperties | Format-List | Out-String)
                    }
                
                if ($AutoConnect -and $SetPublicIP -and $VMDetails.Statuses[1].DisplayStatus -eq 'VM Running') {
                    Write-Verbose "Starting mstsc.exe and connecting to $($VMDetails.Name) on public IP address $($GetPubIP.IpAddress)."
                    Start-Process mstsc.exe -ArgumentList "/v:$($GetPubIP.IpAddress)"
                }
                elseif ($AutoConnect -and $VMDetails.Statuses[1].DisplayStatus -eq 'VM deallocated') {
                    Write-Verbose "$($VMDetails.Name) powerstate is currently $($VMDetails.Statuses[1].DisplayStatus), unable to connect. Try starting the VM and connecting manually."
                }
                elseif ($AutoConnect -and $null -eq $SetPublicIP) {
                    Write-Verbose "No public IP Address exists for $($VMDetails.Name), unable to connect via RDP."
                }

            } # try
            catch { 
                "ERROR: $_"
            } # catch
            finally {
            } # finally
        } #PROCESS
        END { }
} #Function