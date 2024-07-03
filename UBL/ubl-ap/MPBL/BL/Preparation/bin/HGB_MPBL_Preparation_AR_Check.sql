--########################################################################################
--# Program name : HGB_UBL_Preparation.sh
--# Path : /extsoft/UBL/BL/Preparation/bin
--# SQL name : HGB_UBL_Preparation_AR_Check.sql
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################
--# Date : 2021/03/04 Modify by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB add DBMS_OUTPUT NU_CNT_VALUE
--########################################################################################
--# Date : 2021/09/02 Created by Mike Kuan
--# Description : SR233414_行動裝置險月繳保費預繳專案
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
  CH_STATUS        FY_TB_DIO_CNTRL.STATUS%TYPE;
  CH_IO_TYPE       FY_TB_DIO_CNTRL.IO_TYPE%TYPE;
  NU_CNT           NUMBER;
  NU_CNT_CHECK     NUMBER; 
  NU_CNT_VALUE     NUMBER; 
  On_Err           EXCEPTION;
CURSOR C1 IS
SELECT   status, b.COUNT p_count, c.COUNT c_count, d.COUNT d_count
    FROM fy_tb_dio_cntrl a,
         (SELECT COUNT (proc_id) COUNT
            FROM fy_tb_dio_cntrl a
           WHERE bill_seq = nu_bill_seq
             AND process_no = v_process_no
             AND acct_group = ch_acct_group
             AND proc_type = v_proc_type
             AND proc_id = 'BALANCE'
             AND confirm_id =
                    (SELECT MAX (confirm_id)
                       FROM fy_tb_dio_cntrl
                      WHERE bill_seq = a.bill_seq
                        AND process_no = a.process_no
                        AND acct_group = a.acct_group
                        AND proc_type = a.proc_type
                        AND proc_id = 'MPACCTLIST')) b,
         (SELECT COUNT (status) COUNT
            FROM fy_tb_dio_cntrl a
           WHERE bill_seq = nu_bill_seq
             AND process_no = v_process_no
             AND acct_group = ch_acct_group
             AND proc_type = v_proc_type
             AND proc_id = 'BALANCE'
             AND status = 'S'
             AND confirm_id =
                    (SELECT MAX (confirm_id)
                       FROM fy_tb_dio_cntrl
                      WHERE bill_seq = a.bill_seq
                        AND process_no = a.process_no
                        AND acct_group = a.acct_group
                        AND proc_type = a.proc_type
                        AND proc_id = 'MPACCTLIST')) c,(SELECT LAST_GRP_ID*2 COUNT
            FROM fy_tb_dio_cntrl a
           WHERE bill_seq = nu_bill_seq
             AND process_no = v_process_no
             AND acct_group = ch_acct_group
             AND proc_type = v_proc_type
             AND proc_id = 'MPACCTLIST'
             AND status = 'S'
             AND confirm_id =(SELECT MAX (confirm_id)
                FROM fy_Tb_dio_cntrl
                WHERE bill_seq = a.bill_seq
                AND process_no = a.process_no
                AND acct_group = a.acct_group
                AND proc_type  = a.proc_type 
                AND proc_id='MPACCTLIST')) d
   WHERE bill_seq = nu_bill_seq
     AND process_no = v_process_no
     AND acct_group = ch_acct_group
     AND proc_type = v_proc_type
     AND proc_id = 'BALANCE'
     AND confirm_id =
            (SELECT MAX (confirm_id)
               FROM fy_tb_dio_cntrl
              WHERE bill_seq = a.bill_seq
                AND process_no = a.process_no
                AND acct_group = a.acct_group
                AND proc_type = a.proc_type
                AND proc_id = 'MPACCTLIST')
ORDER BY DECODE (status, 'E', 1, 'A', 2, 'S', 3, 4);

begin
SELECT bill_seq,
       (CASE
           WHEN v_process_no <> 999
              THEN (SELECT acct_group
                      FROM fy_tb_bl_cycle_process
                     WHERE CYCLE = v_cycle AND process_no = v_process_no)
           ELSE (SELECT DECODE (v_proc_type, 'B', 'HOLD', 'QA')
                   FROM DUAL)
        END
       ) acct_group
  INTO nu_bill_seq,
       ch_acct_group
  FROM fy_tb_bl_bill_cntrl a
 WHERE a.bill_date = TO_DATE (v_bill_date, 'yyyymmdd')
   AND a.CYCLE = v_cycle
   AND a.create_user = ch_user;

CH_STATUS :='Y';
FOR R1 IN C1 LOOP
    IF R1.STATUS='E' THEN
        DBMS_OUTPUT.Put_Line('Preparation_AR_Check Process RETURN_CODE = 9999'); 
        RAISE ON_ERR;
    ELSIF R1.STATUS<>'S' THEN
        DBMS_OUTPUT.Put_Line('Preparation_AR_Check Processing'); 
        RAISE ON_ERR;
    END IF;
    CH_STATUS :='N';
    NU_CNT := R1.P_COUNT;
    NU_CNT_CHECK := R1.C_COUNT;
    NU_CNT_VALUE := R1.D_COUNT;
    DBMS_OUTPUT.Put_Line('CH_STATUS='||CH_STATUS||' ,NU_CNT='||NU_CNT||' ,NU_CNT_CHECK='||NU_CNT_CHECK||' ,NU_CNT_VALUE='||NU_CNT_VALUE);
END LOOP;

IF CH_STATUS='N' AND NU_CNT = NU_CNT_VALUE AND NU_CNT = NU_CNT_CHECK THEN
    DBMS_OUTPUT.Put_Line('Preparation_AR_Check Process RETURN_CODE = 0000'); 
ELSE   
    DBMS_OUTPUT.Put_Line('Preparation_AR_Check Processing'); 
END IF;

EXCEPTION 
   WHEN ON_ERR THEN
      NULL;
   WHEN OTHERS THEN
    DBMS_OUTPUT.Put_Line('Preparation_AR_Check Process RETURN_CODE = 9999'); 
end;
/
