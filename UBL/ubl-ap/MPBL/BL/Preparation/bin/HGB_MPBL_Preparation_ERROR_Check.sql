--########################################################################################
--# Program name : HGB_MPBL_Preparation.sh
--# Path : /extsoft/MPBL/BL/Preparation/bin
--# SQL name : HGB_MPBL_Preparation_ERROR_Check.sql
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
CH_BILL_DAY       VARCHAR2(2);
CH_HOLD_TABLE     VARCHAR2(30);
v_SQL             VARCHAR2(1000);
NU_CYCLE_MONTH    NUMBER(2);
NU_BILL_SEQ       NUMBER;
CH_ERR_CDE        VARCHAR2(10);
CH_ERR_MSG        VARCHAR2(300);
On_Err            EXCEPTION;

  CURSOR C1(ibill_seq number) IS
     select distinct ERR_CDE MSG, count(1) cnt
           from fy_tb_bl_bill_process_err B
          where B.bill_seq=ibill_seq
		  AND B.process_no   =v_PROCESS_NO
          group by b.ERR_CDE;  
		
begin 
   CH_ERR_MSG := 'GET BILL_CNTRL:';
   SELECT A.BILL_SEQ, A.CYCLE_MONTH, substr(to_char(A.BILL_DATE,'yyyymmdd'),7,8) BILL_DAY
     INTO NU_BILL_SEQ, NU_CYCLE_MONTH, CH_BILL_DAY
     FROM FY_TB_BL_BILL_CNTRL A,
          FY_TB_BL_CYCLE_PROCESS B
    WHERE TO_CHAR(A.BILL_DATE,'YYYYMMDD')=v_BILL_DATE
	  AND A.CREATE_USER=CH_USER
	  --AND A.CREATE_USER=B.CREATE_USER
	  AND A.CYCLE=v_CYCLE
      AND B.CYCLE=A.CYCLE
      AND B.PROCESS_NO=v_PROCESS_NO;
   DBMS_OUTPUT.Put_Line('BILL_SEQ = '||NU_BILL_SEQ||' , CYCLE_MONTH = '||NU_CYCLE_MONTH||' , BILL_DAY = '||CH_BILL_DAY);

CH_HOLD_TABLE:='M'||CH_BILL_DAY||'_HOLD_LIST@prdappc.prdcm';
   DBMS_OUTPUT.Put_Line('OCS HOLD TABLE = '||CH_HOLD_TABLE);
   
--dynamic SQL insert OCS hold_list from HGB_MPBL acct_list
   DBMS_OUTPUT.Put_Line('start insert into '||CH_HOLD_TABLE);
   v_SQL:='INSERT INTO '||CH_HOLD_TABLE 
                      ||'(ba_no, '
                      ||' account_no, '
                      ||' format_ext_group, ' 
                      ||' customer_id, '
                      ||' hold_desc, '
                      ||' bf_undo, '
                      ||' bl_undo, '
                      ||' rerate, '
                      ||' insert_date, '
                      ||' cycle_code, '
                      ||' cycle_month, '
                      ||' cycle_seq_no, '
                      ||' cycle_year, '
                      ||' bu_qa, '
                      ||' hold_ind, '
                      ||' qa_group_name) '
             ||' SELECT DISTINCT d.ben,' 
                    ||'d.ban, '
                    ||'''0'', '
                    ||'d.customer_id, '
                    ||'''HGB_MPBL_Reject'', '
                    ||'''Y'', '
                    ||'''Y'', '
                    ||'''N'', '
                    ||'TO_DATE('''||TO_CHAR(SYSDATE,'YYYYMMDD')||''',''YYYYMMDD'')' ||',' 
                    ||'c.cycle_code, '
                    ||'c.cycle_instance, '
                    ||'c.cycle_seq_no, '
                    ||'c.cycle_year, '
                    ||'''Y'', '
                    ||'''Y'', '
                    ||'''HGB_MPBL_Reject'''
              ||' FROM fy_tb_bl_bill_process_err a, '
              ||' fy_tb_bl_bill_acct b, '
			  ||'(SELECT cycle_year, '
			  ||'cycle_instance, '
			  ||'cycle_code, '
              ||'cycle_seq_no'
                      ||' FROM bl1_cycle_control@prdappc.prdcm '
                     ||'WHERE cycle_seq_no = '||NU_BILL_SEQ
					 ||') c,'
              ||'csm_pay_channel@prdappc.prdcm'||' d '
            || ' WHERE a.bill_seq = '||NU_BILL_SEQ
            || '   and a.bill_seq = b.bill_seq '
            || '   and a.bill_seq = c.cycle_seq_no '
            || '   and a.process_no = '||v_PROCESS_NO
            || '   and a.acct_id = b.acct_id '
            || '   and a.acct_id = d.ban '
            || '   and b.bill_status = ''RJ'''	
            || '   and d.ben NOT IN (SELECT ba_no'
			|| ' FROM '||CH_HOLD_TABLE
			|| ' WHERE hold_desc LIKE ''HGB_MPBL_Reject'')';

execute immediate v_SQL;
   DBMS_OUTPUT.Put_Line('end insert into '||CH_HOLD_TABLE);
COMMIT;

FOR R1 IN C1(nu_bill_seq) LOOP
   DBMS_OUTPUT.Put_Line('Preparation ERROR Check MSG='||r1.MSG||', Cnt='||to_char(r1.cnt));
       DBMS_OUTPUT.Put_Line('Preparation ERROR Check Process RETURN_CODE = 0000'); 
end loop; 

EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line(CH_ERR_MSG||'Preparation ERROR Check Process RETURN_CODE = 9999'); 
end;
/

exit;
