CREATE OR REPLACE PACKAGE BODY HGBBLAPPO.FY_PG_BL_BILL_CONFIRM IS                
   
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL CUT_DATE �B�z
      DESCRIPTION : BL CUT_DATE �B�z
      PARAMETER:
            PI_BILL_SEQ           :�X�b�Ǹ�
            PI_PROCESS_NO         :����Ǹ�
            PI_ACCT_GROUP         :�Ȥ�����
            PI_PROC_TYPE          :���櫬�A �w�]�� B (B: �����X�b, T:���եX�b)  
            PI_USER_ID            :����USER_ID        
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      1.1   2018/09/20      FOYA       MODIFY �אּPROCESS_NO����覡
   **************************************************************************/
   PROCEDURE MAIN(PI_BILL_SEQ       IN   NUMBER,
                  PI_PROCESS_NO     IN   NUMBER,
                  PI_ACCT_GROUP     IN   VARCHAR2,
                  PI_PROC_TYPE      IN   VARCHAR2 DEFAULT 'B',  
                  PI_USER_ID        IN   VARCHAR2, 
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2) IS
   
      CURSOR C_AT(iCYCLE NUMBER, iCYCLE_MONTH NUMBER) IS
         SELECT BA.ROWID, 
                BA.ACCT_ID,
                BA.CYCLE,
                BA.CYCLE_MONTH,
                BA.PRODUCTION_TYPE,
                BA.CUST_ID,
                MT.BILL_NBR,
                MT.TOT_AMT,
                MT.CHRG_AMT
           FROM FY_TB_BL_BILL_ACCT BA,
                FY_TB_BL_BILL_MAST MT
          WHERE BA.BILL_SEQ   =PI_BILL_SEQ
            AND BA.CYCLE      =iCYCLE
            AND BA.CYCLE_MONTH=iCYCLE_MONTH
            AND ((PI_PROCESS_NO<>999 AND BA.ACCT_GROUP =PI_ACCT_GROUP) OR 
                 (PI_PROCESS_NO =999 AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                                        WHERE BILL_SEQ=BA.BILL_SEQ
                                                          AND TYPE    =PI_ACCT_GROUP
                                                          AND ACCT_ID =BA.ACCT_ID))
                 )                                         
            AND BA.BILL_STATUS='MA'
            AND MT.BILL_SEQ   =BA.BILL_SEQ
            AND MT.CYCLE      =BA.CYCLE
            AND MT.CYCLE_MONTH=BA.CYCLE_MONTH
            AND MT.ACCT_KEY   =BA.ACCT_KEY
            AND MT.ACCT_ID    =BA.ACCT_ID
          ORDER BY BA.ACCT_ID;   
          
      CURSOR C_PKG(iACCT_ID NUMBER) IS
         SELECT ROWID,
                ACCT_PKG_SEQ,  
                PKG_TYPE_DTL,
                BILL_QTY,    
                BILL_USE_QTY,
                BILL_BAL_QTY,
                RECUR_BILLED,
                BILL_DISC_AMT,
                VALIDITY_PERIOD,
                TRANS_IN_QTY,  
                TRANS_IN_DATE, 
                TRANS_OUT_QTY, 
                TRANS_OUT_DATE, 
                OFFER_LEVEL,
                OFFER_LEVEL_ID,
                PREPAYMENT, 
                RECURRING,
                END_RSN, --2022/10/20 MODIFY FOR SR250171_ESDP_Migration_Project_�~úDFC���i���e����A�]���h�O�ݨD
                EFF_DATE,
                END_DATE,
                FUTURE_EXP_DATE,
                SYS_END_DATE,
                STATUS
           FROM FY_TB_BL_ACCT_PKG
          WHERE ACCT_ID    =iACCT_ID
            AND ACCT_KEY   =MOD(iACCT_ID,100) 
            AND (RECUR_SEQ =PI_BILL_SEQ OR
                 (STATUS='OPEN' AND (TRUNC(EFF_DATE)=TRUNC(END_DATE) OR TRUNC(END_DATE)-1=RECUR_BILLED)
				 AND PREPAYMENT IS NULL) --2021/10/06 MODIFY FOR �p�B�wú�B�z
                 );          

      NU_CNT             NUMBER  :=0;
      NU_CTRL_CNT        NUMBER;
      NU_CONFIRM_ID      NUMBER;
      NU_SHOW_CNT        NUMBER;
      DT_BILL_END_DATE   DATE;
      NU_CYCLE           FY_TB_BL_BILL_CNTRL.CYCLE%TYPE;
      NU_CYCLE_MONTH     FY_TB_BL_BILL_CNTRL.CYCLE_MONTH%TYPE;
      NU_NEW_CYCLE       FY_TB_BL_BILL_CNTRL.CYCLE%TYPE;
      CH_SEND_FLAG       FY_TB_BL_CHANGE_CYCLE.SEND_FLAG%TYPE;
      NU_TRAN_ID         FY_TB_BL_CHANGE_CYCLE.TRAN_ID%TYPE;
      CH_REMARK          FY_TB_BL_CHANGE_CYCLE.REMARK%TYPE;
      CH_STATUS          FY_TB_BL_BILL_CNTRL.STATUS%TYPE;
      CH_BILL_FLAG       VARCHAR2(4);
      CH_ERR_CDE         VARCHAR2(4);
      CH_ERR_MSG         VARCHAR2(250);
      CH_STEP            VARCHAR2(250);
      On_Err             EXCEPTION;
   BEGIN  
      gvUSER        := PI_USER_ID;
	  CH_STEP := 'CALL Ins_Process_LOG:';
      Fy_Pg_Bl_Bill_Util.Ins_Process_LOG
                     ('CN',  --PI_STATUS 
                      Pi_Bill_Seq,   
                      Pi_Proc_Type, 
                      Pi_Process_No, 
                      Pi_Acct_Group ,
                      PI_User_Id ,   
                      CH_ERR_CDE ,   
                      CH_ERR_MSG);
      IF CH_ERR_CDE<>'0000' THEN
         Po_Err_Cde:= CH_ERR_CDE;
         CH_STEP   := SUBSTR(CH_STEP||CH_ERR_MSG,1,250);
         RAISE On_Err;
      END IF;                        
      ----GET BILL_CNTRL.CONFIRM_ID
      CH_STEP := 'GET BILL_CNTRL.BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||':';
      SELECT CONFIRM_ID, BILL_END_DATE, CYCLE, CYCLE_MONTH, STATUS
        INTO NU_CONFIRM_ID, DT_BILL_END_DATE, NU_CYCLE, NU_CYCLE_MONTH, CH_STATUS
        FROM FY_TB_BL_BILL_CNTRL
       WHERE BILL_SEQ=PI_BILL_SEQ;
      IF CH_STATUS='CN' THEN
         PO_ERR_CDE := 'C001';
         CH_STEP := 'GET BILL_CNTRL.BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||'�w����CONFIRM';  
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
      ----ACCOUNT�B�z
      CH_BILL_FLAG := 'N';
      FOR R_AT IN C_AT(NU_CYCLE, NU_CYCLE_MONTH) LOOP 
         NU_CTRL_CNT := NVL(NU_CTRL_CNT,0)+1;
         IF MOD(NU_CTRL_CNT/NU_SHOW_CNT,1)=0 THEN
            DBMS_OUTPUT.Put_Line('CNT='||TO_CHAR(NU_CTRL_CNT));
         END IF; 
         BEGIN
            --INSERT ACCT_PKG_LOG
            CH_STEP := 'INSERT ACCT_PKG_LOG.ACCT_ID='||R_AT.ACCT_ID||':';
            INSERT INTO FY_TB_BL_ACCT_PKG_LOG
                        (BILL_SEQ,
                         ACCT_PKG_SEQ,
                         OFFER_SEQ,
                         OFFER_ID,
                         OFFER_INSTANCE_ID,
                         ACCT_ID,
                         ACCT_KEY,
                         CUST_ID,
                         OFFER_LEVEL,
                         OFFER_LEVEL_ID,
                         PKG_ID,
                         PKG_TYPE_DTL,
                         PREPAYMENT,
                         RECURRING,
                         PKG_PRIORITY,
                         EFF_DATE,
                         END_DATE,
                         FUTURE_EXP_DATE,
                         STATUS,
                         INIT_PKG_QTY,
                         TOTAL_DISC_AMT,
                         CUR_QTY,
                         CUR_USE_QTY,
                         CUR_BAL_QTY,
                         CUR_BILLED,
                         VALIDITY_PERIOD,
                         BILL_QTY,
                         BILL_USE_QTY,
                         BILL_BAL_QTY,
                         BILL_DISC_AMT,
                         FIRST_BILL_DATE,
                         RECUR_BILLED,
                         SYS_EFF_DATE,
                         SYS_END_DATE,
                         PRE_OFFER_SEQ,
                         PRE_PKG_SEQ,
                         TRANS_IN_QTY,
                         TRANS_IN_DATE,
                         TRANS_OUT_QTY,
                         TRANS_OUT_DATE,
                         ORIG_EFF_DATE,
                         OVERWRITE,
                         OFFER_NAME,
                         CLEAR_FLAG,
                         CLEAR_QTY,
                         END_RSN,
                         RECUR_SEQ,
                         CREATE_DATE,
                         CREATE_USER,
                         UPDATE_DATE,
                         UPDATE_USER)
                  SELECT PI_BILL_SEQ,
                         ACCT_PKG_SEQ,
                         OFFER_SEQ,
                         OFFER_ID,
                         OFFER_INSTANCE_ID,
                         ACCT_ID,
                         ACCT_KEY,
                         CUST_ID,
                         OFFER_LEVEL,
                         OFFER_LEVEL_ID,
                         PKG_ID,
                         PKG_TYPE_DTL,
                         PREPAYMENT,
                         RECURRING,
                         PKG_PRIORITY,
                         EFF_DATE,
                         END_DATE,
                         FUTURE_EXP_DATE,
                         STATUS,
                         INIT_PKG_QTY,
                         TOTAL_DISC_AMT,
                         CUR_QTY,
                         CUR_USE_QTY,
                         CUR_BAL_QTY,
                         CUR_BILLED,
                         VALIDITY_PERIOD,
                         BILL_QTY,
                         BILL_USE_QTY,
                         BILL_BAL_QTY,
                         BILL_DISC_AMT,
                         FIRST_BILL_DATE,
                         RECUR_BILLED,
                         SYS_EFF_DATE,
                         SYS_END_DATE,
                         PRE_OFFER_SEQ,
                         PRE_PKG_SEQ,
                         TRANS_IN_QTY,
                         TRANS_IN_DATE,
                         TRANS_OUT_QTY,
                         TRANS_OUT_DATE,
                         ORIG_EFF_DATE,
                         OVERWRITE,
                         OFFER_NAME,
                         CLEAR_FLAG,
                         CLEAR_QTY,
                         END_RSN,
                         RECUR_SEQ,
                         SYSDATE,
                         PI_USER_ID,
                         SYSDATE,
                         PI_USER_ID
                    FROM FY_TB_BL_ACCT_PKG
                   WHERE ACCT_ID  =R_AT.ACCT_ID
                     AND ACCT_KEY =MOD(R_AT.ACCT_ID,100)
                     AND RECUR_SEQ=PI_BILL_SEQ;            
            
            --ACCT_PKG�B�z
            CH_STEP := 'UPDATE ACCT_PKG.ACCT_ID='||R_AT.ACCT_ID||':';  
            FOR R_PKG IN C_PKG(R_AT.ACCT_ID) LOOP 
               IF R_PKG.BILL_DISC_AMT>0 AND R_PKG.VALIDITY_PERIOD<>-1 THEN
                  R_PKG.VALIDITY_PERIOD := R_PKG.VALIDITY_PERIOD-1;
               END IF;   
               IF NVL(R_PKG.END_RSN,' ') NOT IN ('DFC','CS1','CS2','CS3','CS4','CS5','CS6','CS7','CS8','CS9','CSZ') AND (TRUNC(R_PKG.EFF_DATE)=TRUNC(R_PKG.END_DATE) OR --2022/10/20 MODIFY FOR SR250171_ESDP_Migration_Project_�DDFC���`CLOSE --2023/02/03 MODIFY FOR SR250171_ESDP_Migration_Project_�ץ��ŭȵL�k�P�_���D  --2023/07/13 MODIFY FOR SR260229_Project-M Fixed line Phase I_�W�[��ú�w�����Τ��iCLOSE
                  R_PKG.TRANS_OUT_DATE IS NOT NULL OR
                  R_PKG.VALIDITY_PERIOD=0 OR
                 (TRUNC(R_PKG.END_DATE)-1=R_PKG.RECUR_BILLED) OR
                 (TRUNC(R_PKG.FUTURE_EXP_DATE)-1=R_PKG.RECUR_BILLED) OR
                 (TRUNC(R_PKG.SYS_END_DATE)-1=R_PKG.RECUR_BILLED) OR
                 (R_PKG.PREPAYMENT IS NOT NULL AND R_PKG.RECURRING='N' AND R_PKG.BILL_BAL_QTY=0)) THEN
                  R_PKG.STATUS := 'CLOSE';
               ELSIF NVL(R_PKG.END_RSN,' ') = 'DFC' AND (TRUNC(R_PKG.EFF_DATE)=TRUNC(R_PKG.END_DATE) OR --2022/10/20 MODIFY FOR SR250171_ESDP_Migration_Project_��DFC�ݧP�_�h�O�A����12�Ӥ�CLOSE --2023/02/03 MODIFY FOR SR250171_ESDP_Migration_Project_�ץ��ŭȵL�k�P�_���D
                  R_PKG.TRANS_OUT_DATE IS NOT NULL OR
                  R_PKG.VALIDITY_PERIOD=0 OR
                 (TRUNC(R_PKG.END_DATE)=R_PKG.RECUR_BILLED) OR --2022/10/20 MODIFY FOR SR250171_ESDP_Migration_Project_END_DATE�P�̫�X�b��۵����ݰh�O
                 (TRUNC(R_PKG.FUTURE_EXP_DATE)-1=add_months(R_PKG.RECUR_BILLED,-12)) OR
                 (TRUNC(R_PKG.SYS_END_DATE)-1=add_months(R_PKG.RECUR_BILLED,-12)) OR
                 (R_PKG.PREPAYMENT IS NOT NULL AND R_PKG.RECURRING='N' AND R_PKG.BILL_BAL_QTY=0)) THEN
                  R_PKG.STATUS := 'CLOSE';
               ELSIF NVL(R_PKG.END_RSN,' ') IN ('CS1','CS2','CS3','CS4','CS5','CS6','CS7','CS8','CS9','CSZ') AND (TRUNC(R_PKG.EFF_DATE)=TRUNC(R_PKG.END_DATE) OR --2023/07/13 MODIFY FOR SR260229_Project-M Fixed line Phase I_�W�[��ú�w�����Τ��iCLOSE
                  R_PKG.TRANS_OUT_DATE IS NOT NULL OR
                  R_PKG.VALIDITY_PERIOD=0 OR
                 (TRUNC(R_PKG.END_DATE)=R_PKG.RECUR_BILLED) OR
                 (TRUNC(R_PKG.FUTURE_EXP_DATE)-1=add_months(R_PKG.RECUR_BILLED,-1)) OR
                 (TRUNC(R_PKG.SYS_END_DATE)-1=add_months(R_PKG.RECUR_BILLED,-1)) OR
                 (R_PKG.PREPAYMENT IS NOT NULL AND R_PKG.RECURRING='N' AND R_PKG.BILL_BAL_QTY=0)) THEN
                  R_PKG.STATUS := 'CLOSE';
               END IF;                 
               IF NU_CYCLE IN (10, 15, 20) AND TRUNC(R_PKG.FUTURE_EXP_DATE)-1 > TRUNC(DT_BILL_END_DATE) AND TRUNC(R_PKG.END_DATE) IS NULL AND R_PKG.PKG_TYPE_DTL = 'RC' THEN --2022/11/07 MODIFY FOR SR250171_ESDP_Migration_Project_�קK�~ú�A�Ȳ��ʷs�A�ȴ��eCLOSE --2023/04/19 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�WCYCLE(15,20)
                  R_PKG.STATUS := 'OPEN';
               END IF;
               UPDATE FY_TB_BL_ACCT_PKG  SET TOTAL_DISC_AMT  = NVL(TOTAL_DISC_AMT,0)+NVL(BILL_DISC_AMT,0),
                                             CUR_QTY         = BILL_QTY,
                                             CUR_USE_QTY     = BILL_USE_QTY,
                                             CUR_BAL_QTY     = BILL_BAL_QTY,
                                             --CUR_BILLED      = RECUR_BILLED, --2019/12/12 MODIFY SR220754_��PKG_TYPE_DTL='RC'�i��FY_TB_BL_ACCT_PKG.CUR_BILLED
                                             --CUR_BILLED      = DECODE(PKG_TYPE_DTL,'RC',RECUR_BILLED,NULL), --2019/12/12 MODIFY SR220754_��PKG_TYPE_DTL='RC'�i��FY_TB_BL_ACCT_PKG.CUR_BILLED --2020/02/25 MODIFY ����SR220754_��PKG_TYPE_DTL='RC'�i��FY_TB_BL_ACCT_PKG.CUR_BILLED
                                             --CUR_BILLED      = NVL(RECUR_BILLED, CUR_BILLED), --2020/02/25 MODIFY ����L�ϥήɡA�^����
                                             --CUR_BILLED      = NVL(DECODE(SIGN(NVL (recur_billed, cur_billed)- NVL (cur_billed, recur_billed)),-1, cur_billed,recur_billed),cur_billed), --2022/11/01 MODIFY FOR SR250171_ESDP_Migration_Project_��recur_billed��cur_billed�p�ɡA���i�ק�cur_billed�A�_�h�~ú�|��U�����Ʀ��O
                                             CUR_BILLED      = DECODE(R_PKG.STATUS,'CLOSE',NVL(RECUR_BILLED, CUR_BILLED),NVL(GREATEST(NVL (recur_billed, cur_billed),NVL (cur_billed, recur_billed)),cur_billed)), --2022/11/02 MODIFY FOR SR250171_ESDP_Migration_Project_��STATUS�P�_��CLOSE�h��recur_billed�л\,�Ϥ�OPEN��recur_billed��cur_billed�p�ɡA���i�ק�cur_billed�A�_�h�~ú�|��U�����Ʀ��O
                                             VALIDITY_PERIOD = R_PKG.VALIDITY_PERIOD,
                                             BILL_QTY        = NULL,
                                             BILL_USE_QTY    = NULL,
                                             BILL_BAL_QTY    = NULL,
                                             BILL_DISC_AMT   = NULL,
                                             RECUR_BILLED    = NULL,
                                             RECUR_SEQ       = NULL,
                                             STATUS          = R_PKG.STATUS,
                                          FIRST_BILL_DATE    = DECODE(FIRST_BILL_DATE,NULL,DT_BILL_END_DATE,FIRST_BILL_DATE), 
                                          test_QTY           = NULL,
                                          test_USE_QTY       = NULL,
                                          test_BAL_QTY       = NULL,
                                          test_DISC_AMT      = NULL,
                                          test_RECUR_BILLED  = NULL,
                                          test_RECUR_SEQ     = NULL,
                                          TEST_TRANS_IN_QTY  = NULL, 
                                          TEST_TRANS_IN_DATE = NULL, 
                                          TEST_TRANS_OUT_QTY = NULL, 
                                          TEST_TRANS_OUT_DATE= NULL, 
                                          UPDATE_DATE        = SYSDATE,
                                          UPDATE_USER        = PI_USER_ID
                                    WHERE ROWID=R_PKG.ROWID;  
            END LOOP;
                       
            --CHANGE CYCLE DATA SYNC 
            BEGIN
               SELECT TRAN_ID, NEW_CYCLE, SEND_FLAG, REMARK
                 INTO NU_TRAN_ID, NU_NEW_CYCLE, CH_SEND_FLAG, CH_REMARK
                 FROM FY_TB_BL_CHANGE_CYCLE A
                WHERE CUST_ID        =R_AT.CUST_ID
                  AND FUTURE_EFF_DATE=DT_BILL_END_DATE+1
                  AND TRAN_ID = (SELECT MAX(TRAN_ID) FROM FY_TB_BL_CHANGE_CYCLE 
                                             WHERE CUST_ID        =A.CUST_ID
                                               AND FUTURE_EFF_DATE=A.FUTURE_EFF_DATE);
               
                ----CHANGE CYCLE DATA SYNC 
                IF NVL(CH_SEND_FLAG,' ')<>'Y' THEN
                   CH_STEP := 'INSERT DATA_SYNC.CUST_ID='||TO_CHAR(R_AT.CUST_ID)||':'; 
                   INSERT INTO FY_TB_CM_SYNC_SEND_PUB
                                   (TRX_ID, 
                                    SVC_CODE, 
                                    ACTV_CODE, 
                                    ENTITY_TYPE, 
                                    ENTITY_ID, 
                                    SYNC_MESG, 
                                    CREATE_DATE, 
                                    CREATE_USER, 
                                    UPDATE_DATE, 
                                    UPDATE_USER,
                                    ROUTE_ID)
                             SELECT fy_sq_cm_trx.nextval,
                                    '9926',
                                    'BLCHANGECYCLECONF',
                                    'C',
                                    R_AT.CUST_iD,
                                    ch_remark,
                                    sysdate,
                                    PI_USER_ID, --2020/06/30 MODIFY FOR MPBS_Migration - �קאּ�ܼ�
                                    sysdate,
                                    PI_USER_ID, --2020/06/30 MODIFY FOR MPBS_Migration - �קאּ�ܼ�
                                    R_AT.CUST_ID
                               FROM DUAL;
                   --UPDATE CHANGE_CYCLE                    
                   CH_STEP := 'UPDATE BL_CHANGE_CYCL.ECUST_ID='||TO_CHAR(R_AT.CUST_ID)||':'; 
                   UPDATE FY_TB_BL_CHANGE_CYCLE SET SEND_FLAG   ='Y',
                                                    UPDATE_DATE =SYSDATE,
                                                    UPDATE_USER =PI_USER_ID
                                              WHERE CUST_ID        =R_AT.CUST_ID
                                                AND FUTURE_EFF_DATE=DT_BILL_END_DATE+1
                                                AND TRAN_ID        =NU_TRAN_ID;       
                END IF;                
            EXCEPTION WHEN OTHERS THEN
               NU_NEW_CYCLE := R_AT.CYCLE;
            END;             
            --UPDATE ACCOUNT(�����B���`�B�����B��������,�b������ 'FR', 'RG', 'FN', 'RF, 'DR')  
            CH_STEP := 'UPDATE BL_ACCOUNT='||R_AT.ACCT_ID||':';
            UPDATE FY_TB_BL_ACCOUNT SET FIRST_BILL_SEQ = DECODE(FIRST_BILL_SEQ,NULL,PI_BILL_SEQ,FIRST_BILL_SEQ),
                                        LAST_BILL_SEQ  = DECODE(R_AT.PRODUCTION_TYPE,'FN',PI_BILL_SEQ,LAST_BILL_SEQ),
                                        PRE_BILL_SEQ   = PI_BILL_SEQ,
                                        PRE_BILL_NBR   = R_AT.BILL_NBR,
                                        PRE_BILL_AMT   = R_AT.TOT_AMT,
                                        PRE_CHRG_AMT   = R_AT.CHRG_AMT,
                                        CYCLE          = NU_NEW_CYCLE,
                                        UPDATE_DATE    = SYSDATE,
                                        UPDATE_USER    = PI_USER_ID    
                                  WHERE ACCT_ID=R_AT.ACCT_ID;
            
            --UPDATE BILL_ACCT
            CH_STEP := 'UPDATE BILL_ACCT='||R_AT.ACCT_ID||':';
            UPDATE FY_TB_BL_BILL_ACCT SET BILL_STATUS ='CN',
                                          UPDATE_DATE =SYSDATE,
                                          UPDATE_USER =PI_USER_ID
                                    WHERE ROWID=R_AT.ROWID; 
            CH_BILL_FLAG := 'Y';
         EXCEPTION WHEN OTHERS THEN
            ROLLBACK;
            CH_STEP := Substr(CH_STEP || SQLERRM, 1, 250);
            Fy_Pg_Bl_Bill_Util.Ins_Process_Err(Pi_Bill_Seq,
                                               'B', --PROC_TYPE
                                               r_At.Acct_Id,
                                               NULL, --SUBSCR_ID
                                               pi_PROCESS_NO,
                                               pi_ACCT_GROUP,
                                               'FY_PG_BL_BILL_CONFIRM', --PG_NAME
                                               PI_USER_ID,
                                               'C001',
                                               Ch_Step,
                                               Ch_Err_Cde,
                                               Ch_Err_Msg);
            IF CH_ERR_CDE<>'0000' THEN
               PO_ERR_CDE := CH_ERR_CDE;
               CH_STEP    := Substr('CALL Ins_Process_Err:'||CH_STEP,1,250);
               RAISE ON_ERR;
            END IF;                      
         END;
         COMMIT;    
      END LOOP;
      IF CH_BILL_FLAG='N' THEN
         PO_ERR_CDE := 'C002';
         CH_STEP    := 'BILL_MAST�L�ŦX�ݰ�����';
         RAISE ON_ERR;
      END IF;
      --UPDATE BILL_CNTRL 
      SELECT COUNT(1) INTO NU_CNT
        FROM FY_TB_BL_BILL_ACCT
        WHERE BILL_SEQ   =PI_BILL_SEQ
          AND CYCLE      =NU_CYCLE
          AND CYCLE_MONTH=NU_CYCLE_MONTH
          AND BILL_STATUS<>'CN';  
      IF NU_CNT=0 THEN     
         CH_STEP := 'UPDATE BILL_CNTRL.BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||':';
         UPDATE FY_TB_BL_BILL_CNTRL SET STATUS      =DECODE(NU_CNT,0,'CN',STATUS),
                                        UPDATE_DATE =SYSDATE,
                                        UPDATE_USER =PI_USER_ID
                                  WHERE BILL_SEQ=PI_BILL_SEQ;  
      END IF;                            
      --CALL DATA I/O
      CH_STEP := 'CALL DATA I/O.BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||':';  
	  IF gvUSER='MPBL' THEN	 --2020/06/30 MODIFY FOR MPBS_Migration - �קאּ�ܼ�
		 Fy_Pg_Dio_Util.Ins_Dio_Cntrl
							 ('UBL',     --Pi_Sys_Id ,
							 'MPCONFIRM', --Pi_Proc_Id ,
							 Pi_Bill_Seq ,
							 Pi_Process_No,
							 Pi_Proc_Type, 
							 Pi_Acct_Group,
							 NU_CONFIRM_ID,  --Pi_Confirm_Id,
							 'O',        --Pi_Io_Type,
							 PI_USER_ID,
							 CH_Err_Cde,
							 CH_Err_Msg);
	  ELSE
		 Fy_Pg_Dio_Util.Ins_Dio_Cntrl
							 ('UBL',     --Pi_Sys_Id ,
							 'CONFIRM', --Pi_Proc_Id ,
							 Pi_Bill_Seq ,
							 Pi_Process_No,
							 Pi_Proc_Type, 
							 Pi_Acct_Group,
							 NU_CONFIRM_ID,  --Pi_Confirm_Id,
							 'O',        --Pi_Io_Type,
							 PI_USER_ID,
							 CH_Err_Cde,
							 CH_Err_Msg);
	  END IF;

      IF CH_ERR_CDE<>'0000' THEN
         PO_ERR_CDE := CH_ERR_CDE;
         CH_STEP    := Substr('CALL Ins_Dio_Cntrl:'||CH_STEP,1,250);
         RAISE ON_ERR;
      END IF; 
      --BILL_PROCESS_LOG 
      CH_STEP := 'UPDATE PROCESS_LOG.BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||':'; 
      UPDATE FY_TB_BL_BILL_PROCESS_LOG BL SET END_TIME=SYSDATE,
                                              COUNT   =NU_CTRL_CNT
                                     WHERE BILL_SEQ  = PI_BILL_SEQ
                                       AND PROCESS_NO= PI_PROCESS_NO
                                       AND ACCT_GROUP= PI_ACCT_GROUP
                                       AND PROC_TYPE = PI_PROC_TYPE
                                       AND STATUS    = 'CN'
                                       AND END_TIME IS NULL;     
      --CALL DATA SYNC --AR ACCT_PKG.STATUS='CLOSE'
      CH_STEP := 'CALL DATA_SYNC.CLOSE:';  
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
   END MAIN; 

END FY_PG_BL_BILL_CONFIRM; 
/

