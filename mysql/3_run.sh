#! /bin/bash

cfg_file=$1
if [ "${cfg_file}" = "" ]; then echo -e "Usage:\n\t3_run.sh cfg_file"; exit 1; fi
if [ ! -e ${cfg_file} ]; then echo "can't find configuration file [${cfg_file}]", exit 2; fi
source ${cfg_file}

# output_dir will be used in fio.sh, so make it global
if [ "${output_dir}" == "" ];
then
        export output_dir=${result_dir}/sb-`date +%Y%m%d_%H%M%S`${case_id}
fi

echo "test output will be saved in ${output_dir}"

if [ ! -e ${output_dir} ]; then mkdir -p ${output_dir}; fi

# collect MySQL startup options / configuration / test script
cp $0 ${output_dir}
cp ${cfg_file} ${output_dir}
cp ${mysql_cnf} ${output_dir};
ps aux | grep mysqld | grep -v grep > ${output_dir}/mysqld.cmdline

DU=du

if [ -e /opt/sfx/bin/sfx-du ]; then DU="sudo /opt/sfx/bin/sfx-du "; fi

source ../lib/common-lib
export MYSQL_PWD=${mysql_pwd}
collect_sys_info ${output_dir} ${css_status}

echo "will run workload(s) ${workload_set}"
for workload in ${workload_set};
    do
        echo "run workload ${workload} ${threads}"
	cmd="run"
        # workload friendly name. it will be used in fio.sh, so make it global
        export workload_fname=${workload}_${threads}
	if [ "prepare" == "${workload}" ]; then cmd="prepare"; workload="oltp_common"; workload_fname="prepare"; fi
        echo -e "sfx_message starts at: " `date +%Y-%m-%d\ %H:%M:%S` "\n"  > ${output_dir}/${workload_fname}.sfx_message
        sudo chmod 666 /var/log/sfx_messages;
	tail -f -n 0 /var/log/sfx_messages >> ${output_dir}/${workload_fname}.sfx_message &
        echo $! > ${output_dir}/tail.${workload_fname}.pid
        # try to keep existing result file
        if [ -e ${output_dir}/${workload_fname}.result ];
        then
                mv ${output_dir}/${workload_fname}.result ${output_dir}/${workload_fname}-`date +%Y%m%d_%H%M%S`.result
        fi
        echo "${workload_fname} starts at: " `date +%Y-%m-%d\ %H:%M:%S` > ${output_dir}/${workload_fname}.result

        if [[ "${cmd}" != "prepare" ]] && [[ ${collect_top} -eq 1 ]]; 
        then
                top -H -b -d ${rpt_interval} -n $((${run_time}/${rpt_interval})) > ${output_dir}/${workload_fname}.top &
        fi
        # clearn data in MySQL performance schema tables
        if [ "${collect_mysql_perf_schema}" == "1" ];
        then
                truncate_sys_tables
        fi

        if [[ "${cmd}" == "run" ]] && [[ ${collect_blktrace} -eq 1 ]];
        then
                # start_collect_mysql_lat_act ${output_dir} $((${run_time}+${warmup_time})) ${workload_fname} &
                start_blk_trace ${output_dir} ${workload_fname} ${disk} ${blktrace_time} &
        fi

        echo "iostat start at: " `date +%Y-%m-%d\ %H:%M:%S` > ${output_dir}/${workload_fname}.iostat
        iostat -txdmc ${rpt_interval} ${iostat_dev_str} >> ${output_dir}/${workload_fname}.iostat &
        echo $! > ${output_dir}/${workload_fname}.iostat.pid

        # run sysbench workload, all parameters are from sysbench.cfg
        pushd ${sysbench_dir}
        time ./sysbench \
                --db-driver=mysql \
                --mysql-socket=${mysql_socket} \
                --mysql-db=${db_name} \
                --mysql-user=${mysql_user} \
                --report-interval=${rpt_interval} \
                --time=${run_time} \
                --threads=${threads} \
                --percentile=${percentile} \
                ./${workload}.lua \
                --rand-type=${rand_type} \
                --histogram=on \
                --tables=${table_count} \
                --table-size=${table_size} \
                --create-table-options=${create_tbl_opt} \
                --table-data-src-file=${table_data_src_file} \
                --db-ps-mode=disable \
                ${cmd} \
                >> ${output_dir}/${workload_fname}.result
        rc=$?
        popd

        kill `cat ${output_dir}/${workload_fname}.iostat.pid`
        echo -e "\niostat ends at: " `date +%Y-%m-%d_%H:%M:%S` >> ${output_dir}/${workload_fname}.iostat
        echo ${output_dir}/${workload_fname}.iostat.pid
        rm -f ${output_dir}/${workload_fname}.iostat.pid
        
        if [ $rc -ne 0 ]; then echo "sysbench exited unexpectedly"; exit 1; fi

        if [ "${collect_mysql_perf_schema}" == "1" ];
        then
                stop_collect_mysql_lat_act ${output_dir}
        fi

        df -h ${disk} > ${output_dir}/${workload_fname}.dbsize
        cat /sys/block/${dev_name}/sfx_smart_features/sfx_capacity_stat >> ${output_dir}/${workload_fname}.dbsize
        ${DU} -B1k ${mysql_datadir} >> ${output_dir}/${workload_fname}.dbsize

        # collect redo log perf counter data
        if [ "${collect_mysql_perf_schema}" == "1" ];
        then
                collect_perf_counter_redolog  ${output_dir}/${workload_fname}_redolog.counter
        fi

        echo -e "\nsfx_messages ends at: `date +%Y-%m-%d_%H:%M:%S`\n"  >> ${output_dir}/${workload_fname}.sfx_message
        echo ${output_dir}/tail.${workload_fname}.pid
        kill `cat ${output_dir}/tail.${workload_fname}.pid`
        rm -f ${output_dir}/tail.${workload_fname}.pid
        echo -e "\n${workload_fname}" "\nends at: " "`date +%Y-%m-%d_%H:%M:%S`" >> ${output_dir}/${workload_fname}.result
        sudo pkill top
        sudo pkill blktrace
        sleep 5
    done

generate_csv ${output_dir}
