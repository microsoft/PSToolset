# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Initialize-GitConfig
{
    <#
    .SYNOPSIS
        Configure git before the first use; assigns name and
        email for the current user and sets up some useful defaults
    #>

    [CmdletBinding()]
    param
    (
        [switch] $Force
    )

    $gitName = git config --global user.name
    if( $gitName -and (-not $Force) )
    {
        Write-Warning "Looks like git is already configured. If you want to overwrite git config settings anyway, use -Force switch."
        return
    }

    # Git name and email (required)
    if( $env:USERDOMAIN -eq "Redmond" )
    {
        # Figure out name of the current user from Active Directory
        $ntAccount = new-object Security.Principal.NTAccount($env:USERDOMAIN, $env:USERNAME)
        $sid = $ntAccount.Translate([Security.Principal.SecurityIdentifier])
        $ldap = [adsi] "LDAP://<SID=$sid>"

        git config --global user.name $ldap.cn
        git config --global user.email "$ENV:USERNAME@microsoft.com"
    }
    else
    {
        $name = Read-Host "User name"
        git config --global user.name $name

        $email = Read-Host "User email"
        git config --global user.email "$ENV:USERNAME@microsoft.com"
    }
    "Git user name and email are configured"

    git config --global --replace-all color.grep auto
    git config --global --replace-all color.grep.filename "green"
    git config --global --replace-all color.grep.linenumber "cyan"
    git config --global --replace-all color.grep.match "magenta"
    git config --global --replace-all color.grep.separator "black"
    git config --global --replace-all grep.lineNumber true
    git config --global --replace-all grep.extendedRegexp true

    git config --global --replace-all color.diff.meta "yellow"
    git config --global --replace-all color.diff.frag "cyan"
    git config --global --replace-all color.diff.func "cyan bold"
    git config --global --replace-all color.diff.commit "yellow bold"
    "Git defaults are configured"

    # Aliases for the most used commands
    git config --global alias.co checkout
    git config --global alias.ci commit
    git config --global alias.st status
    git config --global alias.br branch
    git config --global alias.lg "log --graph --pretty=format:'%C(reset)%C(yellow)%h%C(reset) -%C(bold yellow)%d%C(reset) %s %C(green)(%cr) %C(cyan)<%an>%C(reset)' --abbrev-commit --date=relative -n 10"
    git config --global alias.gr "grep --break --heading --line-number -iIE"
    "Git aliases are configured"
}

function Open-GitExtensions
{
    <#
    .SYNOPSIS
        Open GitExtensions GUI frontend, by default browse window
        in the current folder would be opened

    .PARAMETER Args
        Any arguments that should be passed to the git extensions

    .EXAMPLE
        gite commit

        Open git extension comit dialog for the repo in the current folder

    #>

    if( -not (gcm GitExtensions.exe -ea Ignore) )
    {
        throw "GitExtensions.exe must be discoverable via PATH environment variable"
    }

    $param = $args
    if( -not $param ) { $param = @("browse") }
    & GitExtensions.exe $param
}

function Get-CommitAuthorName( [string] $commit )
{
    <#
    .SYNOPSIS
        Get author name from a git commit
    #>

    git log -1 --pretty=format:'%aN' $commit
}

function Get-CommitAuthorEmail( [string] $commit )
{
    <#
    .SYNOPSIS
        Get author email from a git commit
    #>

    git log -1 --pretty=format:'%aE' $commit
}

function Get-CommitAuthorDate( [string] $commit )
{
    <#
    .SYNOPSIS
        Get author commit date from a git commit
    #>

    git log -1 --pretty=format:'%ai' $commit
}

function Get-CommitMessage( [string] $commit )
{
    <#
    .SYNOPSIS
        Get commit message from a git commit
    #>

    git log -1 --pretty=format:'%B' $commit
}
