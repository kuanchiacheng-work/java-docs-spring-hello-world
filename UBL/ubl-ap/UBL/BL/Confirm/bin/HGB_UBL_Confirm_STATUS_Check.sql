--########################################################################################
--# Program name : HGB_UBL_Confirm.sh
--# Path : /extsoft/UBL/BL/Confirm/bin
--# SQL name : HGB_UBL_Confirm_STATUS_Check.sql
--#
--# Date : 2019/06/30 Modify by Mike Kuan
--# Description : SR213344_NPEP add cycle parameter
--########################################################################################
--# Date : 2021/02/20 Modify by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################
--# Date : 2022/04/07 Modify by Mike Kuan
--# Description : HOLD > CONF
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare
  v_BILL_DATE      VARCHAR2(8)  := '&1';
  v_CYCLE          NUMBER(2)    := '&2';
  v_PROCESS_NO     NUMBER(3)    := '&3';
  v_type           VARCHAR2(8)  := '&4';
  CH_USER          VARCHAR2(8)  := 'UBL';
  nu_bill_seq      number;
  v_PROC_TYPE      VARCHAR2(1)  := 'B';
  NU_CYCLE         NUMBER(2);
  NU_CYCLE_MONTH   NUMBER(2);
  CH_ACCT_GROUP    FY_TB_BL_CYCLE_PROCESS.ACCT_GROUP%TYPE;
  nu_cnt           number;
  CH_STEP          VARCHAR2(4);
  CURSOR C1(ibill_seq number, iacct_group varchar2) IS
     select distinct bill_status status, count(1) cnt
	   from fy_tb_bl_acct_list a,
			fy_tb_bl_bill_acct b
	  where a.bill_seq    =ibill_seq
	    and a.type        =iacct_group
	    and b.bill_seq    =a.bill_seq
	    AND B.CYCLE       =NU_CYCLE
	    AND B.CYCLE_MONTH =NU_CYCLE_MONTH
	    AND B.ACCT_KEY    =MOD(A.ACCT_ID,100)
	    and b.acct_id     =a.acct_id
		and v_PROCESS_NO=999
	  group by b.bill_status
	union
     select distinct bill_status status, count(1) cnt
	   from fy_tb_bl_bill_acct b
	  where b.bill_seq    =ibill_seq
	    AND B.CYCLE       =NU_CYCLE
	    AND B.CYCLE_MONTH =NU_CYCLE_MONTH
	    AND B.ACCT_KEY    =MOD(B.ACCT_ID,100)
	    and b.acct_group =iacct_group
		and v_PROCESS_NO<>999
	  group by b.bill_status;	
begin
  select bill_SEQ, CYCLE, CYCLE_MONTH,
        (CASE WHEN v_PROCESS_NO<>999 THEN 
              (SELECT ACCT_GROUP
                   FROM FY_TB_BL_CYCLE_PROCESS
                  WHERE CYCLE     =A.CYCLE
                    AND PROCESS_NO=v_PROCESS_NO)
         ELSE
            (SELECT DECODE(v_PROC_TYPE,'B','CONF','QA')
                FROM DUAL)                      
         END) ACCT_GROUP
    into nu_bill_seq, NU_CYCLE, NU_CYCLE_MONTH, CH_ACCT_GROUP
    from fy_tb_bl_bill_cntrl A
   where A.bill_date =to_date(v_BILL_DATE,'yyyymmdd')
   and a.cycle=v_CYCLE
   AND A.CREATE_USER=CH_USER;
  if v_PROCESS_NO=999 and v_type='AFTER' THEN 
     SELECT MAX(ACCT_GROUP) 
        INTO CH_ACCT_GROUP
        FROM FY_TB_BL_BILL_PROCESS_LOG A
       WHERE BILL_SEQ   =NU_BILL_SEQ
         AND PROCESS_NO =v_PROCESS_NO
         AND ACCT_GROUP LIKE 'CONF%'
         AND PROC_TYPE  ='B'
         AND STATUS     ='CN'; 
  END IF;       
  nu_cnt := 0; 
  FOR R1 IN C1(nu_bill_seq,CH_ACCT_GROUP) LOOP
      nu_cnt := nu_cnt + r1.cnt;
     DBMS_OUTPUT.Put_Line('Confirm_STATUS_Check Status='||r1.status||', Cnt='||to_char(r1.cnt));  
  end loop; 
  if nu_cnt=0 then
     DBMS_OUTPUT.Put_Line('Confirm_STATUS_Check Process RETURN_CODE = 9999'); 
  end if;	 
EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('Confirm_STATUS_Check Process RETURN_CODE = 9999'); 
end;
/  
