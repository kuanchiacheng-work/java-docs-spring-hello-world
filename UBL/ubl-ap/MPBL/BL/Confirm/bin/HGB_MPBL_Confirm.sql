--########################################################################################
--# Program name : HGB_UBL_Confirm.sh
--# Path : /extsoft/UBL/BL/Confirm/bin
--# SQL name : HGB_UBL_Confirm.sql
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
   SELECT A.CYCLE, A.BILL_PERIOD, A.BILL_SEQ, A.CYCLE_MONTH, B.ACCT_GROUP
     INTO NU_CYCLE, CH_BILL_PERIOD, NU_BILL_SEQ, NU_CYCLE_MONTH, CH_ACCT_GROUP
     FROM FY_TB_BL_BILL_CNTRL A,
          FY_TB_BL_CYCLE_PROCESS B
    WHERE TO_CHAR(A.BILL_DATE,'YYYYMMDD')=v_BILL_DATE
	  AND A.CREATE_USER=CH_USER
	  --AND A.CREATE_USER=B.CREATE_USER
	  AND b.cycle =v_CYCLE
      AND B.CYCLE     =A.CYCLE
      AND B.PROCESS_NO=v_PROCESS_NO;
   --999³B²z
	 IF v_PROCESS_NO=999 THEN 
      SELECT MAX(ACCT_GROUP) 
        INTO CH_ACCT_GROUP
        FROM FY_TB_BL_BILL_PROCESS_LOG A
       WHERE BILL_SEQ   =NU_BILL_SEQ
         AND PROCESS_NO =v_PROCESS_NO
         AND ACCT_GROUP LIKE 'CONF%'
         AND PROC_TYPE  ='B'
         AND STATUS     ='CN';
      IF CH_ACCT_GROUP IS NULL THEN
         CH_ACCT_GROUP := 'CONF1';
      ELSE
         CH_ACCT_GROUP := 'CONF'||(TO_NUMBER(SUBSTR(CH_ACCT_GROUP,-1))+1);
      END IF; 
      INSERT INTO FY_TB_BL_BILL_PROCESS_LOG
                      (BILL_SEQ,
                       PROCESS_NO,
                       ACCT_GROUP,
                       PROC_TYPE,
                       STATUS,
                       FILE_REPLY,
                       BEGIN_TIME,
                       END_TIME,
                       CURRECT_ACCT_ID,
                       COUNT,
                       CREATE_DATE,
                       CREATE_USER,
                       UPDATE_DATE,
                       UPDATE_USER)
                SELECT BILL_SEQ,
                       PROCESS_NO,
                       CH_ACCT_GROUP,
                       PROC_TYPE,
                       STATUS,
                       FILE_REPLY,
                       BEGIN_TIME,
                       END_TIME,
                       CURRECT_ACCT_ID,
                       COUNT,
                       CREATE_DATE,
                       CREATE_USER,
                       UPDATE_DATE,
                       UPDATE_USER
                  FROM FY_TB_BL_BILL_PROCESS_LOG
                 WHERE BILL_SEQ   =NU_BILL_SEQ
                   AND PROCESS_NO =v_PROCESS_NO
                   AND (ACCT_GROUP = 'HOLD' OR ACCT_GROUP = 'KEEP')
                   AND PROC_TYPE  ='B'
				   AND ROWNUM <=3
				   ORDER BY begin_time DESC;
      UPDATE FY_TB_BL_ACCT_LIST SET TYPE=CH_ACCT_GROUP
                          WHERE BILL_SEQ =NU_BILL_SEQ
                            AND TYPE     ='CONF';       
   COMMIT;
   END IF;     
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS')||':CONFIRM BEGIN');
   FY_PG_BL_BILL_CONFIRM.MAIN(NU_BILL_SEQ,
                              v_PROCESS_NO,
                              CH_ACCT_GROUP,
                              'B',
                              CH_USER, 
                              CH_ERR_CDE, 
                              CH_ERR_MSG); 
   IF CH_ERR_CDE<>'0000' THEN
      CH_ERR_MSG := 'FY_PG_BL_BILL_CONFIRM:'||CH_ERR_MSG;
      RAISE ON_ERR;
   END IF;                         
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS')||':CONFIRM END');                      
           DBMS_OUTPUT.Put_Line(CH_ERR_CDE||CH_ERR_MSG);  
EXCEPTION 
   WHEN ON_ERR THEN
       DBMS_OUTPUT.Put_Line('Confirm Process RETURN_CODE = 9999');
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('Confirm Process RETURN_CODE = 9999');
end;
/

exit;
