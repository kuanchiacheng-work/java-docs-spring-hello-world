--########################################################################################
--# Program name : HGB_MPBL_Extract.sh
--# Path : /extsoft/MPBL/BL/Extract/bin
--# SQL name : HGB_MPBL_Confirm_DIO_Check.sql
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare
  v_BILL_DATE      VARCHAR2(8)  := '&1'; 
  v_CYCLE          NUMBER(2)    := '&2'; 
  v_PROC_ID        VARCHAR2(9)  := '&3';
  v_PROCESS_NO     NUMBER(3)    := '&4';
  v_PROC_TYPE      VARCHAR2(1)  := 'B';
  CH_USER          VARCHAR2(8)  := 'MPBL';
  nu_bill_seq      number;
  CH_ACCT_GROUP    FY_TB_BL_CYCLE_PROCESS.ACCT_GROUP%TYPE;
  CH_STATUS        FY_TB_DIO_CNTRL.STATUS%TYPE;
  CH_IO_TYPE       FY_TB_DIO_CNTRL.IO_TYPE%TYPE;
  NU_CNT           NUMBER;
  NU_CNT_CHECK     NUMBER; 
  RUN_MINS         NUMBER;  
  On_Err           EXCEPTION;
  CURSOR C1 IS
     SELECT BILL_SEQ, STATUS, ROUND(TO_NUMBER(sysdate - START_TIME) * 24 * 60) RUN_MINS, b.COUNT p_count, c.COUNT c_count
       FROM FY_TB_DIO_CNTRL A,
         (SELECT COUNT (proc_id) COUNT
            FROM fy_tb_dio_cntrl a
           WHERE bill_seq = nu_bill_seq
             AND process_no = v_process_no
             --AND acct_group = ch_acct_group
             AND proc_type = v_proc_type
             AND proc_id = v_PROC_ID
             AND confirm_id =
                    (SELECT MAX (confirm_id)
                       FROM fy_tb_dio_cntrl
                      WHERE bill_seq = a.bill_seq
                        AND process_no = a.process_no
                        --AND acct_group = a.acct_group
                        AND proc_type = a.proc_type
                        AND proc_id = v_PROC_ID)) b,
         (SELECT COUNT (status) COUNT
            FROM fy_tb_dio_cntrl a
           WHERE bill_seq = nu_bill_seq
             AND process_no = v_process_no
             --AND acct_group = ch_acct_group
             AND proc_type = v_proc_type
             AND proc_id = v_PROC_ID
             AND status = 'S'
             AND confirm_id =
                    (SELECT MAX (confirm_id)
                       FROM fy_tb_dio_cntrl
                      WHERE bill_seq = a.bill_seq
                        AND process_no = a.process_no
                        --AND acct_group = a.acct_group
                        AND proc_type = a.proc_type
                        AND proc_id = v_PROC_ID)) c
      WHERE BILL_SEQ  =NU_BILL_SEQ
		AND process_no = v_process_no
		--AND acct_group = ch_acct_group
        AND PROC_TYPE =v_PROC_TYPE
        AND PROC_ID   =v_PROC_ID
        AND CONFIRM_ID =(SELECT MAX(CONFIRM_ID) FROM FY_TB_DIO_CNTRL
                             WHERE BILL_SEQ  =A.BILL_SEQ
                               AND PROC_TYPE =A.PROC_TYPE
                               AND PROC_ID   =v_PROC_ID)
		order by decode(STATUS,'E',1,'A',2,'S',3,4);

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
    ELSIF R1.STATUS<>'S' THEN
       DBMS_OUTPUT.Put_Line('Confirm_DIO_Check '||v_PROC_ID||' Processing'); 
       RAISE ON_ERR;
    END IF;
	CH_STATUS :='N';
	NU_CNT := R1.P_COUNT;
	NU_CNT_CHECK := R1.C_COUNT;
	DBMS_OUTPUT.Put_Line('CH_STATUS='||CH_STATUS||' ,NU_CNT='||NU_CNT||' ,NU_CNT_CHECK='||NU_CNT_CHECK);
  END LOOP;
  
  IF CH_STATUS='N' AND NU_CNT = NU_CNT_CHECK THEN
     DBMS_OUTPUT.Put_Line('Confirm_DIO_Check '||v_PROC_ID||' Process RETURN_CODE = 0000'); 
  ELSE   
     DBMS_OUTPUT.Put_Line('Confirm_DIO_Check '||v_PROC_ID||' Processing'); 
  END IF; 
  
EXCEPTION 
   WHEN on_err THEN
      NULL;
   WHEN OTHERS THEN
     DBMS_OUTPUT.Put_Line('Confirm_DIO_Check '||v_PROC_ID||' Process RETURN_CODE = 9999'); 
end;
/
