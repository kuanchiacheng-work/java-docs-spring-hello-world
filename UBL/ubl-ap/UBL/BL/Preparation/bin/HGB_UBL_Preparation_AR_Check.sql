--########################################################################################
--# Program name : HGB_UBL_Preparation.sh
--# Path : /extsoft/UBL/BL/Preparation/bin
--# SQL name : HGB_UBL_Preparation_AR_Check.sql
--#
--# Date : 2018/09/17 Created by Mike Kuan
--# Description : HGB UBL Preparation
--########################################################################################
--# Date : 2019/06/30 Modify by Mike Kuan
--# Description : SR213344_NPEP add cycle parameter
--########################################################################################
--# Date : 2021/02/20 Modify by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare
  v_BILL_DATE      VARCHAR2(8)  := '&1';
  v_CYCLE          NUMBER(2)    := '&2';
  v_PROCESS_NO     NUMBER(3)    := '&3';
  v_PROC_TYPE      VARCHAR2(1)  := '&4';
  CH_USER          VARCHAR2(8)  := 'UBL';
  nu_bill_seq      number;
  CH_ACCT_GROUP    FY_TB_BL_CYCLE_PROCESS.ACCT_GROUP%TYPE;
  CH_STATUS        FY_TB_DIO_CNTRL.STATUS%TYPE;
  CH_IO_TYPE       FY_TB_DIO_CNTRL.IO_TYPE%TYPE;
  NU_CNT           NUMBER;
  On_Err           EXCEPTION;
  CURSOR C1 IS
     SELECT STATUS
       FROM FY_TB_DIO_CNTRL A
      WHERE BILL_SEQ  =NU_BILL_SEQ
        AND PROCESS_NO=v_PROCESS_NO
        AND ACCT_GROUP=CH_ACCT_GROUP
        AND PROC_TYPE =v_PROC_TYPE
        AND PROC_ID   ='BALANCE' 
     --   AND STATUS    ='S'
        AND PRE_CNTRL_SEQ =(SELECT MAX(CNTRL_SEQ) FROM FY_TB_DIO_CNTRL
                             WHERE BILL_SEQ  =A.BILL_SEQ
                               AND PROCESS_NO=A.PROCESS_NO
                               AND ACCT_GROUP=A.ACCT_GROUP
                               AND PROC_TYPE =A.PROC_TYPE
                               AND PROC_ID   ='ACCTLIST')
		order by decode(STATUS,'E',1,'A',2,'S',3,4);

begin
  select bill_SEQ,
        (CASE WHEN v_PROCESS_NO<>999 THEN 
              (SELECT ACCT_GROUP
                   FROM FY_TB_BL_CYCLE_PROCESS
                  WHERE CYCLE     =v_CYCLE
                    AND PROCESS_NO=v_PROCESS_NO)
         ELSE
            (SELECT DECODE(v_PROC_TYPE,'B','HOLD','QA')
                FROM DUAL)           
         END) ACCT_GROUP
    into nu_bill_seq, CH_ACCT_GROUP
    from fy_tb_bl_bill_cntrl A
   where A.bill_date =to_date(v_BILL_DATE,'yyyymmdd')
   and A.cycle=v_CYCLE
   and A.CREATE_USER=CH_USER;
   
  CH_STATUS :='Y';
  FOR R1 IN C1 LOOP
    IF R1.STATUS='E' THEN
       DBMS_OUTPUT.Put_Line('Preparation_AR_Check Process RETURN_CODE = 9999'); 
       RAISE ON_ERR;
    ELSIF R1.STATUS<>'S' THEN
       DBMS_OUTPUT.Put_Line('Preparation_AR_Check Processing'); 
       RAISE ON_ERR;
    END IF;
    CH_STATUS :='N';
  END LOOP;
  IF CH_STATUS='Y' THEN
     DBMS_OUTPUT.Put_Line('Preparation_AR_Check Processing'); 
  ELSE   
     DBMS_OUTPUT.Put_Line('Preparation_AR_Check Process RETURN_CODE = 0000'); 
  END IF;   
EXCEPTION 
   WHEN on_err THEN
      NULL;
   WHEN OTHERS THEN
     DBMS_OUTPUT.Put_Line('Preparation_AR_Check Process RETURN_CODE = 9999'); 
end;
/
