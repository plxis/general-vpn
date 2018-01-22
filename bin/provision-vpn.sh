#!/bin/bash

projectDir=`cd $(dirname $0)/..;pwd`

awsProfile=lab
foundryContext=foundry-lab 

if [[ $# -ne 1 ]]; then
  echo "usage: `basename $0` <environment.json>"
  echo "Check the doc dir or samples,"
  exit 1
fi

function setup_environment {
  generatedEnvironmentFile=/tmp/`basename $environmentFile`.$$.json

  cp -f $environmentFile $generatedEnvironmentFile
  environmentFile=$generatedEnvironmentFile
}

function get_password {
  echo "This VPN setup needs the password to connect to the partner VPN"
  echo "It is likley that we have this stored in lastpass. Check with Infra."
  echo -n "Enter vpn_dest_secret allocated by partner: "
  read -s password
  echo
}

function update_password {
  cat $environmentFile | sed -e "s/%PASSWORD%/$password/" > $environmentFile.2
  mv $environmentFile.2 $environmentFile
}

function get_context {
  context=`cat $environmentFile | grep '"name":' | awk '{ print $2 }' | cut -d'"' -f2`
}

environmentFile=$1

setup_environment
get_password
update_password
get_context

echo toxic -doDir=$projectDir/test/toxic -preserveResources=true -foundryContext=${foundryContext} -context=${context} -awsProfile=${awsProfile} -environmentFile=${environmentFile} -localProjectDir=$projectDir

