# Load cmdlets from module subfolder
$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

Get-ChildItem "$ModuleRoot\Cmdlets\*.ps1" | ForEach-Object -Process {
    Export-ModuleMember $_.BaseName
}
