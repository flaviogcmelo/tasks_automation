#!/bin/bash
DATE='date +%Y%m%d'
tfactl managelogs -show usage -gi -database -node all |& tee \home\bd_srvs_comum\scripts_util\ahf\log\${DATE}_AHF_space_usage.log
tfactl managelogs -purge -older $1d -gi -database -node all |& tee \home\bd_srvs_comum\scripts_util\ahf\log\${DATE}_AHF_purge_logs.log