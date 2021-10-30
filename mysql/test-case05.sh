#!/bin/bash

# pass any string to test-case05.sh to run formal test
# for example: ./test-case05.sh formal
# without opt it will run a quick test
formal_test=$1

export dev_name=sfdv0n1
export capacity_gb=3200
export prep_dev=yes     # yes|no
export init_db=yes      # yes|no
export atomic_write=0   # 0|1
export WORKLOADS=sb/mysql-5.7
if [[ "${formal_test}" == "" ]] 
then
    ############################################################
    ## test configuraion for quick verification
    export workload_set="prepare oltp_read_only oltp_read_write"
    export warmup_time=5
    export run_time=30      # in seconds
    export thread_count_list="4 16 128"
    export table_count=32
    export table_size=200000
else
    ## 300 table x 10 million records for ~550G data set
    export workload_set="prepare oltp_read_only oltp_insert oltp_update_index oltp_update_non_index oltp_read_write oltp_write_only"
    export run_time=1200
    export thread_count_list="4 32 64 128 256"
    export table_count=300
    export table_size=10000000
    ############################################################
fi
export innodb_buffer_pool_size=32G
## set iostat_dev_str to collect iostat data for all devices
## interested, like below -
## export iostat_dev_str="md0 sfdv0n1 sfdv1n1 sfdv2n1 sfdv3n1"
export iostat_dev_str=${dev_name}
## set dev_pattern like below to let the script generate 
## iostat csv files for all devices. refult file content 
## will be 
## thrd,tps,qps,%lat,,ts,avg-cpu,%user,%sys,%iowait,%idle,Device:,...
# export dev_pattern="md0 sfdv0n1 sfdv1n1 sfd2n1 sfdv3n1"
export dev_pattern=${iostat_dev_str}
export table_data_src_file=""   # empty|../compress/best.txt 
export run_cmd_script=./run-cases.sh

export collect_blktrace=1
export blktrace_time=30
export WORKSPACE=./

pushd ../
if [ ! -d bin ]; then tar xzf bin.tgz; fi
if [ ! -d compress ]; then tar xzf compress.tgz; fi
popd

export cfg_list=${WORKLOADS}
export chart_title="mysql-5.7-awoff"
${run_cmd_script}
