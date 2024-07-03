--########################################################################################
--# Program name : HGB_MPBL_Undo.sh
--# Path : /extsoft/MPBL/BL/Undo/bin
--# SQL name : HGB_MPBL_Undo_MV_ACCT_Check.sql
--#
--# Date : 2021/09/02 Created by Mike Kuan
--# Description : SR233414_行動裝置險月繳保費預繳專案
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare
  v_BILL_DATE      VARCHAR2(8)  := '&1';
  v_CYCLE          NUMBER(2)    := '&2';
  v_PROCESS_NO     NUMBER(3)    := '888';
  v_PROC_TYPE      VARCHAR2(1)  := 'B';
  CH_USER          VARCHAR2(8)  := 'MPBL';
  nu_bill_seq      number;
  CH_ACCT_GROUP    FY_TB_BL_CYCLE_PROCESS.ACCT_GROUP%TYPE;
  CH_STEP          VARCHAR2(4);
  CURSOR C1(ibill_seq number, iacct_group varchar2) IS
     select nvl(
      (select count(1) cnt
       from fy_tb_bl_bill_acct b
      where b.bill_seq   =ibill_seq
        and b.acct_group =iacct_group
        and v_PROCESS_NO=888),0) cnt from dual;
begin
  select bill_SEQ,
        (CASE WHEN v_PROCESS_NO=888 THEN 
              (SELECT ACCT_GROUP
                   FROM FY_TB_BL_CYCLE_PROCESS
                  WHERE CYCLE     =v_CYCLE
                    AND PROCESS_NO=v_PROCESS_NO)    
         END) ACCT_GROUP
    into nu_bill_seq, CH_ACCT_GROUP
    from fy_tb_bl_bill_cntrl A
   where A.bill_date =to_date(v_BILL_DATE,'yyyymmdd')
   and A.cycle=v_CYCLE
   AND A.CREATE_USER=CH_USER;
  FOR R1 IN C1(nu_bill_seq,CH_ACCT_GROUP) LOOP
     DBMS_OUTPUT.Put_Line(to_char(r1.cnt));  
  end loop; 
EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('Undo_MV_ACCT_Check Process RETURN_CODE = 9999'); 
end;
/  
