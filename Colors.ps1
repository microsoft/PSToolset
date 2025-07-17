# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Write-Colorized
{
    <#
    .SYNOPSIS
        Output object to stdout with specific color

    .DESCRIPTION
        Prints an object contents colorized in a specific color. Makes the output
        more readable on a console screen and the output can be still redirected
        as a regular stdout.

    .PARAMETER Color
        Name of the color to be used for coloring.
        Use Get-Colors command to output all available colors.

    .PARAMETER Object
        Object to be outputted to stdout.

    .EXAMPLE
        Write-Colorized green "=)", "test"

        Prints all items in passed string array to stdout with green color
        used in your console.

    .LINK
        Get-Colors
    #>

    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Color,
        [Parameter(Mandatory = $true)]
        [object] $Object
    )

    $previous, [Console]::ForegroundColor = [Console]::ForegroundColor, [ConsoleColor]::$color
    $object
    [Console]::ForegroundColor = $previous
}

function Show-Highlight
{
    <#
    .SYNOPSIS
        Highlight portion of some text to make it visually
        easier to find something in the text

    .DESCRIPTION
        Uses regex to find some some portion in the input text send via pipe.
        Matching text is highlighted with the color specified.

        Without regex specified this function would highlight code examples
        in the Powershell build in help.

        alias: hl

    .PARAMETER Regex
        Regular expression used to match interesting part of the input text.
        By default: regex that would match code snippets in the help examples.

    .PARAMETER Color
        Color that would be used to highlight matching text.
        By default: dark magenta

    .PARAMETER DropUnmatched
        If line doesn't match regex, don't return it.
        By default: unmatched lines are returned without highlighting

    .PARAMETER Interactive
        Render output as soon as it is received.
        By default: Out-String is called after all the input is received.

    .PARAMETER JSON
        Use pre-defined regex for JSON output.
        If user specifies $regex or color explicitly they take precedence.

    .EXAMPLE
        "test tee, please", "tee" | Show-Highlight e+ red

        Highlights all 'e' chars in the input with red.

    .EXAMPLE
        man hl -Examples | hl

        Highlights code snippets in Show-Highlight examples help.

    .EXAMPLE
        tracert bing.com | hl "[a-f0-9]+:[a-f0-9:]+" green -int

        Highlights IPv6 addresses from tracert output with green color.
        Output us rendered as soon as it is available.

    .EXAMPLE
        ls | hl ps1 -drop

        Highlights files or folders from ls output that match 'ps1' regex.
        If a line is not matching, it is dropped.

    .EXAMPLE
        Get-TimeZone | ConvertTo-Json | hl -JSON

        Highlights JSON syntax chars making output a bit more readable.

    .LINK
        Get-Colors
    #>

    param
    (
        [string] $Regex = "^\s*PS\s+.*>.+",
        [ConsoleColor] $Color = "Blue",
        [switch] $DropUnmatched,
        [switch] $Interactive,
        [switch] $JSON
    )

    begin
    {
        function Get-Markup
        {
            $start = 0
            $sections = [Regex]::Matches($line, $regex, "IgnoreCase") | select Index, Length, Value

            foreach( $section in $sections )
            {
                [ordered] @{ type = "text"; start = $start; end = $section.Index - 1 }
                [ordered] @{ type = "high"; start = $section.Index; end = $section.Index + $section.Length - 1 }
                $start = $section.Index + $section.Length
            }

            [ordered] @{ type = "text"; start = $start; end = $line.Length - 1 }
        }

        function Use-Markup
        {
            foreach( $line in ($lines | Out-String | foreach TrimEnd) -split "`r?`n" )
            {
                if( $line -notmatch $regex )
                {
                    if( -not $dropUnmatched )
                    {
                        $line
                    }
                    continue
                }

                foreach( $info in (Get-Markup | where{ $psitem.start -le $psitem.end }) )
                {
                    $text = $line.Substring($info.start, $info.end - $info.start + 1)
                    $foreground = if( $info.type -eq "text" ) { [Console]::ForegroundColor } else { $color }
                    Write-Host $text -ForegroundColor $foreground -NoNewline
                }

                Write-Host ""
            }
        }

        $lines = @()

        if( $JSON )
        {
            if( (-not $Regex) -or ($Regex -eq "^\s*PS\s+.*>.+") )
            {
                $regex = '["{}/:,]'
            }
        }
    }
    process
    {
        $lines += $psitem
        if( $interactive )
        {
            Use-Markup
            $lines = @()
        }
    }
    end
    {
        if( -not $interactive )
        {
            Use-Markup
        }
    }
}

function Get-Colors
{
    <#
    .SYNOPSIS
        Print all console host colors to the console in color

    .DESCRIPTION
        Possible color names taken from '[ConsoleColor] | gm -Static' are:
            Blue    | DarkBlue
            Cyan    | DarkCyan
            Gray    | DarkGray
            Green   | DarkGreen
            Magenta | DarkMagenta
            Red     | DarkRed
            Yellow  | DarkYellow
            White   | Black

    .EXAMPLE
        Get-Colors

        Would output all colors to the console output.
    #>

    function color( $name )
    {
        [Console]::ForegroundColor = [ConsoleColor]::$name
    }

    $previous = [Console]::ForegroundColor

    color Blue
    [Console]::Out.Write("Blue")
    color DarkBlue
    [Console]::Out.WriteLine("     DarkBlue")

    color Cyan
    [Console]::Out.Write("Cyan")
    color DarkCyan
    [Console]::Out.WriteLine("     DarkCyan")

    color Gray
    [Console]::Out.Write("Gray")
    color DarkGray
    [Console]::Out.WriteLine("     DarkGray")

    color Green
    [Console]::Out.Write("Green")
    color DarkGreen
    [Console]::Out.WriteLine("    DarkGreen")

    color Magenta
    [Console]::Out.Write("Magenta")
    color DarkMagenta
    [Console]::Out.WriteLine("  DarkMagenta")

    color Red
    [Console]::Out.Write("Red")
    color DarkRed
    [Console]::Out.WriteLine("      DarkRed")

    color Yellow
    [Console]::Out.Write("Yellow")
    color DarkYellow
    [Console]::Out.WriteLine("   DarkYellow")

    color White
    [Console]::Out.Write("White")
    color Black
    [Console]::Out.WriteLine("    Black")

    [Console]::ForegroundColor = $previous
}

function Get-Source
{
    <#
    .SYNOPSIS
        Print source code of a command or script in color

    .DESCRIPTION
        Gets sources of a command, a script or an alias and outputs
        them with syntax highlighting to the host.

        Alias: source

    .PARAMETER CommandName
        Command name or alias name or path to a Powershell script file.

    .EXAMPLE
        Get-Source hl

        Get sources of the command that is resolved from hl alias in color.
    #>

    param
    (
        [string] $CommandName
    )

    function Get-CommandSource
    {
        # Getting corresponding command object
        $command = Get-Command $commandName | select -First 1
        if( $command.CommandType -eq "Alias" )
        {
            $command = Get-Command $command.Definition
        }

        # Fixing shortcomings of $command.Definition - it truncates
        # function start for some reason
        $firstFix = $false
        $command.Definition -split "`r?`n" | foreach `
        {
            if( (-not $firstFix) -and ($psitem -match "^\S") )
            {
                ""
                "    " + $psitem
                $firstFix = $true
            }
            else
            {
                $psitem
            }
        }
    }

    # Getting source code of the command
    if( Test-Path $commandName )
    {
        $source = Get-Content $commandName
    }
    else
    {
        $source = Get-CommandSource
    }

    # Rendering sources in color
    Show-ColorizedContent $source
}

function Show-ColorizedContent
{
    param
    (
        $content = $(throw "Powershell script must be specified"),
        $highlightRanges = @(),
        [System.Management.Automation.SwitchParameter] $excludeLineNumbers
    )

    $replacementColours =
    @{
        Attribute = "DarkCyan"
        Command = "DarkCyan"
        CommandParameter = "DarkMagenta"
        CommandArgument = "Gray"
        Comment = "DarkGreen"
        Grouper = "DarkCyan"
        Keyword = "Gray"
        Member = "DarkCyan"
        Number = "DarkGray"
        Operator = "DarkRed"
        Property = "Gray"
        StatementSeparator = "DarkCyan"
        String = "DarkYellow"
        Type = "DarkCyan"
        Variable = "DarkGray"
    }
    $highlightColor = "Green"
    $highlightCharacter = ">"

    # Read the text of the file, and parse it
    $content = $content | Out-String
    $parsed = [Management.Automation.PsParser]::Tokenize($content, [ref] $null) | sort StartLine, StartColumn

    function WriteFormattedLine($formatString, [int] $line)
    {
        if($excludeLineNumbers) { return }

        $hColor = "Gray"
        $separator = "|"
        if($highlightRanges -contains $line) { $hColor = $highlightColor; $separator = $highlightCharacter }
        Write-Host -NoNewLine -Fore $hColor ($formatString -f $line, $separator)
    }

    Write-Host

    WriteFormattedLine "{0:D3} {1} " 1

    $column = 1
    foreach($token in $parsed)
    {
        $color = "Gray"

        # Determine the highlighting colour
        $color = $replacementColours[[string]$token.Type]
        if(-not $color) { $color = "Gray" }

        # Now output the token
        if(($token.Type -eq "NewLine") -or ($token.Type -eq "LineContinuation"))
        {
            $column = 1
            Write-Host
            WriteFormattedLine "{0:D3} {1} " ($token.StartLine + 1)
        }
        else
        {
            # Do any indenting
            if($column -lt $token.StartColumn)
            {
                Write-Host -NoNewLine (" " * ($token.StartColumn - $column))
            }

            # See where the token ends
            $tokenEnd = $token.Start + $token.Length - 1

            # Handle the line numbering for multi-line strings
            $lineCounter = $token.StartLine
            $stringLines = $( -join $content[$token.Start..$tokenEnd] -split "`r`n")
            foreach($stringLine in $stringLines)
            {
                if($lineCounter -gt $token.StartLine)
                {
                    WriteFormattedLine "$([Environment]::NewLine){0:D3} {1}" $lineCounter
                }
                Write-Host -NoNewLine -Fore $color $stringLine
                $lineCounter++
            }

            # Update our position in the column
            $column = $token.EndColumn
        }
    }

    Write-Host ([Environment]::NewLine)
}
