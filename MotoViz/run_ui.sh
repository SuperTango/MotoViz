#!/bin/bash -x
PORT=5000
if [[ ${HOSTNAME} == "vm3.funkware.com" ]] ; then
    if [[ ${PWD} == "/funk/home/altitude/MotoViz-staging/MotoViz" ]] ; then
        DANCER_ENV='development-vm3_staging'
        PORT=5002
    else
        DANCER_ENV='development-vm3'
    fi
else
    DANCER_ENV='development-localhost'
fi
plackup -E ${DANCER_ENV} -p ${PORT} -a bin/app.pl -s Starman --error-log `pwd`/logs/error_log --access-log `pwd`/logs/access_log

