#!/usr/bin/env bash
set -e

cwd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pushd $cwd > /dev/null

export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

install_dotnet() {
    mkdir -p $DOTNET_HOME
    rm -rf $DOTNET_HOME/sdk >/dev/null # clear out potentially bad version of CLI
    channel=$(cat $cwd/cli.yml | grep 'channel' | awk '{print $2}')
    curl -sSL https://raw.githubusercontent.com/dotnet/cli/rel/1.0.0/scripts/obtain/dotnet-install.sh \
        | bash -s -- -i $DOTNET_HOME --version $DotnetCliVersion --channel $channel
    export PATH="$DOTNET_HOME:$PATH"
}

ensure_dotnet() {
    export DotnetCliVersion=$(cat $cwd/cli.yml | grep 'version' | awk '{print $2}')
    if test -x $DOTNET_HOME/dotnet && test "$($DOTNET_HOME/dotnet --version)" = $DotnetCliVersion ; then
        return
    elif which dotnet >/dev/null && "$(dotnet --version)" -eq $DotnetCliVersion; then
        local _dotnet="$(which dotnet)"
        export DOTNET_HOME="$(dirname $_dotnet)"
    else
        export DOTNET_HOME="$cwd/.dotnet"
        if test ! -x $DOTNET_HOME/dotnet || test "$($DOTNET_HOME/dotnet --version)" != $DotnetCliVersion; then
            install_dotnet
        fi
    fi
}

# Main

ensure_dotnet
printf "\033[90mUsing $DOTNET_HOME/dotnet\033[0m\n"

$DOTNET_HOME/dotnet restore build.xml
$DOTNET_HOME/dotnet msbuild build.xml /nologo /v:m "$@"
