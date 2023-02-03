
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
        Install-LatestModule -Name Az.Accounts,Az.Resources,Microsoft.Graph.Intune
        Example will scan for 3 modules and check its version. it will update if older than PSGallery's latest version

    .EXAMPLE
        Install-LatestModule -Name AzureAD -Force
        Example will scan for module AzureAD and check its version. If the version is already up-to-date; Force will reinstall it

    .EXAMPLE
        Get-Module -ListAvailable | Install-LatestModule
        Example will scan for all modules on device and install the latest for each if found
    #>
    [CmdletBinding(DefaultParameterSetName = 'NameParameterSet',
        HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=398573',
        SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
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
        [switch]
        $AllowImport
    )

    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        #build log name
        [string]$FileName = 'Modules_' + ${CmdletName} + '_' + (get-date -Format MM-dd-yyyy) + '.log'
        Start-Transcript -Path $env:TEMP\$FileName -Force -Append | Out-Null

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }

        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }

        [string]$ModuleName = $null
        $LatestModule = $null
        $ExistingModules = $null

        Write-Host ("{0} :: Checking {1} for latest installed modules [Press Ctrl+C to cancel]..." -f ${CmdletName},$UpdateFrequency)  -ForegroundColor Gray

        #grab all version of the module installed
        $InstalledModules = Get-InstalledModule -ErrorAction SilentlyContinue

        $RefreshNeeded = $false
    }
    Process{

        If($All){$name = $InstalledModules.name | Select -Unique}

        foreach ($item in $name)
        {

            #format out text
            Write-Host ("  Searching for Module :: ") -ForegroundColor Gray -NoNewline
            Write-Host ("{0}" -f $item) -ForegroundColor White -NoNewline
            Write-Host ("...") -ForegroundColor Gray -NoNewline

            [string]$ModuleName = $item

            #$ExistingModules = $InstalledModules | Where-Object Name -eq $ModuleName
            $ExistingModules = Get-InstalledModule -Name $ModuleName -AllVersions -ErrorAction SilentlyContinue

            If($ExistingModules.count -gt 1){
                Write-Host ("multiple versions found") -ForegroundColor Green -NoNewline
            }
            ElseIf($ExistingModules){
                Write-Host ("[{0}] installed. " -f $ExistingModules.Version.ToString()) -ForegroundColor Green -NoNewline
            }Else{
                Write-Host ("not found") -ForegroundColor Red
            }

            #if scheduled to check module, search for module online
            If($ExistingModules){
                Write-Host ("Checking for the latest version...") -ForegroundColor Yellow
            }

            $LatestModule = Find-Module $ModuleName -ErrorAction SilentlyContinue

            

            #if latest module has been found online, proceed
            If($null -ne $LatestModule)
            {

                #ignore any versions installed, uninstall all and install latest
                Try
                {
                    If($PSBoundParameters.ContainsKey('Force'))
                    {
                        Write-Host ("    Uninstalling old module [{0}] and installing to latest [{1}]..." -f $ModuleName,$LatestModule.Version) -ForegroundColor Cyan -NoNewline
                        $ExistingModules | Uninstall-Module -Force -ErrorAction Stop
                        Install-Module $ModuleName -RequiredVersion $LatestModule.Version -Scope AllUsers -Force -SkipPublisherCheck -ErrorAction Stop -Verbose:$VerbosePreference
                        Write-Host ("Completed") -ForegroundColor Green
                        $RefreshNeeded = $true
                    }
                    Else
                    {
                        #if no moduels exist
                        If($null -eq $ExistingModules)
                        {
                            Write-Host ("    [{0}] is not installed, installing..." -f $ModuleName) -ForegroundColor Gray -NoNewline
                            Install-Module $ModuleName -Scope AllUsers -Force -SkipPublisherCheck -AllowClobber -ErrorAction Stop -Verbose:$VerbosePreference
                            Write-Host ("Installed") -ForegroundColor Green
                        }

                        #are there multiple of the same module installed?
                        ElseIf( ($ExistingModules | Measure-Object).Count -gt 1)
                        {
                            If($LatestModule.Version -in $ExistingModules.Version)
                            {
                                Write-Host ("    Latest Module found [{1}], Cleaning up older [{0}] modules..." -f $ModuleName,$LatestModule.Version.ToString()) -ForegroundColor Yellow -NoNewline
                                #Check to see if latest module is installed already and uninstall anything older
                                $ExistingModules | Where-Object Version -NotMatch $LatestModule.Version | Uninstall-Module -Force -ErrorAction Stop
                            }
                            Else
                            {
                                #uninstall all older Modules with that name, then install the latest
                                Write-Host ("    Uninstalling older [{0}] modules and installing the latest module version [{1}]..." -f $ModuleName,$LatestModule.Version.ToString()) -ForegroundColor Yellow -NoNewline
                                Get-Module -FullyQualifiedName $ModuleName -ListAvailable | Uninstall-Module -Force -ErrorAction Stop
                                Install-Module $ModuleName -RequiredVersion $LatestModule.Version -Scope AllUsers -AllowClobber -Force -SkipPublisherCheck -ErrorAction Stop -Verbose:$VerbosePreference
                            }
                            Write-Host ("done") -ForegroundColor Green
                            $RefreshNeeded = $true
                        }

                        #if only one module exist but not the latest version
                        ElseIf($ExistingModules.Version -ne $LatestModule.Version)
                        {
                            Write-Host ("    Found newer version [{0}]..." -f $LatestModule.Version.ToString()) -ForegroundColor Cyan -NoNewline
                            #Update module since it was found
                            If($VerbosePreference){Write-Host ("Updating Module [{0}] from [{1}] to the latest version [{2}]..." -f $ModuleName,$ExistingModules.Version,$LatestModule.Version) -NoNewline -ForegroundColor Yellow}
                            Try{
                                Update-Module $ModuleName -RequiredVersion $LatestModule.Version -Force -ErrorAction Stop -Verbose:$VerbosePreference
                            }
                            Catch{
                                #$_.Exception.GetType().FullName
                                Install-Module $ModuleName -RequiredVersion $LatestModule.Version -Scope AllUsers -AllowClobber -Force -SkipPublisherCheck -ErrorAction Stop -Verbose:$VerbosePreference
                            }
                            Write-Host ("Updated") -ForegroundColor Green
                            $RefreshNeeded = $true
                        }
                        Else
                        {
                            #No issue
                            Write-Host ("    Module [{0}] is at latest version [{1}]!" -f $ModuleName,$ExistingModules.Version) -ForegroundColor Green
                            Continue
                        }
                    }
                }
                Catch
                {
                    Write-Host ("    Failed. Error: {0}" -f $_.Exception.Message) -ForegroundColor Red

                }
                Finally
                {
                    If($AllowImport){
                        #importing module
                        Write-Host ("    Importing Module [{0}] for use..." -f $ModuleName) -ForegroundColor Green
                        Import-Module -Name $ModuleName -Force:$force -Verbose:$VerbosePreference
                    }
                }
            }
            Else{
                If($VerbosePreference){Write-Host ("    Module [{0}] does not exist, unable to update" -f $ModuleName) -ForegroundColor Red}
            }

        } #end of module loop
    }
    End{
        If($VerbosePreference){Write-Host ("{0} :: Completed module check" -f ${CmdletName}) -ForegroundColor Gray}
        If($RefreshNeeded){Write-Host ("A restart of Powershell may be required to refresh module versions.") -ForegroundColor Magenta}
        Stop-Transcript | Out-Null
    }
}

Function Compare-LatestModule{
     <#
    .SYNOPSIS
       This function will compare installed modules
    
    .DESCRIPTION
        The function will compare installed modules and output data

    .PARAMETER Name
        Specify the name of the module
    
    .EXAMPLE
        Compare-LatestModule -Name AzureAD
        Example will scan for module AzureAD on device in all locations and detemine if each one is at latest

    .EXAMPLE
        Compare-LatestModule -Name Az.Accounts,Az.Resources,Microsoft.Graph.Intune
        Example will scan for 3 modules on device in all locations and detemine if each one is at latest
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false,ValueFromPipelineByPropertyName = $true,Position=0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name
    )
    Begin{
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        $ModuleUpdateStatus = @()

        If($Name){
            Write-Host ("{0} :: Retrieving modules [{1}]..." -f ${CmdletName}, ($name -join ,''))
            $ExistingModules = Get-Module -Name $Name -ListAvailable
        }
        Else{
            Write-Host ("{0} :: Retrieving online details for all modules, this can take a while..." -f ${CmdletName})
            $ExistingModules = Get-Module -ListAvailable -All
        }
    }
    Process{
        #TEST $Name = 'PSFramework'
        #TEST $Module = $ExistingModules[0]
        #TEST $Module = $ExistingModules[1]
        #TEST $Module = $ExistingModules[-1]
        Foreach($Module in $ExistingModules)
        {
            Write-Verbose ("{0} :: Checking status for installed module [{1}]: ..." -f ${CmdletName},$Module.Name)
            $ModuleDetails = '' | Select ModuleName,Location,Count,CurrentVersion,InstalledVersions,LatestRelease,UpToDate
            $AllModules = @()
            $AllModules = $ExistingModules | Where Name -eq $Name
            $LatestModule = Find-Module -Name $Module.Name
            If($Module.version -eq $LatestModule.Version){$Updated = $true}Else{$Updated = $false}

            $ModuleDetails.ModuleName = $Module.Name
            $ModuleDetails.Location = $Module.Path
            $ModuleDetails.Count = $AllModules.Count
            $ModuleDetails.CurrentVersion = $Module.Version
            $ModuleDetails.InstalledVersions = $AllModules.Version
            $ModuleDetails.LatestRelease = $LatestModule.Version
            $ModuleDetails.UpToDate = $Updated
            $ModuleUpdateStatus += $ModuleDetails
        }
    }
    End{
        Write-Host ("{0} :: Status for {1} modules retrieved" -f ${CmdletName},$ModuleUpdateStatus.count)
        Return $ModuleUpdateStatus
    }
}

$exportModuleMemberParams = @{
    Function = @(
        'Install-LatestModule'
        'Compare-LatestModule'
    )
}

Export-ModuleMember @exportModuleMemberParams
