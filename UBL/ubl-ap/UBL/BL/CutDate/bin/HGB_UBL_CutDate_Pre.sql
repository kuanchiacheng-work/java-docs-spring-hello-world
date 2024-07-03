--########################################################################################
--# Program name : HGB_UBL_CutDate.sh
--# SQL name : HGB_UBL_CutDate_Pre.sql
--# Path : /extsoft/UBL/BL/CutDate/bin
--#
--# Date : 2018/09/06 Created by FY
--# Description : HGB UBL CutDate
--########################################################################################
--# Date : 2021/02/20 Modify by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################
--# Date : 2023/04/17 Modify by Mike Kuan
--# Description : SR260229_Project-M Fixed line Phase I_新增CUST_TYPE='P'
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off
declare 
v_BILL_DATE       VARCHAR2(8)   := '&1'; 
v_CYCLE           NUMBER(2)     := '&2'; 
v_TYPE            VARCHAR(1)    := '&3'; 
NU_CNT            NUMBER        := 0;
   CURSOR C_C1 IS
      SELECT DISTINCT DECODE(ENTITY_TYPE,'S','SUBSCR_ID=','ACCT_ID=') TYPE, ENTITY_ID 
        FROM FY_TB_SYS_SYNC_ERROR A
       WHERE MODULE_ID='BL'
         AND ((ENTITY_TYPE='S' AND EXISTS (SELECT 1 FROM FY_TB_CM_SUBSCR S,
                                                         FY_TB_CM_CUSTOMER CC
                                           WHERE S.SUBSCR_ID=A.ENTITY_ID
                                             AND S.INIT_ACT_DATE<TO_DATE(v_BILL_DATE,'YYYYMMDD')
                                             AND CC.CUST_ID =S.CUST_ID
                                             AND CC.CYCLE   =v_CYCLE
											 AND CC.CUST_TYPE IN ('D', 'N', 'P'))) OR --SR260229_Project-M Fixed line Phase I_新增CUST_TYPE='P'
              (ENTITY_TYPE='A' AND EXISTS (SELECT 1 FROM FY_TB_CM_ACCOUNT S,
                                                         FY_TB_CM_CUSTOMER CC
                                           WHERE S.ACCT_ID  =A.ENTITY_ID
										     and s.eff_date <TO_DATE(v_BILL_DATE,'YYYYMMDD')
                                             AND CC.CUST_ID =S.CUST_ID
                                             AND CC.CYCLE   =v_CYCLE
											 AND CC.CUST_TYPE IN ('D', 'N', 'P')))) --SR260229_Project-M Fixed line Phase I_新增CUST_TYPE='P'
       ORDER BY DECODE(ENTITY_TYPE,'S','SUBSCR_ID=','ACCT_ID='),ENTITY_ID;
begin
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN Check DataSync Process...'); 
   --GET DATA_SYNC CHEKC
   FOR R_C1 IN C_C1 LOOP
      NU_CNT := NVL(NU_CNT,0) + 1;
      IF v_TYPE='Y' THEN
         DBMS_OUTPUT.Put_Line(R_C1.TYPE||TO_CHAR(R_C1.ENTITY_ID)); 
      END IF;   
   END LOOP;
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||' END Check DataSync Process...');   
   IF NU_CNT=0 THEN
      DBMS_OUTPUT.Put_Line('Pre_CutDate Process RETURN_CODE = 0000'||NULL);
   ELSE
      DBMS_OUTPUT.Put_Line('Pre_CutDate Process RETURN_CODE = 9999'||' Warning... ERROR_CNT = '||TO_CHAR(NU_CNT)); 
   END IF;                                                                               
EXCEPTION 
   WHEN OTHERS THEN
      DBMS_OUTPUT.Put_Line('Pre_CutDate Process RETURN_CODE = 9999');
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||SUBSTR(' END Check DataSync Process... '||SQLERRM,1,250)); 
end;
/
