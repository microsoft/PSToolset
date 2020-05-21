# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Invoke-Elevated
{
    <#
    .SYNOPSIS
        Invoke script in elevated Powershell session

    .DESCRIPTION
        Executes script in an elevated Powershell session. If elevation is needed,
        user is prompted via UAC, new elevated process is created, input and output
        objects are transferred between processes.

        Beware that not all objects are deserialized well by internally used
        Import-CliXml. If output received is unreadable try using | Out-String
        at the end of the script.

    .PARAMETER Scriptblock
        Script block that needs to be invoked in elevated session.

    .PARAMETER State
        State object that would be passes as argument to the executed script.
        On elevation state is serialized via Export-CliXml.

    .EXAMPLE
        PS> $name = "test"
        PS> $cred = Get-Credential
        PS> $state = construct name cred
        PS> Invoke-Elevated { param( $state ) $state; Test-Elevated } $state

        This sample shows how to call script in elevated session and pass a
        complex argument into it. Test-Elevated would return true here.

    .NOTES
        For text output it is possible to redirect it to the main program in async
        way. But that would not work for Powershell objects.
    #>

    param
    (
        [Parameter(Mandatory = $true)] [ScriptBlock] $Scriptblock,
        [object] $State
    )

    # Do direct invoke if we are already elevated
    if( Test-Elevated )
    {
        return & $scriptblock $state
    }

    # Prepare input and output files
    $stateFile = [IO.Path]::GetTempFileName()
    $outputFile = [IO.Path]::GetTempFileName()
    $state | Export-CliXml -Depth 1 $stateFile

    # Prepare encoded command to be called
    $commandString = @"
Set-Location '$($pwd.Path)'
`$state = Import-CliXml '$stateFile'
`$output = & { $($scriptblock.ToString()) } `$state *>&1
`$output | Export-CliXml -Depth 1 '$outputFile'
"@
    $commandBytes = [Text.Encoding]::Unicode.GetBytes($commandString)
    $commandEncoded = [Convert]::ToBase64String($commandBytes)
    $commandLine = "-EncodedCommand $commandEncoded"

    # Start elevated PowerShell process
    try
    {
        $process = Start-Process `
            -FilePath (Get-Command powershell).Definition `
            -ArgumentList $commandLine `
            -WindowStyle Hidden `
            -Verb RunAs `
            -Passthru
    }
    catch
    {
        # This is to make cancelled UAC a terminating error
        # -ea Stop doesn't work here for some reason
        throw
    }
    $process.WaitForExit()

    # Return output to the user and cleaning up
    Import-CliXml $outputFile
    Remove-Item $outputFile
    Remove-Item $stateFile
}

function Test-Interactive
{
    <#
    .SYNOPSIS
        Determine if the current Powershell session is interactive

    .DESCRIPTION
        Interactive shell should have human being observing it =) You can ask
        something him/her via Read-Host command. If there is no human being,
        no reason to ask, right?

    .EXAMPLE
        Test-Interactive

        Would return true for a regular Powershell session.
        Would return false for an automation job.
        Would return false for a remote session.
        Does not detect -NonInteractive Powershell calling argument.
    #>

    [Environment]::UserInteractive
}

function Test-Elevated
{
    <#
    .SYNOPSIS
        Test if current Powershell session is elevated

    .DESCRIPTION
        Several commands need to be executed in an elevated session to
        have administrator rights. This function allows safely and robustly
        detect if current session is elevated.

    .EXAMPLE
        Test-Elevated

        Would return true for an elevated Powershell session with administrator
        rights.
        Would return false for a regular Powershell session.
        Would return true for a remote Powershell session that is started under
        user that is a local administrator (by default in Powershell 3.0/Windows
        there is no way of running not elevated remote session if the user in in
        the administrator group).
    #>

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal] $identity
    $role = [Security.Principal.WindowsBuiltInRole] "Administrator"
    $principal.IsInRole($role)
}

function Set-DelayLock
{
    <#
    .SYNOPSIS
        Lock machine after the specified timeout
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification='Intended to be this way')]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Minutes")] [int] $Minutes,
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "TimeSpan")] [timespan] $Timeout
    )

    if( $Minutes )
    {
        $Timeout = [timespan]::FromMinutes($Minutes)
    }

    "Setting timer for $timeout"
    "Computer would lock at $((Get-Date) + $timeout)"
    Start-Job -ArgumentList ($timeout.TotalSeconds) -ScriptBlock {
        Start-Sleep -Seconds $args[0]
        rundll32.exe user32.dll,LockWorkStation
    } | Out-Null
}