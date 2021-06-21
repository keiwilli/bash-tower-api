#!/bin/bash

towerurl=
templateid=
username=
password=

jobrun=$(curl -k -s --user $username:$password -X POST https://$towerurl/api/v2/job_templates/$templateid/launch/)
if $( echo $jobrun | jq 'has("failed")' ); then
  jobfailed=$( jq -r '."failed"' <<< "${jobrun}" )
  if [ $jobfailed == "false" ]; then
    jobid=$( jq -r '."job"' <<< "${jobrun}" )
    echo "The Tower job number is: ${jobid}"
  else
    echo "An unknown error has occured, dumping JSON response:"
    echo $jobrun 
    exit 5
  fi
elif $( echo $jobrun | jq -e 'has("detail")' ); then
  echo "There was an error in launching the Tower job: $( jq -r '."detail"' <<< "${jobrun}" )"
  exit 4
else
  echo "An unspecified error has occured trying to launch the Tower job!"
  exit 3
fi

loopexit=false
while [ $loopexit != "true" ]
do
  jobprogress=$(curl -k -s --user $username:$password -X GET https://$towerurl/api/v2/jobs/$jobid/)
  jobstatus=$( jq -r '."status"' <<< "${jobprogress}" )
  if [ $jobstatus == "pending" ]; then
    echo "Tower is preparing"
    sleep 5
  elif [ $jobstatus == "running" ]; then
    echo "Tower is running"
    sleep 5
  elif [ $jobstatus == "successful" ]; then
    echo "The Tower job has finished successfully"
    loopexit=true
  elif [ $jobstatus == "failed" ]; then
    echo "The Tower job has failed. Check the logs for jobid: $jobid"
    exit 2
  else
    echo "I don't know how to interperate the Tower response, HALP!"
    exit 1
  fi
done
