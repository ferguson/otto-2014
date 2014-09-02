#!/bin/bash

cd /usr/local/otto

. activate

while true; do
  coffee otto
  if [ $? -eq 0 ]; then
      break
  fi
  sleep 2
done
