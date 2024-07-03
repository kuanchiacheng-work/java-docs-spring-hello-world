--########################################################################################
--# Program name : HGB_MPBL_Confirm.sh
--# SQL name : HGB_MPBL_Confirm_Patch_Change_Cycle.sql
--# Path : /extsoft/MPBL/BL/CutDate/bin
--#
--# Date : 2021/01/19 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB_Patch_Change_Cycle
--########################################################################################
--# Date : 2021/02/23 Created by Mike Kuan
--# Description : 修正有出帳CUST中含有不需出帳的ACCT無法被正常更新CYCLE的問題
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off
declare 
   v_BILL_DATE       VARCHAR2(8)  := '&1'; 
   v_CYCLE           NUMBER(2)    := '&2'; 
   CH_STATUS         VARCHAR2(6);
   CH_USER           VARCHAR2(8)  := 'MPBL';
   NU_CNT            NUMBER;
   ERR_CNT           NUMBER       := 0;
   On_ERR            EXCEPTION;
CURSOR c1 IS
    SELECT CUST_ID
      FROM fy_tb_bl_change_cycle a
     WHERE future_eff_date = TO_DATE (v_BILL_DATE, 'yyyymmdd')
       AND old_cycle = v_CYCLE
       AND tran_id =
            (SELECT MAX (tran_id)
                FROM fy_tb_bl_change_cycle
                WHERE cust_id = a.cust_id AND future_eff_date = a.future_eff_date);
                
begin
	DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN Patch Change Cycle Process...'); 
	DBMS_OUTPUT.Put_Line('CYCLE='||v_CYCLE||', BILL_DATE='||v_BILL_DATE);
	--查詢出帳狀態 (需為CN才可繼續)
    SELECT status
      INTO CH_STATUS
      FROM fy_tb_bl_bill_cntrl
     WHERE bill_date = TO_DATE (v_BILL_DATE, 'yyyymmdd')
       AND CYCLE = v_CYCLE
       AND create_user = CH_USER;
	DBMS_OUTPUT.Put_Line('CH_STATUS='||CH_STATUS);

	--確認BL fy_tb_bl_change_cycle send_flag筆數
    SELECT COUNT (1)
	  INTO nu_cnt
      FROM fy_tb_bl_change_cycle a
     WHERE old_cycle = v_CYCLE
       AND future_eff_date = TO_DATE (v_BILL_DATE, 'yyyymmdd')
       AND tran_id =
              (SELECT MAX (tran_id)
                 FROM fy_tb_bl_change_cycle
                WHERE cust_id = a.cust_id AND future_eff_date = a.future_eff_date);
	DBMS_OUTPUT.Put_Line('NULL SEND_FLAG COUNT='||TO_CHAR(NU_CNT));
	
	IF CH_STATUS='CN' AND NU_CNT>0 THEN
		for R1 in c1 loop
			begin
				DBMS_OUTPUT.Put_Line('CUST_ID='||TO_CHAR(R1.CUST_ID));
				--確認CUSTOMER啟用早於出帳日
				SELECT COUNT (1)
				  INTO nu_cnt
				  FROM fy_Tb_cm_customer
				 WHERE cust_id = R1.CUST_ID
				   --AND CYCLE = v_CYCLE
				   AND eff_date < TO_DATE (v_BILL_DATE, 'yyyymmdd');
				IF NU_CNT=0 THEN
					RAISE ON_ERR;
				ELSE
					--寫入CM fy_tb_cm_sync_send_pub
					INSERT INTO fy_tb_cm_sync_send_pub
								(trx_id, svc_code, actv_code, entity_type, entity_id, sync_mesg,
								create_date, create_user, update_date, update_user, route_id)
					SELECT fy_sq_cm_trx.NEXTVAL, '9926', 'BLCHANGECYCLECONF', 'C', cust_id,
							remark, SYSDATE, 'MPBL_PATCH', SYSDATE, 'MPBL_PATCH', cust_id
						FROM fy_tb_bl_change_cycle a
						WHERE send_flag IS NULL
						  AND old_cycle = v_CYCLE
						  AND future_eff_date = TO_DATE (v_BILL_DATE, 'yyyymmdd')
						  AND cust_id = R1.CUST_ID
						  AND tran_id =
								(SELECT MAX (tran_id)
									FROM fy_tb_bl_change_cycle
								WHERE cust_id = a.cust_id
									AND future_eff_date = a.future_eff_date);
					DBMS_OUTPUT.Put_Line('INSERT fy_tb_cm_sync_send_pub, CUST_ID='||TO_CHAR(R1.CUST_ID));
					
                    --更新BL fy_tb_bl_account
                    UPDATE fy_tb_bl_account a
                       SET CYCLE =
                              (SELECT new_cycle
                                 FROM fy_tb_bl_change_cycle a
                                WHERE old_cycle = v_CYCLE
                                  AND future_eff_date = TO_DATE (v_BILL_DATE, 'yyyymmdd')
                                  AND cust_id = R1.CUST_ID
                                  AND tran_id =
                                         (SELECT MAX (tran_id)
                                            FROM fy_tb_bl_change_cycle
                                           WHERE cust_id = a.cust_id
                                             AND future_eff_date = a.future_eff_date)),
                           update_date = SYSDATE,
                           update_user = 'MPBL_PATCH'
                     WHERE bl_status = 'OPEN'
                       AND CYCLE = v_CYCLE
                       AND EXISTS (SELECT 1
                                     FROM fy_tb_cm_account b
                                    WHERE b.cust_id = R1.CUST_ID AND a.acct_id = b.acct_id);
					DBMS_OUTPUT.Put_Line('UPDATE fy_tb_bl_account, CUST_ID='||TO_CHAR(R1.CUST_ID));
					
					--更新BL fy_tb_bl_change_cycle
					UPDATE fy_tb_bl_change_cycle a
						SET send_flag = 'Y',
							update_date = SYSDATE,
							update_user = 'MPBL_PATCH'
						WHERE send_flag IS NULL
	                      AND old_cycle = v_CYCLE
                          AND future_eff_date = TO_DATE (v_BILL_DATE, 'yyyymmdd')
                          AND cust_id = R1.CUST_ID
                          AND tran_id =
                                (SELECT MAX (tran_id)
                                    FROM fy_tb_bl_change_cycle
                                    WHERE cust_id = a.cust_id AND future_eff_date = a.future_eff_date);
					DBMS_OUTPUT.Put_Line('UPDATE fy_tb_bl_change_cycle, CUST_ID='||TO_CHAR(R1.CUST_ID));									
                END IF;

            EXCEPTION
                WHEN ON_ERR THEN
                    ERR_CNT := ERR_CNT+1;
                WHEN OTHERS THEN
                    ERR_CNT := ERR_CNT+1;
            END;
        END LOOP;

		--確認BL fy_tb_bl_change_cycle send_flag筆數
        SELECT COUNT (1)
		  INTO nu_cnt
          FROM fy_tb_bl_change_cycle a
         WHERE send_flag IS NULL
           AND old_cycle = v_CYCLE
           AND future_eff_date = TO_DATE (v_BILL_DATE, 'yyyymmdd')
           AND tran_id =
                  (SELECT MAX (tran_id)
                     FROM fy_tb_bl_change_cycle
                    WHERE cust_id = a.cust_id AND future_eff_date = a.future_eff_date);

        DBMS_OUTPUT.Put_Line('ERR_CNT='||TO_CHAR(ERR_CNT)||', NULL SEND_FLAG COUNT='||TO_CHAR(NU_CNT));
        IF ERR_CNT>0 OR NU_CNT>0 THEN
            ROLLBACK;
            DBMS_OUTPUT.Put_Line('Confirm_Patch_Change_Cycle Process RETURN_CODE = 9999');
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END Patch Change Cycle Process...');
        ELSE
            COMMIT;
            DBMS_OUTPUT.Put_Line('fy_tb_bl_change_cycle null send_flag count='||TO_CHAR(NU_CNT));
            DBMS_OUTPUT.Put_Line('Confirm_Patch_Change_Cycle Process RETURN_CODE = 0000');
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END Patch Change Cycle Process...');
        END IF;
        
    ELSE
        DBMS_OUTPUT.Put_Line('CYCLE NOT FINISHED YET or NO DATA NEED TO PROCESS');
        DBMS_OUTPUT.Put_Line('Confirm_Patch_Change_Cycle Process RETURN_CODE = 0000');
        DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END Patch Change Cycle Process...');
    END IF;

EXCEPTION 
   WHEN OTHERS THEN
      DBMS_OUTPUT.Put_Line('Confirm_Patch_Change_Cycle Process RETURN_CODE = 9999');
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||SUBSTR(' END Patch Change Cycle Process... '||SQLERRM,1,250));         
end;
/
exit
