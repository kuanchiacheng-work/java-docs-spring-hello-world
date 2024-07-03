--########################################################################################
--# Program name : HGB_MPBL_Undo.sh
--# Program name : HGB_MPBL_Confirm.sh
--# Path : /extsoft/MPBL/BL/Undo/bin
--# Path : /extsoft/MPBL/BL/Confirm/bin
--# SQL name : HGB_MPBL_UPDATE_ACCT_LIST.sql
--#
--# Date : 2021/02/19 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off
declare 
v_BILL_DATE       VARCHAR2(8)  := '&1';
v_CYCLE           NUMBER(2)    := '&2';
v_PROCESS_NO      NUMBER(3)    := '999';
CH_USER           VARCHAR2(8)  := 'MPBL';
CH_BILL_DAY       VARCHAR2(2);
CH_HOLD_TABLE     VARCHAR2(30);
v_SQL1             VARCHAR2(1000);
v_SQL2            VARCHAR2(1000);
NU_CYCLE_MONTH    NUMBER(2);
NU_BILL_SEQ       NUMBER;
CH_ERR_CDE        VARCHAR2(10);
CH_ERR_MSG        VARCHAR2(300);
On_Err            EXCEPTION;

  CURSOR C1(ibill_seq number) IS
	SELECT h.hold_count, c.confirm_count, ced.confirmed_count
	FROM (SELECT COUNT (1) hold_count
			FROM fy_tb_bl_acct_list
			WHERE bill_seq = ibill_seq AND TYPE = 'HOLD') h,
		(SELECT COUNT (1) confirm_count
			FROM fy_tb_bl_acct_list
			WHERE bill_seq = ibill_seq AND TYPE = 'CONF') c,
		(SELECT COUNT (1) confirmed_count
			FROM fy_tb_bl_acct_list
			WHERE bill_seq = ibill_seq
			AND TYPE LIKE 'CONF%'
			AND TYPE NOT IN ('HOLD', 'CONF')) ced;
		
begin 
   CH_ERR_MSG := 'GET BILL_CNTRL:';
   SELECT A.BILL_SEQ, A.CYCLE_MONTH, substr(to_char(A.BILL_DATE,'yyyymmdd'),7,8) BILL_DAY
     INTO NU_BILL_SEQ, NU_CYCLE_MONTH, CH_BILL_DAY
     FROM FY_TB_BL_BILL_CNTRL A,
          FY_TB_BL_CYCLE_PROCESS B
    WHERE TO_CHAR(A.BILL_DATE,'YYYYMMDD')=v_BILL_DATE
	  AND A.CREATE_USER=CH_USER
	  AND A.CYCLE=v_CYCLE
      AND B.CYCLE=A.CYCLE
      AND B.PROCESS_NO=v_PROCESS_NO;
   DBMS_OUTPUT.Put_Line('BILL_SEQ = '||NU_BILL_SEQ||' , CYCLE_MONTH = '||NU_CYCLE_MONTH||' , BILL_DAY = '||CH_BILL_DAY);

CH_HOLD_TABLE:='M'||CH_BILL_DAY||'_HOLD_LIST@prdappc.prdcm';
   DBMS_OUTPUT.Put_Line('OCS HOLD TABLE = '||CH_HOLD_TABLE);
   
--dynamic SQL update HGB_MPBL acct_list from OCS hold_list
   DBMS_OUTPUT.Put_Line('start update FY_TB_BL_ACCT_LIST.TYPE from HOLD to CONF');
   v_SQL1:='update fy_tb_bl_acct_list a set TYPE = ''CONF'''
            || ' WHERE TYPE = ''HOLD'''
            || '   AND NOT EXISTS ('
			|| ' SELECT 1 FROM ' ||CH_HOLD_TABLE
			|| ' WHERE a.acct_id = account_no AND a.bill_seq = cycle_seq_no '
			|| ' AND a.CYCLE = cycle_code)'
            || ' AND a.bill_seq = '||NU_BILL_SEQ;
   DBMS_OUTPUT.Put_Line('start update FY_TB_BL_ACCT_LIST.TYPE from CONF to HOLD');		
   v_SQL2:='update fy_tb_bl_acct_list a set TYPE = ''HOLD'''
            || ' WHERE TYPE = ''CONF'''
            || '   AND EXISTS ('
			|| ' SELECT 1 FROM ' ||CH_HOLD_TABLE
			|| ' WHERE a.acct_id = account_no AND a.bill_seq = cycle_seq_no '
			|| ' AND a.CYCLE = cycle_code)'
            || ' AND a.bill_seq = '||NU_BILL_SEQ;
			
execute immediate v_SQL1;
   DBMS_OUTPUT.Put_Line('end update FY_TB_BL_ACCT_LIST.TYPE from HOLD to CONF');
execute immediate v_SQL2;
   DBMS_OUTPUT.Put_Line('end update FY_TB_BL_ACCT_LIST.TYPE from CONF to HOLD');
COMMIT;

FOR R1 IN C1(nu_bill_seq) LOOP
   DBMS_OUTPUT.Put_Line('updated FY_TB_BL_ACCT_LIST.TYPE, HOLD_COUNT='||to_char(r1.hold_count)||' ,CONFIRM_COUNT='||to_char(r1.confirm_count)||' ,CONFIRMED_COUNT='||to_char(r1.confirmed_count));
       DBMS_OUTPUT.Put_Line('update FY_TB_BL_ACCT_LIST.TYPE = 0000'); 
end loop; 

EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line(CH_ERR_MSG||'update FY_TB_BL_ACCT_LIST.TYPE = 9999'); 
end;
/

exit;
