#!/bin/bash

set -xvEe -o pipefail

HNAME=$1

sshpass -p "3tango" ssh root@$HNAME 'bash -s' < FixSlurmIssue.sh 

