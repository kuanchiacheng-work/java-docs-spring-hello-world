--########################################################################################
--# Program name : HGB_MPBL_CutDate.sh
--# SQL name : HGB_MPBL_CutDate_STATUS_Check.sql
--# Path : /extsoft/MPBL/BL/CutDate/bin
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare
  v_BILL_DATE      VARCHAR2(8)  := '&1';
  v_CYCLE          NUMBER(2)    := '&2';
  v_USER           VARCHAR2(8)  := 'MPBL';
  nu_bill_seq      number;
  CH_ACCT_GROUP    FY_TB_BL_CYCLE_PROCESS.ACCT_GROUP%TYPE;
  CH_STEP          VARCHAR2(4);
  CURSOR C1(ibill_seq number) IS
     select distinct bill_status status, count(1) cnt
           from fy_tb_bl_bill_acct B
          where B.bill_seq=ibill_seq
		  AND B.CYCLE   =v_CYCLE
          group by b.bill_status;  
begin
  select bill_SEQ
    into nu_bill_seq
    from fy_tb_bl_bill_cntrl A
   where A.bill_date =to_date(v_BILL_DATE,'yyyymmdd')
   AND A.CYCLE   =v_CYCLE
   AND A.CREATE_USER =v_USER;
  FOR R1 IN C1(nu_bill_seq) LOOP
     DBMS_OUTPUT.Put_Line('CutDate_STATUS_Check Status='||r1.status||', Cnt='||to_char(r1.cnt));  
  end loop; 
EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('CutDate_STATUS_Check Process RETURN_CODE = 9999'); 
end;
/  
