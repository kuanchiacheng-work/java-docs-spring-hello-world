SET serveroutput ON SIZE 1000000
set verify off
DECLARE
   PI_ACCT_ID           NUMBER       := '&1'; 
   PI_BILL_DATE         VARCHAR(8)   := '&2';  --計費截止日(當天不算，NULL=SYSDATE)
   PI_USER              VARCHAR(10)  := 'UBL_TST';
   CH_ERR_CDE           VARCHAR2(4);
   CH_ERR_MSG           VARCHAR2(250);
   NU_BILL_SEQ          NUMBER;
   DT_BILL_FROM_DATE    DATE;
   DT_BILL_END_DATE     DATE;
   DT_BILL_DATE         DATE;
   On_Err               EXCEPTION;
   CURSOR C_CYC IS
      SELECT C.CYCLE,
             C.NAME,
             C.BILLING_DAY,
             C.FROM_DAY,
             C.END_DAY,
             C.DUE_DAY,
             C.LBC_DATE,
             C.CURRECT_PERIOD BILL_PERIOD,
             TO_NUMBER(SUBSTR(C.CURRECT_PERIOD,-2)) CYCLE_MONTH
        FROM FY_TB_BL_ACCOUNT A,
             FY_TB_BL_CYCLE C
       WHERE A.ACCT_ID=PI_ACCT_ID
         AND A.CYCLE=C.CYCLE;
      R_CYC       C_CYC%ROWTYPE;    
   
BEGIN
   ----CHECK CYCLE正確性
   OPEN C_CYC;
   FETCH C_CYC INTO R_CYC;
   IF C_CYC%NOTFOUND THEN
      CH_ERR_CDE := '9999';
      CH_ERR_MSG := 'CHECK CYCLE.ACCT_ID='||TO_CHAR(PI_ACCT_ID)||':NO DATA FOUND';
      RAISE ON_ERR;
   END IF;
   CLOSE C_CYC;
   --DATA 處理
   CH_ERR_MSG := 'GET BILL_SEQ :';
   SELECT FY_SQ_BL_BILL_CNTRL.NEXTVAL
     INTO NU_BILL_SEQ
     FROM DUAL; 
   IF R_CYC.FROM_DAY=1 THEN
      DT_BILL_FROM_DATE := TO_DATE(R_CYC.BILL_PERIOD||TO_CHAR(R_CYC.FROM_DAY),'YYYYMMDD');
      DT_BILL_END_DATE  := TO_DATE(R_CYC.BILL_PERIOD||TO_CHAR(Last_Day(DT_BILL_FROM_DATE),'DD'),'YYYYMMDD');
   ELSE    
      DT_BILL_END_DATE  := TO_DATE(R_CYC.BILL_PERIOD||TO_CHAR(R_CYC.END_DAY),'YYYYMMDD');
      DT_BILL_FROM_DATE := ADD_MONTHS(DT_BILL_END_DATE,-1)+1;
   END IF;  
   DT_BILL_DATE := DT_BILL_END_DATE+1; 
   
   --GET UC
   CH_ERR_MSG := 'GET UC:';
   INSERT INTO FY_TB_BL_BILL_CI_TEST
                           (CI_SEQ,
                            ACCT_ID,
                            ACCT_KEY,
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
                            SOURCE,
                            SOURCE_CI_SEQ,
                            SOURCE_OFFER_ID,
                            BI_SEQ,
                            SERVICE_RECEIVER_TYPE,
                            CORRECT_SEQ,
                            CORRECT_CI_SEQ,
                            SERVICE_FILTER,
                            POINT_CLASS,
                            CDR_QTY,
                            CDR_ORG_AMT,
                            CET,
                            OVERWRITE,
                            DYNAMIC_ATTRIBUTE,
                            CREATE_DATE,
                            CREATE_USER,
                            UPDATE_DATE,
                            UPDATE_USER)
                     SELECT FY_SQ_BL_BILL_CI_TEST.NEXTVAL,
                            RT.ACCT_ID,
                            MOD(RT.ACCT_ID,100),
                            RT.SUBSCR_ID,
                            RT.CUST_ID,
                            NULL,   --OU_ID,
                            RT.ITEM_ID, --CHRG_ID,
                            'DBT',  --CHARGE_TYPE, 正DBT、負CRD
                            ROUND(RT.CHRG_AMT,2),
                            NULL,   --OFFER_SEQ,
                            RT.OFFER_ID,
                            NULL,   --OFFER_INSTANCE_ID,
                            NULL,   --PKG_ID,
                            RT.CREATE_DATE,   --CHRG_DATE,
                            NULL,   --CHRG_FROM_DATE,
                            NULL,   --CHRG_END_DATE,
                            RT.CHARGE_CODE,
                            NU_BILL_SEQ,
                            RT.CYCLE,
                            RT.CYCLE_MONTH,
                            NULL,   --TRX_ID,
                            NULL,   --TX_REASON,
                            NULL,   --AMT_DAY,
                            'UC',   --SOURCE,
                            NULL,   --SOURCE_CI_SEQ,
                            NULL,   --SOURCE_OFFER_ID,
                            NULL,   --BI_SEQ,
                            'S',    --SERVICE_RECEIVER_TYPE,
                            NULL,   --CORRECT_SEQ,
                            NULL,   --CORRECT_CI_SEQ,
                            RT.SERVICE_FILTER,
                            RT.POINT_CLASS,
                            RT.QTY,
                            round(RT.ORG_AMT,2),
                            RT.CET,
                            NULL,   --OVERWRITE,
                            NULL,   --DYNAMIC_ATTRIBUTE,
                            SYSDATE,
                            PI_USER,
                            SYSDATE,
                            PI_USER
                       FROM FY_TB_RAT_SUMMARY RT
                      WHERE BILL_PERIOD=R_CYC.BILL_PERIOD
                        AND CYCLE      =R_CYC.CYCLE
                        AND CYCLE_MONTH=R_CYC.CYCLE_MONTH
                        AND ACCT_ID    =PI_ACCT_ID
                        AND ACCT_KEY   =MOD(PI_ACCT_ID,100); 
   --OC
   CH_ERR_MSG := 'GET OC:';
   INSERT INTO FY_TB_BL_BILL_CI_TEST
              (CI_SEQ,
               ACCT_ID,
               ACCT_KEY,
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
               SOURCE,
               SOURCE_CI_SEQ,
               SOURCE_OFFER_ID,
               BI_SEQ,
               SERVICE_RECEIVER_TYPE,
               CORRECT_SEQ,
               CORRECT_CI_SEQ,
               SERVICE_FILTER,
               POINT_CLASS,
               CDR_QTY,
               CDR_ORG_AMT,
               CET,
               OVERWRITE,
               DYNAMIC_ATTRIBUTE,
               CREATE_DATE,
               CREATE_USER,
               UPDATE_DATE,
               UPDATE_USER)
        SELECT FY_SQ_BL_BILL_CI_TEST.NEXTVAL,
               ACCT_ID,
               MOD(ACCT_ID,100),
               SUBSCR_ID,
               CUST_ID,
               OU_ID,
               CHRG_ID,
               CHARGE_TYPE,
               ROUND(AMOUNT,2),
               OFFER_SEQ,
               OFFER_ID,
               OFFER_INSTANCE_ID,
               PKG_ID,
               CHRG_DATE,
               CHRG_FROM_DATE,
               CHRG_END_DATE,
               CHARGE_CODE,
               NU_BILL_SEQ,
               CYCLE,
               CYCLE_MONTH,
               TRX_ID,
               TX_REASON,
               AMT_DAY,
               SOURCE,
               SOURCE_CI_SEQ,
               SOURCE_OFFER_ID,
               BI_SEQ,
               SERVICE_RECEIVER_TYPE,
               CORRECT_SEQ,
               CORRECT_CI_SEQ,
               SERVICE_FILTER,
               POINT_CLASS,
               CDR_QTY,
               ROUND(CDR_ORG_AMT,2),
               CET,
               OVERWRITE,
               DYNAMIC_ATTRIBUTE,
               CREATE_DATE,
               CREATE_USER,
               UPDATE_DATE,
               UPDATE_USER
           FROM FY_TB_BL_BILL_CI CI
          WHERE CYCLE      =R_CYC.CYCLE
            AND CYCLE_MONTH=R_CYC.CYCLE_MONTH  
            AND ACCT_ID    =PI_ACCT_ID 
            AND ACCT_KEY   =MOD(PI_ACCT_ID,100)
            AND SOURCE     ='OC'
            AND BILL_SEQ IS NULL;  
   --RC
   CH_ERR_MSG := 'DO_RECUR:';
   FY_PG_BL_BILL_UTIL.DO_RECUR(PI_ACCT_ID  ,
                               NU_BILL_SEQ ,
                               R_CYC.CYCLE ,
                               R_CYC.CYCLE_MONTH,
                               DT_BILL_FROM_DATE,
                               DT_BILL_END_DATE ,
                               DT_BILL_DATE     ,
                               R_CYC.FROM_DAY   ,
                               TO_DATE(NVL(PI_BILL_DATE,TO_CHAR(SYSDATE,'YYYYMMDD')),'YYYYMMDD')-1,
                               CH_ERR_CDE       ,
                               CH_ERR_MSG       ); 
   IF CH_ERR_CDE<>'0000' THEN
      CH_ERR_MSG := 'DO_RECUR:'||CH_ERR_MSG;
      RAISE ON_ERR; 
   END IF;
   CH_ERR_MSG := 'LIST_DTL:';
   INSERT INTO FY_TB_BL_ACCT_LIST_DTL
                          (BILL_SEQ ,
                           ACCT_ID,
                           TYPE,
                           CI_ID,
                           OFFER_SEQ,
                           Create_Date,
                           Create_User,
                           Update_Date,
                           Update_User)
                    SELECT BILL_SEQ,
                           ACCT_ID,
                           SOURCE,
                           ROUND(SUM(AMOUNT)),
                           NULL,
                           SYSDATE,
                           'UBL',
                           SYSDATE,
                           'UBL'
                      FROM FY_TB_BL_BILL_CI_TEST A
                     WHERE A.CYCLE      =R_CYC.CYCLE
                       AND A.CYCLE_MONTH=R_CYC.CYCLE_MONTH
                       AND A.ACCT_KEY   =MOD(PI_ACCT_ID,100)
                       AND A.BILL_SEQ   =NU_BILL_SEQ
                       AND A.ACCT_ID    =PI_ACCT_ID
                    GROUP BY A.BILL_SEQ, A.ACCT_ID, A.SOURCE ;
                    
   CH_ERR_MSG := 'LIST:';
   INSERT INTO FY_TB_BL_ACCT_LIST
                          (BILL_SEQ ,
                           CYCLE,
                           CYCLE_MONTH,
                           ACCT_ID,
                           BILL_START_PERIOD,
                           BILL_END_PERIOD,
                           BILL_END_DATE,
                           TYPE,
                           HOLD_DESC,
                           UC_FLAG,
                         --  ERR_MSG,
                           Create_Date,
                           Create_User,
                           Update_Date,
                           Update_User)
                     VALUES
                          (NU_BILL_SEQ,
                           R_CYC.CYCLE,
                           R_CYC.CYCLE_MONTH,
                           PI_ACCT_ID,
                           R_CYC.BILL_PERIOD,
                           R_CYC.BILL_PERIOD,
                           DT_BILL_END_DATE,
                           'BILL',
                           NULL,
                           'Y',
                        --   'Immediately Bill',
                           SYSDATE,
                           'UBL',
                           SYSDATE,
                           'UBL'); 
   COMMIT;
   DBMS_OUTPUT.Put_Line('BILL_SEQ='||TO_CHAR(NU_BILL_SEQ));                        
EXCEPTION
    WHEN On_Err THEN
        ROLLBACK;
        DBMS_OUTPUT.Put_Line(CH_ERR_CDE||CH_ERR_MSG);
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.Put_Line(SUBSTR(CH_ERR_MSG||SQLERRM,1,250));    
END ;    
      
                                                 
             