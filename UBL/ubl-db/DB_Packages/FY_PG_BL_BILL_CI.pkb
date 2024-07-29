CREATE OR REPLACE PACKAGE BODY HGBBLAPPO.FY_PG_BL_BILL_CI IS
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL_CI 處理
      DESCRIPTION : BL BILL_CI 處理
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
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration GET新安東京共用參數
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理 Fy_Pg_Bl_Bill_Util.MARKET_PKG ADD參數PROC_TYPE,BILL_SEQ
   **************************************************************************/
   PROCEDURE MAIN(PI_BILL_SEQ       IN   NUMBER,
                  PI_PROCESS_NO     IN   NUMBER,
                  PI_ACCT_GROUP     IN   VARCHAR2,
                  PI_PROC_TYPE      IN   VARCHAR2 DEFAULT 'B',
                  PI_USER_ID        IN   VARCHAR2,
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2) IS

      --抓取應出帳之ACCT_ID
      CURSOR C_AT IS
         SELECT AT.ACCT_ID ACCT_ID,
                AT.CUST_ID,
                AT.OU_ID,
                'Y' UC_FLAG,
                NULL SUBSCR_ID,
                NULL PRE_ACCT_ID,
                NULL PRE_CYCLE,
                AT.ACCT_KEY
           FROM FY_TB_BL_BILL_ACCT AT
          WHERE AT.BILL_SEQ   =gnBILL_SEQ
            AND AT.CYCLE      =gnCYCLE
            AND AT.CYCLE_MONTH=gnCYCLE_MONTH
            AND AT.ACCT_GROUP =gvACCT_GROUP
            AND gnPROCESS_NO <>999
            AND ((gvPROC_TYPE='B' AND AT.BILL_STATUS ='CL') OR
                 (gvPROC_TYPE='T' AND AT.BILL_STATUS<>'CN'))
          UNION
         SELECT AT.ACCT_ID ACCT_ID,
                AT.CUST_ID,
                AT.OU_ID,
                AL.UC_FLAG,
                NULL SUBSCR_ID,
                NULL PRE_ACCT_ID,
                NULL PRE_CYCLE,
                AT.ACCT_KEY
           FROM FY_TB_BL_ACCT_LIST AL,
                FY_TB_BL_BILL_ACCT AT
          WHERE AL.BILL_SEQ   =gnBILL_SEQ
            AND AL.TYPE       =gvACCT_GROUP
            AND AT.BILL_SEQ   =AL.BILL_SEQ
            AND AT.CYCLE      =gnCYCLE
            AND AT.CYCLE_MONTH=gnCYCLE_MONTH
            AND AT.ACCT_ID    =AL.ACCT_ID
            AND AT.ACCT_KEY   =MOD(AL.ACCT_ID,100)
            AND gnPROCESS_NO  =999
            AND ((gvPROC_TYPE='B' AND AT.BILL_STATUS ='CL') OR
                 (gvPROC_TYPE='T' AND AT.BILL_STATUS<>'CN'))
          ORDER BY ACCT_ID;
      R_AT       C_AT%ROWTYPE;

      CURSOR C_MV IS
         SELECT ACCT_ID,
                CUST_ID,
                OU_ID,
                'N' UC_FLAG,
                SUBSCR_ID,
                PRE_ACCT_ID,
                PRE_CYCLE,
                MOD(ACCT_ID,100) ACCT_KEY
           FROM (SELECT SUB.BILL_SEQ, SUB.ACCT_ID, SUB.SUBSCR_ID, SUB.PRE_ACCT_ID, SUB.PRE_SUBSCR_ID, SUB.PRE_CYCLE,
                        BA.CUST_ID, BA.OU_ID
                   FROM FY_TB_BL_BILL_MV_SUB SUB,
                        FY_TB_BL_BILL_ACCT BA
                  WHERE SUB.BILL_SEQ   =gnBILL_SEQ
                    AND SUB.CYCLE      =gnCYCLE
                    AND SUB.CYCLE_MONTH=gnCYCLE_MONTH
                    AND BA.BILL_SEQ    =SUB.BILL_SEQ
                    AND BA.CYCLE       =SUB.CYCLE
                    AND BA.CYCLE_MONTH =SUB.CYCLE_MONTH
                    AND BA.ACCT_ID     =SUB.ACCT_ID
                    AND BA.ACCT_KEY    =MOD(SUB.ACCT_ID,100)
                    AND ((gnPROCESS_NO<>999 AND BA.ACCT_GROUP='MV') OR
                         (gnPROCESS_NO =999 AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                                         WHERE BILL_SEQ =SUB.BILL_SEQ
                                                           AND ACCT_ID  =SUB.ACCT_ID
                                                           AND TYPE     =gvACCT_GROUP)
                         ))) MV
          START WITH PRE_SUBSCR_ID IS NULL OR PRE_CYCLE IS NOT NULL ----2021/06/15 MODIFY FOR 小額預繳處理 ADD PRE_CYCLE
         CONNECT BY PRIOR SUBSCR_ID=PRE_SUBSCR_ID;

      CURSOR C_PKG(iSUBSCR_ID NUMBER) IS
         SELECT PKG.ROWID,
                PKG.ACCT_KEY,
                PKG.ACCT_PKG_SEQ,
                PKG.TOTAL_DISC_AMT,
                PKG.VALIDITY_PERIOD,
                PKG.CUR_BAL_QTY,
                PKG.TRANS_IN_QTY,
                PKG.PRE_PKG_SEQ ,
                PKG.TRANS_IN_DATE,
                PKG.ORIG_EFF_DATE
           FROM FY_TB_BL_ACCT_PKG PKG
          WHERE PKG.ACCT_ID       =gnACCT_ID
            AND PKG.ACCT_KEY      =MOD(gnACCT_ID,100)
            AND PKG.OFFER_LEVEL   ='S'
            AND PKG.OFFER_LEVEL_ID=iSUBSCR_ID
            AND PKG.PRE_PKG_SEQ IS NOT NULL
            AND PKG.TRANS_IN_DATE IS NULL;

      NU_CNT             NUMBER  :=0;
      NU_AT_CNT          NUMBER;
      NU_CTRL_CNT        NUMBER;
      NU_SHOW_CNT        NUMBER;
      CH_PG_NAME         FY_TB_BL_BILL_PROCESS_ERR.PG_NAME%TYPE;
      CH_STATUS          FY_TB_RAT_PERIOD_CNTRL.STATUS%TYPE;
      On_Err             EXCEPTION;
      On_AT_Err          EXCEPTION;
   BEGIN
      --設定一些全域的變數
      gnBILL_SEQ  := PI_BILL_SEQ;
      gnPROCESS_NO:= PI_PROCESS_NO;
      gvACCT_GROUP:= PI_ACCT_GROUP;
      gvPROC_TYPE := PI_PROC_TYPE;
      gvUSER      := PI_USER_ID;
      --GET BILL_CNTRL
      gvSTEP := 'GET BILL_DATA FROM BILLING_LOG, BILL_SEQ:'||TO_CHAR(gnBILL_SEQ);
      SELECT BC.BILL_DATE, BC.CYCLE, BC.BILL_PERIOD, BC.BILL_FROM_DATE, BC.BILL_END_DATE,
             TO_NUMBER(TO_CHAR(BC.BILL_FROM_DATE,'DD')), TO_NUMBER(SUBSTR(BC.BILL_PERIOD,-2))
        INTO gdBILL_DATE, gnCYCLE, gvBILL_PERIOD, gdBILL_FROM_DATE, gdBILL_END_DATE,
             gnFROM_DAY, gnCYCLE_MONTH
        FROM FY_TB_BL_BILL_CNTRL BC
       WHERE BC.BILL_SEQ  = gnBILL_SEQ;
      --CHECK CDR
      gvSTEP := 'CYCLE='||TO_CHAR(gnCYCLE)||',PERIOD='||gvBILL_PERIOD||':';
      SELECT STATUS
        INTO CH_STATUS
        FROM FY_TB_RAT_PERIOD_CNTRL
       WHERE CYCLE      =gnCYCLE
         AND CYCLE_MONTH=gnCYCLE_MONTH
         AND BILL_PERIOD=gvBILL_PERIOD;
      IF CH_STATUS<>'CLOSE' THEN
         PO_ERR_CDE := 'S001';
         gvSTEP     := 'GET CDR_STATUS.'||gvSTEP||'該CDR尚未CLOSE';
         RAISE ON_ERR;
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
      ----CHECK PROCESS_NO
      DBMS_OUTPUT.Put_Line('BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||', PROCESS_NO='||TO_CHAR(PI_PROCESS_NO)||
                           ', ACCT_GROUP='||PI_ACCT_GROUP||', PROCESS_TYPE='||PI_PROC_TYPE);
      gvSTEP := 'CALL Ins_Process_LOG:';
      Fy_Pg_Bl_Bill_Util.Ins_Process_LOG
                     ('CI',  --PI_STATUS
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
      ----DIO
      gvSTEP := 'CALL DATA I/O.BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||':';
      IF gvUSER='MPBL' THEN     --2020/06/30 MODIFY FOR MPBS_Migration - 修改為變數
        Fy_Pg_Dio_Util.Ins_Dio_Cntrl
                            ('UBL',     --Pi_Sys_Id ,
                            'MPACCTLIST', --Pi_Proc_Id ,
                            Pi_Bill_Seq ,
                            Pi_Process_No,
                            Pi_Proc_Type,
                            Pi_Acct_Group,
                            NULL,  --Pi_Confirm_Id,
                            'O',   --Pi_Io_Type,
                            Pi_User_ID,
                            Po_Err_Cde,
                            Po_Err_Msg);
      ELSE
        Fy_Pg_Dio_Util.Ins_Dio_Cntrl
                            ('UBL',     --Pi_Sys_Id ,
                            'ACCTLIST', --Pi_Proc_Id ,
                            Pi_Bill_Seq ,
                            Pi_Process_No,
                            Pi_Proc_Type,
                            Pi_Acct_Group,
                            NULL,  --Pi_Confirm_Id,
                            'O',   --Pi_Io_Type,
                            Pi_User_ID,
                            Po_Err_Cde,
                            Po_Err_Msg);
      END IF;

      IF Po_Err_Cde <> '0000' THEN
         gvSTEP :=Substr('CALL Ins_Dio_Cntrl:'||Po_Err_Msg,1,250);
         RAISE ON_ERR;
      END IF;
      
      --2020/06/30 MODIFY FOR MPBS_Migration GET新安東京共用參數
      gnPRT_ID    := NULL;
      gvPRT_VALUE := NULL;
      gnROUNDING  := 2;
      gvPARAM_NAME:= NULL;  
      IF gvUSER='MPBL' THEN
         BEGIN
            gvSTEP := 'GET MPBL PRT_ID:';
            SELECT NUM1
              INTO gnPRT_ID
              FROM FY_TB_SYS_LOOKUP_CODE
             WHERE LOOKUP_TYPE='TMNEWA'
               AND LOOKUP_CODE='PRT_ID';
            gvSTEP := 'GET MPBL PRT_VALUE:';
            SELECT CH1
              INTO gvPRT_VALUE
              FROM FY_TB_SYS_LOOKUP_CODE
             WHERE LOOKUP_TYPE='TMNEWA'
               AND LOOKUP_CODE='PRT_VALUE';
            --GET ROUNDING位數
            gvSTEP := 'GET MPBL ROUNDING位數:';
            SELECT NVL(NUM1,2)
              INTO gnROUNDING
              FROM FY_TB_SYS_LOOKUP_CODE
             WHERE LOOKUP_TYPE='TMNEWA'
               AND LOOKUP_CODE='ROUNDING'; 
           --GET PARAM_NAME
           gvSTEP := 'GET MPBL PARAM_NAME:';
           SELECT CH1 
             INTO gvPARAM_NAME
             FROM FY_TB_SYS_LOOKUP_CODE
            WHERE LOOKUP_TYPE='TMNEWA'
              AND LOOKUP_CODE='PARAM_NAME';   
         EXCEPTION WHEN OTHERS THEN
            gvSTEP :=Substr(gvSTEP||SQLERRM, 1, 250);
            RAISE ON_ERR;
         END; 
      END IF;  --2020/06/30  

      --2021/10/20 MODIFY SR239378 SDWAN_NPEP solution建置 (共用參數)
      --DBMS_OUTPUT.Put_Line('CYCLE='||TO_CHAR(gnCYCLE));
      IF gnCYCLE IN ('10','15','20') THEN --2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CYCLE(15,20)
         BEGIN
            gvSTEP := 'GET HGBN PRT_ID:';
            SELECT NUM1
              INTO gnPRT_ID
              FROM FY_TB_SYS_LOOKUP_CODE
             WHERE LOOKUP_TYPE='SDWAN'
               AND LOOKUP_CODE='PRT_ID';
            gvSTEP := 'GET HGBN PRT_VALUE:';
            SELECT CH1
              INTO gvPRT_VALUE
              FROM FY_TB_SYS_LOOKUP_CODE
             WHERE LOOKUP_TYPE='SDWAN'
               AND LOOKUP_CODE='PRT_VALUE';  
         EXCEPTION WHEN OTHERS THEN
            gvSTEP :=Substr(gvSTEP||SQLERRM, 1, 250);
            RAISE ON_ERR;
         END; 
         --DBMS_OUTPUT.Put_Line('PRT_ID='||TO_CHAR(gnPRT_ID)||', PRT_VALUE='||TO_CHAR(gvPRT_VALUE));
      END IF;  --2021/10/20 MODIFY SR239378 SDWAN_NPEP solution建置 (取得LOOKUP_CODE)
      
      --GET ACCT_ID
      FOR i IN 1 .. 2 LOOP
         SELECT DECODE(i,1,NULL,'_MV')
           INTO CH_STATUS
           FROM DUAL;
       --  DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS')||' :FY_PG_BL_BILL_CI'||CH_STATUS||' BEGIN');
         IF i=1 THEN
            OPEN C_AT;
         ELSE
            OPEN C_MV;
         END IF;
         LOOP
            IF i=1 THEN
              FETCH C_AT INTO R_AT;
              EXIT WHEN C_AT%NOTFOUND;
            ELSE
              FETCH C_MV INTO R_AT;
              EXIT WHEN C_MV%NOTFOUND;
            END IF;
            BEGIN
               gnACCT_ID    := R_AT.ACCT_ID;
               gnCUST_ID    := R_AT.CUST_ID;
               gnACCT_OU_ID := R_AT.OU_ID;
               IF i=1 THEN
                  NU_AT_CNT := NVL(NU_AT_CNT,0)+1;
                  IF MOD(NU_AT_CNT/NU_SHOW_CNT,1)=0 THEN
                     DBMS_OUTPUT.Put_Line('CNT='||TO_CHAR(NU_AT_CNT));
                  END IF;
                  --GET UC
                  GET_UC(R_AT.UC_FLAG);
                  IF gvERR_CDE<>'0000' THEN
                     gvSTEP     := Substr('CALL GET_UC:'||gvErr_Msg,1,250);
                     CH_PG_NAME := 'FY_PG_BL_BILL_CI.GET_UD';
                     RAISE ON_AT_ERR;
                  END IF;
                  --月租
                  DO_RECUR;
                  IF gvERR_CDE<>'0000' THEN
                     gvSTEP     := Substr('CALL DO_RECUR:'||gvErr_Msg,1,250);
                     CH_PG_NAME := 'FY_PG_BL_BILL_CI.DO_RECUR';
                     RAISE ON_AT_ERR;
                  END IF;
                  NU_CNT    := 0;
               ELSIF R_AT.PRE_ACCT_ID IS NULL THEN
                  NU_CNT    := 1;
               ELSE
                  SELECT COUNT(1)
                    INTO NU_CNT
                    FROM FY_TB_BL_BILL_PROCESS_ERR
                   WHERE BILL_SEQ   =gnBILL_SEQ
                     AND PROCESS_NO =gnPROCESS_NO
                     AND ACCT_GROUP =gvACCT_GROUP
                     AND PROC_TYPE  =gvPROC_TYPE
                     AND ACCT_ID  IN (R_AT.ACCT_ID,R_AT.PRE_ACCT_ID);
                  IF NU_CNT=0 AND R_AT.PRE_CYCLE IS NOT NULL THEN
                     --不同CYCLE是否尚未出帳結束
                     SELECT COUNT(1)
                       INTO NU_CNT
                       FROM FY_TB_BL_BILL_CNTRL A,
                            FY_TB_BL_BILL_ACCT B
                      WHERE A.CYCLE=R_AT.PRE_CYCLE
                        AND A.STATUS<>'CN'
                        AND B.BILL_SEQ   =A.BILL_SEQ
                        AND B.CYCLE      =A.CYCLE
                        AND B.CYCLE_MONTH=A.CYCLE_MONTH
                        AND B.ACCT_ID    =R_AT.PRE_ACCT_ID
                        AND B.ACCT_KEY   =MOD(R_AT.ACCT_ID,100)
                        AND B.BILL_STATUS<>'CN';
                     IF NU_CNT>0 THEN
                        gvERR_CDE  := 'D001';
                        gvSTEP     := 'MARKET MOVE不同CYCLE.PRE_ACCT_ID='||TO_CHAR(R_AT.PRE_ACCT_ID)||'尚未出帳結束';
                        CH_PG_NAME := 'FY_PG_BL_BILL_CI.DO_DISCOUNT';
                        RAISE ON_AT_ERR;
                     END IF;
                     --移轉
                     FOR R_PKG IN C_PKG(R_AT.SUBSCR_ID) LOOP
                        gvSTEP := 'CALL MARKET_PKG.ACCT_ID='||TO_CHAR(gnACCT_ID)||',ACCT_PKG_SEQ='||TO_CHAR(R_PKG.ACCT_PKG_SEQ)||':';
                      -- DBMS_OUTPUT.Put_Line( gvSTEP);
                        Fy_Pg_Bl_Bill_Util.MARKET_PKG(gnCYCLE ,
                                                      R_PKG.ACCT_PKG_SEQ,
                                                      gdBILL_FROM_DATE,
                                                      gvPROC_TYPE, --2021/06/15 MODIFY FOR 小額預繳處理
                                                      gnBILL_SEQ,  --2021/06/15 MODIFY FOR 小額預繳處理
                                                      gvUSER,
                                                      gvERR_CDE ,
                                                      gvERR_MSG );
                        IF gvERR_CDE<>'0000' THEN
                           gvSTEP     := SUBSTR('CALL MARKET_PKG:'||gvERR_MSG,1,250);
                           CH_PG_NAME := 'FY_PG_BL_BILL_CI.DO_DISCOUNT';
                           RAISE ON_AT_ERR;
                        END IF;
                     END LOOP;
                  END IF;
               END IF;
               --GET ACCT_PKG
               IF NU_CNT=0 THEN
                  DO_DISCOUNT(i, R_AT.SUBSCR_ID, R_AT.PRE_CYCLE);
                  IF gvERR_CDE<>'0000' THEN
                     gvSTEP     := Substr('CALL DO_DISCOUNT:'||gvErr_Msg,1,250);
                     CH_PG_NAME := 'FY_PG_BL_BILL_CI.DO_DISCOUNT';
                     RAISE ON_AT_ERR;
                  END IF;
               END IF;
            EXCEPTION
               WHEN ON_AT_ERR THEN
                  ROLLBACK;
                  -- '新增出帳錯誤記錄檔';
                  Fy_Pg_Bl_Bill_Util.Ins_Process_Err(gnBill_Seq,
                                                     gvProc_Type,
                                                     gnAcct_Id,
                                                     gnSUBSCR_ID,
                                                     gnProcess_No,
                                                     gvAcct_Group,
                                                     CH_PG_NAME,
                                                     gvUser,
                                                     gvERR_CDE,
                                                     gvStep,
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
                                                     gnSUBSCR_ID,
                                                     gnProcess_No,
                                                     gvAcct_Group,
                                                     CH_PG_NAME,
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
         END LOOP; --R_AT
         IF i=1 THEN
            CLOSE C_AT;
         ELSE
            CLOSE C_MV;
         END IF;
     --    DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS')||' :FY_PG_BL_BILL_CI'||CH_STATUS||' END');
         IF gvACCT_GROUP<>'MV' AND gnProcess_No<>999 THEN
            EXIT;
         END IF;
      END LOOP;
      gvSTEP := 'UPDATE PROCESS_LOG.BILL_SEQ='||TO_CHAR(gnBILL_SEQ)||':';
      UPDATE FY_TB_BL_BILL_PROCESS_LOG BL SET END_TIME=SYSDATE,
                                              COUNT   =NU_AT_CNT
                                     WHERE BILL_SEQ  = gnBILL_SEQ
                                       AND PROCESS_NO= gnPROCESS_NO
                                       AND ACCT_GROUP= gvACCT_GROUP
                                       AND PROC_TYPE = gvPROC_TYPE
                                       AND STATUS    = 'CI'
                                       AND END_TIME IS NULL;
      COMMIT;
      PO_ERR_CDE := '0000';
      PO_ERR_MSG := NULL;
   EXCEPTION
      WHEN On_Err THEN
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END MAIN;

   /*************************************************************************
      PROCEDURE : GET_UC
      PURPOSE :   GET UC DATA FOR RAT_SUMMARY
      DESCRIPTION : GET UC DATA FOR RAT_SUMMARY
      PARAMETER:
            PI_UC_FLAG            :UC註記(Y:SYNC RAT)

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 從FY_TB_RAT_SUMMARY →FY_TB_RAT_SUMMARY_BILL, 
                                                                 ADD ITEM FY_TB_BL_BILL_CI.TXN_ID
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE GET_UC(PI_UC_FLAG      IN   VARCHAR2) IS

      CH_STATUS          FY_TB_RAT_PERIOD_CNTRL.STATUS%TYPE;
      NU_CNT             NUMBER;
      On_Err             EXCEPTION;
   BEGIN
      --GET UC
      IF gvPROC_TYPE='B' AND PI_UC_FLAG='Y' THEN
         SELECT COUNT(1)
           INTO NU_CNT
           FROM FY_TB_RAT_SUMMARY_BILL RT --2020/06/30 MODIFY FOR MPBS_Migration 從FY_TB_RAT_SUMMARY →FY_TB_RAT_SUMMARY_BILL
          WHERE BILL_PERIOD=gvBILL_PERIOD
            AND CYCLE      =gnCYCLE
            AND CYCLE_MONTH=gnCYCLE_MONTH
            AND ACCT_ID    =gnACCT_ID
            AND ACCT_KEY   =MOD(gnACCT_ID,100);
         IF NU_CNT>0 THEN
            gvSTEP := 'INSERT BILL_CI:';
            INSERT INTO FY_TB_BL_BILL_CI
                        (CI_SEQ,
                         ACCT_ID,
                        -- ACCT_KEY,  為虛擬欄位
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
                         UPDATE_USER,
                         TXN_ID,         --2020/06/30 MODIFY FOR MPBS_Migration ADD ITEM
                         BILL_SUBSCR_ID) --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                  SELECT FY_SQ_BL_BILL_CI.NEXTVAL,
                         RT.ACCT_ID,
                       --  MOD(RT.ACCT_ID,100),
                         RT.SUBSCR_ID,
                         RT.CUST_ID,
                         NULL,   --OU_ID,
                         RT.ITEM_ID, --CHRG_ID,
                         DECODE(SIGN(RT.CHRG_AMT),-1,'CRD','DBT'), --CHARGE_TYPE, 正DBT、負CRD --2020/06/30 MODIFY FOR MPBS_Migration ADD CRD
                         ROUND(RT.CHRG_AMT,2),
                         NULL,   --OFFER_SEQ,
                         RT.OFFER_ID,
                         NULL,   --OFFER_INSTANCE_ID,
                         NULL,   --PKG_ID,
                         RT.CREATE_DATE,   --CHRG_DATE,
                         NULL,   --CHRG_FROM_DATE,
                         NULL,   --CHRG_END_DATE,
                         RT.CHARGE_CODE,
                         gnBILL_SEQ,
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
                         'First_Event_Date='||nvl(to_char(FIRST_EVENT_DATE,'yyyymmdd'),'')||
                         '#'||'Last_Event_Date='||nvl(to_char(LAST_EVENT_DATE,'yyyymmdd'),'')||
                         '#'||'Count='||nvl(COUNT,'')||
                         '#'||'CDR_QTY='||nvl(QTY,'')||
                         '#'||'CALLED_NUMBER='||nvl(CALLED_NUMBER,'')|| --2021/07/22增加CSP_SERVICE_ID資訊
                         '#'||'TX_ID='||nvl(TX_ID,'') DYNAMIC_ATTRIBUTE,   --DYNAMIC_ATTRIBUTE, --2019/06/30 MODIFY FY_TB_BL_BILL_CI add UC DYNAMIC_ATTRIBUTE --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算 --2020/06/30 MODIFY FOR MPBS_Migration 增加TX_ID
                         SYSDATE,
                         gvUSER,
                         SYSDATE,
                         gvUSER,
                         TX_ID,    --2020/06/30 MODIFY FOR MPBS_Migration ADD ITEM
                         SUB.BILL_SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                    FROM FY_TB_RAT_SUMMARY_BILL RT, --2020/06/30 MODIFY FOR MPBS_Migration 從FY_TB_RAT_SUMMARY →FY_TB_RAT_SUMMARY_BILL
                         FY_TB_BL_BILL_SUB SUB  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 ADD FY_TB_BL_BILL_SUB
                   WHERE RT.BILL_PERIOD=gvBILL_PERIOD
                     AND RT.CYCLE      =gnCYCLE
                     AND RT.CYCLE_MONTH=gnCYCLE_MONTH
                     AND RT.ACCT_ID    =gnACCT_ID
                     AND RT.ACCT_KEY   =MOD(gnACCT_ID,100)
                     AND SUB.BILL_SEQ(+)   =gnBILL_SEQ
                     AND SUB.CYCLE(+)      =RT.CYCLE
                     AND SUB.CYCLE_MONTH(+)=RT.CYCLE_MONTH
                     AND SUB.ACCT_ID(+)    =RT.ACCT_ID
                     AND SUB.ACCT_KEY(+)   =RT.ACCT_KEY
                     AND SUB.SUBSCR_ID(+)  =RT.SUBSCR_ID;
            IF SQL%ROWCOUNT<>NU_CNT THEN
               gvERR_CDE := 'U001';
               gvSTEP := 'RAT_CNT='||TO_CHAR(NU_CNT)||',與INSERT筆數不符';
               RAISE ON_ERR;
            END IF;
         END IF;  --NU_CNT>0
      ELSIF gvPROC_TYPE='T' THEN
         --UC
         IF PI_UC_FLAG='Y' THEN
            SELECT COUNT(1)
              INTO NU_CNT
              FROM FY_TB_RAT_SUMMARY_BILL RT --2020/06/30 MODIFY FOR MPBS_Migration 從FY_TB_RAT_SUMMARY →FY_TB_RAT_SUMMARY_BILL
             WHERE BILL_PERIOD=gvBILL_PERIOD
               AND CYCLE      =gnCYCLE
               AND CYCLE_MONTH=gnCYCLE_MONTH
               AND ACCT_ID    =gnACCT_ID
               AND ACCT_KEY   =MOD(gnACCT_ID,100);
            IF NU_CNT>0 THEN
               gvSTEP := 'INSERT BILL_CI_TEST:';
               INSERT INTO FY_TB_BL_BILL_CI_TEST
                           (CI_SEQ,
                            ACCT_ID,
                           -- ACCT_KEY,  為虛擬欄位
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
                            UPDATE_USER,
                            TXN_ID,         --2020/06/30 MODIFY FOR MPBS_Migration ADD ITEM
                            BILL_SUBSCR_ID) --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                     SELECT FY_SQ_BL_BILL_CI.NEXTVAL,
                            RT.ACCT_ID,
                          --  MOD(RT.ACCT_ID,100),
                            RT.SUBSCR_ID,
                            RT.CUST_ID,
                            NULL,   --OU_ID,
                            RT.ITEM_ID, --CHRG_ID,
                            DECODE(SIGN(RT.CHRG_AMT),-1,'CRD','DBT'),  --CHARGE_TYPE, 正DBT、負CRD --2020/06/30 MODIFY FOR MPBS_Migration ADD CRD
                            ROUND(RT.CHRG_AMT,2),
                            NULL,   --OFFER_SEQ,
                            RT.OFFER_ID,
                            NULL,   --OFFER_INSTANCE_ID,
                            NULL,   --PKG_ID,
                            RT.CREATE_DATE,   --CHRG_DATE,
                            NULL,   --CHRG_FROM_DATE,
                            NULL,   --CHRG_END_DATE,
                            RT.CHARGE_CODE,
                            gnBILL_SEQ,
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
                            'First_Event_Date='||nvl(to_char(FIRST_EVENT_DATE,'yyyymmdd'),'')||
                            '#'||'Last_Event_Date='||nvl(to_char(LAST_EVENT_DATE,'yyyymmdd'),'')||
                            '#'||'Count='||nvl(COUNT,'')||
                            '#'||'CDR_QTY='||nvl(QTY,'')||
                            '#'||'CALLED_NUMBER='||nvl(CALLED_NUMBER,'')|| --2021/07/22增加CSP_SERVICE_ID資訊
                            '#'||'TX_ID='||nvl(TX_ID,'') DYNAMIC_ATTRIBUTE,   --DYNAMIC_ATTRIBUTE, --2019/06/30 MODIFY FY_TB_BL_BILL_CI add UC DYNAMIC_ATTRIBUTE --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算 --2020/06/30 MODIFY FOR MPBS_Migration 增加TX_ID
                            SYSDATE,
                            gvUSER,
                            SYSDATE,
                            gvUSER,
                            TX_ID,    --2020/06/30 MODIFY FOR MPBS_Migration ADD ITEM
                            SUB.BILL_SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                       FROM FY_TB_RAT_SUMMARY_BILL RT, --2020/06/30 MODIFY FOR MPBS_Migration 從FY_TB_RAT_SUMMARY →FY_TB_RAT_SUMMARY_BILL
                            FY_TB_BL_BILL_SUB SUB  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 ADD FY_TB_BL_BILL_SUB
                      WHERE RT.BILL_PERIOD=gvBILL_PERIOD
                        AND RT.CYCLE      =gnCYCLE
                        AND RT.CYCLE_MONTH=gnCYCLE_MONTH
                        AND RT.ACCT_ID    =gnACCT_ID
                        AND RT.ACCT_KEY   =MOD(gnACCT_ID,100)
                        AND SUB.BILL_SEQ(+)   =gnBILL_SEQ
                        AND SUB.CYCLE(+)      =RT.CYCLE
                        AND SUB.CYCLE_MONTH(+)=RT.CYCLE_MONTH
                        AND SUB.ACCT_ID(+)    =RT.ACCT_ID
                        AND SUB.ACCT_KEY(+)   =RT.ACCT_KEY
                        AND SUB.SUBSCR_ID(+)  =RT.SUBSCR_ID;
               IF SQL%ROWCOUNT<>NU_CNT THEN
                  gvERR_CDE := 'U001';
                  gvSTEP := 'RAT_CNT='||TO_CHAR(NU_CNT)||',與INSERT筆數不符';
                  RAISE ON_ERR;
               END IF;
            END IF;  --NU_CNT>0
         END IF;  --UC_FLAG
         --OC
         gvSTEP := 'OC INSERT BILL_CI_TEST:';
         INSERT INTO FY_TB_BL_BILL_CI_TEST
                    (CI_SEQ,
                     ACCT_ID,
                   --  ACCT_KEY, 為虛擬欄位
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
                     UPDATE_USER,
                     TXN_ID,        --2020/06/30 MODIFY FOR MPBS_Migration ADD ITEM
                     BILL_SUBSCR_ID)  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
              SELECT CI_SEQ,
                     ACCT_ID,
                   --  ACCT_KEY,
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
                     ROUND(CDR_ORG_AMT,2),
                     CET,
                     OVERWRITE,
                     DYNAMIC_ATTRIBUTE,
                     CREATE_DATE,
                     CREATE_USER,
                     UPDATE_DATE,
                     UPDATE_USER,
                     TXN_ID,        --2020/06/30 MODIFY FOR MPBS_Migration ADD ITEM
                     BILL_SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                 FROM FY_TB_BL_BILL_CI CI
                WHERE BILL_SEQ   =gnBILL_SEQ
                  AND CYCLE      =gnCYCLE
                  AND CYCLE_MONTH=gnCYCLE_MONTH
                  AND ACCT_ID    =gnACCT_ID
                  AND ACCT_KEY   =MOD(gnACCT_ID,100)
                  AND ((PI_UC_FLAG='Y' AND SOURCE='OC') OR
                       (NVL(PI_UC_FLAG,'N')='N' AND SOURCE IN ('OC','UC')));
      END IF;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END GET_UC;

   /*************************************************************************
      PROCEDURE : DO_RECUR
      PURPOSE :   計算用戶月租費
      DESCRIPTION : 計算用戶月租費
      PARAMETER:


      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 新安東京總額管控處理
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE DO_RECUR IS

      --ACCT_PKG(END_DATE要算)
      CURSOR C_RC IS
         SELECT AP.ROWID,
                AP.ACCT_PKG_SEQ,
                AP.OFFER_SEQ,
                AP.OFFER_ID,
                AP.OFFER_INSTANCE_ID,
                AP.ACCT_ID,
                AP.ACCT_KEY,
                AP.CUST_ID,
                AP.OFFER_LEVEL,
                AP.OFFER_LEVEL_ID,
                AP.PKG_ID,
                AP.PKG_TYPE_DTL,
                AP.PREPAYMENT,
                AP.PKG_PRIORITY,
                TRUNC(AP.EFF_DATE) EFF_DATE,
                --TRUNC(AP.END_DATE)-1 END_DATE,
                CASE --MODIFY FOR SR260229_Project-M Fixed line Phase I，席次異動超過出帳日影響
                  WHEN sign(nvl(AP.end_date,gdBILL_END_DATE)-gdBILL_END_DATE) = 1 and AP.CUR_BILLED IS NULL and PR.PAYMENT_TIMING = 'D' and AP.END_RSN IN ('DFC','CS1','CS2','CS3','CS4','CS5','CS6','CS7','CS8','CS9','CSZ')
                    THEN NULL
                  ELSE TRUNC(AP.END_DATE)-1
                END END_DATE,
                TRUNC(AP.FUTURE_EXP_DATE)-1 FUTURE_EXP_DATE,
                AP.STATUS,
                AP.INIT_PKG_QTY,
                AP.TOTAL_DISC_AMT,
                AP.CUR_QTY,
                AP.CUR_USE_QTY,
                AP.CUR_BAL_QTY,
                AP.CUR_BILLED,
                AP.VALIDITY_PERIOD,
                AP.BILL_QTY,
                AP.BILL_USE_QTY,
                AP.BILL_BAL_QTY,
                AP.BILL_DISC_AMT,
                AP.TRANS_IN_QTY,
                TRUNC(AP.TRANS_IN_DATE) TRANS_IN_DATE,
                AP.FIRST_BILL_DATE,
                AP.RECUR_BILLED,
                TRUNC(AP.SYS_EFF_DATE) SYS_EFF_DATE,
                TRUNC(AP.SYS_END_DATE)-1 SYS_END_DATE,
                AP.PRE_OFFER_SEQ,
                AP.PRE_PKG_SEQ,
                TRUNC(AP.ORIG_EFF_DATE) ORIG_EFF_DATE,
                AP.END_RSN, --2022/08/16 MODIFY FOR SR250171_ESDP_Migration_Project (退CREDIT改用RSN)
                AP.OVERWRITE,
                AP.OFFER_NAME,
                AP.RECUR_SEQ,
                AP.TEST_QTY,
                AP.TEST_USE_QTY,
                AP.TEST_BAL_QTY,
                AP.TEST_DISC_AMT,
                AP.TEST_TRANS_IN_QTY,
                AP.TEST_TRANS_IN_DATE,
                AP.TEST_RECUR_BILLED,
                AP.TEST_RECUR_SEQ
           FROM FY_TB_BL_ACCT_PKG AP, fy_tb_pbk_package_rc pr --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
          WHERE AP.ACCT_ID     =gnACCT_ID
            AND AP.ACCT_KEY    =MOD(gnACCT_ID,100)
            AND AP.PKG_TYPE_DTL='RC'
            AND AP.PKG_ID=PR.PKG_ID --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
            --AND AP.EFF_DATE<>NVL(AP.END_DATE,AP.EFF_DATE+1)
            AND AP.EFF_DATE<>DECODE(AP.END_RSN,'DFC',AP.EFF_DATE+1,NVL(AP.END_DATE,AP.EFF_DATE+1)) --2023/12/28 MODIFY FOR SR260229_Project-M Fixed line Phase 1.1，後收DFC退款，DFC忽略當天安裝當天移除
            AND AP.EFF_DATE<gdBILL_DATE
            --AND NVL(AP.END_DATE, gdBILL_FROM_DATE+1)>gdBILL_FROM_DATE
            --AND ((NVL (ap.end_date, gdBILL_FROM_DATE+ 1)>gdBILL_FROM_DATE AND pr.payment_timing = 'R') OR (pr.payment_timing = 'D'))  --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
            AND ((NVL (ap.end_date, gdBILL_FROM_DATE+ 1)>gdBILL_FROM_DATE AND pr.payment_timing = 'R') OR (NVL(ap.cur_billed,gdBILL_END_DATE) > ap.end_date AND ap.end_rsn = 'DFC' AND pr.payment_timing = 'R') OR ((NVL(ap.cur_billed,gdBILL_FROM_DATE) <> gdBILL_END_DATE OR NVL(ap.END_RSN,' ') IN ('DFC','CS1','CS2','CS3','CS4','CS5','CS6','CS7','CS8','CS9','CSZ')) AND pr.payment_timing = 'D') OR ((NVL(ap.cur_billed,gdBILL_FROM_DATE) = gdBILL_END_DATE AND PR.FREQUENCY = 1) AND pr.payment_timing = 'D'))  --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算 --2023/04/06 MODIFY FOR SR250171_ESDP_Migration_Project_Migration_重開月底最後一天落下月出帳與新增/修改此段DBMS --2023/07/25 MODIFY FOR SR250171_ESDP_Migration_Project_Migration_月繳前收次期帳單不受已出帳至BILL_END_DATE限制 --2023/10/11 MODIFY FOR SR260229_Project-M Fixed line Phase 1.1，後收DFC退款
            AND (AP.OFFER_LEVEL <> 'S' OR EXISTS (SELECT 1 FROM fy_tb_bl_bill_sub WHERE acct_id = AP.acct_id and subscr_id = AP.offer_level_id AND bill_seq = gnBILL_SEQ AND cycle = gnCYCLE AND cycle_month = gnCYCLE_MONTH)) --2024/06/27 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1，修正ACCT_PKG需參考出帳SUB名單
            AND AP.STATUS<>'CLOSE'
          ORDER BY PKG_ID;

      --PBK_PACKAGE_RC
      CURSOR C_PP(iPKG_ID NUMBER) IS
         SELECT PP.PKG_ID,
                PP.RC_ID,
                PP.CHARGE_CODE,
                PP.PRICING_TYPE,
                PP.PAYMENT_TIMING,
                PP.PRORATE_METHOD,
                NVL(PP.FREQUENCY,1) FREQUENCY,
                PP.QTY_CONDITION,
                PP.QTYS1,
                PP.QTYE1,
                PP.RATE1,
                PP.QTYS2,
                PP.QTYE2,
                PP.RATE2,
                PP.QTYS3,
                PP.QTYE3,
                PP.RATE3,
                PP.QTYS4,
                PP.QTYE4,
                PP.RATE4,
                PP.QTYS5,
                PP.QTYE5,
                PP.RATE5
           FROM FY_TB_PBK_PACKAGE_RC PP
          WHERE PKG_ID=iPKG_ID;
      R_PP        C_PP%ROWTYPE;

      CURSOR C_OP(iOFFER_SEQ NUMBER, iCNT NUMBER) IS
         SELECT /*+ index (FY_TB_BL_BILL_OFFER_PARAM FY_IX1_BL_BILL_OFFER_PARAM)*/ SUBSTR (SUBSTR (PARAM_NAME, 1, INSTR(PARAM_NAME,'_',-1) -1), --2021/02/20 MODIFY FOR MPBS_Migration 新增新安東京RC總額處理 add hint
                           INSTR (SUBSTR (PARAM_NAME,1, INSTR(PARAM_NAME,'_',-1) -1),'_') +1) PARAM_NAME,
                TO_NUMBER(PARAM_VALUE) PARAM_VALUE,
                EFF_DATE,
                TRUNC(END_DATE)-1 END_DATE
           FROM FY_TB_BL_BILL_OFFER_PARAM
          WHERE BILL_SEQ      =gnBILL_SEQ
            AND CYCLE         =gnCYCLE
            AND CYCLE_MONTH   =gNCYCLE_MONTH
            AND OFFER_SEQ     =iOFFER_SEQ
            AND ACCT_ID       =gnACCT_ID
            AND ACCT_KEY      =MOD(gnACCT_ID,100)
            AND OVERWRITE_TYPE IN ('RC','BL') --2020/06/09 MODIFY SR226548_遠傳(遠欣)企業客服新服務系統建置
            AND ((iCNT=1 AND PARAM_NAME NOT IN ('DEVICE_COUNT','InsuranceID')) OR  --服務數量 --2020/06/09 MODIFY SR226548_遠傳(遠欣)企業客服新服務系統建置
                 (iCNT=2 AND PARAM_NAME='DEVICE_COUNT'))
            AND PARAM_NAME NOT IN ('DEACT_FOR_CHANGE') --2022/08/25 MODIFY FOR SR250171_ESDP_Migration_Project (忽略DEACT_FOR_CHANGE判斷)
          ORDER BY PARAM_NAME,EFF_DATE ;

      --抓取subscr_id出帳資訊
      CURSOR C_SUB(iSUBSCR_ID NUMBER) IS
         SELECT SUBSCR_ID,
                OU_ID,
                TRUNC(EFF_DATE) EFF_DATE,
                TRUNC(END_DATE)-1 END_DATE,
                PRE_SUB_ID,
                INIT_RSN_CODE,
                INHERIT_FLAG,
                BILL_SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
           FROM FY_TB_BL_BILL_SUB
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gNCYCLE_MONTH
            AND ACCT_KEY    =MOD(gnACCT_ID,100)
            AND ACCT_ID     =gnACCT_ID
            AND SUBSCR_ID   =iSUBSCR_ID;
      R_SUB      C_SUB%ROWTYPE;

      Tab_PKG_RATES      t_PKG_RATES;
      NU_PKG_ID          FY_TB_BL_ACCT_PKG.PKG_ID%TYPE;
      DT_CI_FROM_DATE    DATE;
      DT_CI_END_DATE     DATE;
      DT_CTRL_FROM_DATE  DATE;
      DT_CTRL_END_DATE   DATE;
      NU_ACTIVE_DAY      NUMBER;
      NU_AMT_QTY         NUMBER;
      NU_CNT             NUMBER;
      NU_RATES           NUMBER;
      CH_ERR_CDE         VARCHAR2(4);
      On_Err             EXCEPTION;
      V_OFFER_SEQ        NUMBER;
      V_CUR_BILLED       DATE;
   BEGIN
      dbms_output.enable(999999999999999999999);
      NU_PKG_ID       := NULL;
      --GET ACCT_PKG
      FOR R_RC IN C_RC LOOP
         --設定一些全域的變數
         gnOFFER_SEQ         := R_RC.OFFER_SEQ;
         gnOFFER_ID          := R_RC.OFFER_ID;
         gnOFFER_INSTANCE_ID := R_RC.OFFER_INSTANCE_ID;
         gnPKG_ID            := R_RC.PKG_ID;
         gvOFFER_LEVEL       := R_RC.OFFER_LEVEL;
         gnOFFER_LEVEL_ID    := R_RC.OFFER_LEVEL_ID;
         gvCI_STEP           := NULL;
         gnBILL_SUBSCR_ID    := NULL;   --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
         --CHECK SUBSCR
         IF R_RC.OFFER_LEVEL='S' THEN
            gnSUBSCR_ID := R_RC.OFFER_LEVEL_ID;
            gnOU_ID     := NULL;
            --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 ADD C_SUB
            OPEN C_SUB(gnSUBSCR_ID);
            FETCH C_SUB INTO R_SUB;
            IF C_SUB%FOUND THEN
               gnBILL_SUBSCR_ID := R_SUB.BILL_SUBSCR_ID;
            END IF;
            CLOSE C_SUB;
         ELSE
            gnSUBSCR_ID := NULL;
            gnOU_ID     := R_RC.OFFER_LEVEL_ID;
         END IF;
         
         --MODIFY FOR SR260229_Project-M Fixed line Phase I，席次異動超過出帳日影響
         --IF R_RC.EFF_DATE >= gdBILL_FROM_DATE AND R_RC.EFF_DATE <= gdBILL_END_DATE AND R_RC.END_DATE > gdBILL_END_DATE AND R_RC.END_RSN = 'DFC' AND R_RC.pkg_type_dtl = 'RC' AND R_RC.CUR_BILLED IS NULL THEN
         --   R_RC.END_DATE := R_RC.FUTURE_EXP_DATE;
         --   DBMS_OUTPUT.Put_Line('席次異動超過出帳日影響'||'R_RC.END_DATE='||to_char(R_RC.END_DATE,'yyyymmdd'));
         --END IF;

         --2020/06/30 MODIFY FOR MPBS_Migration 增加新安東京判別
         gvTMNEWA   := 'N';  
         gvTXN_ID   := NULL;
         gvDYNAMIC_ATTRIBUTE := NULL;
         IF gvUSER='MPBL' THEN
            SELECT COUNT(1) 
              INTO NU_CNT
              FROM FY_TB_PBK_OFFER_PROPERTIES A
             WHERE OFFER_ID =R_RC.OFFER_ID
               AND PRT_ID   =gnPRT_ID
               AND PRT_VALUE=gvPRT_VALUE;
            IF NU_CNT>0 THEN
               gvTMNEWA := 'Y';
               --GET TXN_ID
               BEGIN
                  SELECT /*+ index (A FY_IX1_BL_BILL_OFFER_PARAM)*/ PARAM_VALUE --2021/02/20 MODIFY FOR MPBS_Migration 新增新安東京RC總額處理 add hint
                    INTO gvTXN_ID
                    FROM FY_TB_BL_BILL_OFFER_PARAM A
                   WHERE BILL_SEQ      =gnBILL_SEQ
                     AND CYCLE         =gnCYCLE
                     AND CYCLE_MONTH   =gNCYCLE_MONTH
                     AND OFFER_SEQ     =gnOFFER_SEQ
                     AND ACCT_ID       =gnACCT_ID
                     AND ACCT_KEY      =MOD(gnACCT_ID,100)
                     AND PARAM_NAME    =gvPARAM_NAME
                     AND EFF_DATE      =(SELECT /*+ index (FY_TB_BL_BILL_OFFER_PARAM FY_IX1_BL_BILL_OFFER_PARAM)*/ MAX(EFF_DATE) FROM FY_TB_BL_BILL_OFFER_PARAM --2021/02/20 MODIFY FOR MPBS_Migration 新增新安東京RC總額處理 add hint
                                                     WHERE BILL_SEQ      =gnBILL_SEQ
                                                       AND CYCLE         =gnCYCLE
                                                       AND CYCLE_MONTH   =gNCYCLE_MONTH
                                                       AND OFFER_SEQ     =gnOFFER_SEQ
                                                       AND ACCT_ID       =gnACCT_ID
                                                       AND ACCT_KEY      =MOD(gnACCT_ID,100)
                                                       AND PARAM_NAME    =A.PARAM_NAME
                                                       AND trunc(EFF_DATE)      <=NVL(R_RC.END_DATE+1,gdBILL_DATE));
               EXCEPTION WHEN OTHERS THEN
                  gvSTEP := Substr('GET TXN_ID.OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||','||SQLERRM, 1, 250);
                  gvERR_CDE := 'M001';
                  RAISE ON_ERR;
               END;
               SELECT 'Expiration date='||DECODE(TO_CHAR(R_RC.END_DATE+1,'YYYYMMDD'),NULL,TO_CHAR(R_RC.END_DATE+1,'YYYYMMDD'),LEAST(TO_CHAR(R_RC.END_DATE+1,'YYYYMMDD'),TO_CHAR(R_RC.FUTURE_EXP_DATE+1,'YYYYMMDD')))|| --如果L9_EXP比EXP小就用L9_EXP，如果EXP是空的就用空的
                      '#Is RC=true'||
                      '#L9 future expiration date='||TO_CHAR(R_RC.FUTURE_EXP_DATE+1, 'YYYYMMDD')||
                      '#SOC status='||DECODE(R_RC.END_DATE,NULL,'A','C')||
                      '#TXN_ID='||gvTXN_ID 
                 INTO gvDYNAMIC_ATTRIBUTE   
                 FROM DUAL;
            END IF;   
         END IF;  --gvUSER='MPBL'

         --2021/10/20 MODIFY SR239378 SDWAN_NPEP solution建置 (增加SDWAN判別)
         gvSDWAN   := 'N';  
         IF gnCYCLE IN ('10','15','20') THEN --2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CYCLE(15,20)
            BEGIN
               SELECT 'Y' 
                 INTO gvSDWAN
                 FROM FY_TB_PBK_OFFER_PROPERTIES A
                WHERE OFFER_ID =R_RC.OFFER_ID
                  AND PRT_ID   =gnPRT_ID
                  AND PRT_VALUE=gvPRT_VALUE;
            EXCEPTION WHEN OTHERS THEN 
               gvSDWAN := 'N';
            END;
            DBMS_OUTPUT.Put_Line('OFFER_ID='||R_RC.OFFER_ID||', SD-WAN='||TO_CHAR(gvSDWAN));
         END IF;
         
         --2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project (增加DEACT_FOR_CHANGE判斷)
         /*gvDFC   := 'N';
         IF gnCYCLE='10' THEN
            BEGIN
               SELECT 'Y' 
                 INTO gvDFC
           FROM FY_TB_BL_BILL_OFFER_PARAM
          WHERE BILL_SEQ      =gnBILL_SEQ
            AND CYCLE         =gnCYCLE
            AND CYCLE_MONTH   =gNCYCLE_MONTH
            AND OFFER_SEQ     =gnOFFER_SEQ
            AND ACCT_ID       =gnACCT_ID
            AND ACCT_KEY      =MOD(gnACCT_ID,100)
            AND OVERWRITE_TYPE IN ('RC','BL')
            AND PARAM_NAME='DEACT_FOR_CHANGE'
            AND PARAM_VALUE='Y'
          ORDER BY PARAM_NAME,EFF_DATE ;
            EXCEPTION WHEN OTHERS THEN 
               gvDFC := 'N';
            END;
            DBMS_OUTPUT.Put_Line('OFFER_ID='||R_RC.OFFER_ID||', DEACT_FOR_CHANGE='||TO_CHAR(gvDFC));
         END IF;*/

         --GET RC_PACKAGE
         --IF NU_PKG_ID IS NULL OR NU_PKG_ID<>R_RC.PKG_ID THEN
         IF NU_PKG_ID IS NULL OR NU_PKG_ID<>R_RC.PKG_ID OR gnCYCLE IN ('10','15','20') THEN --2022/11/14 MODIFY FOR SR250171_ESDP_Migration_Project_HGBN先開放讓每個pkg都抓取初始值，避免無overwrite時發生錯誤金額計算 --2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CYCLE(15,20)
            NU_PKG_ID := R_RC.PKG_ID;
            gvSTEP := 'GET PBK_PKG_RC.PKG_ID='||TO_CHAR(R_RC.PKG_ID)||':';
            OPEN C_PP(R_RC.PKG_ID);
            FETCH C_PP INTO R_PP;
            IF C_PP%NOTFOUND THEN
               gvSTEP    := gvSTEP||' NOT FOUND';
               gvERR_CDE := 'P001';
               RAISE ON_ERR;
            END IF;
            CLOSE C_PP;
            --設定PACKAGE的變數
            gvCHRG_ID        := R_PP.RC_ID;
            gvCHARGE_CODE    := R_PP.CHARGE_CODE;
            gvPRICING_TYPE   := R_PP.PRICING_TYPE;
            gvPAYMENT_TIMING := R_PP.PAYMENT_TIMING;
            gvPRORATE_METHOD := R_PP.PRORATE_METHOD;
            gnFREQUENCY      := R_PP.FREQUENCY;
            gvQTY_CONDITION  := R_PP.QTY_CONDITION;
         END IF;

         --2022/08/16 MODIFY FOR SR250171_ESDP_Migration_Project (增加DEACT_FOR_CHANGE判斷)
         --gvDFC   := R_RC.END_RSN;
         IF R_RC.END_RSN='DFC' OR (gvPAYMENT_TIMING='D' and gnFREQUENCY=1 and R_RC.END_RSN IN ('CS1','CS2','CS3','CS4','CS5','CS6','CS7','CS8','CS9','CSZ')) THEN --2023/04/28 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增月繳預收停用退費
            gvDFC := 'Y';
         ELSE
            gvDFC := 'N';
         END IF;
         
         --計費日期處理(END_DATE計算_已做-1處理)
         IF gvPAYMENT_TIMING='D' THEN --預收    
            gvDYNAMIC_ATTRIBUTE := gvDYNAMIC_ATTRIBUTE||'#PAYMENT_TIMING=D'; --2022/08/01 MODIFY FOR SR250171_ESDP_Migration_Project_年繳帳單要顯示收費期間
            --IF R_RC.CUR_BILLED>gdBILL_FROM_DATE THEN
            IF R_RC.CUR_BILLED>=gdBILL_FROM_DATE THEN --2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project_CUR_BILLED日期為已收費最終日，修正最終日次年重複收費問題
               IF (R_RC.END_DATE<R_RC.CUR_BILLED OR
                  R_RC.FUTURE_EXP_DATE<R_RC.CUR_BILLED OR
                  R_RC.SYS_END_DATE<R_RC.CUR_BILLED) AND 
                  (R_RC.END_DATE<gdBILL_END_DATE OR --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改
                  R_RC.FUTURE_EXP_DATE<gdBILL_END_DATE OR --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改
                  --R_RC.SYS_END_DATE<gdBILL_END_DATE) THEN --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改
                  R_RC.SYS_END_DATE<gdBILL_END_DATE) AND gvDFC = 'Y' THEN --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改 --2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project (增加DEACT_FOR_CHANGE判斷)
                  DT_CI_FROM_DATE := least(NVL(R_RC.END_DATE,NVL(R_RC.FUTURE_EXP_DATE,R_RC.SYS_END_DATE)),
                                           NVL(R_RC.FUTURE_EXP_DATE,NVL(R_RC.END_DATE,R_RC.SYS_END_DATE)),
                                           NVL(R_RC.SYS_END_DATE,NVL(R_RC.END_DATE,R_RC.FUTURE_EXP_DATE))
                                           )+1; ---取其小
                  gvCI_STEP :='T'; ---- 補退費  
                  DT_CI_END_DATE  := R_RC.CUR_BILLED;
               ELSIF R_RC.CUR_BILLED>=gdBILL_FROM_DATE AND R_RC.CUR_BILLED <= gdBILL_END_DATE THEN --2022/11/07 MODIFY FOR SR250171_ESDP_Migration_Project_修復當已出帳不需退費就需要判斷是否需收費
                  gvCI_STEP :='D';
                  DT_CI_FROM_DATE :=R_RC.CUR_BILLED+1;
                  DT_CI_END_DATE  :=least(NVL(R_RC.END_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                          NVL(R_RC.FUTURE_EXP_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                          NVL(R_RC.SYS_END_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                          --ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)); ---取其小 --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                                          ADD_MONTHS(DT_CI_FROM_DATE,gnFREQUENCY)-1); ---取其小 --N+N期間計算 改為N期間計算 --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                  --IF DT_CI_FROM_DATE = gdBILL_DATE THEN --2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project_Migration預收當起算日為BILL_DATE則不出帳，落下期出帳 --2023/04/06 MODIFY FOR SR250171_ESDP_Migration_Project_Migration_重開月底最後一天落下月出帳與新增/修改此段DBMS
                  --  gvCI_STEP :='Z';  --放Z等於不計費
                  --  DBMS_OUTPUT.Put_Line('月租PKG_SEQ='||TO_CHAR(R_RC.ACCT_PKG_SEQ)||' gvCI_STEP='||gvCI_STEP);
                  --END IF;
                  --DBMS_OUTPUT.Put_Line('-------------------------------------------------------------------------check000-----------------------------------------------------------------------');
                  --DBMS_OUTPUT.Put_Line('DT_CI_END_DATE='||to_char(DT_CI_END_DATE,'yyyymmdd')||', gvCI_STEP='||gvCI_STEP);
               ELSE --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改
                  gvCI_STEP :='S'; --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改
                  DT_CI_FROM_DATE  := gdBILL_FROM_DATE; --2022/11/02 MODIFY FOR SR250171_ESDP_Migration_Project_修復S狀態無指定起訖日期，導致日期會取上一個PKG日期，影響資料判讀
                  DT_CI_END_DATE  := gdBILL_END_DATE; --2022/11/02 MODIFY FOR SR250171_ESDP_Migration_Project_修復S狀態無指定起訖日期，導致日期會取上一個PKG日期，影響資料判讀
               END IF;
               --IF R_RC.CUR_BILLED IS NOT NULL THEN --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
               --   gvCI_STEP :='S';
               --END IF;      
                  --DBMS_OUTPUT.Put_Line('-------------------------------------------------------------------------check00-----------------------------------------------------------------------');
                  --DBMS_OUTPUT.Put_Line('DT_CI_END_DATE='||to_char(DT_CI_END_DATE,'yyyymmdd')||', gvCI_STEP='||gvCI_STEP);
            ELSE
               IF R_RC.CUR_BILLED IS NOT NULL THEN
                  DT_CI_FROM_DATE :=R_RC.CUR_BILLED+1;
               ELSE
                  DT_CI_FROM_DATE :=R_RC.EFF_DATE;
               END IF;              
               DT_CI_END_DATE  :=least(NVL(R_RC.END_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                       NVL(R_RC.FUTURE_EXP_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                       NVL(R_RC.SYS_END_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                       --ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)); ---取其小 --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                                       ADD_MONTHS(DT_CI_FROM_DATE,gnFREQUENCY)-1); ---取其小 --N+N期間計算 改為N期間計算 --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
               gvCI_STEP :='D'; ---- 預收 --BUG由R改為D --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
               IF R_RC.CUR_BILLED IS NOT NULL THEN
                  DBMS_OUTPUT.Put_Line('月租PKG_SEQ='||TO_CHAR(R_RC.ACCT_PKG_SEQ)||' DT_CI_FROM_DATE='||to_char(DT_CI_FROM_DATE,'yyyymmdd')||', ADD_MONTHS((gdBILL_DATE),-1)='||to_char(ADD_MONTHS((gdBILL_DATE),-1),'yyyymmdd')); --2023/04/06 MODIFY FOR SR250171_ESDP_Migration_Project_Migration_重開月底最後一天落下月出帳與新增/修改此段DBMS
                  --IF DT_CI_FROM_DATE = gdBILL_DATE THEN --2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project_Migration預收當起算日為BILL_DATE則不出帳，落下期出帳
                  --  gvCI_STEP :='Z';  --放Z等於不計費
                  --  DBMS_OUTPUT.Put_Line('gvCI_STEP='||gvCI_STEP);
                  --END IF;
               END IF;
                  --DBMS_OUTPUT.Put_Line('-------------------------------------------------------------------------check0-----------------------------------------------------------------------');
                  --DBMS_OUTPUT.Put_Line('DT_CI_END_DATE='||to_char(DT_CI_END_DATE,'yyyymmdd')||', gvCI_STEP='||gvCI_STEP);
            END IF;
         ELSIF gvPAYMENT_TIMING='R' AND gvDFC = 'Y' AND R_RC.END_DATE<R_RC.CUR_BILLED AND R_RC.END_DATE<gdBILL_END_DATE THEN --2023/10/11 MODIFY FOR SR260229_Project-M Fixed line Phase 1.1，後收DFC退款
                  gvCI_STEP :='T';
                  DT_CI_FROM_DATE := least(NVL(R_RC.END_DATE,NVL(R_RC.FUTURE_EXP_DATE,R_RC.SYS_END_DATE)),
                                           NVL(R_RC.FUTURE_EXP_DATE,NVL(R_RC.END_DATE,R_RC.SYS_END_DATE)),
                                           NVL(R_RC.SYS_END_DATE,NVL(R_RC.END_DATE,R_RC.FUTURE_EXP_DATE))
                                           )+1;
                  DT_CI_END_DATE  := R_RC.CUR_BILLED;
                  DBMS_OUTPUT.Put_Line('gvCI_STEP='||gvCI_STEP||',gnPKG_ID='||gnPKG_ID);
         ELSE -- PAYMENT_TIMING='R' --後收
            IF ADD_MONTHS(NVL(R_RC.CUR_BILLED,R_RC.EFF_DATE),gnFREQUENCY)<=gdBILL_END_DATE OR
               gnFREQUENCY=1 OR
               R_RC.END_DATE<=gdBILL_END_DATE OR
               R_RC.FUTURE_EXP_DATE<=gdBILL_END_DATE OR
               R_RC.SYS_END_DATE<=gdBILL_END_DATE THEN
               IF R_RC.CUR_BILLED IS NOT NULL THEN
                  DT_CI_FROM_DATE :=R_RC.CUR_BILLED+1;
               ELSE
                  DT_CI_FROM_DATE :=R_RC.EFF_DATE;
               END IF;
               DT_CI_END_DATE  :=least(NVL(R_RC.END_DATE,gdBILL_END_DATE),
                                       NVL(R_RC.FUTURE_EXP_DATE,gdBILL_END_DATE),
                                       NVL(R_RC.SYS_END_DATE,gdBILL_END_DATE),
                                       gdBILL_END_DATE); ---取其小
               gvCI_STEP :='R';    
            END IF;
         END IF;  --PAYMENT_TIMING
    --DBMS_OUTPUT.Put_Line('月租PKG_SEQ='||TO_CHAR(R_RC.ACCT_PKG_SEQ)||' FROM_DATE='||TO_CHAR(DT_CI_FROM_DATE,'YYYYMMDD')||',END_DATE='||TO_CHAR(DT_CI_END_DATE,'YYYYMMDD'));
         --需產生計費資料
         IF gvCI_STEP IS NOT NULL THEN
            --OVERWRITE OFFER_PARAM
            gvSTEP := 'GET OFFER_PARAM.OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||':';
            gvOVERWRITE := 'N';
            FOR R_OP IN C_OP(gnOFFER_SEQ, 1) LOOP
               gvOVERWRITE := 'Y';
               IF R_OP.PARAM_NAME='QTYS1' THEN
                  R_PP.QTYS1 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='QTYE1' THEN
                  R_PP.QTYE1 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='RATE1' THEN
                  R_PP.RATE1 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='QTYS2' THEN
                  R_PP.QTYS2 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='QTYE2' THEN
                  R_PP.QTYE2 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='RATE2' THEN
                  R_PP.RATE2 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='QTYS3' THEN
                  R_PP.QTYS3 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='QTYE3' THEN
                  R_PP.QTYE3 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='RATE3' THEN
                  R_PP.RATE3 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='QTYS4' THEN
                  R_PP.QTYS4 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='QTYE4' THEN
                  R_PP.QTYE4 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='RATE4' THEN
                  R_PP.RATE4 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='QTYS5' THEN
                  R_PP.QTYS5 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='QTYE5' THEN
                  R_PP.QTYE5 :=R_OP.PARAM_VALUE;
               ELSIF R_OP.PARAM_NAME='RATE5' THEN
                  R_PP.RATE5 :=R_OP.PARAM_VALUE;
               END IF;
            END LOOP; --C_OP
            --MOVE RATES TO OBJECT
            NU_CNT := 0;
            FOR i IN 1 .. 5 LOOP
               IF gvPRICING_TYPE='F' THEN --收費類型:Flat
                  NU_CNT := 1;
                  Tab_PKG_RATES(Nu_CNT).ITEM_NO  := 1;
                  Tab_PKG_RATES(Nu_CNT).QTY_S    := 0;
                  Tab_PKG_RATES(Nu_CNT).QTY_E    := NULL;
                  Tab_PKG_RATES(Nu_CNT).RATES    := R_PP.RATE1;
                  EXIT;
               ELSE
                  SELECT DECODE(i,1,R_PP.RATE5,2,R_PP.RATE4,3,R_PP.RATE3,4,R_PP.RATE2,R_PP.RATE1)
                    INTO NU_RATES
                    FROM DUAL;
                  IF NU_RATES IS NOT NULL THEN
                     NU_CNT := NU_CNT + 1;
                     SELECT DECODE(i,1,5,2,4,3,3,4,2,1),
                            DECODE(i,1,R_PP.QTYS5,2,R_PP.QTYS4,3,R_PP.QTYS3,4,R_PP.QTYS2,R_PP.QTYS1),
                            DECODE(i,1,R_PP.QTYE5,2,R_PP.QTYE4,3,R_PP.QTYE3,4,R_PP.QTYE2,R_PP.QTYE1),
                            DECODE(i,1,R_PP.RATE5,2,R_PP.RATE4,3,R_PP.RATE3,4,R_PP.RATE2,R_PP.RATE1)
                       INTO Tab_PKG_RATES(Nu_CNT).ITEM_NO,
                            Tab_PKG_RATES(Nu_CNT).QTY_S,
                            Tab_PKG_RATES(Nu_CNT).QTY_E,
                            Tab_PKG_RATES(Nu_CNT).RATES
                       FROM DUAL;
                  END IF;
               END IF;
            END LOOP;
            IF NU_CNT=0 THEN
               gvERR_CDE := 'D001';
               gvSTEP := 'PKG_ID='||TO_CHAR(gnPKG_ID)||'多皆費率皆為NULL';
               RAISE ON_ERR;
            ELSE
               FOR I IN NU_CNT+1 .. 5 LOOP
                  Tab_PKG_RATES(I).ITEM_NO := NULL;
               END LOOP;
            END IF;
            --QTY_CONDITION
            --IF gvQTY_CONDITION='D' AND gvPRICING_TYPE<>'F' THEN --服務數量
            IF gvQTY_CONDITION='D' AND gvCI_STEP != 'S' THEN --服務數量 --2022/07/28 MODIFY FOR SR250171_ESDP_Migration_Project (使年繳有單價*數量功能)  --2022/09/29 MODIFY FOR SR250171_ESDP_Migration_Project (gvCI_STEP='S'不須計算RC)
               DT_CTRL_FROM_DATE := DT_CI_FROM_DATE;
               DT_CTRL_END_DATE  := DT_CI_END_DATE;
               FOR R_OP IN C_OP(gnOFFER_SEQ, 2) LOOP
                  NU_AMT_QTY := R_OP.PARAM_VALUE;
                  DT_CTRL_FROM_DATE := greatest(DT_CTRL_FROM_DATE,R_OP.EFF_DATE);
                  --DT_CTRL_END_DATE  := least(DT_CI_END_DATE,NVL(R_OP.END_DATE,DT_CI_END_DATE));
                  IF gvCI_STEP IN ('T') THEN --2022/09/29 MODIFY FOR SR250171_ESDP_Migration_Project (年繳退款抓END_DATE)
                     DT_CTRL_END_DATE  := greatest(DT_CI_END_DATE,NVL(R_OP.END_DATE,DT_CI_END_DATE));
                  ELSE
                     DT_CTRL_END_DATE  := least(DT_CI_END_DATE,NVL(R_OP.END_DATE,DT_CI_END_DATE));

                  --MODIFY FOR SR260229_Project-M Fixed line Phase I，席次異動超過出帳日影響
                  IF R_RC.EFF_DATE >= gdBILL_FROM_DATE AND R_RC.EFF_DATE <= gdBILL_END_DATE AND R_RC.END_DATE IS NULL AND R_RC.END_RSN = 'DFC' AND R_RC.pkg_type_dtl = 'RC' AND R_RC.CUR_BILLED IS NULL THEN
                     DT_CTRL_END_DATE  := DT_CI_END_DATE;
                     DBMS_OUTPUT.Put_Line('席次異動超過出帳日影響'||'DT_CTRL_END_DATE='||to_char(DT_CTRL_END_DATE,'yyyymmdd'));
                  END IF;

                  END IF;
                  gvSTEP := 'OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||'.GET_ACTIVE_DAY:';
                  GET_ACTIVE_DAY('RC',
                                 DT_CTRL_FROM_DATE,
                                 DT_CTRL_END_DATE,
                                 NU_AMT_QTY ,
                                 Tab_PKG_RATES,
                                 NU_ACTIVE_DAY); 

            --預收suspend天數計算 --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算 (未完成，還需再增加產品條件)
            --IF R_RC.CUR_BILLED IS NOT NULL THEN
            --IF gvCI_STEP = 'D' OR gvCI_STEP = 'S' THEN --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改
                --DBMS_OUTPUT.Put_Line('LINE1055 - NU_AMT_QTY ='|| NU_AMT_QTY );
                --    GET_SUSPEND_DAY('RC',
                --                           NU_AMT_QTY,
                --                           Tab_PKG_RATES,
                --                           R_RC.CUR_BILLED,--sharon add
                --                           NU_ACTIVE_DAY);
                --DBMS_OUTPUT.Put_Line('LINE1060 - NU_ACTIVE_DAY ='|| NU_ACTIVE_DAY );
            --END IF; 

                  IF gvERR_CDE<>'0000' THEN
                     gvSTEP := SUBSTR('OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||'.GET_ACTIVE_DAY:'||gvERR_MSG,1,250);
                     RAISE ON_ERR;
                  END IF;
                  DT_CTRL_FROM_DATE := DT_CTRL_END_DATE+1;
                  IF DT_CTRL_END_DATE=DT_CI_END_DATE THEN
                     EXIT;
                  END IF;
               END LOOP;
            ELSE
               IF gvPRICING_TYPE='F' THEN
                  NU_AMT_QTY := 1;
               ELSIF gvQTY_CONDITION='M' THEN  --啟用月數
                  --GET MONTH
                  gvSTEP := 'GET_MONTH:';
                  GET_MONTH(TRUNC(NVL(R_RC.ORIG_EFF_DATE,R_RC.EFF_DATE)),
                            TRUNC(DT_CI_END_DATE),
                            NU_AMT_QTY);
                  IF gvERR_CDE<>'0000' THEN
                     gvSTEP := SUBSTR(gvSTEP||gvERR_MSG,1,250);
                     RAISE ON_ERR;
                  END IF;
               ELSIF gvQTY_CONDITION='P' THEN  --門號數
                  IF R_RC.OFFER_LEVEL='O' THEN
                     SELECT NVL(COUNT(1),0)
                       INTO NU_AMT_QTY
                       FROM FY_TB_BL_BILL_SUB A
                      WHERE BILL_SEQ   = gnBILL_SEQ
                        AND CYCLE      = gnCYCLE
                        AND CYCLE_MONTH= gnCYCLE_MONTH
                        AND ACCT_ID    = gnACCT_ID
                        AND ACCT_KEY   = MOD(gnACCT_ID,100)
                        AND EFF_DATE  <= gdBILL_END_DATE
                        AND (END_DATE IS NULL OR END_DATE>gdBILL_FROM_DATE)
                        AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                    Start with OU_ID =R_RC.OFFER_LEVEL_ID
                                  Connect by prior OU_ID=PARENT_OU_ID);
                  END IF;
               END IF;
               IF gvPRICING_TYPE='F' AND R_PP.RATE1=0 THEN --RC=0 --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                  --CALL INSERT BILL_CI
                  gvSTEP := 'INS_CI:';
                  INS_CI(DT_CI_FROM_DATE,
                         DT_CI_END_DATE,
                         'RC', ---PI_SOURCE
                         NULL, ---PI_SOURCE_CI_SEQ ,
                         NULL, ---PI_SOURCE_OFFER_ID,
                         gvOFFER_LEVEL,  ---PI_SERVICE_RECEIVER_TYPE,
                         0);   ---PI_CHRG_AMT
                  IF gvERR_CDE<>'0000' THEN
                     gvSTEP := SUBSTR('INS_CI:'||gvERR_MSG,1,250);
                     RAISE ON_ERR;
                  END IF;
               ELSE
         --DBMS_OUTPUT.Put_Line('LINE1117 - gvCI_STEP ='|| gvCI_STEP );

          --IF gvCI_STEP != 'S' THEN --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改
          IF gvCI_STEP NOT IN ('S','Z') THEN --2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project_Migration預收當起算日為BILL_DATE則不出帳，落下期出帳
                  gvSTEP := 'OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||'.GET_ACTIVE_DAY:';
                  --2023/04/20 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增月繳預收功能
                  IF gnCYCLE IN ('10','15','20') and gvPAYMENT_TIMING='D' and gnFREQUENCY = 1 and gvCI_STEP != 'T' THEN --2023/04/20 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增月繳預收功能，月繳預收_HGBN預收非年繳非退款收費至出帳當月最後一天 --2023/10/16 MODIFY FOR SR263630_LSP產品制式化需求開發，新增三年繳預收
                     DBMS_OUTPUT.Put_Line('DT_CI_END_DATE='||TO_CHAR(DT_CI_END_DATE,'YYYYMMDD')||' ,gdBILL_FROM_DATE='||TO_CHAR(gdBILL_FROM_DATE,'YYYYMMDD'));
                     --DT_CI_END_DATE  := ADD_MONTHS(gdBILL_END_DATE,1);
                     DT_CI_END_DATE  :=least(NVL(R_RC.END_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                                         NVL(R_RC.FUTURE_EXP_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                                         NVL(R_RC.SYS_END_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                                         ADD_MONTHS(gdBILL_END_DATE,1));
                     DBMS_OUTPUT.Put_Line('DT_CI_END_DATE='||TO_CHAR(DT_CI_END_DATE,'YYYYMMDD'));
                  END IF;
                  gvSTEP := 'OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||'.GET_ACTIVE_DAY:';
                  GET_ACTIVE_DAY('RC',
                                 DT_CI_FROM_DATE,
                                 DT_CI_END_DATE,
                                 NU_AMT_QTY ,
                                 Tab_PKG_RATES,
                                 NU_ACTIVE_DAY);
          END IF; --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改
                                 
            --預收suspend天數計算 --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算 (未完成，還需再增加產品條件)
          --IF R_RC.CUR_BILLED IS NOT NULL THEN
          IF (gvCI_STEP = 'T' AND gvSDWAN = 'N') OR gvCI_STEP = 'S' THEN --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改 --2023/07/25 MODIFY SR260229_Project-M Fixed line Phase I，SUSPEND重複退費問題修正
          GET_SUSPEND_DAY('RC',
                       NU_AMT_QTY,
                       Tab_PKG_RATES,
                       R_RC.CUR_BILLED,--sharon add
                       NU_ACTIVE_DAY);
          ELSIF gvCI_STEP = 'D' THEN
          gvCI_STEP :='S'; --2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改
          GET_SUSPEND_DAY('RC',
                                 NU_AMT_QTY,
                                 Tab_PKG_RATES,
                                 R_RC.CUR_BILLED,--sharon add
                                 NU_ACTIVE_DAY);
          END IF;
            DBMS_OUTPUT.Put_Line('charge start--->');
            DBMS_OUTPUT.Put_Line('ACCT_ID='||TO_CHAR(gnACCT_ID)||', S/O_LEVEL='||TO_CHAR(gvOFFER_LEVEL)||', S/O='||TO_CHAR(gnOFFER_INSTANCE_ID));                                 
            DBMS_OUTPUT.Put_Line('OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||', PKG_SEQ='||TO_CHAR(R_RC.ACCT_PKG_SEQ));                                 
            DBMS_OUTPUT.Put_Line('FROM_DATE='||TO_CHAR(DT_CI_FROM_DATE,'yyyy/mm/dd')||', END_DATE='||TO_CHAR(DT_CI_END_DATE,'yyyy/mm/dd')||', ACTIVE_DAY='||TO_CHAR(NU_ACTIVE_DAY));                                 
            DBMS_OUTPUT.Put_Line('<---charge end');
                  IF gvERR_CDE<>'0000' THEN
                     gvSTEP := SUBSTR('OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||'.GET_ACTIVE_DAY:'||gvERR_MSG,1,250);
                     RAISE ON_ERR;
                  END IF;
               END IF;
            END IF;  --R_DS.QTY_CONDITION
            --
            gvSTEP := 'UPDATE ACCT_PKG.SEQ='||TO_CHAR(R_RC.ACCT_PKG_SEQ)||':';                              
            UPDATE FY_TB_BL_ACCT_PKG
               --SET RECUR_BILLED=DECODE(gvPROC_TYPE,'B',DECODE(gvCI_STEP,'T',DT_CI_FROM_DATE,DT_CI_END_DATE),RECUR_BILLED),
               SET RECUR_BILLED=DECODE(gvPROC_TYPE,'B',DECODE(gvCI_STEP,'T',DT_CI_FROM_DATE,'Z',NULL,DT_CI_END_DATE),RECUR_BILLED), --2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project_預收當起算日為BILL_DATE則不出帳，落下期出帳
                   RECUR_SEQ   =DECODE(gvPROC_TYPE,'B',gnBILL_SEQ,RECUR_SEQ),
                   --TEST_RECUR_BILLED=DECODE(gvPROC_TYPE,'T',DECODE(gvCI_STEP,'T',DT_CI_FROM_DATE,DT_CI_END_DATE),TEST_RECUR_BILLED),
                   TEST_RECUR_BILLED=DECODE(gvPROC_TYPE,'T',DECODE(gvCI_STEP,'T',DT_CI_FROM_DATE,'Z',NULL,DT_CI_END_DATE),TEST_RECUR_BILLED), --2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project_預收當起算日為BILL_DATE則不出帳，落下期出帳
                   TEST_RECUR_SEQ   =DECODE(gvPROC_TYPE,'T',gnBILL_SEQ,TEST_RECUR_SEQ),
                   UPDATE_DATE =SYSDATE,
                   UPDATE_USER =gvUSER
             WHERE ROWID=R_RC.ROWID;
         END IF;  -- CI_STEP
      END LOOP; --C_RC
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END DO_RECUR;

   /*************************************************************************
      PROCEDURE : DO_DISCOUNT
      PURPOSE :   計算用戶折扣資料
      DESCRIPTION : 計算用戶折扣資料
      PARAMETER:
            PI_PROC_ID             :執行序號(1:ACCT_GROUP='MV'_只執行PRE_SUBSCR IS NULL/2:只執行MV)
            PI_SUBSCR_ID           :執行序號=2:執行該SUBSCR_ID
            PI_PRE_CYCLE           :PRE_ACCT_ID CYCLE

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 增加新安東京判別
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE DO_DISCOUNT(PI_PROC_ID       IN   NUMBER,
                         PI_SUBSCR_ID     IN   NUMBER,
                         PI_PRE_CYCLE     IN   NUMBER) IS

      --GET ACCT_PKG
      CURSOR C_RC IS
         SELECT 'N' MARKET_LEVEL,
                AP.ROWID,
                AP.ACCT_PKG_SEQ,
                AP.OFFER_SEQ OFFER_SEQ,
                AP.OFFER_ID,
                AP.OFFER_INSTANCE_ID,
                AP.ACCT_ID,
                AP.ACCT_KEY,
                AP.CUST_ID,
                AP.OFFER_LEVEL,
                AP.OFFER_LEVEL_ID,
                AP.PKG_ID,
                AP.PKG_TYPE_DTL,
                AP.PREPAYMENT,
                AP.PKG_PRIORITY PKG_PRIORITY,
                TRUNC(AP.EFF_DATE) EFF_DATE,
                TRUNC(AP.END_DATE)-1 END_DATE,
                TRUNC(AP.FUTURE_EXP_DATE)-1 FUTURE_EXP_DATE,
                AP.STATUS,
                AP.INIT_PKG_QTY,
                AP.TOTAL_DISC_AMT,
                AP.CUR_QTY,
                AP.CUR_USE_QTY,
                AP.CUR_BAL_QTY,
                AP.CUR_BILLED,
                AP.VALIDITY_PERIOD,
                AP.BILL_QTY,
                AP.BILL_USE_QTY,
                AP.BILL_BAL_QTY,
                AP.BILL_DISC_AMT,
                AP.TRANS_IN_QTY,
                TRUNC(AP.TRANS_IN_DATE) TRANS_IN_DATE,
                AP.FIRST_BILL_DATE,
                AP.RECUR_BILLED,
                TRUNC(AP.SYS_EFF_DATE) SYS_EFF_DATE,
                TRUNC(AP.SYS_END_DATE)-1 SYS_END_DATE,
                AP.PRE_OFFER_SEQ,
                AP.PRE_PKG_SEQ,
                TRUNC(AP.ORIG_EFF_DATE) ORIG_EFF_DATE,
                AP.OVERWRITE,
                AP.END_RSN,
                AP.OFFER_NAME,
                AP.RECUR_SEQ,
                AP.TEST_QTY,
                AP.TEST_USE_QTY,
                AP.TEST_BAL_QTY,
                AP.TEST_DISC_AMT,
                AP.TEST_TRANS_IN_QTY,
                AP.TEST_TRANS_IN_DATE,
                AP.TEST_RECUR_BILLED,
                AP.TEST_RECUR_SEQ
           FROM FY_TB_BL_ACCT_PKG AP
          WHERE AP.ACCT_ID     =gnACCT_ID
            AND AP.ACCT_KEY    =MOD(gnACCT_ID,100)
            AND AP.PKG_TYPE_DTL IN ('BDN','BDX')
            AND AP.EFF_DATE<>NVL(AP.END_DATE,AP.EFF_DATE+1)
            AND AP.EFF_DATE<gdBILL_END_DATE+1
            AND NVL(AP.END_DATE, gdBILL_FROM_DATE+1)>gdBILL_FROM_DATE
            AND AP.STATUS<>'CLOSE'
            AND ((PI_PROC_ID=1 AND ((gvPN_FLAG='Y' AND OFFER_LEVEL='S' --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 ADD gvPN_FLAG判別
                                                   AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_SUB
                                                                 WHERE BILL_SEQ   =gnBILL_SEQ
                                                                   AND CYCLE      =gnCYCLE
                                                                   AND CYCLE_MONTH=gnCYCLE_MONTH
                                                                   AND ACCT_ID    =AP.ACCT_ID
                                                                   AND ACCT_KEY   =AP.ACCT_KEY
                                                                   AND SUBSCR_ID  =AP.OFFER_LEVEL_ID
                                                                   AND SUBSCR_ID <>BILL_SUBSCR_ID)
                                     ) OR
                                    (gvPN_FLAG='N' AND NOT EXISTS(SELECT 1 FROM FY_TB_BL_BILL_SUB
                                                                     WHERE BILL_SEQ   =gnBILL_SEQ
                                                                       AND CYCLE      =gnCYCLE
                                                                       AND CYCLE_MONTH=gnCYCLE_MONTH
                                                                       AND ACCT_ID    =AP.ACCT_ID
                                                                       AND ACCT_KEY   =AP.ACCT_KEY
                                                                       AND SUBSCR_ID  =AP.OFFER_LEVEL_ID
                                                                       AND SUBSCR_ID <>BILL_SUBSCR_ID)
                                                   AND (gvACCT_GROUP<>'MV' OR --2021/10/06 MODIFY FOR 小額預繳處理 
                                                        OFFER_LEVEL = 'O' OR
                                                        NOT EXISTS(SELECT 1 FROM FY_TB_BL_BILL_MV_SUB
                                                                    WHERE BILL_SEQ   =gnBILL_SEQ
                                                                      AND CYCLE      =gnCYCLE
                                                                      AND CYCLE_MONTH=gnCYCLE_MONTH
                                                                      AND ACCT_ID    =AP.ACCT_ID
                                                                      AND SUBSCR_ID  =AP.OFFER_LEVEL_ID
                                                                      AND PRE_SUBSCR_ID IS NOT NULL)))
                  )) OR
                 (PI_PROC_ID=2 AND OFFER_LEVEL='S' AND OFFER_LEVEL_ID=PI_SUBSCR_ID))
        UNION --2019/12/12 MODIFY SR220754_AI_Star_FY_TB_BL_ACCT_PKG增加抓取MV折扣的UNION
         SELECT 'N' MARKET_LEVEL,
                AP.ROWID,
                AP.ACCT_PKG_SEQ,  
                AP.OFFER_SEQ OFFER_SEQ,
                AP.OFFER_ID,      
                AP.OFFER_INSTANCE_ID,
                AP.ACCT_ID,       
                AP.ACCT_KEY,      
                AP.CUST_ID,       
                AP.OFFER_LEVEL,
                AP.OFFER_LEVEL_ID,
                AP.PKG_ID,
                AP.PKG_TYPE_DTL,
                AP.PREPAYMENT,
                AP.PKG_PRIORITY PKG_PRIORITY,
                TRUNC(AP.EFF_DATE) EFF_DATE,
                TRUNC(AP.END_DATE)-1 END_DATE,
                TRUNC(AP.FUTURE_EXP_DATE)-1 FUTURE_EXP_DATE,
                AP.STATUS,         
                AP.INIT_PKG_QTY,   
                AP.TOTAL_DISC_AMT, 
                AP.CUR_QTY,
                AP.CUR_USE_QTY,
                AP.CUR_BAL_QTY,
                AP.CUR_BILLED,
                AP.VALIDITY_PERIOD,
                AP.BILL_QTY,
                AP.BILL_USE_QTY,
                AP.BILL_BAL_QTY,
                AP.BILL_DISC_AMT,
                AP.TRANS_IN_QTY,
                TRUNC(AP.TRANS_IN_DATE) TRANS_IN_DATE,
                AP.FIRST_BILL_DATE,
                AP.RECUR_BILLED,
                TRUNC(AP.SYS_EFF_DATE) SYS_EFF_DATE,
                TRUNC(AP.SYS_END_DATE)-1 SYS_END_DATE,
                AP.PRE_OFFER_SEQ,
                AP.PRE_PKG_SEQ,
                TRUNC(AP.ORIG_EFF_DATE) ORIG_EFF_DATE,
                AP.OVERWRITE,
                AP.END_RSN,
                AP.OFFER_NAME,
                AP.RECUR_SEQ,
                AP.TEST_QTY,
                AP.TEST_USE_QTY,
                AP.TEST_BAL_QTY,
                AP.TEST_DISC_AMT,
                AP.TEST_TRANS_IN_QTY,
                AP.TEST_TRANS_IN_DATE,
                AP.TEST_RECUR_BILLED,
                AP.TEST_RECUR_SEQ
           FROM FY_TB_BL_ACCT_PKG AP
          WHERE AP.ACCT_ID     =gnACCT_ID
            AND AP.ACCT_KEY    =MOD(gnACCT_ID,100)
            AND AP.PKG_TYPE_DTL IN ('BDN','BDX')
            AND AP.EFF_DATE<>NVL(AP.END_DATE,AP.EFF_DATE+1)
            AND AP.EFF_DATE<gdBILL_END_DATE+1
            AND AP.STATUS<>'CLOSE'
            AND ((PI_PROC_ID=1 AND ((gvUSER ='MPBL' AND AP.END_RSN IS NOT NULL) OR   --2021/06/15 MODIFY FOR 小額預繳處理  ADD小額預繳折扣是否可抵一律不看reason code
                                    (gvUSER!='MPBL' AND AP.END_RSN in (SELECT lookup_code FROM fy_tb_cm_lookup_code 
                                                                        WHERE lookup_type IN ('MARKETMOVE','PRODUCTMIG')))) --2021/06/15 MODIFY FOR 小額預繳處理 ADD 'PRODUCTMIG'
                               AND (--gvACCT_GROUP<>'MV' OR --2021/10/06 MODIFY FOR 小額預繳處理 
                                    OFFER_LEVEL = 'O' OR
                                    NOT EXISTS(SELECT 1 FROM FY_TB_BL_BILL_MV_SUB
                                               WHERE BILL_SEQ   =gnBILL_SEQ
                                                 AND CYCLE      =gnCYCLE
                                                 AND CYCLE_MONTH=gnCYCLE_MONTH
                                                 AND ACCT_ID    =AP.ACCT_ID
                                                 AND SUBSCR_ID  =AP.OFFER_LEVEL_ID
                                                 AND PRE_SUBSCR_ID IS NOT NULL))
                               AND gvPN_FLAG='N'  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                  ) OR
                 (PI_PROC_ID=2 AND OFFER_LEVEL='S' AND OFFER_LEVEL_ID=PI_SUBSCR_ID))
        UNION
         SELECT 'Y' MARKET_LEVEL,
                PO.ROWID,
                NULL ACCT_PKG_SEQ,
                NULL OFFER_SEQ,
                PO.OFFER_ID,
                NULL OFFER_INSTANCE_ID,
                gnACCT_ID,
                TO_NUMBER(SUBSTR(TO_CHAR(gnACCT_ID),-2)),
                gnCUST_ID,
                DECODE(PO.OFFER_LEVEL,'SUB','S','O'),
                gnACCT_OU_ID OFFER_LEVEL_ID,
                PP.PKG_ID,
                PP.PKG_TYPE_DTL,
                NULL PREPAYMENT,
                PKG_PRIORITY PKG_PRIOITY,
                TRUNC(PO.EFF_DATE),
                TRUNC(PO.END_DATE),
                NULL FUTURE_EXP_DATE,
                'OPEN' STATUS,
                NULL INIT_PKG_QTY,
                NULL TOTAL_DISC_AMT,
                NULL CUR_QTY,
                NULL CUR_USE_QTY,
                NULL CUR_BAL_QTY,
                NULL CUR_BILLED,
                NULL VALIDITY_PERIOD,
                NULL BILL_QTY,
                NULL BILL_USE_QTY,
                NULL BILL_BAL_QTY,
                NULL BILL_DISC_AMT,
                NULL TRANS_IN_QTY,
                NULL TRANS_IN_DATE,
                NULL FIRST_BILL_DATE,
                NULL RECUR_BILLED,
                NULL SYS_EFF_DATE,
                NULL SYS_END_DATE,
                NULL PRE_OFFER_SEQ,
                NULL PRE_PKG_SEQ,
                NULL ORIG_EFF_DATE,
                NULL OVERWRITE,
                NULL END_RSN,
                PP.PKG_NAME OFFER_NAME,
                NULL RECUR_SEQ,
                NULL TEST_QTY,
                NULL TEST_USE_QTY,
                NULL TEST_BAL_QTY,
                NULL TEST_DISC_AMT,
                NULL TEST_TRANS_IN_QTY,
                NULL TEST_TRANS_IN_DATE,
                NULL TEST_RECUR_BILLED,
                NULL TEST_RECUR_SEQ
           FROM FY_TB_PBK_OFFER PO,
                FY_TB_PBK_OFFER_PACKAGE OP,
                FY_TB_PBK_PACKAGE PP
          WHERE PO.OFFER_TYPE='MK'
            AND PO.EFF_DATE < gdBILL_END_DATE+1
            AND (PO.END_DATE IS NULL OR PO.END_DATE >= gdBILL_FROM_DATE)
            AND OP.OFFER_ID  = PO.OFFER_ID
            AND PP.PKG_ID    = OP.PKG_ID
            AND PP.PKG_TYPE_DTL IN ('BDN','BDX')
            AND PI_PROC_ID   =1
            AND gvPN_FLAG    ='N'  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
          ORDER BY PKG_PRIORITY,OFFER_SEQ;

      --GET PBK_PKG_DISCOUNT
      CURSOR C_PP(iPKG_ID NUMBER) IS
         SELECT PKG_ID,
                DIS_TYPE,
                DIS_TYPE_DTL,
                ACM_GROUP,
                SERVICE_FILTER,
                SERVICE_FILTER_G,
                POINT_CLASS,
                POINT_CLASS_G,
                CONTENT_LIST,
                CONTENT_LIST_G,
                DIS_UOM_METHOD,
                PRORATE_METHOD,
                VALIDITY_METHOD,
                VALIDITY_PERIOD,
                RECURRING,
                ROLLING,
                PRICING_TYPE,
                QTY_CONDITION,
                QUOTA,
                MAX_ROLLED_QUOTA,
                MAX_QUOTA_UNIT,
                QTYS1,
                QTYE1,
                DIS1 RATE1,
                QTYS2,
                QTYE2,
                DIS2 RATE2,
                QTYS3,
                QTYE3,
                DIS3 RATE3,
                QTYS4,
                QTYE4,
                DIS4 RATE4,
                QTYS5,
                QTYE5,
                DIS5 RATE5,
                CAL_METHOD,
                ELIGIBLE_IN,
                ELIGIBLE_EX,
                CONTRIBUTE_IN,
                CONTRIBUTE_EX
           FROM FY_TB_PBK_PKG_DISCOUNT
          WHERE PKG_ID=iPKG_ID;
      R_PP        C_PP%ROWTYPE;

      CURSOR C_OP(iOFFER_SEQ NUMBER) IS
         SELECT SUBSTR (SUBSTR (PARAM_NAME, 1, INSTR(PARAM_NAME,'_',-1) -1),
                           INSTR (SUBSTR (PARAM_NAME,1, INSTR(PARAM_NAME,'_',-1) -1),'_') +1) PARAM_NAME,
                PARAM_VALUE,
                EFF_DATE,
                END_DATE
           FROM FY_TB_BL_BILL_OFFER_PARAM
          WHERE BILL_SEQ      =gnBILL_SEQ
            AND CYCLE         =gnCYCLE
            AND CYCLE_MONTH   =gnCYCLE_MONTH
            AND ACCT_ID       =gnACCT_ID
            AND ACCT_KEY      =MOD(gnACCT_ID,100)
            AND OFFER_SEQ     =iOFFER_SEQ
            AND OVERWRITE_TYPE='BD'
          ORDER BY PARAM_NAME,EFF_DATE ;

      --抓取subscr_id出帳資訊
      CURSOR C_SUB(iSUBSCR_ID NUMBER) IS
        SELECT SUBSCR_ID,
               OU_ID,
               TRUNC(EFF_DATE) EFF_DATE,
               TRUNC(END_DATE) END_DATE,
               PRE_SUB_ID,
               INIT_RSN_CODE,
               INHERIT_FLAG,
               BILL_SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
          FROM FY_TB_BL_BILL_SUB
         WHERE BILL_SEQ      =gnBILL_SEQ
           AND CYCLE         =gnCYCLE
           AND CYCLE_MONTH   =gnCYCLE_MONTH
           AND ACCT_ID       =gnACCT_ID
           AND ACCT_KEY      =MOD(gnACCT_ID,100)
           AND SUBSCR_ID     =iSUBSCR_ID;
      R_SUB      C_SUB%ROWTYPE;

      --抓取MARKET MOVE PACKAGE資訊(同CYCLE)
      CURSOR C_ORG(iACCT_PKG_SEQ NUMBER) IS
         SELECT ROWID,
                ACCT_ID,
                ACCT_KEY,
                VALIDITY_PERIOD,
                NVL(TOTAL_DISC_AMT,0) TOTAL_DISC_AMT,
                NVL(CUR_BAL_QTY,0) CUR_BAL_QTY,
                NVL(BILL_BAL_QTY,0)  BILL_BAL_QTY,
                NVL(BILL_DISC_AMT,0) BILL_DISC_AMT,
                NVL(TEST_BAL_QTY,0)  TEST_BAL_QTY,
                NVL(TEST_DISC_AMT,0) TEST_DISC_AMT,
                FIRST_BILL_DATE,
                RECUR_BILLED,
                test_recur_billed,
                TRANS_OUT_DATE
           FROM FY_TB_BL_ACCT_PKG
          WHERE ACCT_PKG_SEQ=iACCT_PKG_SEQ
            --AND ACCT_KEY    =MOD(gnACCT_ID,100)
            AND TRANS_OUT_DATE IS NULL;
      R_ORG       C_ORG%ROWTYPE;

      Tab_PKG_RATES      t_PKG_RATES;
      DT_CI_FROM_DATE    DATE;
      DT_CI_END_DATE     DATE;
      DT_CTRL_FROM_DATE  DATE;
      DT_CTRL_END_DATE   DATE;
      NU_ACTIVE_DAY      NUMBER;
      NU_AMT_QTY         NUMBER;
      NU_CNT             NUMBER;
      NU_CONTRIBUTE_CNT  NUMBER;
      NU_CRI_ORDER       NUMBER;
      NU_RATES           NUMBER;
      NU_PKG_DISC        NUMBER;
      NU_PKG_QTY         NUMBER;
      NU_PKG_USE         NUMBER;
      CH_ERR_CDE         VARCHAR2(4);
      CH_MARKET          VARCHAR2(1);--Y:MARKET MOVE
      On_Err             EXCEPTION;
   BEGIN
      gvCI_STEP := NULL;
      --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
      gvPN_FLAG := 'N';
      IF PI_PROC_ID=1 THEN
         SELECT COUNT(1) INTO NU_CNT
           FROM FY_TB_BL_BILL_SUB
          WHERE BILL_SEQ   =gnBILL_SEQ
            AND CYCLE      =gnCYCLE
            AND CYCLE_MONTH=gnCYCLE_MONTH
            AND ACCT_ID    =gnACCT_ID   
            AND ACCT_KEY   =MOD(gnACCT_ID,100)
            AND SUBSCR_ID <>BILL_SUBSCR_ID;
         IF NU_CNT>0 THEN   
            gvPN_FLAG := 'Y';
         END IF; 
      END IF; 
      LOOP   --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 控制PN須執行次數及抓取的對象 
      FOR R_RC IN C_RC LOOP
         --設定一些全域的變數
         gvPREPAYMENT        := R_RC.PREPAYMENT; --2021/06/15 MODIFY FOR 小額預繳處理
         gnOFFER_SEQ         := R_RC.OFFER_SEQ;
         gnOFFER_ID          := R_RC.OFFER_ID;
         gnOFFER_INSTANCE_ID := R_RC.OFFER_INSTANCE_ID;
         gnPKG_ID            := R_RC.PKG_ID;
         gvOFFER_LEVEL       := R_RC.OFFER_LEVEL;
         gnOFFER_LEVEL_ID    := R_RC.OFFER_LEVEL_ID;
         gvMARKET_LEVEL      := R_RC.MARKET_LEVEL;
         gvOFFER_NAME        := R_RC.OFFER_NAME;
         gnACCT_PKG_SEQ      := R_RC.ACCT_PKG_SEQ;
         gnEND_DATE          := R_RC.END_DATE; --2020/06/30 MODIFY FOR MPBS_Migration 折扣到期日
         gnFUTURE_EXP_DATE   := R_RC.FUTURE_EXP_DATE; --2020/06/30 MODIFY FOR MPBS_Migration 折扣未來到期日
         gnPKG_TYPE_DTL      := R_RC.PKG_TYPE_DTL; --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
         CH_MARKET    := 'N';
         NU_PKG_DISC  := NULL;
         NU_PKG_QTY   := NULL;
         NU_PKG_USE   := NULL;
         gnBILL_SUBSCR_ID := NULL;  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 ADD C_SUB
         --CHECK SUBSCR
         IF R_RC.OFFER_LEVEL='S' AND gvMARKET_LEVEL<>'Y' THEN
            gnSUBSCR_ID := R_RC.OFFER_LEVEL_ID;
            gnOU_ID     := NULL;
            --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 ADD C_SUB
            OPEN C_SUB(gnSUBSCR_ID);
            FETCH C_SUB INTO R_SUB;
            IF C_SUB%FOUND THEN
               gnBILL_SUBSCR_ID := R_SUB.BILL_SUBSCR_ID;
            END IF;
            CLOSE C_SUB;
         ELSE
            gnSUBSCR_ID := NULL;
            gnOU_ID     := R_RC.OFFER_LEVEL_ID;
         END IF;

         --2020/06/30 MODIFY FOR MPBS_Migration 增加新安東京判別
         gvTMNEWA   := 'N';  
         gvTXN_ID   := NULL;
         gvDYNAMIC_ATTRIBUTE := NULL;
         IF gvUSER='MPBL' THEN
            BEGIN
               SELECT 'Y' 
                 INTO gvTMNEWA
                 FROM FY_TB_PBK_OFFER_PROPERTIES A
                WHERE OFFER_ID =R_RC.OFFER_ID
                  AND PRT_ID   =gnPRT_ID
                  AND PRT_VALUE=gvPRT_VALUE;
            EXCEPTION WHEN OTHERS THEN 
               gvTMNEWA := 'N';
            END;
         END IF;  --2020/06/30    
         
         --GET DISCOUNT_PACKAGE
         OPEN C_PP(R_RC.PKG_ID);
         FETCH C_PP INTO R_PP;
         IF C_PP%NOTFOUND THEN
            gvSTEP := 'GET DISCOUNT_PACKAGE.PKG_ID='||TO_CHAR(R_RC.PKG_ID)||' NOT FOUND' ||'gnACCT_ID='||TO_CHAR(gnACCT_ID);          
            gvERR_CDE := 'P001';
            RAISE ON_ERR;
         END IF;
         CLOSE C_PP;
         --設定PACKAGE的變數
         gvRECURRING      := R_PP.RECURRING;
         gvPRICING_TYPE   := R_PP.PRICING_TYPE;
         gvPRORATE_METHOD := R_PP.PRORATE_METHOD;
         gvDIS_UOM_METHOD := R_PP.DIS_UOM_METHOD;
         gvQTY_CONDITION  := R_PP.QTY_CONDITION;
         --DATE 處理
         DT_CI_FROM_DATE :=greatest(NVL(R_RC.CUR_BILLED+1,R_RC.EFF_DATE),
                                    NVL(R_RC.SYS_EFF_DATE,R_RC.EFF_DATE),
                                    R_RC.EFF_DATE);  ----取其大
         DT_CI_END_DATE  :=least(NVL(R_RC.END_DATE,gdBILL_END_DATE),
                                 NVL(R_RC.FUTURE_EXP_DATE,gdBILL_END_DATE),
                                 NVL(R_RC.SYS_END_DATE,gdBILL_END_DATE),
                                 gdBILL_END_DATE); ---取其小
         --MARKET MOVE處理(同CYCLE)
         IF PI_PROC_ID=2 THEN
  /*   DBMS_OUTPUT.Put_Line('MARKET MOVE.PKG_ID='||TO_CHAR(R_RC.ACCT_PKG_SEQ)||
                                 ',ORG_PKG_ID='||TO_CHAR(R_RC.PRE_PKG_SEQ)||
                                 ',DATE='||TO_CHAR(R_RC.TRANS_IN_DATE,'YYYYMMDD'));  */
            CH_MARKET := 'Y';
            IF R_RC.PRE_PKG_SEQ IS NOT NULL AND R_RC.TRANS_IN_DATE IS NULL AND R_RC.PREPAYMENT IS NOT NULL THEN
               --GET PRE_PACKAGE
               OPEN C_ORG(R_RC.PRE_PKG_SEQ);
               FETCH C_ORG INTO R_ORG;
               IF C_ORG%NOTFOUND THEN
                  gvSTEP := 'GET MARKET MOVE.PKG_ID='||TO_CHAR(R_RC.PRE_PKG_SEQ)||' NOT FOUND' ||'gnACCT_ID='||TO_CHAR(gnACCT_ID);                
                  gvERR_CDE := 'P001';
                  RAISE ON_ERR;
               END IF;
               CLOSE C_ORG;
               --從未使用
               IF R_ORG.FIRST_BILL_DATE IS NULL AND
                  ((gvPROC_TYPE='B' AND R_ORG.RECUR_BILLED IS NULL) OR
                   (gvPROC_TYPE='T' AND R_ORG.TEST_RECUR_BILLED IS NULL)) THEN
                  SELECT DECODE(gvPROC_TYPE,'B',R_PP.QUOTA,R_ORG.BILL_BAL_QTY), DECODE(gvPROC_TYPE,'T',R_PP.QUOTA,R_ORG.TEST_BAL_QTY)
                    INTO R_ORG.BILL_BAL_QTY, R_ORG.TEST_BAL_QTY
                    FROM DUAL;
               --2020/02/14 MODIFY MV取得有出過帳且本期未使用者的BDE剩餘金額
               ELSIF ((gvPROC_TYPE='B' AND R_ORG.RECUR_BILLED IS NULL) OR
                   (gvPROC_TYPE='T' AND R_ORG.TEST_RECUR_BILLED IS NULL)) THEN
                SELECT DECODE(gvPROC_TYPE,'B',R_ORG.CUR_BAL_QTY,R_ORG.BILL_BAL_QTY), DECODE(gvPROC_TYPE,'T',R_ORG.CUR_BAL_QTY,R_ORG.TEST_BAL_QTY)
                    INTO R_ORG.BILL_BAL_QTY, R_ORG.TEST_BAL_QTY
                    FROM DUAL;
               END IF;

               --同CYCLE(PRE_CYCLE IS NULL)
               gvSTEP := 'MARKET MOVE.UPDATE ACCT_PKG.PRE_PKG_SEQ=:'||TO_CHAR(R_RC.PRE_PKG_SEQ)||':';
               UPDATE FY_TB_BL_ACCT_PKG SET TRANS_OUT_QTY =DECODE(gvPROC_TYPE,'B',R_ORG.BILL_BAL_QTY*-1,TRANS_OUT_QTY),
                                           TRANS_OUT_DATE =DECODE(gvPROC_TYPE,'B',DT_CI_FROM_DATE,       TRANS_OUT_DATE),
                                           --BILL_BAL_QTY =DECODE(gvPROC_TYPE,'B',(BILL_BAL_QTY-R_ORG.BILL_BAL_QTY),BILL_BAL_QTY), --2020/02/14 MODIFY MV取消非最後一筆SUB的剩餘金額
                                             BILL_BAL_QTY =DECODE(gvPROC_TYPE,'B',0,BILL_BAL_QTY), --2020/02/14 MODIFY MV新增非最後一筆SUB的剩餘金額=0
                                                RECUR_SEQ =DECODE(gvPROC_TYPE,'B',DECODE(RECUR_SEQ,NULL,gnBILL_SEQ,RECUR_SEQ),RECUR_SEQ),
                                      TEST_TRANS_OUT_DATE =DECODE(gvPROC_TYPE,'T',DT_CI_FROM_DATE,       TEST_TRANS_OUT_DATE),
                                           --TEST_BAL_QTY =DECODE(gvPROC_TYPE,'T',(TEST_BAL_QTY-R_ORG.TEST_BAL_QTY),TEST_BAL_QTY), --2020/02/14 MODIFY MV取消非最後一筆SUB的剩餘金額
                                             TEST_BAL_QTY =DECODE(gvPROC_TYPE,'T',0,TEST_BAL_QTY), --2020/02/14 MODIFY MV新增非最後一筆SUB的剩餘金額=0
                                           TEST_RECUR_SEQ =DECODE(gvPROC_TYPE,'T',DECODE(TEST_RECUR_SEQ,NULL,gnBILL_SEQ,TEST_RECUR_SEQ),TEST_RECUR_SEQ),
                                              UPDATE_DATE =SYSDATE,
                                              UPDATE_USER =gvUSER
                                  WHERE ROWID=R_ORG.ROWID;
               gvSTEP := 'MARKET MOVE:';
               SELECT DECODE(gvPROC_TYPE,'B',R_ORG.BILL_BAL_QTY,R_RC.TRANS_IN_QTY),
                      DECODE(gvPROC_TYPE,'B',DT_CI_FROM_DATE,    R_RC.TRANS_IN_DATE),
                      DECODE(gvPROC_TYPE,'T',R_ORG.TEST_BAL_QTY,R_RC.TEST_TRANS_IN_QTY),
                      DECODE(gvPROC_TYPE,'T',DT_CI_FROM_DATE,    R_RC.TEST_TRANS_IN_DATE),
                      DECODE(gvPROC_TYPE,'B',(R_ORG.TOTAL_DISC_AMT+R_ORG.BILL_DISC_AMT),R_RC.TOTAL_DISC_AMT),
                      R_ORG.VALIDITY_PERIOD
                 INTO R_RC.TRANS_IN_QTY,
                      R_RC.TRANS_IN_DATE,
                      R_RC.TEST_TRANS_IN_QTY,
                      R_RC.TEST_TRANS_IN_DATE,
                      R_RC.TOTAL_DISC_AMT,
                      R_RC.VALIDITY_PERIOD
                 FROM DUAL;
            END IF; --R_RC.PRE_PKG_SEQ IS NOT NULL
         END IF;  --PI_PROC_ID=2
         --需處理計費資料
         --IF DT_CI_FROM_DATE>=DT_CI_END_DATE OR --2020/02/25 MODIFY 排除計費天數僅一天的資料
           --IF DT_CI_FROM_DATE>DT_CI_END_DATE OR --2020/02/25 MODIFY 排除計費天數僅一天的資料
           IF DT_CI_FROM_DATE>DT_CI_END_DATE+1 OR --2022/11/04 MODIFY FOR SR250171_ESDP_Migration_Project_END在bill_date會造成無法則抵亦會造成MV金額無法移轉
            (R_RC.PREPAYMENT IS NOT NULL AND
             R_PP.ROLLING='Y' AND
             --R_PP.RECURRING='Y' AND --(不限定保值卡折扣) --2019/11/05 MODIFY SR219716_IOT預繳折扣，END_RSN為CREQ且END_DATE小於BILL_DATE時折扣不給
             --NVL(R_RC.END_DATE+1,gdBILL_END_DATE)<gdBILL_END_DATE AND --2019/11/05 MODIFY SR219716_IOT預繳折扣，END_RSN為CREQ且END_DATE小於BILL_DATE時折扣不給
             NVL(R_RC.END_DATE,gdBILL_END_DATE)<gdBILL_END_DATE AND --(END在CYCLE最後一天也不給) --2019/11/05 MODIFY SR219716_IOT預繳折扣，END_RSN為CREQ且END_DATE小於BILL_DATE時折扣不給
             NVL(R_RC.END_RSN,' ')='CREQ' AND gvUSER!='MPBL') THEN  --2021/06/15 MODIFY FOR 小額預繳處理 ADD gvUSER判別
            NU_CRI_ORDER := NULL;
            Tab_PKG_RATES(1).ITEM_NO := NULL;
            DBMS_OUTPUT.Put_Line('discount start--->');
            DBMS_OUTPUT.Put_Line('ACCT_ID='||TO_CHAR(gnACCT_ID)||', S/O_LEVEL='||TO_CHAR(gvOFFER_LEVEL)||', S/O='||TO_CHAR(gnOFFER_INSTANCE_ID));                                 
            DBMS_OUTPUT.Put_Line('OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||', PKG_SEQ='||TO_CHAR(R_RC.ACCT_PKG_SEQ));                                 
            DBMS_OUTPUT.Put_Line('DISCOUNT_START_DATE='||TO_CHAR(DT_CI_FROM_DATE,'yyyy/mm/dd')||', DISCOUNT_END_DATE='||TO_CHAR(DT_CI_END_DATE,'yyyy/mm/dd'));
            DBMS_OUTPUT.Put_Line('<---discount end');
         ELSE
            DBMS_OUTPUT.Put_Line('discount start--->');
            DBMS_OUTPUT.Put_Line('ACCT_ID='||TO_CHAR(gnACCT_ID)||', S/O_LEVEL='||TO_CHAR(gvOFFER_LEVEL)||', S/O='||TO_CHAR(gnOFFER_INSTANCE_ID));                                 
            DBMS_OUTPUT.Put_Line('OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||', PKG_SEQ='||TO_CHAR(R_RC.ACCT_PKG_SEQ));                                 
            DBMS_OUTPUT.Put_Line('DISCOUNT_START_DATE='||TO_CHAR(DT_CI_FROM_DATE,'yyyy/mm/dd')||', DISCOUNT_END_DATE='||TO_CHAR(DT_CI_END_DATE,'yyyy/mm/dd'));
            DBMS_OUTPUT.Put_Line('<---discount end');
            gvOVERWRITE   := 'N';
            gnROLLING_QTY := 0;
            --收費類別PRICING_TYPE
            IF R_PP.PRICING_TYPE='F' THEN --Flat
               --QUOTA OVERWRITE
               BEGIN
                  SELECT PARAM_VALUE
                    INTO R_PP.QUOTA
                    FROM FY_TB_BL_BILL_OFFER_PARAM
                   WHERE BILL_SEQ      =gnBILL_SEQ
                     AND CYCLE         =gnCYCLE
                     AND CYCLE_MONTH   =gnCYCLE_MONTH
                     AND ACCT_ID       =gnACCT_ID
                     AND ACCT_KEY      =MOD(gnACCT_ID,100)
                     AND OFFER_SEQ     =R_RC.OFFER_SEQ
                     AND OVERWRITE_TYPE='BD'
                     AND SUBSTR (SUBSTR (PARAM_NAME, 1, INSTR(PARAM_NAME,'_',-1) -1),
                           INSTR (SUBSTR (PARAM_NAME,1, INSTR(PARAM_NAME,'_',-1) -1),'_') +1)='QUOTA';
               EXCEPTION WHEN OTHERS THEN
                  NULL;
               END;
               --計算遞延量gnROLLING_QTY
               IF R_PP.ROLLING='Y' AND
                 (gvUSER='MPBL' OR  --2021/06/15 MODIFY FOR 小額預繳處理 ADD gvUSER判別
                  NVL(R_RC.END_RSN,' ')<>'CREQ' OR
                  NVL(R_RC.END_DATE,gdBILL_END_DATE)>=gdBILL_END_DATE) THEN
                  IF NVL(R_RC.CUR_BAL_QTY,0)>R_PP.MAX_ROLLED_QUOTA THEN --最多可遞延配額
                     NU_CNT := R_PP.MAX_ROLLED_QUOTA;
DBMS_OUTPUT.Put_Line('1603--NU_CNT='||TO_CHAR(NU_CNT)||' R_PP.MAX_ROLLED_QUOTA='||TO_CHAR(R_PP.MAX_ROLLED_QUOTA));
                  ELSE
                     NU_CNT := NVL(R_RC.CUR_BAL_QTY,0);
DBMS_OUTPUT.Put_Line('1606--NU_CNT='||TO_CHAR(NU_CNT)||' R_RC.CUR_BAL_QTY='||TO_CHAR(R_RC.CUR_BAL_QTY));
                  END IF;
               ELSE
                  NU_CNT := 0;
               END IF;
               gnROLLING_QTY := NU_CNT;
               Tab_PKG_RATES(1).ITEM_NO := 1;
               Tab_PKG_RATES(1).QTY_S   := 0;
               Tab_PKG_RATES(1).QTY_E   := NULL;
               IF CH_MARKET='Y' THEN
                  gnROLLING_QTY := 0;
                  IF (R_RC.PREPAYMENT IS NULL OR R_RC.TRANS_IN_QTY IS NULL) AND --2022/04/07 MODIFY FOR 修正MV但BDE無移轉造成金額變為0問題
                    (gvDIS_UOM_METHOD='P' OR R_RC.FIRST_BILL_DATE IS NULL) THEN  --2021/06/15 MODIFY FOR 小額預繳處理 ADD FIRST_BILL_DATE
                     Tab_PKG_RATES(1).RATES := R_PP.QUOTA;
                  ELSIF gvPROC_TYPE='B' THEN
                     Tab_PKG_RATES(1).RATES :=R_RC.TRANS_IN_QTY;
                  ELSE
                     Tab_PKG_RATES(1).RATES :=R_RC.TEST_TRANS_IN_QTY;
                  END IF;
               ELSIF gvRECURRING='Y' OR R_RC.FIRST_BILL_DATE IS NULL THEN
                  Tab_PKG_RATES(1).RATES := R_PP.QUOTA;
               ELSE
                  Tab_PKG_RATES(1).RATES :=0;
DBMS_OUTPUT.Put_Line('1629--Tab_PKG_RATES(1).RATES='||TO_CHAR(Tab_PKG_RATES(1).RATES));
               END IF;
                        gnQUOTA      := R_PP.QUOTA; --2022/07/05 MODIFY FOR SR250171_ESDP_Migration_Project 提供HBO折扣數量
               IF R_RC.INIT_PKG_QTY IS NULL THEN
                  R_RC.INIT_PKG_QTY := R_PP.QUOTA;
               END IF;
               NU_CONTRIBUTE_CNT := 1;
               NU_CRI_ORDER      := 1;
               Tab_PKG_RATES(2).ITEM_NO := NULL; 
            ELSE
               --OVERWRITE OFFER_PARAM
               IF gvMARKET_LEVEL<>'Y' AND CH_MARKET<>'Y' THEN --非MARKET_LEVEL & MARKET MOVE
                  FOR R_OP IN C_OP(R_RC.OFFER_SEQ) LOOP
                      gvOVERWRITE := 'Y';
                      IF R_OP.PARAM_NAME='QTYS1' THEN
                         R_PP.QTYS1 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='QTYE1' THEN
                         R_PP.QTYE1 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='RATE1' THEN
                         R_PP.RATE1 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='QTYS2' THEN
                         R_PP.QTYS2 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='QTYE2' THEN
                         R_PP.QTYE2 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='RATE2' THEN
                         R_PP.RATE2 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='QTYS3' THEN
                         R_PP.QTYS3 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='QTYE3' THEN
                         R_PP.QTYE3 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='RATE3' THEN
                         R_PP.RATE3 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='QTYS4' THEN
                         R_PP.QTYS4 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='QTYE4' THEN
                         R_PP.QTYE4 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='RATE4' THEN
                         R_PP.RATE4 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='QTYS5' THEN
                         R_PP.QTYS5 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='QTYE5' THEN
                         R_PP.QTYE5 :=R_OP.PARAM_VALUE;
                      ELSIF R_OP.PARAM_NAME='RATE5' THEN
                         R_PP.RATE5 :=R_OP.PARAM_VALUE;
                      END IF;
                  END LOOP;
               END IF;
               --OFFER_NAME
               IF INSTR(gvOFFER_NAME, '$')>0 THEN
                   gvOFFER_NAME := SUBSTR(gvOFFER_NAME,1,INSTR(gvOFFER_NAME,'$')-1)||
                                  TO_CHAR(R_PP.RATE1)||
                                  SUBSTR(gvOFFER_NAME,INSTR(gvOFFER_NAME, '$')+7,LENGTH(gvOFFER_NAME));
               END IF;
               --MOVE RATES TO OBJECT
               NU_CNT := 0;
               FOR i IN 1 .. 5 LOOP
                   SELECT DECODE(i,1,R_PP.RATE5,2,R_PP.RATE4,3,R_PP.RATE3,4,R_PP.RATE2,R_PP.RATE1)
                     INTO NU_RATES
                     FROM DUAL;
                   IF NU_RATES IS NOT NULL THEN
                      NU_CNT := NU_CNT + 1;
                      SELECT DECODE(i,1,5,2,4,3,3,4,2,1),
                             DECODE(i,1,R_PP.QTYS5,2,R_PP.QTYS4,3,R_PP.QTYS3,4,R_PP.QTYS2,R_PP.QTYS1),
                             DECODE(i,1,R_PP.QTYE5,2,R_PP.QTYE4,3,R_PP.QTYE3,4,R_PP.QTYE2,R_PP.QTYE1),
                             DECODE(i,1,R_PP.RATE5,2,R_PP.RATE4,3,R_PP.RATE3,4,R_PP.RATE2,R_PP.RATE1)
                        INTO Tab_PKG_RATES(Nu_CNT).ITEM_NO,
                             Tab_PKG_RATES(Nu_CNT).QTY_S,
                             Tab_PKG_RATES(Nu_CNT).QTY_E,
                             Tab_PKG_RATES(Nu_CNT).RATES
                        FROM DUAL;
                   END IF;
               END LOOP;
               IF NU_CNT=0 THEN
                   gvERR_CDE := 'D001';
                   gvSTEP := 'PKG_ID='||TO_CHAR(gnPKG_ID)||'多皆費率皆為NULL';
                   RAISE ON_ERR;
               ELSE
                   FOR I IN NU_CNT+1 .. 5 LOOP
                      Tab_PKG_RATES(I).ITEM_NO := NULL;
                   END LOOP;
               END IF;
               --QTY_CONDITION
               NU_CRI_ORDER := NULL;
               gvSTEP := 'GET_CONTRIBUTE:';
               GET_CONTRIBUTE(R_PP.CONTRIBUTE_IN ,
                              R_PP.CONTRIBUTE_EX ,
                              Tab_PKG_RATES,
                              R_RC.EFF_DATE,  --2020/06/30 MODIFY FOR MPBS_Migration ADD 參數
                              NU_CONTRIBUTE_CNT,
                              NU_CRI_ORDER);  
               IF gvERR_CDE<>'0000' THEN
                  gvSTEP := SUBSTR('GET_CONTRIBUTE:'||gvERR_MSG,1,250);
                  RAISE ON_ERR;
               END IF;
            END IF;  --R_PP.PRICING_TYPE='F'
            --DO_ELIGIBLE
            gvSTEP := 'DO_ELIGIBLE.ELIGIBLE='||TO_CHAR(NVL(R_PP.ELIGIBLE_IN,R_PP.ELIGIBLE_EX))||':';
 -- DBMS_OUTPUT.Put_Line('SUB_ID='||TO_CHAR(gnOFFER_LEVEL_ID)||',PKG_ID='||TO_CHAR(R_RC.PKG_ID)||',CONTRIBUTE_CNT='||TO_CHAR(NU_CONTRIBUTE_CNT)||
 --                     ',CRI_ORDER='||TO_CHAR(NU_CRI_ORDER));
            DO_ELIGIBLE(R_PP.ELIGIBLE_IN,
                        R_PP.ELIGIBLE_EX,
                        NU_CONTRIBUTE_CNT,
                        NU_CRI_ORDER,
                        DT_CI_FROM_DATE,
                        DT_CI_END_DATE,
                        Tab_PKG_RATES,
                        CH_MARKET,
                        R_RC.EFF_DATE,  --2020/06/30 MODIFY FOR MPBS_Migration ADD 參數
                        NU_PKG_DISC,
                        NU_PKG_QTY,
                        NU_PKG_USE);
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR('DO_ELIGIBLE.ELIGIBLE='||TO_CHAR(NVL(R_PP.ELIGIBLE_IN,R_PP.ELIGIBLE_EX))||':'||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;
         END IF;  -- DT_CI_FROM_DATE<DT_CI_END_DATE
         --UPDATE ACCT_PKG
         IF gnACCT_PKG_SEQ IS NOT NULL THEN --非MARKET LEVEL
            gvSTEP := 'UPDATE FY_TB_BL_ACCT_PKG:';
            UPDATE FY_TB_BL_ACCT_PKG A SET BILL_QTY          =DECODE(gvPROC_TYPE,'B',NVL(NU_PKG_QTY,0),BILL_QTY), --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                                           BILL_USE_QTY      =DECODE(gvPROC_TYPE,'B',NVL(NU_PKG_USE,0),BILL_USE_QTY), --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                                           BILL_BAL_QTY      =DECODE(gvPROC_TYPE,'B',NVL(NU_PKG_QTY,0)-NVL(NU_PKG_USE,0),BILL_BAL_QTY), --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                                           BILL_DISC_AMT     =DECODE(gvPROC_TYPE,'B',NVL(NU_PKG_DISC,0),BILL_DISC_AMT), --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                                           RECUR_BILLED      =DECODE(gvPROC_TYPE,'B',DT_CI_END_DATE,RECUR_BILLED),
                                           RECUR_SEQ         =DECODE(gvPROC_TYPE,'B',gnBILL_SEQ,RECUR_SEQ),
                                           TOTAL_DISC_AMT    =DECODE(CH_MARKET,'Y',R_RC.TOTAL_DISC_AMT,TOTAL_DISC_AMT),
                                           VALIDITY_PERIOD   =DECODE(CH_MARKET,'Y',R_RC.VALIDITY_PERIOD,VALIDITY_PERIOD),
                                           TRANS_IN_QTY      =DECODE(CH_MARKET,'Y',R_RC.TRANS_IN_QTY, TRANS_IN_QTY),
                                           TRANS_IN_DATE     =DECODE(CH_MARKET,'Y',R_RC.TRANS_IN_DATE,TRANS_IN_DATE),
                                           TEST_QTY          =DECODE(gvPROC_TYPE,'T',NVL(NU_PKG_QTY,0),TEST_QTY), --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                                           TEST_USE_QTY      =DECODE(gvPROC_TYPE,'T',NVL(NU_PKG_USE,0),TEST_USE_QTY), --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                                           TEST_BAL_QTY      =DECODE(gvPROC_TYPE,'T',NVL(NU_PKG_QTY,0)-NVL(NU_PKG_USE,0),TEST_BAL_QTY), --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                                           TEST_DISC_AMT     =DECODE(gvPROC_TYPE,'T',NVL(NU_PKG_DISC,0),TEST_DISC_AMT), --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
                                           TEST_RECUR_BILLED =DECODE(gvPROC_TYPE,'T',DT_CI_END_DATE,TEST_RECUR_BILLED),
                                           TEST_RECUR_SEQ    =DECODE(gvPROC_TYPE,'T',gnBILL_SEQ,TEST_RECUR_SEQ),
                                           TEST_TRANS_IN_QTY =DECODE(CH_MARKET,'Y',R_RC.TEST_TRANS_IN_QTY, TEST_TRANS_IN_QTY),
                                           TEST_TRANS_IN_DATE=DECODE(CH_MARKET,'Y',R_RC.TEST_TRANS_IN_DATE,TEST_TRANS_IN_DATE),
                                           INIT_PKG_QTY      =R_RC.INIT_PKG_QTY,
                                           UPDATE_DATE       =SYSDATE,
                                           UPDATE_USER       =gvUSER
                                     WHERE ROWID=R_RC.ROWID;
         END IF;
      END LOOP; --C_RC
      --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
      IF gvPN_FLAG='N' THEN
         EXIT;
      END IF;
      gvPN_FLAG := 'N';
      END LOOP;   --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 控制PN須執行次數及抓取的對象 
      gvERR_Cde := '0000';
      gvERR_Msg := NULL;
   EXCEPTION
      WHEN ON_ERR THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END DO_DISCOUNT;

   /*************************************************************************
      PROCEDURE : GET_CONTRIBUTE
      PURPOSE :   針對PBK定義之CONTRIBUTE，判斷是否符合資格
      DESCRIPTION : 針對PBK定義之CONTRIBUTE，判斷是否符合資格
      PARAMETER:
            PI_CONTRIBUTE_IN        :資格條件群組代碼_IN
            PI_CONTRIBUTE_EX        :資格條件群組代碼_EX
            PI_Tab_PKG_RATES        :PBK多皆費率
            PI_EFF_DATE             :折扣OFFER生效日
            PO_CONTRIBUTE_CNT       :資格條件數量
            PO_CRI_ORDER            :資格條件組別

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 增加參數&新安東京RC OFFER生效日必須小於折扣生效日
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE GET_CONTRIBUTE(PI_CONTRIBUTE_IN      IN   NUMBER,
                            PI_CONTRIBUTE_EX      IN   NUMBER,
                            PI_Tab_PKG_RATES      IN   t_PKG_RATES,
                            PI_EFF_DATE           IN   DATE,
                            PO_CONTRIBUTE_CNT    OUT   NUMBER,
                            PO_CRI_ORDER         OUT   NUMBER) IS

      CURSOR C_CI IS
         SELECT NVL(SUM(DECODE(gvQTY_CONDITION,'A',NVL(AMOUNT,0),NVL(CDR_QTY,0))),0) QTY  --CDR_QTY(單位B)
           FROM FY_TB_BL_BILL_CI A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_ID     =gnACCT_ID
            AND ACCT_KEY    =MOD(gnACCT_ID,100)
            AND ((gvOFFER_LEVEL='S' AND SERVICE_RECEIVER_TYPE='S' AND
                --SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)) OR --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                  ((gvPN_FLAG='Y' AND SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)
                                  AND SUBSCR_ID<>BILL_SUBSCR_ID) OR 
                   (gvPN_FLAG='N' AND (SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID) OR
                                       NVL(BILL_SUBSCR_ID,SUBSCR_ID)=DECODE(gvMARKET_LEVEL,'Y',NVL(BILL_SUBSCR_ID,SUBSCR_ID),gnOFFER_LEVEL_ID))))
                  ) OR
                 (gvOFFER_LEVEL='O' AND
                  ((SERVICE_RECEIVER_TYPE='O' AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                             Start with OU_ID=gnOFFER_LEVEL_ID
                                                            Connect by prior OU_ID=PARENT_OU_ID)) OR
                   (SERVICE_RECEIVER_TYPE='S' AND EXISTS (Select 1 from FY_TB_BL_BILL_SUB
                                                            WHERE BILL_SEQ    =A.BILL_SEQ
                                                              AND CYCLE       =A.CYCLE
                                                              AND CYCLE_MONTH =A.CYCLE_MONTH
                                                              AND ACCT_ID     =A.ACCT_ID
                                                              AND ACCT_KEY    =A.ACCT_KEY 
                                                            --AND SUBSCR_ID   =A.SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                                                              --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                                                              AND ((gvPN_FLAG='Y' AND SUBSCR_ID=A.SUBSCR_ID AND SUBSCR_ID<>BILL_SUBSCR_ID) OR
                                                                   (gvPN_FLAG='N' AND (SUBSCR_ID=A.SUBSCR_ID OR BILL_SUBSCR_ID=A.SUBSCR_ID)))
                                                              AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                                             Start with OU_ID=gnOFFER_LEVEL_ID
                                                                            Connect by prior OU_ID=PARENT_OU_ID)))
                 )))
            AND (PI_CONTRIBUTE_IN IS NULL OR
                 (EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                           WHERE CRI_GROUP_ID =PI_CONTRIBUTE_IN
                             AND CRI_TYPE     ='D'
                             AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                             AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                             AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                             AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                  DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                             AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                             AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                ))
            AND (PI_CONTRIBUTE_EX IS NULL OR
                 (NOT EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                               WHERE CRI_GROUP_ID =PI_CONTRIBUTE_EX
                                 AND CRI_TYPE     ='D'
                                 AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                                 AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                                 AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                                 AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                      DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                                 AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                                 AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                ))
            AND gvPROC_TYPE='B'
            --2020/06/30 MODIFY FOR MPBS_Migration ADD 新安東京RC OFFER生效日必須小於折扣生效日
            AND ((gvTMNEWA <>'Y') OR
                 (gvTMNEWA  ='Y' AND ((SOURCE='RC' AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG
                                                              WHERE OFFER_SEQ =A.OFFER_SEQ
                                                                AND A.CHRG_END_DATE >=PI_EFF_DATE --2020/06/30 MODIFY FOR MPBS_Migration 新安東京RC Charge需在折扣生效期間
                                                                AND TRUNC(EFF_DATE) <=PI_EFF_DATE
                                                                AND least(NVL(END_DATE-1,gdBILL_END_DATE),
                                                                          NVL(FUTURE_EXP_DATE-1,gdBILL_END_DATE),
                                                                          gdBILL_END_DATE)>=PI_EFF_DATE)) OR
                                      gvPREPAYMENT IS NOT NULL))  --2021/06/15 MODIFY FOR 小額預繳處理 ADD PERPAYMENT判別
                )
        UNION
         SELECT NVL(SUM(DECODE(gvQTY_CONDITION,'A',NVL(AMOUNT,0),NVL(CDR_QTY,0))),0) QTY
           FROM FY_TB_BL_BILL_CI_TEST A
           WHERE BILL_SEQ      =gnBILL_SEQ
             AND CYCLE         =gnCYCLE
             AND CYCLE_MONTH   =gnCYCLE_MONTH
             AND ACCT_KEY      =MOD(gnACCT_ID,100)
             AND ACCT_ID       =gnACCT_ID
             AND ((gvOFFER_LEVEL='S' AND SERVICE_RECEIVER_TYPE='S' AND
                --SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)) OR --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                  ((gvPN_FLAG='Y' AND SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)
                                  AND SUBSCR_ID<>BILL_SUBSCR_ID) OR 
                   (gvPN_FLAG='N' AND (SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID) OR
                                       NVL(BILL_SUBSCR_ID,SUBSCR_ID)=DECODE(gvMARKET_LEVEL,'Y',NVL(BILL_SUBSCR_ID,SUBSCR_ID),gnOFFER_LEVEL_ID))))
                  ) OR
                 (gvOFFER_LEVEL='O' AND
                  ((SERVICE_RECEIVER_TYPE='O' AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                             Start with OU_ID=gnOFFER_LEVEL_ID
                                                            Connect by prior OU_ID=PARENT_OU_ID)) OR
                   (SERVICE_RECEIVER_TYPE='S' AND EXISTS (Select 1 from FY_TB_BL_BILL_SUB
                                                            WHERE BILL_SEQ    =A.BILL_SEQ
                                                              AND CYCLE       =A.CYCLE
                                                              AND CYCLE_MONTH =A.CYCLE_MONTH
                                                              AND ACCT_ID     =A.ACCT_ID
                                                              AND ACCT_KEY    =A.ACCT_KEY 
                                                            --AND SUBSCR_ID   =A.SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                                                              --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                                                              AND ((gvPN_FLAG='Y' AND SUBSCR_ID=A.SUBSCR_ID AND SUBSCR_ID<>BILL_SUBSCR_ID) OR
                                                                   (gvPN_FLAG='N' AND (SUBSCR_ID=A.SUBSCR_ID OR BILL_SUBSCR_ID=A.SUBSCR_ID)))
                                                              AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                                             Start with OU_ID=gnOFFER_LEVEL_ID
                                                                            Connect by prior OU_ID=PARENT_OU_ID)))
                  )))
            AND (PI_CONTRIBUTE_IN IS NULL OR
                 (EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                           WHERE CRI_GROUP_ID =PI_CONTRIBUTE_IN
                             AND CRI_TYPE     ='D'
                             AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                             AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                             AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                             AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                  DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                             AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                             AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                ))
            AND (PI_CONTRIBUTE_EX IS NULL OR
                 (NOT EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                               WHERE CRI_GROUP_ID =PI_CONTRIBUTE_EX
                                 AND CRI_TYPE     ='D'
                                 AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                                 AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                                 AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                                 AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                      DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                                 AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                                 AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                ))
             AND gvPROC_TYPE='T' 
             --2020/06/30 MODIFY FOR MPBS_Migration ADD 新安東京RC OFFER生效日必須小於折扣生效日
             AND ((gvTMNEWA <>'Y') OR
                  (gvTMNEWA  ='Y' AND ((SOURCE='RC' AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG
                                                               WHERE OFFER_SEQ =A.OFFER_SEQ
                                                                 AND A.CHRG_END_DATE >=PI_EFF_DATE --2020/06/30 MODIFY FOR MPBS_Migration 新安東京RC Charge需在折扣生效期間
                                                                 AND TRUNC(EFF_DATE) <=PI_EFF_DATE
                                                                 AND least(NVL(END_DATE-1,gdBILL_END_DATE),
                                                                           NVL(FUTURE_EXP_DATE-1,gdBILL_END_DATE),
                                                                           gdBILL_END_DATE)>=PI_EFF_DATE)) OR
                                        gvPREPAYMENT IS NOT NULL)) --2021/06/15 MODIFY FOR 小額預繳處理 ADD PERPAYMENT判別
                 );

      NU_CONTRIBUTE_CNT  NUMBER;
      NU_CRI_ORDER       FY_TB_PBK_CRITERION_GROUP.CRI_ORDER%TYPE;
      NU_OU_ID           FY_TB_BL_BILL_CI.OU_ID%TYPE;
      CH_TRUE            VARCHAR2(1);
      CH_FLAG            VARCHAR2(1);
      DT_END_DATE        DATE;
      NU_CNT             NUMBER;
      NU_SUBSCR_ID       NUMBER;
      On_Err             EXCEPTION;
   BEGIN
      NU_CRI_ORDER := NULL;
      NU_CONTRIBUTE_CNT := 0;
      CH_TRUE      := 'N';
      NU_SUBSCR_ID := NULL;
      FOR R_CI IN C_CI LOOP
          NU_CONTRIBUTE_CNT := NU_CONTRIBUTE_CNT+R_CI.QTY;
      END LOOP;
      --CHECK 條件符合
      IF NU_CONTRIBUTE_CNT>0 THEN
         --使用量轉換(byte)
         IF gvQTY_CONDITION='KB' THEN
            NU_CONTRIBUTE_CNT := ROUND(NU_CONTRIBUTE_CNT /1024,4);
         ELSIF gvQTY_CONDITION='M' THEN
            NU_CONTRIBUTE_CNT := ROUND(NU_CONTRIBUTE_CNT /1024 /1024,4);
         ELSIF gvQTY_CONDITION='G' THEN
            NU_CONTRIBUTE_CNT := ROUND(NU_CONTRIBUTE_CNT /1024 /1024 /1024,4);
         ELSIF gvQTY_CONDITION='T' THEN
            NU_CONTRIBUTE_CNT := ROUND(NU_CONTRIBUTE_CNT /1024 /1024 /1024 /1024,4);
         END IF;
         --RATES處理
         FOR i IN 1 .. 5 LOOP
            IF PI_Tab_PKG_RATES(i).ITEM_NO IS NULL THEN
               EXIT;
            END IF;
            IF NU_CONTRIBUTE_CNT >= PI_Tab_PKG_RATES(i).QTY_S THEN
               NU_CRI_ORDER := I;
               EXIT;
            END IF;
         END LOOP;
      END IF;
      PO_CONTRIBUTE_CNT := NU_CONTRIBUTE_CNT;
      PO_CRI_ORDER    := NU_CRI_ORDER;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END GET_CONTRIBUTE;

   /*************************************************************************
      PROCEDURE : DO_ELIGIBLE
      PURPOSE :   針對PBK定義之ELIGIBLE，計算DISCOUNT金額
      DESCRIPTION : 針對PBK定義之ELIGIBLE，計算DISCOUNT金額
      PARAMETER:
            PI_ELIGIBLE_IN        :資格條件群組代碼_IN
            PI_ELIGIBLE_EX        :資格條件群組代碼_EX
            PI_CONTRIBUTE_CNT     :資格條件數量
            PI_CRI_ORDER          :資格條件組別
            PI_FROM_DATE          :計算起始日
            PI_END_DATE           :計算截止日
            PI_Tab_PKG_RATES      :PBK多皆費率
            PI_MARKET             :MARKET MOVE FLAG(Y:MARKET MOVE/N)
            PI_EFF_DATE           :折扣OFFER生效日
            PO_PKG_DISC           :折扣金額
            PO_PKG_QTY            :可使用量
            PO_PKG_USE            :使用量

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 增加參數&新安東京RC OFFER生效日必須小於折扣生效日
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE DO_ELIGIBLE(PI_ELIGIBLE_IN      IN   NUMBER,
                         PI_ELIGIBLE_EX      IN   NUMBER,
                         PI_CONTRIBUTE_CNT   IN   NUMBER,
                         PI_CRI_ORDER        IN   NUMBER,
                         PI_FROM_DATE        IN   DATE,
                         PI_END_DATE         IN   DATE,
                         PI_Tab_PKG_RATES    IN   t_PKG_RATES,
                         PI_MARKET           IN   VARCHAR2,
                         PI_EFF_DATE         IN   DATE,
                         PO_PKG_DISC        OUT   NUMBER,
                         PO_PKG_QTY         OUT   NUMBER,
                         PO_PKG_USE         OUT   NUMBER) IS

      CURSOR C_CI IS
         SELECT CI_SEQ,
                ACCT_ID,
                SUBSCR_ID,
                CUST_ID,
                OU_ID,
                CHRG_ID,
                CHARGE_TYPE,
                (AMOUNT+(SELECT NVL(SUM(AMOUNT),0)
                           FROM FY_TB_BL_BILL_CI
                          WHERE BILL_SEQ      =A.BILL_SEQ
                            AND CYCLE         =A.CYCLE
                            AND CYCLE_MONTH   =A.CYCLE_MONTH
                            AND ACCT_KEY      =A.ACCT_KEY
                            AND ACCT_ID       =A.ACCT_ID
                            AND (SOURCE_CI_SEQ =A.CI_SEQ OR CORRECT_CI_SEQ=A.CI_SEQ)
                          )) AMOUNT,
                OFFER_SEQ,
                OFFER_ID,
                OFFER_INSTANCE_ID,
                PKG_ID,
                CHRG_FROM_DATE, --2020/06/30 MODIFY FOR MPBS_Migration 新安東京DE應顯示CHRG_FROM_DATE
                CHRG_END_DATE, --2020/06/30 MODIFY FOR MPBS_Migration 新安東京DE應顯示CHRG_END_DATE
                CHARGE_CODE,
                SOURCE,
                SOURCE_CI_SEQ,
                SOURCE_OFFER_ID,
                BI_SEQ,
                SERVICE_RECEIVER_TYPE,
                BILL_SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
           FROM FY_TB_BL_BILL_CI A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =MOD(gnACCT_ID,100)
            AND ACCT_ID     =gnACCT_ID
            AND AMOUNT      > 0
            AND ((gvOFFER_LEVEL='S' AND SERVICE_RECEIVER_TYPE='S' AND
                --SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)) OR --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                  ((gvPN_FLAG='Y' AND SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)
                                  AND SUBSCR_ID<>BILL_SUBSCR_ID) OR 
                   (gvPN_FLAG='N' AND (SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID) OR
                                       NVL(BILL_SUBSCR_ID,SUBSCR_ID)=DECODE(gvMARKET_LEVEL,'Y',NVL(BILL_SUBSCR_ID,SUBSCR_ID),gnOFFER_LEVEL_ID))))
                  ) OR
                 (gvOFFER_LEVEL='O' AND
                  ((SERVICE_RECEIVER_TYPE='O' AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                             Start with OU_ID=gnOFFER_LEVEL_ID
                                                            Connect by prior OU_ID=PARENT_OU_ID)) OR
                   (SERVICE_RECEIVER_TYPE='S' AND EXISTS (Select 1 from FY_TB_BL_BILL_SUB
                                                            WHERE BILL_SEQ    =A.BILL_SEQ
                                                              AND CYCLE       =A.CYCLE
                                                              AND CYCLE_MONTH =A.CYCLE_MONTH
                                                              AND ACCT_ID     =A.ACCT_ID
                                                              AND ACCT_KEY    =A.ACCT_KEY 
                                                            --AND SUBSCR_ID   =A.SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                                                              --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                                                              AND ((gvPN_FLAG='Y' AND SUBSCR_ID=A.SUBSCR_ID AND SUBSCR_ID<>BILL_SUBSCR_ID) OR
                                                                   (gvPN_FLAG='N' AND (SUBSCR_ID=A.SUBSCR_ID OR BILL_SUBSCR_ID=A.SUBSCR_ID)))
                                                              AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                                             Start with OU_ID=gnOFFER_LEVEL_ID
                                                                            Connect by prior OU_ID=PARENT_OU_ID)))
                  )))
            AND (PI_ELIGIBLE_IN IS NULL OR
                 (EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                           WHERE CRI_GROUP_ID =PI_ELIGIBLE_IN
                             AND CRI_TYPE     ='D'
                             AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                             AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                             AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                             AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                  DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                             AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                             AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                ))
            AND (PI_ELIGIBLE_EX IS NULL OR
                 (NOT EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                               WHERE CRI_GROUP_ID =PI_ELIGIBLE_EX
                                 AND CRI_TYPE     ='D'
                                 AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                                 AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                                 AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                                 AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                      DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                                 AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                                 AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                ))
            AND gvPROC_TYPE='B'
            --2020/06/30 MODIFY FOR MPBS_Migration ADD 新安東京RC OFFER生效日必須小於折扣生效日
            AND ((gvTMNEWA <>'Y') OR
                 (gvTMNEWA  ='Y' AND ((SOURCE='RC' AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG
                                                              WHERE OFFER_SEQ =A.OFFER_SEQ
                                                                AND A.CHRG_END_DATE >=PI_EFF_DATE --2020/06/30 MODIFY FOR MPBS_Migration 新安東京RC Charge需在折扣生效期間
                                                                AND TRUNC(EFF_DATE) <=PI_EFF_DATE
                                                                AND least(NVL(END_DATE-1,gdBILL_END_DATE),
                                                                          NVL(FUTURE_EXP_DATE-1,gdBILL_END_DATE),
                                                                          gdBILL_END_DATE)>=PI_EFF_DATE)) OR
                                       gvPREPAYMENT IS NOT NULL)) --2021/06/15 MODIFY FOR 小額預繳處理 ADD PERPAYMENT

                )
        UNION
          SELECT CI_SEQ,
                ACCT_ID,
                SUBSCR_ID,
                CUST_ID,
                OU_ID,
                CHRG_ID,
                CHARGE_TYPE,
                (AMOUNT+(SELECT NVL(SUM(AMOUNT),0)
                           FROM FY_TB_BL_BILL_CI_TEST
                          WHERE BILL_SEQ      =A.BILL_SEQ
                            AND CYCLE         =A.CYCLE
                            AND CYCLE_MONTH   =A.CYCLE_MONTH
                            AND ACCT_KEY      =A.ACCT_KEY
                            AND ACCT_ID       =A.ACCT_ID
                            AND (SOURCE_CI_SEQ =A.CI_SEQ OR CORRECT_CI_SEQ=A.CI_SEQ)

                          )) AMOUNT,
                OFFER_SEQ,
                OFFER_ID,
                OFFER_INSTANCE_ID,
                PKG_ID,
                CHRG_FROM_DATE, --2020/06/30 MODIFY FOR MPBS_Migration 新安東京DE應顯示CHRG_FROM_DATE
                CHRG_END_DATE, --2020/06/30 MODIFY FOR MPBS_Migration 新安東京DE應顯示CHRG_END_DATE
                CHARGE_CODE,
                SOURCE,
                SOURCE_CI_SEQ,
                SOURCE_OFFER_ID,
                BI_SEQ,
                SERVICE_RECEIVER_TYPE,
                BILL_SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
           FROM FY_TB_BL_BILL_CI_TEST A
          WHERE BILL_SEQ    =gnBILL_SEQ
            AND CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_KEY    =MOD(gnACCT_ID,100)
            AND ACCT_ID     =gnACCT_ID
            AND AMOUNT      > 0
            AND ((gvOFFER_LEVEL='S' AND SERVICE_RECEIVER_TYPE='S' AND
                --SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)) OR --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                  ((gvPN_FLAG='Y' AND SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)
                                  AND SUBSCR_ID<>BILL_SUBSCR_ID) OR 
                   (gvPN_FLAG='N' AND (SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID) OR
                                       NVL(BILL_SUBSCR_ID,SUBSCR_ID)=DECODE(gvMARKET_LEVEL,'Y',NVL(BILL_SUBSCR_ID,SUBSCR_ID),gnOFFER_LEVEL_ID))))
                  ) OR
                 (gvOFFER_LEVEL='O' AND
                  ((SERVICE_RECEIVER_TYPE='O' AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                             Start with OU_ID=gnOFFER_LEVEL_ID
                                                            Connect by prior OU_ID=PARENT_OU_ID)) OR
                   (SERVICE_RECEIVER_TYPE='S' AND EXISTS (Select 1 from FY_TB_BL_BILL_SUB
                                                            WHERE BILL_SEQ    =A.BILL_SEQ
                                                              AND CYCLE       =A.CYCLE
                                                              AND CYCLE_MONTH =A.CYCLE_MONTH
                                                              AND ACCT_ID     =A.ACCT_ID
                                                              AND ACCT_KEY    =A.ACCT_KEY 
                                                            --AND SUBSCR_ID   =A.SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                                                              --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                                                              AND ((gvPN_FLAG='Y' AND SUBSCR_ID=A.SUBSCR_ID AND SUBSCR_ID<>BILL_SUBSCR_ID) OR
                                                                   (gvPN_FLAG='N' AND (SUBSCR_ID=A.SUBSCR_ID OR BILL_SUBSCR_ID=A.SUBSCR_ID)))
                                                              AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                                             Start with OU_ID=gnOFFER_LEVEL_ID
                                                                            Connect by prior OU_ID=PARENT_OU_ID)))
                  )))
            AND (PI_ELIGIBLE_IN IS NULL OR
                 (EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                           WHERE CRI_GROUP_ID =PI_ELIGIBLE_IN
                             AND CRI_TYPE     ='D'
                             AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                             AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                             AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                             AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                  DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                             AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                             AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                ))
            AND (PI_ELIGIBLE_EX IS NULL OR
                 (NOT EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                               WHERE CRI_GROUP_ID =PI_ELIGIBLE_EX
                                 AND CRI_TYPE     ='D'
                                 AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                                 AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                                 AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                                 AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                      DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                                 AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                                 AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                ))
            AND gvPROC_TYPE='T'
            --2020/06/30 MODIFY FOR MPBS_Migration ADD 新安東京RC OFFER生效日必須小於折扣生效日
            AND ((gvTMNEWA <>'Y') OR
                 (gvTMNEWA  ='Y' AND ((SOURCE='RC' AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG
                                                              WHERE OFFER_SEQ =A.OFFER_SEQ
                                                                AND A.CHRG_END_DATE >=PI_EFF_DATE --2020/06/30 MODIFY FOR MPBS_Migration 新安東京RC Charge需在折扣生效期間
                                                                AND TRUNC(EFF_DATE) <=PI_EFF_DATE
                                                                AND least(NVL(END_DATE-1,gdBILL_END_DATE),
                                                                          NVL(FUTURE_EXP_DATE-1,gdBILL_END_DATE),
                                                                          gdBILL_END_DATE)>=PI_EFF_DATE)) OR
                                       gvPREPAYMENT IS NOT NULL)) --2021/06/15 MODIFY FOR 小額預繳處理 ADD PERPAYMENT
                )
          ORDER BY CI_SEQ;

      NU_RATES           NUMBER;
      NU_RATES_AMT       NUMBER;
      NU_CTRL_AMT        NUMBER;
      NU_CHRG_AMT        NUMBER;
      NU_CHRG_QTY        NUMBER;
      NU_AMT_QTY         NUMBER;
      NU_CTRL_AMT_QTY    NUMBER;
      NU_CNT             NUMBER;
      NU_CTRL_CNT        NUMBER  :=0;
      NU_TOT_AMOUNT      NUMBER;
      NU_PKG_QTY         NUMBER  :=0;
      NU_PKG_USE         NUMBER  :=0;
      NU_PKG_DISC        NUMBER  :=0;
      NU_ACTIVE_DAY      NUMBER;
      DT_START_DATE      DATE; --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應顯示CHRG_FROM_DATE
      DT_END_DATE        DATE; --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應顯示CHRG_END_DATE
   --   Tab_PKG_RATES      t_PKG_RATES;
      On_Err             EXCEPTION;
   BEGIN
      dbms_output.enable(999999999999999999999);
      --GET TOTOL_AMOUNT
      gvSTEP := 'GET TOTOL_AMOUNT';
      IF PI_CRI_ORDER IS NULL THEN
         NU_TOT_AMOUNT := 0;
      ELSIF gvDIS_UOM_METHOD='A' OR 
           (gvDIS_UOM_METHOD='P' AND gvTMNEWA='Y') THEN  --2020/06/30 MODIFY FOR MPBS_Migration ADD DIS_UOM_METHOD='P'總額處理
         IF gVPROC_TYPE='B' THEN
            SELECT COUNT(1),
                   NVL(SUM((NVL(AMOUNT,0)+(SELECT NVL(SUM(NVL(AMOUNT,0)),0)
                                         FROM FY_TB_BL_BILL_CI
                                        WHERE BILL_SEQ      =A.BILL_SEQ
                                          AND CYCLE         =A.CYCLE
                                          AND CYCLE_MONTH   =A.CYCLE_MONTH
                                          AND ACCT_KEY      =A.ACCT_KEY
                                          AND ACCT_ID       =A.ACCT_ID
                                          AND (SOURCE_CI_SEQ =A.CI_SEQ OR CORRECT_CI_SEQ=A.CI_SEQ)
                                       ))),0) AMT
              INTO NU_CTRL_CNT, NU_TOT_AMOUNT
              FROM FY_TB_BL_BILL_CI A
             WHERE BILL_SEQ    =gnBILL_SEQ
               AND CYCLE       =gnCYCLE
               AND CYCLE_MONTH =gnCYCLE_MONTH
               AND ACCT_KEY    =MOD(gnACCT_ID,100)
               AND ACCT_ID     =gnACCT_ID
               --AND AMOUNT      >0  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
               AND (AMOUNT > 0 OR (SOURCE<>'DE' AND correct_ci_seq IS NULL)) --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
               AND ((gvOFFER_LEVEL='S' AND SERVICE_RECEIVER_TYPE='S' AND
                   --SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)) OR --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                   --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                    ((gvPN_FLAG='Y' AND SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)
                                    AND SUBSCR_ID<>BILL_SUBSCR_ID) OR 
                     (gvPN_FLAG='N' AND (SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID) OR
                                       NVL(BILL_SUBSCR_ID,SUBSCR_ID)=DECODE(gvMARKET_LEVEL,'Y',NVL(BILL_SUBSCR_ID,SUBSCR_ID),gnOFFER_LEVEL_ID))))
                     ) OR
                    (gvOFFER_LEVEL='O' AND
                     ((SERVICE_RECEIVER_TYPE='O' AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                                Start with OU_ID=gnOFFER_LEVEL_ID
                                                               Connect by prior OU_ID=PARENT_OU_ID)) OR
                      (SERVICE_RECEIVER_TYPE='S' AND EXISTS (Select 1 from FY_TB_BL_BILL_SUB
                                                              WHERE BILL_SEQ    =A.BILL_SEQ
                                                                AND CYCLE       =A.CYCLE
                                                                AND CYCLE_MONTH =A.CYCLE_MONTH
                                                                AND ACCT_ID     =A.ACCT_ID
                                                                AND ACCT_KEY    =A.ACCT_KEY 
                                                              --AND SUBSCR_ID   =A.SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                                                                --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                                                                AND ((gvPN_FLAG='Y' AND SUBSCR_ID=A.SUBSCR_ID AND SUBSCR_ID<>BILL_SUBSCR_ID) OR
                                                                     (gvPN_FLAG='N' AND (SUBSCR_ID=A.SUBSCR_ID OR BILL_SUBSCR_ID=A.SUBSCR_ID)))
                                                                AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                                               Start with OU_ID=gnOFFER_LEVEL_ID
                                                                              Connect by prior OU_ID=PARENT_OU_ID)))
                    )))
               AND (PI_ELIGIBLE_IN IS NULL OR
                    (EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                              WHERE CRI_GROUP_ID =PI_ELIGIBLE_IN
                                AND CRI_TYPE     ='D'
                                AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                                AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                                AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                                AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                     DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                                AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                                AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                   ))
               AND (PI_ELIGIBLE_EX IS NULL OR
                    (NOT EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                                       WHERE CRI_GROUP_ID =PI_ELIGIBLE_EX
                                         AND CRI_TYPE     ='D'
                                         AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                                         AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                                         AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                                         AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                              DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                                         AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                                         AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                   ))
               --2020/06/30 MODIFY FOR MPBS_Migration ADD 新安東京RC OFFER生效日必須小於折扣生效日
               AND ((gvTMNEWA <>'Y') OR
                    (gvTMNEWA  ='Y' AND ((SOURCE='RC' AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG
                                                                 WHERE OFFER_SEQ =A.OFFER_SEQ
                                                                   AND A.CHRG_END_DATE >=PI_EFF_DATE --2020/06/30 MODIFY FOR MPBS_Migration 新安東京RC Charge需在折扣生效期間
                                                                   AND TRUNC(EFF_DATE) <=PI_EFF_DATE
                                                                   AND least(NVL(END_DATE-1,gdBILL_END_DATE),
                                                                             NVL(FUTURE_EXP_DATE-1,gdBILL_END_DATE),
                                                                             gdBILL_END_DATE)>=PI_EFF_DATE)) OR
                                          gvPREPAYMENT IS NOT NULL)) --2021/06/15 MODIFY FOR 小額預繳處理 ADD PERPAYMENT
                    );
         ELSE
            SELECT COUNT(1),
                   NVL(SUM((NVL(AMOUNT,0)+(SELECT NVL(SUM(NVL(AMOUNT,0)),0)
                                         FROM FY_TB_BL_BILL_CI_TEST
                                        WHERE BILL_SEQ      =A.BILL_SEQ
                                          AND CYCLE         =A.CYCLE
                                          AND CYCLE_MONTH   =A.CYCLE_MONTH
                                          AND ACCT_KEY      =A.ACCT_KEY
                                          AND ACCT_ID       =A.ACCT_ID
                                          AND (SOURCE_CI_SEQ =A.CI_SEQ OR CORRECT_CI_SEQ=A.CI_SEQ)
                                       ))),0) AMT
              INTO NU_CTRL_CNT, NU_TOT_AMOUNT
              FROM FY_TB_BL_BILL_CI_TEST A
             WHERE BILL_SEQ    =gnBILL_SEQ
               AND CYCLE       =gnCYCLE
               AND CYCLE_MONTH =gnCYCLE_MONTH
               AND ACCT_KEY    =MOD(gnACCT_ID,100)
               AND ACCT_ID     =gnACCT_ID
               --AND AMOUNT      >0  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
               AND (AMOUNT > 0 OR (SOURCE<>'DE' AND correct_ci_seq IS NULL)) --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
               AND ((gvOFFER_LEVEL='S' AND SERVICE_RECEIVER_TYPE='S' AND
                   --SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)) OR --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                   --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                    ((gvPN_FLAG='Y' AND SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID)
                                    AND SUBSCR_ID<>BILL_SUBSCR_ID) OR 
                     (gvPN_FLAG='N' AND (SUBSCR_ID=DECODE(gvMARKET_LEVEL,'Y',SUBSCR_ID,gnOFFER_LEVEL_ID) OR
                                       NVL(BILL_SUBSCR_ID,SUBSCR_ID)=DECODE(gvMARKET_LEVEL,'Y',NVL(BILL_SUBSCR_ID,SUBSCR_ID),gnOFFER_LEVEL_ID))))
                     ) OR
                    (gvOFFER_LEVEL='O' AND
                     ((SERVICE_RECEIVER_TYPE='O' AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                                Start with OU_ID=gnOFFER_LEVEL_ID
                                                               Connect by prior OU_ID=PARENT_OU_ID)) OR
                      (SERVICE_RECEIVER_TYPE='S' AND EXISTS (Select 1 from FY_TB_BL_BILL_SUB
                                                              WHERE BILL_SEQ    =A.BILL_SEQ
                                                                AND CYCLE       =A.CYCLE
                                                                AND CYCLE_MONTH =A.CYCLE_MONTH
                                                                AND ACCT_ID     =A.ACCT_ID
                                                                AND ACCT_KEY    =A.ACCT_KEY 
                                                              --AND SUBSCR_ID   =A.SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                                                                --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理 增加gvPN_FLAG判別
                                                                AND ((gvPN_FLAG='Y' AND SUBSCR_ID=A.SUBSCR_ID AND SUBSCR_ID<>BILL_SUBSCR_ID) OR
                                                                     (gvPN_FLAG='N' AND (SUBSCR_ID=A.SUBSCR_ID OR BILL_SUBSCR_ID=A.SUBSCR_ID)))
                                                                AND OU_ID IN (Select OU_ID from FY_TB_CM_ORG_UNIT
                                                                               Start with OU_ID=gnOFFER_LEVEL_ID
                                                                              Connect by prior OU_ID=PARENT_OU_ID)))
                    )))
               AND (PI_ELIGIBLE_IN IS NULL OR
                    (EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                              WHERE CRI_GROUP_ID =PI_ELIGIBLE_IN
                                AND CRI_TYPE     ='D'
                                AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                                AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                                AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                                AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                     DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                                AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                                AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                   ))
               AND (PI_ELIGIBLE_EX IS NULL OR
                    (NOT EXISTS (SELECT 1 FROM FY_TB_PBK_CRITERION_GROUP
                                       WHERE CRI_GROUP_ID =PI_ELIGIBLE_EX
                                         AND CRI_TYPE     ='D'
                                         AND (REVENUE_CODE IS NULL OR REVENUE_CODE=A.SOURCE)
                                         AND (SERVICE_FILTER IS NULL OR SERVICE_FILTER=A.SERVICE_FILTER)
                                         AND (POINT_CLASS IS NULL OR POINT_CLASS=A.POINT_CLASS)
                                         AND (DECODE(REVENUE_CODE,'RC',RC_ID,'OC',OC_ID,NULL) IS NULL OR
                                              DECODE(REVENUE_CODE,'RC',RC_ID,OC_ID)=A.CHRG_ID)
                                         AND (CHARGE_CODE IS NULL OR CHARGE_CODE=A.CHARGE_CODE)
                                         AND (OFFER_ID IS NULL OR OFFER_ID=A.OFFER_ID))
                   ))
               --2020/06/30 MODIFY FOR MPBS_Migration ADD 新安東京RC OFFER生效日必須小於折扣生效日
               AND ((gvTMNEWA <>'Y') OR
                    (gvTMNEWA  ='Y' AND ((SOURCE='RC' AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG
                                                                 WHERE OFFER_SEQ =A.OFFER_SEQ
                                                                   AND A.CHRG_END_DATE >=PI_EFF_DATE --2020/06/30 MODIFY FOR MPBS_Migration 新安東京RC Charge需在折扣生效期間
                                                                   AND TRUNC(EFF_DATE) <=PI_EFF_DATE
                                                                   AND least(NVL(END_DATE-1,gdBILL_END_DATE),
                                                                             NVL(FUTURE_EXP_DATE-1,gdBILL_END_DATE),
                                                                             gdBILL_END_DATE)>=PI_EFF_DATE)) OR
                                         gvPREPAYMENT IS NOT NULL)) --2021/06/15 MODIFY FOR 小額預繳處理 ADD PERPAYMENT
                    );
         END IF;
      ELSE
         NU_TOT_AMOUNT := 1;
      END IF; -- gvDIS_UOM_METHOD
  --DBMS_OUTPUT.Put_Line('ACCT_ID='||TO_CHAR(gnACCT_ID)||', OFFER_LEVEL_ID='||TO_CHAR(gnOFFER_LEVEL_ID)||', ACCT_PKG_SEQ='||TO_CHAR(gnACCT_PKG_SEQ)||
  --                     ', TOT_AMT='||TO_CHAR(NU_TOT_AMOUNT)||', CNT='||TO_CHAR(NU_CTRL_CNT));
      NU_CHRG_AMT     := 0;
      NU_CTRL_AMT_QTY := PI_CONTRIBUTE_CNT;
      NU_PKG_DISC     := 0;
      --RATES處理
      FOR i IN 1 .. 5 LOOP
         IF PI_Tab_PKG_RATES(i).ITEM_NO IS NULL THEN
            EXIT;
         END IF;
         IF NU_CTRL_AMT_QTY >= PI_Tab_PKG_RATES(i).QTY_S THEN
            --CHECK 條件數量迄
            IF gvPRICING_TYPE<>'F' AND NU_CTRL_AMT_QTY>=PI_Tab_PKG_RATES(i).QTY_E THEN
               NU_CTRL_AMT_QTY := PI_Tab_PKG_RATES(i).QTY_E -0.0001 ;
            END IF;
            --CHECK 條件數量起
            IF gvPRICING_TYPE='S' THEN
               IF PI_Tab_PKG_RATES(i).QTY_S=0 THEN
                  NU_CHRG_QTY := NU_CTRL_AMT_QTY-PI_Tab_PKG_RATES(i).QTY_S;
               ELSE
                  NU_CHRG_QTY := NU_CTRL_AMT_QTY-PI_Tab_PKG_RATES(i).QTY_S+1;
               END IF;
            ELSE
               NU_CHRG_QTY := NU_CTRL_AMT_QTY;
            END IF;
            IF gvDIS_UOM_METHOD='P' THEN --2020/06/30 MODIFY FOR MPBS_Migration ADD DIS_UOM_METHOD='P'無破月&無遞延處理
               NU_RATES :=PI_Tab_PKG_RATES(i).RATES;
            ELSIF gvPRORATE_METHOD='Y' AND PI_MARKET='N' THEN --非MARKET MOVE
               gvSTEP := 'GET_ACTIVE_DAY:';
               GET_ACTIVE_DAY('DE',
                              PI_FROM_DATE,
                              PI_END_DATE,
                              NU_CHRG_QTY ,
                              PI_Tab_PKG_RATES,
                              NU_ACTIVE_DAY); 
               IF gvERR_CDE<>'0000' THEN
                  gvSTEP := SUBSTR(gvSTEP||gvERR_MSG,1,250);
                  RAISE ON_ERR;
               END IF;
               NU_RATES :=PI_Tab_PKG_RATES(i).RATES*round(NU_ACTIVE_DAY/(gdBILL_END_DATE-gdBILL_FROM_DATE+1),6)+gnROLLING_QTY; --2020/06/30 MODIFY FOR MPBS_Migration 因修改所有RC月租計算比重ROUND至小數6位，故DE可扣抵金額也一併修改
            ELSE
               NU_RATES :=PI_Tab_PKG_RATES(i).RATES+gnROLLING_QTY;
            END IF;
            IF gvDIS_UOM_METHOD='A' THEN
               IF gvTMNEWA<>'N' THEN  --2020/06/30 MODIFY FOR MPBS_Migration ADD gvTMNEWA<>'N' CHECK
                  NU_RATES := ROUND(NU_RATES,gnROUNDING);
               ELSE
                  NU_RATES := ROUND(NU_RATES,2);
               END IF;   
            END IF;
            IF gvDIS_UOM_METHOD='P' AND gvTMNEWA='Y' THEN --2020/06/30 MODIFY FOR MPBS_Migration ADD DIS_UOM_METHOD='P'新安東京處理
               NU_CTRL_AMT := ROUND(NU_TOT_AMOUNT*(NU_RATES/100),gnROUNDING);
            ELSIF gvDIS_UOM_METHOD='A' AND NU_RATES>NU_TOT_AMOUNT THEN
               NU_CTRL_AMT := NU_TOT_AMOUNT;
            ELSE
               NU_CTRL_AMT := NU_RATES;
            END IF;
            IF gvPRICING_TYPE='F' AND gvDIS_UOM_METHOD='A' THEN
               NU_PKG_QTY := NU_RATES;
               --NU_PKG_USE := NU_CTRL_AMT; --2024/04/16 MODIFY FOR SR266082_ICT專案，折扣不折抵負項金額
               IF NU_CTRL_AMT >= 0 THEN
                    NU_PKG_USE := NU_CTRL_AMT;
               ELSE
                    NU_PKG_USE := 0;
               END IF;
            ELSE
               NU_PKG_QTY := NULL;
               NU_PKG_USE := NULL;
            END IF; 
 --   DBMS_OUTPUT.Put_Line('OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||', NU_RATES='||TO_CHAR(NU_RATES)||
 --                       ', NU_CTRL_AMT='||to_char(NU_CTRL_AMT)||', NU_TOT_AMOUNT='||TO_CHAR(NU_TOT_AMOUNT)||
 --                       ', CNT='||TO_CHAR(NU_CTRL_CNT)||' ,CHRG_QTY='||TO_CHAR(NU_CHRG_QTY)||
 --                       ', CONTRIBUTE_CNT='||TO_CHAR(PI_CONTRIBUTE_CNT));         
            IF NU_TOT_AMOUNT>0 THEN
               NU_CNT      := 0;
               NU_RATES_AMT:=NU_CTRL_AMT;
               FOR R_CI IN C_CI LOOP
                  gvCHRG_ID     := R_CI.CHRG_ID;
                  gvCHARGE_CODE := R_CI.CHARGE_CODE;
                  gnSUBSCR_ID   := R_CI.SUBSCR_ID;
                  gnOU_ID       := R_CI.OU_ID;
                  NU_CNT        := NU_CNT+1;
                  gnBILL_SUBSCR_ID := R_CI.BILL_SUBSCR_ID;  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                  --DIS_UOM_METHOD
                  IF gvDIS_UOM_METHOD='P' THEN
                     IF gvTMNEWA='Y' THEN  --2020/06/30 MODIFY FOR MPBS_Migration ADD gvTMNEWA='Y' 處理
                        IF NU_CNT=NU_CTRL_CNT THEN
                           NU_CHRG_AMT := NU_CTRL_AMT;
                        ELSE
                           NU_CHRG_AMT := ROUND(R_CI.AMOUNT*(NU_RATES/100)*NU_CHRG_QTY/PI_CONTRIBUTE_CNT,gnROUNDING);
                        END IF;
                        IF NU_CHRG_AMT> NU_CTRL_AMT THEN
                           NU_CHRG_AMT := NU_CTRL_AMT;
                        END IF;
                        NU_CTRL_AMT := NU_CTRL_AMT - NU_CHRG_AMT;                        
                     ELSE
                        NU_CHRG_AMT := ROUND(R_CI.AMOUNT*(NU_RATES/100)*NU_CHRG_QTY/PI_CONTRIBUTE_CNT,2);
                     END IF;   
                  ELSE
                     IF NU_CNT=NU_CTRL_CNT THEN
                        NU_CHRG_AMT := NU_CTRL_AMT;
                     ELSE
                        IF gvTMNEWA<>'N' THEN  --2020/06/30 MODIFY FOR MPBS_Migration ADD gvTMNEWA<>'N' CHECK
                           NU_CHRG_AMT := ROUND(NU_RATES_AMT*R_CI.AMOUNT/NU_TOT_AMOUNT,gnROUNDING);
                        ELSE
                           NU_CHRG_AMT := ROUND(NU_RATES_AMT*R_CI.AMOUNT/NU_TOT_AMOUNT,2);
                        END IF;  
                     END IF;
                     IF NU_CHRG_AMT> NU_CTRL_AMT THEN
                        NU_CHRG_AMT := NU_CTRL_AMT;
                     END IF;
                     NU_CTRL_AMT := NU_CTRL_AMT - NU_CHRG_AMT;
                     IF NU_CHRG_AMT<0 THEN
                        NU_CHRG_AMT := 0;
                     END IF;
                  END IF;
            DBMS_OUTPUT.Put_Line('<ACCT_ID='||gnACCT_ID||', SUB_ID='||to_char(gnSUBSCR_ID)||', CHARGE_CODE='||TO_CHAR(gvCHARGE_CODE)||', CHRG_AMT='||TO_CHAR(NU_CHRG_AMT*-1)||'>');
                  IF NU_CHRG_AMT>0 THEN
                     gnSUBSCR_ID := R_CI.SUBSCR_ID;
                     gnOU_ID     := R_CI.OU_ID;
                     gvSTEP := 'INS_CI:';
                     DT_START_DATE := greatest(trunc(PI_FROM_DATE), R_CI.CHRG_FROM_DATE);--取其大
                     DT_END_DATE   := least(trunc(PI_END_DATE),NVL(R_CI.CHRG_END_DATE,PI_END_DATE)); --取其小
                     INS_CI(DT_START_DATE,
                            DT_END_DATE,
                            'DE', ---PI_SOURCE
                            R_CI.CI_SEQ,   ---PI_SOURCE_CI_SEQ ,
                            R_CI.OFFER_ID, ---PI_SOURCE_OFFER_ID,
                            R_CI.SERVICE_RECEIVER_TYPE,
                            NU_CHRG_AMT*-1);
                     IF gvERR_CDE<>'0000' THEN
                        gvSTEP := SUBSTR(gvSTEP||gvERR_MSG,1,250);
                        RAISE ON_ERR;
                     END IF;
                  END IF;
                  NU_PKG_DISC := NU_PKG_DISC+NU_CHRG_AMT;
               END LOOP; --CI
               NU_CTRL_AMT_QTY  := NU_CTRL_AMT_QTY - NU_CHRG_QTY;
               NU_TOT_AMOUNT    := NU_TOT_AMOUNT - NU_RATES_AMT;
            END IF; ---NU_TOT_AMOUNT
         END IF; --NU_CTRL_AMT_QTY >= Tab_PKG_RATES(i).QTY_S
         IF NU_CTRL_AMT_QTY=0 OR NU_TOT_AMOUNT=0 THEN
            EXIT;
         END IF;
      END LOOP;  --RATES
      PO_PKG_DISC := NU_PKG_DISC;
      PO_PKG_QTY  := NU_PKG_QTY;
      PO_PKG_USE  := NU_PKG_USE;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END DO_ELIGIBLE;

   /*************************************************************************
      PROCEDURE : GET_SUSPEND_DAY
      PURPOSE :   GET SUBSCR_ID SUSPEND DAY
      DESCRIPTION : GET SUBSCR_ID SUSPEND DAY
      PARAMETER:
            PI_TYPE               :RC:INSERT SUSPEND_DAY 
            PI_AMY_QTY            :計費數量
            PI_Tab_PKG_RATES      :PBK多皆費率
            PI_CUR_BILLED         :CURRENT BILLED 日期
            PO_ACTIVE_DAY         :計算期間SUSPEND天數
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration DO_RC_ACTIVE新增兩個參數PI_RC_CTRL_AMT,PO_RC_AMT
   **************************************************************************/
   PROCEDURE GET_SUSPEND_DAY(PI_TYPE             IN   VARCHAR2,
                             PI_AMY_QTY          IN   NUMBER,
                             PI_Tab_PKG_RATES    IN   t_PKG_RATES,
                             PI_CUR_BILLED       IN    DATE,
                             PO_ACTIVE_DAY      OUT   NUMBER) IS

      CURSOR C_SP IS
            SELECT   status, TRUNC (status_date) status_date,TRUNC (exp_date) - 1 exp_date, prev_billed, recur_billed
                FROM fy_tb_bl_sub_status_period a,
                    (SELECT bill_from_date, bill_end_date
                        FROM fy_tb_bl_bill_cntrl
                    WHERE bill_seq = gnBILL_SEQ) b
            WHERE subscr_id = gnSUBSCR_ID
                AND status = 'S'
                AND exp_date IS NOT NULL
                AND exp_date < TRUNC (b.bill_end_date) + 1
                AND exp_date >= TRUNC (b.bill_from_date)
                AND TRUNC(exp_date)-1 <= PI_CUR_BILLED --sharon add
                AND TRUNC (exp_date) != nvl((SELECT TRUNC (status_date)
                                            FROM fy_tb_bl_sub_status_period
                                        WHERE status = 'C' AND subscr_id = gnSUBSCR_ID),to_date(20991231,'yyyymmdd'))
            ORDER BY status_date;

      NU_CNT             NUMBER  :=0;
      DT_START_DATE      DATE;
      DT_END_DATE        DATE;
      On_Err             EXCEPTION;
      NU_RC_CTRL_AMT     NUMBER;    --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC總額
      NU_RC_AMT          NUMBER;    --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC金額
   BEGIN
      if gvOFFER_LEVEL='S' AND gvPRORATE_METHOD='Y' THEN  --破月
         nu_cnt := 0;
         FOR R_SP IN C_SP LOOP
            DT_START_DATE := R_SP.STATUS_DATE;
            DT_END_DATE   := R_SP.EXP_DATE;
            NU_CNT        := NU_CNT + (DT_END_DATE-DT_START_DATE)+1;
            IF PI_TYPE='RC' THEN
               gvSTEP := 'DO_RC_ACTIVE:';
               DO_RC_ACTIVE(DT_START_DATE,
                            DT_END_DATE,
                            PI_AMY_QTY,
                            PI_Tab_PKG_RATES,
                            NU_RC_CTRL_AMT,  --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC總額
                            NU_RC_AMT);      --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC金額
               IF gvERR_CDE<>'0000' THEN
                  gvSTEP := SUBSTR('DO_RC_ACTIVE:'||gvERR_MSG,1,250);
                  RAISE ON_ERR;
               END IF;
            END IF;
         END LOOP;
      END IF;
      PO_ACTIVE_DAY := NU_CNT;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END GET_SUSPEND_DAY;
   
   /*************************************************************************
      PROCEDURE : GET_ACTIVE_DAY
      PURPOSE :   GET SUBSCR_ID ACTIVE DAY
      DESCRIPTION : GET SUBSCR_ID ACTIVE DAY
      PARAMETER:
            PI_TYPE               :DE:GET ACTIVE_DAY/RC:INSERT ACTIVE_DAY
            PI_START_DATE         :計算開始日
            PI_END_DATE           :計算截止日
            PI_AMY_QTY            :計費數量
            PI_Tab_PKG_RATES      :PBK多皆費率
            PO_ACTIVE_DAY         :計算期間ACTIVE天數(扣除停話天數)
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration ADD新安東京GET RC應收總額控制
   **************************************************************************/
   PROCEDURE GET_ACTIVE_DAY(PI_TYPE             IN   VARCHAR2,
                            PI_START_DATE       IN   DATE,
                            PI_END_DATE         IN   DATE,
                            PI_AMY_QTY          IN   NUMBER,
                            PI_Tab_PKG_RATES    IN   t_PKG_RATES,
                            PO_ACTIVE_DAY      OUT   NUMBER) IS

      CURSOR C_SP IS
         SELECT STATUS,
                trunc(STATUS_DATE) status_date,
                TRUNC(EXP_DATE)-1 EXP_DATE,
                PREV_BILLED,
                RECUR_BILLED
           FROM FY_TB_BL_SUB_STATUS_PERIOD
          WHERE SUBSCR_ID = gnSUBSCR_ID
            AND STATUS    = 'A'
            AND STATUS_DATE < trunc(PI_END_DATE)+1 --SR228032 - NPEP 專案 Phase 2.1 add trunc
            AND (EXP_DATE IS NULL OR EXP_DATE>=trunc(PI_START_DATE)+1) --SR228032 - NPEP 專案 Phase 2.1 add trunc
          ORDER BY STATUS_DATE;

      --2021/10/20 MODIFY SR239378 SDWAN_NPEP solution建置 暫斷區間
      CURSOR C_SP2 IS
         SELECT STATUS,
                trunc(STATUS_DATE) status_date,
                TRUNC(EXP_DATE)-1 EXP_DATE,
                PREV_BILLED,
                RECUR_BILLED
           FROM FY_TB_BL_SUB_STATUS_PERIOD
          WHERE SUBSCR_ID = gnSUBSCR_ID
            AND STATUS    = 'S'
            AND STATUS_DATE < trunc(PI_END_DATE)+1
            AND (EXP_DATE IS NULL OR EXP_DATE>=trunc(PI_START_DATE)+1)
          ORDER BY STATUS_DATE;

      --2022/09/29 MODIFY FOR SR250171_ESDP_Migration_Project (年繳退款抓END_DATE)
      CURSOR C_SP3 IS
         SELECT STATUS,
                trunc(STATUS_DATE) status_date,
                trunc(PI_END_DATE)+1 EXP_DATE,
                PREV_BILLED,
                RECUR_BILLED
           FROM FY_TB_BL_SUB_STATUS_PERIOD
          WHERE SUBSCR_ID = gnSUBSCR_ID
            AND STATUS    = 'C'
            AND STATUS_DATE < trunc(PI_END_DATE)+1
            AND (EXP_DATE IS NULL OR EXP_DATE>=trunc(PI_START_DATE)+1)
          ORDER BY STATUS_DATE;
          
      NU_CNT             NUMBER  :=0;
      DT_START_DATE      DATE;
      DT_END_DATE        DATE;
      On_Err             EXCEPTION;
      NU_MONTH           NUMBER;    --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收月數(含補收)
      NU_RC_CTRL_AMT     NUMBER;    --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC總額
      NU_RC_AMT          NUMBER;    --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC金額
   BEGIN
      --if pi_end_date<pi_start_date then
      if trunc(pi_end_date)<trunc(pi_start_date) then --2022/09/19 MODIFY FOR SR250171_ESDP_Migration_Project_修正同日無加TRUNC導致判斷錯誤
         nu_cnt := 0;
      ELSIF gvOFFER_LEVEL='S' AND gvPRORATE_METHOD='Y' THEN  --破月
         nu_cnt := 0;

         --2020/06/30 MODIFY FOR MPBS_Migration 計算RC應收總額(只針對個人&破月)         
         IF gvTMNEWA='Y' AND PI_TYPE='RC' THEN
            gvSTEP := 'GET_MPBL_AMT:';
            GET_MPBL_AMT(PI_START_DATE,
                         PI_END_DATE,
                         PI_AMY_QTY,
                         PI_Tab_PKG_RATES,
                         NU_MONTH,  
                         NU_RC_AMT);
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR('GET_MPBL_AMT:'||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;
            NU_RC_CTRL_AMT := NU_RC_AMT;
         END IF;  --2020/06/30 
                 
         FOR R_SP IN C_SP LOOP
            DT_START_DATE := greatest(trunc(PI_START_DATE), R_SP.STATUS_DATE);--取其大
            DT_END_DATE   := least(trunc(PI_END_DATE),NVL(R_SP.EXP_DATE,PI_END_DATE)); --取其小
            NU_CNT        := NU_CNT + (DT_END_DATE-DT_START_DATE)+1;
            IF PI_TYPE='RC' THEN
               gvSTEP := 'DO_RC_ACTIVE:';
               DO_RC_ACTIVE(DT_START_DATE,
                            DT_END_DATE,
                            PI_AMY_QTY,
                            PI_Tab_PKG_RATES,
                            NU_RC_CTRL_AMT,  --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC總額
                            NU_RC_AMT);      --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC金額
               IF gvERR_CDE<>'0000' THEN
                  gvSTEP := SUBSTR('DO_RC_ACTIVE:'||gvERR_MSG,1,250);
                  RAISE ON_ERR;
               END IF;
               --2020/06/30 MODIFY FOR MPBS_Migration 總額NU_RC_CTRL_AMT處理
               IF gvTMNEWA='Y' THEN
                  NU_RC_CTRL_AMT := NU_RC_CTRL_AMT - NU_RC_AMT;   
               END IF;
            END IF;
            IF DT_END_DATE=trunc(PI_END_DATE) THEN
               EXIT;
            END IF;
         END LOOP;
         
         --2021/10/20 MODIFY SR239378 SDWAN_NPEP solution建置 暫斷收費計算
         IF gvSDWAN='Y' THEN
            FOR R_SP2 IN C_SP2 LOOP
                DT_START_DATE := greatest(trunc(PI_START_DATE), R_SP2.STATUS_DATE);--取其大
                DT_END_DATE   := least(trunc(PI_END_DATE),NVL(R_SP2.EXP_DATE,PI_END_DATE)); --取其小
                NU_CNT        := NU_CNT + (DT_END_DATE-DT_START_DATE)+1;
                IF PI_TYPE='RC' THEN
                    gvSTEP := 'DO_RC_ACTIVE:';
                    DO_RC_ACTIVE(DT_START_DATE,
                                    DT_END_DATE,
                                    PI_AMY_QTY,
                                    PI_Tab_PKG_RATES,
                                    NU_RC_CTRL_AMT,  --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC總額
                                    NU_RC_AMT);      --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC金額
                    IF gvERR_CDE<>'0000' THEN
                        gvSTEP := SUBSTR('DO_RC_ACTIVE:'||gvERR_MSG,1,250);
                        RAISE ON_ERR;
                    END IF;
                END IF;
                IF DT_END_DATE=trunc(PI_END_DATE) THEN
                    EXIT;
                END IF;
            END LOOP;
         END IF;
         
         --2022/09/29 MODIFY FOR SR250171_ESDP_Migration_Project (年繳退款抓END_DATE)
         IF gvCI_STEP='T' THEN
            FOR R_SP3 IN C_SP3 LOOP
                DT_START_DATE := greatest(trunc(PI_START_DATE), R_SP3.STATUS_DATE);--取其大
                DT_END_DATE   := least(trunc(PI_END_DATE),NVL(R_SP3.EXP_DATE,PI_END_DATE)); --取其小
                NU_CNT        := NU_CNT + (DT_END_DATE-DT_START_DATE)+1;
                IF PI_TYPE='RC' THEN
                    gvSTEP := 'DO_RC_ACTIVE:';
                    DO_RC_ACTIVE(DT_START_DATE,
                                    DT_END_DATE,
                                    PI_AMY_QTY,
                                    PI_Tab_PKG_RATES,
                                    NU_RC_CTRL_AMT,  --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC總額
                                    NU_RC_AMT);      --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC金額
                    IF gvERR_CDE<>'0000' THEN
                        gvSTEP := SUBSTR('DO_RC_ACTIVE:'||gvERR_MSG,1,250);
                        RAISE ON_ERR;
                    END IF;
                END IF;
                IF DT_END_DATE=trunc(PI_END_DATE) THEN
                    EXIT;
                END IF;
            END LOOP;
         END IF;

      ELSE
         NU_CNT := trunc(PI_END_DATE)-trunc(PI_START_DATE)+1;
         IF PI_TYPE='RC' THEN
            gvSTEP := 'DO_RC_ACTIVE:';
            DO_RC_ACTIVE(trunc(PI_START_DATE),
                         trunc(PI_END_DATE),
                         PI_AMY_QTY,
                         PI_Tab_PKG_RATES,
                         NU_RC_CTRL_AMT,  --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC總額
                         NU_RC_AMT);      --2020/06/30 MODIFY FOR MPBS_Migration 新安東京應收RC金額
DBMS_OUTPUT.Put_Line('LINE2548 -  PI_AMY_QTY ='|| PI_AMY_QTY );                           
            IF gvERR_CDE<>'0000' THEN              
               gvSTEP := SUBSTR('OU DO_RC_ACTIVE:'||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;
         END IF;
      END IF;
      PO_ACTIVE_DAY := NU_CNT;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END GET_ACTIVE_DAY;

   /*************************************************************************
      PROCEDURE : DO_RC_ACTIVE
      PURPOSE :   DO SUBSCR_ID ACTIVE DAY RC處理
      DESCRIPTION : DO SUBSCR_ID ACTIVE DAY RC處理
      PARAMETER:
            PI_START_DATE         :計算開始日
            PI_END_DATE           :計算截止日
            PI_AMY_QTY            :計費數量
            PI_Tab_PKG_RATES      :PBK多皆費率
            PI_RC_CTRL_AMT        :新安東京應收RC總額
            PO_RC_AMT             :應收RC金額
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 新增兩個參數PI_RC_CTRL_AMT,PO_RC_AMT
   **************************************************************************/
   PROCEDURE DO_RC_ACTIVE(PI_START_DATE       IN   DATE,
                          PI_END_DATE         IN   DATE,
                          PI_AMY_QTY          IN   NUMBER,
                          PI_Tab_PKG_RATES    IN   t_PKG_RATES,
                          PI_RC_CTRL_AMT      IN   NUMBER,       --2020/06/30 MODIFY FOR MPBS_Migration
                          PO_RC_AMT          OUT   NUMBER) IS    --2020/06/30 MODIFY FOR MPBS_Migration

      NU_CNT             NUMBER  :=0;
      NU_QTY_CNT         NUMBER;
      NU_MONTH           NUMBER;
      NU_CHRG_AMT        NUMBER;
      NU_CTRL_AMT_QTY    NUMBER;
      NU_CHRG_QTY        NUMBER;
      DT_START_DATE      DATE;
      DT_END_DATE        DATE;
    --  Tab_PKG_RATES      t_PKG_RATES;
      On_Err             EXCEPTION;
   BEGIN
      dbms_output.enable(999999999999999999999);
      PO_RC_AMT := 0; --2020/06/30 MODIFY FOR MPBS_Migration
      IF gvQTY_CONDITION='D' THEN --服務數量(定義offer parameter, 由CM提供)
         NU_QTY_CNT := PI_AMY_QTY;
         IF NU_QTY_CNT < 1 THEN --2020/06/30 MODIFY FOR MPBS_Migration
            --gvDYNAMIC_ATTRIBUTE := 'DEVICE_COUNT='||'0'||TO_CHAR(NU_QTY_CNT);
            gvDYNAMIC_ATTRIBUTE := gvDYNAMIC_ATTRIBUTE||'#DEVICE_COUNT='||'0'||TO_CHAR(NU_QTY_CNT); --2022/07/28 MODIFY FOR SR250171_ESDP_Migration_Project (使年繳有單價*數量功能)
         ELSE
            --gvDYNAMIC_ATTRIBUTE := 'DEVICE_COUNT='||NU_QTY_CNT;
            gvDYNAMIC_ATTRIBUTE := gvDYNAMIC_ATTRIBUTE||'#DEVICE_COUNT='||NU_QTY_CNT; --2022/07/28 MODIFY FOR SR250171_ESDP_Migration_Project (使年繳有單價*數量功能)
         END IF;
      ELSE
         NU_QTY_CNT := 1;
      END IF;
      --GET MONTH
      gvSTEP := 'GET_MONTH.OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||':';
      GET_MONTH(TRUNC(PI_START_DATE),
                TRUNC(PI_END_DATE),
                NU_MONTH);
      IF gvERR_CDE<>'0000' THEN
         gvSTEP := SUBSTR('GET_MONTH.OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||':'||gvERR_MSG,1,250);
         RAISE ON_ERR;
      END IF;
      gvSTEP := 'CHECK FREQUENCY='||TO_CHAR(gnFREQUENCY);
      IF gvPRORATE_METHOD<>'Y' AND NU_MONTH<gnFREQUENCY THEN
         IF gvCI_STEP='T' THEN --補退
            NU_MONTH := 0;
         ELSE
            NU_MONTH := gnFREQUENCY;
         END IF;
      END IF;
      NU_CHRG_AMT     := 0;
      NU_CTRL_AMT_QTY := PI_AMY_QTY;
      --RATES處理
      gvSTEP := 'RATES處理';
      FOR i IN 1 .. 5 LOOP
         IF PI_Tab_PKG_RATES(i).ITEM_NO IS NULL THEN
            EXIT;
         END IF;
         IF NU_CTRL_AMT_QTY >= NVL(PI_Tab_PKG_RATES(i).QTY_S,0) THEN
            --CHECK 條件數量迄
            IF gvPRICING_TYPE<>'F' AND NU_CTRL_AMT_QTY>=PI_Tab_PKG_RATES(i).QTY_E THEN
               NU_CTRL_AMT_QTY := PI_Tab_PKG_RATES(i).QTY_E -0.0001 ;
            END IF;
            --CHECK 條件數量起
            IF gvPRICING_TYPE='S' THEN
               IF PI_Tab_PKG_RATES(i).QTY_S=0 THEN
                  NU_CHRG_QTY := NU_CTRL_AMT_QTY;
               ELSE
                  NU_CHRG_QTY := NU_CTRL_AMT_QTY-PI_Tab_PKG_RATES(i).QTY_S+1;
               END IF;
            ELSE
               NU_CHRG_QTY := NU_CTRL_AMT_QTY;
            END IF;
  --  DBMS_OUTPUT.Put_Line('AMT='||TO_CHAR(NU_CHRG_AMT)||' ,REQUENCY='||TO_CHAR(gnFREQUENCY)||' ,MON='||TO_CHAR(NU_MONTH)||' ,QTY='||TO_CHAR(NU_QTY_CNT));
            NU_CHRG_AMT    := ROUND(NU_CHRG_AMT+PI_Tab_PKG_RATES(i).RATES/gnFREQUENCY*NU_QTY_CNT*NU_MONTH,2);
            NU_CTRL_AMT_QTY:= NU_CTRL_AMT_QTY - NU_CHRG_QTY;
         END IF;
         IF NU_CTRL_AMT_QTY=0 THEN
            EXIT;
         END IF;
      END LOOP;
      --IF gvCI_STEP='T' OR gvCI_STEP='S' THEN --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
      IF gvDFC = 'Y' AND (gvCI_STEP='T' OR gvCI_STEP='S') THEN --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算 --2022/10/24 MODIFY FOR SR250171_ESDP_Migration_Project (年繳已收暫斷期間不需收費則需退款)
         NU_CHRG_AMT  := NU_CHRG_AMT*-1;
      ELSIF  gvDFC = 'N' AND (gvCI_STEP='T' OR gvCI_STEP='S') THEN --2022/10/24 MODIFY FOR SR250171_ESDP_Migration_Project (年繳已收暫斷期間需收費則不需退款)
         NU_CHRG_AMT  :=0;
      ELSE --後收SUSPEND補收 --2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
         NU_CHRG_AMT  := NU_CHRG_AMT;
      END IF;
      
      --2020/06/30 MODIFY FOR MPBS_Migration FOR 破月且非退費才做總額管控
      IF gvTMNEWA='Y' THEN
         NU_CHRG_AMT  := ROUND(NU_CHRG_AMT, gnROUNDING);
         IF gvPRORATE_METHOD='Y' AND gvCI_STEP<>'T' THEN
            IF (PI_START_DATE=gdLAST_DATE) OR 
               (NU_CHRG_AMT>=0 AND NU_CHRG_AMT>PI_RC_CTRL_AMT) OR
               (NU_CHRG_AMT<0 AND NU_CHRG_AMT<PI_RC_CTRL_AMT) THEN
               NU_CHRG_AMT := PI_RC_CTRL_AMT;
            END IF;
         END IF;   
         PO_RC_AMT := NU_CHRG_AMT;
      END IF;  --2020/06/30      
      
      --CALL INSERT BILL_CI
      gvSTEP := 'INS_CI:';
            DBMS_OUTPUT.Put_Line('<ACCT_ID='||gnACCT_ID||', SUB_ID='||to_char(gnSUBSCR_ID)||', CHARGE_CODE='||TO_CHAR(gvCHARGE_CODE)||', CHRG_AMT='||TO_CHAR(NU_CHRG_AMT)||'>'); 
      INS_CI(PI_START_DATE,
             PI_END_DATE,
             'RC', ---PI_SOURCE
             NULL, ---PI_SOURCE_CI_SEQ ,
             NULL, ---PI_SOURCE_OFFER_ID,
             gvOFFER_LEVEL,  ---PI_SERVICE_RECEIVER_TYPE,
             NU_CHRG_AMT);
      IF gvERR_CDE<>'0000' THEN
         gvSTEP := SUBSTR('INS_CI:'||gvERR_MSG,1,250);
         RAISE ON_ERR;
      END IF;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END DO_RC_ACTIVE;

   /*************************************************************************
      PROCEDURE : GET_MONTH
      PURPOSE :   計算該起迄日為月數(小數4位)
      DESCRIPTION : 計算該起迄日為月數(小數4位)
      PARAMETER:
            PI_START_DATE         :計算開始日
            PI_END_DATE           :計算截止日
            PO_ACTIVE_DAY         :計算期間ACTIVE天數(扣除停話天數)
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE GET_MONTH(PI_START_DATE       IN   DATE,
                       PI_END_DATE         IN   DATE,
                       PO_MONTH           OUT   NUMBER) IS

      DT_START_DATE               DATE;
      DT_END_DATE                    DATE;
      DT_BILL_FROM_DATE          DATE;
      DT_BILL_END_DATE            DATE;
      NU_MONTH                            NUMBER;
   BEGIN
      if pi_end_date<pi_start_date then
         po_month := 0;
      else
         DT_START_DATE := trunc(PI_START_DATE);
         LOOP
            IF DT_START_DATE=PI_START_DATE THEN
               IF gnFROM_DAY=1 THEN
                  DT_BILL_FROM_DATE := TO_DATE(TO_CHAR(DT_START_DATE,'YYYYMM')||'01','YYYYMMDD');
                  DT_BILL_END_DATE  := TO_DATE(TO_CHAR(DT_START_DATE,'YYYYMM')||TO_CHAR(Last_Day(DT_BILL_FROM_DATE),'DD'),'YYYYMMDD');
               ELSE
                  IF TO_NUMBER(TO_CHAR(DT_START_DATE,'DD'))>=gnFROM_DAY THEN
                     DT_BILL_FROM_DATE := TO_DATE(TO_CHAR(DT_START_DATE,'YYYYMM')||TO_CHAR(gnFROM_DAY),'YYYYMMDD');
                  ELSE
                     DT_BILL_FROM_DATE  := TO_DATE(TO_CHAR(ADD_MONTHS(DT_START_DATE,-1),'YYYYMM')||TO_CHAR(gnFROM_DAY),'YYYYMMDD');
                  END IF;
                  DT_BILL_END_DATE := ADD_MONTHS(DT_BILL_FROM_DATE,1)-1;
               END IF;
            ELSE
               DT_BILL_FROM_DATE := DT_START_DATE;
               DT_BILL_END_DATE  := ADD_MONTHS(DT_BILL_FROM_DATE,1)-1;
            END IF;
            IF trunc(PI_END_DATE)>=DT_BILL_END_DATE THEN
               DT_END_DATE := DT_BILL_END_DATE;
            ELSE
               DT_END_DATE := trunc(PI_END_DATE);
            END IF;
  -- DBMS_OUTPUT.Put_Line('SUB='||gnSUBSCR_ID||',PKG_ID='||gnPKG_ID||',DATE='||TO_CHAR(DT_BILL_FROM_DATE,'YYYYMMDD')||'~'||TO_CHAR(DT_BILL_END_DATE,'YYYYMMDD')||' ,MON='||TO_CHAR((DT_END_DATE-DT_START_DATE+1))||'~'||TO_CHAR(DT_BILL_END_DATE-DT_BILL_FROM_DATE+1));
            NU_MONTH := NVL(NU_MONTH,0)+ ROUND((DT_END_DATE-DT_START_DATE+1)/(DT_BILL_END_DATE-DT_BILL_FROM_DATE+1),6); --2020/06/30 MODIFY FOR MPBS_Migration 修改所有RC月租計算比重ROUND至小數6位
            DT_START_DATE := DT_END_DATE+1;
            IF DT_START_DATE>trunc(PI_END_DATE) THEN
               EXIT;
            END IF;
         END LOOP;
         --PO_MONTH   := NU_MONTH;
         IF gnCYCLE IN ('10','15','20') and gvPAYMENT_TIMING='D' and ADD_MONTHS(trunc(PI_START_DATE),gnFREQUENCY) = trunc(PI_END_DATE)+1 THEN --2023/03/06 MODIFY FOR HGBN預收，收費頻率與起迄時間比對，控制PO_MONTH，避免超收短收現象發生 --2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CYCLE(15,20)
               PO_MONTH   := gnFREQUENCY;
         ELSE
               PO_MONTH   := NU_MONTH;
         END IF;
      end if;
      gvERR_CDE := '0000';
      gvERR_MSG := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         gvErr_Cde := '4999';
         gvErr_Msg := Substr(SQLERRM, 1, 250);
   END GET_MONTH;
   
   /*************************************************************************
      PROCEDURE : GET_MPBL_AMT
      PURPOSE :   計算MPBL該其應收總月數(含補收)及RC可收金額
      DESCRIPTION : 計算MPBL該其應收總月數(含補收)及RC可收金額
      PARAMETER:
            PI_START_DATE         :計算開始日
            PI_END_DATE           :計算截止日
            PI_AMY_QTY            :計費數量
            PI_Tab_PKG_RATES      :PBK多皆費率
            PO_MONTH              :計算總月數(含補收)
            PO_AMT                :RC可收總額
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2020/06/30      FOYA       CREATE FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE GET_MPBL_AMT(PI_START_DATE       IN   DATE,
                          PI_END_DATE         IN   DATE,
                          PI_AMY_QTY          IN   NUMBER,
                          PI_Tab_PKG_RATES    IN   t_PKG_RATES,
                          PO_MONTH           OUT   NUMBER,
                          PO_AMT             OUT   NUMBER) IS

      CURSOR C_CI IS
         SELECT CHRG_FROM_DATE, CHRG_END_DATE, AMOUNT
           FROM FY_TB_BL_BILL_CI
          WHERE CYCLE       =gnCYCLE
            AND CYCLE_MONTH =gnCYCLE_MONTH
            AND ACCT_ID     =gnACCT_ID
            AND ACCT_KEY    =MOD(gnACCT_ID,100)
            AND BILL_SEQ    =gnBILL_SEQ
            AND SOURCE      ='OC'
            AND TXN_ID      =gvTXN_ID;
            
      CURSOR C_SP IS
         SELECT STATUS,
                trunc(STATUS_DATE) status_date,
                TRUNC(EXP_DATE)-1 EXP_DATE,
                PREV_BILLED,
                RECUR_BILLED
           FROM FY_TB_BL_SUB_STATUS_PERIOD
          WHERE SUBSCR_ID = gnSUBSCR_ID
            AND STATUS    = 'A'
            AND STATUS_DATE < trunc(PI_END_DATE)+1 --SR228032 - NPEP 專案 Phase 2.1 add trunc
            AND (EXP_DATE IS NULL OR EXP_DATE>=trunc(PI_START_DATE)+1) --SR228032 - NPEP 專案 Phase 2.1 add trunc
          ORDER BY STATUS_DATE;                   

      NU_MONTH           NUMBER   :=0;
      NU_OC_AMT          NUMBER   :=0;
      NU_TOT_AMT         NUMBER   :=0;
      DT_START_DATE      DATE;
      DT_END_DATE        DATE;
      On_Err             EXCEPTION;
   BEGIN
      PO_MONTH    :=0;
      PO_AMT      :=0;
      gdLAST_DATE := NULL;
      --GET OC補收月數&補收金額
      FOR R_CI IN C_CI LOOP
         IF R_CI.AMOUNT<>0 THEN
            --GET MONTH
            gvSTEP := 'MPBL OC GET_MONTH.ACCT_ID='||TO_CHAR(gnACCT_ID)||',TXN_ID='||TO_CHAR(gvTXN_ID)||':';
            GET_MONTH(TRUNC(R_CI.CHRG_FROM_DATE),
                      TRUNC(R_CI.CHRG_END_DATE),
                      NU_MONTH);
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR(gvSTEP||':'||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;
            IF R_CI.AMOUNT>0 THEN
               PO_MONTH := PO_MONTH + NU_MONTH;
            ELSE
               PO_MONTH := PO_MONTH - NU_MONTH;
            END IF;   
            NU_OC_AMT := NU_OC_AMT + R_CI.AMOUNT;
         END IF;
      END LOOP;      
      --GET RC應收月數(只做破月且非退補收)
      IF gvPRORATE_METHOD='Y' AND gvCI_STEP<>'T' THEN
         FOR R_SP IN C_SP LOOP
            DT_START_DATE := greatest(trunc(PI_START_DATE), R_SP.STATUS_DATE);--取其大
            DT_END_DATE   := least(trunc(PI_END_DATE),NVL(R_SP.EXP_DATE,PI_END_DATE)); --取其小
            --GET MONTH
            gvSTEP := 'MPBL RC GET_MONTH.SUBSCR_ID='||TO_CHAR(gnSUBSCR_ID)||':';
            GET_MONTH(DT_START_DATE,
                      DT_END_DATE,
                      NU_MONTH);
            IF gvERR_CDE<>'0000' THEN
               gvSTEP := SUBSTR(gvSTEP||gvERR_MSG,1,250);
               RAISE ON_ERR;
            END IF;          
            PO_MONTH    := PO_MONTH + NU_MONTH;
            gdLAST_DATE := DT_START_DATE; 
            IF DT_END_DATE=trunc(PI_END_DATE) THEN
               EXIT;
            END IF;
         END LOOP;
      END IF;   
      --本期RC應收金額
      IF gdLAST_DATE IS NOT NULL THEN
         NU_TOT_AMT  := ROUND(PI_Tab_PKG_RATES(1).RATES/gnFREQUENCY*PO_MONTH,gnROUNDING);
         PO_AMT      := NU_TOT_AMT - NU_OC_AMT; 
      ELSE
         NU_TOT_AMT  := NU_OC_AMT;
         PO_AMT      := 0;
      END IF;     
      --DYNAMIC_ATTRIBUTE處理
      IF NU_TOT_AMT>=PI_Tab_PKG_RATES(1).RATES THEN
         gvDYNAMIC_ATTRIBUTE := gvDYNAMIC_ATTRIBUTE||'#Is prorated=false';
      ELSE
         gvDYNAMIC_ATTRIBUTE := gvDYNAMIC_ATTRIBUTE||'#Is prorated=true';
      END IF;           
      gvERR_CDE := '0000';
      gvERR_MSG := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '4999';
         gvErr_Msg := Substr(SQLERRM, 1, 250);
   END GET_MPBL_AMT;
   
   /*************************************************************************
      PROCEDURE : INS_CI
      PURPOSE :   寫計價項目(CI)至 BILL_CI(PKG本身呼叫使用，不被外部呼叫)
      DESCRIPTION : 寫計價項目(CI)至 BILL_CI
      PARAMETER:
            PI_START_DATE              :計算開始日
            PI_END_DATE                :計算截止日
            PI_SOURCE                  :產生時機(UC/OC/RC/DE)
            PI_SOURCE_CI_SEQ           :折扣來源
            PI_SOURCE_OFFER_ID         :來源OFFER 編號
            PI_SERVICE_RECEIVER_TYPE   :費用歸屬階層(S:Subscr/A:ACCT/U:OU)
            PI_AMOUNT                  :金額
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration DYNAMIC_ATTRIBUTE 當PI_SOURCE='RC':從NULL→gvDYNAMIC_ATTRIBUTE
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE INS_CI(PI_START_DATE               IN   DATE,
                    PI_END_DATE                 IN   DATE,
                    PI_SOURCE                   IN   VARCHAR2,
                    PI_SOURCE_CI_SEQ            IN   NUMBER,
                    PI_SOURCE_OFFER_ID          IN   NUMBER,
                    PI_SERVICE_RECEIVER_TYPE    IN   VARCHAR2,
                    PI_AMOUNT                   IN   NUMBER) IS

      CH_CHARGE_TYPE      FY_TB_BL_BILL_CI.CHARGE_TYPE%TYPE;
      CH_REVENUE_CODE     FY_TB_PBK_CHARGE_CODE.REVENUE_CODE%TYPE;
      NU_AMT_DAY          NUMBER  :=NULL;
      NU_BI_SEQ           NUMBER;
      On_Err              EXCEPTION;
   BEGIN
      IF PI_SOURCE='DE' THEN
         CH_CHARGE_TYPE := 'DSC';
      ELSIF PI_AMOUNT>=0 THEN
         CH_CHARGE_TYPE := 'DBT';
      ELSE
         CH_CHARGE_TYPE := 'CRD';
      END IF;
      IF PI_START_DATE IS NOT NULL THEN
         NU_AMT_DAY := PI_END_DATE-PI_START_DATE+1;
      END IF;
      gvSTEP := 'GET REVENUE_CODE.CHARGE_CODE='||gvCHARGE_CODE||':';
      SELECT REVENUE_CODE
        INTO CH_REVENUE_CODE
        FROM FY_TB_PBK_CHARGE_CODE
       WHERE CHARGE_CODE=gvCHARGE_CODE;
      gvSTEP := 'INSERT BILL_CI_'||gvPROC_TYPE||':';
      IF gvPROC_TYPE='T' THEN --測試
         INSERT INTO FY_TB_BL_BILL_CI_TEST
                          (CI_SEQ,
                           ACCT_ID,
                         --  ACCT_KEY,  為虛擬欄位
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
                           UPDATE_USER,
                           TXN_ID,   --2020/06/30 MODIFY FOR MPBS_Migration ADD ITEM
                           BILL_SUBSCR_ID)  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                    SELECT FY_SQ_BL_BILL_CI_TEST.NEXTVAL,
                           gnACCT_ID,
                          -- MOD(gnACCT_ID,100),
                           gnSUBSCR_ID,
                           gnCUST_ID,
                           gnOU_ID,
                           gvCHRG_ID,
                           CH_CHARGE_TYPE,
                           ROUND(PI_AMOUNT,2),
                           gnOFFER_SEQ,
                           gnOFFER_ID,
                           gnOFFER_INSTANCE_ID,
                           gnPKG_ID,
                           gdBILL_DATE-1,   --CHRG_DATE,
                           TRUNC(PI_START_DATE), --CHRG_FROM_DATE,
                           TRUNC(PI_END_DATE),   --CHRG_END_DATE,
                           gvCHARGE_CODE,
                           gnBILL_SEQ,
                           gnCYCLE,
                           gnCYCLE_MONTH,
                           NULL,  --TRX_ID,
                           NULL,  --TX_REASON,
                           NU_AMT_DAY,
                           NULL,  --CDR_QTY,
                           NULL,  --CDR_ORG_AMT
                           PI_SOURCE,
                           PI_SOURCE_CI_SEQ,
                           PI_SOURCE_OFFER_ID,
                           NU_BI_SEQ,
                           PI_SERVICE_RECEIVER_TYPE,
                           NULL,  --CORRECT_SEQ,
                           NULL,  --CORRECT_CI_SEQ,
                           NULL,  --SERVICE_FILTER,
                           NULL,  --POINT_CLASS,
                           NULL,  --CET,
                           gvOVERWRITE,
                           --NULL,  --DYNAMIC_ATTRIBUTE, --2019/11/05 MODIFY SR219716_IOT預繳折扣，END_RSN為CREQ且END_DATE小於BILL_DATE時折扣不給
                           --2020/06/30 MODIFY FOR MPBS_Migration DYNAMIC_ATTRIBUTE 當PI_SOURCE='RC':從NULL→gvDYNAMIC_ATTRIBUTE
                           --DECODE(PI_SOURCE,'DE','SOURCE_CI_SEQ='||PI_SOURCE_CI_SEQ||'#Is RC=true#L9 future expiration date='||TO_CHAR(gnFUTURE_EXP_DATE+1, 'YYYYMMDD')||'#SOC status='||DECODE(gnEND_DATE,NULL,'A','C')||'#Expiration date='||TO_CHAR(gnEND_DATE+1, 'YYYYMMDD'),gvDYNAMIC_ATTRIBUTE) DYNAMIC_ATTRIBUTE,  --2019/11/05 MODIFY SR219716_IOT預繳折扣，END_RSN為CREQ且END_DATE小於BILL_DATE時折扣不給 ----2020/06/30 MODIFY FOR MPBS_Migration DE ADD Is RC=true, L9時間與acct_pkg值相同
                           DECODE(PI_SOURCE,'DE','SOURCE_CI_SEQ='||PI_SOURCE_CI_SEQ||'#Is RC=true#L9 future expiration date='||TO_CHAR(gnFUTURE_EXP_DATE+1, 'YYYYMMDD')||'#SOC status='||DECODE(gnEND_DATE,NULL,'A','C')||'#Expiration date='||TO_CHAR(gnEND_DATE+1, 'YYYYMMDD')||'#gvDIS_UOM_METHOD='||gvDIS_UOM_METHOD||'#QUOTA='||gnQUOTA,gvDYNAMIC_ATTRIBUTE) DYNAMIC_ATTRIBUTE,  --2019/11/05 MODIFY SR219716_IOT預繳折扣，END_RSN為CREQ且END_DATE小於BILL_DATE時折扣不給 ----2020/06/30 MODIFY FOR MPBS_Migration DE ADD Is RC=true, L9時間與acct_pkg值相同 --2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project折扣單位與金額
                           SYSDATE,
                           gvUSER,
                           SYSDATE,
                           gvUSER,
                           DECODE(PI_SOURCE,'RC',gvTXN_ID,NULL),  --2020/06/30 MODIFY FOR MPBS_Migration ADD ITEM
                           gnBILL_SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                      FROM DUAL;
      ELSE
         INSERT INTO FY_TB_BL_BILL_CI
                          (CI_SEQ,
                           ACCT_ID,
                         --  ACCT_KEY, 為虛擬欄位
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
                           UPDATE_USER,
                           TXN_ID,   --2020/06/30 MODIFY FOR MPBS_Migration ADD ITEM
                           BILL_SUBSCR_ID)  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                    SELECT FY_SQ_BL_BILL_CI.NEXTVAL,
                           gnACCT_ID,
                          -- MOD(gnACCT_ID,100),
                           gnSUBSCR_ID,
                           gnCUST_ID,
                           gnOU_ID,
                           gvCHRG_ID,
                           CH_CHARGE_TYPE,
                           ROUND(PI_AMOUNT,2),
                           gnOFFER_SEQ,
                           gnOFFER_ID,
                           gnOFFER_INSTANCE_ID,
                           gnPKG_ID,
                           gdBILL_DATE-1,   --CHRG_DATE,
                           TRUNC(PI_START_DATE), --CHRG_FROM_DATE,
                           TRUNC(PI_END_DATE),   --CHRG_END_DATE,
                           gvCHARGE_CODE,
                           gnBILL_SEQ,
                           gnCYCLE,
                           gnCYCLE_MONTH,
                           NULL,  --TRX_ID,
                           NULL,  --TX_REASON,
                           NU_AMT_DAY,
                           NULL,  --CDR_QTY,
                           NULL,  --CDR_ORG_AMT
                           PI_SOURCE,
                           PI_SOURCE_CI_SEQ,
                           PI_SOURCE_OFFER_ID,
                           NU_BI_SEQ,
                           PI_SERVICE_RECEIVER_TYPE,
                           NULL,  --CORRECT_SEQ,
                           NULL,  --CORRECT_CI_SEQ,
                           NULL,  --SERVICE_FILTER,
                           NULL,  --POINT_CLASS,
                           NULL,  --CET,
                           gvOVERWRITE,
                           --NULL,  --DYNAMIC_ATTRIBUTE, --2019/11/05 MODIFY SR219716_IOT預繳折扣，END_RSN為CREQ且END_DATE小於BILL_DATE時折扣不給
                           --2020/06/30 MODIFY FOR MPBS_Migration DYNAMIC_ATTRIBUTE 當PI_SOURCE='RC':從NULL→gvDYNAMIC_ATTRIBUTE
                           --DECODE(PI_SOURCE,'DE','SOURCE_CI_SEQ='||PI_SOURCE_CI_SEQ||'#Is RC=true#L9 future expiration date='||TO_CHAR(gnFUTURE_EXP_DATE+1, 'YYYYMMDD')||'#SOC status='||DECODE(gnEND_DATE,NULL,'A','C')||'#Expiration date='||TO_CHAR(gnEND_DATE+1, 'YYYYMMDD'),gvDYNAMIC_ATTRIBUTE) DYNAMIC_ATTRIBUTE,  --2019/11/05 MODIFY SR219716_IOT預繳折扣，END_RSN為CREQ且END_DATE小於BILL_DATE時折扣不給 ----2020/06/30 MODIFY FOR MPBS_Migration DE ADD Is RC=true, L9時間與acct_pkg值相同
                           DECODE(PI_SOURCE,'DE','SOURCE_CI_SEQ='||PI_SOURCE_CI_SEQ||'#Is RC=true#L9 future expiration date='||TO_CHAR(gnFUTURE_EXP_DATE+1, 'YYYYMMDD')||'#SOC status='||DECODE(gnEND_DATE,NULL,'A','C')||'#Expiration date='||TO_CHAR(gnEND_DATE+1, 'YYYYMMDD')||'#gvDIS_UOM_METHOD='||gvDIS_UOM_METHOD||'#QUOTA='||gnQUOTA,gvDYNAMIC_ATTRIBUTE) DYNAMIC_ATTRIBUTE,  --2019/11/05 MODIFY SR219716_IOT預繳折扣，END_RSN為CREQ且END_DATE小於BILL_DATE時折扣不給 ----2020/06/30 MODIFY FOR MPBS_Migration DE ADD Is RC=true, L9時間與acct_pkg值相同 --2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project折扣單位與金額                           
                           SYSDATE,
                           gvUSER,
                           SYSDATE,
                           gvUSER,
                           DECODE(PI_SOURCE,'RC',gvTXN_ID,NULL),  --2020/06/30 MODIFY FOR MPBS_Migration ADD ITEM
                           gnBILL_SUBSCR_ID  --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                      FROM DUAL;
      END IF;
    --  COMMIT;
      gvERR_CDE := '0000';
      gvERR_MSG := NULL;
   EXCEPTION
      WHEN on_err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END INS_CI;

END FY_PG_BL_BILL_CI; -- PACKAGE BODY FY_PG_BL_BILL_CI
/