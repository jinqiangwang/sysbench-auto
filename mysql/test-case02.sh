#!/bin/bash

export dev_name=sfdv0n1
export capacity_gb=6400
export prep_dev=yes     # yes|no
export init_db=yes      # yes|no
export atomic_write=0   # 0|1
export WORKLOADS=sb/mysql-8.0
############################################################
## test configuraion for quick verification
export workload_set="prepare oltp_read_only oltp_insert"
export run_time=30      # in seconds
export thread_count_list="1 4"
export table_count=60
export table_size=150000
## 600 table x 15 million records for 2T data set
# export workload_set="prepare oltp_read_only oltp_insert oltp_update_index oltp_update_non_index oltp_read_write oltp_write_only"
# export run_time=1200
# export thread_count_list="1 4 16 64 256 512 1024 2048"
# export table_count=600
# export table_size=15000000
############################################################
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

export WORKSPACE=./

pushd ../
if [ ! -d bin ]; then tar xzf bin.tgz; fi
if [ ! -d compress ]; then tar xzf compress.tgz; fi
popd

export cfg_list=${WORKLOADS}
export chart_title="mysql-8.0-awoff"
${run_cmd_script}
