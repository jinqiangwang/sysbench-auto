#!/bin/bash

# pass any string to sysbench-test.sh to run formal test
# for example: ./sysbench-test.sh formal
# without opt it will run a quick test
formal_test=$1

export dev_name=${dev_name-nvme10n1}
export capacity_gb=${capacity_gb-3840}
export prep_dev=${prep_dev-yes}         # yes|no
export init_db=${init_db-yes}           # yes|no
export atomic_write=${atomic_write-0}   # 0|1
export WORKLOADS=${WORKLOADS-sb/mysql-8.0}
if [[ "${formal_test}" == "" ]] 
then
    ############################################################
    ## test configuraion for quick verification
    export workload_set="prepare oltp_read_write"
    export warmup_time=5
    export run_time=30      # in seconds
    export thread_count_list="1"
    export table_count=32
    export table_size=200000
else
    ## 300 table x 10 million records for ~550G data set
    export workload_set="prepare oltp_read_only oltp_insert oltp_update_index oltp_update_non_index oltp_read_write oltp_write_only"
    export run_time=1200
    export thread_count_list="1 4 16 32 64 128"
    export table_count=300
    export table_size=20000000
    ############################################################
fi
export innodb_buffer_pool_size=${innodb_buffer_pool_size-64G}
## set iostat_dev_str to collect iostat data for all devices
## interested, like below -
## export iostat_dev_str="md0 nvme0n1 nvme1n1 nvme2n1 nvme3n1"
export iostat_dev_str=${iostat_dev_str-${dev_name}}
## set dev_pattern like below to let the script generate 
## iostat csv files for all devices. refult file content 
## will be 
## thrd,tps,qps,%lat,,ts,avg-cpu,%user,%sys,%iowait,%idle,Device:,...
# export dev_pattern="md0 nvme0n1 nvme1n1 nvme2n1 nvme3n1"
export dev_pattern=${dev_pattern-${iostat_dev_str}}
export run_cmd_script=./run-cases.sh

export collect_blktrace=0
export blktrace_time=30
export WORKSPACE=./

pushd ../
if [ ! -d bin ]; then tar xzf bin.tgz; fi
if [ ! -d compress ]; then tar xzf compress.tgz; fi
popd

export cfg_list=${WORKLOADS}
export chart_title="${WORKLOADS#*/}-awoff"
if [ ${atomic_write} -eq 1 ]; then chart_title="${WORKLOADS#*/}-awoff"; fi
${run_cmd_script}
