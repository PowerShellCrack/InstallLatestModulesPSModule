
Function Install-LatestModule {
    <#
    .SYNOPSIS
       This function will install and update module to latest version

    .DESCRIPTION
        The function will install and update module to latest version under system context

    .PARAMETER Name
        Specify the name of the module

    .PARAMETER All
        Will scan for all modules install under C:\Program Files\WindowsPowerShell\Modules and attempt to update them

    .PARAMETER Force
        Will reinstall modules no matter if the module is at the latest version

    .PARAMETER AllowImport
        After installation of module; it will import it for use within powershell session

    .EXAMPLE
        Install-LatestModule -All
        Example will update all modules installed under C:\Program Files\WindowsPowerShell\Modules

    .EXAMPLE
        Install-LatestModule -Name AzureAD
        Example will scan for module AzureAD and check its version. it will update if older than PSGallewries latest version

    .EXAMPLE
        Install-LatestModule -Name Az.Accounts,Az.Resources,Microsoft.Graph.Intune -Confirm:$false
        Example will scan for 3 modules and check its version. it will update if older than PSGallery's latest version

    .EXAMPLE
        Install-LatestModule -Name AzureAD -Force -Confirm:$false
        Example will scan for module AzureAD and check its version. If the version is already up-to-date; Force will reinstall it

    .EXAMPLE
        Get-Module -ListAvailable | Install-LatestModule
        Example will scan for all modules on device and install the latest for each if found
    .EXAMPLE
       $Name = 'Az.Resources'
       $Name = 'AzFilesHybrid'
       $Name = 'PSReadLine'
       $Name = 'AzureAD'
    #>
    [CmdletBinding(DefaultParameterSetName = 'NameParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=398573',
        SupportsShouldProcess = $true,ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromPipeline = $true,
            Position = 0,
            ParameterSetName = 'NameParameterSet')]
        [ValidateNotNullOrEmpty()]
        [Alias("ModuleName")]
        [string[]]
        $Name,

        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'AllParameterSet')]
        [ValidateNotNullOrEmpty()]
        [switch]
        $All,

        [Parameter()]
        [switch]
        $Force,

        [Parameter()]
        [bool]
        $AllUsers = $true,

        [Parameter()]
        [switch]
        $AllowImport
    )

    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        #build log name
        If($DebugPreference){
            [string]$FileName = 'InstallLatestModules_' + ${CmdletName} + '_' + (get-date -Format MM-dd-yyyy) + '.log'
            Start-Transcript -Path $env:TEMP\$FileName -Force -Append | Out-Null
        }

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }

        Write-Output ("{0} :: Checking for latest installed modules [Press Ctrl+C to cancel]..." -f ${CmdletName})

        #grab just module installed
        $InstalledModules = Get-InstalledModule -ErrorAction SilentlyContinue

        #set variables
        [string]$ModuleName = $null
        $LatestModule = $null
        $ExistingModules = $null
        $RefreshNeeded = $false
        $ModuleInstallStatus = @()


        #set scope for module install
        If($AllUsers -eq $true){$ScopeParam = @{Scope = 'AllUsers'} }Else{$ScopeParam= @{Scope = 'CurrentUser'}}
    }
    Process{
        #create object
        $ModuleDetails = '' | Select ModuleName,InstallStatus,InstallVersion,InstallPath,PriorVersion,InstallMessage,ErrorMsg

        #check if all modules are to be updated, just use one unique name
        If($All){
            $ModuleNames = $InstalledModules.name | Select -Unique
        }Else{
            $ModuleNames = $Name
        }

        #TEST $moduleName = $moduleNames | Select -First 1
        foreach ($ModuleName in $ModuleNames)
        {
            $ModuleDetails.ModuleName = $ModuleName
            Write-Verbose ("{0} :: Searching for Module: {1}" -f ${CmdletName},$ModuleName)

            #$ExistingModules = $InstalledModules | Where-Object Name -eq $ModuleName
            $ExistingModules = Get-Module -Name $ModuleName -ListAvailable

            If($ExistingModules.count -gt 1){
                Write-Verbose ("{0} :: Multiple versions found: {1}" -f ${CmdletName},$ExistingModules.count)
            }ElseIf($ExistingModules){
                Write-Verbose ("{0} :: Found installed version: {1}" -f ${CmdletName},$ExistingModules.Version.ToString())
            }Else{
                Write-Verbose ("{0} :: Module not found" -f ${CmdletName})
            }

            #search for module online and get latest version
            Write-Verbose ("{0} :: Checking for the latest version..." -f ${CmdletName})
            $LatestModule = Find-Module $ModuleName -ErrorAction SilentlyContinue

            #if latest module has been found online, proceed
            If($null -ne $LatestModule)
            {

                #ignore any versions installed, uninstall all and install latest
                Try
                {
                    if($PSCmdlet.ShouldProcess($ModuleName)){
                        
                        If($PSBoundParameters.ContainsKey('Force'))
                        {
                            $StatusMsg = ("Force uninstalling existing module [{0} ({1})] and installing to [{2}]" -f $ModuleName,$ExistingModules.Version.ToString(),$LatestModule.Version)
                            Write-Verbose ("{0} :: {1}" -f ${CmdletName},$StatusMsg)
                            $ModuleDetails.InstallMessage = $StatusMsg
                            
                            $ExistingModules | Remove-Module -Force -ErrorAction Stop
                            $ExistingModules | Uninstall-Module -Force -ErrorAction Stop
                            Install-Module $ModuleName -RequiredVersion $LatestModule.Version @ScopeParam -Force -SkipPublisherCheck -ErrorAction Stop

                            $ModuleDetails.InstallStatus = 'InstalledToLatest'
                            $RefreshNeeded = $true
                        }
                        Else
                        {                       
                            #if no moduels exist
                            If($null -eq $ExistingModules)
                            {
                                $StatusMsg = ("Module not found [{0}], installing..." -f $ModuleName)
                                Write-Verbose ("{0} :: {1}" -f ${CmdletName},$StatusMsg)
                                $ModuleDetails.InstallMessage = $StatusMsg

                                Install-Module $ModuleName @ScopeParam -Force -SkipPublisherCheck -AllowClobber -ErrorAction Stop

                                $ModuleDetails.InstallStatus = 'NewInstall'
                                $ModuleDetails.InstallVersion = $LatestModule.Version
                            }

                            #check if module is installed for all users or current user
                            ElseIf(($ExistingModules.Path -like "$env:USERPROFILE*") -and ($ExistingModules.Path -notlike "*.vscode*") -and ($AllUsers -eq $true)){
                                
                                $StatusMsg = ("Uninstalling existing module [{0}] from scope [{1}] and installing latest [{2}] in scope [{3}]" -f $ModuleName,'CurrentUser',$LatestModule.Version,'AllUsers')
                                Write-Verbose ("{0} :: {1}" -f ${CmdletName},$StatusMsg)
                                $ModuleDetails.InstallMessage = $StatusMsg
                                
                                $ExistingModules | Remove-Module -Force -ErrorAction Stop
                                $ExistingModules | Uninstall-Module -Force -ErrorAction Stop
                                Install-Module $ModuleName -RequiredVersion $LatestModule.Version @ScopeParam -Force -SkipPublisherCheck -ErrorAction Stop

                                $ModuleDetails.InstallStatus = 'MovedToAllUsers'
                                $RefreshNeeded = $true
                            }

                            #check if module is installed for all users or current user
                            ElseIf(($ExistingModules.Path -notlike "$env:USERPROFILE*") -and ($AllUsers -ne $true)){
                                $StatusMsg = ("Uninstalling existing module [{0}] from scope [{1}] and installing latest [{2}] in scope [{3}]" -f $ModuleName,'AllUsers',$LatestModule.Version,'CurrentUser')
                                Write-Verbose ("{0} :: {1}" -f ${CmdletName},$StatusMsg)
                                $ModuleDetails.InstallMessage = $StatusMsg
                                
                                $ExistingModules | Remove-Module -Force -ErrorAction Stop
                                $ExistingModules | Uninstall-Module -Force -ErrorAction Stop
                                Install-Module $ModuleName -RequiredVersion $LatestModule.Version @ScopeParam -Force -SkipPublisherCheck -ErrorAction Stop

                                $ModuleDetails.InstallVersion = $LatestModule.Version
                                $ModuleDetails.InstallStatus = 'MovedToCurrentUser'
                                $RefreshNeeded = $true
                            }

                            ElseIf($ExistingModules.Version -eq $LatestModule.Version)
                            {
                                $StatusMsg = ("Module [{0}] is at latest version [{1}]!" -f $ModuleName,$ExistingModules.Version)
                                Write-Verbose ("{0} :: {1}" -f ${CmdletName},$StatusMsg)
                                $ModuleDetails.InstallMessage = $StatusMsg
                                
                                $ModuleDetails.InstallStatus = 'UpToDate'
                                $ModuleDetails.InstallVersion = $ExistingModules.Version
                            }

                            #are there multiple of the same module installed?
                            ElseIf( ($ExistingModules | Measure-Object).Count -gt 1)
                            {
                                $ModuleDetails.PriorVersion = $ExistingModules.Version
                                If($LatestModule.Version -in $ExistingModules.Version)
                                {
                                    $StatusMsg = ("Latest Module found [{1}], Cleaning up older [{0}] modules..." -f $ModuleName,$LatestModule.Version.ToString())
                                    Write-Verbose ("{0} :: {1}" -f ${CmdletName},$StatusMsg)
                                    $ModuleDetails.InstallMessage = $StatusMsg

                                    #Check to see if latest module is installed already and uninstall anything older
                                    $ExistingModules | Where-Object Version -NotMatch $LatestModule.Version | Uninstall-Module -Force -ErrorAction Stop
                                    
                                    $ModuleDetails.InstallStatus = 'RemovedOlder'
                                }
                                Else
                                {
                                    $StatusMsg = ("Uninstalling older [{0}] modules and installing the latest module version [{1}]..." -f $ModuleName,$LatestModule.Version.ToString())
                                    Write-Verbose ("{0} :: {1}" -f ${CmdletName},$StatusMsg)
                                    $ModuleDetails.InstallMessage = $StatusMsg

                                    #uninstall all older Modules with that name, then install the latest
                                    Get-Module -FullyQualifiedName $ModuleName -ListAvailable | Uninstall-Module -Force -ErrorAction Stop
                                    Install-Module $ModuleName -RequiredVersion $LatestModule.Version @ScopeParam -AllowClobber -Force -SkipPublisherCheck -ErrorAction Stop
     
                                    $ModuleDetails.InstallStatus = 'Installed'
                                }
                                $ModuleDetails.InstallVersion = $LatestModule.Version
                                $RefreshNeeded = $true
                            }

                            #if only one module exist but not the latest version
                            ElseIf($ExistingModules.Version -ne $LatestModule.Version)
                            {
                                Write-Verbose ("{0} :: Found newer version [{1}]..." -f ${CmdletName},$LatestModule.Version.ToString())
                                #Update module since it was found
                                $StatusMsg = ("Updating Module [{0}] from [{1}] to the latest version [{2}]..." -f $ModuleName,$ExistingModules.Version,$LatestModule.Version)
                                Write-Verbose ("{0} :: {1}" -f ${CmdletName},$StatusMsg)
                                $ModuleDetails.InstallMessage = $StatusMsg

                                Try{
                                    Update-Module $ModuleName -RequiredVersion $LatestModule.Version -Force -ErrorAction Stop    
                                    $ModuleDetails.InstallStatus = 'Updated'
                                }
                                Catch{
                                    #$_.Exception.GetType().FullName
                                    Install-Module $ModuleName -RequiredVersion $LatestModule.Version @ScopeParam -AllowClobber -Force -SkipPublisherCheck -ErrorAction Stop
                                    $ModuleDetails.InstallStatus = 'Installed'
                                }
                                $ModuleDetails.InstallVersion = $LatestModule.Version
                                $RefreshNeeded = $true
                            }
                            Else
                            {
                                $StatusMsg = ("Unable to determine if module [{0}] is at latest version!",$ModuleName)
                                Write-Verbose ("{0} :: {1}" -f ${CmdletName},$StatusMsg)

                                $ModuleDetails.InstallMessage = $StatusMsg
                                $ModuleDetails.InstallStatus = $false
                                Continue
                            }
                        }
                        $ModuleDetails.InstallStatus = $true
                        $ModuleDetails.InstallPath = (Get-Module -Name $ModuleName -ListAvailable).Path

                    }Else{
                        $ModuleDetails.InstallStatus = 'Skipped'
                        $ModuleDetails.InstallVersion = $ExistingModules.Version
                        $ModuleDetails.InstallPath = $ExistingModules.Path
                    }
                    
                }
                Catch
                {
                    Write-Error ("Failed with error: {0}" -f $_.Exception.Message)
                    $ModuleDetails.InstallStatus = 'Failed'
                    $ModuleDetails.InstallPath = $ExistingModules.Path
                    $ModuleDetails.ErrorMsg = $_.Exception.Message
                }
                Finally
                {
                    If($AllowImport){
                        #importing module
                        Write-Verbose ("{0} :: Importing Module [{1}] for use..." -f ${CmdletName},$ModuleName)
                        Import-Module -Name $ModuleName -Force:$force -Verbose:$VerbosePreference
                    }
                }
            }
            Else{
                Write-Verbose ("{0} :: Module [{1}] does not exist, unable to update" -f ${CmdletName},$ModuleName)
                $ModuleDetails.InstallStatus = 'NotFound'
            }

            $ModuleInstallStatus += $ModuleDetails

        } #end of module loop
    }
    End{
        Write-Output ("{0} :: Completed updates on {1} modules" -f ${CmdletName},$ModuleInstallStatus.count)
        If($RefreshNeeded){Write-Host ("A restart of Powershell may be required to refresh module versions.") -ForegroundColor Magenta}
        If($DebugPreference){Stop-Transcript | Out-Null}
        return $ModuleInstallStatus
    }
}