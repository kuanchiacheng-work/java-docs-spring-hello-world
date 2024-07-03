--########################################################################################
--# Program name : HGB_UBL_CutDate.sh
--# SQL name : HGB_UBL_CutDate.sql
--# Path : /extsoft/UBL/BL/CutDate/bin
--#
--# Date : 2018/09/06 Created by FY
--# Description : HGB UBL CutDate
--########################################################################################
--# Date : 2021/02/20 Modify by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off
declare 
v_CYCLE          NUMBER(2)    := '&1'; 
v_BILL_PERIOD    VARCHAR2(6)  := '&2'; 
CH_USER          VARCHAR2(8)  := 'UBL';
CH_ERR_CDE       VARCHAR2(10);
CH_ERR_MSG       VARCHAR2(300);
begin
     FY_PG_BL_BILL_CUTDATE.MAIN(v_CYCLE, v_BILL_PERIOD, CH_USER, CH_ERR_CDE, CH_ERR_MSG);
     if ch_err_cde='0000' then
        DBMS_OUTPUT.Put_Line('CutDate Process RETURN_CODE = 0000');
     else        
        DBMS_OUTPUT.Put_Line('CutDate Process RETURN_CODE = 9999'); 
     end if;     
EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('CutDate Process RETURN_CODE = 9999'); 
end;
/

exit;
