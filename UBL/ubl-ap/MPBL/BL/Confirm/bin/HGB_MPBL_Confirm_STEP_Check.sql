--########################################################################################
--# Program name : HGB_UBL_Confirm.sh
--# Path : /extsoft/UBL/BL/Confirm/bin
--# SQL name : HGB_UBL_Confirm_STEP_Check.sql
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare
  v_BILL_DATE      VARCHAR2(8)  := '&1';
  v_CYCLE          NUMBER(2)    := '&2';
  v_PROCESS_NO     NUMBER(3)    := '&3';
  v_PROC_TYPE      VARCHAR2(1)  := 'B';
  CH_USER          VARCHAR2(8)  := 'MPBL';
  nu_bill_seq      number;
  CH_ACCT_GROUP    FY_TB_BL_CYCLE_PROCESS.ACCT_GROUP%TYPE;
  CH_STEP          VARCHAR2(4);
  CURSOR C1 IS
     SELECT DECODE(STATUS,'CL','CI',
                   'CI','BI',
                   'BI','MAST',
                   'MAST','CN',
                   'CN','END',STATUS) STEP                            
       FROM FY_TB_BL_BILL_PROCESS_LOG BL 
      WHERE BILL_SEQ  = nu_BILL_SEQ
        AND PROCESS_NO= v_PROCESS_NO
        AND (ACCT_GROUP= CH_ACCT_GROUP OR ACCT_GROUP= 'KEEP')
        AND PROC_TYPE = v_PROC_TYPE
        AND BEGIN_TIME= (SELECT MAX(BEGIN_TIME) from FY_TB_BL_BILL_PROCESS_LOG 
                                           WHERE BILL_SEQ  = BL.BILL_SEQ
                                             AND PROCESS_No= BL.PROCESS_NO
                                             AND ACCT_GROUP= BL.ACCT_GROUP
                                             AND PROC_TYPE = BL.PROC_TYPE)
     order by DECODE(STATUS,'CL',1,'CI',2,'BI',3,'MAST',4,'CN',5,0) DESC; 
     R1     C1%ROWTYPE;
begin
  select bill_SEQ,
        (CASE WHEN v_PROCESS_NO<>999 THEN 
              (SELECT ACCT_GROUP
                   FROM FY_TB_BL_CYCLE_PROCESS
                  WHERE CYCLE     =A.CYCLE
                    AND PROCESS_NO=v_PROCESS_NO)
         ELSE
            (SELECT DECODE(v_PROC_TYPE,'B','HOLD','QA')
                FROM DUAL)           
         END) ACCT_GROUP
    into nu_bill_seq, CH_ACCT_GROUP
    from fy_tb_bl_bill_cntrl A
   where A.bill_date =to_date(v_BILL_DATE,'yyyymmdd')
   and a.cycle=v_CYCLE
   and a.create_user=CH_USER;
  OPEN C1;
  FETCH C1 INTO R1;
  IF C1%NOTFOUND THEN  
     CH_STEP :='CI';
  ELSE
     CH_STEP := R1.STEP;
  END IF;
  CLOSE C1;
  IF CH_STEP NOT IN ('CI','BI','MAST','CN') THEN
     DBMS_OUTPUT.Put_Line('Confirm_STEP_Check Process RETURN_CODE = 9999'); 
  ELSE   
     DBMS_OUTPUT.Put_Line(CH_STEP);
  END IF;   
EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('Confirm_STEP_Check Process RETURN_CODE = 9999'); 
end;
/  
