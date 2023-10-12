#!/bin/bash

function show_case_detail() {
    echo "case config           =${cfg}"
    echo "mysql_cnf             =${mysql_cnf}"
    echo "create_tbl_opt        =${create_tbl_opt}"
    echo "table_data_src_file   =${table_data_src_file}"
    echo "case_id               =${case_id}"
    echo "output_dir            =${output_dir}"
    echo -e "\n"
}

# cfg_list=${cfg_list-"sb/csd-300g-awoff sb/csd-300g-awon sb/csd-2t-awoff sb/csd-2t-awon"}
cfg_list=${cfg_list-"tpcc/csd-500-awoff tpcc/csd-500-awon tpcc/csd-2000-awoff tpcc/csd-2000-awon"}

if [[ "${WORKSPACE}" != "" ]] && [[ -d ${WORKSPACE} ]];
then
        if [ ! -d ${WORKSPACE}/test_output ]; then mkdir -p ${WORKSPACE}/test_output; fi
fi

fail_count=0

for cfg in ${cfg_list}
do
    run_script=./3_run.sh
    type=$(echo ${cfg} | cut -d/ -f1)

    if [ "${type}" == "tpcc" ];
    then
        run_script=./3_run_tpcc.sh
    fi

    cfg=${cfg}.cfg
    echo ${run_script} ${cfg}
    
    source ${cfg}; 
    if [ $? -ne 0 ]; 
    then 
        echo "source [${cfg}] failed, try next cfg"
        fail_count=$((${fail_count}+1))
        continue
    fi
    timestamp=`date +%Y%m%d_%H%M%S`
    export output_dir=${result_dir}sb-${timestamp}${case_id}
    show_case_detail
    
    if [ ! -e ${output_dir} ]; then mkdir -p ${output_dir}; fi
    touch ${output_dir}/time_${timestamp}
    mkdir ${output_dir}/scripts
    cp -r `ls | grep -v test_output` ${output_dir}/scripts

    if [ "${prep_dev}" == "yes" ];
    then 
        ./1_prep_dev.sh  ${cfg}
    fi

    if [ "${init_db}" == "yes" ];
    then
        ./2_initdb.sh   ${cfg}
    else
        ./stop.sh
        export MYSQL_PWD=${mysql_pwd}
        disk_mnt="`lsblk -o mountpoint ${disk} | tail -n1`"
        if [[ "${disk_mnt}" != "${mnt_point_data}" ]]
        then
            sudo mount ${mnt_opt} ${disk} ${mnt_point_data}
        fi
        ./start.sh ${cfg}
    fi

    if [ "${workload_set%% *}" == "prepare" ];
    then
        workload_set_bk=${workload_set}
        export workload_set="prepare"
        threads=$((`grep processor  /proc/cpuinfo | wc -l`*2))
        ${run_script} $cfg
        export workload_set=${workload_set_bk#* }
    fi

    if [ "${thread_count_list}" != "" ]
    then        
        for thread_count in ${thread_count_list[@]}
        do
            export threads=${thread_count}
            ${run_script} $cfg
            if [ $? -ne 0 ]; 
            then 
                echo "[${run_script} $cfg] failed, increase fail_count and continue"
                fail_count=$((${fail_count}+1))
            fi
        done
    else
        ${run_script} $cfg
        if [ $? -ne 0 ]; 
        then 
            echo "[${run_script} $cfg] failed, increase fail_count and continue"
            fail_count=$((${fail_count}+1))
        fi
    fi

    timestamp=`date +%Y%m%d_%H%M%S`
    touch ${output_dir}/time_${timestamp}

    if [[ "${WORKSPACE}" != "" ]] && [[ -d ${WORKSPACE} ]];
    then
        dir_name=`echo ${cfg} | sed -r -e "s#/#_#g" -e "s/.cfg//g"`
        dir_name=${dir_name}_${timestamp}
        pushd ${output_dir}/csv
        export CSV_FILE_LIST=`ls -tr *.csv`
        popd
        export chart_title=${chart_title-"${cfg} - ${sw_ver}"}
        echo "chart title is ${chart_title}"
        
        # -p: p99,p999,p9999 lat are calcualted from
        # sysbench latency histogram
        python3 ../lib/csv2chart.py \
            -d ${output_dir}/csv \
            -l 1 \
            -r 2,3 \
            -o ${output_dir}/result.png \
            -s ${output_dir}/summary.csv \
            -t "${chart_title}" \
            -p 99,99.9,99.99

        mkdir -p ${WORKSPACE}/test_output/${dir_name}
        echo "collecting test output from [${output_dir}] to [${WORKSPACE}/test_output/${dir_name}]"
        cp -ra `ls -d ${output_dir}/* | grep -v -e btrace -e d2c -e fp.dat -e scripts -e message -e redo -e iostat`\
               ${WORKSPACE}/test_output/${dir_name}
        cp -a ${output_dir}/*.png  ${WORKSPACE}/test_output/${dir_name}
        tar czf ${WORKSPACE}/test_output/${dir_name}/scripts.tgz ${output_dir}/scripts
    fi
done

echo "[${fail_count}] case failed"
