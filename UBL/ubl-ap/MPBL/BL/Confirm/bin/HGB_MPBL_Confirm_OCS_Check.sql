--########################################################################################
--# Program name : HGB_UBL_Preparation.sh
--# Path : /extsoft/UBL/BL/Preparation/bin
--# SQL name : HGB_UBL_Preparation_AR_Check.sql
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare
  v_BILL_DATE      VARCHAR2(8)  := '&1';
  v_CYCLE          NUMBER(2)    := '&2';
  CH_USER          VARCHAR2(8)  := 'MPBL';
  nu_bill_seq      number;
  nu_count         number;
  NU_CNT           NUMBER;
  On_Err           EXCEPTION;
  CURSOR C1 IS
	SELECT count(1) COUNT
		FROM bl1_cyc_payer_pop@prdappc.prdcm
	WHERE cycle_seq_no = NU_BILL_SEQ AND status = 'BL';

begin
  select bill_SEQ
    into nu_bill_seq
    from fy_tb_bl_bill_cntrl A
   where A.bill_date =to_date(v_BILL_DATE,'yyyymmdd')
   and A.cycle=v_CYCLE
   and A.CREATE_USER=CH_USER;
   
  nu_count :=0;
  FOR R1 IN C1 LOOP
    IF R1.COUNT != 0 THEN
       DBMS_OUTPUT.Put_Line('Confirm_OCS_Check Processing'); 
       RAISE ON_ERR;
    ELSIF R1.COUNT IS NULL THEN
       DBMS_OUTPUT.Put_Line('Confirm_OCS_Check Process RETURN_CODE = 9999'); 
       RAISE ON_ERR;
    END IF;
    nu_count :=0;
  END LOOP;
  IF nu_count !=0 THEN
     DBMS_OUTPUT.Put_Line('Confirm_OCS_Check Processing'); 
  ELSE   
     DBMS_OUTPUT.Put_Line('Confirm_OCS_Check Process RETURN_CODE = 0000'); 
  END IF;   
EXCEPTION 
   WHEN on_err THEN
      NULL;
   WHEN OTHERS THEN
     DBMS_OUTPUT.Put_Line('Confirm_OCS_Check Process RETURN_CODE = 9999'); 
end;
/
