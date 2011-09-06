#!/bin/bash -x
if [[ ${HOSTNAME} == "vm3.funkware.com" ]] ; then
    DANCER_ENV='development-vm3'
else
    DANCER_ENV='development-localhost'
fi
plackup -E ${DANCER_ENV} -p 5001 -a bin/app.pl -s Starman --error-log `pwd`/logs/error_log --access-log `pwd`/logs/access_log

