SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
. /etc/profile
. /home/oracle/.bash_profile
. /etc/bashrc

for dummy in 1
do
export ORAENV_ASK=NO
export ORACLE_SID=$1
export PDB_NAME=$2
. /usr/local/bin/oraenv

date

sqlplus / as sysdba <<script
alter session set container=$2;

script
done
