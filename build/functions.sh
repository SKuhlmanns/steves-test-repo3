#! /bin/bash

# ATTENTION: DEVELOPERS ARE NOT ALLOWED TO CHANGE THIS SCRIPT
#            CONTACT THE BUILD ENGINEER IF YOU NEED CHANGES

#--------------------------
# Exit on build log Errors
#--------------------------
function exit_on_errors_in_log()
{
    pushd_e $ROOT_DIR
    if [ -f .out ]
    then
        declare -a error_list=("Error 2$" "Error 1$")
        for error in "${error_list[@]}"
        do
            if [ `grep -c "$error" .out` -gt 0 ]
            then
                touch error_detected
                popd
                echo "Exiting build process with errors."
                exit 1
            fi
        done
    fi
    popd
}

#--------------------------
# Exit build on Error
#--------------------------
function exit_on_errors()
{
    RC=$?
    msg=$1
    filename=$2
    if [ "$filename" != "" ]; then
       cat $filename
    fi
    if [ $RC == 1 ]; then
        if [ "$msg" != "" ]; then
           echo $msg
        fi
        echo "Exiting build process with errors."
        echo "Error 1"
        exit 1
    fi
}

#--------------------------
# Exit popd on Error
#--------------------------
function pushd_e()
{
    pushd $1
    exit_on_errors
}

#----------------------------
# Set the QMAKE PATH
#----------------------------
function set_qmake_path()
{
    OSTYPE=`uname -msr`
    echo $OSTYPE
    # ATTENTION: DEVELOPERS ARE NOT ALLOWED TO CHANGE THIS SCRIPT
    #            CONTACT THE BUILD ENGINEER IF YOU NEED CHANGES
    if [[ $OSTYPE == *MING* ]]; then
        PATH="/c/Qt/Qt5.12.0/5.12.0/msvc2017/bin:${PATH}:/c/Program Files/Git/bin"
    elif [[ $OSTYPE == *i686* ]]; then
        PATH="/opt/Qt5.12.0/5.12.0/gcc/bin:$PATH"
    elif [[ $OSTYPE == *amd64* ]]; then
        PATH="/opt/Qt5.12.0/5.12.0/gcc_64/bin:$PATH"
    else
        echo "ERROR: OS Unknown"
        exit 1
    fi
    echo $PATH
    gcc --version
}

#----------------------------
# Check build logs for errors
#----------------------------
function check_for_log_errors()
{
   exit_status=0
   #grep -c "Error 1$" .out
   if [ `grep -c "Error 1$" .out` -gt 0 ]
   then
       echo '*************** ERROR(S) CODE 1 ********************'
       grep -A 2 -B 15 -n "Error 1$" .out
       echo '*************** ERROR(S) ***************************'
       exit_status=1
   fi
   #grep -c "Error 2$" .out
   if [ `grep -c "Error 2$" .out` -gt 0 ]
   then
       echo '*************** ERROR(S) CODE 2 ********************'
       grep -A 2 -B 15 -n "Error 2$" .out
       echo '*************** ERROR(S) ***************************'
       exit_status=1
   fi
   exit $exit_status
}

#------------------------------------------------
# Set Build Mode Release Flag for Build Archiving
#------------------------------------------------
function set_release_flag()
{
    rm -f ../package/release.flag
    if [[ $1 == "BUILD=RELEASE" ]]; then
        #echo "setting release flag"
        if [[ $OSTYPE != *MINGW* ]]; then
            TARGET="BUILD=Release"
        else
            TARGET="Release"
        fi
        TGT=lib
        touch ../package/release.flag
    else
        if [[ $1 == "BUILD=DEBUG" ]]; then
            if [[ $OSTYPE != *MINGW* ]]; then
                TARGET="BUILD=Debug"
            else
                TARGET="Debug"
            fi
        fi
    fi
}

#------------------------------------------------
# Set Debian version
#------------------------------------------------
function set_deb_ver()
{
    version_file="version.txt"
    if [ -f version_num.txt ]; then
        version_file="version_num.txt"
    fi
    MAJ=`cat ${version_file} |cut -d"." -f1`
    MIN=`cat ${version_file} |cut -d"." -f2`
    BLD=`cat ${version_file} |cut -d"." -f3`
    PHASE_ID=`cat ${version_file} | cut -d"." -f3 | rev | cut -c 1 |grep [a-z]`
    if (test ${BUILD_NUMBER} != "") then
        BUILD_NUM="-${BUILD_NUMBER}"
    fi
}
