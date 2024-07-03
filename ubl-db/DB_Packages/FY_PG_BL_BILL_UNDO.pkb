CREATE OR REPLACE PACKAGE BODY HGBBLAPPO.FY_PG_BL_BILL_UNDO IS                
   
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL PROCESS_NO UNDO 處理
      DESCRIPTION : BL BILL PROCESS_NO UNDO 處理
      PARAMETER:
            PI_BILL_SEQ           :出帳序號
            PI_PROCESS_NO         :執行序號
            PI_ACCT_GROUP         :客戶類型OR ACCT_LIST.TYPE
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)  
            PI_USER               :執行USER_ID         
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      4.1   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
   **************************************************************************/
   PROCEDURE MAIN(PI_BILL_SEQ       IN   NUMBER,
                  PI_PROCESS_NO     IN   NUMBER,
                  PI_ACCT_GROUP     IN   VARCHAR2,
                  PI_PROC_TYPE      IN   VARCHAR2 DEFAULT 'B',  
                  PI_USER           IN   VARCHAR2, 
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2) IS

      --抓取應出帳之ACCT_ID
      CURSOR C_AT(iCYCLE NUMBER, iCYCLE_MONTH NUMBER) IS
         SELECT AT.ACCT_ID,
                AT.CUST_ID,
                AT.OU_ID,
                'Y' UC_FLAG,
                NULL SUBSCR_ID,
                NULL PRE_ACCT_ID,
                NULL PRE_CYCLE
           FROM FY_TB_BL_BILL_ACCT AT
          WHERE AT.BILL_SEQ   =PI_BILL_SEQ
            AND AT.CYCLE      =iCYCLE
            AND AT.CYCLE_MONTH=iCYCLE_MONTH
            AND AT.ACCT_GROUP =PI_ACCT_GROUP 
            AND AT.ACCT_KEY   =MOD(AT.ACCT_ID,100)
            AND PI_PROCESS_NO <>999
            AND AT.BILL_STATUS<>'CN'
         --   AND ((PI_PROC_TYPE='B' AND AT.BILL_STATUS ='CL') OR
         --        (PI_PROC_TYPE='T' AND AT.BILL_STATUS<>'CN'))   
          UNION
         SELECT AT.ACCT_ID,
                AT.CUST_ID,
                AT.OU_ID,
                AL.UC_FLAG,
                NULL SUBSCR_ID,
                NULL PRE_ACCT_ID,
                NULL PRE_CYCLE
           FROM FY_TB_BL_ACCT_LIST AL,
                FY_TB_BL_BILL_ACCT AT
          WHERE AL.BILL_SEQ   =PI_BILL_SEQ
            AND AL.TYPE       =PI_ACCT_GROUP
            AND AT.BILL_SEQ   =AL.BILL_SEQ
            AND AT.CYCLE      =iCYCLE
            AND AT.CYCLE_MONTH=iCYCLE_MONTH
            AND AT.ACCT_KEY   =MOD(AT.ACCT_ID,100)
            AND AT.ACCT_ID    =AL.ACCT_ID
            AND PI_PROCESS_NO  =999
            AND AT.BILL_STATUS<>'CN'
         --   AND ((PI_PROC_TYPE='B' AND AT.BILL_STATUS ='CL') OR
         --        (PI_PROC_TYPE='T' AND AT.BILL_STATUS<>'CN'))                  
          ORDER BY ACCT_ID;
      
      CURSOR C_PKG(iACCT_ID NUMBER) IS
         SELECT ROWID,
                ACCT_PKG_SEQ,  
                PKG_TYPE_DTL,
                TOTAL_DISC_AMT,
                INIT_PKG_QTY,
                CUR_QTY,
                CUR_USE_QTY,
                CUR_BAL_QTY,
                TRANS_IN_QTY,  
                TRANS_IN_DATE, 
                TRANS_OUT_QTY, 
                TRANS_OUT_DATE, 
                test_TRANS_IN_QTY,  
                test_TRANS_IN_DATE, 
                test_TRANS_OUT_QTY, 
                test_TRANS_OUT_DATE, 
                OFFER_LEVEL,
                OFFER_LEVEL_ID,
                PREPAYMENT, 
                PRE_PKG_SEQ
           FROM FY_TB_BL_ACCT_PKG
          WHERE ACCT_ID    =iACCT_ID
            AND ACCT_KEY   =MOD(iACCT_ID,100)
            AND PI_BILL_SEQ=DECODE(PI_PROC_TYPE,'B',RECUR_SEQ,TEST_RECUR_SEQ);     
            
      ----2021/06/15 MODIFY FOR 小額預繳處理 ADD MV多CYCLE處理
      CURSOR C_MV(iACCT_ID NUMBER, iACCT_PKG_SEQ NUMBER) IS
         SELECT PKG.ACCT_PKG_SEQ, PKG.ACCT_ID, AT.CYCLE
           FROM (SELECT PKG.* 
                   FROM FY_TB_BL_ACCT_PKG PKG
                   START WITH ACCT_PKG_SEQ   =iACCT_PKG_SEQ
                 CONNECT BY PRIOR PRE_PKG_SEQ=ACCT_PKG_SEQ) PKG,
                 FY_TB_BL_ACCOUNT AT
          WHERE AT.ACCT_ID=PKG.ACCT_ID
            AND AT.ACCT_ID<>iACCT_ID
            AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_MV_SUB
                          WHERE BILL_SEQ=PI_BILL_SEQ
                            AND ACCT_ID =iACCT_ID
                            AND PRE_CYCLE IS NOT NULL);          
      NU_CNT             NUMBER;
      NU_CYCLE           NUMBER;
      NU_CYCLE_MONTH     NUMBER;
      CH_UC_FLAG         VARCHAR2(1);
      CH_STATUS          FY_TB_BL_BILL_CNTRL.STATUS%TYPE;
      CH_ACCT_GROUP      FY_TB_BL_BILL_ACCT.ACCT_GROUP%TYPE;
      CH_ERR_CDE         VARCHAR2(4);
      CH_ERR_MSG         VARCHAR2(250);
      CH_STEP            VARCHAR2(300);
      On_Err             EXCEPTION;
   BEGIN
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':FY_PG_BL_BILL_UNDO BEGIN');
      CH_STEP := 'GET CYCLE FROM BILL_CNTRL.BILL_SEQ:'||TO_CHAR(PI_BILL_SEQ);
      SELECT BC.CYCLE, TO_NUMBER(SUBSTR(BC.BILL_PERIOD,-2)), STATUS
        INTO NU_CYCLE, NU_CYCLE_MONTH, CH_STATUS
        FROM FY_TB_BL_BILL_CNTRL BC
       WHERE BC.BILL_SEQ     = PI_BILL_SEQ;
      IF PI_PROC_TYPE='B' AND CH_STATUS='CN' THEN
         CH_STEP := 'GET BILL_CNTRL.BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||',STATUS='||CH_STATUS||'無法執行';  
         PO_ERR_CDE := 'U001';
         RAISE ON_ERR;
      END IF;  
              
      --DELETE BILL_MAST
      IF PI_PROC_TYPE='B' THEN
         IF PI_PROCESS_NO=999 THEN
            CH_STEP := ':DELETE FY_TB_BL_BILL_PAID:'; --2020/06/30 MODIFY FOR MPBS_Migration
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_PAID A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND PROC_TYPE  =PI_PROC_TYPE
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT AL.ACCT_ID FROM FY_TB_BL_ACCT_LIST AL,
                                                        FY_TB_BL_BILL_ACCT BA
                                               WHERE AL.BILL_SEQ   =PI_BILL_SEQ
                                                 AND AL.TYPE       =PI_ACCT_GROUP
                                                 AND AL.ACCT_ID    =A.ACCT_ID
                                                 AND BA.BILL_SEQ   =AL.BILL_SEQ
                                                 AND BA.CYCLE      =A.CYCLE
                                                 AND BA.CYCLE_MONTH=A.CYCLE_MONTH
                                                 AND BA.ACCT_KEY   =MOD(AL.ACCT_ID,100)
                                                 AND BA.ACCT_ID    =AL.ACCT_ID
                                                 AND BA.BILL_STATUS<>'CN'); 
                                                 
            CH_STEP := ':DELETE FY_TB_BL_BILL_MAST:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_MAST A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT AL.ACCT_ID FROM FY_TB_BL_ACCT_LIST AL,
                                                        FY_TB_BL_BILL_ACCT BA
                                               WHERE AL.BILL_SEQ   =PI_BILL_SEQ
                                                 AND AL.TYPE       =PI_ACCT_GROUP
                                                 AND AL.ACCT_ID    =A.ACCT_ID
                                                 AND BA.BILL_SEQ   =AL.BILL_SEQ
                                                 AND BA.CYCLE      =A.CYCLE
                                                 AND BA.CYCLE_MONTH=A.CYCLE_MONTH
                                                 AND BA.ACCT_KEY   =MOD(AL.ACCT_ID,100)
                                                 AND BA.ACCT_ID    =AL.ACCT_ID
                                                 AND BA.BILL_STATUS<>'CN');
            CH_STEP := ':DELETE FY_TB_BL_BILL_BI:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_BI A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT AL.ACCT_ID FROM FY_TB_BL_ACCT_LIST AL,
                                                        FY_TB_BL_BILL_ACCT BA
                                               WHERE AL.BILL_SEQ   =PI_BILL_SEQ
                                                 AND AL.TYPE       =PI_ACCT_GROUP
                                                 AND AL.ACCT_ID    =A.ACCT_ID
                                                 AND BA.BILL_SEQ   =AL.BILL_SEQ
                                                 AND BA.CYCLE      =A.CYCLE
                                                 AND BA.CYCLE_MONTH=A.CYCLE_MONTH
                                                 AND BA.ACCT_KEY   =MOD(AL.ACCT_ID,100)
                                                 AND BA.ACCT_ID    =AL.ACCT_ID
                                                 AND BA.BILL_STATUS<>'CN'); 

            CH_STEP := ':DELETE FY_TB_BL_BILL_CI:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_CI A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT AL.ACCT_ID FROM FY_TB_BL_ACCT_LIST AL,
                                                        FY_TB_BL_BILL_ACCT BA
                                               WHERE AL.BILL_SEQ   =PI_BILL_SEQ
                                                 AND AL.TYPE       =PI_ACCT_GROUP
                                                 AND AL.ACCT_ID    =A.ACCT_ID
                                                 AND BA.BILL_SEQ   =AL.BILL_SEQ
                                                 AND BA.CYCLE      =A.CYCLE
                                                 AND BA.CYCLE_MONTH=A.CYCLE_MONTH
                                                 AND BA.ACCT_KEY   =MOD(AL.ACCT_ID,100)
                                                 AND BA.ACCT_ID    =AL.ACCT_ID
                                                 AND BA.BILL_STATUS<>'CN')
                     AND (SOURCE IN ('RC','DE') OR 
                          (SOURCE='UC' AND ACCT_ID IN (SELECT ACCT_ID FROM FY_TB_BL_ACCT_LIST
                                                        WHERE BILL_SEQ=PI_BILL_SEQ
                                                          AND TYPE    =PI_ACCT_GROUP
                                                          AND ACCT_ID =A.ACCT_ID
                                                          AND NVL(UC_FLAG,'N')='Y')
                           ));  
            CH_STEP := ':UPDATE FY_TB_BL_BILL_CI:';   
            UPDATE FY_TB_BL_BILL_CI A SET BI_SEQ=NULL
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT AL.ACCT_ID FROM FY_TB_BL_ACCT_LIST AL,
                                                            FY_TB_BL_BILL_ACCT BA
                                               WHERE AL.BILL_SEQ   =PI_BILL_SEQ
                                                 AND AL.TYPE       =PI_ACCT_GROUP
                                                 AND AL.ACCT_ID    =A.ACCT_ID
                                                 AND BA.BILL_SEQ   =AL.BILL_SEQ
                                                 AND BA.CYCLE      =NU_CYCLE
                                                 AND BA.CYCLE_MONTH=NU_CYCLE_MONTH
                                                 AND BA.ACCT_KEY   =MOD(AL.ACCT_ID,100)
                                                 AND BA.ACCT_ID    =AL.ACCT_ID
                                                 AND BA.BILL_STATUS<>'CN');                                     
            CH_STEP := ':UPDATE FY_TB_BL_BILL_ACCT:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            UPDATE FY_TB_BL_BILL_ACCT A SET BILL_STATUS ='CL',
                                            UPDATE_DATE =SYSDATE,
                                            UPDATE_USER =PI_USER
                                  WHERE BILL_SEQ   =PI_BILL_SEQ      
                                    AND CYCLE      =NU_CYCLE         
                                    AND CYCLE_MONTH=NU_CYCLE_MONTH 
                                    AND ACCT_KEY   =MOD(ACCT_ID,100) 
                                    AND EXISTS (SELECT AL.ACCT_ID FROM FY_TB_BL_ACCT_LIST AL
                                                      WHERE AL.BILL_SEQ   =PI_BILL_SEQ
                                                        AND AL.TYPE       =PI_ACCT_GROUP
                                                        AND AL.ACCT_ID    =A.ACCT_ID)
                                    AND BILL_STATUS<>'CN';         
         ELSE    
            CH_STEP := ':DELETE FY_TB_BL_BILL_PAID:'; --2020/06/30 MODIFY FOR MPBS_Migration
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_PAID A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND PROC_TYPE  =PI_PROC_TYPE
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_BILL_ACCT 
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND CYCLE      =A.CYCLE
                                                 AND CYCLE_MONTH=A.CYCLE_MONTH
                                                 AND ACCT_KEY   =A.ACCT_KEY
                                                 AND ACCT_ID    =A.ACCT_ID
                                                 AND ACCT_GROUP =PI_ACCT_GROUP
                                                 AND BILL_STATUS<>'CN');
                                                 
            CH_STEP := ':DELETE FY_TB_BL_BILL_MAST:';    
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);                                                                           
            DELETE FY_TB_BL_BILL_MAST    A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_BILL_ACCT 
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND CYCLE      =A.CYCLE
                                                 AND CYCLE_MONTH=A.CYCLE_MONTH
                                                 AND ACCT_KEY   =A.ACCT_KEY
                                                 AND ACCT_ID    =A.ACCT_ID
                                                 AND ACCT_GROUP =PI_ACCT_GROUP
                                                 AND BILL_STATUS<>'CN');                                     
            
            CH_STEP := ':DELETE FY_TB_BL_BILL_BI:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_BI A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_BILL_ACCT 
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND CYCLE      =A.CYCLE
                                                 AND CYCLE_MONTH=A.CYCLE_MONTH
                                                 AND ACCT_KEY   =A.ACCT_KEY
                                                 AND ACCT_ID    =A.ACCT_ID
                                                 AND ACCT_GROUP =PI_ACCT_GROUP
                                                 AND BILL_STATUS<>'CN');    
            
            CH_STEP := ':DELETE FY_TB_BL_BILL_CI:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_CI A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_BILL_ACCT 
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND CYCLE      =A.CYCLE
                                                 AND CYCLE_MONTH=A.CYCLE_MONTH
                                                 AND ACCT_KEY   =A.ACCT_KEY
                                                 AND ACCT_ID    =A.ACCT_ID
                                                 AND ACCT_GROUP =PI_ACCT_GROUP
                                                 AND BILL_STATUS<>'CN')
                     AND SOURCE IN ('RC','DE','UC');  
            CH_STEP := ':UPDATE FY_TB_BL_BILL_CI:';   
            UPDATE FY_TB_BL_BILL_CI A SET BI_SEQ=NULL   
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_BILL_ACCT 
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND CYCLE      =A.CYCLE
                                                 AND CYCLE_MONTH=A.CYCLE_MONTH
                                                 AND ACCT_KEY   =A.ACCT_KEY
                                                 AND ACCT_ID    =A.ACCT_ID
                                                 AND ACCT_GROUP =PI_ACCT_GROUP
                                                 AND BILL_STATUS<>'CN');                                     
            CH_STEP := ':UPDATE FY_TB_BL_BILL_ACCT:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            UPDATE FY_TB_BL_BILL_ACCT A SET BILL_STATUS ='CL',
                                            UPDATE_DATE =SYSDATE,
                                            UPDATE_USER =PI_USER
                                  WHERE BILL_SEQ   =PI_BILL_SEQ      
                                    AND CYCLE      =NU_CYCLE         
                                    AND CYCLE_MONTH=NU_CYCLE_MONTH  
                                    AND ACCT_KEY   =MOD(ACCT_ID,100)
                                    AND ACCT_GROUP =PI_ACCT_GROUP
                                    AND BILL_STATUS<>'CN';                               
         END IF; --PI_PROCESS_NO
      ELSE 
         IF PI_PROCESS_NO=999 THEN
            CH_STEP := ':DELETE FY_TB_BL_BILL_PAID (TEST):'; --2020/06/30 MODIFY FOR MPBS_Migration
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_PAID A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND PROC_TYPE  =PI_PROC_TYPE
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_ACCT_LIST
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND TYPE       =PI_ACCT_GROUP
                                                 AND ACCT_ID    =A.ACCT_ID);   
            CH_STEP := ':DELETE FY_TB_BL_BILL_MAST_TEST:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_MAST_TEST A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_ACCT_LIST
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND TYPE       =PI_ACCT_GROUP
                                                 AND ACCT_ID    =A.ACCT_ID);
            CH_STEP := ':DELETE FY_TB_BL_BILL_BI_TEST:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_BI_TEST A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_ACCT_LIST
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND TYPE       =PI_ACCT_GROUP
                                                 AND ACCT_ID    =A.ACCT_ID);   
            CH_STEP := ':DELETE FY_TB_BL_BILL_CI_TEST:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_CI_TEST A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_ACCT_LIST
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND TYPE       =PI_ACCT_GROUP
                                                 AND ACCT_ID    =A.ACCT_ID);                                   
         ELSE    
            CH_STEP := ':DELETE FY_TB_BL_BILL_PAID (TEST):'; --2020/06/30 MODIFY FOR MPBS_Migration
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_PAID A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND PROC_TYPE  =PI_PROC_TYPE
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_BILL_ACCT 
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND CYCLE      =NU_CYCLE
                                                 AND CYCLE_MONTH=NU_CYCLE_MONTH
                                                 AND ACCT_KEY   =A.ACCT_KEY
                                                 AND ACCT_ID    =A.ACCT_ID
                                                 AND ACCT_GROUP =PI_ACCT_GROUP);  
            CH_STEP := ':DELETE FY_TB_BL_BILL_MAST_TEST:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);                                                                               
            DELETE FY_TB_BL_BILL_MAST_TEST A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_BILL_ACCT 
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND CYCLE      =NU_CYCLE
                                                 AND CYCLE_MONTH=NU_CYCLE_MONTH
                                                 AND ACCT_KEY   =A.ACCT_KEY
                                                 AND ACCT_ID    =A.ACCT_ID
                                                 AND ACCT_GROUP =PI_ACCT_GROUP);                                     
            CH_STEP := ':DELETE FY_TB_BL_BILL_BI_TEST:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_BI_TEST A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_BILL_ACCT 
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND CYCLE      =NU_CYCLE
                                                 AND CYCLE_MONTH=NU_CYCLE_MONTH
                                                 AND ACCT_KEY   =A.ACCT_KEY
                                                 AND ACCT_ID    =A.ACCT_ID
                                                 AND ACCT_GROUP =PI_ACCT_GROUP);   
            CH_STEP := ':DELETE FY_TB_BL_BILL_CI_TEST:';
            DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||CH_STEP);
            DELETE FY_TB_BL_BILL_CI_TEST A
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH 
                     AND ACCT_KEY   =MOD(ACCT_ID,100)
                     AND EXISTS (SELECT ACCT_ID FROM FY_TB_BL_BILL_ACCT 
                                               WHERE BILL_SEQ   =PI_BILL_SEQ
                                                 AND CYCLE      =NU_CYCLE
                                                 AND CYCLE_MONTH=NU_CYCLE_MONTH
                                                 AND ACCT_KEY   =A.ACCT_KEY
                                                 AND ACCT_ID    =A.ACCT_ID
                                                 AND ACCT_GROUP =PI_ACCT_GROUP);                         
         END IF; --PI_PROCESS_NO
      END IF; --PI_PROC_TYPE  
      --ACCT_PKG處理
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':FY_TB_BL_ACCT_PKG BEGIN:');
      FOR R_AT IN C_AT(NU_CYCLE, NU_CYCLE_MONTH) LOOP   
         FOR R_PKG IN C_PKG(R_AT.ACCT_ID) LOOP 
            IF R_PKG.PREPAYMENT IS NOT NULL AND R_PKG.OFFER_LEVEL='S' THEN
               --2021/06/15 MODIFY FOR 小額預繳處理
               SELECT COUNT(1) INTO NU_CNT
                 FROM ( SELECT PKG.ACCT_PKG_SEQ, PKG.ACCT_ID, AT.CYCLE
                         FROM (SELECT * FROM FY_TB_BL_ACCT_PKG
                                  START WITH ACCT_PKG_SEQ   =R_PKG.ACCT_PKG_SEQ
                                CONNECT BY PRIOR PRE_PKG_SEQ=ACCT_PKG_SEQ) PKG,
                               FY_TB_BL_ACCOUNT AT
                        WHERE AT.ACCT_ID=PKG.ACCT_ID
                          AND AT.ACCT_ID<>R_AT.ACCT_ID
                          AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_MV_SUB
                                        WHERE BILL_SEQ=PI_BILL_SEQ
                                          AND ACCT_ID =R_AT.ACCT_ID
                                          AND PRE_CYCLE IS NOT NULL)) MV
                WHERE CYCLE=NU_CYCLE;
               IF NU_CNT>0 THEN                          
                  FOR R_MV IN C_MV(R_AT.ACCT_ID, R_PKG.ACCT_PKG_SEQ) LOOP
                     IF R_MV.CYCLE=NU_CYCLE THEN
                        UPDATE FY_TB_BL_ACCT_PKG A 
                                       SET TRANS_OUT_QTY =DECODE(PI_PROC_TYPE,'B',NULL,TRANS_OUT_QTY), 
                                           TRANS_OUT_DATE=DECODE(PI_PROC_TYPE,'B',NULL,TRANS_OUT_DATE),
                                           TEST_TRANS_OUT_QTY =DECODE(PI_PROC_TYPE,'T',NULL,TEST_TRANS_OUT_QTY), 
                                           TEST_TRANS_OUT_DATE=DECODE(PI_PROC_TYPE,'T',NULL,TEST_TRANS_OUT_DATE),
                                           UPDATE_DATE   =SYSDATE,
                                           UPDATE_USER   =PI_USER 
                                      WHERE ACCT_PKG_SEQ=R_MV.ACCT_PKG_SEQ; 
                        EXIT;
                     END IF;
                     CH_STEP := ':UPDATE FY_TB_BL_ACCT_PKG:ACCT_PKG_SEQ'||TO_CHAR(R_MV.ACCT_PKG_SEQ);
                     UPDATE FY_TB_BL_ACCT_PKG A 
                                       SET CUR_QTY        =NULL,     
                                           CUR_USE_QTY    =NULL, 
                                           CUR_BAL_QTY    =NULL, 
                                           TRANS_IN_QTY   =NULL,  
                                           TRANS_IN_DATE  =NULL,
                                           TRANS_OUT_QTY  =NULL, 
                                           TRANS_OUT_DATE =NULL,
                                           TOTAL_DISC_AMT =NULL,
                                           INIT_PKG_QTY   =NULL, 
                                           STATUS        ='OPEN',
                                           UPDATE_DATE   =SYSDATE,
                                           UPDATE_USER   =PI_USER 
                                      WHERE ACCT_PKG_SEQ=R_MV.ACCT_PKG_SEQ;      
                  END LOOP;
                  R_PKG.CUR_QTY        :=NULL;
                  R_PKG.CUR_USE_QTY    :=NULL;
                  R_PKG.CUR_BAL_QTY    :=NULL;
                  R_PKG.TRANS_IN_QTY   :=NULL;
                  R_PKG.TRANS_IN_DATE  :=NULL;
                  R_PKG.TOTAL_DISC_AMT :=NULL;
                  R_PKG.INIT_PKG_QTY   :=NULL;
               END IF;  --2021/06/15 MODIFY FOR 小額預繳處理
               
               --TRANS_IN
               IF R_PKG.PRE_PKG_SEQ IS NOT NULL THEN 
                  SELECT COUNT(1) 
                    INTO NU_CNT
                    FROM FY_TB_BL_BILL_MV_SUB
                   WHERE BILL_SEQ=PI_BILL_SEQ
                     AND CYCLE   =NU_CYCLE
                     AND CYCLE_MONTH=NU_CYCLE_MONTH
                    -- AND ACCT_KEY   =MOD(R_AT.ACCT_ID,100)
                     AND ACCT_ID    =R_AT.ACCT_ID
                     AND SUBSCR_ID  =R_PKG.OFFER_LEVEL_ID
                     AND PRE_CYCLE IS NULL;
                  IF NU_CNT>0 THEN
                     IF PI_PROC_TYPE='B' THEN
                        R_PKG.TRANS_IN_DATE := NULL;
                        R_PKG.TRANS_IN_QTY  := NULL;
                        R_PKG.TOTAL_DISC_AMT:= NULL;
                        R_PKG.INIT_PKG_QTY  := NULL;
                     ELSE
                        R_PKG.TEST_TRANS_IN_DATE := NULL; 
                        R_PKG.TEST_TRANS_IN_QTY  := NULL; 
                     END IF;
                  END IF;
               END IF; --2020/02/25 MODIFY 原MV僅舊SUB會清空TRANS_OUT_QTY、TRANS_OUT_DATE，改為新舊SUB都會清空TRANS_OUT_QTY、TRANS_OUT_DATE
               --TRANS_OUT
               --ELSE --2020/02/25 MODIFY 原MV僅舊SUB會清空TRANS_OUT_QTY、TRANS_OUT_DATE，改為新舊SUB都會清空TRANS_OUT_QTY、TRANS_OUT_DATE
                  SELECT COUNT(1) 
                    INTO NU_CNT
                    FROM FY_TB_BL_BILL_MV_SUB
                   WHERE BILL_SEQ=PI_BILL_SEQ
                     AND CYCLE   =NU_CYCLE
                     AND CYCLE_MONTH =NU_CYCLE_MONTH
                     AND PRE_ACCT_ID =R_AT.ACCT_ID
                     AND PRE_SUBSCR_ID=R_PKG.OFFER_LEVEL_ID
                     AND PRE_CYCLE IS NULL;
                  IF NU_CNT>0 THEN
                     IF PI_PROC_TYPE='B' THEN
                        R_PKG.TRANS_OUT_DATE := NULL;
                        R_PKG.TRANS_OUT_QTY  := NULL;
                     ELSE
                        R_PKG.TEST_TRANS_OUT_DATE := NULL; 
                        R_PKG.TEST_TRANS_OUT_QTY  := NULL; 
                     END IF;
                  END IF;
               --END IF; --2020/02/25 MODIFY 原MV僅舊SUB會清空TRANS_OUT_QTY、TRANS_OUT_DATE，改為新舊SUB都會清空TRANS_OUT_QTY、TRANS_OUT_DATE
            END IF;   
            CH_STEP := ':UPDATE FY_TB_BL_ACCT_PKG:';
            UPDATE FY_TB_BL_ACCT_PKG A SET BILL_QTY       =DECODE(PI_PROC_TYPE,'B',NULL,BILL_QTY),     
                                           BILL_USE_QTY   =DECODE(PI_PROC_TYPE,'B',NULL,BILL_USE_QTY), 
                                           BILL_BAL_QTY   =DECODE(PI_PROC_TYPE,'B',NULL,BILL_BAL_QTY), 
                                           BILL_DISC_AMT  =DECODE(PI_PROC_TYPE,'B',NULL,BILL_DISC_AMT),
                                           RECUR_BILLED   =DECODE(PI_PROC_TYPE,'B',NULL,RECUR_BILLED),
                                           RECUR_SEQ      =DECODE(PI_PROC_TYPE,'B',NULL,RECUR_SEQ),    
                                           TRANS_IN_QTY   =R_PKG.TRANS_IN_QTY,  
                                           TRANS_IN_DATE  =R_PKG.TRANS_IN_DATE,
                                           TRANS_OUT_QTY  =R_PKG.TRANS_OUT_QTY, 
                                           TRANS_OUT_DATE =R_PKG.TRANS_OUT_DATE,
                                           TOTAL_DISC_AMT =R_PKG.TOTAL_DISC_AMT,
                                           INIT_PKG_QTY   =R_PKG.INIT_PKG_QTY,    
                                           CUR_QTY        =R_PKG.CUR_QTY,      --2021/06/15 MODIFY FOR 小額預繳處理
                                           CUR_USE_QTY    =R_PKG.CUR_USE_QTY,  --2021/06/15 MODIFY FOR 小額預繳處理
                                           CUR_BAL_QTY    =R_PKG.CUR_BAL_QTY,  --2021/06/15 MODIFY FOR 小額預繳處理                                      
                                           TEST_QTY           =DECODE(PI_PROC_TYPE,'T',NULL,TEST_QTY),           
                                           TEST_USE_QTY       =DECODE(PI_PROC_TYPE,'T',NULL,TEST_USE_QTY),       
                                           TEST_BAL_QTY       =DECODE(PI_PROC_TYPE,'T',NULL,TEST_BAL_QTY),       
                                           TEST_DISC_AMT      =DECODE(PI_PROC_TYPE,'T',NULL,TEST_DISC_AMT),      
                                           TEST_RECUR_BILLED  =DECODE(PI_PROC_TYPE,'T',NULL,TEST_RECUR_BILLED),  
                                           TEST_RECUR_SEQ     =DECODE(PI_PROC_TYPE,'T',NULL,TEST_RECUR_SEQ),     
                                           TEST_TRANS_IN_QTY  =R_PKG.TEST_TRANS_IN_QTY,  
                                           TEST_TRANS_IN_DATE =R_PKG.TEST_TRANS_IN_DATE, 
                                           TEST_TRANS_OUT_QTY =R_PKG.TEST_TRANS_OUT_QTY, 
                                           TEST_TRANS_OUT_DATE=R_PKG.TEST_TRANS_OUT_DATE,
                                           UPDATE_DATE   =SYSDATE,
                                           UPDATE_USER   =PI_USER 
                                      WHERE ROWID=R_PKG.ROWID;      
         END LOOP;
      END LOOP;  
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':FY_TB_BL_ACCT_PKG END:'); 
      --處理ERR FILE
      CH_STEP := 'DELETE FY_TB_BL_BILL_PROCESS_ERR:'; 
      DELETE FY_TB_BL_BILL_PROCESS_ERR A
                    WHERE BILL_SEQ   =PI_BILL_SEQ
                      AND PROCESS_NO =PI_PROCESS_NO
                      AND ACCT_GROUP =PI_ACCT_GROUP
                      AND PROC_TYPE  =PI_PROC_TYPE;
      --處理PROCESS_LOG      
       CH_STEP := 'DELETE FY_TB_BL_BILL_PROCESS_LOG:KEEP'; --2020/05/14 MODIFY SR215584_NPEP 2.0調整出帳Confirm流程，使Confirm作業可在Undo之後執行
       DELETE FY_TB_BL_BILL_PROCESS_LOG A
                    WHERE BILL_SEQ   =PI_BILL_SEQ
                      AND PROCESS_NO =PI_PROCESS_NO
                      AND ACCT_GROUP ='KEEP'
                      AND PROC_TYPE  =PI_PROC_TYPE;  
       
       CH_STEP := 'INSERT FY_TB_BL_BILL_PROCESS_LOG:KEEP'; --2020/05/14 MODIFY SR215584_NPEP 2.0調整出帳Confirm流程，使Confirm作業可在Undo之後執行
      INSERT INTO FY_TB_BL_BILL_PROCESS_LOG VALUE
      (SELECT bill_seq,process_no,'KEEP',proc_type,status,file_reply,begin_time,end_time,currect_acct_id,count,create_date,create_user,update_date,update_user FROM FY_TB_BL_BILL_PROCESS_LOG
                    WHERE BILL_SEQ   =PI_BILL_SEQ
                      AND PROCESS_NO =PI_PROCESS_NO
                      AND ACCT_GROUP =PI_ACCT_GROUP
                      AND PROC_TYPE  =PI_PROC_TYPE); 
					  
      CH_STEP := 'DELETE FY_TB_BL_BILL_PROCESS_LOG:';
      DELETE FY_TB_BL_BILL_PROCESS_LOG A
                    WHERE BILL_SEQ   =PI_BILL_SEQ
                      AND PROCESS_NO =PI_PROCESS_NO
                      AND ACCT_GROUP =PI_ACCT_GROUP
                      AND PROC_TYPE  =PI_PROC_TYPE;                                      
      COMMIT;
      DBMS_OUTPUT.Put_Line('0000'||'FY_PG_BL_BILL_UNDO END');
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
   END MAIN; 

END FY_PG_BL_BILL_UNDO;
/