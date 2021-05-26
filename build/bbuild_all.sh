#! /bin/bash

#----------------------------
# Expected Input:
# --path to top-level of source tree

EXPECTED_ARGS=1
E_BADARGS=65
ROOT_DIR=`pwd`
LIB_ROOT=$1
BUILDER=`echo $2 | tr '[a-z]' '[A-Z]'`
NOVOS_TEST=`echo $3 | tr '[a-z]' '[A-Z]'`
let FAILURES=0
let SUCCESSES=0
TARGET=`echo $4 | tr '[a-z]' '[A-Z]'`
OSTYPE=`uname -msr`
TGT=libdebug
UNAME=`uname -s`

if [ $# -lt $EXPECTED_ARGS ]
then
    clear
    echo "Usage: `basename $0` {source_path} [BuildType] [run_tests] [target]"
    echo 'Where: [BuildType] = BUILDER=1 or "" '
    echo "       [run_tests] = TRUE, FALSE"
    echo "          [target] = BUILD=Release (Default: BUILD=Debug)"
    echo '(Note: To add make options use: export MAKE_OPTIONS="<options>"'
    echo
    echo "WARNING:  This script needs to run inside a Docker Container."
    echo
    UNAME=`uname -s`
    if [[ $UNAME == *Linux* ]]; then
        echo "Linux Non-Interactive Example:"
        echo
        echo "docker run --mount type=bind,source="$(pwd)/../..",target=/srv/workspace --workdir /srv/workspace/libraries/build -it stash.nov.com:5006/deb9/build/novos-build-linux:latest bash ./`basename $0` .. BUILDER=1 FALSE BUILD=Release"
        echo
        echo "Linux Interactive Example:"
        echo
        echo "docker run --mount type=bind,source="$(pwd)/../..",target=/srv/workspace --workdir /srv/workspace/libraries/build -it stash.nov.com:5006/deb9/build/novos-build-linux:latest bash"
        echo
    else
        dirname "$(dirname `pwd`)}" | sed 's./.\\.g' |cut -c 2- | sed "s/^c/c:/g" > workdir.txt
        WORKPATH=`cat workdir.txt`
        rm workdir.txt
        echo "Windows Non-Interactive (Command or Powershell) Example:"
        echo
        echo 'docker run --mount type=bind,source='$WORKPATH',target=c:\code --workdir c:\code\libraries\build -it stash.nov.com:5006/win/build/novos-build-win:latest powershell c:\Git\bin\bash.exe' ./`basename $0` '.. BUILDER=1 FALSE BUILD=Release'
        echo
        echo "Windows Interactive (Command or Powershell) Example:"
        echo
        echo 'docker run --mount type=bind,source='$WORKPATH',target=c:\code --workdir c:\code\libraries\build -it stash.nov.com:5006/win/build/novos-build-win:latest powershell c:\Git\bin\bash.exe'
        echo
    fi
    exit $E_BADARGS
fi

#-------------------------------------
# Version dependend variables
# RTI
RTI_VERSION='6.0.0'
RTI_HOME_LINUX='/opt/rti'
RTI_HOME_WINDOWS='C:/RTI'
RTI_LIB_LINUX='x64Linux3gcc5.4.0'
RTI_LIB_WINDOWS='i86Win32VS2017'

# QT
QMAKE='C:\Qt\Qt5.12.0\5.12.0\msvc2017\bin\qmake.exe'
QMAKESPEC='win32-msvc'
QTCREATORPATH_WINDOWS='C:\Qt\Qt5.12.0\Tools\QtCreator\bin\'

# Visual Studio
VCVARSALL='c:\BuildTools\VC\Auxiliary\Build\vcvarsall.bat'
MSVC_ARCH='amd64_x86'
#-------------------------------------

#----------------------------
# Functions used in script
#----------------------------
source functions.sh
set_release_flag $TARGET
set_deb_ver

#------------------------------------------------------------------------------
# If running in Builder Mode (BUILDER=1) then set the NDDS* env vars for
# Linux and Windows.  Otherwise, expect the host to already have the variables
# defined.
#------------------------------------------------------------------------------
function set_ndds_environment()
{
    echo "BUILDER: $BUILDER"

    if [[ $UNAME == *Linux* ]]
    then
        export NDDS_HOME=$RTI_HOME_LINUX/rti_connext_dds-$RTI_VERSION
        export NDDS_BIN=$NDDS_HOME/bin
        export NDDS_INC=$NDDS_HOME/include
        export NDDS_LIB=$NDDS_HOME/lib/$RTI_LIB_LINUX

        echo $LD_LIBRARY_PATH | grep "$NDDS_LIB" &> /dev/null
        if [ "$?" != 0 ]
        then
            export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$NDDS_LIB
        fi

        echo $PATH | grep "$NDDS_BIN" &> /dev/null
        if [ "$?" != "0" ]
        then
            export PATH="$PATH:$NDDS_BIN"
        fi
    elif [[ $UNAME == *MING* ]] && [[ $BUILDER == "BUILDER=1" ]]
    then
        export NDDS_HOME=$RTI_HOME_WINDOWS/rti_connext_dds-$RTI_VERSION
        export NDDS_BIN=$NDDS_HOME/bin
        export NDDS_INC=$NDDS_HOME/include
        export NDDS_LIB=$NDDS_HOME/lib/$RTI_LIB_WINDOWS

        if [ -z "$TOP_DIR" ]
        then
            pushd $ROOT_DIR/..
            export TOP_DIR=$(pwd)
            popd
        fi
        echo "TOP_DIR: $TOP_DIR"
    fi

    echo ""
    echo "NDDS_HOME: $NDDS_HOME"
    echo "NDDS_BIN:  $NDDS_BIN"
    echo "NDDS_INC:  $NDDS_INC"
    echo "NDDS_LIB:  $NDDS_LIB"
    echo ""
    echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
    echo "PATH: $PATH"
    echo ""
}

function build_windows()
{
    pushd_e $LIB_ROOT

    echo cmd //c "build\msvc_jom_build.bat" "$VCVARSALL" "$MSVC_ARCH" "$QTCREATORPATH_WINDOWS" "$QMAKE" "$QMAKESPEC"
    cmd //c "build\msvc_jom_build.bat" "$VCVARSALL" "$MSVC_ARCH" "$QTCREATORPATH_WINDOWS" "$QMAKE" "$QMAKESPEC"
    RC=$?

    popd
}

function copy_qos_file()
{
   pushd_e $LIB_ROOT

   if ! [ -d topics/qos ]; then
       echo "Can't find topics/qos directory!"
       exit 1
   fi

   cp topics/qos/NovosQosProfiles.xml lib/

   popd
}


function build_libs()
{
    echo "Building Libraries..."
    echo $OSTYPE
    set_ndds_environment
    if [[ $OSTYPE == *MING* ]]; then
        echo "#--------------------------------------------------------------"
        echo "# Building libraries for windows"
        echo "#--------------------------------------------------------------"
        build_windows
        exit_on_errors_in_log
        copy_qos_file
    else
        CORE_COUNT=$(nproc)
        pushd_e $LIB_ROOT
        make clean
        make $TARGET all -j${CORE_COUNT}
        exit_on_errors
        make $TARGET doc
        exit_on_errors
        make TARG_BUILD_NUMBER=${PHASE_ID}${BUILD_NUM} $TARGET deb
        exit_on_errors
        make TARG_BUILD_NUMBER=${PHASE_ID}${BUILD_NUM} $TARGET deb_dev
        exit_on_errors
        make TARG_BUILD_NUMBER=${PHASE_ID}${BUILD_NUM} $TARGET install_deb_dev
        exit_on_errors
        popd
        exit_on_errors_in_log
        run_unit_tests
    fi
}

function run_unit_tests()
{
    if [[ $NOVOS_TEST == TRUE ]] && [[ $TARGET == "BUILD=Debug" ]]
    then
	echo "Running NOVOS tests..."
	pushd_e $LIB_ROOT/sample/unittests
	make tests
	echo "Running Sample Unit test..."
	bindebug/novos-sample-unittest
	popd
	pushd_e $LIB_ROOT/novos_math/unittests
	make tests
	echo "Running Math Unit tests..."
	bindebug/novos-math-unittests
	popd
    fi
}

function main()
{
    echo "Make Options Used: $MAKE_OPTIONS"
    build_libs
}

main
