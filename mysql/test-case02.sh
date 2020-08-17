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
export run_time=30
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
export iostat_dev_str=${dev_name}
export table_data_src_file=""   # empty|../compress/best.txt 
export run_cmd_script=./run-cases.sh

export WORKSPACE=./

pushd ../

tar xzf bin.tgz
tar xzf compress.tgz

popd

export cfg_list=${WORKLOADS}
${run_cmd_script}
