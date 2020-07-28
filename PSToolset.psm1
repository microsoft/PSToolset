# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# Scripts use some not-strict mode features
Set-StrictMode -Off

# Include all used files
. "$PSScriptRoot\Colors.ps1"
. "$PSScriptRoot\Data.ps1"
. "$PSScriptRoot\DocFx.ps1"
. "$PSScriptRoot\Files.ps1"
. "$PSScriptRoot\Functional.ps1"
. "$PSScriptRoot\Git.ps1"
. "$PSScriptRoot\Python.ps1"
. "$PSScriptRoot\Security.ps1"
. "$PSScriptRoot\TabExpansion.ps1"
. "$PSScriptRoot\Text.ps1"
. "$PSScriptRoot\Utils.ps1"
. "$PSScriptRoot\Xml.ps1"

# Test that no other version of this module is imported
if( Get-Module PSToolset )
{
    Write-Warning 'Several versions of PSToolset detected. Check your $PROFILE and $env:PSModulePath and cleanup extra modules via Remove-Module.'
}

# Setting up aliases
Set-Alias all       Test-All
Set-Alias any       Test-Any
Set-Alias call      Set-CmdEnvironment
Set-Alias construct ConvertTo-PsObject
Set-Alias default   Use-Default
Set-Alias dfx       Start-DocFx
Set-Alias first     Get-First
Set-Alias f         Use-Filter
Set-Alias gite      Open-GitExtensions
Set-Alias hl        Show-Highlight
Set-Alias jn        Start-JupyterNotebook
Set-Alias last      Get-Last
Set-Alias lock      Set-DelayLock
Set-Alias lookup    Get-Lookup
Set-Alias p         Use-Project
Set-Alias parse     Use-Parse
Set-Alias separate  Get-Separation
Set-Alias source    Get-Source
Set-Alias xattr     New-XAttribute
Set-Alias xcomm     New-XComment
Set-Alias xelem     New-XElement
Set-Alias xmlns     New-Xmlns
Set-Alias xname     New-XName