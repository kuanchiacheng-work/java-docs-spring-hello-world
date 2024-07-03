--########################################################################################
--# Program name : HGB_UBL_Preparation.sh
--# Path : /extsoft/UBL/BL/Preparation/bin
--# SQL name : HGB_UBL_Preparation_AR_Check.sql
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off
declare 
v_BILL_DATE       VARCHAR2(8)  := '&1';
v_CYCLE           NUMBER(2)    := '&2';
v_PROCESS_NO      NUMBER(3)    := '&3';
v_STEP            VARCHAR2(4)  := '&4';
v_PROC_TYPE       VARCHAR2(1)  := 'B';
CH_USER           VARCHAR2(8)  := 'MPBL';
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
      AND A.CREATE_USER=CH_USER
	  --AND A.CREATE_USER=B.CREATE_USER
	  AND A.CYCLE     =v_CYCLE
      AND B.CYCLE     =A.CYCLE
      AND B.PROCESS_NO=v_PROCESS_NO;
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':Preparation_'||v_STEP||' BEGIN');  
   IF v_STEP='CI' THEN
      FY_PG_BL_BILL_CI.MAIN(NU_BILL_SEQ,
                            v_PROCESS_NO,
                            CH_ACCT_GROUP,
                            v_PROC_TYPE,
                            CH_USER, 
                            CH_ERR_CDE, 
                            CH_ERR_MSG); 
      IF CH_ERR_CDE<>'0000' THEN
         RAISE ON_ERR;
      END IF;
   ELSIF v_STEP='BI' THEN   
      FY_PG_BL_BILL_BI.MAIN(NU_BILL_SEQ,
                            v_PROCESS_NO,
                            CH_ACCT_GROUP,
                            v_PROC_TYPE,
                            CH_USER, 
                            CH_ERR_CDE, 
                            CH_ERR_MSG); 
      IF CH_ERR_CDE<>'0000' THEN
         RAISE ON_ERR;
      END IF;   
   ELSIF v_STEP='MAST' THEN 
      FY_PG_BL_BILL_MAST.MAIN(NU_BILL_SEQ,
                              v_PROCESS_NO,
                              CH_ACCT_GROUP,
                              v_PROC_TYPE,
                              CH_USER, 
                              CH_ERR_CDE, 
                              CH_ERR_MSG); 
      IF CH_ERR_CDE<>'0000' THEN
         RAISE ON_ERR;
      END IF;  
   END IF;
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':Preparation_'||v_STEP||' END');                       
	 DBMS_OUTPUT.Put_Line(CH_ERR_CDE||CH_ERR_MSG);  
EXCEPTION 
   WHEN ON_ERR THEN
       DBMS_OUTPUT.Put_Line('Preparation_'||v_STEP|| ' Process RETURN_CODE = 9999'); 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('Preparation_'||v_STEP|| ' Process RETURN_CODE = 9999'); 
end;
/

exit;