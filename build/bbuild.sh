#!/bin/bash

# ATTENTION: DEVELOPERS ARE NOT ALLOWED TO CHANGE THIS SCRIPT
#            CONTACT THE BUILD ENGINEER IF YOU NEED CHANGES
#
#            THIS SCRIPT SHOULD ONLY BE EXECUTED IN A DOCKER CONTAINER 

#-----------------------------------------------------------------------------
# This script is used by Bamboo to call the developers bbuild_all.sh 
# script and to improve error checking. The Bamboo build plan will
# call this script and pass in the build paramaters to the bbuild_all.sh
# script. Provided the developers do not change the name of the build script,
# the Bamboo builder will require no modifications to take advantage of the 
# developer's build changes.
#
# The functions.sh script may need to be modified when the build environment changes.
# For example, a new verson of Qt, library or compiler is installed.
#-----------------------------------------------------------------------------

#----------------------------
# Expected Input:
# {source_path} to top-level of source tree
# [BuildType] option to a BUILDER type (BUILDER=1)"
# [run_tests} option to run unit tests [TRUE, FALSE]
# [target] option to build in release or debug mode [BUILD=Release]

EXPECTED_ARGS=1
E_BADARGS=65

if [ $# -lt $EXPECTED_ARGS ]
then
    clear
    echo "Usage: `basename $0` {source_path} [BuildType] [run_tests] [target]"
    echo "Where: [BuildType] = BUILDER=1, NONE"
    echo "       [run_tests] = TRUE, FALSE"
    echo "          [target] = BUILD=Release"
    echo
    echo "WARNING:  This script needs to run inside a Docker Container."
    echo 
    UNAME=`uname -s`
    if [[ $UNAME == *Linux* ]]; then
        echo "Linux Non-Interactive Example:"
        echo
        echo "docker run --rm --mount type=bind,source="$(pwd)/../..",target=/srv/workspace --workdir /srv/workspace/libraries/build -it stash.nov.com:5006/deb9/build/novos-build-linux:latest bash ./`basename $0` .. BUILDER=1 FALSE BUILD=Release"
        echo 
        echo "Linux Interactive Example:"
        echo
        echo "docker run --rm --mount type=bind,source="$(pwd)/../..",target=/srv/workspace --workdir /srv/workspace/libraries/build -it stash.nov.com:5006/deb9/build/novos-build-linux:latest bash"
        echo 
    else
        dirname `pwd` | sed 's./.\\.g' | cut -c 2- | sed "s/^c/c:/g" > workdir.txt
        WORKPATH=`cat workdir.txt`
        rm workdir.txt
        echo "Windows Non-Interactive (Command or Powershell) Example:"
        echo
        echo 'docker run --rm --mount type=bind,source='$WORKPATH',target=c:\code --workdir c:\code\build -it stash.nov.com:5006/win/build/novos-build-win:latest powershell c:\Git\bin\bash.exe' ./`basename $0` '.. BUILDER=1 FALSE BUILD=Release'
        echo
        echo "Windows Interactive (Command or Powershell) Example:"
        echo
        echo 'docker run --rm --mount type=bind,source='$WORKPATH',target=c:\code --workdir c:\code\build -it stash.nov.com:5006/win/build/novos-build-win:latest powershell c:\Git\bin\bash.exe'
        echo
    fi
    exit $E_BADARGS
fi

#----------------------------
# Commands Passed into script
#----------------------------
NOVOS_ROOT=$1
BUILDER="$2"
NOVOS_TEST=$3
TARGET="$4"

BUILD_ROOT=`pwd`
OSTYPE=`uname -msr`

source functions.sh

#set_qmake_path

rm -f .out
if [[ $OSTYPE == *MING* ]]; then
    echo "Copying source to workspace ..."
    cd ..
    mkdir -p ~/workspace
    tar -c --exclude='.[^/]*' --exclude=builder . | tar -x -C ~/workspace
    cd ~/workspace/build
    echo "Done"
    if [[ $BUILDER == "NONE" ]]; then
        ./bbuild_all.sh $NOVOS_ROOT "" $NOVOS_TEST $TARGET 2>&1 | tee $BUILD_ROOT/.out
    else
        ./bbuild_all.sh $NOVOS_ROOT $BUILDER $NOVOS_TEST $TARGET 2>&1 | tee $BUILD_ROOT/.out
    fi
    echo "Copying Build to source ..."
    cp -rpu .. c:/code
    echo "Done"
else
    if [[ $BUILDER == "NONE" ]]; then
        echo ./bbuild_all.sh $NOVOS_ROOT "" $NOVOS_TEST $TARGET
    else
        echo ./bbuild_all.sh $NOVOS_ROOT $BUILDER $NOVOS_TEST $TARGET
    fi
fi

#check_for_log_errors
