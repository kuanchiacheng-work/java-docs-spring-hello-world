--########################################################################################
--# Program name : HGB_MPBL_CutDate.sh
--# SQL name : HGB_MPBL_CutDate_Pre.sql
--# Path : /extsoft/MPBL/BL/CutDate/bin
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare 
	v_BILL_DATE         VARCHAR2(8)   := '&1'; 
	v_CYCLE             NUMBER(2)     := '&2';
	v_USER              VARCHAR2(8)   := 'MPBL'; 
	NU_CNT              NUMBER        := 0;
	NU_BILL_SEQ         NUMBER;
	NU_BILL_FROM_DATE   DATE;
	NU_BILL_END_DATE    DATE;
begin
--Check Cycle Information
DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN Check Cycle Information Process...'||v_BILL_DATE||' cycle:'||v_CYCLE); 
	SELECT cycle_seq_no, TRUNC (start_date), TRUNC (end_date)
	INTO nu_bill_seq, nu_bill_from_date, nu_bill_end_date
	FROM bl1_cycle_control
	WHERE end_date = TO_DATE (v_bill_date, 'yyyymmdd') - 1
		AND cycle_code = v_cycle;
DBMS_OUTPUT.Put_Line('BILL_SEQ='||NU_BILL_SEQ||', NU_BILL_FROM_DATE='||NU_BILL_FROM_DATE||', NU_BILL_END_DATE='||NU_BILL_END_DATE); 
DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END Check Cycle Information Process...'); 

--Query
DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN Query Table Process...'); 
	SELECT COUNT (1)
	INTO nu_cnt
	FROM fet1_transaction_log_mpbl
	WHERE bill_seq = nu_bill_seq;
DBMS_OUTPUT.Put_Line('NU_CNT='||NU_CNT);
DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END Query Table Process...'); 

--Delete
if NU_CNT > 0 then
	DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN Delete Table Process...'); 
		DELETE fet1_transaction_log_mpbl WHERE bill_seq = nu_bill_seq;
		COMMIT;
	DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END Delete Table Process...'); 
	
	--Insert
	DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN Insert Table Process...'); 
		INSERT INTO fet1_transaction_log_mpbl VALUE
					(period_key, bill_seq, TRANS_TYPE, TRANS_DATE, account_id, create_date, create_user)
		SELECT   a.period_key, NU_BILL_SEQ , TRANS_TYPE, TRANS_DATE, account_id , SYSDATE , v_USER
			FROM fet1_transaction_log a
		WHERE (   a.period_key =
						TO_NUMBER (TO_CHAR (NU_BILL_FROM_DATE, 'YYYYMM'))
				OR a.period_key =
						TO_NUMBER (TO_CHAR (NU_BILL_END_DATE, 'YYYYMM'))
				)
			AND a.trans_date >= NU_BILL_FROM_DATE
			AND a.trans_date <= NU_BILL_END_DATE
			AND a.trans_type NOT IN ('WO', 'WOR', 'INV')
			AND a.account_id < 990000000;
		commit;
	DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END Insert Table Process...'); 
else
	--Insert
	DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN Insert Table Process...'); 
		INSERT INTO fet1_transaction_log_mpbl VALUE
					(period_key, bill_seq, TRANS_TYPE, TRANS_DATE, account_id, create_date, create_user)
		SELECT   a.period_key, NU_BILL_SEQ , TRANS_TYPE, TRANS_DATE, account_id , SYSDATE , v_USER
			FROM fet1_transaction_log a
		WHERE (   a.period_key =
						TO_NUMBER (TO_CHAR (NU_BILL_FROM_DATE, 'YYYYMM'))
				OR a.period_key =
						TO_NUMBER (TO_CHAR (NU_BILL_END_DATE, 'YYYYMM'))
				)
			AND a.trans_date >= NU_BILL_FROM_DATE
			AND a.trans_date <= NU_BILL_END_DATE
			AND a.trans_type NOT IN ('WO', 'WOR', 'INV')
			AND a.account_id < 990000000;
		commit;
	DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END Insert Table Process...'); 
end if;

--Query
DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN Query Table Process...'); 
	SELECT COUNT (1)
	INTO nu_cnt
	FROM fet1_transaction_log_mpbl
	WHERE bill_seq = nu_bill_seq;
 DBMS_OUTPUT.Put_Line('NU_CNT='||NU_CNT);
DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END Query Table Process...'); 

   --IF NU_CNT!=0 THEN
   --   DBMS_OUTPUT.Put_Line('Create_AR_Table Process RETURN_CODE = 0000'||NULL);
   --ELSE
   --   DBMS_OUTPUT.Put_Line('Create_AR_Table Process RETURN_CODE = 9999'||' Warning... ROW_CNT = '||TO_CHAR(NU_CNT)); 
   --END IF;                                                                               
EXCEPTION 
   WHEN OTHERS THEN
      DBMS_OUTPUT.Put_Line('Create_AR_Table Process RETURN_CODE = 9999');
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||SUBSTR(' END Check DataSync Process... '||SQLERRM,1,250)); 
end;
/
