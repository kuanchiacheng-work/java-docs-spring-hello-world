CREATE OR REPLACE PACKAGE BODY FY_PG_BL_BILL_CUTDATE IS

   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL CUT_DATE 處理
      DESCRIPTION : BL CUT_DATE 處理
      PARAMETER:
            PI_CYCLE              :出帳週期
            PI_BILL_PERIOD        :出帳年月
            PI_USER               :USER_ID
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/03/18      FOYA       MODIFY FOR MPBS_Migration 
                                       FY_TB_BL_CYCLE P_KEY變更 & FY_TB_BL_BILL_CNTRL ADD ITEM                                       
   **************************************************************************/
   PROCEDURE MAIN(PI_CYCLE          IN   NUMBER,
                  PI_BILL_PERIOD    IN   VARCHAR2,
                  PI_USER           IN   VARCHAR2,
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2) IS

      CURSOR C_CYC IS
         SELECT CYCLE,
                NAME,
                BILLING_DAY,
                FROM_DAY,
                END_DAY,
                DUE_DAY,
                LBC_DATE,
                CURRECT_PERIOD
           FROM FY_TB_BL_CYCLE
          WHERE CYCLE      =PI_CYCLE
            AND CREATE_USER=PI_USER; --2020/06/30 MODIFY FOR MPBS_Migration - FY_TB_BL_CYCLE.P_KEY:CYCLE&CREATE_USER
      R_CYC       C_CYC%ROWTYPE;

      DT_DUE_DATE        DATE;
      NU_CNT             NUMBER;
      NU_ACCT_CNT        NUMBER;
      NU_SUB_CNT         NUMBER;
      On_Err             EXCEPTION;
   BEGIN
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':FY_PG_BL_BILL_CUTDATE BEGIN');
      gnCYCLE       := PI_CYCLE;
      gvBILL_PERIOD := PI_BILL_PERIOD;
      gnCYCLE_MONTH := TO_NUMBER(SUBSTR(PI_BILL_PERIOD,-2));
      gvUSER        := PI_USER;
      ----CHECK CYCLE正確性
      OPEN C_CYC;
      FETCH C_CYC INTO R_CYC;
      IF C_CYC%NOTFOUND THEN
         PO_ERR_CDE := 'C001';
         gvSTEP    := 'CHECK CYCLE='||TO_CHAR(PI_CYCLE)||':NO DATA FOUND';
         RAISE ON_ERR;
      END IF;
      IF PI_BILL_PERIOD<>R_CYC.CURRECT_PERIOD THEN
         PO_ERR_CDE := 'C002';
         gvSTEP    := 'CHECK CYCLE='||TO_CHAR(PI_CYCLE)||':BILL_PERIOD<>CURRECT_PERIOD';
         RAISE ON_ERR;
      END IF;
      CLOSE C_CYC;
      
      --BILL_DATE 處理
      IF R_CYC.FROM_DAY=1 THEN
         gdBILL_FROM_DATE := TO_DATE(gvBILL_PERIOD||TO_CHAR(R_CYC.FROM_DAY),'YYYYMMDD');
         gdBILL_END_DATE  := TO_DATE(gvBILL_PERIOD||TO_CHAR(Last_Day(gdBILL_FROM_DATE),'DD'),'YYYYMMDD');
      ELSE
         gdBILL_END_DATE  := TO_DATE(gvBILL_PERIOD||TO_CHAR(R_CYC.END_DAY),'YYYYMMDD');
         gdBILL_FROM_DATE := ADD_MONTHS(gdBILL_END_DATE,-1)+1;
      END IF;
      gdBILL_DATE := gdBILL_END_DATE+1;
      
      --BILL_SEQ處理
      gvSTEP := 'GET BILL_SEQ :';
        IF gvUSER='MPBL' THEN --2020/06/30 MODIFY FOR MPBS_Migration - GET BILL_SEQ處理
          BEGIN
            SELECT cycle_seq_no
                   INTO gnbill_seq
                FROM bl1_cycle_control
             WHERE cycle_code       = gnCYCLE
                 AND cycle_instance   = gnCYCLE_MONTH
                 AND trunc(start_date)= trunc(gdBILL_FROM_DATE)
                 AND trunc(end_date)  = trunc(gdBILL_END_DATE);
            EXCEPTION WHEN OTHERS THEN
               PO_ERR_CDE:= 'C002';
           gvSTEP    := 'MPBL BILL_SEQ NO_DATA_FOUND';
           RAISE ON_ERR;  
        END;   
        ELSE
        SELECT FY_SQ_BL_BILL_CNTRL.NEXTVAL
          INTO gnBILL_SEQ
          FROM DUAL;
      END IF;    

      --DT_CUT_DATE處理
      BEGIN
         SELECT DUE_DATE
           INTO DT_DUE_DATE
           FROM FY_TB_BL_CYCLE_DUE
          WHERE CYCLE      =gnCYCLE
            AND BILL_PERIOD=gvBILL_PERIOD
            AND CREATE_USER=gvUSER; --2020/06/30 MODIFY FOR MPBS_Migration - GET BILL_SEQ處理
      EXCEPTION WHEN OTHERS THEN
         IF R_CYC.DUE_DAY<R_CYC.END_DAY THEN
            IF R_CYC.DUE_DAY>TO_NUMBER(TO_CHAR(Last_Day(ADD_MONTHS(gdBILL_END_DATE,1)),'DD')) THEN
               PO_ERR_CDE:= 'C002';
               gvSTEP    := 'DUE_DATE超出月底日期';
               RAISE ON_ERR;
            END IF;
            IF gnCYCLE = '15' THEN --2023/04/19 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CYCLE(15)DueDate需跨至次月
               DT_DUE_DATE := TO_DATE(TO_CHAR(ADD_MONTHS(gdBILL_END_DATE,2),'YYYYMM')||R_CYC.DUE_DAY,'YYYYMMDD');
            ELSE
               DT_DUE_DATE := TO_DATE(TO_CHAR(ADD_MONTHS(gdBILL_END_DATE,1),'YYYYMM')||R_CYC.DUE_DAY,'YYYYMMDD');
            END IF;
         ELSE
            DT_DUE_DATE := TO_DATE(TO_CHAR(gdBILL_END_DATE,'YYYYMM')||R_CYC.DUE_DAY,'YYYYMMDD');
         END IF;
      END;

      ----CHECK PROCESS_NO
      gvSTEP := 'CALL Ins_Process_LOG:';
      Fy_Pg_Bl_Bill_Util.Ins_Process_LOG
                     ('CL',  --PI_STATUS
                      gnBILL_SEQ,
                      'B',
                      0,
                      'CUT' ,
                      'UBL',
                      gvERR_CDE ,
                      gvERR_MSG);
      IF gvERR_CDE<>'0000' THEN
         Po_Err_Cde:= gvERR_CDE;
         gvSTEP    := SUBSTR('CALL Ins_Process_LOG:'||gvERR_MSG,1,250);
         RAISE On_Err;
      END IF;

      --ACCOUNT KEEP
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':KEEP_ACCT BEGIN');
      KEEP_ACCT;
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP := SUBSTR('CALL KEEP_ACCT.CYCLE='||TO_CHAR(gnCYCLE)||':'||gvERR_MSG,1,250);
         RAISE ON_ERR;
      END IF;
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':KEEP_ACCT END');

      --MARKET MOVE ACCT_PKG處理
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':MARKET_MOVE BEGIN');
      MARKET_MOVE;
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP := SUBSTR('CALL MARKET_MOVE.CYCLE='||TO_CHAR(gnCYCLE)||':'||gvERR_MSG,1,250);
         RAISE ON_ERR;
      END IF;
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':MARKET_MOVE END');   

      SELECT COUNT(1)
        INTO NU_ACCT_CNT
        FROM FY_TB_BL_BILL_ACCT
       WHERE BILL_SEQ   =gnBILL_SEQ
         AND CYCLE      =gnCYCLE
         AND CYCLE_MONTH=gnCYCLE_MONTH;

      --INSERT BL_BILL_CNTRL
      gvSTEP := 'INSERT BL_BILL_CNTRL.CYCLE='||TO_CHAR(gnCYCLE)||':';
      INSERT INTO FY_TB_BL_BILL_CNTRL
                 (BILL_SEQ,
                  CYCLE,
                  BILL_PERIOD,
                  CYCLE_MONTH,
                  BILL_DATE,
                  BILL_FROM_DATE,
                  BILL_END_DATE,
                  DUE_DATE,
                  STATUS,
                  FILE_REPLY,
                  IMMEDIATELY_FLAG,
                  ACCT_COUNT,
                  ORG_ACCT_COUNT, --2020/06/30 MODIFY FOR MPBS_Migration - CUT_DATE ACCT_COUNT
                  CONFIRM_ID,
                  CREATE_DATE,
                  CREATE_USER,
                  UPDATE_DATE,
                  UPDATE_USER)
            VALUES
                 (gnBILL_SEQ,
                  gnCYCLE,
                  gvBILL_PERIOD,
                  gnCYCLE_MONTH,
                  gdBILL_DATE,
                  gdBILL_FROM_DATE,
                  gdBILL_END_DATE,
                  DT_DUE_DATE,
                  'CL',     ---STATUS,
                  NULL,     ---FILE_REPLY,
                  NULL,     ---IMMEDIATELY_FLAG,
                  NU_ACCT_CNT, ---ACCT_COUNT,
                  NU_ACCT_CNT, --2020/06/30 MODIFY FOR MPBS_Migration ADD ORG_ACCT_COUNT
                  1,        ---CONFIRM_ID)
                  SYSDATE,
                  gvUSER,
                  SYSDATE,
                  gvUSER);

      --UPDATE FY_TB_BL_CYCLE
      gvSTEP := 'UPDATE BL_CYCLE.CYCLE='||TO_CHAR(PI_CYCLE)||':';
      UPDATE FY_TB_BL_CYCLE SET LBC_DATE      =gdBILL_END_DATE,
                                CURRECT_PERIOD=TO_CHAR(ADD_MONTHS(TO_DATE(gvBILL_PERIOD,'YYYYMM'),1),'YYYYMM'),
                                UPDATE_DATE   =SYSDATE,
                                UPDATE_USER   =gvUSER
                           WHERE CYCLE      =gnCYCLE
                             AND CREATE_USER=gvUSER; --2020/06/30 MODIFY FOR MPBS_Migration - FY_TB_BL_CYCLE.P_KEY:CYCLE&CREATE_USER

      --SET ACCT_GROUP
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':CUT_GROUP BEGIN');
      CUT_GROUP;
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP := SUBSTR('CALL CUT_GROU.CYCLE='||TO_CHAR(gnCYCLE)||':'||gvERR_MSG,1,250);
         RAISE ON_ERR;
      END IF;
      --
      gvSTEP := 'UPDATE PROCESS_LOG.BILL_SEQ='||TO_CHAR(gnBILL_SEQ)||':';
      UPDATE FY_TB_BL_BILL_PROCESS_LOG BL SET END_TIME=SYSDATE,
                                              COUNT   =NU_ACCT_CNT
                                     WHERE BILL_SEQ  = gnBILL_SEQ
                                       AND PROCESS_NO= 0
                                       AND ACCT_GROUP= 'CUT'
                                       AND PROC_TYPE = 'B'
                                       AND STATUS    = 'CL'
                                       AND END_TIME IS NULL;
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':CUT_GROUP END');
      COMMIT;
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':FY_PG_BL_BILL_CUTDATE END');
      DBMS_OUTPUT.Put_Line('ACCT_ID CNT='||TO_CHAR(NU_ACCT_CNT));
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN on_err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END MAIN;

   /*************************************************************************
      PROCEDURE : KEEP_ACCT
      PURPOSE :   KEEP ACCT & ACCOUNT/SUBSCR SYNC 處理
      DESCRIPTION : KEEP ACCT & ACCOUNT/SUBSCR SYNC 處理
      PARAMETER:

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE KEEP_ACCT IS

      CURSOR C_AT(iCYCLE NUMBER) IS
         SELECT BA.ACCT_ID,
                MOD(BA.ACCT_ID,100) ACCT_KEY,
                BA.ACCT_GROUP,
                BA.CUST_ID,
                BA.BL_STATUS,
                BA.STATUS_DATE,
                BA.EFF_DATE,
                BA.FIRST_BILL_SEQ,
                BA.LAST_BILL_SEQ,
                BA.PRE_BILL_SEQ,
                BA.PRE_BILL_NBR,
                BA.PRE_BILL_AMT,
                BA.PRE_CHRG_AMT,
                CM.OU_ID,
                CM.ACCT_CATEGORY,
                CM.STATUS,
                CM.CURRENCY,
                'N' SRC_ACCT_PKG,  --2020/06/30 MODIFY FOR MPBS_Migration ADD
                'N' SRC_ACTIVITY,  --2020/06/30 MODIFY FOR MPBS_Migration ADD
                'N' SRC_BALANCE,   --2020/06/30 MODIFY FOR MPBS_Migration ADD
                'N' SRC_UC,        --2020/06/30 MODIFY FOR MPBS_Migration ADD
                'N' SRC_OC,        --2020/06/30 MODIFY FOR MPBS_Migration ADD
                decode(gvUSER,'MPBL','Y' ,'N') UNBILL_FLAG    --2020/06/30 MODIFY FOR MPBS_Migration ADD
           FROM FY_TB_BL_ACCOUNT BA,
                FY_TB_CM_ACCOUNT CM,
                FY_TB_CM_CUSTOMER CMC --2020/06/30 MODIFY FOR MPBS_Migration - CUST_TYPE判別
          WHERE BA.CYCLE     =iCYCLE
            AND BA.BL_STATUS<>'CLOSE'
            AND CM.ACCT_ID=BA.ACCT_ID
            AND CM.STATUS<>'T' --T:未開帳/O:開帳/C:CLOSE
            AND CM.EFF_DATE <gdBILL_DATE
            AND BA.CUST_ID  =CMC.CUST_ID    --2020/06/30 MODIFY FOR MPBS_Migration ADD
            AND CMC.CUST_ID=CM.CUST_ID  --2020/06/30 MODIFY FOR MPBS_Migration ADD
            AND ((gvUSER  ='MPBL' AND NOT EXISTS (SELECT 1 FROM FY_TB_SYS_LOOKUP_CODE 
                                                          WHERE LOOKUP_TYPE='MPBL'
                                                            AND LOOKUP_CODE='CUST_TYPE'
                                                              AND (CH1=CMC.CUST_TYPE OR CH2=CMC.CUST_type OR CH3=CMC.CUST_TYPE OR CH4=CMC.CUST_TYPE))) OR
                   (gvUSER <>'MPBL' AND  EXISTS (SELECT 1 FROM FY_TB_SYS_LOOKUP_CODE 
                                                          WHERE LOOKUP_TYPE='MPBL'
                                                            AND LOOKUP_CODE='CUST_TYPE'
                                                              AND (CH1=CMC.CUST_TYPE OR CH2=CMC.CUST_type OR CH3=CMC.CUST_TYPE OR CH4=CMC.CUST_TYPE))))
                --CMC.CUST_TYPE NOT IN ('D','N')) OR 
                -- (gvUSER <>'MPBL' AND CMC.CUST_TYPE IN ('D','N'))) --2020/06/30 MODIFY FOR MPBS_Migration - CHECK CUST_TYPE
          ORDER BY BA.ACCT_ID;

      --CURSOR C_SUB(iACCT_ID NUMBER,iBILL_FROM_DATE DATE, iBILL_END_DATE DATE) IS --2019/06/30 MODIFY skip_bill 大額客戶SQL
        CURSOR C_SUB(iACCT_ID NUMBER) IS --2019/06/30 MODIFY FY_TB_CM_SUBSCR cancel status時間判斷
         SELECT STATUS, COUNT(1) CNT
           FROM FY_TB_CM_SUBSCR
          WHERE ACCT_ID   = iACCT_ID
            AND INIT_ACT_DATE < gdBILL_DATE
            --AND (STATUS<>'C' OR --2019/06/30 MODIFY FY_TB_CM_SUBSCR cancel status時間判斷
            --     (STATUS='C' AND STATUS_DATE>=iBILL_FROM_DATE)) 2019/06/30 MODIFY FY_TB_CM_SUBSCR cancel status時間判斷
          GROUP BY STATUS;

      CURSOR C1 IS
         SELECT DISTINCT ACCT_ID
           FROM (SELECT ACCT_ID,SUBSCR_ID,PRE_SUB_ID,INHERIT_FLAG
                          FROM FY_TB_BL_BILL_SUB
                         WHERE BILL_SEQ   =gnBILL_SEQ
                           AND CYCLE      =gnCYCLE
                           AND CYCLE_MONTH=gnCYCLE_MONTH) SUB
          START WITH PRE_SUB_ID IS NOT NULL AND INHERIT_FLAG='Y'
        CONNECT BY PRIOR PRE_SUB_ID=SUBSCR_ID;

      --2019/12/31 MODIFY 新增cursor C2，取出新舊Account&SUB關聯
      CURSOR C2 IS
      SELECT a.acct_id old_acct, b.subscr_id old_sub, b.acct_id new_acct,
             b.pre_sub_id new_sub
        FROM fy_tb_bl_bill_sub a,
             (SELECT     acct_id, pre_sub_id, subscr_id
                    FROM (SELECT acct_id, subscr_id, pre_sub_id, inherit_flag
                            FROM fy_tb_bl_bill_sub
                           WHERE bill_seq = gnBILL_SEQ
                             AND CYCLE = gnCYCLE
                             AND cycle_month = gnCYCLE_MONTH
                             AND pre_sub_id IS NOT NULL) sub
              START WITH pre_sub_id IS NOT NULL AND inherit_flag = 'Y'
              CONNECT BY PRIOR pre_sub_id = subscr_id) b
       WHERE bill_seq = gnBILL_SEQ
         AND CYCLE = gnCYCLE
         AND cycle_month = gnCYCLE_MONTH
         AND a.subscr_id = b.pre_sub_id;     

      CH_PERM_PRINTING_CAT   FY_TB_BL_BILL_ACCT.PERM_PRINTING_CAT%TYPE;
      CH_PRODUCTION_TYPE     FY_TB_BL_BILL_ACCT.PRODUCTION_TYPE%TYPE;
      NU_CNT                 NUMBER  :=0;
      NU_SUB_CNT             NUMBER;
      NU_SUS_CNT             NUMBER;
      NU_CAN_CNT             NUMBER;
      NU_ATV_CNT             NUMBER;
      NU_ACCT_CNT            NUMBER;
      NU_SHOW_CNT            NUMBER;
      NU_SRC_CNT             NUMBER;   --2020/06/30 MODIFY FOR MPBS_Migration - 新增暫存變數
      On_Err                 EXCEPTION;
   BEGIN
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
      ----ACCOUNT處理
      FOR R_AT IN C_AT(gnCYCLE) LOOP
         NU_ACCT_CNT := NVL(NU_ACCT_CNT,0)+1;
         IF MOD(NU_ACCT_CNT/NU_SHOW_CNT,1)=0 THEN
            DBMS_OUTPUT.Put_Line('CNT='||TO_CHAR(NU_ACCT_CNT)||', ACCT_ID='||TO_CHAR(R_AT.ACCT_ID));
            COMMIT;
         END IF;
         NU_SUS_CNT := 0;
         NU_CAN_CNT := 0;
         NU_ATV_CNT := 0;
         CH_PERM_PRINTING_CAT := 'N';
         --2020/06/30 MODIFY FOR MPBS_Migration
         IF gvUSER='MPBL' THEN
            --SRC_ACCT_PKG
            SELECT COUNT(1)
              INTO NU_SRC_CNT
              FROM fy_tb_bl_acct_pkg a, fy_Tb_pbk_offer b
             WHERE A.acct_key = R_AT.acct_key
               AND A.acct_id  = R_AT.acct_id
               AND a.status   = 'OPEN'
                     AND a.offer_id = b.offer_id
                     and a.eff_date < gdBILL_DATE
                     and b.offer_type != 'PP';
            IF NU_SRC_CNT>0 THEN
               R_AT.SRC_ACCT_PKG := 'Y';
               R_AT.UNBILL_FLAG  := 'N';
            END IF;   

            --SRC_BALANCE
            SELECT COUNT(1)
              INTO NU_SRC_CNT
              FROM fet1_account a
             WHERE a.account_id = R_AT.acct_id
               AND a.ar_balance<> 0;
            IF NU_SRC_CNT>0 THEN
               R_AT.SRC_BALANCE  := 'Y';
               R_AT.UNBILL_FLAG  := 'N';
            END IF;   

            --SRC_ACTIVITY
            SELECT COUNT(1)
              INTO NU_SRC_CNT
              FROM fet1_transaction_log_mpbl a
             WHERE a.bill_seq = gnBILL_SEQ
               AND a.account_id = R_AT.acct_id;
            IF NU_SRC_CNT>0 THEN
               R_AT.SRC_ACTIVITY := 'Y';
               R_AT.UNBILL_FLAG  := 'N';
            END IF;     

            --SRC_UC
            SELECT COUNT(1)
              INTO NU_SRC_CNT
              FROM fy_tb_rat_summary_bill a
             WHERE a.CYCLE       = gnCYCLE
               AND a.cycle_month = gnCYCLE_MONTH
               AND A.acct_key    = R_AT.acct_key
               AND A.acct_id     = R_AT.acct_id;
            IF NU_SRC_CNT>0 THEN
               R_AT.SRC_UC       := 'Y';
               R_AT.UNBILL_FLAG  := 'N';
            END IF;  

            --SRC_OC
            SELECT COUNT(1)
              INTO NU_SRC_CNT
              FROM fy_tb_bl_bill_ci a
             WHERE a.CYCLE       = gnCYCLE
               AND a.cycle_month = gnCYCLE_MONTH
               AND A.acct_key    = R_AT.acct_key
               AND A.acct_id     = R_AT.acct_id 
               AND A.bill_seq IS NULL;
            IF NU_SRC_CNT>0 THEN
               R_AT.SRC_OC       := 'Y';
               R_AT.UNBILL_FLAG  := 'N';
            END IF;  
            
            --2021/06/15 MODIFY FOR 小額預繳處理
            IF R_AT.UNBILL_FLAG<>'N' THEN
               SELECT COUNT(1)
                 INTO NU_CNT
                 FROM FY_TB_CM_SUBSCR A 
                WHERE ACCT_ID = R_AT.ACCT_ID
                  AND INIT_ACT_DATE < gdBILL_DATE
                  AND NVL(END_DATE,gdBILL_END_DATE) >= gdBILL_FROM_DATE
                  AND NVL(
                    PREV_SUB_ID,
                    CASE --20230221_Project M修改亞太資料中，非"="的資料會造成FAIL，而"-"號後的資料為亞太SUB，不需處理
                      WHEN INSTR(EXTERNAL_ID, '=') > 0 THEN
                        TO_NUMBER(TRIM(SUBSTR(EXTERNAL_ID, INSTR(EXTERNAL_ID, '=') + 1)))
                    END
                  ) IS NOT NULL
                  --AND RSN_CODE in (SELECT lookup_code FROM fy_tb_cm_lookup_code WHERE lookup_type IN ('MARKETMOVE','PRODUCTMIG')) 
                  AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG 
                                      WHERE ACCT_ID       =A.ACCT_ID
                                        AND ACCT_KEY      =MOD(A.ACCT_ID,100)
                                        AND OFFER_LEVEL   ='S'
                                        AND OFFER_LEVEL_ID=A.SUBSCR_ID
                                        AND PRE_PKG_SEQ IS NOT NULL
                                        AND TRANS_OUT_DATE IS NULL);
              /*    AND NVL(PREV_SUB_ID,TO_NUMBER(TRIM(SUBSTR (EXTERNAL_ID,INSTR (EXTERNAL_ID, '=') + 1)))) IS NOT NULL
                  --AND RSN_CODE in (SELECT lookup_code FROM fy_tb_cm_lookup_code WHERE lookup_type IN ('MARKETMOVE','PRODUCTMIG')) 
                  AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG 
                                      WHERE ACCT_ID       =A.ACCT_ID
                                        AND ACCT_KEY      =MOD(A.ACCT_ID,100)
                                        AND OFFER_LEVEL   ='S'
                                        AND OFFER_LEVEL_ID=A.SUBSCR_ID
                                        AND PRE_PKG_SEQ IS NOT NULL
                                        AND TRANS_OUT_DATE IS NULL); */
              /*    AND (NVL(PREV_SUB_ID,TO_NUMBER(TRIM(SUBSTR (EXTERNAL_ID,INSTR (EXTERNAL_ID, '=') + 1)))) IS NOT NULL OR
                       SUBSCR_ID IN (SELECT NVL(PREV_SUB_ID,TO_NUMBER(TRIM(SUBSTR (EXTERNAL_ID,INSTR (EXTERNAL_ID, '=') + 1)))) 
                                       FROM FY_TB_BL_ACCOUNT BA,
                                            FY_TB_CM_SUBSCR CM
                                      WHERE BA.CYCLE   =gnCYCLE
                                        AND BA.ACCT_ID = CM.ACCT_ID
                                        AND CM.INIT_ACT_DATE < gdBILL_DATE
                                        AND NVL(CM.END_DATE,gdBILL_END_DATE) >= gdBILL_FROM_DATE
                                        AND (CM.PREV_SUB_ID IS NOT NULL OR CM.EXTERNAL_ID IS NOT NULL))); */
               IF NU_CNT>0 THEN
                  R_AT.UNBILL_FLAG  := 'N';
               END IF;
            END IF; --2021/06/15 MODIFY FOR 小額預繳處理
            
            --INSERT FY_TB_BL_BILL_ACCT_MPBL
            gvSTEP := 'MPBL INSERT FY_TB_BL_BILL_ACCT_MPBL:ACCT_ID='||TO_CHAR(R_AT.ACCT_ID)||':';
            INSERT INTO FY_TB_BL_BILL_ACCT_MPBL
                    (BILL_SEQ,
                     CYCLE,
                     CYCLE_MONTH,
                     CUST_ID,
                     ACCT_ID,
                   --  ACCT_KEY, 為虛擬欄位
                     SRC_ACCT_PKG,
                     SRC_ACTIVITY,
                     SRC_BALANCE,
                     SRC_UC,
                     SRC_OC,
                     UNBILL_FLAG,
                     CREATE_DATE,
                     CREATE_USER,
                     UPDATE_DATE,
                     UPDATE_USER)
               VALUES
                    (gnBILL_SEQ,
                     gnCYCLE,
                     gnCYCLE_MONTH,
                     R_AT.CUST_ID,
                     R_AT.ACCT_ID,
                   --  R_AT.ACCT_KEY,
                     R_AT.SRC_ACCT_PKG,
                     R_AT.SRC_ACTIVITY,
                     R_AT.SRC_BALANCE,
                     R_AT.SRC_UC,
                     R_AT.SRC_OC,
                     R_AT.UNBILL_FLAG,
                     SYSDATE,
                     gvUSER,
                     SYSDATE,
                     gvUSER);
         END IF; --2020/06/30 MODIFY FOR MPBS_Migration 
         
         IF R_AT.UNBILL_FLAG='N' THEN  --2020/06/30 MODIFY FOR MPBS_Migration  
            --非末期
            IF R_AT.LAST_BILL_SEQ IS NULL THEN
               gvSTEP := 'INSERT BILL_SUB.ACCT_ID='||TO_CHAR(R_AT.ACCT_ID)||':';
               INSERT INTO FY_TB_BL_BILL_SUB
                          (BILL_SEQ,
                           CYCLE,
                           CYCLE_MONTH,
                           ACCT_ID,
                         --  ACCT_KEY,  為虛擬欄位
                           SUBSCR_ID,
                           STATUS,
                           OU_ID,
                           EFF_DATE,
                           END_DATE,
                           PRE_SUB_ID,
                           INIT_RSN_CODE,
                           INHERIT_FLAG,
                           CREATE_DATE,
                           CREATE_USER,
                           UPDATE_DATE,
                           UPDATE_USER,
                           BILL_SUBSCR_ID) --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理   
                    SELECT gnBILL_SEQ,
                           gnCYCLE,
                           gnCYCLE_MONTH,
                           R_AT.ACCT_ID,
                         --  R_AT.ACCT_KEY,
                           SUBSCR_ID,
                           STATUS,
                           OU_ID,
                           INIT_ACT_DATE, --EFF_DATE,
                           DECODE(STATUS,'C',STATUS_DATE,NULL) END_DATE, --2019/01/02 MODIFY select FY_TB_CM_SUBSCR.DECODE(STATUS,'C',STATUS_DATE,NULL) END_DATE,
                           --NVL(PREV_SUB_ID,TO_NUMBER(TRIM(SUBSTR (EXTERNAL_ID,INSTR (EXTERNAL_ID, '=') + 1)))) PREV_SUB_ID, --2021/06/15 MODIFY FOR 小額預繳處理
                           NVL(
                             PREV_SUB_ID,
                             CASE --20230221_Project M修改亞太資料中，非"="的資料會造成FAIL，而"-"號後的資料為亞太SUB，不需處理
                               WHEN INSTR(EXTERNAL_ID, '=') > 0 THEN
                                 TO_NUMBER(TRIM(SUBSTR(EXTERNAL_ID, INSTR(EXTERNAL_ID, '=') + 1)))
                             END
                           ) PREV_SUB_ID, --20230221_Project M修改亞太資料中，非"="的資料會造成FAIL，而"-"號後的資料為亞太SUB，不需處理
                           INIT_RSN_CODE,
                          --(CASE WHEN NVL(PREV_SUB_ID,TO_NUMBER(TRIM(SUBSTR (EXTERNAL_ID,INSTR (EXTERNAL_ID, '=') + 1)))) IS NOT NULL THEN --2021/06/15 MODIFY FOR 小額預繳處理  刪除gvUSER判別 AND gvUSER<>'MPBL' THEN --AND INIT_RSN_CODE='A2A', --2020/06/30 MODIFY FOR MPBS_Migration ADD gvUSER<>'MPBL'判別
                          (CASE WHEN NVL(
                             PREV_SUB_ID,
                             CASE --20230221_Project M修改亞太資料中，非"="的資料會造成FAIL，而"-"號後的資料為亞太SUB，不需處理
                               WHEN INSTR(EXTERNAL_ID, '=') > 0 THEN
                                 TO_NUMBER(TRIM(SUBSTR(EXTERNAL_ID, INSTR(EXTERNAL_ID, '=') + 1)))
                             END
                           ) IS NOT NULL THEN  --20230221_Project M修改亞太資料中，非"="的資料會造成FAIL，而"-"號後的資料為亞太SUB，不需處理
                               (SELECT DECODE(COUNT(1),0,'N','Y')
                                 FROM FY_TB_BL_ACCT_PKG
                                WHERE ACCT_ID       =R_AT.ACCT_ID
                                  AND ACCT_KEY      =R_AT.ACCT_KEY
                                  AND OFFER_LEVEL   ='S'
                                  AND OFFER_LEVEL_ID=A.SUBSCR_ID
                                  AND PRE_PKG_SEQ IS NOT NULL
                                  --AND TRANS_IN_DATE IS NULL --尚未處理 2019/12/02 MODIFY mark for NPEP Project
                                  AND FIRST_BILL_DATE IS NULL)  --尚未出帳
                           ELSE
                              'N'
                           END) INHERIT_FLAG,
                           SYSDATE,
                           gvUSER,
                           SYSDATE,
                           gvUSER,
                           --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                           (SELECT ATTRIBUTE_VALUE
                              FROM FY_TB_CM_ATTRIBUTE_PARAM
                             WHERE ENTITY_TYPE   ='S' 
                               AND ENTITY_ID     = A.SUBSCR_ID 
                               AND (END_DATE IS NULL OR END_DATE=A.STATUS_DATE)
                               AND ATTRIBUTE_NAME='BILL_SUBSCR_ID') BILL_SUBSCR_ID --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                      FROM FY_TB_CM_SUBSCR A 
                     WHERE ACCT_ID = R_AT.ACCT_ID
                       AND INIT_ACT_DATE < gdBILL_DATE
                       AND NVL(END_DATE,gdBILL_END_DATE) >= gdBILL_FROM_DATE; 
       
                  --KEEP OFFER PARAM處理
                  gvSTEP := 'INSERT OFFER_PARAM.ACCT_ID='||TO_CHAR(R_AT.ACCT_ID)||':';
                  INSERT INTO FY_TB_BL_BILL_OFFER_PARAM
                          (BILL_SEQ  ,
                           CYCLE,
                           CYCLE_MONTH,
                           SEQ_NO,
                           ACCT_ID,
                           OFFER_INSTANCE_ID,
                           OFFER_SEQ,
                           PARAM_NAME,
                           PARAM_VALUE,
                           EFF_DATE,
                           END_DATE,
                           overwrite_type,
                           CREATE_DATE,
                           CREATE_USER,
                           UPDATE_DATE,
                           UPDATE_USER)
                    SELECT gnBILL_SEQ,
                           gnCYCLE,
                           gnCYCLE_MONTH,
                           A.SEQ_NO,
                           A.ACCT_ID,
                           A.OFFER_INSTANCE_ID,
                           A.OFFER_SEQ,
                           A.PARAM_NAME,
                           A.PARAM_VALUE,
                           A.EFF_DATE,
                           A.END_DATE,
                           overwrite_type,
                           SYSDATE,
                           gvUSER,
                           SYSDATE,
                           gvUSER
                      FROM FY_TB_BL_OFFER_PARAM A
                     WHERE ACCT_ID   = R_AT.ACCT_ID
                       AND EFF_DATE  < gdBILL_DATE
                       --AND NVL(END_DATE,gdBILL_END_DATE) > gdBILL_FROM_DATE
                       AND NVL(END_DATE,gdBILL_END_DATE) >= add_months(gdBILL_FROM_DATE,-6) --2023/08/02 MODIFY FOR SR260229_Project-M Fixed line Phase I_修改BILL_OFFER_PARAM抓取範圍，納入END_DATE等於BILL_FROM_DATE --2023/08/21 MODIFY FOR SR260229_Project-M Fixed line Phase I_修改BILL_OFFER_PARAM抓取範圍，BACKDATE最多6個月
                       AND (PARAM_NAME IN ('DEVICE_COUNT','InsuranceID') OR  --服務數量 --2020/06/09 MODIFY SR226548_遠傳(遠欣)企業客服新服務系統建置
                            (END_DATE IS NULL OR TRUNC(END_DATE) IN (SELECT TRUNC(END_DATE)
                                                                       FROM FY_TB_BL_ACCT_PKG
                                                                      WHERE ACCT_ID  =A.ACCT_ID
                                                                        AND ACCT_KEY =R_AT.ACCT_KEY
                                                                        AND OFFER_SEQ=A.OFFER_SEQ)
                            ) OR  --2023/12/29 MODIFY FOR SR260229_Project-M Fixed line Phase 1.1，後收DFC退款，DFC取得BACKDATE議價資料
                            (TRUNC(END_DATE) NOT IN (SELECT TRUNC(END_DATE)
                                                                       FROM FY_TB_BL_ACCT_PKG
                                                                      WHERE ACCT_ID  =A.ACCT_ID
                                                                        AND END_RSN = 'DFC'
                                                                        AND STATUS = 'OPEN'
                                                                        AND ACCT_KEY =R_AT.ACCT_KEY
                                                                        AND OFFER_SEQ=A.OFFER_SEQ)
                            ));
                  
               gvSTEP := 'GET SUBSCR_CNT'; --2020/06/30 MODIFY FOR MPBS_Migration  搬移位置
               --FOR R_SUB IN C_SUB(R_AT.ACCT_ID, gdBILL_FROM_DATE, gdBILL_END_DATE) LOOP --2019/06/30 MODIFY FY_TB_CM_SUBSCR cancel status時間判斷
               FOR R_SUB IN C_SUB(R_AT.ACCT_ID) LOOP --2019/06/30 MODIFY FY_TB_CM_SUBSCR cancel status時間判斷
                  IF R_SUB.STATUS='A' THEN
                     NU_ATV_CNT := NU_ATV_CNT + R_SUB.CNT;
                  ELSIF R_SUB.STATUS='S' THEN
                     NU_SUS_CNT := NU_SUS_CNT + R_SUB.CNT;
                  ELSE
                     NU_CAN_CNT := NU_CAN_CNT + R_SUB.CNT;
                  END IF;
               END LOOP;
               NU_CNT := NU_SUS_CNT + NU_CAN_CNT + NU_ATV_CNT;
               NU_SUB_CNT  := NU_CNT;
               --PERM_PRINTING_CAT CHECK
               IF gvUSER!='MPBL' THEN --2020/06/30 MODIFY FOR MPBS_Migration  ADD gvUSER=MPBL判別
                  --大額客戶
                  BEGIN
                     --SELECT 'L' 
                     --  INTO CH_PERM_PRINTING_CAT
                     --  FROM FY_TB_CM_CUSTOMER
                     -- WHERE CUST_ID  =R_AT.CUST_ID
                     --   AND cust_type='D';
                     SELECT distinct 'L' --2019/06/30 MODIFY skip_bill 大額客戶SQL --2019/08/29 MODIFY skip_bill 大額客戶SQL，修正同一cust下多acct會誤判為一般客戶
                       INTO ch_perm_printing_cat
                       FROM fy_tb_cm_customer a,
                            fy_tb_bl_account b,
                            fy_tb_cm_prof_link c,
                            fy_tb_bl_cust_cycle d
                      WHERE a.cust_id = r_at.cust_id
                        AND a.cust_id = b.cust_id
                        AND a.cust_id = d.cust_id
                        AND b.bl_status = 'OPEN'
                        AND c.entity_type = 'A'
                        AND c.link_type = 'A'
                        AND c.elem5 = '2'
                        AND c.entity_id = b.acct_id
                        AND a.CYCLE = gncycle
                        AND a.CYCLE = d.CYCLE;
                  EXCEPTION WHEN OTHERS THEN
                     CH_PERM_PRINTING_CAT := 'N';
                  END;
                  /*  --2020/06/30 MODIFY FOR MPBS_Migration  搬移位置
                  gvSTEP := 'GET SUBSCR_CNT';
                  --FOR R_SUB IN C_SUB(R_AT.ACCT_ID, gdBILL_FROM_DATE, gdBILL_END_DATE) LOOP --2019/06/30 MODIFY FY_TB_CM_SUBSCR cancel status時間判斷
                  FOR R_SUB IN C_SUB(R_AT.ACCT_ID) LOOP --2019/06/30 MODIFY FY_TB_CM_SUBSCR cancel status時間判斷
                     IF R_SUB.STATUS='A' THEN
                        NU_ATV_CNT := NU_ATV_CNT + R_SUB.CNT;
                     ELSIF R_SUB.STATUS='S' THEN
                        NU_SUS_CNT := NU_SUS_CNT + R_SUB.CNT;
                     ELSE
                        NU_CAN_CNT := NU_CAN_CNT + R_SUB.CNT;
                     END IF;
                  END LOOP;
                  NU_CNT := NU_SUS_CNT + NU_CAN_CNT + NU_ATV_CNT;
                  NU_SUB_CNT  := NU_CNT;
                  */
                  IF NU_CNT<>0 THEN
                     IF NU_CNT=NU_CAN_CNT THEN
                        CH_PERM_PRINTING_CAT := 'X';
                     ELSIF NU_CNT=NU_SUS_CNT THEN
                        CH_PERM_PRINTING_CAT := 'T';
                     END IF;
                  END IF;
               END IF; --2020/06/30 MODIFY FOR MPBS_Migration ADD gvUSER=MPBL判別
            ELSE
               CH_PERM_PRINTING_CAT := 'X';
            END IF;  --R_AT.LAST_BILL_SEQ IS NULL
            
            IF gvUSER<>'MPBL' THEN  --2020/06/30 MODIFY FOR MPBS_Migration ADD 排除gvUSER=MPBL
               --CHECK 欠費120天
               gvSTEP := 'CHECK 欠費120天:';
               SELECT /*+ INDEX(f FET1_INVOICE_P_1IX) */
                      DECODE(COUNT(1),0,CH_PERM_PRINTING_CAT,'M')
                 INTO CH_PERM_PRINTING_CAT
                 FROM FET1_INVOICE f,
                      FY_TB_BL_BILL_CNTRL C
                WHERE f.Partition_Id =mod(R_AT.ACCT_ID,10)
                  --and f.period_key   =c.bill_period  --2020/06/30 MODIFY FOR MPBS_Migration ADD 移除欠款120天條件for NPEP 2.1
                  and f.account_id = R_AT.ACCT_ID
                  AND f.cycle_code = gnCYCLE
                  AND NVL(f.invoice_balance, 0) > 0
                  AND NVL(f.invoice_type, 'BILL') = 'BILL'
                  AND f.invoice_status = 'O'
                  AND f.cycle_year  = TO_NUMBER(substr(C.BILL_PERIOD,1,4))
                  AND f.cycle_month = c.CYCLE_MONTH
                  AND f.cycle_code  = c.cycle
                  AND c.BILL_end_date + 1 < gdBILL_DATE - 120;
               --詐欺戶
               SELECT COUNT(1)
                 INTO NU_CNT
                 FROM FY_TB_CM_SUBSCR
                WHERE ACCT_ID=R_AT.ACCT_ID
                  AND STATUS='C'
                  AND RSN_CODE IN ('FI01', 'C10', '201', 'F01');
               IF NU_CNT>0 THEN
                  CH_PERM_PRINTING_CAT := 'F';
               END IF;
               --ACCT_GROUP=MV處理
               gvSTEP := 'ACCT_GROUP=MV處理:';
               SELECT DECODE(COUNT(1),0,R_AT.ACCT_GROUP,'MV')
                 INTO R_AT.ACCT_GROUP
                 FROM FY_TB_BL_BILL_SUB A
                WHERE BILL_SEQ    =gnBILL_SEQ
                  AND CYCLE       =gnCYCLE
                  AND CYCLE_MONTH =gnCYCLE_MONTH
                  AND ACCT_ID     =R_AT.ACCT_ID
                  AND ACCT_KEY    =R_AT.ACCT_KEY
                  AND INHERIT_FLAG='Y'
                  AND INIT_RSN_CODE in (SELECT lookup_code FROM fy_tb_cm_lookup_code WHERE lookup_type IN ('MARKETMOVE','PRODUCTMIG')) --2021/06/15 MODIFY FOR 小額預繳處理  --2019/12/12 MODIFY SR220754_AI Star增加MV A2A條件
                  AND PRE_SUB_ID IS NOT NULL;
               
            --2021/06/15 MODIFY FOR 小額預繳處理  ADD小額預繳折扣是否可抵一律不看reason code
            ELSE
               --ACCT_GROUP=MV處理
               gvSTEP := 'ACCT_GROUP=MV處理:';
               SELECT DECODE(COUNT(1),0,R_AT.ACCT_GROUP,'MV')
                 INTO R_AT.ACCT_GROUP
                 FROM FY_TB_BL_BILL_SUB A
                WHERE BILL_SEQ    =gnBILL_SEQ
                  AND CYCLE       =gnCYCLE
                  AND CYCLE_MONTH =gnCYCLE_MONTH
                  AND ACCT_ID     =R_AT.ACCT_ID
                  AND ACCT_KEY    =R_AT.ACCT_KEY
                  AND INHERIT_FLAG='Y'
                  AND PRE_SUB_ID IS NOT NULL;
            END IF; --2020/06/30 MODIFY FOR MPBS_Migration  gvUSER<>'MPBL'

            --PRODUCTION_TYPE處理 (首期、正常、末期、末期之後,帳單類型 'FR', 'RG', 'FN', 'RF, 'DR')
            IF R_AT.FIRST_BILL_SEQ IS NULL THEN
               CH_PRODUCTION_TYPE := 'FR';
            ELSIF R_AT.LAST_BILL_SEQ IS NOT NULL THEN
               CH_PRODUCTION_TYPE := 'RF';
            ELSIF R_AT.STATUS='C' THEN
               CH_PRODUCTION_TYPE := 'FN';
            ELSE
               CH_PRODUCTION_TYPE := 'RG';
            END IF;

            ---INSERT BILL_ACCT
            gvSTEP := 'INSERT BILL_ACCT.ACCT_ID='||TO_CHAR(R_AT.ACCT_ID)||':';
            INSERT INTO FY_TB_BL_BILL_ACCT
                       (BILL_SEQ,
                        CYCLE,
                        CYCLE_MONTH,
                        ACCT_ID,
                     --   ACCT_KEY, 為虛擬欄位
                        CUST_ID,
                        OU_ID,
                        SUBSCR_CNT,
                        ACCT_GROUP,
                        BILL_CURRENCY,
                        ACCT_STATUS,
                        PERM_PRINTING_CAT,
                        ACCT_CATEGORY,
                        PRODUCTION_TYPE,
                        PRE_BILL_NBR,
                        PRE_BILL_AMT,
                        PRE_CHRG_AMT,
                        BALANCE,
                        BALANCE_TEST,
                        ERR_MESG,
                        CONFIRM_ID,
                        PRE_ACCT_ID,
                        BILL_STATUS,
                        CREATE_DATE,
                        CREATE_USER,
                        UPDATE_DATE,
                        UPDATE_USER)
                  VALUES
                       (gnBILL_SEQ,
                        gnCYCLE,
                        gnCYCLE_MONTH,
                        R_AT.ACCT_ID,
                      --  R_AT.ACCT_KEY,
                        R_AT.CUST_ID,
                        R_AT.OU_ID,
                        NU_SUB_CNT,   ---SUBSCR_CNT
                        R_AT.ACCT_GROUP,
                        R_AT.CURRENCY,
                        R_AT.STATUS,
                        CH_PERM_PRINTING_CAT,
                        R_AT.ACCT_CATEGORY,
                        CH_PRODUCTION_TYPE,
                        R_AT.PRE_BILL_NBR,
                        R_AT.PRE_BILL_AMT,
                        R_AT.PRE_CHRG_AMT,
                        NULL,  --BALANCE,
                        NULL,  --BALANCE_TEST,
                        NULL,  --ERR_MESG,
                        NULL,  --CONFIRM_ID,
                        DECODE(R_AT.ACCT_GROUP,'MV',1,NULL),
                        'CL',
                        SYSDATE,
                        gvUSER,
                        SYSDATE,
                        gvUSER);
            --OC處理
            gvSTEP := 'UPDATE BILL_CI.ACCT_ID='||TO_CHAR(R_AT.ACCT_ID)||':';
            IF gvUSER='MPBL' THEN  --2020/06/30 MODIFY FOR MPBS_Migration 將OC寫入實體欄位
                UPDATE FY_TB_BL_BILL_CI a SET 
                    a.CHRG_FROM_DATE =NVL (to_date(REGEXP_SUBSTR (a.dynamic_attribute,'.*Period start date=([0-9]+).*',1,1,NULL,1),'yyyymmdd'),NULL),
                    a.CHRG_END_DATE  =NVL (to_date(REGEXP_SUBSTR (a.dynamic_attribute,'.*Period end date=([0-9]+).*',1,1,NULL,1),'yyyymmdd')-1,NULL),                
                    a.TXN_ID         =NVL (REGEXP_SUBSTR (a.dynamic_attribute,'.*InsuranceID=([^#]*).*',1,1,NULL,1),NULL),
                    a.UPDATE_DATE    =SYSDATE,
                    a.UPDATE_USER    =gvUSER
                  WHERE ROWID IN (SELECT ROWID FROM FY_TB_BL_BILL_CI b WHERE
                    b.CYCLE            =gnCYCLE
                    AND b.CYCLE_MONTH  =gnCYCLE_MONTH
                    AND b.ACCT_ID      =R_AT.ACCT_ID
                    AND b.ACCT_KEY     =R_AT.ACCT_KEY
                    AND b.SOURCE       ='OC'
                    AND NVL (REGEXP_SUBSTR (a.dynamic_attribute,'.*InsuranceID=([^#]*).*',1,1,NULL,1),NULL) IS NOT NULL
                    AND b.TXN_ID IS NULL
                    AND b.BILL_SEQ IS NULL);
            END IF; --2020/06/30 MODIFY FOR MPBS_Migration 將OC寫入實體欄位
            
            UPDATE FY_TB_BL_BILL_CI A SET BILL_SEQ      =gnBILL_SEQ,
                                          UPDATE_DATE   =SYSDATE,
                                          UPDATE_USER   =gvUSER,
                                          --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
                                          BILL_SUBSCR_ID=DECODE(SUBSCR_ID,NULL,NULL,(SELECT BILL_SUBSCR_ID 
                                                                                       FROM FY_TB_BL_BILL_SUB 
                                                                                      WHERE BILL_SEQ   =gnBILL_SEQ
                                                                                        AND CYCLE      =A.CYCLE
                                                                                        AND CYCLE_MONTH=A.CYCLE_MONTH
                                                                                        AND ACCT_ID    =A.ACCT_ID
                                                                                        AND ACCT_KEY   =A.ACCT_KEY
                                                                                        AND SUBSCR_ID  =A.SUBSCR_ID))               
                                  WHERE CYCLE       =gnCYCLE
                                    AND CYCLE_MONTH =gnCYCLE_MONTH
                                    AND ACCT_ID     =R_AT.ACCT_ID
                                    AND ACCT_KEY    =R_AT.ACCT_KEY
                                    AND BILL_SEQ IS NULL;
         END IF; --2020/06/30 MODIFY FOR MPBS_Migration gvUSER<>'MPBL' OR (gvUSER='MPBL' AND R_AT.UNBILL_FLAG='N')                       
      END LOOP; --C_AT
      
      --PRE_SUB_ID ACCT_GROUP 處理
      FOR R1 IN C1 LOOP
         gvSTEP := 'PRE_SUB_ID UPDATE BILL_ACCT:';
         UPDATE FY_TB_BL_BILL_ACCT SET ACCT_GROUP='MV'
                    WHERE BILL_SEQ    =gnBILL_SEQ
                      AND CYCLE       =gnCYCLE
                      AND CYCLE_MONTH =gnCYCLE_MONTH
                      AND ACCT_KEY    =MOD(R1.ACCT_ID,100)
                      AND ACCT_ID     =R1.ACCT_ID;
      END LOOP;
      --UPDATE PRE_ACCT 處理 --2019/12/31 MODIFY 新增cursor C2，取出新舊Account&SUB關聯
      FOR R2 IN C2 LOOP
         gvSTEP := 'UPDATE PRE_ACCT:';
         UPDATE FY_TB_BL_BILL_ACCT SET PRE_ACCT_ID=R2.OLD_ACCT
                    WHERE BILL_SEQ    =gnBILL_SEQ
                      AND CYCLE       =gnCYCLE
                      AND CYCLE_MONTH =gnCYCLE_MONTH
                      AND ACCT_KEY    =MOD(R2.NEW_ACCT,100)
                      AND ACCT_ID     =R2.NEW_ACCT;
      END LOOP;
      DBMS_OUTPUT.Put_Line('CNT='||TO_CHAR(NU_ACCT_CNT));
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN on_err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END KEEP_ACCT;

   /*************************************************************************
      PROCEDURE : MARKET_MOVE
      PURPOSE :   MARKET_MOVE不同CYCLE ACCT_PKG 處理
      DESCRIPTION : MARKET_MOVE不同CYCLE ACCT_PKG 處理
      PARAMETER:

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理 
   **************************************************************************/
   PROCEDURE MARKET_MOVE IS

      CURSOR C_AT IS
         SELECT BILL_SEQ,
                CYCLE,
                CYCLE_MONTH,
                ACCT_ID,
                NVL(ACCT_GROUP,'A') ACCT_GROUP,
                ACCT_KEY
           FROM FY_TB_BL_BILL_ACCT BA
          WHERE BA.BILL_SEQ   =gnBILL_SEQ
            AND BA.CYCLE      =gnCYCLE
            AND BA.CYCLE_MONTH=gnCYCLE_MONTH
            AND BA.ACCT_GROUP ='MV'
          ORDER BY ACCT_ID;

      CURSOR C_SUB(iACCT_ID NUMBER) IS
         SELECT SUBSCR_ID,
                PRE_SUB_ID,
                INHERIT_FLAG
           FROM FY_TB_BL_BILL_SUB
          WHERE BILL_SEQ   =gnBILL_SEQ
            AND CYCLE      =gnCYCLE
            AND CYCLE_MONTH=gnCYCLE_MONTH
            AND ACCT_ID    =iACCT_ID
            AND ACCT_KEY   =MOD(iACCT_ID,100);

      CURSOR C_PKG(iACCT_ID NUMBER, iSUBSCR_ID NUMBER) IS
         SELECT ROWID,
                ACCT_PKG_SEQ,
                TOTAL_DISC_AMT,
                VALIDITY_PERIOD,
                CUR_BAL_QTY,
                PRE_PKG_SEQ ,
                TRANS_IN_DATE,
                TRANS_IN_QTY
           FROM FY_TB_BL_ACCT_PKG
          WHERE ACCT_ID       =iACCT_ID
            AND ACCT_KEY      =MOD(iACCT_ID,100)
            AND OFFER_LEVEL   ='S'
            AND OFFER_LEVEL_ID=iSUBSCR_ID
            AND PRE_PKG_SEQ IS NOT NULL
            AND TRANS_IN_DATE IS NULL;
            
      ----2021/06/15 MODIFY FOR 小額預繳處理 ADD MV多CYCLE處理
      CURSOR C1 IS
         SELECT PKG.ACCT_PKG_SEQ
           FROM FY_TB_BL_ACCT_PKG PKG,
                FY_TB_BL_BILL_MV_SUB MV
          WHERE MV.BILL_SEQ = gnBILL_SEQ
            AND MV.PRE_CYCLE IS NOT NULL
            AND MV.ACCT_ID  =PKG.ACCT_ID
            AND MV.SUBSCR_ID=PKG.OFFER_LEVEL_ID
            AND PKG.PRE_PKG_SEQ IS NOT NULL;
                 
      CURSOR C_MV(iACCT_PKG_SEQ NUMBER) IS
         SELECT DISTINCT PKG.ACCT_ID
           FROM (SELECT * FROM FY_TB_BL_ACCT_PKG
                    START WITH ACCT_PKG_SEQ  =iACCT_PKG_SEQ
                  CONNECT BY PRIOR PRE_PKG_SEQ=ACCT_PKG_SEQ) PKG
          WHERE EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                               WHERE BILL_SEQ = gnBILL_SEQ
                                 AND ACCT_ID=PKG.ACCT_ID
                                 AND ACCT_GROUP<>'MV');    

      NU_CNT             NUMBER  :=0;
      NU_MV_CNT          NUMBER  :=0;  --2021/06/15 MODIFY FOR 小額預繳處理
      NU_CYCLE           FY_TB_BL_CYCLE.CYCLE%TYPE;
      NU_PRE_ACCT_ID     FY_TB_BL_ACCOUNT.ACCT_ID%TYPE;
      DT_START_DATE      DATE;
      DT_END_DATE        DATE;
      On_Err             EXCEPTION;
   BEGIN
      ----MARTET MOVE ACCT_PKG處理
      FOR R_AT IN C_AT LOOP
         FOR R_SUB IN C_SUB(R_AT.ACCT_ID) LOOP
            NU_PRE_ACCT_ID := NULL;
            NU_CYCLE       := NULL;
            IF R_SUB.INHERIT_FLAG='N' THEN
               R_SUB.PRE_SUB_ID := NULL;
            END IF;
            --GET CYCLE
            IF R_SUB.PRE_SUB_ID IS NOT NULL THEN
               gvSTEP := 'GET_CYCLE.PRE_SUB_ID='||TO_CHAR(R_SUB.PRE_SUB_ID)||':';
               SELECT DECODE(CM.CYCLE,gnCYCLE,NULL,CM.CYCLE),
                      SU.ACCT_ID
                 INTO NU_CYCLE,
                      NU_PRE_ACCT_ID
                 FROM FY_TB_CM_SUBSCR SU,
                      FY_TB_CM_CUSTOMER CM
                WHERE SU.SUBSCR_ID=R_SUB.PRE_SUB_ID
                  AND CM.CUST_ID  =SU.CUST_ID;
               IF NU_CYCLE IS NOT NULL THEN
                  --不同CYCLE是否尚未出帳結束
                  SELECT COUNT(1)
                    INTO NU_CNT
                    FROM FY_TB_BL_BILL_CNTRL
                   WHERE CYCLE=NU_CYCLE
                     AND STATUS<>'CN';
               END IF;
               --不同CYCLE&無出帳中
               IF NU_CYCLE IS NOT NULL AND NU_CNT=0 THEN
                  FOR R_PKG IN C_PKG(R_AT.ACCT_ID, R_SUB.SUBSCR_ID) LOOP
                     --2021/06/15 MODIFY FOR 小額預繳處理 ADD NU_MV_CNT判別
                     SELECT COUNT(1) INTO NU_MV_CNT
                       FROM ( SELECT PKG.ACCT_PKG_SEQ, PKG.ACCT_ID, AT.CYCLE
                                FROM (SELECT * FROM FY_TB_BL_ACCT_PKG
                                        START WITH ACCT_PKG_SEQ   =R_PKG.ACCT_PKG_SEQ
                                      CONNECT BY PRIOR PRE_PKG_SEQ=ACCT_PKG_SEQ) PKG,
                                     FY_TB_BL_ACCOUNT AT
                               WHERE AT.ACCT_ID=PKG.ACCT_ID
                                 AND AT.ACCT_ID<>R_AT.ACCT_ID) MV
                       WHERE CYCLE=gnCYCLE;
                     IF NU_MV_CNT=0 THEN --2021/06/15 MODIFY FOR 小額預繳處理
                        gvSTEP := 'CALL MARKET_PKG.ACCT_ID='||TO_CHAR(R_AT.ACCT_ID)||',ACCT_PKG_SEQ='||TO_CHAR(R_PKG.ACCT_PKG_SEQ)||':';
                        Fy_Pg_Bl_Bill_Util.MARKET_PKG(gnCYCLE ,
                                                      R_PKG.ACCT_PKG_SEQ,
                                                      gdBILL_FROM_DATE,
                                                      'B',         --2021/06/15 MODIFY FOR 小額預繳處理
                                                      gnBILL_SEQ,  --2021/06/15 MODIFY FOR 小額預繳處理
                                                      gvUSER,
                                                      gvERR_CDE ,
                                                      gvERR_MSG );
                        IF gvERR_CDE<>'0000' THEN
                           gvSTEP := SUBSTR('CALL MARKET_PKG:'||gvERR_MSG,1,250);
                        END IF;
                     END IF;  --NU_MV_CNT --2021/06/15 MODIFY FOR 小額預繳處理 ADD NU_MV_CNT判別  
                  END LOOP;  --C_PKG
               END IF;  --NU_CYCLE
            END IF; --R_SUB.PRE_SUBSCR_ID IS NOT NULL
            --MV順序處理
            gvSTEP := 'INSERT BILL_MV_SUB.SUBSCR_ID='||TO_CHAR(R_SUB.SUBSCR_ID)||':';
            INSERT INTO FY_TB_BL_BILL_MV_SUB
                             (BILL_SEQ,
                              CYCLE,
                              CYCLE_MONTH,
                              ACCT_ID,
                              SUBSCR_ID,
                              PRE_ACCT_ID,
                              PRE_SUBSCR_ID,
                              PRE_CYCLE,
                              CREATE_DATE,
                              CREATE_USER,
                              UPDATE_DATE,
                              UPDATE_USER)
                        VALUES
                             (R_AT.BILL_SEQ,
                              R_AT.CYCLE,
                              R_AT.CYCLE_MONTH,
                              R_AT.ACCT_ID,
                              R_SUB.SUBSCR_ID,
                              NU_PRE_ACCT_ID,
                              R_SUB.PRE_SUB_ID,
                              NU_CYCLE,
                              SYSDATE,
                              gVUSER,
                              SYSDATE,
                              gvUSER);
         END LOOP;  --C_SUB
      END LOOP; --C_AT
      
      ----2021/06/15 MODIFY FOR 小額預繳處理 ADD MV多CYCLE處理
      FOR R1 IN C1 LOOP
         gvSTEP := '**MUTI_CYCLE UPDATE BILL_ACCT.acct_pjg_seq='||TO_CHAR(R1.ACCT_PKG_SEQ)||':';  
         FOR R_MV IN C_MV(R1.ACCT_PKG_SEQ) LOOP
            gvSTEP := 'MUTI_CYCLE UPDATE BILL_ACCT.ACCT_ID='||TO_CHAR(R_MV.ACCT_ID)||':';    
            UPDATE FY_TB_BL_BILL_ACCT SET ACCT_GROUP='MV'
                       WHERE BILL_SEQ    =gnBILL_SEQ
                         AND CYCLE       =gnCYCLE
                         AND CYCLE_MONTH =gnCYCLE_MONTH
                         AND ACCT_KEY    =MOD(R_MV.ACCT_ID,100)
                         AND ACCT_ID     =R_MV.ACCT_ID;
            gvSTEP := 'INSERT MUTI_MV_SUB.ACCT_ID='||TO_CHAR(R_MV.ACCT_ID)||':';
            INSERT INTO FY_TB_BL_BILL_MV_SUB
                                (BILL_SEQ,
                                 CYCLE,
                                 CYCLE_MONTH,
                                 ACCT_ID,
                                 SUBSCR_ID,
                                 PRE_ACCT_ID,
                                 PRE_SUBSCR_ID,
                                 PRE_CYCLE,
                                 CREATE_DATE,
                                 CREATE_USER,
                                 UPDATE_DATE,
                                 UPDATE_USER)
                          SELECT BILL_SEQ,
                                 CYCLE,
                                 CYCLE_MONTH,
                                 ACCT_ID,
                                 SUBSCR_ID,
                                 NULL,
                                 NULL,
                                 NULL,
                                 CREATE_DATE,
                                 CREATE_USER,
                                 UPDATE_DATE,
                                 UPDATE_USER 
                            FROM FY_TB_BL_BILL_SUB
                           WHERE BILL_SEQ   =gnBILL_SEQ
                             AND CYCLE      =gnCYCLE
                             AND CYCLE_MONTH=gnCYCLE_MONTH
                             AND ACCT_ID    =R_MV.ACCT_ID
                             AND ACCT_KEY   =MOD(R_MV.ACCT_ID,100);          
            
         END LOOP;  --C_MV
      END LOOP; --C1
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN on_err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END MARKET_MOVE;

   /*************************************************************************
      PROCEDURE : CUT_GROUP
      PURPOSE :   CUT BILL_ACCT ACCT_GROUP處理
      DESCRIPTION : CUT BILL_ACCT ACCT_GROUP處理
      PARAMETER:

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE CUT_GROUP IS

      CURSOR C_AT(iBILL_SEQ NUMBER, iCYCLE NUMBER, iCYCLE_MONTH NUMBER) IS
         SELECT ROWID, ACCT_ID, nvl(SUBSCR_CNT,0) subscr_cnt
           FROM FY_TB_BL_BILL_ACCT BA
          WHERE BA.BILL_SEQ   =iBILL_SEQ
            AND BA.CYCLE      =iCYCLE
            AND BA.CYCLE_MONTH=iCYCLE_MONTH
            AND BA.ACCT_GROUP<>'MV'
          ORDER BY ACCT_KEY, ACCT_ID;

      NU_CNT             NUMBER  :=0;
      NU_GROUP_CNT       NUMBER;
      NU_PROCESS_NO      NUMBER;
      DT_START_DATE      DATE;
      DT_END_DATE        DATE;
      On_Err             EXCEPTION;
   BEGIN
      --ADD 888, 999
      FOR i IN 1 .. 2 LOOP
         IF I=1 THEN
            NU_PROCESS_NO := 888;
         ELSE
            NU_PROCESS_NO := 999;
         END IF;
         SELECT COUNT(1)
           INTO NU_CNT
           FROM FY_TB_BL_CYCLE_PROCESS
          WHERE CYCLE     =gnCYCLE
            AND PROCESS_NO=NU_PROCESS_NO;
         IF NU_CNT=0 THEN
            INSERT INTO FY_TB_BL_CYCLE_PROCESS
                         (CYCLE ,
                          PROCESS_NO,
                          ACCT_GROUP,
                          CREATE_DATE,
                          CREATE_USER,
                          UPDATE_DATE,
                          UPDATE_USER)
                     VALUES
                         (gnCYCLE ,
                          NU_PROCESS_NO,
                          DECODE(NU_PROCESS_NO,888,'MV','HOLD'),
                          SYSDATE,
                          gvUSER,
                          SYSDATE,
                          gvUSER);
         END IF;
      END LOOP;
      --清除PROCESS
      gvSTEP := 'DELETE PROCESS.CYCLE='||TO_CHAR(gnCYCLE)||':';
      DELETE FY_TB_BL_CYCLE_PROCESS
        WHERE CYCLE=gnCYCLE
          AND PROCESS_NO NOT IN (999,888);

      SELECT SUM(nvl(SUBSCR_CNT,0))
        INTO NU_CNT
        FROM FY_TB_BL_BILL_ACCT BA
       WHERE BA.BILL_SEQ   =gnBILL_SEQ
         AND BA.CYCLE      =gnCYCLE
         AND BA.CYCLE_MONTH=gnCYCLE_MONTH
         AND BA.ACCT_GROUP<>'MV';

      --GET CUT_PROCESS
      gvSTEP := 'GET CUT_PROCESS.LOOKUP_CODE:';
      SELECT ROUND(NU_CNT/NUM1)
        INTO NU_GROUP_CNT
        FROM FY_TB_SYS_LOOKUP_CODE
       WHERE LOOKUP_TYPE='CUT_GROUP'
         AND LOOKUP_CODE='PROCESS'
         AND NUM1>0;

      NU_PROCESS_NO := 1;
      NU_CNT        := 0;
      ----MARTET MOVE ACCT_PKG處理
      FOR R_AT IN C_AT(gnBILL_SEQ,gnCYCLE,gnCYCLE_MONTH) LOOP
         gvSTEP := 'UPDATE BILL_ACCT.ACCT_ID='||TO_CHAR(R_AT.ACCT_ID)||':';
         UPDATE FY_TB_BL_BILL_ACCT SET ACCT_GROUP='G'||LPAD(TO_CHAR(NU_PROCESS_NO),3,0)
                                      WHERE ROWID=R_AT.ROWID;
         NU_CNT := NU_CNT+R_AT.SUBSCR_CNT;
         IF NU_CNT>=NU_GROUP_CNT THEN
            gvSTEP := 'INSERT CYCLE_PROCESS:';
            INSERT INTO FY_TB_BL_CYCLE_PROCESS
                         (CYCLE ,
                          PROCESS_NO,
                          ACCT_GROUP,
                          CREATE_DATE,
                          CREATE_USER,
                          UPDATE_DATE,
                          UPDATE_USER)
                     VALUES
                         (gnCYCLE ,
                          NU_PROCESS_NO,
                          'G'||LPAD(TO_CHAR(NU_PROCESS_NO),3,0),
                          SYSDATE,
                          gvUSER,
                          SYSDATE,
                          gvUSER);
            NU_PROCESS_NO := NU_PROCESS_NO + 1;
            NU_CNT := 0;
         END IF;
      END LOOP; --C_AT
      if nu_cnt>0 then
         gvSTEP := 'INSERT CYCLE_PROCESS:';
         INSERT INTO FY_TB_BL_CYCLE_PROCESS
                         (CYCLE ,
                          PROCESS_NO,
                          ACCT_GROUP,
                          CREATE_DATE,
                          CREATE_USER,
                          UPDATE_DATE,
                          UPDATE_USER)
                     VALUES
                         (gnCYCLE ,
                          NU_PROCESS_NO,
                          'G'||LPAD(TO_CHAR(NU_PROCESS_NO),3,0),
                          SYSDATE,
                          gvUSER,
                          SYSDATE,
                          gvUSER);
      end if;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN on_err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END CUT_GROUP;

END FY_PG_BL_BILL_CUTDATE;
/