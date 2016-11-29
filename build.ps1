$ErrorActionPreference='Stop'

cd $PSScriptRoot

$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

function install_dotnet {
    mkdir $env:DOTNET_HOME -ErrorAction Ignore | Out-Null
    rm -Recurse -Force $env:DOTNET_HOME/sdk -ErrorAction Ignore
    $channel=($(sls 'channel' $PSScriptRoot/cli.yml | select -exp line) -split ': ')[1]
    Invoke-WebRequest https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0/scripts/obtain/dotnet-install.ps1 -OutFile $env:DOTNET_HOME/dotnet-install.ps1
    & $env:DOTNET_HOME/dotnet-install.ps1 -InstallDir $env:DOTNET_HOME -Version $env:DotnetCliVersion -Channel $channel
    $env:PATH = "${env:DOTNET_HOME};${env:PATH}"
}

function ensure_dotnet {
    $env:DotnetCliVersion = ($(sls 'version' $PSScriptRoot/cli.yml | select -exp line) -split ': ')[1]
    if ((Test-Path "$env:DOTNET_HOME/dotnet.exe") -and "$(& $env:DOTNET_HOME/dotnet.exe --version)" -eq $env:DotnetCliVersion) {
        return
    }

    $globalDotnet = Get-Command dotnet
    if ((Test-Path $globalDotnet.Path) -and "$(& $globalDotnet.Path --version)" -eq $env:DotnetCliVersion) {
        $env:DOTNET_HOME = Split-Path $globalDotnet.Path -Parent
    } else {
        $env:DOTNET_HOME = "$PSScriptRoot/.dotnet"
        if ( !(Test-Path $env:DOTNET_HOME/dotnet.exe) -or "$(& $env:DOTNET_HOME/dotnet.exe --version)" -ne $env:DotnetCliVersion) {
            install_dotnet
        }
    }
}

# Main

ensure_dotnet
Write-Host -ForegroundColor Gray "Using $env:DOTNET_HOME/dotnet.exe"

& $env:DOTNET_HOME/dotnet.exe restore build.xml
if ($LASTEXITCODE -ne 0) {
    throw 'Restoring packages for build.xml failed'
}
& $env:DOTNET_HOME/dotnet.exe msbuild build.xml /nologo /v:m $args
