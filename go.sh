#!/bin/bash

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd $ROOT
. activate

while true; do
  coffee otto
  if [ $? -eq 0 ]; then
      break
  fi
  sleep 2
done
