SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
. /etc/profile
. /home/oracle/.bash_profile
. /etc/bashrc

for dummy in 1
do
export ORAENV_ASK=NO
export ORACLE_SID=$1
. /usr/local/bin/oraenv

date

rman target /  msglog /rman/log/$1/delete_archive_$1_`date +%Y%m%d`.log <<eof

run{
    crosscheck archivelog all;
    backup archivelog all delete input;
    crosscheck archivelog all;
    delete noprompt obsolete;
}
eof
done
