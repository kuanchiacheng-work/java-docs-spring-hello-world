CREATE OR REPLACE PACKAGE BODY Fy_Pg_Bl_Bill_Util IS

   /*************************************************************************
      PROCEDURE : Ins_Process_Err
      PURPOSE :   出帳程式Ins_Process_ERR 處理
      DESCRIPTION : 出帳程式Ins_Process_ERR 處理
      PARAMETER:
            PI_BILL_SEQ           :出帳序號
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)  
            Pi_Acct_Id            :ACCT_ID
            Pi_SUBSCR_Id          :SUBSCR_ID
            PI_PROCESS_NO         :執行序號
            PI_ACCT_GROUP         :客戶類型OR ACCT_LIST.TYPE
            PI_PG_NAME            :執行程式代號
            PI_USER_ID            :執行USER_ID    
            PI_ERR_CDE            :執行ERR_CODE
            PI_ERR_MSG            :執行ERR_MSG     
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/ 
   PROCEDURE Ins_Process_Err(Pi_Bill_Seq   IN Fy_Tb_Bl_Bill_Process_Err.Bill_Seq%TYPE,
                             Pi_Proc_Type  IN Fy_Tb_Bl_Bill_Process_Err.Proc_Type%TYPE,
                             Pi_Acct_Id    IN Fy_Tb_Bl_Bill_Process_Err.Acct_Id%TYPE,
                             Pi_Subscr_Id  IN Fy_Tb_Bl_Bill_Process_Err.Subscr_Id%TYPE,
                             Pi_Process_No IN Fy_Tb_Bl_Bill_Process_Err.Process_No%TYPE,
                             Pi_Acct_Group IN Fy_Tb_Bl_Bill_Process_Err.Acct_Group%TYPE,
                             Pi_Pg_Name    IN Fy_Tb_Bl_Bill_Process_Err.Pg_Name%TYPE,
                             Pi_User_Id    IN Fy_Tb_Bl_Bill_Process_Err.Create_User%TYPE,
                             Pi_Err_Cde    IN Fy_Tb_Bl_Bill_Process_Err.Err_Cde%TYPE,
                             Pi_Err_Msg    IN Fy_Tb_Bl_Bill_Process_Err.Err_Msg%TYPE,
                             Po_Err_Cde    OUT VARCHAR2,
                             Po_Err_Msg    OUT VARCHAR2) IS
                             
      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err EXCEPTION;
      Ch_Proc_Type Fy_Tb_Bl_Bill_Process_Err.Proc_Type%TYPE;
   BEGIN
      IF Pi_Bill_Seq IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入出帳編號';
         RAISE On_Err;
      END IF;
      IF Pi_Proc_Type IS NULL THEN
         Ch_Proc_Type := 'B';
      ELSIF Pi_Proc_Type NOT IN ('B', 'T') THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '輸入出帳類型應為B:正式出帳,T:測試出帳';
         RAISE On_Err;
      ELSE
         Ch_Proc_Type := Pi_Proc_Type;
      END IF;
      IF Pi_Process_No IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入執行序號(若輸入99代表吃名單處理，以ACCT_LIST為主)';
         RAISE On_Err;
      END IF;
      IF Pi_Acct_Id IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入帳戶編號';
         RAISE On_Err;
      END IF;
      IF Pi_Pg_Name IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入執行程式代碼';
         RAISE On_Err;
      END IF;
      IF Pi_User_Id IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入執行人員代碼';
         RAISE On_Err;
      END IF;
      IF Pi_Err_Cde IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入錯誤代碼';
         RAISE On_Err;
      END IF;
      IF Pi_Err_Msg IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入錯誤訊息';
         RAISE On_Err;
      END IF;
      PO_ERR_MSG := 'INSERT Bill_Process_Err.ACCT_ID=:'||TO_CHAR(PI_ACCT_ID);
      INSERT INTO Fy_Tb_Bl_Bill_Process_Err
         (Bill_Seq,
          Proc_Type,
          Acct_Group,
          Process_No,
          Acct_Id,
          Subscr_Id,
          Pg_Name,
          Err_Cde,
          Err_Msg,
          Create_Date,
          Create_User,
          Update_Date,
          Update_User)
      VALUES
         (Pi_Bill_Seq,
          Ch_Proc_Type,
          Pi_Acct_Group,
          Pi_Process_No,
          Pi_Acct_Id,
          Pi_Subscr_Id,
          Pi_Pg_Name,
          Pi_Err_Cde,
          Pi_Err_Msg,
          SYSDATE,
          Pi_User_Id,
          SYSDATE,
          Pi_User_Id);
      IF CH_Proc_Type='B' THEN
         PO_ERR_MSG := 'UPDATE BILL_ACCT.ACCT_ID=:'||TO_CHAR(PI_ACCT_ID);
         UPDATE FY_TB_BL_BILL_ACCT SET BILL_STATUS='RJ'
                                   WHERE BILL_SEQ=PI_BILL_SEQ
                                     AND ACCT_ID =PI_ACCT_ID;                            
      END IF; 
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;                                   
   EXCEPTION
      WHEN On_Err THEN
         NULL;
      WHEN OTHERS THEN
         Po_Err_Cde := '4999';
         Po_Err_Msg := Substr(Po_Err_Msg ||
                              SQLERRM,
                              1,
                              250);
   END Ins_Process_Err;
   
   /*************************************************************************
      PROCEDURE : Ins_Process_LOG
      PURPOSE :   出帳程式Ins_Process_LOG 處理
      DESCRIPTION : 出帳程式Ins_Process_LOG 處理
      PARAMETER:
            PI_STATUS             :出帳狀態CI/BI/MAST/CN
            PI_BILL_SEQ           :出帳序號
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)  
            PI_PROCESS_NO         :執行序號
            PI_ACCT_GROUP         :客戶類型OR ACCT_LIST.TYPE
            PI_USER_ID            :執行USER_ID         
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/   
   PROCEDURE Ins_Process_LOG(PI_STATUS     IN FY_TB_BL_BILL_PROCESS_LOG.STATUS%TYPE,
                             Pi_Bill_Seq   IN Fy_Tb_Bl_Bill_Process_Err.Bill_Seq%TYPE,
                             Pi_Proc_Type  IN Fy_Tb_Bl_Bill_Process_Err.Proc_Type%TYPE,
                             Pi_Process_No IN Fy_Tb_Bl_Bill_Process_Err.Process_No%TYPE,
                             Pi_Acct_Group IN Fy_Tb_Bl_Bill_Process_Err.Acct_Group%TYPE,
                             Pi_User_Id    IN Fy_Tb_Bl_Bill_Process_Err.Create_User%TYPE,
                             Po_Err_Cde    OUT VARCHAR2,
                             Po_Err_Msg    OUT VARCHAR2) IS
                             
      CURSOR C_C1 IS 
         SELECT END_TIME, STATUS,
                DECODE(STATUS,'CL','CI',
                              'CI','BI',
                              'BI','MAST',
                              'MAST','CN',
                              'CN','END',
                              STATUS) NEXT_STATUS                          
           FROM FY_TB_BL_BILL_PROCESS_LOG BL 
          WHERE BILL_SEQ  = PI_BILL_SEQ
            AND PROCESS_NO= PI_PROCESS_NO
            AND ACCT_GROUP= PI_ACCT_GROUP
            AND PROC_TYPE = PI_PROC_TYPE
            AND BEGIN_TIME= (SELECT MAX(BEGIN_TIME) from FY_TB_BL_BILL_PROCESS_LOG 
                                               WHERE BILL_SEQ   = BL.BILL_SEQ
                                                 AND PROCESS_NO = BL.PROCESS_NO
                                                 AND ACCT_GROUP= BL.ACCT_GROUP
                                                 AND PROC_TYPE = BL.PROC_TYPE)
         ORDER BY DECODE('CI',1,'BI',2,'MAST',3,4) DESC ;
      R_C1            C_C1%ROWTYPE;
                                                 
      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err           EXCEPTION;
      DT_END_DATE      DATE;
      CH_STATUS        FY_TB_BL_BILL_PROCESS_LOG.STATUS%TYPE;
      CH_NEXT_STATUS   FY_TB_BL_BILL_PROCESS_LOG.STATUS%TYPE;
      Ch_Proc_Type     Fy_Tb_Bl_Bill_Process_LOG.Proc_Type%TYPE;
      Nu_Cnt           NUMBER := 0;
      CH_STEP          VARCHAR2(300);
   BEGIN
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
      IF PI_STATUS NOT IN ('CL','CI','BI','MAST','CN') THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '輸入STATUS類型應為CL/CI/BI/MAST/CN';
         RAISE On_Err;
      END IF;
      IF Pi_Bill_Seq IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入出帳編號';
         RAISE On_Err;
      END IF;
      IF Pi_Proc_Type IS NULL THEN
         Ch_Proc_Type := 'B';
      ELSIF Pi_Proc_Type NOT IN ('B', 'T') THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '輸入出帳類型應為B:正式出帳,T:測試出帳';
         RAISE On_Err;
      ELSIF PI_STATUS='CN' AND PI_PROC_TYPE<>'B' THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := 'CONFIRM輸入出帳類型應為B:正式出帳';
         RAISE On_Err;
      ELSE
         Ch_Proc_Type := Pi_Proc_Type;
      END IF;
      IF Pi_Process_No IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入執行序號(若輸入999代表吃名單處理，以ACCT_LIST為主)';
         RAISE On_Err;
      END IF;
      IF Pi_User_Id IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入執行人員代碼';
         RAISE On_Err;
      END IF;
      ----CHECK PROCESS_NO  
      OPEN C_C1;
      FETCH C_C1 INTO R_C1;
      IF C_C1%NOTFOUND THEN
         IF PI_STATUS NOT IN ('CL','CI') THEN
            Po_Err_Cde := '4003';
            Po_Err_Msg  := CH_STEP||',狀態<>(CL,CI),無法執行'; 
            RAISE ON_ERR;
         END IF;
      ELSE
         IF R_C1.END_TIME IS NULL THEN
            Po_Err_Cde := '4002';
            Po_Err_Msg  := CH_STEP||'有其他JOB正在執行'; 
            RAISE ON_ERR;
         ELSIF R_C1.STATUS =PI_STATUS THEN
            Po_Err_Cde := '4003';
            Po_Err_Msg  := CH_STEP||',已執行完畢'; 
            RAISE ON_ERR;
         ELSIF R_C1.NEXT_STATUS<>PI_STATUS THEN
            Po_Err_Cde := '4003';
            Po_Err_Msg  := CH_STEP||',非下一個狀態無法執行'; 
            RAISE ON_ERR;
         END IF; 
      END IF;
      CLOSE C_C1;  

      CH_STEP := 'INSERT '||CH_STEP;
      INSERT INTO FY_TB_BL_BILL_PROCESS_LOG
                      (BILL_SEQ,
                       PROCESS_NO,
                       ACCT_GROUP,
                       PROC_TYPE,
                       STATUS,
                       FILE_REPLY,
                       BEGIN_TIME,
                       END_TIME,
                       CURRECT_ACCT_ID,
                       COUNT,
                       CREATE_DATE,
                       CREATE_USER,
                       UPDATE_DATE,
                       UPDATE_USER)
                  VALUES
                      (PI_BILL_SEQ,
                       PI_PROCESS_NO,
                       PI_ACCT_GROUP,
                       PI_PROC_TYPE,
                       PI_STATUS,
                       NULL,  ---FILE_REPLY,
                       SYSDATE, ---BEGIN_TIME,
                       NULL,    ---END_TIME,
                       NULL,    ---CURRECT_ACCT_ID,
                       NULL,
                       SYSDATE,
                       PI_USER_ID,
                       SYSDATE,
                       PI_USER_ID);
      COMMIT;                  
   EXCEPTION
      WHEN On_Err THEN
         NULL;
      WHEN OTHERS THEN
         Po_Err_Cde := '4999';
         Po_Err_Msg := Substr(CH_STEP || SQLERRM, 1, 250);
   END Ins_Process_LOG;
   
   /*************************************************************************
      PROCEDURE : MARKET_PKG
      PURPOSE :   MARKET_MOVE不同CYCLE ACCT_PKG 處理
      DESCRIPTION : MARKET_MOVE不同CYCLE ACCT_PKG 處理
      PARAMETER:
            PI_CYCLE              :出帳CYCLE
            PI_ACCT_PKG_SEQ       :ACCT_PKG_SEQ
            PI_TRANS_DATE         :移轉日期  
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)
            PI_BILL_SEQ           :出帳序號
            PI_USER               :USER_ID    
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理 ADD參數PROC_TYPE,BILL_SEQ
   **************************************************************************/
   PROCEDURE MARKET_PKG(PI_CYCLE            IN   NUMBER,
                        PI_ACCT_PKG_SEQ     IN   NUMBER,
                        PI_TRANS_DATE       IN   DATE,  
                        PI_PROC_TYPE        IN   VARCHAR2 DEFAULT 'B',  --2021/06/15 MODIFY FOR 小額預繳處理
                        PI_BILL_SEQ         IN   NUMBER,      --2021/06/15 MODIFY FOR 小額預繳處理   
                        PI_USER             IN   VARCHAR2,
                        PO_ERR_CDE         OUT   VARCHAR2,
                        PO_ERR_MSG         OUT   VARCHAR2) IS
                             
      CURSOR C_PKG(iACCT_PKG_SEQ NUMBER) IS
         SELECT PKG.ACCT_ID, 
                PKG.ACCT_KEY,     
                PKG.ACCT_PKG_SEQ,  
                NVL(PKG.TOTAL_DISC_AMT,0) TOTAL_DISC_AMT,
                PKG.VALIDITY_PERIOD,
                PKG.CUR_BAL_QTY CUR_BAL_QTY,
                PKG.CUR_USE_QTY CUR_USE_QTY,
                PKG.CUR_QTY CUR_QTY,
                PKG.TRANS_IN_DATE,
                PKG.TRANS_IN_QTY,
                PKG.TRANS_OUT_DATE,
                PKG.TRANS_OUT_QTY,
                PKG.OFFER_LEVEL_ID,
                PKG.PKG_ID,
                PKG.FIRST_BILL_DATE,
                PKG.INIT_PKG_QTY,
                PKG.STATUS,
                AT.CYCLE,
                --2021/06/15 MODIFY FOR 小額預繳處理 ADD 多CYCL繼承處理
                PKG.BILL_QTY,      
                PKG.BILL_USE_QTY,  
                PKG.BILL_BAL_QTY,  
                PKG.BILL_DISC_AMT, 
                PKG.RECUR_SEQ,
                PKG.TEST_QTY,
                PKG.TEST_USE_QTY,
                PKG.TEST_BAL_QTY,
                PKG.TEST_DISC_AMT,
                PKG.TEST_TRANS_IN_QTY,
                PKG.TEST_TRANS_IN_DATE,
                PKG.TEST_TRANS_OUT_QTY,
                PKG.TEST_TRANS_OUT_DATE,
                PKG.TEST_RECUR_SEQ
           FROM (SELECT * FROM FY_TB_BL_ACCT_PKG
                    START WITH ACCT_PKG_SEQ  =iACCT_PKG_SEQ
                  CONNECT BY PRIOR PRE_PKG_SEQ=ACCT_PKG_SEQ) PKG,
                FY_TB_BL_ACCOUNT AT                           
          WHERE AT.ACCT_ID=PKG.ACCT_ID
            -- AND PKG.TRANS_OUT_DATE IS NULL --2021/06/15 MODIFY FOR 小額預繳處理 移至程式處理
          START WITH PRE_PKG_SEQ IS NULL 
        CONNECT BY PRIOR ACCT_PKG_SEQ=PRE_PKG_SEQ; 
        
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
         
      PRAGMA AUTONOMOUS_TRANSACTION;
      NU_CNT             NUMBER  :=0;
      NU_CYCLE           FY_TB_BL_CYCLE.CYCLE%TYPE;
      NU_PRE_ACCT_ID     FY_TB_BL_ACCOUNT.ACCT_ID%TYPE;
      NU_VALIDITY_PERIOD NUMBER;
      NU_TOTAL_DISC_AMT  NUMBER;
      NU_TRANS_IN_QTY    NUMBER;
      NU_TRANS_OUT_QTY   NUMBER;
      NU_INIT_PKG_QTY    NUMBER;
      CH_FIRST_FLAG      VARCHAR2(1);
      CH_STEP            VARCHAR2(250);
      On_Err             EXCEPTION;
      CH_MUTI_CYCLE      VARCHAR2(1);  --2021/06/15 MODIFY FOR 小額預繳處理 ADD 同CYCLE處理
   BEGIN  
      NU_TRANS_IN_QTY := NULL;  
      CH_FIRST_FLAG   := 'Y'; 
      CH_MUTI_CYCLE   := 'N';               
      ----MARTET MOVE ACCT_PKG處理
      FOR R_PKG IN C_PKG(PI_ACCT_PKG_SEQ) LOOP  
       IF R_PKG.TRANS_OUT_DATE IS NULL THEN 
         IF NU_TRANS_IN_QTY IS NOT NULL THEN
            R_PKG.TRANS_IN_QTY    := NU_TRANS_IN_QTY;
            R_PKG.TRANS_IN_DATE   := SYSDATE; --2021/06/15 MODIFY FOR 小額預繳處理 PI_TRANS_DATE;
            R_PKG.VALIDITY_PERIOD := NU_VALIDITY_PERIOD;
            R_PKG.TOTAL_DISC_AMT  := NU_TOTAL_DISC_AMT;
            R_PKG.INIT_PKG_QTY    := NU_TRANS_IN_QTY;
            R_PKG.CUR_QTY         := NU_TRANS_IN_QTY;
            R_PKG.CUR_USE_QTY     := 0;
            R_PKG.CUR_BAL_QTY     := NU_TRANS_IN_QTY;  --2021/06/15 MODIFY FOR 小額預繳處理 ADD 同CYCLE處理
         END IF; 
         NU_TRANS_OUT_QTY:= NULL; 
         --非最後一筆
         IF R_PKG.ACCT_PKG_SEQ<>PI_ACCT_PKG_SEQ AND R_PKG.TRANS_OUT_DATE IS NULL THEN  
            IF R_PKG.CYCLE=PI_CYCLE THEN 
               --2021/06/15 MODIFY FOR 小額預繳處理 ADD 同CYCLE處理
               IF (PI_PROC_TYPE='B' AND PI_BILL_SEQ<>R_PKG.RECUR_SEQ) OR
                  (PI_PROC_TYPE<>'B' AND PI_BILL_SEQ<>R_PKG.TEST_RECUR_SEQ) THEN
                  PO_ERR_CDE  := 'D001'; 
                  CH_STEP     := 'MARKET MOVE同CYCLE.PRE_SUB_ID='||TO_CHAR(R_PKG.OFFER_LEVEL_ID)||'CYCLE交差無法執行';
                  RAISE ON_ERR;
               END IF;
               IF PI_PROC_TYPE='B' THEN
                  NU_TRANS_OUT_QTY    := R_PKG.BILL_BAL_QTY;
                  R_PKG.TRANS_OUT_QTY := NU_TRANS_OUT_QTY*-1;
                  R_PKG.TRANS_OUT_DATE:= SYSDATE; --2021/06/15 MODIFY FOR 小額預繳處理 PI_TRANS_DATE;
                  R_PKG.BILL_BAL_QTY  := 0;
               ELSE
                  NU_TRANS_OUT_QTY         := R_PKG.TEST_BAL_QTY;
                  R_PKG.TEST_TRANS_OUT_QTY := NU_TRANS_OUT_QTY*-1;
                  R_PKG.TEST_TRANS_OUT_DATE:= SYSDATE; --2021/06/15 MODIFY FOR 小額預繳處理 PI_TRANS_DATE;
                  R_PKG.TEST_BAL_QTY       := 0;
               END IF;
               CH_MUTI_CYCLE := 'Y';
            ELSE 
               --不同CYCLE是否尚未出帳結束    
               SELECT COUNT(1)
                 INTO NU_CNT
                 FROM FY_TB_BL_BILL_CNTRL A,
                      FY_TB_BL_BILL_ACCT B
                WHERE A.CYCLE=R_PKG.CYCLE
                  AND A.STATUS<>'CN'
                  AND B.BILL_SEQ   =A.BILL_SEQ
                  AND B.CYCLE      =A.CYCLE
                  AND B.CYCLE_MONTH=A.CYCLE_MONTH
                  AND B.ACCT_KEY   =MOD(R_PKG.ACCT_ID,100)
                  AND B.ACCT_ID    =R_PKG.ACCT_ID
                  AND B.BILL_STATUS<>'CN';          
               IF NU_CNT>0 THEN
                  PO_ERR_CDE  := 'D001'; 
                  CH_STEP     := 'MARKET MOVE不同CYCLE.PRE_ACCT_ID='||TO_CHAR(R_PKG.ACCT_ID)||'尚未出帳結束';
                  RAISE ON_ERR;
               END IF;
   DBMS_OUTPUT.Put_Line('PKG_SEQ='||TO_CHAR(R_PKG.ACCT_PKG_SEQ)||
                         ',FIRST_DATE='||TO_CHAR(R_PKG.FIRST_BILL_DATE,'YYYY/MM/DD')||
                         ',CUR_BAL_QTY='||TO_CHAR(R_PKG.CUR_BAL_QTY));            
               IF CH_FIRST_FLAG='Y' AND R_PKG.FIRST_BILL_DATE IS NULL AND R_PKG.CUR_BAL_QTY IS NULL THEN
                  --GET DISCOUNT_PACKAGE 
                  OPEN C_PP(R_PKG.PKG_ID);
                  FETCH C_PP INTO R_PP;
                  IF C_PP%NOTFOUND THEN
                     PO_ERR_CDE  := 'D001'; 
                     CH_STEP     := 'GET DISCOUNT_PACKAGE.PKG_ID='||TO_CHAR(R_PKG.PKG_ID)||' NOT FOUND'; 
                     RAISE ON_ERR;
                  END IF;
                  CLOSE C_PP; 
                  NU_TRANS_OUT_QTY    := R_PP.QUOTA;
                  R_PKG.INIT_PKG_QTY  := R_PP.QUOTA;
                  R_PKG.TOTAL_DISC_AMT:= 0;
                  R_PKG.CUR_QTY       := R_PP.QUOTA;
                  R_PKG.CUR_USE_QTY   := 0;
                  --VALIDITY_PERIOD
                  IF R_PP.VALIDITY_METHOD='T' THEN
                     R_PKG.VALIDITY_PERIOD := R_PP.VALIDITY_PERIOD;
                  END IF;   
                  CH_FIRST_FLAG       := 'N';
               ELSE   
                  NU_TRANS_OUT_QTY    := R_PKG.CUR_QTY-R_PKG.CUR_USE_QTY;
               END IF;  
               R_PKG.CUR_BAL_QTY   := 0;  --2021/06/15 MODIFY FOR 小額預繳處理
               R_PKG.TRANS_OUT_QTY := NU_TRANS_OUT_QTY*-1;
               R_PKG.TRANS_OUT_DATE:= SYSDATE; --2021/06/15 MODIFY FOR 小額預繳處理 PI_TRANS_DATE;
               R_PKG.STATUS        := 'CLOSE'; 
            END IF; 
         END IF; --非最後一筆
    DBMS_OUTPUT.Put_Line('PKG_SEQ='||TO_CHAR(R_PKG.ACCT_PKG_SEQ)||
                         ' ,IN='||TO_CHAR(NU_TRANS_IN_QTY)||
                         ' ,OUT='||TO_CHAR(NU_TRANS_OUT_QTY));    
         IF NU_TRANS_IN_QTY IS NOT NULL OR NU_TRANS_OUT_QTY IS NOT NULL THEN  
            --2021/06/15 MODIFY FOR 小額預繳處理
            IF CH_MUTI_CYCLE='Y' THEN  
               SELECT DECODE(PI_PROC_TYPE,'T',NU_TRANS_IN_QTY,R_PKG.TEST_TRANS_IN_QTY),
                      DECODE(PI_PROC_TYPE,'T',SYSDATE,R_PKG.TEST_TRANS_IN_DATE) --2021/06/15 MODIFY FOR 小額預繳處理 由PI_TRAN_DATE改為SYSDATE
                    INTO R_PKG.TEST_TRANS_IN_QTY, R_PKG.TEST_TRANS_IN_DATE
                    FROM DUAL;
            END IF;  --2021/06/15 MODIFY FOR 小額預繳處理
            CH_STEP := 'UPDATE ACCT_PKG.ACCT_ID='||TO_CHAR(R_PKG.ACCT_ID)||',ACCT_PKG_SEQ='||TO_CHAR(R_PKG.ACCT_PKG_SEQ)||':';
            UPDATE FY_TB_BL_ACCT_PKG SET CUR_BAL_QTY    =R_PKG.CUR_BAL_QTY,  --2021/06/15 MODIFY FOR 小額預繳處理
                                         CUR_QTY        =R_PKG.CUR_QTY,
                                         CUR_USE_QTY    =R_PKG.CUR_USE_QTY,
                                         INIT_PKG_QTY   =R_PKG.INIT_PKG_QTY,
                                         TRANS_OUT_QTY  =R_PKG.TRANS_OUT_QTY,
                                         TRANS_OUT_DATE =R_PKG.TRANS_OUT_DATE,
                                         TRANS_IN_QTY   =R_PKG.TRANS_IN_QTY,
                                         TRANS_IN_DATE  =R_PKG.TRANS_IN_DATE, 
                                    TEST_TRANS_OUT_QTY  =R_PKG.TEST_TRANS_OUT_QTY,  --2021/06/15 MODIFY FOR 小額預繳處理
                                    TEST_TRANS_OUT_DATE =R_PKG.TEST_TRANS_OUT_DATE, --2021/06/15 MODIFY FOR 小額預繳處理
                                    TEST_TRANS_IN_QTY   =R_PKG.TEST_TRANS_IN_QTY,   --2021/06/15 MODIFY FOR 小額預繳處理
                                    TEST_TRANS_IN_DATE  =R_PKG.TEST_TRANS_IN_DATE,  --2021/06/15 MODIFY FOR 小額預繳處理
                                          BILL_BAL_QTY  =R_PKG.BILL_BAL_QTY,        --2021/06/15 MODIFY FOR 小額預繳處理
                                          TEST_BAL_QTY  =R_PKG.TEST_BAL_QTY,        --2021/06/15 MODIFY FOR 小額預繳處理
                                         VALIDITY_PERIOD=R_PKG.VALIDITY_PERIOD,
                                         TOTAL_DISC_AMT =R_PKG.TOTAL_DISC_AMT, 
                                         STATUS         =R_PKG.STATUS,
                                         UPDATE_DATE    =SYSDATE,
                                         UPDATE_USER    =PI_USER
                                     WHERE ACCT_PKG_SEQ=R_PKG.ACCT_PKG_SEQ
                                       AND ACCT_KEY    =R_PKG.ACCT_KEY; 
         END IF; --R_PKG.CYCLE<>PI_CYCLE  
         NU_TRANS_IN_QTY   := NU_TRANS_OUT_QTY;  
         NU_VALIDITY_PERIOD:= R_PKG.VALIDITY_PERIOD;
         NU_TOTAL_DISC_AMT := R_PKG.TOTAL_DISC_AMT;
         NU_INIT_PKG_QTY   := R_PKG.INIT_PKG_QTY;
         IF R_PKG.ACCT_PKG_SEQ=PI_ACCT_PKG_SEQ THEN
            EXIT;
         END IF; 
       END IF; --2021/06/15 MODIFY FOR 小額預繳處理
      END LOOP;  
      COMMIT;                  
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN on_err THEN
         ROLLBACK;
         Po_Err_Msg := CH_STEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(CH_STEP || SQLERRM, 1, 250);
   END MARKET_PKG;
   
   /*************************************************************************
      PROCEDURE : QUERY_ACCT_PKG
      PURPOSE :   ACCT_PKG QUERY 處理
      DESCRIPTION : ACCT_PKG QUERY 處理
      PARAMETER:
            PI_ACCT_ID            :出帳帳戶   
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE QUERY_ACCT_PKG(PI_ACCT_ID            IN   NUMBER,
                            PO_ERR_CDE           OUT   VARCHAR2,
                            PO_ERR_MSG           OUT   VARCHAR2) IS     

      CURSOR C1(iDT_LBC_DATE DATE) IS
         SELECT DISTINCT
                A.ACCT_ID,
                a.offer_level,
                a.offer_level_id,
                a.offer_seq,
                a.offer_id,
                b.offer_name        
           FROM fy_tb_bl_acct_pkg a,
                fy_tb_pbk_offer b
          WHERE a.acct_id  =pi_acct_id
            and a.acct_key =mod(pi_acct_id,100)
            and (a.end_date is null OR A.END_DATE>iDT_LBC_DATE)
            and b.offer_id =a.offer_id;             
      
      DT_LBC_DATE        DATE;
      CH_ACCT_ID         VARCHAR2(18)  :='ACCT_ID';
      CH_OFFER_LEVEL     VARCHAR2(18)  :='OFFER_LEVEL';
      CH_OFFER_LEVEL_ID  VARCHAR2(18)  :='OFFER_LEVEL_ID';
      CH_OFFER_SEQ       VARCHAR2(18)  :='OFFER_SEQ';
      CH_OFFER_NAME      FY_TB_PBK_OFFER.OFFER_NAME%TYPE  :='OFFER_NAME';
      On_Err             EXCEPTION;
   BEGIN
      SELECT TRUNC(LBC_DATE)
        INTO DT_LBC_DATE
        FROM FY_TB_BL_ACCOUNT A,
             FY_TB_BL_CYCLE C
       WHERE A.ACCT_iD=PI_ACCT_ID
         AND C.CYCLE  =A.CYCLE; 
      --
      DBMS_OUTPUT.Put_Line(RPAD(CH_ACCT_ID,18,' ')||RPAD(CH_OFFER_LEVEL,18,' ')||RPAD(CH_OFFER_LEVEL_ID,18,' ')||
                           RPAD(CH_OFFER_SEQ,18,' ')||CH_OFFER_NAME);
      FOR R1 IN C1(DT_LBC_DATE) LOOP 
         CH_ACCT_ID     := R1.ACCT_ID;
         CH_OFFER_LEVEL := R1.OFFER_LEVEL;
         CH_OFFER_LEVEL_ID := R1.OFFER_LEVEL_ID;
         CH_OFFER_SEQ   := R1.OFFER_SEQ;
         CH_OFFER_NAME  := R1.OFFER_NAME;  
         DBMS_OUTPUT.Put_Line(RPAD(CH_ACCT_ID,18,' ')||RPAD(CH_OFFER_LEVEL,18,' ')||RPAD(CH_OFFER_LEVEL_ID,18,' ')||
                           RPAD(CH_OFFER_SEQ,18,' ')||CH_OFFER_NAME);
      END LOOP;              
      Po_Err_Cde := '0000';
      Po_Err_Msg := null;      
   EXCEPTION
      WHEN OTHERS THEN
         Po_Err_Cde := '8999';
         Po_Err_Msg := Substr('CALL query ERROR:' || SQLERRM, 1, 250);
   END QUERY_ACCT_PKG;                              
    
   /*************************************************************************
      PROCEDURE : DO_RECUR
      PURPOSE :   計算用戶月租費
      DESCRIPTION : 計算用戶月租費
      PARAMETER:
            PI_ACCT_ID            :ACCT_ID
            PI_BILL_SEQ           :出帳序號
            PI_CYCLE              :出帳週期
            PI_CYCLE_MONTH        :出帳月份  
            PI_BILL_FROM_DATE     :出帳起始日
            PI_BILL_END_DATE      :出帳截止日
            PI_BILL_DATE          :出帳日       
            PI_FROM_DAY           :FROM_DAY  
            PI_END_DATE           :計費截止日
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE DO_RECUR(PI_ACCT_ID        IN   NUMBER,
                      PI_BILL_SEQ       IN   NUMBER,
                      PI_CYCLE          IN   NUMBER,
                      PI_CYCLE_MONTH    IN   NUMBER,
                      PI_BILL_FROM_DATE IN   DATE,
                      PI_BILL_END_DATE  IN   DATE,
                      PI_BILL_DATE      IN   DATE,
                      PI_FROM_DAY       IN   NUMBER,
                      PI_END_DATE       IN   DATE,
                      PO_ERR_CDE       OUT   VARCHAR2,
                      PO_ERR_MSG       OUT   VARCHAR2) IS
      
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
                NVL(TRUNC(AP.END_DATE)-1,PI_END_DATE) END_DATE,
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
            AND AP.PKG_TYPE_DTL='RC'
            AND AP.EFF_DATE<>NVL(AP.END_DATE,AP.EFF_DATE+1)
            AND AP.EFF_DATE<gdBILL_DATE
            AND NVL(AP.END_DATE, gdBILL_FROM_DATE+1)>gdBILL_FROM_DATE
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
         SELECT SUBSTR (SUBSTR (PARAM_NAME, 1, INSTR(PARAM_NAME,'_',-1) -1),
                           INSTR (SUBSTR (PARAM_NAME,1, INSTR(PARAM_NAME,'_',-1) -1),'_') +1) PARAM_NAME,
                TO_NUMBER(PARAM_VALUE) PARAM_VALUE,
                EFF_DATE,
                TRUNC(END_DATE)-1 END_DATE
           FROM FY_TB_BL_OFFER_PARAM A
          WHERE ACCT_ID   = gnACCT_ID
            AND OFFER_SEQ = iOFFER_SEQ
            AND EFF_DATE  < gdBILL_DATE   
            AND NVL(END_DATE,gdBILL_END_DATE) > gdBILL_FROM_DATE
            AND (PARAM_NAME='DEVICE_COUNT' OR  --服務數量
                 (END_DATE IS NULL OR TRUNC(END_DATE) IN (SELECT TRUNC(END_DATE)
                                                            FROM FY_TB_BL_ACCT_PKG
                                                           WHERE ACCT_ID  =A.ACCT_ID
                                                             AND ACCT_KEY =MOD(A.ACCT_ID,100)
                                                             AND OFFER_SEQ=A.OFFER_SEQ)
                 )) 
            AND OVERWRITE_TYPE IN ('RC','BL') --2020/06/09 MODIFY SR226548_遠傳(遠欣)企業客服新服務系統建置
            AND ((iCNT=1 AND PARAM_NAME NOT IN ('DEVICE_COUNT','InsuranceID')) OR  --服務數量 --2020/06/09 MODIFY SR226548_遠傳(遠欣)企業客服新服務系統建置
                 (iCNT=2 AND PARAM_NAME='DEVICE_COUNT'))
          ORDER BY PARAM_NAME,EFF_DATE ;                              
     
      Tab_PKG_RATES      FY_PG_BL_BILL_CI.t_PKG_RATES;
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
   BEGIN
      --設定一些全域的變數
      gnBILL_SEQ       := PI_BILL_SEQ;
      gnACCT_ID        := PI_ACCT_ID;
      gnCYCLE          := PI_CYCLE;
      gnCYCLE_MONTH    := PI_CYCLE_MONTH;
      gdBILL_FROM_DATE := PI_BILL_FROM_DATE;
      gdBILL_END_DATE  := PI_BILL_END_DATE;
      gdBILL_DATE      := PI_BILL_DATE;
      gnFROM_DAY       := PI_FROM_DAY;
      gvUSER           :='TST_BILL';
      NU_PKG_ID        := NULL;
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
         gnCUST_ID           := R_RC.CUST_ID;
         --CHECK SUBSCR
         IF R_RC.OFFER_LEVEL='S' THEN
            gnSUBSCR_ID := R_RC.OFFER_LEVEL_ID;
            gnOU_ID     := NULL;
         ELSE
            gnSUBSCR_ID := NULL;
            gnOU_ID     := R_RC.OFFER_LEVEL_ID;
         END IF; 
         --GET RC_PACKAGE             
         IF NU_PKG_ID IS NULL OR NU_PKG_ID<>R_RC.PKG_ID THEN
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
-- DBMS_OUTPUT.Put_Line('STEP='||gvCI_STEP||' ,月租PKG_SEQ='||TO_CHAR(R_RC.ACCT_PKG_SEQ)||' CUR_BILLED='||TO_CHAR(R_RC.CUR_BILLED,'YYYYMMDD')||',END_DATE='||TO_CHAR(R_RC.END_DATE,'YYYYMMDD'));            
         --計費日期處理(END_DATE算_已做-1處理)                         
         IF gvPAYMENT_TIMING='D' THEN --預收 
            IF R_RC.CUR_BILLED>gdBILL_FROM_DATE THEN
               IF R_RC.END_DATE<R_RC.CUR_BILLED OR 
                  R_RC.FUTURE_EXP_DATE<R_RC.CUR_BILLED OR
                  R_RC.SYS_END_DATE<R_RC.CUR_BILLED THEN  
                  DT_CI_FROM_DATE := least(NVL(R_RC.END_DATE,NVL(R_RC.FUTURE_EXP_DATE,R_RC.SYS_END_DATE)),
                                           NVL(R_RC.FUTURE_EXP_DATE,NVL(R_RC.END_DATE,R_RC.SYS_END_DATE)),
                                           NVL(R_RC.SYS_END_DATE,NVL(R_RC.END_DATE,R_RC.FUTURE_EXP_DATE))
                                           )+1; ---取其小
                  DT_CI_END_DATE  := R_RC.CUR_BILLED;
                  gvCI_STEP :='T'; ---- 補退費                    
               END IF;
            ELSE
               IF R_RC.CUR_BILLED IS NOT NULL THEN
                  DT_CI_FROM_DATE :=R_RC.CUR_BILLED+1;
               ELSE   
                  DT_CI_FROM_DATE :=R_RC.EFF_DATE;
               END IF;   
               DT_CI_END_DATE  :=least(NVL(R_RC.END_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                       NVL(R_RC.FUTURE_EXP_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                       NVL(R_RC.SYS_END_DATE,ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)),
                                       ADD_MONTHS(gdBILL_END_DATE,gnFREQUENCY)); ---取其小    
               gvCI_STEP :='R'; ---- 預收   
            END IF;   
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
  --  DBMS_OUTPUT.Put_Line('STEP='||gvCI_STEP||' ,月租PKG_SEQ='||TO_CHAR(R_RC.ACCT_PKG_SEQ)||' FROM_DATE='||TO_CHAR(DT_CI_FROM_DATE,'YYYYMMDD')||',END_DATE='||TO_CHAR(DT_CI_END_DATE,'YYYYMMDD'));            
         --需產生計費資料    
         IF gvCI_STEP IS NOT NULL THEN --11.14 AND gvCI_STEP <>'T' THEN  --不做補退          
            --OVERWRITE OFFER_PARAM
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
            IF gvQTY_CONDITION='D' AND gvPRICING_TYPE<>'F' THEN --服務數量 
               DT_CTRL_FROM_DATE := DT_CI_FROM_DATE; 
               DT_CTRL_END_DATE  := DT_CI_END_DATE;
               FOR R_OP IN C_OP(gnOFFER_SEQ, 2) LOOP  
                  NU_AMT_QTY := R_OP.PARAM_VALUE;
                  DT_CTRL_FROM_DATE := greatest(DT_CTRL_FROM_DATE,R_OP.EFF_DATE);
                  DT_CTRL_END_DATE  := least(DT_CI_END_DATE,NVL(R_OP.END_DATE,DT_CI_END_DATE)); 
                  gvSTEP := 'OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||'.GET_ACTIVE_DAY:';            
                  GET_ACTIVE_DAY('RC',
                                 DT_CTRL_FROM_DATE,
                                 DT_CTRL_END_DATE,
                                 NU_AMT_QTY ,
                                 Tab_PKG_RATES,
                                 NU_ACTIVE_DAY);
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
               IF gvPRICING_TYPE='F' AND R_PP.RATE1=0 THEN --RC=0
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
                  gvSTEP := 'OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||'.GET_ACTIVE_DAY:'; 
                  GET_ACTIVE_DAY('RC',
                                 DT_CI_FROM_DATE,
                                 DT_CI_END_DATE,
                                 NU_AMT_QTY ,
                                 Tab_PKG_RATES,
                                 NU_ACTIVE_DAY);
                  IF gvERR_CDE<>'0000' THEN
                     gvSTEP := SUBSTR('OFFER_SEQ='||TO_CHAR(gnOFFER_SEQ)||'.GET_ACTIVE_DAY:'||gvERR_MSG,1,250);
                     RAISE ON_ERR;
                  END IF;
               END IF;                          
            END IF;  --R_DS.QTY_CONDITION     
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
   **************************************************************************/
   PROCEDURE GET_ACTIVE_DAY(PI_TYPE             IN   VARCHAR2,
                            PI_START_DATE       IN   DATE,
                            PI_END_DATE         IN   DATE,
                            PI_AMY_QTY          IN   NUMBER,
                            PI_Tab_PKG_RATES    IN   FY_PG_BL_BILL_CI.t_PKG_RATES,
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
            AND STATUS_DATE < PI_END_DATE+1
            AND (EXP_DATE IS NULL OR EXP_DATE>=PI_START_DATE+1)
          ORDER BY STATUS_DATE;         
            
      NU_CNT             NUMBER  :=0;
      DT_START_DATE      DATE;
      DT_END_DATE        DATE;
      On_Err             EXCEPTION;
   BEGIN
      if pi_end_date<pi_start_date then
         nu_cnt := 0;  
      ELSIF gvOFFER_LEVEL='S' AND gvPRORATE_METHOD='Y' THEN  --破月   
         nu_cnt := 0; 
         FOR R_SP IN C_SP LOOP
            DT_START_DATE := greatest(trunc(PI_START_DATE), R_SP.STATUS_DATE);--取其大
            DT_END_DATE   := least(trunc(PI_END_DATE),NVL(R_SP.EXP_DATE,PI_END_DATE)); --取其小
            NU_CNT        := NU_CNT + (DT_END_DATE-DT_START_DATE)+1;
            IF PI_TYPE='RC' THEN
               gvSTEP := 'DO_RC_ACTIVE:';
               DO_RC_ACTIVE(DT_START_DATE,
                            DT_END_DATE,
                            PI_AMY_QTY,
                            PI_Tab_PKG_RATES);
               IF gvERR_CDE<>'0000' THEN
                  gvSTEP := SUBSTR('DO_RC_ACTIVE:'||gvERR_MSG,1,250);
                  RAISE ON_ERR; 
               END IF;
            END IF;   
            IF DT_END_DATE=trunc(PI_END_DATE) THEN
               EXIT;
            END IF;
         END LOOP;
      ELSE
         NU_CNT := trunc(PI_END_DATE)-trunc(PI_START_DATE)+1;
         IF PI_TYPE='RC' THEN
            gvSTEP := 'DO_RC_ACTIVE:';
            DO_RC_ACTIVE(trunc(PI_START_DATE),
                         trunc(PI_END_DATE),
                         PI_AMY_QTY,
                         PI_Tab_PKG_RATES);
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
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE DO_RC_ACTIVE(PI_START_DATE       IN   DATE,
                          PI_END_DATE         IN   DATE,
                          PI_AMY_QTY          IN   NUMBER,
                          PI_Tab_PKG_RATES    IN   FY_PG_BL_BILL_CI.t_PKG_RATES) IS

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
      IF gvQTY_CONDITION='D' THEN --服務數量(定義offer parameter, 由CM提供) 
         NU_QTY_CNT := PI_AMY_QTY;
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
            IF gvPRICING_TYPE='S' THEN  
               IF PI_Tab_PKG_RATES(i).QTY_S=0 THEN
                  NU_CHRG_QTY := NU_CTRL_AMT_QTY;
               ELSE                                          
                  NU_CHRG_QTY := NU_CTRL_AMT_QTY-PI_Tab_PKG_RATES(i).QTY_S+1;
               END IF;   
            ELSE
               NU_CHRG_QTY := NU_CTRL_AMT_QTY;
            END IF; 
            NU_CHRG_AMT  := ROUND(NU_CHRG_AMT+(PI_Tab_PKG_RATES(i).RATES/gnFREQUENCY*NU_QTY_CNT*NU_MONTH),2); 
            NU_CTRL_AMT_QTY:= NU_CTRL_AMT_QTY - NU_CHRG_QTY;  
        --   DBMS_OUTPUT.Put_Line('AMT='||TO_CHAR(PI_Tab_PKG_RATES(i).RATES)||' ,REQUENCY='||TO_CHAR(gnFREQUENCY)||' ,MON='||TO_CHAR(NU_MONTH)||' ,QTY='||TO_CHAR(NU_QTY_CNT));          
         END IF;   
         IF NU_CTRL_AMT_QTY=0 THEN
            EXIT;
         END IF;                             
      END LOOP;
      IF gvCI_STEP='T' THEN
         NU_CHRG_AMT  := NU_CHRG_AMT*-1;
      END IF;
      --CALL INSERT BILL_CI            
      gvSTEP := 'INS_CI:';
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
            NU_MONTH := NVL(NU_MONTH,0)+ (DT_END_DATE-DT_START_DATE+1)/(DT_BILL_END_DATE-DT_BILL_FROM_DATE+1);
            DT_START_DATE := DT_END_DATE+1;
            IF DT_START_DATE>trunc(PI_END_DATE) THEN
               EXIT;
            END IF;
         END LOOP;       
         PO_MONTH   := NU_MONTH; 
      end if;      
      gvERR_CDE := '0000';
      gvERR_MSG := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         gvErr_Cde := '4999';
         gvErr_Msg := Substr(SQLERRM, 1, 250);     
   END GET_MONTH;    
   
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
   **************************************************************************/
   PROCEDURE INS_CI(PI_START_DATE               IN   DATE,
                    PI_END_DATE                 IN   DATE,
                    PI_SOURCE                   IN   VARCHAR2,
                    PI_SOURCE_CI_SEQ            IN   NUMBER,
                    PI_SOURCE_OFFER_ID          IN   NUMBER,
                    PI_SERVICE_RECEIVER_TYPE    IN   VARCHAR2,
                    PI_AMOUNT                   IN   NUMBER) IS         

      CH_CHARGE_TYPE             FY_TB_BL_BILL_CI.CHARGE_TYPE%TYPE;
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
      gvSTEP := 'INSERT BILL_CI_TEST:';
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
                    SELECT FY_SQ_BL_BILL_CI_TEST.NEXTVAL,
                           gnACCT_ID,
                           MOD(gnACCT_ID,100),
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
                           NULL,  --DYNAMIC_ATTRIBUTE,
                           SYSDATE,
                           gvUSER,
                           SYSDATE,
                           gvUSER
                      FROM DUAL;                    
      gvERR_CDE := '0000';
      gvERR_MSG := NULL;
   EXCEPTION
      WHEN on_err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END INS_CI; 
   
   /*************************************************************************
      PROCEDURE : CHECK_MPBL
      PURPOSE :   CHECK CUST_ID是否為MPBL      
      DESCRIPTION : CHECK CUST_ID是否為MPBL  
      PARAMETER:
            PI_CUST_ID            :CUST_ID
            PO_MPBL               :Y:MPBL/N
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明 
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2020/06/30      FOYA       CREATE FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE CHECK_MPBL(PI_CUST_ID          IN   NUMBER,
                        PO_MPBL            OUT   VARCHAR2,
                        PO_ERR_CDE         OUT   VARCHAR2,
                        PO_ERR_MSG         OUT   VARCHAR2) IS         

      On_Err           EXCEPTION;
      Ch_CUST_TYPE     FY_TB_CM_CUSTOMER.CUST_TYPE%TYPE;
      CH_STEP          VARCHAR2(300);
   BEGIN
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
      IF PI_CUST_ID IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '輸入CUST_ID不可為空';
         RAISE On_Err;
      END IF;
      
      CH_STEP := 'CUST_ID='||TO_CHAR(PI_CUST_ID);
      BEGIN
         SELECT CUST_TYPE
           INTO CH_CUST_TYPE
           FROM FY_TB_CM_CUSTOMER 
          WHERE CUST_ID=PI_CUST_ID;
      EXCEPTION WHEN OTHERS THEN
         Po_Err_Cde := '4002';
         Po_Err_Msg := Substr(CH_STEP || SQLERRM, 1, 250);
         RAISE On_Err;
      END; 
       
      CH_STEP := 'CUST_TYPE='||CH_CUST_TYPE; 
      BEGIN
         SELECT 'Y' 
           INTO PO_MPBL
           FROM FY_TB_SYS_LOOKUP_CODE
          WHERE LOOKUP_TYPE  ='MPBL'
            AND lookup_code  ='CUST_TYPE'
            AND (NVL(CH1,' ')!=CH_CUST_TYPE AND 
                 NVL(CH2,' ')!=CH_CUST_TYPE AND
                 NVL(CH3,' ')!=CH_CUST_TYPE AND
                 NVL(CH4,' ')!=CH_CUST_TYPE);
      EXCEPTION WHEN OTHERS THEN
         PO_MPBL := 'N';
      END;            
   EXCEPTION
      WHEN On_Err THEN
         NULL;
      WHEN OTHERS THEN
         Po_Err_Cde := '4999';
         Po_Err_Msg := Substr(CH_STEP || SQLERRM, 1, 250);
   END CHECK_MPBL; 
   
END Fy_Pg_Bl_Bill_Util;
/