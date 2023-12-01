/*
   Labs Oracle OCP 19
   Recover Truncated table with Flashback Database
   Ref.: https://netsoftmate.com/recover-truncated-table-using-flashback-database/
        http://dbaharrison.blogspot.com/2014/09/datapump-export-from-standbyread-only.html
 
   Pré-Requisitos
    - Database must in using Fast Recovery Area
    - Database must have flashback set to ON
*/

-- Passo  1: Conectado ao banco verificar definir o padrão de exibição de data e hora
alter session set nls_date_format='dd/mm/yy hh24:mi:ss';

-- Verificar se o flashback e o modo archive estão habilitados
set lines 200
SQL> select log_mode, flashback_on from v$database;

LOG_MODE     FLASHBACK_ON
------------ ------------------
ARCHIVELOG   YES

SQL> alter session set container=pdbdenver;

Session altered.

col host_name for a30
SQL> select instance_number, instance_name, host_name, startup_time, status, con_id from v$instance;

INSTANCE_NUMBER INSTANCE_NAME    HOST_NAME                      STARTUP_TIME      STATUS           CON_ID
--------------- ---------------- ------------------------------ ----------------- ------------ ----------
              1 denver           denver.localdomain             21/09/23 19:13:50 OPEN                  0

SQL> select sysdate from dual;

SYSDATE
-----------------
21/09/23 19:54:37

-- Passo 2: Criar a tabela que será o alvo do laboratório

SQL> col username for a30
SQL> select username, account_status, authentication_type from dba_users where oracle_maintained = 'N';

USERNAME                       ACCOUNT_STATUS                   AUTHENTI
------------------------------ -------------------------------- --------
PDB_ADMIN                      OPEN                             PASSWORD
AD_FLAVIO                      OPEN                             PASSWORD
HR                             OPEN                             NONE
CO                             OPEN                             NONE
CENSOSUP_2022                  LOCKED                           NONE

SQL> select sysdate from dual;

SYSDATE
-----------------
21/09/23 19:56:03

SQL> create table hr.bkp_employees as select * from hr.employees;

Table created.

SQL> select count(1) from hr.employees;

  COUNT(1)
----------
      3424

SQL> select count(1) from hr.bkp_employees;

  COUNT(1)
----------
      3424

SQL> select sysdate from dual;

SYSDATE
-----------------
21/09/23 19:56:47

SQL> truncate table hr.bkp_employees;

Table truncated.

SQL> select count(1) from hr.bkp_employees;

  COUNT(1)
----------
         0

SQL> select sysdate from dual;

SYSDATE
-----------------
21/09/23 19:57:40


-- Passo 4: Parar o banco e subir em estado mount

SQL> alter session set container=cdb$root;

Session altered.

SQL> shutdown immediate
Database closed.
Database dismounted.
ORACLE instance shut down.

SQL> startup mount
ORACLE instance started.

Total System Global Area 3221224152 bytes
Fixed Size                  9140952 bytes
Variable Size             654311424 bytes
Database Buffers         2550136832 bytes
Redo Buffers                7634944 bytes
Database mounted.
SQL> show pdbs

    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       MOUNTED
         3 PDBDENVER                      MOUNTED
         4 PDB2                           MOUNTED

--Passo 5: Executar o flashback database com o CDB e os PDBs em estado MOUNT

SQL> alter session set nls_date_format='dd/mm/yy hh24:mi:ss';

SQL> flashback database to timestamp to_date('21/09/23 19:56:47','dd/mm/yy hh24:mi:ss');
Flashback complete.

-- Passo 6: Abrir o CDB e o PDB em modo read only
SQL> alter database open read only;

Database altered.

SQL> set line 200
SQL> select name, open_mode, database_role from v$database;

NAME      OPEN_MODE            DATABASE_ROLE
--------- -------------------- ----------------
DENVER    READ ONLY            PRIMARY

SQL> alter pluggable database pdbdenver open read only;

Pluggable database altered.

SQL> show pdbs

    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDBDENVER                      READ ONLY  NO
         4 PDB2                           MOUNTED

SQL> alter session set container=pdbdenver;

Session altered.

-- Passo 7: Verificar se os registros truncados foram recuperados e realizar o export da tabela
SQL> select sysdate from dual;

SYSDATE
-----------------
21/09/23 20:03:46

SQL> select count(1) from hr.bkp_employees;

  COUNT(1)
----------
      3424

SQL> exit
Disconnected from Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.17.0.0.0
[oracle@denver ~]$ expdp sys@pdbdenver file=bkp_employees.dmp log=bkp_employee.log tables=hr.bkp_employees compress=y;

Export: Release 19.0.0.0.0 - Production on Thu Sep 21 19:06:51 2023
Version 19.17.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.
Password:

UDE-28009: operation generated ORACLE error 28009
ORA-28009: connection as SYS should be as SYSDBA or SYSOPER

Username: sys / as sysdba
Password:

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
ORA-31626: job does not exist
ORA-31633: unable to create master table "SYS.SYS_EXPORT_TABLE_05"
ORA-06512: at "SYS.DBMS_SYS_ERROR", line 95
ORA-06512: at "SYS.KUPV$FT", line 1163
ORA-16000: database or pluggable database open for read-only access
ORA-06512: at "SYS.KUPV$FT", line 1056
ORA-06512: at "SYS.KUPV$FT", line 1044

-- **************************************************************
--  Como o banco está em modo read only o expdp gera o erro acima devido a necessídade de criar a master table no processo de export
--  Para contornar esse erro existem duas possibilidades:
--  7.1. Usar o exp ao invés do expdp  (mais prática, mas pode gerar conversão de carcteres)
--  7.2. Usar um segundo banco de dados para, via dblink, criar a tabela master e realizar o export
--   How To Use DataPump Export (EXPDP) To Export From Physical Standby Database (Doc ID 1356592.1)

-- 7.1. Export usando o exp
[oracle@denver ~]$ exp system@pdbdenver file=bkp_employees.dmp log=bkp_employee.log tables=hr.bkp_employees compress=y;

Export: Release 19.0.0.0.0 - Production on Thu Sep 21 19:08:09 2023
Version 19.17.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

Password:

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Version 19.17.0.0.0
Export done in US7ASCII character set and AL16UTF16 NCHAR character set
server uses AL32UTF8 character set (possible charset conversion)

About to export specified tables via Conventional Path ...
Current user changed to HR
. . exporting table                  BKP_EMPLOYEES       3424 rows exported
EXP-00091: Exporting questionable statistics.
Export terminated successfully with warnings.

-- 7.2. Export criando a master table em outro banco via database link
-- Conectar na instância ORCL no mesmo host e acessar o pdb1
-- Criar o database link apontando para a entrada TNS do banco e modo de restauração

SQL> create public database link remote_pump connect to system identified by "Senha#" using 'pdbdenver';

Database link created.

-- No caso como estamos usando um PDB, é preciso criar um entrada no TNS para que o banco em recuperação possa se conectar a ele
-- Entrada no TNSNAMES.ora do banco secundário, onde foi criado o database link
ORCL_PDB1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = denver)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = pdb1)

-- Testar o acesos do banco secundário ao banco primário
SQL> select db_unique_name from v$database;

DB_UNIQUE_NAME
------------------------------
orcl

SQL> select db_unique_name from v$database@remote_pump;

DB_UNIQUE_NAME
------------------------------
denver

SQL> create directory pump as '/tmp';

Directory created.

-- Após a criação do dblilnk e da entrada no TNS, executar o expdp incluíndo o parâmtro network_link
[oracle@denver ~]$ expdp system@orcl_pdb1 network_link=remote_pump directory=pump dumpfile=bkp_employees.dmp logfile=bkp_employee.log tables=hr.bkp_employees

Export: Release 19.0.0.0.0 - Production on Thu Sep 21 20:16:48 2023
Version 19.17.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.
Password:

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Starting "SYSTEM"."SYS_EXPORT_TABLE_01":  system/ *******@orcl_pdb1 network_link=remote_pump directory=pump dumpfile=bkp_employees.dmp logfile=bkp_employee.log tables=hr.bkp_employees
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
Processing object type TABLE_EXPORT/TABLE/STATISTICS/TABLE_STATISTICS
Processing object type TABLE_EXPORT/TABLE/STATISTICS/MARKER
Processing object type TABLE_EXPORT/TABLE/TABLE
. . exported "HR"."BKP_EMPLOYEES"                        282.7 KB    3424 rows
Master table "SYSTEM"."SYS_EXPORT_TABLE_01" successfully loaded/unloaded
******************************************************************************
Dump file set for SYSTEM.SYS_EXPORT_TABLE_01 is:
  /tmp/bkp_employees.dmp
Job "SYSTEM"."SYS_EXPORT_TABLE_01" successfully completed at Thu Sep 21 20:17:09 2023 elapsed 0 00:00:17

-- Passo 8: Abrir o bando em modo read/write e executar o RESETLOGS
SQL> shutdown immediate
Database closed.
Database dismounted.
ORACLE instance shut down.
SQL> startup
ORACLE instance started.

Total System Global Area 3221224152 bytes
Fixed Size                  9140952 bytes
Variable Size             687865856 bytes
Database Buffers         2516582400 bytes
Redo Buffers                7634944 bytes
Database mounted.
ORA-01589: must use RESETLOGS or NORESETLOGS option for database open

SQL> recover database;
Media recovery complete.
SQL> alter database open;

Database altered.

-- Passo 9: Verificar o estado do banco e da tabela truncada
SQL> select name,open_mode,database_role from v$database;

NAME      OPEN_MODE            DATABASE_ROLE
--------- -------------------- ----------------
DENVER    READ WRITE           PRIMARY


SQL> show pdbs

    CON_ID CON_NAME                       OPEN MODE  RESTRICTED
---------- ------------------------------ ---------- ----------
         2 PDB$SEED                       READ ONLY  NO
         3 PDBDENVER                      READ WRITE NO
         4 PDB2                           MOUNTED
SQL> alter session set container = pdbdenver;

Session altered.

SQL> select count(1) from hr.bkp_employees;

  COUNT(1)
----------
         0
-- Passo 10: Realizar o import da tabela truncada

-- 10.1: Conectado no PDB de destino dos dados truncados, criar o diretório para referenciar o dump gerado

SQL> create directory pump as '/tmp';

Directory created.

SQL> host
[oracle@denver ~]$ impdp system@pdbdenver directory=pump dumpfile=bkp_employees.dmp logfile=imp-bkp_employee.log content=data_o

Import: Release 19.0.0.0.0 - Production on Thu Sep 21 20:38:34 2023
Version 19.17.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.
Password:

Connected to: Oracle Database 19c Enterprise Edition Release 19.0.0.0.0 - Production
Master table "SYSTEM"."SYS_IMPORT_FULL_01" successfully loaded/unloaded
Starting "SYSTEM"."SYS_IMPORT_FULL_01":  system/ ********@pdbdenver directory=pump dumpfile=bkp_employees.dmp logfile=imp-bkp_employee.log content=data_only
Processing object type TABLE_EXPORT/TABLE/TABLE_DATA
. . imported "HR"."BKP_EMPLOYEES"                        282.7 KB    3424 rows
Job "SYSTEM"."SYS_IMPORT_FULL_01" successfully completed at Thu Sep 21 20:38:45 2023 elapsed 0 00:00:06

[oracle@denver ~]$ exit
exit

SQL> select count(1) from hr.bkp_employees;

  COUNT(1)
----------
      3424

--  TODOS OS REGISTROS DA TABELA TRUNCADA FORAM RECUPERADO USANDO O FLASHBACK DATABASE, EXPDP E IMPDP.