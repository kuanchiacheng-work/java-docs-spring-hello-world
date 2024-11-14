CREATE OR REPLACE PACKAGE BODY FY_PG_BL_BILL_MAST IS

   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL_MAST �B�z
      DESCRIPTION : BL BILL_MAST �B�z
      PARAMETER:
            PI_BILL_SEQ           :�X�b�Ǹ�
            PI_PROCESS_NO         :����Ǹ�
            PI_ACCT_GROUP         :�Ȥ�����
            PI_PROC_TYPE          :���櫬�A �w�]�� B (B: �����X�b, T:���եX�b)
            PI_USER               :����USER_ID
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
      4.1   2021/06/15      FOYA       MODIFY FOR �p�B�wú�B�z
   **************************************************************************/
   PROCEDURE Main(Pi_Bill_Seq   IN NUMBER,
                  Pi_Process_No IN NUMBER,
                  Pi_Acct_Group IN VARCHAR2,
                  Pi_Proc_Type  IN VARCHAR2 DEFAULT 'B',
                  Pi_User_Id    IN VARCHAR2,
                  Po_Err_Cde    OUT VARCHAR2,
                  Po_Err_Msg    OUT VARCHAR2) IS

      --������X�b��ACCT_ID
      CURSOR c_At(iCYCLE NUMBER, iCYCLE_MONTH NUMBER) IS
         SELECT AT.ROWID,
                At.Acct_Id,
                At.Cust_Id,
                At.Ou_Id,
                At.Subscr_Cnt,
                At.Acct_Group,
                At.Bill_Currency,
                At.Acct_Status,
                At.Perm_Printing_Cat,
                At.Acct_Category,
                At.Production_Type,
                ct.cust_type, --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
                At.Pre_Bill_Nbr,
                NVL(pd.act_amt,0) act_amt, --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
                NVL(At.Pre_Bill_Amt,0) Pre_Bill_Amt,
                NVL(AT.PRE_CHRG_AMT,0) PRE_CHRG_AMT,
                DECODE(PI_PROC_TYPE,'B',At.Balance,AT.BALANCE_TEST) BALANCE,
                At.Cycle,
                At.Cycle_Month,
                AT.ACCT_KEY
           FROM Fy_Tb_Bl_Bill_Acct At, fy_tb_cm_customer Ct --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
           ,(SELECT bill_seq, CYCLE, cycle_month, acct_group, acct_id,SUM (amount) act_amt 
                FROM fy_tb_bl_bill_paid
             WHERE bill_seq = Pi_Bill_Seq AND financial_activity IN ('RFND', 'RFNDR') 
             GROUP BY bill_seq, CYCLE, cycle_month, acct_group, acct_id) pd --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
          WHERE At.Bill_Seq    = Pi_Bill_Seq
            AND AT.CYCLE       = iCYCLE
            AND AT.CYCLE_MONTH = iCYCLE_MONTH
            AND At.Acct_Group  = Pi_Acct_Group
            AND AT.bill_seq = pd.bill_seq(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AT.CYCLE = pd.CYCLE(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AT.cycle_month = pd.cycle_month(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AT.acct_group = pd.acct_group(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AT.acct_id = pd.acct_id(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            and at.cust_id     = ct.cust_id --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
            AND Pi_Process_No <> 999
            AND ((PI_PROC_TYPE='B' AND AT.BILL_STATUS ='CL') OR
                 (PI_PROC_TYPE='T' AND AT.BILL_STATUS<>'CN' AND
                  NOT EXISTS (SELECT 1 FROM FY_TB_BL_BILL_PROCESS_ERR
                                WHERE BILL_SEQ   =AT.BILL_SEQ
                                  AND PROCESS_NO =PI_PROCESS_NO
                                  AND ACCT_GROUP =AT.ACCT_GROUP
                                  AND PROC_TYPE  =PI_PROC_TYPE
                                  AND ACCT_ID    =AT.ACCT_ID)
                ))
         UNION
         SELECT AT.ROWID,
                At.Acct_Id,
                At.Cust_Id,
                At.Ou_Id,
                At.Subscr_Cnt,
                At.Acct_Group,
                At.Bill_Currency,
                At.Acct_Status,
                At.Perm_Printing_Cat,
                At.Acct_Category,
                At.Production_Type,
                ct.cust_type, --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
                At.Pre_Bill_Nbr,
                NVL(pd.act_amt,0) act_amt, --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
                NVL(At.Pre_Bill_Amt,0) Pre_Bill_Amt,
                NVL(AT.PRE_CHRG_AMT,0) PRE_CHRG_AMT,
                DECODE(PI_PROC_TYPE,'B',At.Balance,AT.BALANCE_TEST) BALANCE,
                At.Cycle,
                At.Cycle_Month,
                AT.ACCT_KEY
           FROM Fy_Tb_Bl_Acct_List Al,
                Fy_Tb_Bl_Bill_Acct At,
                fy_tb_cm_customer Ct --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
           ,(SELECT bill_seq, CYCLE, cycle_month, acct_group, acct_id,SUM (amount) act_amt 
                FROM fy_tb_bl_bill_paid
             WHERE bill_seq = Pi_Bill_Seq AND financial_activity IN ('RFND', 'RFNDR') 
             GROUP BY bill_seq, CYCLE, cycle_month, acct_group, acct_id) pd --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
          WHERE AL.Bill_Seq    = Pi_Bill_Seq
            AND AL.TYPE        = PI_ACCT_GROUP
            AND At.Bill_Seq    = AL.Bill_Seq
            AND AT.CYCLE       = iCYCLE
            AND AT.CYCLE_MONTH = iCYCLE_MONTH
            AND AT.ACCT_KEY    = TO_NUMBER(SUBSTR(LPAD(Al.Acct_Id,18,0),-2))
            AND At.Acct_Id     = Al.Acct_Id
            AND AT.bill_seq = pd.bill_seq(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AL.bill_seq = pd.bill_seq(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AT.CYCLE = pd.CYCLE(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AL.CYCLE = pd.CYCLE(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AT.cycle_month = pd.cycle_month(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AL.cycle_month = pd.cycle_month(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AT.acct_group = pd.acct_group(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AT.acct_id = pd.acct_id(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            AND AL.acct_id = pd.acct_id(+) --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            and at.cust_id     = ct.cust_id --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
            and al.cust_id     = ct.cust_id --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
            AND Pi_Process_No = 999
            AND ((PI_PROC_TYPE='B' AND AT.BILL_STATUS ='CL') OR
                 (PI_PROC_TYPE='T' AND AT.BILL_STATUS<>'CN' AND
                  NOT EXISTS (SELECT 1 FROM FY_TB_BL_BILL_PROCESS_ERR
                                WHERE BILL_SEQ   =AL.BILL_SEQ
                                  AND PROCESS_NO =PI_PROCESS_NO
                                  AND ACCT_GROUP =AL.TYPE
                                  AND PROC_TYPE  =PI_PROC_TYPE
                                  AND ACCT_ID    =AL.ACCT_ID)
                ))
          ORDER BY Acct_Id;

      CURSOR C_BI(iACCT_ID NUMBER, iACCT_KEY NUMBER, iCYCLE NUMBER, iCYCLE_MONTH NUMBER) IS
         SELECT Bi.Acct_Id,
                Bi.Bill_Rate,
                SUM(Bi.Bill_Amt) Bill_Amt, -- �X�b���O���B
                SUM(Bi.Amount) Org_Chrg_Amt,
                SUM(Bi.Tax_Amt) Org_Tax_Amt,
                SUM(Bi.Amount - Bi.Tax_Amt) Org_Net_Amt
           FROM Fy_Tb_Bl_Bill_Bi Bi
          WHERE Bi.Bill_Seq    = Pi_Bill_Seq
            AND BI.CYCLE       = iCYCLE
            AND BI.CYCLE_MONTH = iCYCLE_MONTH
            AND BI.ACCT_KEY    = iACCT_KEY
            AND Bi.Acct_Id     = iAcct_Id
            AND Bi.CHARGE_ORG != 'NN' --2019/12/31 MODIFY �������ͤ����O���x��rounding charge���ǤJinvoice amount
            AND Pi_PROC_TYPE   = 'B'
          GROUP BY Bi.Acct_Id, Bi.Bill_Rate
         UNION
         SELECT Bi.Acct_Id,
                Bi.Bill_Rate,
                SUM(Bi.Bill_Amt) Bill_Amt, -- �X�b���O���B
                SUM(Bi.Amount) Org_Chrg_Amt,
                SUM(Bi.Tax_Amt) Org_Tax_Amt,
                SUM(Bi.Amount - Bi.Tax_Amt) Org_Net_Amt
           FROM Fy_Tb_Bl_Bill_Bi_Test Bi
          WHERE Bi.Bill_Seq    = Pi_Bill_Seq
            AND BI.CYCLE       = iCYCLE
            AND BI.CYCLE_MONTH = iCYCLE_MONTH
            AND BI.ACCT_KEY    = iACCT_KEY
            AND Bi.Acct_Id     = iAcct_Id
            AND Bi.CHARGE_ORG != 'NN' --2019/12/31 MODIFY �������ͤ����O���x��rounding charge���ǤJinvoice amount
            AND Pi_PROC_TYPE   = 'T'
          GROUP BY Bi.Acct_Id, Bi.Bill_Rate ;
      r_BI                    c_BI%ROWTYPE;

      Ch_Payment_Method       Fy_Tb_Cm_Pay_Method.Payment_Method%TYPE; --   ���ڤ覡 CA:�{��/CC:�H�Υd/DD:��b�Nú�A�p���ǤJ�ȡA�w�]��CA(�{��)
      Ch_Payment_Type         Fy_Tb_Cm_Pay_Method.Payment_Type%TYPE; --       Payment���O FY_TB_CM_PAYMENT_TYPE_MAP
      Ch_Payment_Category     Fy_Tb_Cm_Pay_Method.Payment_Category%TYPE; --       POST/PRE POST/PRE
      Ch_Bank_Code            Fy_Tb_Cm_Pay_Method.Bank_Code%TYPE; --       �Ȧ�N�X
      Ch_Bank_Acct_Type       Fy_Tb_Cm_Pay_Method.Bank_Acct_Type%TYPE; --   �Ȧ������� B:Business I:Individual
      Ch_Bank_Acct_No         Fy_Tb_Cm_Pay_Method.Bank_Acct_No%TYPE; --       �Ȧ�b��
      Ch_Bank_Branch_No       Fy_Tb_Cm_Pay_Method.Bank_Branch_No%TYPE; --    ����N�X
      Ch_Bank_Ach_Code        Fy_Tb_Cm_Pay_Method.Bank_Ach_Code%TYPE; --          ACH�N�X
      Ch_Holder_Id            Fy_Tb_Cm_Pay_Method.Holder_Id %TYPE; --       �Ȧ�b��/�H�Υd�����H�Ҹ�
      Ch_Holder_Name          Fy_Tb_Cm_Pay_Method.Holder_Name %TYPE; --    �Ȧ�b��/�H�Υd�����H�m�W
      Ch_Credit_Card_Type     Fy_Tb_Cm_Pay_Method.Credit_Card_Type %TYPE; --          �H�Υd�O
      Ch_Credit_Card_No       Fy_Tb_Cm_Pay_Method.Credit_Card_No %TYPE; --    �H�Υd��
      Dt_Credit_Card_Exp_Date Fy_Tb_Cm_Pay_Method.Credit_Card_Exp_Date %TYPE; -- �H�Υd�Ĵ�
      NU_CYCLE                FY_TB_BL_BILL_CNTRL.CYCLE%TYPE;
      NU_CYCLE_MONTH          FY_TB_BL_BILL_CNTRL.CYCLE_MONTH%TYPE;
      CH_Invoice_Type         FY_TB_BL_BILL_MAST.Invoice_Type%TYPE;
      CH_Invoice_Type_Dtl     FY_TB_BL_BILL_MAST.Invoice_Type_DTL%TYPE;
      CH_ERR_CDE              VARCHAR2(4);
      NU_CTRL_CNT             NUMBER;
      NU_ERR_CNT              NUMBER;
      NU_CNT                  NUMBER;
      NU_SHOCK_AMT            NUMBER;
      NU_LOW_AMT              NUMBER;
      CH_SHOCK                VARCHAR2(1);
      Ch_Pg_Name              VARCHAR2(100) := 'FY_PG_BL_BILL_MAST.MAIN';
      Ch_Step                 VARCHAR2(500); --2020/06/30 MODIFY FOR MPBS_Migration
      On_Err                  EXCEPTION;
      On_AT_Err               EXCEPTION;
      Dt_Due_Date             DATE := NULL;
      Nu_Mast_Seq             Fy_Tb_Bl_Bill_Mast.Mast_Seq%TYPE;
      Ch_Bill_Nbr             Fy_Tb_Bl_Bill_Mast.Bill_Nbr%TYPE;
      Ch_Bill_Period          Fy_Tb_Bl_Bill_Mast.Bill_Period%TYPE;
      NU_SHOW_CNT             NUMBER;
      NU_TAX_ID               NUMBER; --20191231
      NU_AR_CNT               NUMBER; --2020/06/30 MODIFY FOR MPBS_Migration AR PAID����CHECK
      CH_UNBILL_FLAG          FY_TB_BL_BILL_ACCT_MPBL.UNBILL_FLAG%TYPE; --2020/06/30 MODIFY FOR MPBS_Migration
   BEGIN
      ----CHECK PROCESS_NO
      CH_STEP := 'CALL Ins_Process_LOG:';
      Fy_Pg_Bl_Bill_Util.Ins_Process_LOG
                     ('MAST',  --PI_STATUS
                      Pi_Bill_Seq,
                      Pi_Proc_Type,
                      Pi_Process_No,
                      Pi_Acct_Group ,
                      Pi_User_Id ,
                      CH_Err_Cde ,
                      CH_STEP);
      IF CH_Err_Cde<>'0000' THEN
         Po_Err_Cde := CH_Err_Cde;
         Po_Err_Msg := CH_STEP;
         RAISE On_Err;
      END IF;
      Ch_Step := '���o Fy_Tb_Bl_Bill_Cntrl�������';
      SELECT Trunc(Due_Date), Bill_Period, CYCLE, CYCLE_MONTH
        INTO Dt_Due_Date, Ch_Bill_Period, NU_CYCLE, NU_CYCLE_MONTH
        FROM Fy_Tb_Bl_Bill_Cntrl
       WHERE Bill_Seq = Pi_Bill_Seq;
      BEGIN
           SELECT NUM1
             INTO NU_SHOCK_AMT
             FROM FY_TB_SYS_LOOKUP_CODE
            WHERE LOOKUP_TYPE='SHOCK_AMT'
              AND LOOKUP_CODE='AMOUNT';
      EXCEPTION WHEN OTHERS THEN
         NU_SHOCK_AMT :=0;
      END;
      BEGIN
           SELECT NUM1
             INTO NU_LOW_AMT
             FROM FY_TB_SYS_LOOKUP_CODE
            WHERE LOOKUP_TYPE='BILL_MAST'
              AND LOOKUP_CODE='AMOUNT'; --2022/02/08 MODIFY SR246834 SDWAN_NPEP solution�ظm_�ק�NU_LOW_AMT�P�_����
      EXCEPTION WHEN OTHERS THEN
         NU_LOW_AMT :=700;
      END;
      --SHOW_CNT
      BEGIN
           SELECT DECODE(NVL(NUM1,1),0,1,NUM1)
             INTO NU_SHOW_CNT
             FROM FY_TB_SYS_LOOKUP_CODE
            WHERE LOOKUP_TYPE='OUTPUT'
              AND LOOKUP_CODE='SHOW_CNT';
      EXCEPTION WHEN OTHERS THEN
         NU_SHOW_CNT :=10000;
      END;
      BEGIN
           SELECT CH1
             INTO NU_TAX_ID
             FROM FY_TB_SYS_LOOKUP_CODE
            WHERE LOOKUP_TYPE='UPDATE_DOCUMENT'
              AND LOOKUP_CODE='TAX_ID';
      EXCEPTION WHEN OTHERS THEN
         NU_TAX_ID :=70774626;
      END;

      Ch_Step := '���o�X�b�b�����';
      FOR R_AT IN c_At(NU_CYCLE, NU_CYCLE_MONTH) LOOP
         BEGIN
      dbms_output.enable(999999999999999999999);
            NU_CTRL_CNT := NVL(NU_CTRL_CNT,0)+1;
            IF MOD(NU_CTRL_CNT/NU_SHOW_CNT,1)=0 THEN
               DBMS_OUTPUT.Put_Line('CNT='||TO_CHAR(NU_CTRL_CNT));
            END IF;
            IF R_AT.BALANCE IS NULL  THEN
               Po_Err_Cde := '4001';
               Po_Err_Msg := '�|�Lú�ڸ��';
               RAISE On_AT_Err;
            END IF;
               --CHECK �l�B
               SELECT NVL(SUM(AMOUNT),0)*-1, COUNT(1)
                 INTO NU_CNT, NU_AR_CNT  --2020/06/30 MODIFY FOR MPBS_Migration AR PAID����CHECK
                 FROM FY_TB_BL_BILL_PAID
                WHERE BILL_SEQ   =PI_BILL_SEQ
                  AND CYCLE      =R_AT.CYCLE
                  AND CYCLE_MONTH=R_AT.CYCLE_MONTH
                  AND PROCESS_NO =PI_PROCESS_NO
                  AND ACCT_GROUP =PI_ACCT_GROUP
                  AND PROC_TYPE  =PI_PROC_TYPE
                  AND ACCT_ID    =R_AT.ACCT_ID
                  AND ACCT_KEY   =R_AT.ACCT_KEY;
            IF NVL(R_AT.PRE_BILL_AMT,0)-R_AT.BALANCE<>NU_CNT THEN
               Po_Err_Cde := '4001';
               Po_Err_Msg := 'ú�ھl�B���X';
               RAISE On_AT_Err;
            END IF;
            
            -- GET BILL_BI
            CH_UNBILL_FLAG := 'N';  --2020/06/30 MODIFY FOR MPBS_Migration
            OPEN C_BI(R_AT.ACCT_ID, R_AT.ACCT_KEY, R_AT.CYCLE, R_AT.CYCLE_MONTH);
            FETCH C_BI INTO R_BI;
            IF C_BI%NOTFOUND THEN
               R_BI.Bill_Rate := 1;
               R_BI.Bill_Amt  := 0;
               R_BI.Org_Chrg_Amt := 0;
               R_BI.Org_Tax_Amt := 0;
               R_BI.Org_Net_Amt := 0;
               --2020/06/30 MODIFY FOR MPBS_Migration UNBILL_FLAG�B�z
               IF Pi_User_Id='MPBL' AND R_AT.BALANCE=0 AND NU_AR_CNT=0 THEN  
                  --2021/06/15 MODIFY FOR �p�B�wú�B�z ADD MV�P�O
                  SELECT COUNT(1) INTO NU_CNT
                    FROM FY_TB_BL_BILL_MV_SUB
                   WHERE BILL_SEQ   =PI_BILL_SEQ
                     AND CYCLE      =R_AT.CYCLE
                     AND CYCLE_MONTH=R_AT.CYCLE_MONTH
                     AND (ACCT_ID   =R_AT.ACCT_ID OR PRE_ACCT_ID=R_AT.ACCT_ID);
                  IF NU_CNT=0 THEN
                     CH_UNBILL_FLAG := 'Y';
                  END IF;
               END IF;
            END IF;
                  CLOSE C_BI;
                  
                  IF Pi_User_Id='MPBL' AND R_BI.Bill_Amt < 0 THEN  --2020/06/30 MODIFY FOR MPBS_Migration
                      Po_Err_Cde := '4001';
                      Po_Err_Msg := '�����s�W���B�p��0';
                      RAISE On_AT_Err;
                  END IF;

            --2020/06/30 MODIFY FOR MPBS_Migration UNBILL_FLAG�B�z
            IF CH_UNBILL_FLAG='Y' THEN
               Ch_Step := 'MPBL UPDATE 9527 FY_TB_BL_BILL_ACCT.ACCT_ID='||TO_CHAR(R_AT.ACCT_ID);
               UPDATE FY_TB_BL_BILL_ACCT SET BILL_SEQ = '9527'||BILL_SEQ
                       WHERE BILL_SEQ = PI_BILL_SEQ AND ROWID = R_AT.ROWID;
               Ch_Step := 'MPBL UPDATE FY_TB_BL_BILL_ACCT_MPBL.ACCT_ID='||TO_CHAR(R_AT.ACCT_ID);        
               UPDATE FY_TB_BL_BILL_ACCT_MPBL SET UNBILL_FLAG=CH_UNBILL_FLAG,UPDATE_DATE =SYSDATE
                                   WHERE BILL_SEQ = PI_BILL_SEQ
                                     AND ACCT_ID  = R_AT.ACCT_ID
                                     AND ACCT_KEY = R_AT.ACCT_KEY;       
            ELSE
               Ch_Step := '���o�I�ڤ覡���';  --2020/06/30 MODIFY FOR MPBS_Migration ���ʦ�m�u�B�zUNBILL_FLAG='N'
               BEGIN
                  SELECT Payment_Method,
                         Payment_Type,
                         Payment_Category,
                         Bank_Code,
                         Bank_Acct_Type,
                         Bank_Acct_No,
                         Bank_Branch_No,
                         Bank_Ach_Code,
                         Holder_Id,
                         Holder_Name,
                         Credit_Card_Type,
                         Credit_Card_No,
                         Credit_Card_Exp_Date
                    INTO Ch_Payment_Method,
                         Ch_Payment_Type,
                         Ch_Payment_Category,
                         Ch_Bank_Code,
                         Ch_Bank_Acct_Type,
                         Ch_Bank_Acct_No,
                         Ch_Bank_Branch_No,
                         Ch_Bank_Ach_Code,
                         Ch_Holder_Id,
                         Ch_Holder_Name,
                         Ch_Credit_Card_Type,
                         Ch_Credit_Card_No,
                         Dt_Credit_Card_Exp_Date
                    FROM Fy_Tb_Cm_Pay_Method
                   WHERE Acct_Id = r_At.Acct_Id;
               EXCEPTION
                  WHEN No_Data_Found THEN
                     Ch_Payment_Method := 'CA';
               END;
               --ĵ�ܳB�z
               IF NU_SHOCK_AMT>0 AND ABS(R_AT.PRE_CHRG_AMT-R_BI.Bill_Amt)>NU_SHOCK_AMT THEN
                  CH_SHOCK := 'Y';
               ELSE
                  CH_SHOCK := 'N';
               END IF;
               --INVOICE_TYPE �B�z
               IF Pi_User_Id='MPBL' THEN --2020/06/30 MODIFY FOR MPBS_Migration MPBL������update_document
                  CH_INVOICE_TYPE := 'N';
                  CH_Invoice_Type_Dtl := 'N';
                        PO_ERR_CDE := '0000'; --2020/06/30 MODIFY FOR MPBS_Migration �M��err_code
                        PO_ERR_MSG := NULL; --2020/06/30 MODIFY FOR MPBS_Migration �M��err_message
               ELSE
               INVOICE_TYPE(PI_BILL_SEQ ,
                            PI_PROC_TYPE ,
                            NU_CYCLE,
                            Ch_Bill_Period,
                            R_AT.ACCT_ID ,
                            R_AT.CUST_ID ,
                            R_AT.PRE_BILL_NBR,
                            R_AT.PERM_PRINTING_CAT,
                            R_AT.PRODUCTION_TYPE ,
                            R_AT.CUST_TYPE, --2019/06/30 MODIFY �ð����A�B��ú���B��0�AINVOICE_TYPE := 'A'
                            r_At.Pre_Bill_Amt, --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
                            ((Nvl(r_At.Pre_Bill_Amt, 0) - Nvl(r_At.Balance, 0))*-1), --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
                            R_AT.ACT_AMT, --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
                            R_BI.Bill_Amt,
                            (Nvl(r_At.Balance, 0) + R_BI.Bill_Amt),
                            NU_LOW_AMT,
                            NU_TAX_ID, --2019/12/31 MODIFY �������ͤ����O���x��rounding charge���ǤJinvoice amount
                            R_AT.BILL_CURRENCY, --2019/12/31 MODIFY �������ͤ����O���x��rounding charge���ǤJinvoice amount
                            CH_INVOICE_TYPE ,
                            CH_Invoice_Type_Dtl ,
                            PO_ERR_CDE ,
                            PO_ERR_MSG);
               END IF;
               
               IF PO_ERR_CDE<>'0000' THEN
                  RAISE On_AT_Err;
               END IF;
               IF Pi_Proc_Type='T' THEN
                  Ch_Step := '���oMAST_SEQ��';
                  SELECT Fy_Sq_Bl_Bill_Mast_TEST.Nextval
                    INTO Nu_Mast_Seq
                    FROM Dual;
                  Ch_Step     := '���o�b�渹�X';
                  IF R_AT.CUST_TYPE IN ('D','P') THEN --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr --2020/06/30 MODIFY FOR MPBS_Migration MPBL������mast_seq�a�Jinvoice number --2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�WCUST_TYPE='P'
                     Ch_Bill_Nbr := '78' || Lpad(Nu_Mast_Seq, 10, '0');
                  ELSIF R_AT.CUST_TYPE ='N' THEN --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
                     Ch_Bill_Nbr := '66' || Lpad(Nu_Mast_Seq, 10, '0'); --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr --2020/06/30 MODIFY FOR MPBS_Migration MPBL������mast_seq�a�Jinvoice number
                  ELSE --2020/06/30 MODIFY FOR MPBS_Migration MPBL������mast_seq�a�Jinvoice number
                     Ch_Bill_Nbr := Lpad(Nu_Mast_Seq, 10, '0'); --2020/06/30 MODIFY FOR MPBS_Migration MPBL������mast_seq�a�Jinvoice number
                  END IF; --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
                  Ch_Step     := '�s�W�b����(' || Pi_Proc_Type || ')';
                  INSERT INTO Fy_Tb_Bl_Bill_Mast_Test
                                    (Mast_Seq,
                                     Bill_Nbr,
                                     Bill_Seq,
                                     Acct_Id,
                                     Bill_Period,
                                     Cycle,
                                     Cycle_Month,
                                     Due_Date,
                                     Last_Amt,
                                     Paid_Amt,
                                     Chrg_Amt,
                                     Tot_Amt,
                                     Bill_Currency,
                                     Bill_Rate,
                                     Org_Chrg_Amt,
                                     Org_Tax_Amt,
                                     Org_Net_Amt,
                                     Invoice_Type,
                                     Invoice_Type_Dtl,
                                     Perm_Printing_Cat,
                                     Payment_Method,
                                     Payment_Type,
                                     Payment_Category,
                                     Bank_Code,
                                     Bank_Acct_Type,
                                     Bank_Acct_No,
                                     Bank_Branch_No,
                                     Bank_Ach_Code,
                                     Holder_Id,
                                     Holder_Name,
                                     Credit_Card_Type,
                                     Credit_Card_No,
                                     Credit_Card_Exp_Date,
                                     SHOCK_FLAG,
                                     Create_Date,
                                     Create_User,
                                     Update_Date,
                                     Update_User)
                                VALUES
                                    (Nu_Mast_Seq,
                                     Ch_Bill_Nbr,
                                     Pi_Bill_Seq,
                                     r_At.Acct_Id,
                                     Ch_Bill_Period,
                                     r_At.Cycle,
                                     r_At.Cycle_Month,
                                     Dt_Due_Date,
                                     r_At.Pre_Bill_Amt,
                                     (Nvl(r_At.Pre_Bill_Amt, 0) - Nvl(r_At.Balance, 0))*-1,
                                     R_BI.Bill_Amt,
                                     (Nvl(r_At.Balance, 0) + R_BI.Bill_Amt),
                                     r_At.Bill_Currency,
                                     R_BI.Bill_Rate,
                                     R_BI.Org_Chrg_Amt,
                                     R_BI.Org_Tax_Amt,
                                     R_BI.Org_Net_Amt,
                                     CH_Invoice_Type,
                                     CH_Invoice_Type_Dtl,
                                     r_At.Perm_Printing_Cat,
                                     Ch_Payment_Method,
                                     Ch_Payment_Type,
                                     Ch_Payment_Category,
                                     Ch_Bank_Code,
                                     Ch_Bank_Acct_Type,
                                     Ch_Bank_Acct_No,
                                     Ch_Bank_Branch_No,
                                     Ch_Bank_Ach_Code,
                                     Ch_Holder_Id,
                                     Ch_Holder_Name,
                                     Ch_Credit_Card_Type,
                                     Ch_Credit_Card_No,
                                     TO_CHAR(Dt_Credit_Card_Exp_Date,'YYYYMM'),
                                     CH_SHOCK,
                                     SYSDATE,
                                     Pi_User_Id,
                                     SYSDATE,
                                     Pi_User_Id);
               ELSE
                  Ch_Step := '���oMAST_SEQ��';
                  SELECT Fy_Sq_Bl_Bill_Mast.Nextval
                    INTO Nu_Mast_Seq
                    FROM Dual;
                  Ch_Step     := '���o�b�渹�X';
                  IF R_AT.CUST_TYPE ='D' THEN --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr --2020/06/30 MODIFY FOR MPBS_Migration MPBL������mast_seq�a�Jinvoice number
                     Ch_Bill_Nbr := '78' || Lpad(Nu_Mast_Seq, 10, '0');
                  ELSIF R_AT.CUST_TYPE ='N' THEN --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
                     Ch_Bill_Nbr := '66' || Lpad(Nu_Mast_Seq, 10, '0'); --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr --2020/06/30 MODIFY FOR MPBS_Migration MPBL������mast_seq�a�Jinvoice number
                  ELSE --2020/06/30 MODIFY FOR MPBS_Migration MPBL������mast_seq�a�Jinvoice number
                     Ch_Bill_Nbr := Lpad(Nu_Mast_Seq, 10, '0'); --2020/06/30 MODIFY FOR MPBS_Migration MPBL������mast_seq�a�Jinvoice number
                  END IF; --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
                  Ch_Step     := '�s�W�b����(' || Pi_Proc_Type || ')';
                  INSERT INTO Fy_Tb_Bl_Bill_Mast
                                    (Mast_Seq,
                                     Bill_Nbr,
                                     Bill_Seq,
                                     Acct_Id,
                                     Bill_Period,
                                     Cycle,
                                     Cycle_Month,
                                     Due_Date,
                                     Last_Amt,
                                     Paid_Amt,
                                     Chrg_Amt,
                                     Tot_Amt,
                                     Bill_Currency,
                                     Bill_Rate,
                                     Org_Chrg_Amt,
                                     Org_Tax_Amt,
                                     Org_Net_Amt,
                                     Invoice_Type,
                                     Invoice_Type_Dtl,
                                     Perm_Printing_Cat,
                                     Payment_Method,
                                     Payment_Type,
                                     Payment_Category,
                                     Bank_Code,
                                     Bank_Acct_Type,
                                     Bank_Acct_No,
                                     Bank_Branch_No,
                                     Bank_Ach_Code,
                                     Holder_Id,
                                     Holder_Name,
                                     Credit_Card_Type,
                                     Credit_Card_No,
                                     Credit_Card_Exp_Date,
                                     SHOCK_FLAG,
                                     Create_Date,
                                     Create_User,
                                     Update_Date,
                                     Update_User)
                                VALUES
                                    (Nu_Mast_Seq,
                                     Ch_Bill_Nbr,
                                     Pi_Bill_Seq,
                                     r_At.Acct_Id,
                                     Ch_Bill_Period,
                                     r_At.Cycle,
                                     r_At.Cycle_Month,
                                     Dt_Due_Date,
                                     r_At.Pre_Bill_Amt,
                                     (Nvl(r_At.Pre_Bill_Amt, 0) - Nvl(r_At.Balance, 0))*-1,
                                     R_BI.Bill_Amt,
                                     (Nvl(r_At.Balance, 0) + R_BI.Bill_Amt),
                                     r_At.Bill_Currency,
                                     R_BI.Bill_Rate,
                                     R_BI.Org_Chrg_Amt,
                                     R_BI.Org_Tax_Amt,
                                     R_BI.Org_Net_Amt,
                                     CH_Invoice_Type,
                                     CH_Invoice_Type_Dtl,
                                     r_At.Perm_Printing_Cat,
                                     Ch_Payment_Method,
                                     Ch_Payment_Type,
                                     Ch_Payment_Category,
                                     Ch_Bank_Code,
                                     Ch_Bank_Acct_Type,
                                     Ch_Bank_Acct_No,
                                     Ch_Bank_Branch_No,
                                     Ch_Bank_Ach_Code,
                                     Ch_Holder_Id,
                                     Ch_Holder_Name,
                                     Ch_Credit_Card_Type,
                                     Ch_Credit_Card_No,
                                     TO_CHAR(Dt_Credit_Card_Exp_Date,'YYYYMM'),
                                     CH_SHOCK,
                                     SYSDATE,
                                     Pi_User_Id,
                                     SYSDATE,
                                     Pi_User_Id);
                  Ch_Step:= 'UPDATE BILL_ACCT.ACCT_ID=' || TO_CHAR(R_AT.ACCT_ID) || ':';
                  UPDATE FY_TB_BL_BILL_ACCT SET BILL_STATUS='MA'
                                   WHERE ROWID = R_AT.ROWID;
               END IF; --Pi_Proc_Type='T'
            END IF;  --CH_UNBILL_FLAG='Y' --2020/06/30 MODIFY FOR MPBS_Migration UNBILL_FLAG�B�z   
         EXCEPTION
            WHEN ON_AT_ERR THEN
           DBMS_OUTPUT.Put_Line('EXCE_'||TO_CHAR(NU_CTRL_CNT+1)||':ACCT_ID='||TO_CHAR(R_AT.ACCT_ID));
               NU_ERR_CNT := NVL(NU_ERR_CNT,0) + 1;
               CH_STEP := PO_ERR_MSG;
               ROLLBACK;
               -- '�s�W�X�b���~�O����';
               Fy_Pg_Bl_Bill_Util.Ins_Process_Err(Pi_Bill_Seq,
                                                  Pi_Proc_Type,
                                                  r_At.Acct_Id,
                                                  NULL,
                                                  Pi_Process_No,
                                                  Pi_Acct_Group,
                                                  Ch_Pg_Name,
                                                  Pi_User_Id,
                                                  '4092',
                                                  Ch_Step,
                                                  CH_Err_Cde,
                                                  Po_Err_Msg);
               IF CH_Err_Cde<>'0000' THEN
                  Po_Err_Cde := CH_Err_Cde;
                  RAISE On_Err;
               END IF;
            WHEN OTHERS THEN
               NU_ERR_CNT := NVL(NU_ERR_CNT,0) + 1;
               ROLLBACK;
               -- '�s�W�X�b���~�O����';
               Fy_Pg_Bl_Bill_Util.Ins_Process_Err(Pi_Bill_Seq,
                                                  Pi_Proc_Type,
                                                  r_At.Acct_Id,
                                                  NULL,
                                                  Pi_Process_No,
                                                  Pi_Acct_Group,
                                                  Ch_Pg_Name,
                                                  Pi_User_Id,
                                                  '4092',
                                                  Substr(Ch_Step || ',' || SQLERRM, 1, 250),
                                                  CH_Err_Cde,
                                                  Po_Err_Msg);
               IF CH_Err_Cde<>'0000' THEN
                  Po_Err_Cde := CH_Err_Cde;
                  RAISE On_Err;
               END IF;
         END;
         COMMIT;
      END LOOP; --C_AT
      --
      CH_STEP := 'UPDATE PROCESS_LOG.BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||':';
      UPDATE FY_TB_BL_BILL_PROCESS_LOG BL SET END_TIME=SYSDATE,
                                              COUNT   =NU_CTRL_CNT
                                        WHERE BILL_SEQ  = PI_BILL_SEQ
                                          AND PROCESS_NO= PI_PROCESS_NO
                                          AND ACCT_GROUP= PI_ACCT_GROUP
                                          AND PROC_TYPE = PI_PROC_TYPE
                                          AND STATUS    = 'MAST'
                                          AND END_TIME IS NULL;
      --UPDATE BILL_CNTRL
      SELECT COUNT(1) INTO NU_CNT
        FROM FY_TB_BL_BILL_ACCT
        WHERE BILL_SEQ   =PI_BILL_SEQ
          AND CYCLE      =NU_CYCLE
          AND CYCLE_MONTH=NU_CYCLE_MONTH
          --2019/01/02 MODIFY select count(1) from FY_TB_BL_BILL_ACCT.BILL_STATUS NOT IN ('MAST','CN') > ('MA','CN')
          AND BILL_STATUS NOT IN ('MA','CN');
          
      --2020/06/30 MODIFY FOR MPBS_Migration ACCT_CNT�B�z  
      IF PI_USER_ID='MPBL' THEN
         SELECT COUNT(1) INTO NU_AR_CNT
           FROM FY_TB_BL_BILL_ACCT
          WHERE BILL_SEQ   =PI_BILL_SEQ
            AND CYCLE      =NU_CYCLE
            AND CYCLE_MONTH=NU_CYCLE_MONTH;
      END IF; 
       
      IF NU_CNT=0 OR PI_USER_ID='MPBL' THEN --2020/06/30 MODIFY FOR MPBS_Migration ADD PI_USER_ID CHECK 
         CH_STEP := 'UPDATE BILL_CNTRL.BILL_SEQ='||TO_CHAR(PI_BILL_SEQ)||':';
         UPDATE FY_TB_BL_BILL_CNTRL SET STATUS      =DECODE(NU_CNT,0,'MAST',STATUS),
                                        ACCT_COUNT  =DECODE(PI_USER_ID,'MPBL',NU_AR_CNT,ACCT_COUNT),  --2020/06/30 MODIFY FOR MPBS_Migration ACCT_CNT�B�z
                                        UPDATE_DATE =SYSDATE,
                                        UPDATE_USER =PI_USER_ID
                                  WHERE BILL_SEQ=PI_BILL_SEQ;
      END IF;
      DBMS_OUTPUT.Put_Line('CNT='||TO_CHAR(NU_CTRL_CNT));
      PO_ERR_CDE := '0000';
      PO_ERR_MSG := NULL;
      COMMIT;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '4999';
         Po_Err_Msg := Substr('BILL_MAST:' || Ch_Step || ',' || SQLERRM, 1, 250);
   END Main;

   /*************************************************************************
      PROCEDURE : INVOICE_TYPE
      PURPOSE :   INVOICE_TYPE / INVOICE_TYPE_DTL �B�z
      DESCRIPTION : INVOICE_TYPE/INVOICE_TYPE_DTL �B�z
      PARAMETER:
            PI_BILL_SEQ           :�X�b�Ǹ�
            PI_PROC_TYPE          :���櫬�A �w�]�� B (B: �����X�b, T:���եX�b)
            PI_CYCLE              :�g��
            PI_BILL_PERIOD        :�X�b�~��
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_PRE_BILL_NBR       :�W���b��
            PI_PERM_PRINTING_CAT  :�Ȥ�����
            PI_PRODUCTION_TYPE    :�b������
            PI_CUSTOMER_TYPE      :CUST���� --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
            PI_LAST_AMT           :�W����ú --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            PI_PAID_AMT           :�W��ú�ڪ��B --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            PI_ACT_AMT            :�h�ڻP�����h�ڪ��B --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
            PI_CHRG_AMT           :�������B
            PI_TOT_AMT            :��ú���B
            PI_LOW_AMT            :�̧C���B
            PI_TAX_ID             :�����귽�Τ@�s�� --2019/12/31 MODIFY �������ͤ����O���x��rounding charge���ǤJinvoice amount
            PI_BILL_CURRENCY      :���O --2019/12/31 MODIFY �������ͤ����O���x��rounding charge���ǤJinvoice amount
            PO_INVOICE_TYPE       :Invoice����
            PO_INVOICE_DTL        :Invoice�����Ӷ�
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE INVOICE_TYPE(PI_BILL_SEQ             IN     FY_TB_BL_BILL_ACCT.BILL_SEQ%TYPE,
                          PI_PROC_TYPE            IN     FY_TB_BL_BILL_PROCESS_LOG.PROC_TYPE%TYPE,
                          PI_CYCLE                IN     FY_TB_BL_BILL_CNTRL.CYCLE%TYPE,
                          PI_BILL_PERIOD          IN     FY_TB_BL_BILL_CNTRL.BILL_PERIOD%TYPE,
                          PI_ACCT_ID              IN     FY_TB_BL_BILL_ACCT.ACCT_ID%TYPE,
                          PI_CUST_ID              IN     FY_TB_BL_BILL_ACCT.CUST_ID%TYPE,
                          PI_PRE_BILL_NBR         IN     FY_TB_BL_BILL_ACCT.PRE_BILL_NBR%TYPE,
                          PI_PERM_PRINTING_CAT    IN     FY_TB_BL_BILL_ACCT.PERM_PRINTING_CAT%TYPE,
                          PI_PRODUCTION_TYPE      IN     FY_TB_BL_BILL_ACCT.PRODUCTION_TYPE%TYPE,
                          PI_CUSTOMER_TYPE        IN     FY_TB_CM_CUSTOMER.CUST_TYPE%TYPE, --2019/06/30 MODIFY �ð����A�B��ú���B��0�AINVOICE_TYPE := 'A'
                          PI_LAST_AMT             IN     NUMBER, --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
                          PI_PAID_AMT             IN     NUMBER, --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
                          PI_ACT_AMT              IN     NUMBER, --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
                          PI_CHRG_AMT             IN     NUMBER,
                          PI_TOT_AMT              IN     NUMBER,
                          PI_LOW_AMT              IN     NUMBER,
                          PI_TAX_ID               IN     NUMBER, --2019/12/31 MODIFY �������ͤ����O���x��rounding charge���ǤJinvoice amount
                          PI_BILL_CURRENCY        IN     FY_TB_BL_BILL_ACCT.BILL_CURRENCY%TYPE,
                          PO_INVOICE_TYPE        OUT     FY_TB_BL_BILL_MAST.INVOICE_TYPE%TYPE,
                          PO_INVOICE_DTL         OUT     FY_TB_BL_BILL_MAST.INVOICE_TYPE_DTL%TYPE,
                          PO_ERR_CDE             OUT     VARCHAR2,
                          PO_ERR_MSG             OUT     VARCHAR2) IS

      NU_CNT             NUMBER  :=0;
      CH_FLAG            VARCHAR2(1);
      CH_INVOICE_TYPE    FY_TB_BL_BILL_MAST.INVOICE_TYPE%TYPE;
      CH_INVOICE_DTL     FY_TB_BL_BILL_MAST.INVOICE_TYPE_DTL%TYPE;
      CH_L9_DOC_PRODUCE_IND    FY_TB_BL_ACCOUNT.L9_DOC_PRODUCE_IND%TYPE; --NPEP 2.1 �j���H
      ON_ERR             EXCEPTION;
   BEGIN
         CH_INVOICE_TYPE:= 'N';
         CH_INVOICE_DTL := 'N';
         BEGIN
              SELECT 'U'
                INTO CH_INVOICE_TYPE
                FROM FY_TB_BL_BILL_MAST
               WHERE ACCT_ID     =PI_ACCT_ID
                 AND CYCLE       =PI_CYCLE
            AND CYCLE_MONTH =TO_NUMBER(TO_CHAR(ADD_MONTHS(TO_DATE(PI_BILL_PERIOD||'01','YYYYMMDD'),-1),'MM'))
            AND ACCT_KEY    =TO_NUMBER(SUBSTR(LPAD(PI_ACCT_ID,18,0),-2))
                 AND BILL_NBR    =PI_PRE_BILL_NBR
                 AND INVOICE_TYPE='S';
         EXCEPTION WHEN OTHERS THEN
            NULL;
         END;
         
         --NPEP 2.1 �j���H
         BEGIN
            SELECT nvl(L9_DOC_PRODUCE_IND,'N')
              INTO CH_L9_DOC_PRODUCE_IND
              FROM FY_TB_BL_ACCOUNT A
             WHERE A.ACCT_ID=PI_ACCT_ID;
         EXCEPTION WHEN OTHERS THEN
            NULL;
         END;
         
         IF PI_PERM_PRINTING_CAT IN ('F','M') AND PI_CUSTOMER_TYPE IN ('D','N','P') THEN --2019/06/30 MODIFY F6_EBU,CBU customer_type�ư�('F','M','S','U') --2019/12/31 MODIFY INVOICE_TYPE �s�W�DIOT���A(F,M)�A�ư��DIOT���AS>N, Z�������ҡA�ק�S�b�污�� --NPEP 2.1 CUSTOMER_TYPE IN ('D','N') --2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�WCUST_TYPE='P'
            CH_INVOICE_TYPE := PI_PERM_PRINTING_CAT;
         END IF;

         IF PI_PERM_PRINTING_CAT = 'M' AND PI_CUSTOMER_TYPE IN ('D','N','P') AND PI_CHRG_AMT != 0 THEN --2021/10/20 MODIFY SR239378 SDWAN_NPEP solution�ظm --2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�WCUST_TYPE='P'
            CH_INVOICE_TYPE := 'N';
         END IF;
         
         IF CH_INVOICE_TYPE='N' THEN
          IF PI_TOT_AMT<=PI_LOW_AMT AND PI_TOT_AMT>0 AND PI_LAST_AMT+PI_PAID_AMT=0 AND PI_PERM_PRINTING_CAT='N' AND CH_L9_DOC_PRODUCE_IND='N' AND PI_BILL_CURRENCY='NTD' AND PI_CUSTOMER_TYPE IN ('D','P') THEN --2019/12/31 MODIFY INVOICE_TYPE �s�W�DIOT���A(F,M)�A�ư��DIOT���AS>N, Z�������ҡA�ק�S�b�污�� --2020/05/28�W�[AND PI_CUSTOMER_TYPE='D' --2021/04/01 MODIFY SR228032_NPEP 2.1 - ����PI_CUSTOMER_TYPE='D' --2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�WCUST_TYPE='P'
          --ADD PI_PERM_PRINTING_CAT --��ú --2019/06/30 MODIFY F6_EBU,CBU customer_type�ư�('F','M','S','U')
               CH_INVOICE_TYPE :='S';
            ELSIF PI_TOT_AMT<=PI_LOW_AMT AND PI_TOT_AMT>0 AND PI_LAST_AMT<=PI_PAID_AMT*-1 AND PI_PERM_PRINTING_CAT='N' AND CH_L9_DOC_PRODUCE_IND='N' AND PI_BILL_CURRENCY='NTD' AND PI_CUSTOMER_TYPE='N' THEN --NPEP 2.1 HGBN����H(������)1�B�~��H(�~�y�H�h�ҷӸ��X)0 --2023/03/13 MODIFY FOR SR257682_SKIP BILL Rule�վ�--�����ձb�P�_
                SELECT COUNT(1)
                    INTO NU_CNT
                FROM fy_tb_cm_prof_link
                  WHERE entity_type = 'A'
                  AND link_type = 'A'
                  AND prof_type = 'NAME'
                  AND entity_id = PI_ACCT_ID
                  AND elem5 IN ('0', '1');
                IF NU_CNT>0 THEN
                    CH_INVOICE_TYPE := 'S';
                END IF;
               --�C���BAR���ձb(CREDIT)����& perm_printing_cat='N' --2023/03/13 MODIFY FOR SR257682_SKIP BILL Rule�վ�--�����ձb�P�_
               --SELECT COUNT(1)
               --  INTO NU_CNT
               --  FROM FET1_customer_credit b
               -- WHERE b.Partition_Id =mod(PI_ACCT_ID,10)
               --and b.period_key   =PI_BILL_PERIOD
               --and b.account_id = PI_ACCT_ID
               --   AND b.billing_arrangement_id = PI_ACCT_ID
               --   AND b.bill_seq_no = PI_BILL_SEQ;
               --IF NU_CNT>0 THEN
               --   CH_INVOICE_TYPE :='N';
               --   CH_INVOICE_DTL :='J';
               --ELSIF PI_PRODUCTION_TYPE='FR' THEN --2021/04/01 MODIFY SR234553_����0���B�C���B�Ĥ@������H��H
               --   --�Ĥ@��S (FR)
               --   BEGIN
               --         SELECT 'N', 'V'
               --           INTO CH_INVOICE_TYPE, CH_INVOICE_DTL
               --           FROM FY_TB_CM_CUSTOMER b
               --       WHERE b.CUST_ID = PI_CUST_ID
               --       --AND b.CUST_type <> 'Q';
               --      AND b.CUST_type NOT IN ('Q', 'N'); --2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N'
               --   EXCEPTION WHEN OTHERS THEN
               --      NULL;
               --   END;
               --END IF;
            ELSE
               IF PI_PERM_PRINTING_CAT='X' AND PI_PAID_AMT=0 AND PI_TOT_AMT-PI_LAST_AMT-PI_PAID_AMT=0 THEN --�ð� --2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
                  CH_INVOICE_TYPE := 'A';
               --ELSIF PI_LAST_AMT<=0 AND PI_PAID_AMT=0 AND PI_CHRG_AMT=0 AND PI_TOT_AMT<=0 AND PI_CUSTOMER_TYPE='N' THEN --NPEP 2.1�D�ð�N>A
               --   CH_INVOICE_TYPE := 'A';
               ELSE
                  IF PI_TOT_AMT=0 AND PI_PERM_PRINTING_CAT IN ('X', 'N', 'L', 'T') THEN  --��ú=0
                  CH_INVOICE_TYPE := 'Z';
                  --2019/12/31 MODIFY INVOICE_TYPE �s�W�DIOT���A(F,M)�A�ư��DIOT���AS>N, Z�������ҡA�ק�S�b�污��
                        IF PI_CUSTOMER_TYPE = 'N' THEN --NPEP 2.1����CUST_TYPE='O'
                            IF PI_PROC_TYPE='T' THEN
                                SELECT SUM(a.AMOUNT) --NPEP 2.1���O�`�B>0
                                    INTO NU_CNT
                                    FROM FY_TB_BL_BILL_CI_TEST a,
                                            (SELECT entity_id
                                                FROM fy_tb_cm_prof_link
                                                WHERE entity_type = 'A'
                                                AND link_type = 'A'
                                                AND prof_type = 'NAME'
                                                AND elem5 IN ('2', '3', '20')) b
                                    WHERE a.ACCT_ID =PI_ACCT_ID
                                    AND a.ACCT_ID = b.entity_id
                                    AND a.ACCT_KEY=TO_NUMBER(SUBSTR(LPAD(PI_ACCT_ID,18,0),-2))
                                    AND a.BILL_SEQ=PI_BILL_SEQ;
                            ELSE
                                SELECT SUM(a.AMOUNT) --NPEP 2.1���O�`�B>0
                                    INTO NU_CNT
                                    FROM FY_TB_BL_BILL_CI a,
                                            (SELECT entity_id
                                                FROM fy_tb_cm_prof_link
                                                WHERE entity_type = 'A'
                                                AND link_type = 'A'
                                                AND prof_type = 'NAME'
                                                AND elem5 IN ('2', '3', '20')) b
                                    WHERE a.ACCT_ID =PI_ACCT_ID
                                    AND a.ACCT_ID = b.entity_id
                                    AND a.ACCT_KEY=TO_NUMBER(SUBSTR(LPAD(PI_ACCT_ID,18,0),-2))
                                    AND a.BILL_SEQ=PI_BILL_SEQ;
                            END IF;
                                IF NU_CNT>0 THEN --NPEP 2.1���O�`�B>0
                                    CH_INVOICE_TYPE := 'N';
                                    CH_INVOICE_DTL  := 'G';
                                END IF;
                        END IF;
                     --IF PI_PRODUCTION_TYPE='FR' THEN --2021/04/01 MODIFY SR234553_����0���B�C���B�Ĥ@������H��H
                     --   BEGIN
                     --         --�Ĥ@��Z (FR)
                     --       SELECT 'N', 'F'
                    --                INTO CH_INVOICE_TYPE, CH_INVOICE_DTL
                    --            FROM FY_TB_CM_CUSTOMER b
                     --       WHERE b.CUST_ID = PI_CUST_ID
                     --         AND b.CUST_TYPE <> 'N'; --2019/12/31 MODIFY INVOICE_TYPE �s�W�DIOT���A(F,M)�A�ư��DIOT���AS>N, Z�������ҡA�ק�S�b�污�� --NPEP 2.1����CUST_TYPE='O'�A����OR����
                     --   EXCEPTION WHEN OTHERS THEN
                     --      NULL;
                     --   END;
                     --ELS
                     IF PI_PRODUCTION_TYPE='RF' THEN
                        --��������b�� (RF�BDR)
                     CH_INVOICE_TYPE:='A';
                     CH_INVOICE_DTL :='Q';
                     ELSE
                        --�������ϥ�BDE�wú���B�A�B�j���H=Y�A�B�D��������b��
                        BEGIN
                              SELECT 'N','P'
                                INTO CH_INVOICE_TYPE, CH_INVOICE_DTL
                                FROM FY_TB_BL_ACCOUNT A
                               WHERE A.ACCT_ID=PI_ACCT_ID
                                 AND A.L9_DOC_PRODUCE_IND='Y'
                                 AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG
                                               WHERE ACCT_ID =A.ACCT_ID
                                                 AND ACCT_KEY=TO_NUMBER(SUBSTR(LPAD(A.ACCT_ID,18,0),-2))
                                                 AND PREPAYMENT IS NOT NULL
                                                 AND NVL(BILL_USE_QTY,0) > 0 --20200519
                                                 AND ((PI_PROC_TYPE='B' AND RECUR_SEQ=PI_BILL_SEQ) OR
                                                      (PI_PROC_TYPE='T' AND TEST_RECUR_SEQ=PI_BILL_SEQ))
                                             );
                        EXCEPTION WHEN OTHERS THEN
                           NULL;
                        END;
                     END IF;
                  END IF; --PI_CHRG_AMT=0
               END IF;  --PI_PERM_PRINTING_CAT='X'
         END IF;  --PI_CHRG_AMT<=PI_LOW_AMT
         END IF ; --CH_INVOICE_TYPE='N'

        IF CH_INVOICE_TYPE = 'N' AND PI_ACT_AMT <= 0 AND PI_PAID_AMT=0 AND PI_TOT_AMT-PI_LAST_AMT-PI_PAID_AMT=0 THEN --�h�ڻP�����h��<=0 --20190815
                  CH_INVOICE_TYPE := 'A'; --20190815
                  CH_INVOICE_DTL := 'R'; --20190815
        END IF; --20190815

        IF CH_INVOICE_TYPE='A' THEN
           IF PI_TOT_AMT >0 THEN
              CH_INVOICE_TYPE := 'N';
              CH_INVOICE_DTL  := 'D';
           ELSIF PI_PERM_PRINTING_CAT='X' AND PI_TOT_AMT < 0 AND (PI_PAID_AMT <> 0 OR PI_CHRG_AMT <> 0) AND PI_CUSTOMER_TYPE = 'D' THEN --SR276005_SKIP BILL Rule�վ�--�s�W���b+N��ú�ڳq��
              CH_INVOICE_TYPE := 'N';
              CH_INVOICE_DTL  := 'E';
           ELSE
              --�������ϥ�BDE�wú���B
              SELECT COUNT(1)
                INTO NU_CNT
                FROM FY_TB_BL_ACCT_PKG
                WHERE ACCT_ID =PI_ACCT_ID
                  AND ACCT_KEY=TO_NUMBER(SUBSTR(LPAD(PI_ACCT_ID,18,0),-2))
                  AND PREPAYMENT IS NOT NULL
                  AND BILL_USE_QTY > 0 --2019/12/31 MODIFY �W�[SKIPBILL�P�_������ϥ�BDE�����B
                  AND ((PI_PROC_TYPE='B' AND RECUR_SEQ=PI_BILL_SEQ) OR
                        (PI_PROC_TYPE='T' AND TEST_RECUR_SEQ=PI_BILL_SEQ));
               IF NU_CNT>0 THEN
                  CH_INVOICE_TYPE := 'N';
                  CH_INVOICE_DTL  := 'B';
              END IF;
            END IF;
      END IF;
         PO_INVOICE_TYPE := CH_INVOICE_TYPE;
         PO_INVOICE_DTL  := CH_INVOICE_DTL;
         PO_ERR_CDE := '0000';
      PO_ERR_MSG := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         PO_Err_Cde := '9999';
         PO_Err_Msg := Substr('CALL INVOICE_TYPE: '|| SQLERRM, 1, 250);
   END INVOICE_TYPE;

END FY_PG_BL_BILL_MAST;
/