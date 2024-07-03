--########################################################################################
--# Program name : HGB_UBL_Extract.sh
--# Path : /extsoft/UBL/BL/Extract/bin
--# SQL name : HGB_UBL_Extract.sql
--#
--# Date : 2019/06/30 Modify by Mike Kuan
--# Description : SR213344_NPEP add cycle parameter
--########################################################################################
--# Date : 2021/02/20 Modify by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off
declare 
   v_BILL_DATE      VARCHAR2(8)  := '&1';
   v_CYCLE          NUMBER(2)    := '&2';
   v_PROC_TYPE      VARCHAR2(1)  := '&3';
   CH_USER          VARCHAR2(8)  := 'UBL';
   NU_BILL_SEQ      NUMBER;
   CH_ERR_CDE       VARCHAR2(10);
   CH_ERR_MSG       VARCHAR2(300);
   On_Err           EXCEPTION;
begin
        DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN Extract Process...'); 
         SELECT A.BILL_SEQ
           INTO NU_BILL_SEQ
     FROM FY_TB_BL_BILL_CNTRL A
    WHERE A.BILL_DATE   =TO_DATE(v_BILL_DATE,'YYYYMMDD')
	and a.cycle =v_CYCLE
	and a.create_user =CH_USER;
    ----DIO 
    Fy_Pg_Dio_Util.Ins_Dio_MAST
                           ('UBL',     --Pi_Sys_Id ,
                            'MAST', --Pi_Proc_Id ,
                            NU_Bill_Seq ,
                            v_Proc_Type, 
                            'O',        --Pi_Io_Type,
                            CH_USER,
                            CH_Err_Cde,
                            CH_Err_Msg);                           
    IF CH_Err_Cde <> '0000' THEN
       RAISE ON_ERR;
    END IF; 
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||' END Extract Process...'); 
   DBMS_OUTPUT.Put_Line('Extract Process RETURN_CODE = 0000'||null);  
EXCEPTION 
   WHEN ON_ERR THEN
       DBMS_OUTPUT.Put_Line('Extract Process RETURN_CODE = 9999'||SUBSTR(' Extract'||ch_err_msg,1,250)); 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('Extract Process RETURN_CODE = 9999'||SUBSTR(' Extract'||SQLERRM,1,250)); 
end;
/

exit;
