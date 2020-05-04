# The purpose and state of the repository
This module represnts a set of tools for Powershell that I find useful to have available in every Powershell console. It was started as a helper project for some daily work activities and polished over the years as an internal project. Some recent commands rely on Powershell 7 syntax, so the module is marked for PS7, although most of the commands actually should work in older Powershells.

You are welcome to use and contribute. 

# Installation
To make the module auto-discoverable by Powershell, clone it into your Powershell Modules folder without changing it's name:

```powershell
$modulesFolder = $env:PSModulePath -split ";" | select -f 1
mkdir $modulesFolder -ea Ignore
cd $modulesFolder
git clone https://github.com/microsoft/PSToolset
```

Powershell should be able to discover modue commands after that. If it doesn't you can import the module explicitly

```powershell
ipmo PSToolset
```

# Documentation
List all exported commands from the module:

```powershell
Get-Command -Module PSToolset 
```

Get detailed help for a particular function:
``` powershell
man Set-CmdEnvironment -Detailed
```

Get examples for a particular function:
```powershell
man Use-Highlight -Examples 
```

See implementation details in color:
```powershell
source construct
```

# Commands
## Colors
Name | Alias | Description
-----|-------|-------------
Get-Colors |  | Print all console host colors to the console in color
Get-Source | source | Print source code of a command or script in color
Use-Highlight | hl | Highlight portion of some text to make it visually easier to find something in the text
Write-Colorized |  | Output object to stdout with specific color

## Data
Name | Alias | Description
-----|-------|-------------
ConvertFrom-Ini |  | Converts ini strings into Powershell hashtable object
ConvertTo-Hash |  | Convert an object into a hash table
ConvertTo-PsObject | construct | Convert a set of variables into a PsObject
Get-Ini |  | Parse INI file as a hashtable object
Get-Parameter |  | Get names of all available parameters from input objects
Import-Ini |  | Imports ini file into Powershell hashtable object
Show-Ini |  | Print contents of INI parsed file, received from Get-Ini cmdlet
Use-Filter | f | Regex based parameter filter for input objects
Use-Project | p | Project several parameters from input objects

## Files
Name | Alias | Description
-----|-------|-------------
Get-FileEncoding |  | Gets file encoding
Resolve-ScriptPath |  | Resolve path that is local to the script

## Functional
Name | Alias | Description
-----|-------|-------------
Get-First | first | Returns first element in the piped in input that confirms to the condition
Get-Last | last | Returns last element in the piped in input that confirms to the condition
Get-Median |  | Calculate median of numeric array piped in
Get-Randomized |  | Randomize a sequence that is piped in
Get-Reverse |  | Reverse a sequence that is piped in
Get-Separation | separate | Separate collection into two based on some condition
Get-UniqueUnsorted |  | Get unique values from an unsorted array
Test-All | all | Test if all elements in the piped in input confirm to the condition
Test-Any | any | Test if any element in the piped in input confirms to the condition

## Git
Name | Alias | Description
-----|-------|-------------
Get-CommitAuthorDate |  | Get author commit date from a git commit
Get-CommitAuthorEmail |  | Get author email from a git commit
Get-CommitAuthorName |  | Get author name from a git commit
Get-CommitMessage |  | Get commit message from a git commit
Initialize-GitConfig |  | Configure git before the first use; assigns name and email for the current user and sets up some useful defaults
Open-GitExtensions | gite | Open GitExtensions GUI frontend, by default browse window in the current folder would be opened

## Python
Name | Alias | Description
-----|-------|-------------
Start-JupyterNotebook | jn | Start Jupyter Notebook in current folder or $env:DefaultJupyterNotebookPath. Reuse existing notebook already running if possible
Stop-JupyterNotebook |  | Stop all Jupyter Notebooks running

## Security
Name | Alias | Description
-----|-------|-------------
Invoke-Elevated |  | Invoke script in elevated Powershell session
Set-DelayLock | lock | Lock machine after the specified timeout
Test-Elevated |  | Test if current Powershell session is elevated
Test-Interactive |  | Determine if the current Powershell session is interactive

## Text
Name | Alias | Description
-----|-------|-------------
Format-Template |  | Render text template
Get-UnresolvedTemplateItem |  | Find template items that were not resolved yet
Use-Default | default | Define default value if input is null, false or missing
Use-Parse | parse | Parse incoming text to find relevant pieces in it

## Utils
Name | Alias | Description
-----|-------|-------------
Set-CmdEnvironment | call | Call .bat or .cmd file and preserve all environment variables set by it
Use-Retries |  | Retry execution of a script that throws an exception

## Xml
Name | Alias | Description
-----|-------|-------------
New-XAttribute | xattr | Create XAttribute object with specified name and value
New-XComment | xcomm | Create XComment object with specified value
New-XElement | xelem | Create XElement object and attach specified via script blocks other XObjects in a hierarchcal form
New-Xmlns | xmlns | Create Xmlns object with specified namespace and value
New-XName | xname | Create XName object with specified name


# How to regenerate table of exported commands 
``` powershell

ipmo PSToolset
$functions = get-module pstoolset | % ExportedFunctions | % Keys
$aliases = get-module pstoolset | % ExportedAliases | % Keys
$map = @{}

foreach( $function in $functions )
{
    $map.$function = @{}
    $map.$function.Name = $function
    $map.$function.File = gi (ls function: | where Name -eq $function| % ScriptBlock | % File) | % BaseName

    $map.$function.Description = man $function | select -skip 5 -First 10 | % Trim
    $map.$function.Description = foreach( $line in $map.$function.Description )
    {
        if( -not $line ){ break }
        $line
    }
    $map.$function.Description = $map.$function.Description -join " "
}

foreach( $alias in $aliases )
{
    $function = get-alias $alias | % ResolvedCommand | % Name
    $map.$function.Alias = $alias 
}

$parsed = $map.Keys | %{ [PsCustomObject] $map.$psitem }
$groups = $parsed | group File

$table = foreach( $group in $groups )
{
    "## $($group.Name)"
    "Name | Alias | Description"
    "-----|-------|-------------"
    foreach( $element in $group.Group | sort Name )
    {
        "$($element.Name) | $($element.Alias) | $($element.Description)"
    }
    ""
}
$table | clip

"Table is saved to Windows clipboard"

```
