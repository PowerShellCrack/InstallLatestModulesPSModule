# A module to update powershell modules

## Prerequisites

No prerequisites are needed

## Install

```powershell
Install-Module InstallLatestModule -Force
```

## Cmdlets

### IDMGraph.ps1
- **Install-LatestModule** : install and update modules to latest version

## logging

Default location is **\<tempdir\>\\Modules_Install-LatestModule_\<date\>.log**

## Examples

```powershell

Install-LatestModule -All
#Example will update all modules installed under C:\Program #Files\WindowsPowerShell\Modules

Install-LatestModule -Name AzureAD
#Example will scan for module AzureAD and check its version. it will update if older than PSGallery's latest version

Install-LatestModule -Name Az.Accounts,Az.Resources,Microsoft.Graph.Intune
#Example will scan for module AzureAD and check its version. it will update if older than PSGallery's latest version

Install-LatestModule -Name AzureAD -Force
#Example will scan for module AzureAD and check its version. If the version is already up-to-date; Force will reinstall it

Get-Module -ListAvailable | Install-LatestModule
#Example will scan for module AzureAD and check its version. If the version is already up-to-date; Force will reinstall it
```
