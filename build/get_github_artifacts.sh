#!/bin/bash

# Use this script to download and unzip github artifacts by run id and user entered
# artifact list.

EXPECTED_ARGS=4
E_BADARGS=65

if [ $# -lt $EXPECTED_ARGS ]
then
    clear
    echo "Usage: $0 {run_id} {password_token} {repo_name} '{artifact_list}'"
    echo "Where:         {run_id} = ########"
    echo "       {password_token} = Users Github password or token"
    echo "            {repo_name} = Repository name"
    echo "        {artifact_list} = A file containing and artifact list or"
    echo "                          a space separated list of quoated artifacts"
    echo
    echo "Examples:"
    echo
    echo "$0 832176399 b133llcd44faf86966567f3gb3c23733943a3456 steves-test-repo lib_artifact.lst"
    echo "$0 832176399 b133llcd44faf86966567f3gb3c23733943a3456 steves-test-repo 'version-num- version-'"
    exit $E_BADARGS
fi

run_id=${1}
password_token=${2}
repo_name=${3}
artifact_list=${4}
build_dir=`dirname $0`

# Check to see if a artifact file has been entered by the user.
# If not, use the user entered artifact list.
artifact_file=`echo ${artifact_list} | cut -d" " -f1`
if [ -f "${build_dir}/${artifact_file}" ]; then
    artifact_list=`cat ${build_dir}/${artifact_file}`
fi

# Use the run id and curl to get a list of artifacts that can be downloaded from github.
rm -f run_id_artifact.lst
curl -H "Authorization: token ${password_token}" -sL \
https://api.github.com/repos/SKuhlmanns/${repo_name}/actions/runs/${run_id}/artifacts \
-o artifacts.txt
#cat artifacts.txt

# Strip out the name and id from the curl output; generate a run id artifact list file.
cat artifacts.txt | grep '"name":' | cut -d'"' -f4 > name.txt
cat artifacts.txt | grep '"id":' | cut -d':' -f2 | cut -d"," -f1 > id.txt
paste -d "" name.txt id.txt > run_id_artifact.lst
rm id.txt name.txt artifacts.txt
cat run_id_artifact.lst

# Compare the user enter artifact list against the generated run id artifact list.
# Download zipped artifacts by artifact id that are in both lists, where *"${artifact_name}"*
# is contained in run id artifacts list 
for artifact_name in ${artifact_list}
do
    while IFS= read -r line; do
        filename=`echo $line | cut -d" " -f1`
        artifact_id=`echo $line | cut -d" " -f2`
        # Download the artifact if it does not already exist
        if [ ! -f ${filename}.zip ]; then
            if [[ "${filename}" == *"${artifact_name}"* ]]; then
                curl -H "Authorization: token ${password_token}" -sLJO \
https://api.github.com/repos/SKuhlmanns/${repo_name}/actions/artifacts/${artifact_id}/zip
            fi
        fi
    done < run_id_artifact.lst
done

# Unzip and delete the downloaded zip files.
while IFS= read -r line; do
    filename=`echo $line | cut -d" " -f1`
    if [ -f ${filename}.zip ]; then
        unzip -u ${filename}.zip
        rm ${filename}.zip
    fi
done < run_id_artifact.lst

# Delete the generated run id artifacts list file.
rm -f run_id_artifact.lst
