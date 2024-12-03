CREATE OR REPLACE PACKAGE BODY FY_PG_BL_BILL_BI IS
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL_BI 處理
      DESCRIPTION : BL BILL_BI 處理
      PARAMETER:
            PI_BILL_SEQ           :出帳序號
            PI_PROCESS_NO         :執行序號
            PI_ACCT_GROUP         :客戶類型
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)
            PI_USER_ID            :執行USER_ID
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE MAIN(PI_BILL_SEQ       IN   NUMBER,
                  PI_PROCESS_NO     IN   NUMBER,
                  PI_ACCT_GROUP     IN   VARCHAR2,
                  PI_PROC_TYPE      IN   VARCHAR2 DEFAULT 'B',
                  PI_USER_ID        IN   VARCHAR2,
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2) IS

      --抓取應出帳之ACCT_ID
      CURSOR C_AT(iCYCLE NUMBER, iCYCLE_MONTH NUMBER) IS
        SELECT AT.ACCT_ID,
               AT.CUST_ID,
               AT.OU_ID,
               AT.SUBSCR_CNT,
               AT.ACCT_GROUP,
               AT.BILL_CURRENCY,
               AT.ACCT_STATUS,
               AT.PERM_PRINTING_CAT,
               AT.ACCT_CATEGORY,
               AT.PRODUCTION_TYPE,
               AT.PRE_BILL_NBR,
               AT.PRE_BILL_AMT,
               AT.ACCT_KEY
          FROM FY_TB_BL_BILL_ACCT AT
         WHERE AT.BILL_SEQ   =PI_BILL_SEQ
           AND AT.CYCLE      =iCYCLE
           AND AT.CYCLE_MONTH=iCYCLE_MONTH
           AND AT.ACCT_GROUP =PI_ACCT_GROUP
           AND gnPROCESS_NO <>999
           AND ((gvPROC_TYPE='B' AND AT.BILL_STATUS ='CL') OR
                (gvPROC_TYPE='T' AND AT.BILL_STATUS<>'CN' AND
                 NOT EXISTS (SELECT 1 FROM FY_TB_BL_BILL_PROCESS_ERR
                                WHERE BILL_SEQ   =AT.BILL_SEQ
                                  AND PROCESS_NO =gnPROCESS_NO
                                  AND ACCT_GROUP =AT.ACCT_GROUP
                                  AND PROC_TYPE  =gvPROC_TYPE
                                  AND ACCT_ID    =AT.ACCT_ID)
                ))
         UNION
        SELECT AT.ACCT_ID,
               AT.CUST_ID,
               AT.OU_ID,
               AT.SUBSCR_CNT,
               AT.ACCT_GROUP,
               AT.BILL_CURRENCY,
               AT.ACCT_STATUS,
               AT.PERM_PRINTING_CAT,
               AT.ACCT_CATEGORY,
               AT.PRODUCTION_TYPE,
               AT.PRE_BILL_NBR,
               AT.PRE_BILL_AMT,
               AT.ACCT_KEY
          FROM FY_TB_BL_ACCT_LIST AL,
               FY_TB_BL_BILL_ACCT AT
         WHERE AL.BILL_SEQ   =PI_BILL_SEQ
           AND AL.TYPE       =PI_ACCT_GROUP
           AND AT.BILL_SEQ   =AL.BILL_SEQ
           AND AT.CYCLE      =iCYCLE
           AND AT.CYCLE_MONTH=iCYCLE_MONTH
           AND AT.ACCT_ID    =AL.ACCT_ID
           AND AT.ACCT_KEY   =TO_NUMBER(SUBSTR(LPAD(AL.ACCT_ID,18,0),-2))
           AND gnPROCESS_NO  =999
           AND ((gvPROC_TYPE='B' AND AT.BILL_STATUS ='CL') OR
                (gvPROC_TYPE='T' AND AT.BILL_STATUS<>'CN' AND
                 NOT EXISTS (SELECT 1 FROM FY_TB_BL_BILL_PROCESS_ERR
                                WHERE BILL_SEQ   =AL.BILL_SEQ
                                  AND PROCESS_NO =gnPROCESS_NO
                                  AND ACCT_GROUP =AL.TYPE
                                  AND PROC_TYPE  =gvPROC_TYPE
                                  AND ACCT_ID    =AL.ACCT_ID)
                ))
         ORDER BY ACCT_ID;

      --GET TAX_TYPE
      CURSOR C_LK IS
         SELECT LOOKUP_CODE, CH1, NUM1
           FROM FY_TB_SYS_LOOKUP_CODE
          WHERE LOOKUP_TYPE='TAX_TYPE';

      NU_CNT             NUMBER  :=0;
      NU_CTRL_CNT        NUMBER  :=0;
      NU_SHOW_CNT        NUMBER;
      CH_STATUS          FY_TB_BL_BILL_CNTRL.STATUS%TYPE;
      DT_START_DATE      DATE;
      DT_END_DATE        DATE;
      On_AT_Err          EXCEPTION;
      ON_ERR             EXCEPTION;
   BEGIN
      ----CHECK PROCESS_NO
      gvSTEP := 'CALL Ins_Process_LOG:';
      Fy_Pg_Bl_Bill_Util.Ins_Process_LOG
                     ('BI',  --PI_STATUS
                      Pi_Bill_Seq,
                      Pi_Proc_Type,
                      Pi_Process_No,
                      Pi_Acct_Group ,
                      PI_User_Id ,
                      gvERR_CDE ,
                      gvERR_MSG);
      IF gvERR_CDE<>'0000' THEN
         Po_Err_Cde:= gvERR_CDE;
         gvSTEP    := SUBSTR(gvSTEP||gvERR_MSG,1,250);
         RAISE On_Err;
      END IF;
      --設定一些全域的變數
      gnBILL_SEQ  := PI_BILL_SEQ;
      gnPROCESS_NO:= PI_PROCESS_NO;
      gvACCT_GROUP:= PI_ACCT_GROUP;
      gvPROC_TYPE := PI_PROC_TYPE;
      gvUSER      := PI_USER_ID;
      --GET BILL_CNTRL
      gvSTEP := 'GET BILL_DATA FROM BILLING_LOG, BILL_SEQ:'||TO_CHAR(gnBILL_SEQ);
      SELECT BC.BILL_DATE, BC.CYCLE, BC.BILL_PERIOD, BC.BILL_FROM_DATE, BC.BILL_END_DATE,
             TO_CHAR(BC.BILL_FROM_DATE,'DD'), TO_NUMBER(SUBSTR(BC.BILL_PERIOD,-2))
        INTO gdBILL_DATE, gnCYCLE, gvBILL_PERIOD, gdBILL_FROM_DATE, gdBILL_END_DATE,
             gnFROM_DAY, gnCYCLE_MONTH
        FROM FY_TB_BL_BILL_CNTRL BC
       WHERE BC.BILL_SEQ  = gnBILL_SEQ;

      --GET 稅&尾差
      NU_CNT :=0;
      FOR R_LK IN C_LK LOOP
         NU_CNT := NU_CNT +1;
         IF R_LK.LOOKUP_CODE='TX1' THEN
            gvROUND_TX1 := R_LK.CH1;
            gnRATE_TX1  := R_LK.NUM1;
         ELSIF R_LK.LOOKUP_CODE='TX2' THEN
            gvROUND_TX2 := R_LK.CH1;
            gnRATE_TX2  := R_LK.NUM1;
         ELSIF R_LK.LOOKUP_CODE='TX3' THEN
            gvROUND_TX3 := R_LK.CH1;
            gnRATE_TX3  := R_LK.NUM1;
         END IF;
      END LOOP;
      IF NU_CNT=0 THEN
         Po_Err_Cde:= 'B001';
         gvSTEP    := 'FY_TB_SYS_LOOKUP_CODE未設定小數尾差CHARGE_CODE';
         RAISE On_Err;
      END IF;
      --SHOW_CNT
      BEGIN
           SELECT NUM1
             INTO NU_SHOW_CNT
             FROM FY_TB_SYS_LOOKUP_CODE
            WHERE LOOKUP_TYPE='OUTPUT'
              AND LOOKUP_CODE='SHOW_CNT';
      EXCEPTION WHEN OTHERS THEN
         NU_SHOW_CNT :=10000;
      END;
      --GET ACCT_ID
      FOR R_AT IN C_AT(gnCYCLE, gnCYCLE_MONTH) LOOP
         NU_CTRL_CNT := NVL(NU_CTRL_CNT,0)+1;
         IF MOD(NU_CTRL_CNT/NU_SHOW_CNT,1)=0 THEN
            DBMS_OUTPUT.Put_Line('CNT='||TO_CHAR(NU_CTRL_CNT));
         END IF;
         BEGIN
            gnACCT_ID       := R_AT.ACCT_ID;
            gnCUST_ID       := R_AT.CUST_ID;
            gvBILL_CURRENCY := R_AT.BILL_CURRENCY;
            gnACCT_OU_ID    := R_AT.OU_ID;

            --CI SUMMARY BI (FOR CI)
            gvSTEP := 'GEN_BI:';
            GEN_BI;
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR('GEN_BI:'||gvERR_MSG,1,250);
               RAISE ON_AT_ERR;
            END IF;

            --尾差處理
            IF gvBILL_CURRENCY = 'NTD' THEN --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            gvSTEP := 'DO_ROUND:';
            DO_ROUND;
            --gvSTEP := 'DO_ROUND_FIX:'; --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            --DO_ROUND_FIX; --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            ELSIF gvBILL_CURRENCY = 'USD' THEN --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            gvSTEP := 'DO_NTD_ROUND:'; --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            DO_NTD_ROUND; --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            END IF; --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR(gvSTEP||gvERR_MSG,1,250); --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
               RAISE ON_AT_ERR;
            END IF;
         EXCEPTION
            WHEN ON_AT_ERR THEN
               ROLLBACK;
               -- '新增出帳錯誤記錄檔';
               Fy_Pg_Bl_Bill_Util.Ins_Process_Err(gnBill_Seq,
                                                  gvProc_Type,
                                                  gnAcct_Id,
                                                  NULL,
                                                  gnProcess_No,
                                                  gvAcct_Group,
                                                  'FY_PG_BL_BILL_BI',  --PG_NAME
                                                  gvUser,
                                                  gvERR_CDE,
                                                  gvSTEP,
                                                  PO_ERR_CDE,
                                                  PO_ERR_MSG);
               IF PO_ERR_CDE <> '0000' THEN
                  gvSTEP     := Substr('CALL Ins_Process_Err:'||PO_ERR_MSG,1,250);
                  RAISE On_Err;
               END IF;
            WHEN OTHERS THEN
               ROLLBACK;
               -- '新增出帳錯誤記錄檔';
               Fy_Pg_Bl_Bill_Util.Ins_Process_Err(gnBill_Seq,
                                                  gvProc_Type,
                                                  gnAcct_Id,
                                                  NULL,
                                                  gnProcess_No,
                                                  gvAcct_Group,
                                                  'FY_PG_BL_BILL_BI',  --PG_NAME
                                                  gvUser,
                                                  gvERR_CDE,
                                                  Substr(gvStep || ',' || SQLERRM, 1, 250),
                                                  PO_ERR_CDE,
                                                  PO_ERR_MSG);
               IF PO_ERR_CDE <> '0000' THEN
                  gvSTEP     := Substr('CALL Ins_Process_Err:'||PO_ERR_MSG,1,250);
                  RAISE On_Err;
               END IF;
         END;
         COMMIT;
      END LOOP;  --C_AT
      --
      gvSTEP := 'UPDATE PROCESS_LOG.BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||':';
      UPDATE FY_TB_BL_BILL_PROCESS_LOG BL SET END_TIME=SYSDATE,
                                              COUNT   =NU_CTRL_CNT
                                     WHERE BILL_SEQ  = PI_BILL_SEQ
                                       AND PROCESS_NO= PI_PROCESS_NO
                                       AND ACCT_GROUP= PI_ACCT_GROUP
                                       AND PROC_TYPE = PI_PROC_TYPE
                                       AND STATUS    = 'BI'
                                       AND END_TIME IS NULL;
      COMMIT;
      PO_ERR_CDE := '0000';
      PO_ERR_MSG := NULL;
   EXCEPTION
      WHEN On_Err THEN
         Po_Err_Cde := '9001';
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END MAIN;

   /*************************************************************************
      PROCEDURE : GEN_BI
      PURPOSE :   針對CI SUMMARY TO BI (FOR UC/OC)
      DESCRIPTION : 針對CI SUMMARY TO BI (FOR UC/OC)
      PARAMETER:

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE GEN_BI IS

      --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 ADD C_PN
      CURSOR C_PN IS
         SELECT BILL_SUBSCR_ID,
                OFFER_ID,
                MAX(OFFER_INSTANCE_ID) OFFER_INSTANCE_ID, --2022/10/14 SR255529_PN折扣對應修改
                MAX(OFFER_SEQ) OFFER_SEQ, --2022/10/14 SR255529_PN折扣對應修改
                PKG_ID,
                CHARGE_CODE,
                SUM(AMOUNT) AMOUNT,
                SOURCE,
                MAX(CHRG_DATE) CHRG_DATE,
                MIN(CI_SEQ) CI_SEQ,
                DECODE(SOURCE,'OC',NVL(DECODE(MAX(NVL(CORRECT_SEQ,0)),0,0,MAX(NVL(CORRECT_SEQ,0))+1),1),0) CORRECT_SEQ,
                'Is prorated=false#PN_IND=Y' DYNAMIC_ATTRIBUTE,
                DECODE(SOURCE,'UC',DECODE(SIGN(SUM(AMOUNT)),-1,'DE','RA'),'DE','DE','CC') CHARGE_ORG,
                DECODE(SOURCE,'RC',gdBILL_FROM_DATE,NULL) CHRG_FROM_DATE,
                DECODE(SOURCE,'RC',gdBILL_END_DATE,NULL) CHRG_END_DATE
           FROM FY_TB_BL_BILL_CI A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND ACCT_ID     =gnACCT_ID
           -- AND (SOURCE='UC' OR (SOURCE<>'UC' AND CORRECT_CI_SEQ IS NULL))
            AND gvPROC_TYPE ='B'
            AND BILL_SUBSCR_ID<>SUBSCR_ID  
			AND SOURCE != 'DE'  --2024/05/29 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1，修改折扣group條件
         -- GROUP BY BILL_SUBSCR_ID,OFFER_ID,CHARGE_CODE,DYNAMIC_ATTRIBUTE,SOURCE 
          GROUP BY BILL_SUBSCR_ID,CHARGE_CODE,SOURCE,OFFER_ID,PKG_ID
        UNION --2024/05/29 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1，修改折扣group條件
         SELECT BILL_SUBSCR_ID,
                OFFER_ID,
                OFFER_INSTANCE_ID, --2022/10/14 SR255529_PN折扣對應修改
                OFFER_SEQ, --2022/10/14 SR255529_PN折扣對應修改
                PKG_ID,
                MAX(CHARGE_CODE) CHARGE_CODE,
                SUM(AMOUNT) AMOUNT,
                SOURCE,
                MAX(CHRG_DATE) CHRG_DATE,
                MIN(CI_SEQ) CI_SEQ,
                DECODE(SOURCE,'OC',NVL(DECODE(MAX(NVL(CORRECT_SEQ,0)),0,0,MAX(NVL(CORRECT_SEQ,0))+1),1),0) CORRECT_SEQ,
                'Is prorated=false#PN_IND=Y' DYNAMIC_ATTRIBUTE,
                DECODE(SOURCE,'UC',DECODE(SIGN(SUM(AMOUNT)),-1,'DE','RA'),'DE','DE','CC') CHARGE_ORG,
                DECODE(SOURCE,'RC',gdBILL_FROM_DATE,NULL) CHRG_FROM_DATE,
                DECODE(SOURCE,'RC',gdBILL_END_DATE,NULL) CHRG_END_DATE
           FROM FY_TB_BL_BILL_CI A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND ACCT_ID     =gnACCT_ID
           -- AND (SOURCE='UC' OR (SOURCE<>'UC' AND CORRECT_CI_SEQ IS NULL))
            AND gvPROC_TYPE ='B'
            AND BILL_SUBSCR_ID<>SUBSCR_ID  
			AND SOURCE = 'DE'  
			AND PKG_ID IN (SELECT PKG_ID FROM FY_TB_BL_ACCT_PKG A, FY_TB_PBK_OFFER B WHERE A.OFFER_ID = B.OFFER_ID AND B.PRODUCT_TYPE = 'I')
         -- GROUP BY BILL_SUBSCR_ID,OFFER_ID,CHARGE_CODE,DYNAMIC_ATTRIBUTE,SOURCE 
         -- GROUP BY BILL_SUBSCR_ID,SOURCE,OFFER_ID,PKG_ID
			GROUP BY BILL_SUBSCR_ID,CHARGE_CODE,SOURCE,OFFER_ID,PKG_ID,OFFER_INSTANCE_ID,OFFER_SEQ
        UNION
         SELECT BILL_SUBSCR_ID,
                OFFER_ID,
                MAX(OFFER_INSTANCE_ID) OFFER_INSTANCE_ID, --2022/10/14 SR255529_PN折扣對應修改
                MAX(OFFER_SEQ) OFFER_SEQ, --2022/10/14 SR255529_PN折扣對應修改
                PKG_ID,
                MAX(CHARGE_CODE) CHARGE_CODE,
                SUM(AMOUNT) AMOUNT,
                SOURCE,
                MAX(CHRG_DATE) CHRG_DATE,
                MIN(CI_SEQ) CI_SEQ,
                DECODE(SOURCE,'OC',NVL(DECODE(MAX(NVL(CORRECT_SEQ,0)),0,0,MAX(NVL(CORRECT_SEQ,0))+1),1),0) CORRECT_SEQ,
                'Is prorated=false#PN_IND=Y' DYNAMIC_ATTRIBUTE,
                DECODE(SOURCE,'UC',DECODE(SIGN(SUM(AMOUNT)),-1,'DE','RA'),'DE','DE','CC') CHARGE_ORG,
                DECODE(SOURCE,'RC',gdBILL_FROM_DATE,NULL) CHRG_FROM_DATE,
                DECODE(SOURCE,'RC',gdBILL_END_DATE,NULL) CHRG_END_DATE
           FROM FY_TB_BL_BILL_CI A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND ACCT_ID     =gnACCT_ID
           -- AND (SOURCE='UC' OR (SOURCE<>'UC' AND CORRECT_CI_SEQ IS NULL))
            AND gvPROC_TYPE ='B'
            AND BILL_SUBSCR_ID<>SUBSCR_ID  
			AND SOURCE = 'DE'  
			AND PKG_ID NOT IN (SELECT PKG_ID FROM FY_TB_BL_ACCT_PKG A, FY_TB_PBK_OFFER B WHERE A.OFFER_ID = B.OFFER_ID AND B.PRODUCT_TYPE = 'I')
         -- GROUP BY BILL_SUBSCR_ID,OFFER_ID,CHARGE_CODE,DYNAMIC_ATTRIBUTE,SOURCE 
         -- GROUP BY BILL_SUBSCR_ID,SOURCE,OFFER_ID,PKG_ID
			GROUP BY BILL_SUBSCR_ID,CHARGE_CODE,SOURCE,OFFER_ID,PKG_ID
        UNION
         SELECT BILL_SUBSCR_ID,
                OFFER_ID,
                MAX(OFFER_INSTANCE_ID) OFFER_INSTANCE_ID, --2022/10/14 SR255529_PN折扣對應修改
                MAX(OFFER_SEQ) OFFER_SEQ, --2022/10/14 SR255529_PN折扣對應修改
                PKG_ID,
                CHARGE_CODE,
                SUM(AMOUNT) AMOUNT,
                SOURCE,
                MAX(CHRG_DATE) CHRG_DATE,
                MIN(CI_SEQ) CI_SEQ,
                DECODE(SOURCE,'OC',NVL(DECODE(MAX(NVL(CORRECT_SEQ,0)),0,0,MAX(NVL(CORRECT_SEQ,0))+1),1),0) CORRECT_SEQ,
                'Is prorated=false#PN_IND=Y' DYNAMIC_ATTRIBUTE,
                DECODE(SOURCE,'UC',DECODE(SIGN(SUM(AMOUNT)),-1,'DE','RA'),'DE','DE','CC') CHARGE_ORG,
                DECODE(SOURCE,'RC',gdBILL_FROM_DATE,NULL) CHRG_FROM_DATE,
                DECODE(SOURCE,'RC',gdBILL_END_DATE,NULL) CHRG_END_DATE
           FROM FY_TB_BL_BILL_CI_TEST A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND ACCT_ID     =gnACCT_ID
           -- AND (SOURCE='UC' OR (SOURCE<>'UC' AND CORRECT_CI_SEQ IS NULL))
            AND gvPROC_TYPE ='T'
            AND BILL_SUBSCR_ID<>SUBSCR_ID 
			AND SOURCE != 'DE'  --2024/05/29 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1，修改折扣group條件			
          GROUP BY BILL_SUBSCR_ID,CHARGE_CODE,SOURCE,OFFER_ID,PKG_ID  --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
        UNION --2024/05/29 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1，修改折扣group條件
         SELECT BILL_SUBSCR_ID,
                OFFER_ID,
                OFFER_INSTANCE_ID, --2022/10/14 SR255529_PN折扣對應修改
                OFFER_SEQ, --2022/10/14 SR255529_PN折扣對應修改
                PKG_ID,
                MAX(CHARGE_CODE) CHARGE_CODE,
                SUM(AMOUNT) AMOUNT,
                SOURCE,
                MAX(CHRG_DATE) CHRG_DATE,
                MIN(CI_SEQ) CI_SEQ,
                DECODE(SOURCE,'OC',NVL(DECODE(MAX(NVL(CORRECT_SEQ,0)),0,0,MAX(NVL(CORRECT_SEQ,0))+1),1),0) CORRECT_SEQ,
                'Is prorated=false#PN_IND=Y' DYNAMIC_ATTRIBUTE,
                DECODE(SOURCE,'UC',DECODE(SIGN(SUM(AMOUNT)),-1,'DE','RA'),'DE','DE','CC') CHARGE_ORG,
                DECODE(SOURCE,'RC',gdBILL_FROM_DATE,NULL) CHRG_FROM_DATE,
                DECODE(SOURCE,'RC',gdBILL_END_DATE,NULL) CHRG_END_DATE
           FROM FY_TB_BL_BILL_CI A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND ACCT_ID     =gnACCT_ID
           -- AND (SOURCE='UC' OR (SOURCE<>'UC' AND CORRECT_CI_SEQ IS NULL))
            AND gvPROC_TYPE ='T'
            AND BILL_SUBSCR_ID<>SUBSCR_ID  
			AND SOURCE = 'DE'  
			AND PKG_ID IN (SELECT PKG_ID FROM FY_TB_BL_ACCT_PKG A, FY_TB_PBK_OFFER B WHERE A.OFFER_ID = B.OFFER_ID AND B.PRODUCT_TYPE = 'I')
         -- GROUP BY BILL_SUBSCR_ID,OFFER_ID,CHARGE_CODE,DYNAMIC_ATTRIBUTE,SOURCE 
         -- GROUP BY BILL_SUBSCR_ID,SOURCE,OFFER_ID,PKG_ID
			GROUP BY BILL_SUBSCR_ID,CHARGE_CODE,SOURCE,OFFER_ID,PKG_ID,OFFER_INSTANCE_ID,OFFER_SEQ
        UNION
         SELECT BILL_SUBSCR_ID,
                OFFER_ID,
                MAX(OFFER_INSTANCE_ID) OFFER_INSTANCE_ID, --2022/10/14 SR255529_PN折扣對應修改
                MAX(OFFER_SEQ) OFFER_SEQ, --2022/10/14 SR255529_PN折扣對應修改
                PKG_ID,
                MAX(CHARGE_CODE) CHARGE_CODE,
                SUM(AMOUNT) AMOUNT,
                SOURCE,
                MAX(CHRG_DATE) CHRG_DATE,
                MIN(CI_SEQ) CI_SEQ,
                DECODE(SOURCE,'OC',NVL(DECODE(MAX(NVL(CORRECT_SEQ,0)),0,0,MAX(NVL(CORRECT_SEQ,0))+1),1),0) CORRECT_SEQ,
                'Is prorated=false#PN_IND=Y' DYNAMIC_ATTRIBUTE,
                DECODE(SOURCE,'UC',DECODE(SIGN(SUM(AMOUNT)),-1,'DE','RA'),'DE','DE','CC') CHARGE_ORG,
                DECODE(SOURCE,'RC',gdBILL_FROM_DATE,NULL) CHRG_FROM_DATE,
                DECODE(SOURCE,'RC',gdBILL_END_DATE,NULL) CHRG_END_DATE
           FROM FY_TB_BL_BILL_CI A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND ACCT_ID     =gnACCT_ID
           -- AND (SOURCE='UC' OR (SOURCE<>'UC' AND CORRECT_CI_SEQ IS NULL))
            AND gvPROC_TYPE ='T'
            AND BILL_SUBSCR_ID<>SUBSCR_ID  
			AND SOURCE = 'DE'  
			AND PKG_ID NOT IN (SELECT PKG_ID FROM FY_TB_BL_ACCT_PKG A, FY_TB_PBK_OFFER B WHERE A.OFFER_ID = B.OFFER_ID AND B.PRODUCT_TYPE = 'I')
         -- GROUP BY BILL_SUBSCR_ID,OFFER_ID,CHARGE_CODE,DYNAMIC_ATTRIBUTE,SOURCE 
         -- GROUP BY BILL_SUBSCR_ID,SOURCE,OFFER_ID,PKG_ID
			GROUP BY BILL_SUBSCR_ID,CHARGE_CODE,SOURCE,OFFER_ID,PKG_ID;
          
      CURSOR C_UC IS
         SELECT SUBSCR_ID,
                OFFER_ID,
                CHARGE_CODE,
              --  NVL(CET,CHARGE_CODE) CHARGE_CODE,
                SUM(AMOUNT) AMOUNT,
                DECODE(SIGN(AMOUNT),-1,'DE','RA') CHARGE_ORG, --2020/06/30 MODIFY FOR MPBS_Migration ADD DE
                'UC' SOURCE,
                MAX(CHRG_DATE) CHRG_DATE,
                MIN(CI_SEQ) CI_SEQ,
                DYNAMIC_ATTRIBUTE --2019/06/30 MODIFY FY_TB_BL_BILL_BI add UC DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
           FROM FY_TB_BL_BILL_CI A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND ACCT_ID     =gnACCT_ID
            AND SOURCE      ='UC'
            AND gvPROC_TYPE ='B'
            --AND CREATE_USER != 'MPBL'
            AND (BILL_SUBSCR_ID IS NULL OR BILL_SUBSCR_ID=SUBSCR_ID)  --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
          GROUP BY SUBSCR_ID,OFFER_ID,CHARGE_CODE,DYNAMIC_ATTRIBUTE,DECODE(SIGN(AMOUNT),-1,'DE','RA')  --NVL(CET,CHARGE_CODE) --2019/06/30 MODIFY FY_TB_BL_BILL_BI add UC DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI --2020/06/30 MODIFY FOR MPBS_Migration ADD DE
        UNION
         SELECT SUBSCR_ID,
                OFFER_ID,
                CHARGE_CODE,
              --  NVL(CET,CHARGE_CODE) CHARGE_CODE,
                SUM(AMOUNT) AMOUNT,
                DECODE(SIGN(AMOUNT),-1,'DE','RA') CHARGE_ORG, --2020/06/30 MODIFY FOR MPBS_Migration ADD DE
                'UC' SOURCE,
                MAX(CHRG_DATE) CHRG_DATE,
                MIN(CI_SEQ) CI_SEQ,
                DYNAMIC_ATTRIBUTE --2019/06/30 MODIFY FY_TB_BL_BILL_BI add UC DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
           FROM FY_TB_BL_BILL_CI_TEST A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND ACCT_ID     =gnACCT_ID
            AND SOURCE      ='UC'
            AND gvPROC_TYPE ='T'
            --AND CREATE_USER != 'MPBL'
            AND (BILL_SUBSCR_ID IS NULL OR BILL_SUBSCR_ID=SUBSCR_ID)  --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
          GROUP BY SUBSCR_ID,OFFER_ID,CHARGE_CODE,DYNAMIC_ATTRIBUTE,DECODE(SIGN(AMOUNT),-1,'DE','RA');  --NVL(CET,CHARGE_CODE); --2019/06/30 MODIFY FY_TB_BL_BILL_BI add UC DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI --2020/06/30 MODIFY FOR MPBS_Migration ADD DE

      CURSOR C_OC IS
         SELECT CI_SEQ,
                OU_ID,
                SUBSCR_ID,
                OFFER_ID,
                OFFER_SEQ,
                OFFER_INSTANCE_ID,
                PKG_ID,
                CHARGE_CODE,
                CHRG_DATE,
                CHRG_FROM_DATE,
                CHRG_END_DATE,
                AMOUNT,
                SERVICE_RECEIVER_TYPE,
                --DECODE(SOURCE,'OC',DYNAMIC_ATTRIBUTE,NULL) DYNAMIC_ATTRIBUTE, --2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                DYNAMIC_ATTRIBUTE, --2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                --DECODE(SOURCE,'DE',DYNAMIC_ATTRIBUTE,NULL) OFFER_NAME, --2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                NULL OFFER_NAME, --2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                DECODE(SOURCE,'DE','DE','CC') CHARGE_ORG ,
                SOURCE
           FROM FY_TB_BL_BILL_CI A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND ACCT_ID     =gnACCT_ID
            AND SOURCE     <>'UC'
            AND CORRECT_CI_SEQ IS NULL
            AND gvPROC_TYPE ='B'
            AND (BILL_SUBSCR_ID IS NULL OR BILL_SUBSCR_ID=SUBSCR_ID)  --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
        UNION
         SELECT CI_SEQ,
                OU_ID,
                SUBSCR_ID,
                OFFER_ID,
                OFFER_SEQ,
                OFFER_INSTANCE_ID,
                PKG_ID,
                CHARGE_CODE,
                CHRG_DATE,
                CHRG_FROM_DATE,
                CHRG_END_DATE,
                AMOUNT,
                SERVICE_RECEIVER_TYPE,
                --DECODE(SOURCE,'OC',DYNAMIC_ATTRIBUTE,NULL) DYNAMIC_ATTRIBUTE, --2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                DYNAMIC_ATTRIBUTE, --2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                --DECODE(SOURCE,'DE',DYNAMIC_ATTRIBUTE,NULL) OFFER_NAME, --2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                NULL OFFER_NAME, --2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                DECODE(SOURCE,'DE','DE','CC') CHARGE_ORG ,
                SOURCE
           FROM FY_TB_BL_BILL_CI_TEST A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND ACCT_ID     =gnACCT_ID
            AND SOURCE     <>'UC'
            AND CORRECT_CI_SEQ IS NULL
            AND gvPROC_TYPE ='T'
            AND (BILL_SUBSCR_ID IS NULL OR BILL_SUBSCR_ID=SUBSCR_ID)  --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
          ORDER BY CI_SEQ;

      NU_BI_SEQ          NUMBER;
      NU_CORRECT_AMT     NUMBER;
      NU_MAX_CORRECT     NUMBER;
      NU_CNT             NUMBER;
      On_Err             EXCEPTION;
   BEGIN
      --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 ADD GET PN
      gnSUBSCR_ID := NULL;
      FOR R_PN IN C_PN LOOP
         gnSUBSCR_ID := R_PN.BILL_SUBSCR_ID;
         gnOU_ID     := NULL;
         --0元不處理
         IF R_PN.AMOUNT<>0 THEN
            gvSTEP := 'PN INS_BI:';
            INS_BI(R_PN.CHARGE_CODE,
                   R_PN.CHARGE_ORG,
                   R_PN.AMOUNT ,
                   NULL,     --TAX_AMT
                   R_PN.OFFER_INSTANCE_ID,     --OFFER_INSTANCE_ID --2022/10/14 SR255529_PN折扣對應修改
                   R_PN.OFFER_SEQ,     --OFFER_SEQ, --2022/10/14 SR255529_PN折扣對應修改
                   R_PN.OFFER_ID ,
                   R_PN.PKG_ID,   --PKG_ID
                   R_PN.SOURCE,
                   R_PN.CHRG_DATE,
                   R_PN.CHRG_FROM_DATE,
                   R_PN.CHRG_END_DATE,
                   NULL,   --PI_CHARGE_DESCR ,
                   'S',    --SERVICE_RECEIVER_TYPE,
                   R_PN.DYNAMIC_ATTRIBUTE,  
                   R_PN.CORRECT_SEQ,     --PI_CORRECT_SEQ ,
                   R_PN.CI_SEQ,
                   NU_BI_SEQ );
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR('UC INS_BI:'||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;
            --UDPATE BILL_CI
            gvSTEP := 'UPDATE PN BL_BILL_CI_'||gvPROC_TYPE||':';
            IF gvPROC_TYPE='T' THEN --測試
               UPDATE FY_TB_BL_BILL_CI_TEST SET BI_SEQ      =NU_BI_SEQ,
                                                UPDATE_DATE =SYSDATE,
                                                UPDATE_USER =gvUSER
                                      WHERE BILL_SEQ         =gnBILL_SEQ
                                        AND CYCLE            =gnCYCLE
                                        AND CYCLE_MONTH      =gnCYCLE_MONTH
                                        AND ACCT_KEY         =MOD(gnACCT_ID,100)
                                        AND ACCT_ID          =gnACCT_ID
                                        AND SOURCE           =R_PN.SOURCE
                                        AND BILL_SUBSCR_ID   <>SUBSCR_ID
                                        AND BILL_SUBSCR_ID   =R_PN.BILL_SUBSCR_ID
                                        AND CHARGE_CODE      =R_PN.CHARGE_CODE;
            ELSE
               UPDATE FY_TB_BL_BILL_CI SET BI_SEQ      =NU_BI_SEQ,
                                           UPDATE_DATE =SYSDATE,
                                           UPDATE_USER =gvUSER
                                      WHERE BILL_SEQ         =gnBILL_SEQ
                                        AND CYCLE            =gnCYCLE
                                        AND CYCLE_MONTH      =gnCYCLE_MONTH
                                        AND ACCT_KEY         =MOD(gnACCT_ID,100)
                                        AND SOURCE           =R_PN.SOURCE
                                        AND BILL_SUBSCR_ID   <>SUBSCR_ID
                                        AND BILL_SUBSCR_ID   =R_PN.BILL_SUBSCR_ID
                                        AND CHARGE_CODE      =R_PN.CHARGE_CODE;
            END IF;
         END IF;  -- R_PN.AMOUNT<>0
      END LOOP;  --C_PN  --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
      
      --GET UC
      FOR R_UC IN C_UC LOOP
         gnSUBSCR_ID := R_UC.SUBSCR_ID;
         gnOU_ID     := NULL;
         --0元不處理
         IF R_UC.AMOUNT<>0 THEN
            gvSTEP := 'UC INS_BI:';
            INS_BI(R_UC.CHARGE_CODE,
                   R_UC.CHARGE_ORG ,
                   R_UC.AMOUNT ,
                   NULL,     --TAX_AMT
                   NULL,     --OFFER_INSTANCE_ID
                   NULL,     --OFFER_SEQ,
                   R_UC.OFFER_ID ,
                   NULL,   --PKG_ID
                   R_UC.SOURCE,
                   R_UC.CHRG_DATE,
                   NULL,   --CHRG_FROM_DATE,
                   NULL,   --CHRG_END_DATE,
                   NULL,  --PI_CHARGE_DESCR ,
                   'S',   --SERVICE_RECEIVER_TYPE,
                   R_UC.DYNAMIC_ATTRIBUTE,  --DYNAMIC_ATTRIBUTE, --2019/06/30 MODIFY FY_TB_BL_BILL_BI add UC DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                   0,     --PI_CORRECT_SEQ ,
                   R_UC.CI_SEQ,
                   NU_BI_SEQ );
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR('UC INS_BI:'||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;
            --UDPATE BILL_CI
            gvSTEP := 'UPDATE UC BL_BILL_CI_'||gvPROC_TYPE||':';
            IF gvPROC_TYPE='T' THEN --測試
               UPDATE FY_TB_BL_BILL_CI_TEST SET BI_SEQ      =NU_BI_SEQ,
                                                UPDATE_DATE =SYSDATE,
                                                UPDATE_USER =gvUSER
                                      WHERE BILL_SEQ    =gnBILL_SEQ
                                        AND CYCLE       =gnCYCLE
                                        AND CYCLE_MONTH =gnCYCLE_MONTH
                                        AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
                                        AND ACCT_ID     =gnACCT_ID
                                        AND SOURCE      ='UC'
                                        AND SUBSCR_ID   =R_UC.SUBSCR_ID
                                        AND OFFER_ID    =R_UC.OFFER_ID
                                       -- AND CET         =R_UC.CHARGE_CODE;
                                        AND CHRG_DATE   =R_UC.CHRG_DATE --2021/02/23 MODIFY FOR MPBS_Migration 修正同回壓CI.BI_SEQ準確性
                                        AND CHARGE_CODE =R_UC.CHARGE_CODE
                                        AND (BILL_SUBSCR_ID IS NULL OR BILL_SUBSCR_ID=SUBSCR_ID);  --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
            ELSE
               UPDATE FY_TB_BL_BILL_CI SET BI_SEQ      =NU_BI_SEQ,
                                           UPDATE_DATE =SYSDATE,
                                           UPDATE_USER =gvUSER
                                     WHERE BILL_SEQ    =gnBILL_SEQ
                                       AND CYCLE       =gnCYCLE
                                       AND CYCLE_MONTH =gnCYCLE_MONTH
                                       AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
                                       AND ACCT_ID     =gnACCT_ID
                                       AND SOURCE      ='UC'
                                       AND SUBSCR_ID   =R_UC.SUBSCR_ID
                                       AND OFFER_ID    =R_UC.OFFER_ID
                                     --  AND CET         =R_UC.CHARGE_CODE;
                                       AND CHRG_DATE   =R_UC.CHRG_DATE --2021/02/23 MODIFY FOR MPBS_Migration 修正同回壓CI.BI_SEQ準確性
                                       AND CHARGE_CODE =R_UC.CHARGE_CODE
                                       AND (BILL_SUBSCR_ID IS NULL OR BILL_SUBSCR_ID=SUBSCR_ID);  --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
            END IF;
         END IF;  -- R_UC.AMOUNT<>0
      END LOOP;  --C_UC

      --GET OC/RC
      FOR R_OC IN C_OC LOOP
         gnSUBSCR_ID := R_OC.SUBSCR_ID;
         gnOU_ID     := R_OC.OU_ID;
         IF R_OC.SOURCE='OC' AND gvUSER!='MPBL' THEN --2020/06/30 MODIFY FOR MPBS_Migration 使MPBL不產生CORRECT_SEQ=1
            IF gvPROC_TYPE='T' THEN --測試
               --CORRECT_AMT, MAX_CORRECT
               SELECT NVL(SUM(AMOUNT),0), NVL(DECODE(MAX(NVL(CORRECT_SEQ,0)),0,0,MAX(NVL(CORRECT_SEQ,0))+1),1)
                 INTO NU_CORRECT_AMT, NU_MAX_CORRECT
                 FROM FY_TB_BL_BILL_CI_TEST
                WHERE BILL_SEQ      =gnBILL_SEQ
                  AND CYCLE         =gnCYCLE
                  AND CYCLE_MONTH   =gnCYCLE_MONTH
                  AND ACCT_KEY      =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
                  AND ACCT_ID       =gnACCT_ID
                  AND SOURCE        ='OC'
                  AND CORRECT_CI_SEQ=R_OC.CI_SEQ;
            ELSE
               --CORRECT_AMT, MAX_CORRECT
               SELECT NVL(SUM(AMOUNT),0), NVL(DECODE(MAX(NVL(CORRECT_SEQ,0)),0,0,MAX(NVL(CORRECT_SEQ,0))+1),1)
                 INTO NU_CORRECT_AMT, NU_MAX_CORRECT
                 FROM FY_TB_BL_BILL_CI
                WHERE BILL_SEQ      =gnBILL_SEQ
                  AND CYCLE         =gnCYCLE
                  AND CYCLE_MONTH   =gnCYCLE_MONTH
                  AND ACCT_KEY      =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
                  AND ACCT_ID       =gnACCT_ID
                  AND SOURCE        ='OC'
                  AND CORRECT_CI_SEQ=R_OC.CI_SEQ;
            END IF;
         ELSE
            NU_CORRECT_AMT := 0;
            NU_MAX_CORRECT := 0;
         END IF;

         --2020/06/30 MODIFY FOR MPBS_Migration 增加小數位reject
         IF ROUND(R_OC.AMOUNT,0) <> R_OC.AMOUNT AND gvUSER='MPBL' THEN
            gvErr_Cde := 'B002';
            gvSTEP := 'CI中有非整數Charge';
            RAISE ON_ERR;
         END IF;

         --0元不處理
         IF R_OC.AMOUNT+NU_CORRECT_AMT<>0 THEN
            gvSTEP := 'OC INS_BI:';
            INS_BI(R_OC.CHARGE_CODE,
                   R_OC.CHARGE_ORG ,
                   R_OC.AMOUNT+NU_CORRECT_AMT,
                   NULL,     --TAX_AMT
                   R_OC.OFFER_INSTANCE_ID,
                   R_OC.OFFER_SEQ,
                   R_OC.OFFER_ID ,
                   R_OC.PKG_ID,
                   R_OC.SOURCE,
                   R_OC.CHRG_DATE,
                   R_OC.CHRG_FROM_DATE,
                   R_OC.CHRG_END_DATE,
                   R_OC.OFFER_NAME, --PI_CHARGE_DESCR
                   R_OC.SERVICE_RECEIVER_TYPE,
                   R_OC.DYNAMIC_ATTRIBUTE,
                   NU_MAX_CORRECT,  --CORRECT_SEQ ,
                   R_OC.CI_SEQ  ,
                   NU_BI_SEQ);
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR('OC INS_BI:'||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;

            --UDPATE BILL_CI
            gvSTEP := 'UPDATE OC BL_BILL_CI_'||gvPROC_TYPE||'.CI_SEQ='||TO_CHAR(R_OC.CI_SEQ)||':';
            IF gvPROC_TYPE='T' THEN --測試
               UPDATE FY_TB_BL_BILL_CI_TEST SET BI_SEQ      =NU_BI_SEQ,
                                                UPDATE_DATE =SYSDATE,
                                                UPDATE_USER =gvUSER
                              WHERE BILL_SEQ    =gnBILL_SEQ
                                AND CYCLE       =gnCYCLE
                                AND CYCLE_MONTH =gnCYCLE_MONTH
                                AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
                                AND ACCT_ID     =gnACCT_ID
                                AND SOURCE     <>'UC'
                                AND (CI_SEQ=R_OC.CI_SEQ OR CORRECT_CI_SEQ=R_OC.CI_SEQ)
                                AND (BILL_SUBSCR_ID IS NULL OR BILL_SUBSCR_ID=SUBSCR_ID);  --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
            ELSE
               UPDATE FY_TB_BL_BILL_CI SET BI_SEQ      =NU_BI_SEQ,
                                           UPDATE_DATE =SYSDATE,
                                           UPDATE_USER =gvUSER
                              WHERE BILL_SEQ    =gnBILL_SEQ
                                AND CYCLE       =gnCYCLE
                                AND CYCLE_MONTH =gnCYCLE_MONTH
                                AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
                                AND ACCT_ID     =gnACCT_ID
                                AND SOURCE    <>'UC'
                                AND (CI_SEQ=R_OC.CI_SEQ OR CORRECT_CI_SEQ=R_OC.CI_SEQ)
                                AND (BILL_SUBSCR_ID IS NULL OR BILL_SUBSCR_ID=SUBSCR_ID);  --2021/06/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
            END IF;
         END IF; --R_OC.AMOUNT+NU_CORRECT_AMT
      END LOOP;  --C_OC
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END GEN_BI;

   /*************************************************************************
      PROCEDURE : INS_BI
      PURPOSE :   寫計價項目(BI)至 BILL_BI
      DESCRIPTION : 寫計價項目(BI)至 BILL_BI
      PARAMETER:
            PI_CHARGE_CODE             :帳單項目
            PI_CHARGE_ORG              :RA/CC/DE/IN
            PI_AMOUNT                  :金額
            PI_TAX_AMT                 :稅額(PI_CHARGE_ORG=IN)
            PI_OFFER_INSTANCE_ID       :OFFER_INSTANCE_ID
            PI_OFFER_SEQ               :OFFER_SEQ
            PI_OFFER_ID                :OFFER 編號
            PI_PKG_ID                  :PKG_ID
            PI_SOURCE                  :RC/OC/UC/DE/IN
            PI_CHRG_DATE               :計費日期
            PI_CHRG_FROM_DATE          :計費起始日
            PI_CHRG_END_DATE           :計費截止日
            PI_CHARGE_DESCR            :中文說明(CHARGE_CODE)
            PI_SERVICE_RECEIVER_TYPE   :費用歸屬階層(A/O/S)
            PI_DYNAMIC_ATTRIBUTE       :DYNAMIC_ATTRIBUTE
            PI_CORRECT_SEQ             :MAX(CORRECT_SEQ)
            PI_CI_SEQ                  :CI_SEQ
            PO_BI_SEQ                  :BI_SEQ
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
   **************************************************************************/
   PROCEDURE INS_BI(PI_CHARGE_CODE             IN    VARCHAR2,
                    PI_CHARGE_ORG              IN    VARCHAR2,
                    PI_AMOUNT                  IN    NUMBER,
                    PI_TAX_AMT                 IN    NUMBER,
                    PI_OFFER_INSTANCE_ID       IN    NUMBER,
                    PI_OFFER_SEQ               IN    NUMBER,
                    PI_OFFER_ID                IN    NUMBER,
                    PI_PKG_ID                  IN    NUMBER,
                    PI_SOURCE                  IN    VARCHAR2,
                    PI_CHRG_DATE               IN    DATE,
                    PI_CHRG_FROM_DATE          IN    DATE,
                    PI_CHRG_END_DATE           IN    DATE,
                    PI_CHARGE_DESCR            IN    VARCHAR2,
                    PI_SERVICE_RECEIVER_TYPE   IN    VARCHAR2,
                    PI_DYNAMIC_ATTRIBUTE       IN    VARCHAR2,
                    PI_CORRECT_SEQ             IN    NUMBER,
                    PI_CI_SEQ                  IN    NUMBER,
                    PO_BI_SEQ                 OUT    NUMBER) IS

      CURSOR C1 IS
         SELECT DECODE(A.INIT_PKG_QTY,NULL,B.QUOTA,A.INIT_PKG_QTY) INIT_PKG_QTY,
                DECODE(gvPROC_TYPE,'B',(A.BILL_USE_QTY+A.BILL_BAL_QTY),(A.TEST_USE_QTY+A.TEST_BAL_QTY)) BAL_QTY, --2021/06/15 MODIFY FOR 小額預繳處理 由BILL_QTY改取BILL_BAL_QTY --2022/04/08 MODIFY FOR 425帳單4G預繳餘額顯示
                B.PRORATE_METHOD,
                DECODE(B.VALIDITY_METHOD,'T','Y','N') OccurrenceInd
           FROM FY_TB_BL_ACCT_PKG A,
                FY_TB_PBK_PKG_DISCOUNT B
          WHERE A.ACCT_ID  =gnACCT_ID
            AND ACCT_KEY   =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND A.OFFER_SEQ=PI_OFFER_SEQ
            AND A.PKG_ID   =PI_PKG_ID
            AND A.PREPAYMENT IS NOT NULL
            AND B.PKG_ID   =A.PKG_ID;
      R1                C1%ROWTYPE;

      CH_CHARGE_TYPE      FY_TB_BL_BILL_CI.CHARGE_TYPE%TYPE;
      CH_TAX_RATE         FY_TB_PBK_CHARGE_CODE.TAX_RATE%TYPE;
      CH_CHARGE_DESCR     FY_TB_PBK_CHARGE_CODE.DSCR%TYPE;
      NU_RATE_TAX         NUMBER;
      NU_TAX_AMT          NUMBER;
      NU_BILL_AMT         NUMBER;
      NU_BILL_TAX_AMT     NUMBER;
      NU_BILL_RATE        NUMBER;
      NU_BI_SEQ           NUMBER;
      --NU_SUB_TAX_CNT      NUMBER; --2019/12/31 MODIFY overwrite SUB TAX_TYPE & LOOKUP_CODE TAX_RATE ACCOUNT (CANCEL)
      NU_ACCOUNT          NUMBER; --TAX_RATE --2021/04/29 MODIFY FOR SR237202_AWS在HGB 設定美金零稅率(特殊專案設定)
      NU_CNT              NUMBER;
      On_Err              EXCEPTION;
   BEGIN
      IF gvPROC_TYPE='T' THEN --測試
         --GET BI_SEQ
         SELECT FY_SQ_BL_BILL_BI_TEST.NEXTVAL
           INTO NU_BI_SEQ
           FROM DUAL;
      ELSE
         --GET BI_SEQ
         SELECT FY_SQ_BL_BILL_BI.NEXTVAL
           INTO NU_BI_SEQ
           FROM DUAL;
      END IF;
      --CHARGE_TYPE
      IF PI_CHARGE_ORG='DE' AND PI_SOURCE != 'UC' THEN --2020/06/30 MODIFY FOR MPBS_Migration ADD SOURCE != 'UC'
         CH_CHARGE_TYPE := 'DSC';
      ELSIF PI_AMOUNT>=0 THEN
         CH_CHARGE_TYPE := 'DBT';
      ELSE
         CH_CHARGE_TYPE := 'CRD';
      END IF;

      ----GET SUBSCRIBER TAX_RATE COUNT by OFFER_PARAM --2019/12/31 MODIFY overwrite SUB TAX_TYPE & LOOKUP_CODE TAX_RATE ACCOUNT (CANCEL)
      --DBMS_OUTPUT.Put_Line(' ACCT_ID='||TO_CHAR(gnACCT_ID)||' BILL_SEQ='||TO_CHAR(gnBILL_SEQ)||' SUBSCR_ID='||TO_CHAR(gnSUBSCR_ID));
      --gvSTEP := 'GET SUB_TAX_RATE.OFFER_SEQ='||PI_OFFER_SEQ||':';
      --  SELECT count(1)
      --  INTO NU_SUB_TAX_CNT
      --      FROM   fy_tb_sys_lookup_code lc, fy_tb_bl_bill_offer_param op, fy_tb_bl_acct_pkg ap
      --      WHERE op.acct_id = gnACCT_ID
      --      AND op.bill_seq = gnBILL_SEQ
      --      AND op.param_name = 'TAX_TYPE'
      --      AND ap.OFFER_LEVEL = 'S'
      --      AND ap.OFFER_LEVEL_ID = gnSUBSCR_ID
      --      AND lc.lookup_type = op.param_name
      --      AND lc.lookup_code = op.param_value
      --      AND op.offer_instance_id = ap.offer_instance_id
      --      AND op.offer_seq = ap.offer_seq
      --      AND op.param_value = (SELECT DISTINCT FIRST_VALUE (param_value) OVER (PARTITION BY acct_id ORDER BY eff_date DESC) AS latest_value
      --                          FROM fy_tb_bl_bill_offer_param WHERE acct_id = gnACCT_ID)
      --                          ;
      --DBMS_OUTPUT.Put_Line('SUB_TAX_CNT='||TO_CHAR(NU_SUB_TAX_CNT));
      --
      --GET TAX_RATE
      gvSTEP := 'GET TAX_RATE.CHARGE_CODE='||PI_CHARGE_CODE||':';
      SELECT CC.TAX_RATE, DECODE(PI_CHARGE_DESCR,NULL,CC.DSCR,PI_CHARGE_DESCR),
             LC.NUM1
        INTO CH_TAX_RATE, CH_CHARGE_DESCR, NU_RATE_TAX
        FROM FY_TB_PBK_CHARGE_CODE CC,
             FY_TB_SYS_LOOKUP_CODE LC
       WHERE CC.CHARGE_CODE=PI_CHARGE_CODE
         AND LC.LOOKUP_TYPE='TAX_TYPE'
         AND LC.LOOKUP_CODE=CC.TAX_RATE
         AND CC.REVENUE_CODE<>'CET';
       --  AND ((PI_SOURCE='UC' AND CC.REVENUE_CODE='CET') OR
       --       (PI_SOURCE<>'UC' AND CC.REVENUE_CODE<>'CET'));
      --
      ----GET SUBSCRIBER TAX_RATE by OFFER_PARAM --2019/12/31 MODIFY overwrite SUB TAX_TYPE & LOOKUP_CODE TAX_RATE ACCOUNT (CANCEL)
      --IF NU_SUB_TAX_CNT = 1 AND PI_CHARGE_ORG != 'IN' THEN
      --SELECT op.param_value, lc.num1
      --  INTO CH_TAX_RATE, NU_RATE_TAX
      --      FROM   fy_tb_sys_lookup_code lc, fy_tb_bl_bill_offer_param op, fy_tb_bl_acct_pkg ap
      --      WHERE op.acct_id = gnACCT_ID
      --      AND op.bill_seq = gnBILL_SEQ
      --      AND op.param_name = 'TAX_TYPE'
      --      AND ap.OFFER_LEVEL = 'S'
      --      AND ap.OFFER_LEVEL_ID = gnSUBSCR_ID
      --      AND lc.lookup_type = op.param_name
      --      AND lc.lookup_code = op.param_value
      --      AND op.offer_instance_id = ap.offer_instance_id
      --      AND op.offer_seq = ap.offer_seq
      --      AND op.param_value = (SELECT DISTINCT FIRST_VALUE (param_value) OVER (PARTITION BY acct_id ORDER BY eff_date DESC) AS latest_value
      --                          FROM fy_tb_bl_bill_offer_param WHERE acct_id = gnACCT_ID);
      --END IF;
      --
      --2023/04/20 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增電信業者轉換稅率功能
      BEGIN
        IF gnCYCLE IN ('10','15','20') THEN --2024/12/03 MODIFY FOR SR273784_[6240]_Project M Fixed Line Phase II 整合專案，增加稅率轉換FOREIGN_REMITTANCE條件
          SELECT count(entity_id)
          INTO NU_ACCOUNT
            FROM fy_tb_cm_attribute_param
           WHERE entity_type = 'A'
           AND entity_id = gnACCT_ID
           AND attribute_name = 'FOREIGN_REMITTANCE'
           AND attribute_value = 'Y';
        END IF;
	  
        IF PI_CHARGE_CODE LIKE '%_TAX' AND NU_ACCOUNT > 0 THEN --need change to charge_code ('%_TAX') --2024/12/03 MODIFY FOR SR273784_[6240]_Project M Fixed Line Phase II 整合專案，增加稅率轉換FOREIGN_REMITTANCE條件
                     DBMS_OUTPUT.Put_Line(' 2TAX_RATE='||TO_CHAR(CH_TAX_RATE)||' 2RATE_TAX='||TO_CHAR(NU_RATE_TAX));
            --SELECT DECODE (elem5, 21, DECODE (CH_TAX_RATE, 'TX1', 'TX2', 'TX1'), CH_TAX_RATE) TAX_RATE,DECODE (elem5, 21, DECODE (NU_RATE_TAX, 0, 5, 0), NU_RATE_TAX) RATE_TAX
            SELECT DECODE (elem5, 0, DECODE(CH_TAX_RATE, 'TX2', 'TX1', 'TX1', 'TX2', CH_TAX_RATE), 21, DECODE (CH_TAX_RATE, 'TX2', 'TX1', 'TX1', 'TX2', CH_TAX_RATE), CH_TAX_RATE) TAX_RATE,DECODE (elem5, 0, DECODE (NU_RATE_TAX, 0, 5, 5, 0, NU_RATE_TAX), 21, DECODE (NU_RATE_TAX, 0, 5, 5, 0, NU_RATE_TAX), NU_RATE_TAX) RATE_TAX
            INTO CH_TAX_RATE, NU_RATE_TAX
              FROM fy_tb_cm_prof_link
             WHERE prof_type = 'NAME'
             AND entity_type = 'A'
             AND link_type = 'A'
             AND entity_id = gnACCT_ID;
        END IF;
      EXCEPTION WHEN OTHERS THEN
          CH_TAX_RATE :=CH_TAX_RATE;
          NU_RATE_TAX :=NU_RATE_TAX;
		  NU_ACCOUNT :=0;
      END;

      --TAX_RATE --2021/04/29 MODIFY FOR SR237202_AWS在HGB 設定美金零稅率(特殊專案設定)
      BEGIN
      --    SELECT CH1
      --    INTO NU_ACCOUNT
      --    FROM FY_TB_SYS_LOOKUP_CODE
      --    WHERE LOOKUP_TYPE='TAX_RATE'
      --        AND LOOKUP_CODE='ACCOUNT';
        IF gnCYCLE IN ('10','15','20') THEN --2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CYCLE(15,20)
          SELECT count(entity_id)
          INTO NU_ACCOUNT
            FROM fy_tb_cm_attribute_param
           WHERE entity_type = 'A'
           AND entity_id = gnACCT_ID
           AND attribute_name = 'CHANGE_ZERO_TAX'
           AND attribute_value = 'Y';
        END IF;
      EXCEPTION WHEN OTHERS THEN
          NU_ACCOUNT :=0;
      END;      
      --
      IF NU_ACCOUNT>0 THEN
        SELECT 'TX2' as TAX_RATE, 0 as RATE_TAX
          INTO CH_TAX_RATE, NU_RATE_TAX
         FROM   dual;
         DBMS_OUTPUT.Put_Line(' TAX_RATE='||TO_CHAR(CH_TAX_RATE)||' RATE_TAX='||TO_CHAR(NU_RATE_TAX));
      END IF;

      IF PI_CHARGE_ORG IN ('IN','NN') THEN  --ROUND CHARGE --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
         NU_TAX_AMT := PI_TAX_AMT;
      ELSE
         NU_TAX_AMT := ROUND(PI_AMOUNT/(1+NU_RATE_TAX)*NU_RATE_TAX,2);
      END IF;

      IF PI_CHARGE_ORG = 'NN' THEN --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
         gvBILL_CURRENCY := 'NTD'; --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
      END IF; --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge

      --BILL_CURRENCY處理
      IF gvBILL_CURRENCY NOT IN ('TWD','NTD','USD') THEN --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
         gvSTEP := 'GET_CURRENCY.CURRENCY='||gvBILL_CURRENCY||':';
         GET_CURRENCY(gvBILL_CURRENCY, PI_AMOUNT, NU_BILL_AMT, NU_BILL_RATE, gvERR_CDE, gvERR_MSG);
         IF gvERR_CDE<>'0000' THEN
            gvSTEP := SUBSTR('GET_CURRENCY.CURRENCY='||gvBILL_CURRENCY||':'||gvERR_MSG,1,250);
            RAISE ON_ERR;
         END IF;
      ELSE
         NU_BILL_AMT := PI_AMOUNT;
         NU_BILL_RATE:= 1;
      END IF;

      --BILL_CURRENCY處理 (get NTD from USD) --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
      IF gvBILL_CURRENCY IN ('USD') THEN --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
         gvSTEP := 'GET_NTD_CURRENCY.CURRENCY='||gvBILL_CURRENCY||':';
         GET_NTD_CURRENCY(gvBILL_CURRENCY, PI_AMOUNT, NU_TAX_AMT, NU_BILL_AMT, NU_BILL_TAX_AMT, NU_BILL_RATE, gvERR_CDE, gvERR_MSG);
         IF gvERR_CDE<>'0000' THEN
            gvSTEP := SUBSTR('GET_NTD_CURRENCY.CURRENCY='||gvBILL_CURRENCY||':'||gvERR_MSG,1,250);
            RAISE ON_ERR;
         END IF;
      END IF;

      --DYNAMIC_ATTRIBUTE處理
      gvSTEP := 'DYNAMIC_ATTRIBUTE處理:';
      gvDYNAMIC_ATTRIBUTE  := NULL;
      IF PI_SOURCE='OC' THEN
         gvDYNAMIC_ATTRIBUTE := PI_DYNAMIC_ATTRIBUTE;
      ELSIF PI_SOURCE='UC' THEN
         gvDYNAMIC_ATTRIBUTE := PI_DYNAMIC_ATTRIBUTE||'#Gross amount='||(PI_AMOUNT-NU_TAX_AMT); --2019/06/30 MODIFY FY_TB_BL_BILL_BI add UC DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
      ELSIF PI_SOURCE='RC' THEN
         IF PI_CHRG_FROM_DATE=gdBILL_FROM_DATE AND PI_CHRG_END_DATE=gdBILL_END_DATE THEN
            NU_CNT :=1;
         ELSE
            NU_CNT :=0;
         END IF;
         gvDYNAMIC_ATTRIBUTE := PI_DYNAMIC_ATTRIBUTE||  --2020/06/30 MODIFY FOR MPBS_Migration
                                '#Period start date='||TO_CHAR(PI_CHRG_FROM_DATE,'YYYYMMDD')||
                                '#Period end date='||TO_CHAR(PI_CHRG_END_DATE,'YYYYMMDD')||
                                '#Proration factor='||NU_CNT;
      ELSIF PI_SOURCE='DE' THEN
         gvDYNAMIC_ATTRIBUTE := PI_DYNAMIC_ATTRIBUTE|| --2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                                '#Period start date='||TO_CHAR(PI_CHRG_FROM_DATE,'YYYYMMDD')|| --2020/06/30 MODIFY FOR MPBS_Migration
                                '#Period end date='||TO_CHAR(PI_CHRG_END_DATE,'YYYYMMDD')|| --2020/06/30 MODIFY FOR MPBS_Migration
                                '#Discount package ID='||PI_PKG_ID|| --2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
                                '#Discount offer ID='||PI_OFFER_ID||
                                '#Discount offer Seq No='||PI_OFFER_INSTANCE_ID;
         OPEN C1;
         FETCH C1 INTO R1;
         IF C1%FOUND THEN
           gvDYNAMIC_ATTRIBUTE := gvDYNAMIC_ATTRIBUTE||
                                '#Remaining='||R1.BAL_QTY||
                                '#TotalRolloverAmount='||R1.INIT_PKG_QTY||
                                '#OccurrenceInd='||R1.OccurrenceInd||
                                '#ProratedInd='||R1.PRORATE_METHOD;
         END IF;
         CLOSE C1;
      ELSIF PI_CHARGE_ORG='NN' THEN
         gvDYNAMIC_ATTRIBUTE := 'TO_NTD='||to_char(NU_BILL_AMT,'fm99999999990.99')||'#TO_NTD_TAX='||to_char(NU_TAX_AMT,'fm99999999990.99'); --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
      END IF;

      IF gvBILL_CURRENCY IN ('USD') THEN --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
         gvDYNAMIC_ATTRIBUTE := gvDYNAMIC_ATTRIBUTE||'#CONVERSION_RATE='||NU_BILL_RATE||'#TO_NTD='||to_char(NU_BILL_AMT,'fm99999999990.99')||'#TO_NTD_TAX='||to_char(NU_BILL_TAX_AMT,'fm99999999990.99'); --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
      END IF;

      gvSTEP := 'INSERT BILL_BI_'||gvPROC_TYPE||':';
      IF gvPROC_TYPE='T' THEN --測試
         INSERT INTO FY_TB_BL_BILL_BI_TEST
                          (BI_SEQ,
                           ACCT_ID,
                         --  ACCT_KEY,  為虛擬欄位
                           SUBSCR_ID,
                           OU_ID,
                           CHARGE_CODE,
                           CHARGE_ORG,
                           AMOUNT,
                           CHARGE_TYPE,
                           TAX_TYPE,
                           TAX_AMT,
                           OFFER_SEQ,
                           OFFER_ID,
                           CHRG_DATE,
                           CHRG_FROM_DATE,
                           CHRG_END_DATE,
                           BILL_SEQ,
                           CYCLE,
                           CYCLE_MONTH,
                           BILL_CURRENCY,
                           BILL_AMT,
                           BILL_RATE,
                           CHARGE_DESCR,
                           SERVICE_RECEIVER_TYPE,
                           CORRECT_SEQ,
                           DYNAMIC_ATTRIBUTE,
                           CI_SEQ,
                           CREATE_DATE,
                           CREATE_USER,
                           UPDATE_DATE,
                           UPDATE_USER)
                    VALUES
                          (NU_BI_SEQ,
                           gnACCT_ID,
                         --  MOD(gnACCT_ID,100),
                           gnSUBSCR_ID,
                           gnOU_ID,
                           PI_CHARGE_CODE,
                           PI_CHARGE_ORG,
                           PI_AMOUNT,
                           CH_CHARGE_TYPE,
                           CH_TAX_RATE,
                           NU_TAX_AMT,
                           PI_OFFER_SEQ,
                           PI_OFFER_ID,
                           PI_CHRG_DATE,
                           PI_CHRG_FROM_DATE,
                           PI_CHRG_END_DATE,
                           gnBILL_SEQ,
                           gnCYCLE,
                           gnCYCLE_MONTH,
                           gvBILL_CURRENCY,
                           NU_BILL_AMT,
                           NU_BILL_RATE,
                           CH_CHARGE_DESCR,
                           PI_SERVICE_RECEIVER_TYPE,
                           PI_CORRECT_SEQ,
                           gvDYNAMIC_ATTRIBUTE,
                           PI_CI_SEQ,
                           SYSDATE,
                           gvUSER,
                           SYSDATE,
                           gvUSER);
      ELSE
         INSERT INTO FY_TB_BL_BILL_BI
                          (BI_SEQ,
                           ACCT_ID,
                         --  ACCT_KEY,  為虛擬欄位
                           SUBSCR_ID,
                           OU_ID,
                           CHARGE_CODE,
                           CHARGE_ORG,
                           AMOUNT,
                           CHARGE_TYPE,
                           TAX_TYPE,
                           TAX_AMT,
                           OFFER_SEQ,
                           OFFER_ID,
                           CHRG_DATE,
                           CHRG_FROM_DATE,
                           CHRG_END_DATE,
                           BILL_SEQ,
                           CYCLE,
                           CYCLE_MONTH,
                           BILL_CURRENCY,
                           BILL_AMT,
                           BILL_RATE,
                           CHARGE_DESCR,
                           SERVICE_RECEIVER_TYPE,
                           CORRECT_SEQ,
                           DYNAMIC_ATTRIBUTE,
                           CI_SEQ,
                           CREATE_DATE,
                           CREATE_USER,
                           UPDATE_DATE,
                           UPDATE_USER)
                    VALUES
                          (NU_BI_SEQ,
                           gnACCT_ID,
                          -- MOD(gnACCT_ID,100),
                           gnSUBSCR_ID,
                           gnOU_ID,
                           PI_CHARGE_CODE,
                           PI_CHARGE_ORG,
                           PI_AMOUNT,
                           CH_CHARGE_TYPE,
                           CH_TAX_RATE,
                           NU_TAX_AMT,
                           PI_OFFER_SEQ,
                           PI_OFFER_ID,
                           PI_CHRG_DATE,
                           PI_CHRG_FROM_DATE,
                           PI_CHRG_END_DATE,
                           gnBILL_SEQ,
                           gnCYCLE,
                           gnCYCLE_MONTH,
                           gvBILL_CURRENCY,
                           NU_BILL_AMT,
                           NU_BILL_RATE,
                           CH_CHARGE_DESCR,
                           PI_SERVICE_RECEIVER_TYPE,
                           PI_CORRECT_SEQ,
                           gvDYNAMIC_ATTRIBUTE,
                           PI_CI_SEQ,
                           SYSDATE,
                           gvUSER,
                           SYSDATE,
                           gvUSER);
      END IF;
      gvERR_CDE := '0000';
      gvERR_MSG := NULL;
      PO_BI_SEQ := NU_BI_SEQ;
   EXCEPTION
      WHEN on_err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP||SQLERRM, 1, 250);
   END INS_BI;

   /*************************************************************************
      PROCEDURE : DO_ROUND
      PURPOSE :   BL BILL_BI ROUND 處理
      DESCRIPTION : BL BILL_BI ROUND 處理
      PARAMETER:

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE DO_ROUND IS

      --抓取各稅別
      CURSOR C_BI IS
         SELECT TAX_TYPE, SUM(AMOUNT) AMOUNT, SUM(TAX_AMT) TAX_AMT
           FROM FY_TB_BL_BILL_BI A, fy_tb_bl_bill_acct b --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
          WHERE a.BILL_SEQ    =gnBILL_SEQ
            AND a.CYCLE       =gnCYCLE
            AND a.CYCLE_MONTH =gnCYCLE_MONTH
            AND a.ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND a.ACCT_ID     =gnACCT_ID
            AND b.bill_currency = 'NTD' --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND a.bill_seq = b.bill_seq --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND a.CYCLE = b.CYCLE --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND a.cycle_month = b.cycle_month --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND a.acct_key = b.acct_key --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND a.acct_id = b.acct_id --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND gvPROC_TYPE ='B'
          GROUP BY TAX_TYPE
        UNION
         SELECT TAX_TYPE, SUM(AMOUNT), SUM(TAX_AMT)
           FROM FY_TB_BL_BILL_BI_TEST A, fy_tb_bl_bill_acct b --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
          WHERE a.BILL_SEQ    =gnBILL_SEQ
            AND a.CYCLE       =gnCYCLE
            AND a.CYCLE_MONTH =gnCYCLE_MONTH
            AND a.ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND a.ACCT_ID     =gnACCT_ID
            AND b.bill_currency = 'NTD' --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND a.bill_seq = b.bill_seq --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND a.CYCLE = b.CYCLE --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND a.cycle_month = b.cycle_month --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND a.acct_key = b.acct_key --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND a.acct_id = b.acct_id --2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
            AND gvPROC_TYPE ='T'
          GROUP BY TAX_TYPE
          ORDER BY TAX_TYPE DESC;

      NU_TAX_AMT         NUMBER  :=0;
      NU_TX1_AMT         NUMBER  :=0;
      NU_TX2_AMT         NUMBER  :=0;
      NU_TX3_AMT         NUMBER  :=0;
      NU_TOT_AMOUNT      NUMBER  :=0;
      NU_BI_SEQ          NUMBER;
      NU_AMOUNT          NUMBER;
      NU_TAX             NUMBER;
      CH_CHARGE_CODE     FY_TB_BL_BILL_BI.CHARGE_CODE%TYPE;
      On_Err             EXCEPTION;
   BEGIN
   dbms_output.enable(999999999999999999999);
      NU_TOT_AMOUNT := 0;
      FOR R_BI IN C_BI LOOP
         NU_TOT_AMOUNT := NU_TOT_AMOUNT+R_BI.AMOUNT;
         IF R_BI.TAX_TYPE='TX1' THEN
            NU_TX1_AMT := R_BI.AMOUNT;
            NU_TAX_AMT := R_BI.TAX_AMT;
         ELSIF R_BI.TAX_TYPE='TX2' THEN
            NU_TX2_AMT := R_BI.AMOUNT;
         ELSIF R_BI.TAX_TYPE='TX3' THEN
            NU_TX3_AMT := R_BI.AMOUNT;
         END IF;
      END LOOP;
      NU_TAX_AMT := ROUND((ROUND(NU_TOT_AMOUNT,0)-(ROUND(NU_TX2_AMT,0)+ROUND(NU_TX3_AMT,0)))/(1+gnRATE_TX1)*gnRATE_TX1,0)-NU_TAX_AMT;
DBMS_OUTPUT.Put_Line('ACCT_ID='||TO_CHAR(gnACCT_ID)||', TOT_AMT='||TO_CHAR(NU_TOT_AMOUNT)||', TX1_AMT='||TO_CHAR(NU_TX1_AMT)||', TX2_AMT='||TO_CHAR(NU_TX2_AMT));
      NU_TX1_AMT := ROUND(NU_TOT_AMOUNT,0)-(ROUND(NU_TX1_AMT,0)+ROUND(NU_TX2_AMT,0)+ROUND(NU_TX3_AMT,0))+
                    ROUND(NU_TX1_AMT,0)-NU_TX1_AMT;
--DBMS_OUTPUT.Put_Line('NU_TX1_AMT='||TO_CHAR(NU_TX1_AMT));
      NU_TX2_AMT := ROUND(NU_TX2_AMT,0)-NU_TX2_AMT;
--DBMS_OUTPUT.Put_Line('NU_TX2_AMT='||TO_CHAR(NU_TX2_AMT));
      NU_TX3_AMT := ROUND(NU_TX3_AMT,0)-NU_TX3_AMT;
--DBMS_OUTPUT.Put_Line('NU_TX3_AMT='||TO_CHAR(NU_TX3_AMT));
      FOR i IN 1 .. 3 LOOP
         SELECT DECODE(I,1,gvROUND_TX1,2,gvROUND_TX2,gvROUND_TX3),
                DECODE(I,1,NU_TX1_AMT,2,NU_TX2_AMT,NU_TX3_AMT),
                DECODE(I,1,NU_TAX_AMT,0)
           INTO CH_CHARGE_CODE, NU_AMOUNT, NU_TAX
           FROM DUAL;
         IF NU_AMOUNT<>0 OR (I=1 AND NU_TAX<>0) THEN
            INS_BI(CH_CHARGE_CODE,
                   'IN',     --PI_CHARGE_ORG ,
                   NU_AMOUNT ,
                   NU_TAX,
                   NULL,   --OFFER_INSTANCE_ID
                   NULL,   --OFFER_SEQ,
                   NULL,   --OFFER_ID ,
                   NULL,   --PKG_ID
                   'IN',   --SOURCE
                   gdBILL_DATE,   --CHRG_DATE,
                   NULL,   --CHRG_FROM_DATE,
                   NULL,   --CHRG_END_DATE,
                   NULL,  --PI_CHARGE_DESCR ,
                   'A',   --SERVICE_RECEIVER_TYPE,
                   NULL,  --DYNAMIC_ATTRIBUTE,
                   0,     --PI_CORRECT_SEQ ,
                   NULL,  --CI_SEQ
                   NU_BI_SEQ );
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR('INS_BI:'||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;
         END IF;
      END LOOP;
      gvERR_CDE := '0000';
      gvERR_MSG := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END DO_ROUND;

      /*************************************************************************
      PROCEDURE : DO_ROUND_FIX
      PURPOSE :   BL BILL_BI ROUND 處理帳單金額因TAX_RATE導致的誤差
      DESCRIPTION : 當帳單內容同時有不同TAX_RATE時，summary金額>=0.5&<1時補1元rounding charge，summary金額>=1&<1.5時補-1元rounding charge，避免造成客訴
      PARAMETER:

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2019/12/31      MikeKuan     新建
   **************************************************************************/
   PROCEDURE DO_ROUND_FIX IS

      --抓取各稅別
      CURSOR C_BI IS
        SELECT   nvl(SUM (COUNT (tax_type)),0) TAX_COUNT, nvl(SUM (amount),0) TAX_amount
            FROM fy_tb_bl_bill_bi a, fy_tb_bl_bill_acct b
        WHERE a.bill_seq = gnBILL_SEQ
            AND a.CYCLE = gnCYCLE
            AND a.cycle_month = gnCYCLE_MONTH
            AND a.acct_key = TO_NUMBER (SUBSTR (LPAD (gnACCT_ID, 18, 0), -2))
            AND a.acct_id = gnACCT_ID
            AND a.charge_org = 'IN'
            AND b.bill_currency = 'NTD'
            AND a.bill_seq = b.bill_seq
            AND a.CYCLE = b.CYCLE
            AND a.cycle_month = b.cycle_month
            AND a.acct_key = b.acct_key
            AND a.acct_id = b.acct_id
            AND gvPROC_TYPE = 'B'
        GROUP BY a.tax_type, a.amount
        UNION
        SELECT   nvl(SUM (COUNT (tax_type)),0) TAX_COUNT, nvl(SUM (amount),0) TAX_amount
            FROM fy_tb_bl_bill_bi_test a, fy_tb_bl_bill_acct b
        WHERE a.bill_seq = gnBILL_SEQ
            AND a.CYCLE = gnCYCLE
            AND a.cycle_month = gnCYCLE_MONTH
            AND a.acct_key = TO_NUMBER (SUBSTR (LPAD (gnACCT_ID, 18, 0), -2))
            AND a.acct_id = gnACCT_ID
            AND b.bill_currency = 'NTD'
            AND a.bill_seq = b.bill_seq
            AND a.CYCLE = b.CYCLE
            AND a.cycle_month = b.cycle_month
            AND a.acct_key = b.acct_key
            AND a.acct_id = b.acct_id
            AND gvPROC_TYPE = 'T'
        GROUP BY tax_type, amount;

      NU_TAX_COUNT       NUMBER  :=0;
      NU_TOT_AMOUNT      NUMBER  :=0;
      NU_BI_SEQ          NUMBER;
      NU_AMOUNT          NUMBER  :=0;
      NU_TAX             NUMBER;
      CH_CHARGE_CODE     FY_TB_BL_BILL_BI.CHARGE_CODE%TYPE;
      On_Err             EXCEPTION;
   BEGIN
      NU_TAX_COUNT := 0;
      NU_TOT_AMOUNT := 0;
      FOR R_BI IN C_BI LOOP
         NU_TAX_COUNT := NU_TAX_COUNT+R_BI.TAX_COUNT;
         NU_TOT_AMOUNT := NU_TOT_AMOUNT+R_BI.TAX_AMOUNT;

         DBMS_OUTPUT.Put_Line('NU_TAX_COUNT='||TO_CHAR(NU_TAX_COUNT));
         DBMS_OUTPUT.Put_Line('NU_TOT_AMOUNT='||TO_CHAR(NU_TOT_AMOUNT));
         IF R_BI.TAX_COUNT=2 AND NU_TOT_AMOUNT >=-0.98 AND NU_TOT_AMOUNT <=-0.5 THEN
            NU_AMOUNT := 1;
         ELSIF R_BI.TAX_COUNT=2 AND NU_TOT_AMOUNT >=0.49 AND NU_TOT_AMOUNT <=1 THEN
            NU_AMOUNT := -1;
         END IF;
      END LOOP;

         IF NU_TAX_COUNT=2 AND NU_AMOUNT != 0 THEN
            INS_BI(gvROUND_TX2,
                   'IN',     --PI_CHARGE_ORG ,
                   NU_AMOUNT ,
                   0, --NU_TAX
                   NULL,   --OFFER_INSTANCE_ID
                   NULL,   --OFFER_SEQ,
                   NULL,   --OFFER_ID ,
                   NULL,   --PKG_ID
                   'IN',   --SOURCE
                   gdBILL_DATE,   --CHRG_DATE,
                   NULL,   --CHRG_FROM_DATE,
                   NULL,   --CHRG_END_DATE,
                   NULL,  --PI_CHARGE_DESCR ,
                   'A',   --SERVICE_RECEIVER_TYPE,
                   NULL,  --DYNAMIC_ATTRIBUTE,
                   0,     --PI_CORRECT_SEQ ,
                   NULL,  --CI_SEQ
                   NU_BI_SEQ );
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR('INS_BI:'||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;
         END IF;

      gvERR_CDE := '0000';
      gvERR_MSG := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END DO_ROUND_FIX;

   /*************************************************************************
      PROCEDURE : DO_NTD_ROUND
      PURPOSE :   BL BILL_BI ROUND 處理
      DESCRIPTION : 美金換算台幣rounding charge
      PARAMETER:

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2019/12/31      MikeKuan     新建
   **************************************************************************/
   PROCEDURE DO_NTD_ROUND IS

      --抓取各稅別
      CURSOR C_BI IS
         SELECT TAX_TYPE, SUM(REGEXP_SUBSTR (a.DYNAMIC_ATTRIBUTE, '.*TO_NTD=([^#]*).*', 1, 1, NULL, 1)) AMOUNT, SUM(REGEXP_SUBSTR (a.DYNAMIC_ATTRIBUTE, '.*TO_NTD_TAX=([^#]*).*', 1, 1, NULL, 1)) TAX_AMT
           FROM FY_TB_BL_BILL_BI A, fy_tb_bl_bill_acct b
          WHERE a.BILL_SEQ    =gnBILL_SEQ
            AND a.CYCLE       =gnCYCLE
            AND a.CYCLE_MONTH =gnCYCLE_MONTH
            AND a.ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND a.ACCT_ID     =gnACCT_ID
            AND b.bill_currency = 'USD'
            AND a.bill_seq = b.bill_seq
            AND a.CYCLE = b.CYCLE
            AND a.cycle_month = b.cycle_month
            AND a.acct_key = b.acct_key
            AND a.acct_id = b.acct_id
            AND gvPROC_TYPE ='B'
          GROUP BY TAX_TYPE
        UNION
         SELECT TAX_TYPE, SUM(REGEXP_SUBSTR (a.DYNAMIC_ATTRIBUTE, '.*TO_NTD=([^#]*).*', 1, 1, NULL, 1)) AMOUNT, SUM(REGEXP_SUBSTR (a.DYNAMIC_ATTRIBUTE, '.*TO_NTD_TAX=([^#]*).*', 1, 1, NULL, 1)) TAX_AMT
           FROM FY_TB_BL_BILL_BI A, fy_tb_bl_bill_acct b
          WHERE a.BILL_SEQ    =gnBILL_SEQ
            AND a.CYCLE       =gnCYCLE
            AND a.CYCLE_MONTH =gnCYCLE_MONTH
            AND a.ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(gnACCT_ID,18,0),-2))
            AND a.ACCT_ID     =gnACCT_ID
            AND b.bill_currency = 'USD'
            AND a.bill_seq = b.bill_seq
            AND a.CYCLE = b.CYCLE
            AND a.cycle_month = b.cycle_month
            AND a.acct_key = b.acct_key
            AND a.acct_id = b.acct_id
            AND gvPROC_TYPE ='T'
          GROUP BY TAX_TYPE
          ORDER BY TAX_TYPE DESC;

      NU_TAX_AMT         NUMBER  :=0;
      NU_TX1_AMT         NUMBER  :=0;
      NU_TX2_AMT         NUMBER  :=0;
      NU_TX3_AMT         NUMBER  :=0;
      NU_TOT_AMOUNT      NUMBER  :=0;
      NU_BI_SEQ          NUMBER;
      NU_AMOUNT          NUMBER;
      NU_TAX             NUMBER;
      CH_CHARGE_CODE     FY_TB_BL_BILL_BI.CHARGE_CODE%TYPE;
      On_Err             EXCEPTION;
   BEGIN
      NU_TOT_AMOUNT := 0;
      FOR R_BI IN C_BI LOOP
         NU_TOT_AMOUNT := NU_TOT_AMOUNT+R_BI.AMOUNT;
         IF R_BI.TAX_TYPE='TX1' THEN
            NU_TX1_AMT := R_BI.AMOUNT;
            NU_TAX_AMT := R_BI.TAX_AMT;
         ELSIF R_BI.TAX_TYPE='TX2' THEN
            NU_TX2_AMT := R_BI.AMOUNT;
         ELSIF R_BI.TAX_TYPE='TX3' THEN
            NU_TX3_AMT := R_BI.AMOUNT;
         END IF;
      END LOOP;
      NU_TAX_AMT := ROUND((ROUND(NU_TOT_AMOUNT,0)-(ROUND(NU_TX2_AMT,0)+ROUND(NU_TX3_AMT,0)))/(1+gnRATE_TX1)*gnRATE_TX1,0)-NU_TAX_AMT;
      NU_TX1_AMT := ROUND(NU_TOT_AMOUNT,0)-(ROUND(NU_TX1_AMT,0)+ROUND(NU_TX2_AMT,0)+ROUND(NU_TX3_AMT,0))+
                    ROUND(NU_TX1_AMT,0)-NU_TX1_AMT;
      NU_TX2_AMT := ROUND(NU_TX2_AMT,0)-NU_TX2_AMT;
      NU_TX3_AMT := ROUND(NU_TX3_AMT,0)-NU_TX3_AMT;
      FOR i IN 1 .. 3 LOOP
         SELECT DECODE(I,1,gvROUND_TX1,2,gvROUND_TX2,gvROUND_TX3),
                DECODE(I,1,NU_TX1_AMT,2,NU_TX2_AMT,NU_TX3_AMT),
                DECODE(I,1,NU_TAX_AMT,0)
           INTO CH_CHARGE_CODE, NU_AMOUNT, NU_TAX
           FROM DUAL;
         IF NU_AMOUNT<>0 OR (I=1 AND NU_TAX<>0) THEN
            INS_BI(CH_CHARGE_CODE,
                   'NN',     --PI_CHARGE_ORG ,
                   NU_AMOUNT ,
                   NU_TAX,
                   NULL,   --OFFER_INSTANCE_ID
                   NULL,   --OFFER_SEQ,
                   NULL,   --OFFER_ID ,
                   NULL,   --PKG_ID
                   'NN',   --SOURCE
                   gdBILL_DATE,   --CHRG_DATE,
                   NULL,   --CHRG_FROM_DATE,
                   NULL,   --CHRG_END_DATE,
                   NULL,  --PI_CHARGE_DESCR ,
                   'A',   --SERVICE_RECEIVER_TYPE,
                   NULL,  --DYNAMIC_ATTRIBUTE,
                   0,     --PI_CORRECT_SEQ ,
                   NULL,  --CI_SEQ
                   NU_BI_SEQ );
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR('INS_BI:'||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;
         END IF;
      END LOOP;
      gvERR_CDE := '0000';
      gvERR_MSG := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END DO_NTD_ROUND;

   /*************************************************************************
      PROCEDURE : GET_CURRENCY
      PURPOSE :   外幣金額換算處理
      DESCRIPTION : 外幣金額換算處理
      PARAMETER:
            PI_BILL_CURRENCY      :換算幣別
            PI_AMOUNT             :金額
            PO_BILL_AMT           :換算匯率
            PO_BILL_RATE          :換算金額
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE GET_CURRENCY(PI_BILL_CURRENCY    IN    VARCHAR2,
                          PI_AMOUNT           IN    NUMBER,
                          PO_BILL_AMT        OUT    NUMBER,
                          PO_BILL_RATE       OUT    NUMBER,
                          PO_ERR_CDE         OUT   VARCHAR2,
                          PO_ERR_MSG         OUT   VARCHAR2) IS

      CH_ERR_CDE         VARCHAR2(4);
      CH_ERR_MSG         VARCHAR2(250);
      CH_STEP            VARCHAR2(250);
      On_Err             EXCEPTION;
   BEGIN
      SELECT CONVERSION_RATE, ROUND(PI_AMOUNT*CONVERSION_RATE,2)
        INTO PO_BILL_RATE, PO_BILL_AMT
        FROM FY_TB_BL_BILL_RATES A
       WHERE BILL_SEQ   =gnBILL_SEQ
         AND CYCLE      =gnCYCLE
         AND CYCLE_MONTH=gnCYCLE_MONTH
         AND FROM_CURRENCY='NTD'
         AND TO_CURRENCY=PI_BILL_CURRENCY
         AND ROWNUM=1;
      PO_ERR_CDE := '0000';
      PO_ERR_MSG := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         PO_Err_Cde := '9999';
         PO_Err_Msg := Substr(SQLERRM, 1, 250);
   END GET_CURRENCY;

   /*************************************************************************
      PROCEDURE : GET_NTD_CURRENCY
      PURPOSE :   台幣金額換算處理
      DESCRIPTION : 台幣金額換算處理
      PARAMETER:
            PI_BILL_CURRENCY      :換算幣別
            PI_AMOUNT             :金額
            PO_BILL_AMT           :換算匯率
            PO_BILL_RATE          :換算金額
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2019/12/31      MikeKuan       新建
   **************************************************************************/
   PROCEDURE GET_NTD_CURRENCY(PI_BILL_CURRENCY    IN    VARCHAR2,
                          PI_AMOUNT           IN    NUMBER,
                          NU_TAX_AMT           IN    NUMBER,
                          PO_BILL_AMT        OUT    NUMBER,
                          PO_BILL_TAX_AMT        OUT    NUMBER,
                          PO_BILL_RATE       OUT    NUMBER,
                          PO_ERR_CDE         OUT   VARCHAR2,
                          PO_ERR_MSG         OUT   VARCHAR2) IS

      CH_ERR_CDE         VARCHAR2(4);
      CH_ERR_MSG         VARCHAR2(250);
      CH_STEP            VARCHAR2(250);
      On_Err             EXCEPTION;
   BEGIN
      SELECT CONVERSION_RATE, ROUND(PI_AMOUNT*CONVERSION_RATE,2), ROUND(NU_TAX_AMT*CONVERSION_RATE,2)
        INTO PO_BILL_RATE, PO_BILL_AMT, PO_BILL_TAX_AMT
        FROM FY_TB_BL_BILL_RATES A
       WHERE BILL_SEQ   =gnBILL_SEQ
         AND CYCLE      =gnCYCLE
         AND CYCLE_MONTH=gnCYCLE_MONTH
         AND FROM_CURRENCY='USD'
         AND TO_CURRENCY='NTD'
         AND ROWNUM=1;
      PO_ERR_CDE := '0000';
      PO_ERR_MSG := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         PO_Err_Cde := '9999';
         PO_Err_Msg := Substr(SQLERRM, 1, 250);
   END GET_NTD_CURRENCY;

END FY_PG_BL_BILL_BI; -- PACKAGE BODY FY_PG_BL_BILL_BI
/