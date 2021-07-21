#!/bin/bash

towerurl=
templateid=
username=
password=

jobrun=$(curl -k -s --user $username:$password -X POST https://$towerurl/api/v2/workflow_job_templates/$templateid/launch/)
if $( echo $jobrun | jq 'has("failed")' ); then
  jobfailed=$( jq -r '."failed"' <<< "${jobrun}" )
  if [ $jobfailed == "false" ]; then
    jobid=$( jq -r '."workflow_job"' <<< "${jobrun}" )
    echo "The Tower workflow job number is: ${jobid}"
  else
    echo "An unknown error has occured, dumping JSON response:"
    echo $jobrun 
    exit 6
  fi
elif $( echo $jobrun | jq -e 'has("detail")' ); then
  echo "There was an error in launching the Tower workflow job: $( jq -r '."detail"' <<< "${jobrun}" )"
  exit 5
else
  echo "An unspecified error has occured trying to launch the Tower workflow job! Dumping JSON response:"
  echo $jobrun
  exit 4
fi

loopexit=false
errorcaught=false
while [ $loopexit != "true" ]
do
  jobprogress=$(curl -k -s --user $username:$password -X GET https://$towerurl/api/v2/workflow_jobs/$jobid/)
  jobstatus=$( jq -r '."status"' <<< "${jobprogress}" )
  jobworkflownodes=$( jq -r '.related["workflow_nodes"]' <<< "${jobprogress}" )
  if [ $jobstatus == "pending" ]; then
    echo "Tower is preparing"
    sleep 5
  elif [ $jobstatus == "running" ]; then
    echo "Tower is running"
    if [ $errorcaught != "true" ]; then
      echo "Checking workflow components"
      jobnodes=$(curl -k -s --user $username:$password -X GET https://$towerurl$jobworkflownodes)
      for node in $( jq -r '.results | keys | .[]' <<< "${jobnodes}" )
      do
        result=$( jq -r .results[$node] <<< "${jobnodes}" )
        resultid=$( jq -r '.summary_fields.job.id' <<< "${result}" )
        resultstatus=$( jq -r '.summary_fields.job.status' <<< "${result}" )
        if [ $resultstatus == "failed" ]; then
          errorcaught=true
	  errorjobid=$resultid
	  echo "An error in a workflow step has been caught! Check the Tower workflow!"
          break
        fi
      done
    fi
    sleep 5
  elif [ $jobstatus == "successful" ]; then
    if [ $errorcaught == "true" ]; then
	    echo "The Tower workflow (workflow job id: $jobid) has encountered an error in a node! Check the logs for node job id: $errorjobid"
      exit 3
    fi
    echo "The Tower workflow job has finished successfully"
    loopexit=true
  elif [ $jobstatus == "failed" ]; then
    echo "The Tower workflow job has failed. Check the logs for jobid: $jobid"
    exit 2
  else
    echo "I don't know how to interperate the Tower response, HALP! Dumping JSON response:"
    echo $jobprogress
    exit 1
  fi
done

