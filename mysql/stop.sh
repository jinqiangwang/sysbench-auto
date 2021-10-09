#!/bin/bash

function stop_mysqld_instances() {
    for inst in `ps aux | grep mysqld | grep -v grep | sed -r "s/\s+/,/g" | cut -d, -f 2`;
    do 
        kill -9 ${inst};
    done
    sleep_sec=6
    for i in {1..100};
    do
        sleep ${sleep_sec}
        if [ "" ==  "`ps aux | grep mysqld | grep -v grep`" ];
        then 
            echo "stopped"; break;
        else 
            echo "stopping mysqld - waited $((${i}*${sleep_sec})) second(s)"; 
        fi
    done
}

stop_mysqld_instances
