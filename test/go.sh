#! /bin/bash

ERL=erl
COOKIE=ccc2

ERL_LIBS=../:../deps:../lib:../test:$ERL_LIBS
export ERL_LIBS

## Increase max processes
##    (IsWebsockets ? MaxSubscribers*2 : MaxSubscribers*1) + MaxTopics + FixedProcesses
##    (true         ? 500000*2         : 500000*1)         + 50000     + 50000   = 1600000
# Limit ERL_MAX_PROCESSES=134217727
ERL_MAX_PROCESSES=1100000

## TODO - need to check if it's really affects number of open sockets
## Increase number of concurrent ports/sockets
##    MaxSubscribers + FixedPorts
##    500000         + 50000
# Limit ERL_MAX_PORTS=268435456
ERL_MAX_PORTS=550000
export ERL_MAX_PORTS

## Increase number of ETS tables
##    MaxTopics + FixedETS
##    50000     + 2000
ERL_MAX_ETS_TABLES=52000
export ERL_MAX_ETS_TABLES

## Tweak GC to run more often
ERL_FULLSWEEP_AFTER=10
export ERL_FULLSWEEP_AFTER


ERL_ASYNC_THREADS=64
ERL_KERNEL_POLL=true


APPS='[application:start(A)||A<-[cowboy]]'

CMD="$ERL $NOSHELLOPT $NAMEOPT +K $ERL_KERNEL_POLL +A $ERL_ASYNC_THREADS +P $ERL_MAX_PROCESSES -setcookie $COOKIE -eval $APPS"
echo $CMD
$CMD

