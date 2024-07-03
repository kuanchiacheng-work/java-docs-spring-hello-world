--########################################################################################
--# Program name : HGB_MPBL_CutDate_RollBack.sh
--# SQL name : HGB_MPBL_CutDate_RollBack.sql
--# Path : /extsoft/MPBL/BL/CutDate/bin
--#
--# Date : 2020/04/22 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB only for test env
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off
declare 
v_USER                VARCHAR2(8)  := 'MPBL';
v_OLD_BILL_SEQ        NUMBER(6)    := '&1';
v_NEW_BILL_SEQ        NUMBER(6);
nu_CYCLE              NUMBER(2);
nu_OLD_BILL_PERIOD    VARCHAR2(6);
nu_NEW_BILL_PERIOD    VARCHAR2(6);
CH_ERR_CDE            VARCHAR2(10);
CH_ERR_MSG            VARCHAR2(300);
--檢查OC數量
CURSOR C1(v_OLD_BILL_SEQ number) IS
	SELECT COUNT (1) cnt
		FROM fy_tb_bl_bill_ci a
	WHERE a.bill_seq = v_OLD_BILL_SEQ
	AND a.SOURCE = 'OC'
	AND EXISTS (
			SELECT 1
				FROM fy_tb_bl_bill_acct b
			WHERE a.acct_id = b.acct_id
				AND b.bill_status = 'CL'
				AND a.bill_seq = b.bill_seq);
				
--檢查ACCT數量
CURSOR C2(v_OLD_BILL_SEQ number) IS
      SELECT count(1) cnt FROM fy_tb_bl_bill_acct
      WHERE bill_seq = v_OLD_BILL_SEQ AND bill_status = 'CL';
	  
begin
--查詢CYCLE與新舊BILL_PERIOD
	SELECT a.CYCLE, a.currect_period new_bill_period, b.bill_period old_bill_period
		INTO nu_cycle, nu_new_bill_period, nu_old_bill_period
	FROM fy_tb_bl_cycle a, fy_tb_bl_bill_cntrl b
	WHERE b.bill_seq = v_OLD_BILL_SEQ
	AND b.CYCLE = a.CYCLE
	AND b.bill_period =
			TO_CHAR (ADD_MONTHS (TO_DATE (a.currect_period, 'YYYYMM'), -1),
					'YYYYMM'
					);
	DBMS_OUTPUT.Put_Line('CYCLE:'||nu_CYCLE||' OLD_BILL_SEQ:'||v_OLD_BILL_SEQ||' NEW_BILL_PERIOD:'||nu_NEW_BILL_PERIOD||' OLD_BILL_PERIOD:'||nu_OLD_BILL_PERIOD);

--還原FY_TB_BL_CYCLE.CURRECT_PERIOD至前月BILL_PERIOD
if nu_CYCLE is not null then	
	--刪除CUTDATE相關TABLE資料
	FOR R2 IN C2(v_OLD_BILL_SEQ) LOOP
		DBMS_OUTPUT.Put_Line('FY_TB_BL_BILL_ACCT.BILL_SEQ='||v_OLD_BILL_SEQ||', Cnt='||to_char(r2.cnt));
			if r2.cnt > 0 then
				--將ACCOUNT狀態為CL的FY_TB_BL_BILL_CI.BILL_SEQ清空為NULL
				FOR R1 IN C1(v_OLD_BILL_SEQ) LOOP
					DBMS_OUTPUT.Put_Line('FY_TB_BL_BILL_CI.BILL_SEQ='||v_OLD_BILL_SEQ||', Cnt='||to_char(r1.cnt));  
						if r1.cnt > 0 then
							DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' UPDATE FY_TB_BL_BILL_CI.BILL_SEQ BEGIN');
								UPDATE fy_tb_bl_bill_ci a
									SET a.bill_seq = NULL
								WHERE a.bill_seq = v_OLD_BILL_SEQ
								AND a.source = 'OC'
								AND EXISTS (
										SELECT 1
											FROM fy_tb_bl_bill_acct b
										WHERE a.acct_id = b.acct_id
											AND b.bill_status = 'CL'
											AND a.bill_seq = b.bill_seq);
							DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' UPDATE FY_TB_BL_BILL_CI.BILL_SEQ END');	
						else
							DBMS_OUTPUT.Put_Line('FY_TB_BL_BILL_CI no data');
						end if;	
				END LOOP;

			--PARAM
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE OLD FY_TB_BL_BILL_OFFER_PARAM BEGIN');
					DELETE fy_tb_bl_bill_offer_param a
						WHERE bill_seq = v_OLD_BILL_SEQ
							AND NOT EXISTS (
								SELECT 1
									FROM fy_tb_bl_bill_acct b
									WHERE a.acct_id = b.acct_id
									AND b.bill_status = 'CN'
									AND a.bill_seq = b.bill_seq);
					UPDATE fy_tb_bl_bill_offer_param a SET bill_seq = '9527'||v_OLD_BILL_SEQ
						WHERE bill_seq = v_OLD_BILL_SEQ
							AND EXISTS (
								SELECT 1
									FROM fy_tb_bl_bill_acct b
									WHERE a.acct_id = b.acct_id
									AND b.bill_status = 'CN'
									AND a.bill_seq = b.bill_seq);
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE OLD FY_TB_BL_BILL_OFFER_PARAM END');
			
			--SUB
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE OLD FY_TB_BL_BILL_SUB BEGIN');
					DELETE fy_tb_bl_bill_sub a
						WHERE bill_seq = v_OLD_BILL_SEQ
							AND NOT EXISTS (
								SELECT 1
									FROM fy_tb_bl_bill_acct b
									WHERE a.acct_id = b.acct_id
									AND b.bill_status = 'CN'
									AND a.bill_seq = b.bill_seq);
					UPDATE fy_tb_bl_bill_sub a SET bill_seq = '9527'||v_OLD_BILL_SEQ
						WHERE bill_seq = v_OLD_BILL_SEQ
							AND NOT EXISTS (
								SELECT 1
									FROM fy_tb_bl_bill_acct b
									WHERE a.acct_id = b.acct_id
									AND b.bill_status = 'CN'
									AND a.bill_seq = b.bill_seq);
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE OLD FY_TB_BL_BILL_SUB END');
	
			--ACCT_MPBL
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE OLD FY_TB_BL_BILL_ACCT_MPBL BEGIN');
					DELETE fy_tb_bl_bill_acct_mpbl a
						WHERE bill_seq = v_old_bill_seq
							AND NOT EXISTS (SELECT 1
										FROM fy_tb_bl_bill_acct b
										WHERE a.bill_seq = b.bill_seq AND b.bill_status = 'CN');
					UPDATE fy_tb_bl_bill_acct_mpbl a SET bill_seq = '9527'||v_OLD_BILL_SEQ
						WHERE bill_seq = v_old_bill_seq
							AND NOT EXISTS (SELECT 1
										FROM fy_tb_bl_bill_acct b
										WHERE a.bill_seq = b.bill_seq AND b.bill_status = 'CN');
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE OLD FY_TB_BL_BILL_ACCT_MPBL END');
				
			--ACCT
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE OLD FY_TB_BL_BILL_ACCT BEGIN');
					DELETE fy_tb_bl_bill_acct
						WHERE bill_seq = v_OLD_BILL_SEQ AND bill_status = 'CL';
					DELETE fy_tb_bl_bill_acct
						WHERE bill_seq = '9527'||v_OLD_BILL_SEQ AND bill_status = 'CN';
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE OLD FY_TB_BL_BILL_ACCT END');
						
			--Process_Log
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE OLD FY_TB_BL_BILL_PROCESS_LOG BEGIN');
					DELETE fy_tb_bl_bill_process_log WHERE bill_seq = v_old_bill_seq;
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE OLD FY_TB_BL_BILL_PROCESS_LOG END');
					
			--CNTRL
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' UPDATE OLD FY_TB_BL_BILL_CNTRL.ACCT_COUNT BEGIN');
					DELETE fy_tb_bl_bill_cntrl WHERE cycle = nu_cycle AND bill_seq = v_OLD_BILL_SEQ;
                    --UPDATE fy_tb_bl_bill_cntrl a
                    --    SET bill_seq = '9527'||v_OLD_BILL_SEQ, status = 'CN',
                    --    acct_count = (SELECT COUNT (acct_id)
                    --                    FROM fy_tb_bl_bill_acct b
                    --                    WHERE b.bill_status = 'CN' AND b.bill_seq = v_OLD_BILL_SEQ)
                    --WHERE bill_seq = v_OLD_BILL_SEQ;
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' UPDATE OLD FY_TB_BL_BILL_CNTRL.ACCT_COUNT END');

			--CYCLE
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' UPDATE FY_TB_BL_CYCLE.CURRECT_PERIOD BEGIN');
					UPDATE fy_tb_bl_cycle
						SET currect_period = nu_old_bill_period, lbc_date = add_months(lbc_date,-1)
					WHERE CYCLE = nu_cycle AND currect_period = nu_new_bill_period;
				DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' UPDATE FY_TB_BL_CYCLE.CURRECT_PERIOD END');
				DBMS_OUTPUT.Put_Line('CYCLE:'||nu_CYCLE||' UPDATE BILL_PERIOD FROM '||nu_NEW_BILL_PERIOD||' TO '||nu_OLD_BILL_PERIOD);
			commit;

			--執行CUTDATE
				FY_PG_BL_BILL_CUTDATE.MAIN(nu_CYCLE, nu_old_bill_period, v_USER, CH_ERR_CDE, CH_ERR_MSG);
					if ch_err_cde='0000' then
						DBMS_OUTPUT.Put_Line('CutDate Process RETURN_CODE = 0000');
						
						--查詢新BILL_SEQ
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' SELECT FY_TB_BL_BILL_CI.BILL_SEQ BEGIN');
						SELECT b.bill_seq
							INTO v_NEW_BILL_SEQ
						FROM fy_tb_bl_bill_cntrl b, fy_tb_bl_cycle a
						WHERE b.CYCLE = nu_CYCLE
						AND b.CYCLE = a.CYCLE
						AND b.CREATE_USER = v_USER
						AND b.bill_period =
											TO_CHAR (ADD_MONTHS (TO_DATE (a.currect_period, 'YYYYMM'),
																-1
																),
													'YYYYMM'
													);
						DBMS_OUTPUT.Put_Line('CYCLE:'||nu_CYCLE||' NEW_BILL_SEQ:'||v_NEW_BILL_SEQ);
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' SELECT FY_TB_BL_BILL_CI.BILL_SEQ END');
					
						--ACCT_MPBL
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE NEW FY_TB_BL_BILL_ACCT_MPBL BEGIN');
							DELETE fy_tb_bl_bill_acct_mpbl a
								WHERE bill_seq = v_NEW_BILL_SEQ
									AND EXISTS (
										SELECT 1
											FROM fy_tb_bl_bill_acct b
											WHERE a.acct_id = b.acct_id
											AND b.bill_status = 'CN'
											AND b.bill_seq = '9527'||v_OLD_BILL_SEQ
																);
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE NEW FY_TB_BL_BILL_ACCT_MPBL END');
				
						--ACCT
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE NEW FY_TB_BL_BILL_ACCT BEGIN');
							DELETE fy_tb_bl_bill_acct a
								WHERE bill_seq = v_NEW_BILL_SEQ
									AND EXISTS (
										SELECT 1
											FROM fy_tb_bl_bill_acct b
											WHERE a.acct_id = b.acct_id
											AND b.bill_status = 'CN'
											AND b.bill_seq = '9527'||v_OLD_BILL_SEQ
																);
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE NEW FY_TB_BL_BILL_ACCT END');
			
						--SUB
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE NEW FY_TB_BL_BILL_SUB BEGIN');
							DELETE fy_tb_bl_bill_sub a
								WHERE bill_seq = v_NEW_BILL_SEQ
									AND EXISTS (
										SELECT 1
											FROM fy_tb_bl_bill_acct b
											WHERE a.acct_id = b.acct_id
											AND b.bill_status = 'CN'
											AND b.bill_seq = '9527'||v_OLD_BILL_SEQ
																);
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE NEW FY_TB_BL_BILL_SUB END');
						
						--PARAM
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE NEW FY_TB_BL_BILL_OFFER_PARAM BEGIN');
							DELETE fy_tb_bl_bill_offer_param a
								WHERE bill_seq = v_NEW_BILL_SEQ
									AND EXISTS (
										SELECT 1
											FROM fy_tb_bl_bill_acct b
											WHERE a.acct_id = b.acct_id
											AND b.bill_status = 'CN'
											AND b.bill_seq = '9527'||v_OLD_BILL_SEQ
																);
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' DELETE NEW FY_TB_BL_BILL_OFFER_PARAM END');
						--CNTRL
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' UPDATE NEW FY_TB_BL_BILL_CNTRL.ACCT_COUNT BEGIN');
							UPDATE fy_tb_bl_bill_cntrl a
								SET acct_count = (SELECT COUNT (acct_id)
												FROM fy_tb_bl_bill_acct b
												WHERE b.bill_seq = v_NEW_BILL_SEQ
																	)
							WHERE bill_seq = v_NEW_BILL_SEQ;
						DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' UPDATE NEW FY_TB_BL_BILL_CNTRL.ACCT_COUNT END');
						commit;
						DBMS_OUTPUT.Put_Line('CutDate RollBack Process RETURN_CODE = 0000');
					else        
						DBMS_OUTPUT.Put_Line('CutDate Process RETURN_CODE = 9999'); 
					end if;     
			else
				DBMS_OUTPUT.Put_Line('FY_TB_BL_BILL_ACCT無ACCT資料需處理');
			end if;
	END LOOP;
else
	DBMS_OUTPUT.Put_Line('找不到FY_TB_BL_CYCLE資訊');
end if;

EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('CutDate RollBack Process RETURN_CODE = 9999'); 
end;
/

exit;
