# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    "PSAvoidGlobalVars", "",
    Justification = "We need global PSToolsetLastRetryError here")]
param()

function Use-Retries
{
    <#
    .SYNOPSIS
        Retry execution of a script that throws an exception

    .DESCRIPTION
        Retries to execute the 'Action' script. If any exception is thrown,
        next sleep interval is taken from 'RetryIntervalsInMinutes' array.
        If all retries fail an error is thrown.

        -Verbose would print retry log to verbose stream

    .PARAMETER Action
        Script block that is used for retries.

    .PARAMETER RetryIntervalsInMinutes
        Array of retry intervals used between retries.
        Could be empty (the case of a single execution of the action script
        without any retries) Could not be null.

    .EXAMPLE
        Use-Retries $sendMail (0.1, 1, 5, 10, 30)

        Retry $sendMail script block. In case of any exception happened during
        the script block execution perform a retry. Retries should be done with
        gradually increasing retry time interval. If all retries failed then
        error would be thrown.
    #>
    param
    (
        [Parameter(Mandatory = $true)]
        [scriptblock] $Action,
        [ValidateNotNull()]
        [double[]] $RetryIntervalsInMinutes
    )

    # Perform action with retries
    $command = Get-PSCallStack | select -Skip 1 -First 1 | foreach{ "{0} from {1}" -f $psitem.Command, $psitem.Location } | Out-String | foreach Trim
    $retryIntervalsInMinutes += 0

    foreach( $interval in $retryIntervalsInMinutes )
    {
        try
        {
            return & $action
        }
        catch
        {
            $GLOBAL:PSToolsetLastRetryError = $psitem

            Write-Verbose "Retryable action $command failed with error:"
            Expand-Exception $GLOBAL:PSToolsetLastRetryError.Exception | Write-Verbose
            Write-Verbose $GLOBAL:PSToolsetLastRetryError.InvocationInfo.PositionMessage
            Write-Verbose "Waiting before the next retry attempt: $interval (minutes)"

            Start-Sleep -Seconds ($interval * 60)
        }
    }

    throw "$command failed after $($retryIntervalsInMinutes.Count) attempts. See last error is stored in " + '$GLOBAL:PSToolsetLastRetryError or see verbose log for inner exceptions.'
}

function Set-CmdEnvironment
{
    <#
    .SYNOPSIS
        Call .bat or .cmd file and preserve all environment variables set by it

    .DESCRIPTION
        Calls .bat or .cmd file, asynchronously prints all stdout and stderr output
        from it and saves all environment variables that the file sets into the
        current Powershell session.
        - Stderr is outputted into stdout.
        - Output coloring is not preserved.

    .PARAMETER Script
        Path to .bat or .cmd script to execute.

    .PARAMETER Parameters
        Optional .bat or .cmd script parameters.

    .PARAMETER InheritPSModulePath
        Set this switch if you want to inherit $env:PSModulePath from the
        current process. This switch was made as a workaround. When you call
        cmd that calls old powershell.exe it by default would try to use
        modules from pwsh and would fail. So instead we change that default
        to populate PSModulePath from machine and user environment variables
        instead.

        We don't do that for the whole environment as Start-Process switch
        -UseNewEnvironment does since this way we are missing essential parts
        of the environment that turned out to be quite needed.

    .EXAMPLE
        Set-CmdEnvironment set-env-variables.bat

        Will execute 'set-env-variables.bat' script, dump all environment variables
        and transfer them into Powershell host. All original output will be shown as
        well.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Intended to be this way')]
    param
    (
        [Parameter( Mandatory = $true )]
        [ValidatePattern('^.+(\.bat|\.cmd|\.exe)$')]
        [string] $Script,
        [string] $Parameters,
        [switch] $InheritPSModulePath
    )

    # Showing progress
    $info = "Calling $script $parameters"
    $lastProgressOutput = "Initialization"
    Write-Progress $info $lastProgressOutput

    # Helper objects
    $preserved, $GLOBAL:shared = $GLOBAL:shared, @{
        marker = [Guid]::NewGuid().ToString()
        afterMarker = $false
        lineQueue = New-Object Collections.Concurrent.ConcurrentQueue[string]
    }
    $line = ""
    $lineQueue = $GLOBAL:shared.lineQueue

    # Initialize process object
    $process = [Diagnostics.Process] @{
        StartInfo = [Diagnostics.ProcessStartInfo] @{
            FileName = (Get-Command 'cmd').Definition
            Arguments = "/c `"$script`" $parameters & echo $($GLOBAL:shared.marker) & set"
            WorkingDirectory = (Get-Location).Path
            UseShellExecute = $false
            RedirectStandardError = $true
            RedirectStandardOutput = $true
            RedirectStandardInput = $false
        }
    }

    # Check if we need to reinitialize PSModulePath
    if( -not $inheritPSModulePath )
    {
        if( $process.StartInfo.EnvironmentVariables.ContainsKey("PSModulePath") )
        {
            $process.StartInfo.EnvironmentVariables.Remove("PSModulePath") | Out-Null
        }

        $value = @(
            [Environment]::GetEnvironmentVariable("PSModulePath", "Machine") + ";" +
            [Environment]::GetEnvironmentVariable("PSModulePath", "User")
        )
        $process.StartInfo.EnvironmentVariables.Add("PSModulePath", $value) | Out-Null
    }

    try
    {
        # Hook into the standard output and error stream events
        $stdoutJob = Register-ObjectEvent $process OutputDataReceived -Action `
        {
            if( $GLOBAL:shared.afterMarker )
            {
                $GLOBAL:output += $eventArgs.Data
                $split = $eventArgs.Data -split "="
                $value = ($split | select -Skip 1) -join "="
                Set-Content "env:\$($split[0])" $value
            }
            else
            {
                $GLOBAL:shared.afterMarker = $eventArgs.Data.Trim() -eq $GLOBAL:shared.marker
                if( -not $GLOBAL:shared.afterMarker ) { $GLOBAL:shared.lineQueue.Enqueue($eventArgs.Data) }
            }
        }
        $stderrJob = Register-ObjectEvent $process ErrorDataReceived -Action `
        {
            $GLOBAL:shared.lineQueue.Enqueue($eventArgs.Data)
        }

        # Start process and start async read from stdout and stderr
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        # Stopwatches that we use
        $totalStopwatch = [System.Diagnostics.Stopwatch]::new()
        $totalStopwatch.Restart()

        $stopwatch = [System.Diagnostics.Stopwatch]::new()
        $stopwatch.Restart()

        # Wait until process exit and dump stdout and stderr from it
        while( -not $process.HasExited )
        {
            $newOutput = $false

            while( $lineQueue.TryDequeue([ref] $line) )
            {
                $line

                $lastProgressOutput = if( [string]::IsNullOrWhiteSpace($line) )
                {
                    "..."
                }
                else
                {
                    $line
                }

                Write-Progress $info $lastProgressOutput

                $newOutput = $true
                $stopwatch.Restart()
            }

            Start-Sleep -Milliseconds 100

            if( -not $newOutput )
            {
                if( $PSVersionTable.PSVersion -ge 7.2 )
                {
                    $totalText = $totalStopwatch.Elapsed.ToString("hh\:mm\:ss\.f")
                    $localText = $stopwatch.Elapsed.ToString("hh\:mm\:ss\.f")
                    $output = "Total $totalText | Current $localText"
                    Write-Progress $info $output
                }
                else
                {
                    Write-Progress $info $lastProgressOutput -CurrentOperation $stopwatch.Elapsed.ToString("hh\:mm\:ss\.f")
                }
            }
        }
    }
    finally
    {
        # Cleanup that would work even if Ctrl+C is hit
        $process.CancelOutputRead()
        $process.CancelErrorRead()
        $process.Close()
        Remove-Job $stdoutJob -Force
        Remove-Job $stderrJob -Force
        $GLOBAL:shared = $preserved
    }

    # Draining line queue
    while( $lineQueue.TryDequeue([ref] $line) )
    {
        Write-Progress $info $lastProgressOutput
        $line
    }

    Write-Progress $info "Done" -Completed
}