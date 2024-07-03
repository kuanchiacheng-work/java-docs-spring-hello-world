--########################################################################################
--# Program name : HGB_MPBL_Extract.sh
--# Path : /extsoft/MPBL/BL/Extract/bin
--# SQL name : HGB_MPBL_Extract_DIO_Check.sql
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare
  v_BILL_DATE      VARCHAR2(8)  := '&1'; 
  v_CYCLE          NUMBER(2)    := '&2'; 
  v_PROC_ID        VARCHAR2(8)  := '&3';
  v_PROC_TYPE      VARCHAR2(1)  := '&4';
  CH_USER          VARCHAR2(8)  := 'UBL';
  nu_bill_seq      number;
  CH_STATUS        FY_TB_DIO_CNTRL.STATUS%TYPE;
  CH_IO_TYPE       FY_TB_DIO_CNTRL.IO_TYPE%TYPE;
  NU_CNT           NUMBER;
  RUN_MINS         NUMBER;
  On_Err           EXCEPTION;
  CURSOR C1 IS
     SELECT BILL_SEQ, STATUS, ROUND(TO_NUMBER(sysdate - START_TIME) * 24 * 60) RUN_MINS
       FROM FY_TB_DIO_CNTRL A
      WHERE BILL_SEQ  =NU_BILL_SEQ
        AND PROC_TYPE =v_PROC_TYPE
        AND PROC_ID   =v_PROC_ID
        AND CNTRL_SEQ =(SELECT MAX(CNTRL_SEQ) FROM FY_TB_DIO_CNTRL
                             WHERE BILL_SEQ  =A.BILL_SEQ
                               AND PROC_TYPE =A.PROC_TYPE
                               AND PROC_ID   =v_PROC_ID)
		order by decode(STATUS,'E',1,'A',2,'FIN',3,4);

begin
  select bill_SEQ
    into nu_bill_seq
    from fy_tb_bl_bill_cntrl A
   where A.bill_date =to_date(v_BILL_DATE,'yyyymmdd')
   and A.cycle=v_CYCLE
   and a.create_user=CH_USER;
   
  CH_STATUS :='Y';
  FOR R1 IN C1 LOOP
    IF R1.STATUS='E' AND R1.RUN_MINS <= 10 THEN
		DELETE fy_tb_dio_cntrl_dtl
			WHERE cntrl_seq IN (SELECT cntrl_seq
								FROM fy_tb_dio_cntrl
								WHERE bill_seq = nu_bill_seq AND status = 'E');
	
		UPDATE fy_tb_dio_cntrl
			SET status = 'A',
				last_grp_id = NULL,
				tot_cnt = NULL,
				tot_amt = NULL,
				start_time = NULL,
				end_time = NULL
		WHERE bill_seq = nu_bill_seq AND status = 'E';
	
		COMMIT;

       DBMS_OUTPUT.Put_Line('Extract_DIO_Check '||v_PROC_ID||' Processing'); 
       RAISE ON_ERR;
    ELSIF R1.STATUS='E' THEN
       DBMS_OUTPUT.Put_Line('Extract_DIO_Check '||v_PROC_ID||' Process RETURN_CODE = 9999'); 
       RAISE ON_ERR;
    ELSIF R1.STATUS<>'FIN' THEN
       DBMS_OUTPUT.Put_Line('Extract_DIO_Check '||v_PROC_ID||' Processing'); 
       RAISE ON_ERR;
	ELSE
	   CH_STATUS :='N';
    END IF;
  END LOOP;
  IF CH_STATUS='Y' THEN
     DBMS_OUTPUT.Put_Line('Extract_DIO_Check '||v_PROC_ID||' Processing'); 
  ELSE   
     DBMS_OUTPUT.Put_Line('Extract_DIO_Check '||v_PROC_ID||' Process RETURN_CODE = 0000'); 
  END IF;   
EXCEPTION 
   WHEN on_err THEN
      NULL;
   WHEN OTHERS THEN
     DBMS_OUTPUT.Put_Line('Extract_DIO_Check '||v_PROC_ID||' Process RETURN_CODE = 9999'); 
end;
/
