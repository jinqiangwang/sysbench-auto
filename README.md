# sysbench-auto

This is a set of shell / python scripts used to benchmark various 
MySQL/MariaDB versions. Currently MySQL 5.7, MySQL 5.7 Percona
MySQL 8.0 and MariaDB 10.4 are supported.

Prerequisites 
1. CentOS 7. The sysbench binaries included in this scripts
   are build on CentOS 7, may not working properly on other
   systems.
2. Download MySQL tar package from their official sites. Please
   try to avoid using RPM package to install MySQL, it introduces
   unexpected complexity using this set of scripts.
    1) MySQL 5.7.26         - https://cdn.mysql.com/archives/mysql-5.7/mysql-5.7.26-linux-glibc2.12-x86_64.tar.gz
    2) MySQL 5.7.26 Percona - https://www.percona.com/downloads/Percona-XtraDB-Cluster-57/Percona-XtraDB-Cluster-5.7.26-31.37/binary/tarball/Percona-XtraDB-Cluster-5.7.26-rel29-31.37.1.Linux.x86_64.ssl100.tar.gz
    3) MySQL 8.0            - https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.21-linux-glibc2.12-x86_64.tar.xz
    4) MariaDB 10.4         - https://downloads.mariadb.org/interstitial/mariadb-10.4.13/bintar-linux-systemd-x86_64/mariadb-10.4.13-linux-systemd-x86_64.tar.gz/from/https%3A//mirrors.tuna.tsinghua.edu.cn/mariadb/
3. Extract MySQL/MariaDB from the tar ball and save to
    1) MySQL 5.7.26         - /opt/app/mysql-5.7.26
    2) MySQL 5.7.25 Percoan - /opt/app/mysql-5.7.26-percona
    3) MySQL 8.0            - /opt/app/mysql-8.0.21
    4) MariaDB 10.4         - /opt/app/mariadb-10.4.13
4. Package python-matplotlib is needed for presenting results as charts.
5. Do NOT run this script as root. Please create a user, enable sudo without
   password for this user, and run as this user.

How it works
These scripts include -
1. bin.tgz - sysbench binaries which will be unpacked on the fly. When running
   on CentOS 7 you don't need to install systench separately
2. compress.tgz - a set of text files (best, normal, worst) which represent
   the best / normal / worst compressibilities. When runnig for sysbench OLTP
   workloads, if you specifiy one of these files as data source, it will be
   read into memory and sysbench random data generationg will be switched to
   reading memory buffer of text file and fill the MySQL records.
3. mysql-cnf - template MySQL configurations, some of the value are parameterized
   for easy automation test. Check out for values like quoted by % like "%token%".
4. sb - test configurations. These files define parameter of the whole test,
   including aotmic write, MySQL parameters, sysbench parameters, etc.
5. shell scritps -
   1) 1_prep_dev.sh - preparing the device. it will clean data on drive and switch
      on / off atomic write according to configuration in sb/*.cfg files.
   2) 2_initdb.sh - initialized MySQL databases. for different version of MySQL the
      initialization commands vary.
   3) 3_run.sh - run actually OLTP workloads. 
   4) run-cases.sh - the wrapper script to run the whole test. it is the entry point
   parameters in sb/*.cfg file, and run-cases.sh can be overriden by export shell
   environment variables, for those which have default values, like below.
      export innodb_buffer_pool_size=${innodb_buffer_pool_size-48G}
 
By referencing test-case01.sh you should be able to build your own test set
in short time.
