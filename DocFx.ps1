# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Start-DocFx
{
    <#
    .SYNOPSIS
        Start docfx in current folder or $env:DefaultDocFxPath.
        Reuse existing docfx instance already running if possible.

    .PARAMETER Force
        Don't reuse anything and don't use defaults.
        Just open a new docfx in the current folder.

    .EXAMPLE
        Start-DocFx

        Tries to reopen a currently opened docfx.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Intended to be this way')]
    param
    (
        [switch] $Force
    )

    # Test if docfx is installed
    if( -not (Get-Command docfx.exe -ea Ignore) )
    {
        throw "docfx.exe must be discoverable via PATH environment variable"
    }

    # Cleanup cleanup jobs =)
    $cleanupJobName = "Start-DocFx cleanup"
    Get-Job $cleanupJobName -ea Ignore | where State -eq Completed | Remove-Job

    # Helper function
    function Open-DocFx( $folder = $pwd )
    {
        Push-Location $folder
        $path = Get-ChildItem -Recurse "docfx.json" | select -First 1
        Pop-Location

        $ps = Start-Process `
            -FilePath "pwsh" `
            -ArgumentList ('-Command "docfx ' + $path + ' --serve"') `
            -WorkingDirectory $folder `
            -WindowStyle Hidden `
            -PassThru

        Start-Job -Name $cleanupJobName {
            Start-Sleep -Seconds 60
            $ps | Stop-Process

        } | Out-Null

        Start-Process http://localhost:8080
    }

    # When need to open new docfx in current folder
    if( $Force )
    {
        "Open new docfx in current folder $pwd"
        Open-DocFx
        return
    }

    # Trying to reuse opened docfx if possible
    if( Get-Process docfx -ea Ignore )
    {
        "Found existing docfx, reopening default URL"
        Start-Process http://localhost:8080
        return
    }

    # Run notebook from default location if possible
    if( $env:DefaultDocFxPath )
    {
        "Open new docfx in `$env:DefaultDocFxPath = $env:DefaultDocFxPath"
        Open-DocFx $env:DefaultDocFxPath
    }
    else
    {
        "Open new docfx in current folder $pwd, note that you can use `$env:DefaultDocFxPath instead if you define it"
        Open-DocFx
    }
}