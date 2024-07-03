--########################################################################################
--# Program name : HGB_MPBL_Undo.sh
--# SQL name : HGB_MPBL_Undo_STATUS_Check.sql
--# Path : /extsoft/MPBL/BL/Undo/bin
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
  CURSOR C1(ibill_seq number, iacct_group varchar2) IS
     select distinct bill_status status, count(1) cnt
	   from fy_tb_bl_acct_list a,
			fy_tb_bl_bill_acct b
	  where a.bill_seq=ibill_seq
	    and a.type    =iacct_group
	    and b.bill_seq=a.bill_seq
	    and b.acct_id =a.acct_id
		and v_PROCESS_NO=999
	  group by b.bill_status
	union
      select distinct bill_status status, count(1) cnt
	   from fy_tb_bl_bill_acct b
	  where b.bill_seq   =ibill_seq
	    and b.acct_group =iacct_group
		and v_PROCESS_NO<>999
	  group by b.bill_status;	
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
   and a.cycle=v_CYCLE
   AND A.CREATE_USER =CH_USER;
  FOR R1 IN C1(nu_bill_seq,CH_ACCT_GROUP) LOOP
     DBMS_OUTPUT.Put_Line('Undo_STATUS_Check Status='||r1.status||', Cnt='||to_char(r1.cnt));  
  end loop; 
EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('Undo_STATUS_Check Process RETURN_CODE = 9999'); 
end;
/  
