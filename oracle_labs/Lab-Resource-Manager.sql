ALTER SESSION SET CONTAINER=CDB$ROOT;

show parameter resource;

ALTER SESSION SET CONTAINER=ORCLPDB;

exec DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();

BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PLAN(
    plan    => 'my_pdb_plan',
    comment => 'PDB resource plan for 1Z0-083');
END;
/

BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_CONSUMER_GROUP (
   CONSUMER_GROUP => 'pdb_group',
   COMMENT        => 'pdb_group');
END;
/

BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    plan                  => 'my_pdb_plan', 
    GROUP_OR_SUBPLAN      => 'pdb_group',
    COMMENT               => 'pdb_group',
    session_pga_limit     => 100, 
    undo_pool             => 50);
END;
/

BEGIN
  DBMS_RESOURCE_MANAGER.CREATE_PLAN_DIRECTIVE(
    plan                  => 'my_pdb_plan', 
    GROUP_OR_SUBPLAN      => 'OTHER_GROUPS',
    session_pga_limit     => 100, 
    undo_pool             => 50);
END;
/

exec DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA();

exec DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();

ALTER SYSTEM SET RESOURCE_MANAGER_PLAN = 'my_pdb_plan';

SET LINES 400
COL PLUGGABLE_DATABASE FOR A30
SELECT PLUGGABLE_DATABASE, SHARES, PARALLEL_SERVER_LIMIT FROM DBA_CDB_RSRC_PLAN_DIRECTIVES
WHERE PLAN='MY_PLAN' ORDER BY PLUGGABLE_DATABASE;

SELECT NAME, VALUE FROM V$PARAMETER WHERE NAME = 'resource_manager_plan';

exec DBMS_RESOURCE_MANAGER.CREATE_PENDING_AREA();

BEGIN
DBMS_RESOURCE_MANAGER.UPDATE_CDB_AUTOTASK_DIRECTIVE (
   plan                        => 'my_plan2',  
   new_shares                  => null,
   new_parallel_server_limit   => 100);
END;
/

BEGIN
DBMS_RESOURCE_MANAGER.UPDATE_CDB_DEFAULT_DIRECTIVE (
   plan                        => 'my_plan2',
   new_shares                  => 1, 
   new_parallel_server_limit   => 0);
END;
/

exec DBMS_RESOURCE_MANAGER.VALIDATE_PENDING_AREA();

exec DBMS_RESOURCE_MANAGER.SUBMIT_PENDING_AREA();

-- eliminando o plano

ALTER SYSTEM SET RESOURCE_MANAGER_PLAN = '';

BEGIN
  DBMS_RESOURCE_MANAGER.clear_pending_area;
  DBMS_RESOURCE_MANAGER.create_pending_area;

  DBMS_RESOURCE_MANAGER.delete_cdb_plan(plan => 'my_plan2');

  DBMS_RESOURCE_MANAGER.validate_pending_area;
  DBMS_RESOURCE_MANAGER.submit_pending_area;
END;
/