--########################################################################################
--# Program name : HGB_MPBL_Undo.sh
--# Path : /extsoft/MPBL/BL/Undo/bin
--# SQL name : HGB_MPBL_Undo_Pre.sql
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################
--# Date : 2021/09/02 Created by Mike Kuan
--# Description : SR233414_行動裝置險月繳保費預繳專案
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off
declare 
v_BILL_DATE       VARCHAR2(8)  := '&1';
v_CYCLE           NUMBER(2)    := '&2';
v_PROCESS_NO      NUMBER(3)    := '&3';
v_USER            VARCHAR2(8)  := 'MPBL';
CH_BILL_DAY       VARCHAR2(2);
CH_HOLD_TABLE     VARCHAR2(30);
v_SQL             VARCHAR2(3000);
NU_CYCLE_MONTH    NUMBER(2);
NU_BILL_SEQ       NUMBER;
CH_ERR_CDE        VARCHAR2(10);
CH_ERR_MSG        VARCHAR2(300);
On_Err            EXCEPTION;

  CURSOR C1(ibill_seq number) IS
     select '999: '||count(1) cnt
           from fy_tb_bl_acct_list
          where bill_seq=ibill_seq
          AND CYCLE   =v_CYCLE
          AND TYPE='HOLD'
          AND v_PROCESS_NO=999
    UNION
      SELECT '001: '||COUNT(1) cnt
        FROM FY_TB_BL_BILL_ACCT
       WHERE bill_seq=ibill_seq
         AND ACCT_GROUP='G001'
         AND v_PROCESS_NO<>999
    UNION
      SELECT '888: '||COUNT(1) cnt
        FROM FY_TB_BL_BILL_ACCT
       WHERE bill_seq=ibill_seq
         AND ACCT_GROUP='MV'
         AND v_PROCESS_NO<>999;
          
begin 
   CH_ERR_MSG := 'GET BILL_CNTRL:';
   
   SELECT A.BILL_SEQ, A.CYCLE_MONTH, substr(to_char(A.BILL_DATE,'yyyymmdd'),7,8) BILL_DAY
     INTO NU_BILL_SEQ, NU_CYCLE_MONTH, CH_BILL_DAY
     FROM FY_TB_BL_BILL_CNTRL A,
          FY_TB_BL_CYCLE_PROCESS B
    WHERE TO_CHAR(A.BILL_DATE,'YYYYMMDD')=v_BILL_DATE
      AND A.CREATE_USER=v_USER
      --AND A.CREATE_USER=B.CREATE_USER
      AND A.CYCLE=v_CYCLE
      AND B.CYCLE=A.CYCLE
      AND B.PROCESS_NO=v_PROCESS_NO;

   DBMS_OUTPUT.Put_Line('BILL_SEQ = '||NU_BILL_SEQ||' , CYCLE_MONTH = '||NU_CYCLE_MONTH||' , BILL_DAY = '||CH_BILL_DAY);

CH_HOLD_TABLE:='M'||CH_BILL_DAY||'_HOLD_LIST@prdappc.prdcm';
   DBMS_OUTPUT.Put_Line('OCS HOLD TABLE = '||CH_HOLD_TABLE);
   
--dynamic SQL insert HGB_MPBL acct_list from OCS hold_list
   DBMS_OUTPUT.Put_Line('start insert into fy_tb_bl_acct_list');
   v_SQL:='INSERT INTO fy_tb_bl_acct_list '
                      ||'(bill_seq, '
                      ||' acct_id, '
                      ||' bill_start_period, ' 
                      ||' bill_end_period, '
                      ||' bill_end_date, '
                      ||' type, '
                      ||' hold_desc, '
                      ||' uc_flag, '
                      ||' create_date, '
                      ||' create_user, '
                      ||' update_date, '
                      ||' update_user, '
                      ||' cycle_month, '
                      ||' cycle, '
                      ||' cust_id) '
             ||' SELECT distinct a.bill_seq,' 
                    ||'b.acct_id, '
                    ||'a.bill_period, '
                    ||'a.bill_period, '
                    ||'a.bill_end_date, '
                    ||'''HOLD'', '
                    ||'''OCS'', '
                    ||'''Y'', '
                    ||'TO_DATE('''||TO_CHAR(SYSDATE,'YYYYMMDD')||''',''YYYYMMDD'')' ||',' 
                    ||'''MPBL'', '
                    ||'TO_DATE('''||TO_CHAR(SYSDATE,'YYYYMMDD')||''',''YYYYMMDD'')' ||',' 
                    ||'''MPBL'', ' 
                    ||'a.cycle_month, '
                    ||'a.CYCLE, '
                    ||'b.cust_id '
              ||' FROM fy_tb_bl_bill_cntrl a, '
              ||' fy_tb_bl_bill_acct b, '
              ||CH_HOLD_TABLE||' c '
            || ' WHERE a.bill_seq = '||NU_BILL_SEQ
            || '   and a.bill_seq = b.bill_seq '
            || '   and a.bill_seq = c.cycle_seq_no '			
            || '   and b.acct_id = c.account_no '
            || '   AND b.bill_status != ''CN'''
            || '   AND NOT EXISTS (SELECT 1'
            ||' FROM fy_tb_bl_acct_list d '
            ||' WHERE d.bill_seq = b.bill_seq '
            ||' AND d.acct_id = b.acct_id) ';
   --DBMS_OUTPUT.Put_Line(v_SQL);
execute immediate v_SQL;
   DBMS_OUTPUT.Put_Line('end insert into fy_tb_bl_acct_list');
commit;

FOR R1 IN C1(nu_bill_seq) LOOP
   DBMS_OUTPUT.Put_Line('ACCT_LIST HOLD Acct Cnt='||to_char(r1.cnt));
   DBMS_OUTPUT.Put_Line('Undo_Pre Process RETURN_CODE = 0000'); 
end loop; 

EXCEPTION 
   WHEN OTHERS THEN
   DBMS_OUTPUT.Put_Line('Undo_Pre Process RETURN_CODE = 9999'); 
end;
/

exit;
