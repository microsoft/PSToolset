# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

@{

# Script module or binary module file associated with this manifest
RootModule = 'PSToolset.psm1'

# Version number of this module.
ModuleVersion = '0.9.0'

# ID used to uniquely identify this module
GUID = 'c2b885a6-dafe-4aff-9045-414874b9db36'

# Author of this module
Author = 'Aleksandr Kostikov, alexko@microsoft.com'

# Copyright statement for this module
Copyright = '(c) Microsoft Corporation'

# Description of the functionality provided by this module
Description = 'Toolset for Powerhsell environment'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '7.0'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = @(
    'all',
    'any',
    'call',
    'construct',
    'default',
    'f', # filter
    'first',
    'gite',
    'hl', # highlight
    'jn', # jyputer notebook
    'last',
    'lock',
    'p', # project
    'parse',
    'separate',
    'source',
    'xattr',
    'xcomm',
    'xelem',
    'xmlns',
    'xname'
)

# Functions to export from this module
FunctionsToExport = @(
    # Colors
    "Write-Colorized", "Use-Highlight", "Get-Colors", "Get-Source",
    # Data
    "ConvertTo-PsObject", "ConvertTo-Hash",
    "Get-Parameter", "Use-Project", "Use-Filter",
    "Get-Ini", "Show-Ini", "ConvertFrom-Ini", "Import-Ini",
    # Files
    "Resolve-ScriptPath", "Get-FileEncoding",
    # Functional
    "Test-Any", "Test-All", "Get-First", "Get-Last", "Get-Separation",
    "Get-Median", "Get-Reverse", "Get-UniqueUnsorted", "Get-Randomized",
    # Git
    "Initialize-GitConfig", "Open-GitExtensions",
    "Get-CommitAuthorName", "Get-CommitAuthorEmail",
    "Get-CommitAuthorDate", "Get-CommitMessage",
    # Python
    "Start-JupyterNotebook", "Stop-JupyterNotebook",
    # Security
    "Invoke-Elevated", "Test-Interactive", "Test-Elevated", "Set-DelayLock",
    # Text
    "Use-Parse", "Use-Default", "Format-Template", "Get-UnresolvedTemplateItem",
    # Utils
    "Use-Retries", "Set-CmdEnvironment",
    # Xml
    "New-XName", "New-XAttribute", "New-Xmlns", "New-XComment", "New-XElement"
)

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @()

# List of all files packaged with this module
FileList =
    'Colors.ps1',
    'Data.ps1',
    'Files.ps1',
    'Functional.ps1',
    'Git.ps1',
    'PSToolset.psd1',
    'PSToolset.psm1',
    'Python.ps1',
    'Security.ps1',
    'TabExpansion.ps1',
    'Text.ps1',
    'Utils.ps1',
    'Xml.ps1'
}