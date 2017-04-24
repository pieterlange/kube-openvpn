#!/bin/bash

statusfile=$1

while true; do
  sleep 60
  if [ ! -r $statusfile ]; then
    echo "Cannot read statusfile at $statusfile"
    break
  fi
  while read line; do
    IFS=',' read -r -a client <<< $line

    # Opportunistic filtering, only the client section has 5 fields
    if [ ! -z "${client[4]}" -a "${client[0]}" != "Common Name" ]; then
      echo -e "{ \"common_name\": \"${client[0]}\", \"bytes_received\": ${client[2]}, \"bytes_sent\": ${client[3]}, \"connected_since\": \"${client[4]}\" }"
    fi
  done < $statusfile
done
