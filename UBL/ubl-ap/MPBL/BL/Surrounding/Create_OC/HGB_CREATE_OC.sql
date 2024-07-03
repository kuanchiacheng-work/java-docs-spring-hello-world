--########################################################################################
--# Program name : HGB_UBL_Preparation.sh
--# Path : /extsoft/UBL/BL/Preparation/bin
--# SQL name : HGB_UBL_Preparation_AR_Check.sql
--#
--# Date : 2020/07/08 Created by Mike Kuan
--# Description : HGB CREATE OC
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

DECLARE
   V_TYPE               VARCHAR2(1)                              := '&1'; --'S/O/A'
   V_TYPE_ID            NUMBER                                   := '&2';
   V_BILL_PERIOD        FY_TB_BL_BILL_CNTRL.BILL_PERIOD%TYPE     := '&3'; --YYYYMM
   V_CHARGE_CODE        FY_TB_BL_BILL_CI.CHARGE_CODE%TYPE        := '&4';
   V_AMOUNT             FY_TB_BL_BILL_CI.AMOUNT%TYPE             := '&5';
   CH_DYNAMIC_ATTRIBUTE FY_TB_BL_BILL_CI.DYNAMIC_ATTRIBUTE%TYPE  := '&6';
   CH_USER              FY_TB_BL_BILL_CI.CREATE_USER%TYPE        := '&7';
   NU_CNT               NUMBER;
   CH_CHARGE_TYPE       FY_TB_BL_BILL_CI.CHARGE_TYPE%TYPE;
   CH_REVENUE_CODE      FY_TB_PBK_CHARGE_CODE.REVENUE_CODE%TYPE;
   NU_BILL_SEQ          FY_TB_BL_BILL_CNTRL.BILL_SEQ%TYPE;
   CH_STEP              VARCHAR2(300);
   On_Err               EXCEPTION;
   CURSOR C1 IS
      SELECT A.ACCT_ID, A.CUST_ID, A.SUBSCR_ID, B.CYCLE, C.CURRECT_PERIOD
        FROM FY_TB_CM_SUBSCR A,
             FY_TB_CM_CUSTOMER B,
             FY_TB_BL_CYCLE C
       WHERE A.SUBSCR_ID=V_TYPE_ID
         AND B.CUST_ID  =A.CUST_ID
         AND C.CYCLE    =B.CYCLE
         AND V_TYPE     ='S'     
    UNION  
      SELECT A.ACCT_ID, A.CUST_ID, NULL SUBSCR_ID, B.CYCLE, C.CURRECT_PERIOD
        FROM fy_tb_cm_org_unit A,
             FY_TB_CM_CUSTOMER B,
             FY_TB_BL_CYCLE C
       WHERE A.OU_ID    =V_TYPE_ID
         AND B.CUST_ID  =A.CUST_ID
         AND C.CYCLE    =B.CYCLE
         AND V_TYPE     ='O' 
    UNION  
      SELECT A.ACCT_ID, A.CUST_ID, NULL SUBSCR_ID, B.CYCLE, C.CURRECT_PERIOD
        FROM FY_TB_CM_ACCOUNT A,
             FY_TB_CM_CUSTOMER B,
             FY_TB_BL_CYCLE C
       WHERE A.ACCT_ID  =V_TYPE_ID
         AND B.CUST_ID  =A.CUST_ID
         AND C.CYCLE    =B.CYCLE
         AND V_TYPE     ='A'; 
   R1            C1%ROWTYPE;             
BEGIN
   OPEN C1;
   FETCH C1 INTO R1;
   IF C1%NOTFOUND THEN
      CH_STEP     := '系統中無此SUB、OU、ACCOUNT';
      RAISE ON_ERR;
   END IF;  
   CLOSE C1;
   
   --CHECK BILL_SEQ
   IF V_BILL_PERIOD=R1.CURRECT_PERIOD THEN
      NU_BILL_SEQ := NULL;
   ELSE
      SELECT BILL_SEQ 
        INTO NU_BILL_SEQ
        FROM FY_TB_BL_BILL_CNTRL
       WHERE CYCLE=R1.CYCLE
         AND BILL_PERIOD=V_BILL_PERIOD
         AND STATUS<>'CN';   
      R1.CURRECT_PERIOD :=V_BILL_PERIOD;  
   END IF;
   
   IF V_AMOUNT>=0 THEN
      CH_CHARGE_TYPE := 'DBT';
   ELSE
      CH_CHARGE_TYPE := 'CRD';   
   END IF;   

   CH_STEP := 'GET REVENUE_CODE.CHARGE_CODE='||V_CHARGE_CODE||':';
   SELECT REVENUE_CODE
     INTO CH_REVENUE_CODE
     FROM FY_TB_PBK_CHARGE_CODE
    WHERE CHARGE_CODE=V_CHARGE_CODE;

   CH_STEP := 'INSERT BILL_CI:';
   INSERT INTO FY_TB_BL_BILL_CI
                       (CI_SEQ,
                        ACCT_ID,
                        SUBSCR_ID,
                        CUST_ID,
                        OU_ID,
                        CHRG_ID,
                        CHARGE_TYPE,
                        AMOUNT,
                        OFFER_SEQ,
                        OFFER_ID,
                        OFFER_INSTANCE_ID,
                        PKG_ID,
                        CHRG_DATE,
                        CHRG_FROM_DATE,
                        CHRG_END_DATE,
                        CHARGE_CODE,
                        BILL_SEQ,
                        CYCLE,
                        CYCLE_MONTH,
                        TRX_ID,
                        TX_REASON,
                        AMT_DAY,
                        CDR_QTY,
                        CDR_ORG_AMT,
                        SOURCE,
                        SOURCE_CI_SEQ,
                        SOURCE_OFFER_ID,
                        BI_SEQ,
                        SERVICE_RECEIVER_TYPE,
                        CORRECT_SEQ,
                        CORRECT_CI_SEQ,
                        SERVICE_FILTER,
                        POINT_CLASS,
                        CET,
                        OVERWRITE,
                        DYNAMIC_ATTRIBUTE,
                        CREATE_DATE,
                        CREATE_USER,
                        UPDATE_DATE,
                        UPDATE_USER)
                 SELECT FY_SQ_BL_BILL_CI.NEXTVAL,
                        R1.ACCT_ID,
                        R1.SUBSCR_ID,
                        R1.CUST_ID,
                        DECODE(V_TYPE,'O',V_TYPE_ID,NULL) ,--OU_ID,
                        SUBSTR(V_CHARGE_CODE,3), --gvCHRG_ID,
                        CH_CHARGE_TYPE,
                        ROUND(V_AMOUNT,2),
                        NULL, --gnOFFER_SEQ,
                        NULL, --gnOFFER_ID,
                        NULL, --gnOFFER_INSTANCE_ID,
                        NULL, --gnPKG_ID,
                        SYSDATE, --gdBILL_DATE-1,   --CHRG_DATE,
                        NULL, --TRUNC(PI_START_DATE), --CHRG_FROM_DATE,
                        NULL, --TRUNC(PI_END_DATE),   --CHRG_END_DATE,
                        V_CHARGE_CODE,
                        NU_BILL_SEQ,
                        R1.CYCLE,
                        SUBSTR(R1.CURRECT_PERIOD,-2), --CYCLE_MONTH,
                        NULL,  --TRX_ID,
                        NULL,  --TX_REASON,
                        NULL,  --AMT_DAY,
                        NULL,  --CDR_QTY,
                        NULL,  --CDR_ORG_AMT
                        CH_REVENUE_CODE,  --SOURCE,
                        NULL,  --SOURCE_CI_SEQ,
                        NULL,  --SOURCE_OFFER_ID,
                        NULL,  --BI_SEQ,
                        V_TYPE, --SERVICE_RECEIVER_TYPE,
                        0,     --CORRECT_SEQ,
                        NULL,  --CORRECT_CI_SEQ,
                        NULL,  --SERVICE_FILTER,
                        NULL,  --POINT_CLASS,
                        NULL,  --CET,
                        NULL,  --OVERWRITE,
                        CH_DYNAMIC_ATTRIBUTE,  --DYNAMIC_ATTRIBUTE,
                        SYSDATE,
                        CH_USER,
                        SYSDATE,
                        CH_USER
                   FROM DUAL;
   COMMIT;
   DBMS_OUTPUT.Put_Line('0000');
EXCEPTION
   WHEN on_err THEN
      DBMS_OUTPUT.Put_Line('9999');
   WHEN OTHERS THEN
      DBMS_OUTPUT.Put_Line('9999');
END;
/
