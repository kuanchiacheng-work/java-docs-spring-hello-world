--########################################################################################
--# Program name : HGB_MPBL_Undo.sh
--# SQL name : HGB_MPBL_Undo.sql
--# Path : /extsoft/MPBL/BL/Undo/bin
--#
--# Date : 2020/03/24 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off
declare 
v_BILL_DATE 	  VARCHAR2(8)  := '&1';
v_CYCLE           NUMBER(2)    := '&2';
v_PROCESS_NO      NUMBER(3)    := '&3';
v_PROC_TYPE       VARCHAR2(1)  := 'B';
v_USER            VARCHAR2(8)  := 'MPBL';
NU_CYCLE          NUMBER(2);
CH_BILL_PERIOD    VARCHAR2(6);
NU_CYCLE_MONTH    NUMBER(2);
NU_BILL_SEQ       NUMBER;
CH_ACCT_GROUP     FY_TB_BL_CYCLE_PROCESS.ACCT_GROUP%TYPE;
CH_ERR_CDE        VARCHAR2(10);
CH_ERR_MSG        VARCHAR2(300);
On_Err            EXCEPTION;
begin 
	 CH_ERR_MSG := 'GET BILL_CNTRL:';
   SELECT A.CYCLE, A.BILL_PERIOD, A.BILL_SEQ, A.CYCLE_MONTH, DECODE(V_PROCESS_NO,999,DECODE(V_PROC_TYPE,'T','QA',B.ACCT_GROUP),B.ACCT_GROUP)
     INTO NU_CYCLE, CH_BILL_PERIOD, NU_BILL_SEQ, NU_CYCLE_MONTH, CH_ACCT_GROUP
     FROM FY_TB_BL_BILL_CNTRL A,
          FY_TB_BL_CYCLE_PROCESS B
    WHERE TO_CHAR(A.BILL_DATE,'YYYYMMDD')=v_BILL_DATE
	  AND A.CREATE_USER=v_USER
	  --AND A.CREATE_USER=B.CREATE_USER
	  AND A.CYCLE=v_CYCLE
	  AND B.CYCLE     =A.CYCLE
      AND B.PROCESS_NO=v_PROCESS_NO;
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':UNDO BEGIN');
   --update fy_tb_bl_bill_acct										
   FY_PG_BL_BILL_UNDO.MAIN(NU_BILL_SEQ,
                           v_PROCESS_NO,
                           CH_ACCT_GROUP,
                           v_PROC_TYPE,
                           v_USER, 
                           CH_ERR_CDE, 
                           CH_ERR_MSG); 
   IF CH_ERR_CDE<>'0000' THEN
      CH_ERR_MSG := 'FY_PG_BL_BILL_CI:'||CH_ERR_MSG;
      RAISE ON_ERR;
   END IF;
   if v_PROCESS_NO=999 and v_PROC_TYPE='B' then
      update fy_tb_bl_bill_acct a set acct_group='HOLD'
	                    where bill_seq   =nu_bill_seq
						  and cycle      =nu_cycle
						  and cycle_month=nu_cycle_month
						  and acct_key   =mod(acct_id,100)
						  and bill_status <>'CN'
						  and exists (select 1 from fy_tb_bl_acct_list
						                  where bill_seq=nu_bill_seq
										    and type=ch_acct_group
											and acct_id=a.acct_id);
   commit;
   end if;	
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':UNDO END');   
	 DBMS_OUTPUT.Put_Line(CH_ERR_CDE||CH_ERR_MSG);  
EXCEPTION 
   WHEN ON_ERR THEN
       DBMS_OUTPUT.Put_Line('Undo Process RETURN_CODE = 9999');
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('Undo Process RETURN_CODE = 9999'); 
end;
/

exit;