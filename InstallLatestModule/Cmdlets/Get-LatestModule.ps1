Function Get-LatestModule{
    <#
    .SYNOPSIS
        This function will get installed modules

    .DESCRIPTION
        The function will get installed modules and output data

    .PARAMETER Name
        Specify the name of the module

    .EXAMPLE
        Get-LatestModule -Name AzureAD
        Example will scan for module AzureAD on device in all locations and detemine if each one is at latest

    .EXAMPLE
        Get-LatestModule -Name Az.Accounts,Az.Resources,Microsoft.Graph.Intune
        Example will scan for 3 modules on device in all locations and detemine if each one is at latest

    .EXAMPLE
        $Name = @('Az.Accounts')
        $Module = $ExistingModules[0]
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false,ValueFromPipelineByPropertyName = $true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter( {
            param ( $commandName,
                    $parameterName,
                    $wordToComplete,
                    $commandAst,
                    $fakeBoundParameters )


            $Name = Get-Module -ListAvailable | Select-Object -ExpandProperty Name

            $Name| Where-Object {
                $_ -like "$wordToComplete*"
            }

        } )]
        [string[]]$Name
    )
    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        $ModuleUpdateStatus = @()

        If($Name){
            Write-Output ("{0} :: Retrieving modules [{1}]" -f ${CmdletName}, ($name -join ,''))
            $ExistingModules = Get-Module -Name $Name -ListAvailable
        }
        Else{
            Write-Output ("{0} :: Retrieving details for all installed modules, this can take a while..." -f ${CmdletName})
            $ExistingModules = Get-Module -ListAvailable
        }
    }
    Process{

        #TEST $Module = $ExistingModules | Select-Object -First 1
        Foreach($Module in $ExistingModules)
        {
            Write-Verbose ("{0} :: Checking status for installed module [{1}]" -f ${CmdletName},$Module.Name)

            If($Name){
                $ModuleName = $Name
            }
            Else{
                $ModuleName = $Module.Name
            }

            $AllModules = @()
            $AllModules += $ExistingModules | Where-Object {$_.Name -eq $ModuleName}
            #retrieve latest version
            $LatestModuleVersion = $null
            Try{
                $LatestModule = Find-Module -Name $ModuleName -ErrorAction Stop
                $LatestModuleVersion = $LatestModule.Version
            }
            Catch{
                Write-Verbose ("{0} :: Unable to find module [{1}] online" -f ${CmdletName},$ModuleName)
                $LatestModuleVersion = 'Unknown'
            }

            #check if latest version is installed
            If($Module.version -eq $LatestModuleVersion){$Updated = $true}Else{$Updated = $false}

            #create object
            $ModuleDetails = '' | Select ModuleName,Location,InstallCount,CurrentVersion,InstalledVersion,LatestRelease,UpToDate
            $ModuleDetails.ModuleName = $ModuleName
            $ModuleDetails.Location = $Module.Path
            $ModuleDetails.InstallCount = $AllModules.Count
            $ModuleDetails.CurrentVersion = $Module.Version
            $ModuleDetails.InstalledVersion = $AllModules.Version
            $ModuleDetails.LatestRelease = $LatestModuleVersion
            $ModuleDetails.UpToDate = $Updated
            #add to array
            $ModuleUpdateStatus += $ModuleDetails
        }
    }
    End{
        Write-Output ("{0} :: Status for {1} modules retrieved" -f ${CmdletName},$ModuleUpdateStatus.count)
        Return $ModuleUpdateStatus
    }
}
#incase scripts are using old cmdlet
New-Alias -Name "Compare-LatestModule" -Value Get-LatestModule -ErrorAction SilentlyContinue -Force
