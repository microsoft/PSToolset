$FunctionsToExport = @(
    # Colors
    "Show-Highlight", # "Write-Colorized", "Show-Highlight", "Get-Colors", "Get-Source",
    # DocFx.ps1
    "Start-DocFx",
    # Data
    "ConvertTo-PsObject", "ConvertTo-Hash",
    "Use-Project", "Use-Filter", "Get-Parameter",
    "Get-Ini", "Show-Ini", "ConvertFrom-Ini", "Import-Ini",
    # Functional
    "Get-UniqueUnsorted", #
    "Test-Any", "Test-All", "Get-First", "Get-Last", "Get-Separation",
    "Get-Median", "Get-Reverse", "Get-Randomized",
    # Files
    Resolve-ScriptPath, #"Get-FileEncoding"
)

function reload
{
    get-module pstoolset | remove-module
    ipmo \\alexko-11\C$\home\Documents\Powershell\Modules\PSToolset\PSToolset.psd1
}
$ExecutionContext.SessionState.LanguageMode = "ConstrainedLanguage"
reload