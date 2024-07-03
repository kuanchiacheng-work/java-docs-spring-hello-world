--########################################################################################
--# Program name : HGB_MPBL_CutDate.sh
--# SQL name : HGB_MPBL_CutDate_Fix_Change_Cycle.sql
--# Path : /extsoft/MPBL/BL/CutDate/bin
--#
--# Date : 2020/11/19 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB_Fix_Change_Cycle時間差
--########################################################################################
--# Date : 2023/04/17 Modify by Mike Kuan
--# Description : SR260229_Project-M Fixed line Phase I_新增CUST_TYPE='P'
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare 
   v_CYCLE              NUMBER(2)    := '&1';
   CH_BILL_DATE         VARCHAR2(8);
   CH_NEXT_BILL_DATE    VARCHAR2(8);
   NU_CNT               NUMBER;
   NU_OLD_CNT           NUMBER;
   NU_NEW_CNT           NUMBER;
   CH_USER              VARCHAR2(8)  := 'MPBL';
   CH_ERR_MSG           VARCHAR2(300);
   ON_ERR               EXCEPTION;
   
   CURSOR c1(iBILL_DATE VARCHAR2, iNEXT_BILL_DATE VARCHAR2) IS
    SELECT b.cust_id
      FROM fy_tb_cm_customer a, fy_tb_bl_change_cycle b
     WHERE a.CYCLE = b.old_cycle
       AND a.new_cycle = b.new_cycle
       AND a.CYCLE = v_CYCLE
       AND a.cust_id = b.cust_id
       AND a.new_cycle IS NOT NULL
       AND a.cust_type NOT IN ('N', 'D', 'P') --SR260229_Project-M Fixed line Phase I_新增CUST_TYPE='P'
       AND TRUNC (a.update_cycle_date) >= to_date(iBILL_DATE,'yyyymmdd')
	   AND TRUNC (a.update_cycle_date) < to_date(iNEXT_BILL_DATE,'yyyymmdd')
       AND TRUNC (b.future_eff_date) = to_date(iBILL_DATE,'yyyymmdd');
  
BEGIN
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN Fix_Change_Cycle Process...'); 
   CH_ERR_MSG := 'GET CYCLE='||v_CYCLE||':';
   SELECT to_char(add_months(LBC_DATE+1,1),'yyyymmdd') BILL_DATE, to_char(add_months(LBC_DATE+1,2),'yyyymmdd') NEXT_BILL_DATE
     INTO CH_BILL_DATE, CH_NEXT_BILL_DATE
     FROM FY_TB_BL_CYCLE
    WHERE currect_period IS NOT NULL
      AND cycle = v_CYCLE
      AND CREATE_USER = CH_USER;

	FOR R1 IN C1(CH_BILL_DATE, CH_NEXT_BILL_DATE) LOOP
		BEGIN
	    DBMS_OUTPUT.Put_Line('BILL_DATE='||to_date(CH_BILL_DATE,'yyyy/mm/dd')||'; NEXT_BILL_DATE='||to_date(CH_NEXT_BILL_DATE,'yyyy/mm/dd')||'; CYCLE='||v_CYCLE||'; CUST_ID='||R1.CUST_ID);
            CH_ERR_MSG := 'COUNTING FY_TB_BL_CUST_CYCLE.OLD_CYCLE';
            SELECT COUNT(1)
              INTO NU_OLD_CNT
              FROM fy_tb_bl_cust_cycle
             WHERE cust_id = R1.CUST_ID
               AND CYCLE = v_CYCLE
               AND end_date = TO_DATE (CH_BILL_DATE, 'yyyymmdd');
            CH_ERR_MSG := 'COUNTING FY_TB_BL_CUST_CYCLE.NEW_CYCLE';
            SELECT COUNT(1)
              INTO NU_NEW_CNT
              FROM fy_tb_bl_cust_cycle
             WHERE cust_id = R1.CUST_ID
               AND CYCLE != v_CYCLE
               AND eff_date = TO_DATE (CH_BILL_DATE, 'yyyymmdd');
               
            IF NU_OLD_CNT!=1 OR NU_NEW_CNT!=1 THEN
                RAISE ON_ERR;
            ELSE
                CH_ERR_MSG := 'UPDATE FY_TB_BL_CUST_CYCLE.OLD_CYCLE';
                UPDATE fy_tb_bl_cust_cycle
                   SET end_date = TO_DATE (CH_NEXT_BILL_DATE, 'yyyymmdd')
                 WHERE cust_id = R1.CUST_ID
                   AND CYCLE = v_CYCLE
                   AND end_date = TO_DATE (CH_BILL_DATE, 'yyyymmdd');
                CH_ERR_MSG := 'UPDATE FY_TB_BL_CUST_CYCLE.NEW_CYCLE';
                UPDATE fy_tb_bl_cust_cycle
                   SET eff_date = TO_DATE (CH_NEXT_BILL_DATE, 'yyyymmdd')
                 WHERE cust_id = R1.CUST_ID
                   AND CYCLE != v_CYCLE
                   AND eff_date = TO_DATE (CH_BILL_DATE, 'yyyymmdd');
                CH_ERR_MSG := 'UPDATE FY_TB_BL_CHANGE_CYCLE';   
                UPDATE fy_tb_bl_change_cycle
                   SET future_eff_date = TO_DATE (CH_NEXT_BILL_DATE, 'yyyymmdd')
                 WHERE cust_id = R1.CUST_ID
                   AND old_cycle = v_CYCLE
                   AND new_cycle IS NOT NULL
                   AND future_eff_date = TO_DATE (CH_BILL_DATE, 'yyyymmdd');
               
                DBMS_OUTPUT.Put_Line('CUST_ID='||R1.CUST_ID||'; DONE');
            END IF;
            
            EXCEPTION
                WHEN ON_ERR THEN
                    DBMS_OUTPUT.Put_Line('CUST_ID='||R1.CUST_ID||'; ERR_MSG='||CH_ERR_MSG);
                    DBMS_OUTPUT.Put_Line('CutDate_Fix_Change_Cycle Process RETURN_CODE = 9999');
                WHEN OTHERS THEN
                    DBMS_OUTPUT.Put_Line('CutDate_Fix_Change_Cycle Process RETURN_CODE = 9999');
        END;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END Fix_Change_Cycle Process...');  
    DBMS_OUTPUT.Put_Line('CutDate_Fix_Change_Cycle Process RETURN_CODE = 0000');    

EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('CutDate_Fix_Change_Cycle Process RETURN_CODE = 9999'); 
END;
/

exit;
