#!/bin/bash

usage="Usage:\n\t1_prep_dev cfg_file\n\tExample: ./1_prep_dev.sh sysbench.cfg"
if [ "$1" == "" ]; then echo -e ${usage}; exit 1; fi
if [ ! -e $1 ]; then echo "can't find configuration file [$1]", exit 2; fi

# read in configurations
source $1

lsblk ${disk}
if [ "$?" -ne 0 ]; then echo "cannot find disk [${disk}]"; exit 3; fi

# stop mysql service first, since it my occupy the disk
./stop.sh

# prepare the mount point and other folders
if [ ! -e ${mnt_point_data} ]; then sudo mkdir -p ${mnt_point_data}; fi

sudo umount ${disk}

echo ${disk} | grep sfd

if [ $? -eq 0 ];
then
    sw_rel=`sudo sfx-status | grep -i "software"`
    sw_rel=$(echo ${sw_rel#*:} | cut -c1-3)
    cur_cap=$(sudo ${css_status} ${disk} | grep -i "formatted capacity" | sed -r "s/\s+/,/g" | cut -d, -f3)
    echo ${cur_cap} " --> " ${capacity_gb}
    if [ "${cur_cap}" != "${capacity_gb}" ];
    then
        echo "adjusting logical capacity ..."
        # for driver 
        if [ "${sw_rel}" == "3.1" ];
        then
            echo y | sudo sfx-nvme sfx format ${disk} --capacity=${capacity_gb}
        fi
        if [ "${sw_rel}" == "3.2" ];
        then
            echo y | sudo sfx-nvme sfx change-cap ${disk} -c ${capacity_gb}
        fi
        echo "adjusting logical capacity ... done"
    fi

    echo "adjusting atomic write settings ..."
    if [ "${sw_rel}" == "3.1" ];
    then
        echo y | sudo sfx-nvme format ${disk} -a ${atomic_write} -l ${atomic_write} -s 1
    fi
    if [ "${sw_rel}" == "3.2" ];
    then
        echo y | sudo sfx-nvme format ${disk} -l ${atomic_write}
        echo y | sudo sfx-nvme sfx set-feature ${disk} -f 1 -v ${atomic_write}
    fi
    echo "adjusting atomic write settings ... done"
fi

if [ ${pre_cond} -eq 1 ];
then
    sudo fio --filename=${disk} ${pre_cond_cfg}
fi

sudo mkfs ${mkfs_opt} ${disk}
sudo mount ${mnt_opt} ${disk} ${mnt_point_data}
 