CREATE OR REPLACE PACKAGE HGBBLAPPO.Fy_Pg_Bl_Bill_Util IS
   
   /*
      -- Author  : USER
      -- Created : 2018/9/1
      -- Purpose : �X�b���ε{��
      -- Version :
      --             1.0    2018/09/01 CREATE 
      --             1.1    2018/09/20 modify Ins_Process_LOG add status='CN'�B�z
      --             1.2    2018/10/03 modify format
      --             1.3    2018/10/30 modify CUSDATE INSERT PROCESS_LOG
      --             2.0    2018/11/14 modify ADD RC�պ�
      --             2.1    2020/06/09 MODIFY SR226548_����(���Y)���~�ȪA�s�A�Ȩt�Ϋظm
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration ADD PROCEDURE:CHECK_MPBL
      --             4.0    2021/06/15 MODIFY FOR �p�B�wú�B�z MARKET_PKG ADD�Ѽ�PROC_TYPE,BILL_SEQ
   */
   --�O��OFFER�h��
   TYPE OFFER_Rec IS RECORD(
      OFFER_SEQ        number);

   TYPE OFFER_CUR IS TABLE OF OFFER_Rec INDEX BY BINARY_INTEGER;
   
   ----------------------------------------------------------------------------------------------------
   --�@���ܼ�
   ----------------------------------------------------------------------------------------------------
     gnBILL_SEQ          NUMBER;
     gvSTEP              VARCHAR2(300);
     gvERR_CDE           VARCHAR2(4);
     gvERR_MSG           VARCHAR2(300);
     gvCI_STEP           VARCHAR2(5);
     gdBILL_DATE         DATE;--�X�b���
     gdBILL_FROM_DATE    DATE;--�X�b�O�b�_�l��
     gdBILL_END_DATE     DATE;--�X�b�O�b������
     gnFROM_DAY          FY_TB_BL_CYCLE.FROM_DAY%TYPE;
     gnCYCLE             FY_TB_BL_CYCLE.CYCLE%TYPE;--�X�b�g��(05 15 25)
     gnACCT_ID           FY_TB_BL_BILL_ACCT.ACCT_ID%TYPE;--�ثe�X�쪺�b��
     gnCUST_ID           FY_TB_BL_BILL_ACCT.CUST_ID%TYPE;--�ثe�X�쪺����
     gnSUBSCR_ID         FY_TB_BL_BILL_CI.SUBSCR_ID%TYPE;--�ثe�X�쪺�Τ�
     gnOU_ID             FY_TB_BL_BILL_CI.OU_ID%TYPE;
     gnCYCLE_MONTH       FY_TB_BL_BILL_CI.CYCLE_MONTH%TYPE;
     gnOFFER_SEQ         FY_TB_BL_BILL_CI.OFFER_SEQ%TYPE;
     gnOFFER_ID          FY_TB_BL_BILL_CI.OFFER_ID%TYPE;
     gnOFFER_INSTANCE_ID FY_TB_BL_BILL_CI.OFFER_INSTANCE_ID%TYPE;
     gnPKG_ID            FY_TB_BL_ACCT_PKG.PKG_ID%TYPE;
     gvOFFER_LEVEL       FY_TB_BL_ACCT_PKG.OFFER_LEVEL%TYPE;
     gvOFFER_NAME        FY_TB_BL_ACCT_PKG.OFFER_NAME%TYPE;  
     gnACCT_PKG_SEQ      FY_TB_BL_ACCT_PKG.ACCT_PKG_SEQ%TYPE;  
     gnOFFER_LEVEL_ID    FY_TB_BL_ACCT_PKG.OFFER_LEVEL_ID%TYPE;
     gvQTY_CONDITION     FY_TB_PBK_PKG_DISCOUNT.QTY_CONDITION%TYPE;
     gvPRICING_TYPE      FY_TB_PBK_PKG_DISCOUNT.PRICING_TYPE%TYPE;
     gvPRORATE_METHOD    FY_TB_PBK_PKG_DISCOUNT.PRORATE_METHOD%TYPE;
     gvPAYMENT_TIMING    FY_TB_PBK_PACKAGE_RC.PAYMENT_TIMING%TYPE;
     gnFREQUENCY         FY_TB_PBK_PACKAGE_RC.FREQUENCY%TYPE;
     gvRECURRING         FY_TB_PBK_PKG_DISCOUNT.RECURRING%TYPE;
     gvCHRG_ID           FY_TB_BL_BILL_CI.CHRG_ID%TYPE; 
     gvCHARGE_CODE       FY_TB_BL_BILL_CI.CHARGE_CODE%TYPE; 
     gvOVERWRITE         FY_TB_BL_BILL_CI.OVERWRITE%TYPE; 
     gvUSER              FY_TB_BL_BILL_CI.CREATE_USER%TYPE;
   
   ----------------------------------------------------------------------------------------------------
   
   /*************************************************************************
      PROCEDURE : Ins_Process_Err
      PURPOSE :   �X�b�{��Ins_Process_ERR �B�z
      DESCRIPTION : �X�b�{��Ins_Process_ERR �B�z
      PARAMETER:
            PI_BILL_SEQ           :�X�b�Ǹ�
            PI_PROC_TYPE          :���櫬�A �w�]�� B (B: �����X�b, T:���եX�b)  
            Pi_Acct_Id            :ACCT_ID
            Pi_SUBSCR_Id          :SUBSCR_ID
            PI_PROCESS_NO         :����Ǹ�
            PI_ACCT_GROUP         :�Ȥ�����OR ACCT_LIST.TYPE
            PI_PG_NAME            :����{���N��
            PI_USER_ID            :����USER_ID    
            PI_ERR_CDE            :����ERR_CODE
            PI_ERR_MSG            :����ERR_MSG     
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
            
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
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
                             Po_Err_Msg    OUT VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : Ins_Process_LOG
      PURPOSE :   �X�b�{��Ins_Process_LOG �B�z
      DESCRIPTION : �X�b�{��Ins_Process_LOG �B�z
      PARAMETER:
            PI_STATUS             :�X�b���ACI/BI/MAST/CN
            PI_BILL_SEQ           :�X�b�Ǹ�
            PI_PROC_TYPE          :���櫬�A �w�]�� B (B: �����X�b, T:���եX�b)  
            PI_PROCESS_NO         :����Ǹ�
            PI_ACCT_GROUP         :�Ȥ�����OR ACCT_LIST.TYPE
            PI_USER_ID            :����USER_ID         
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
            
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/   
   PROCEDURE Ins_Process_LOG(PI_STATUS     IN FY_TB_BL_BILL_PROCESS_LOG.STATUS%TYPE,
                             Pi_Bill_Seq   IN Fy_Tb_Bl_Bill_Process_Err.Bill_Seq%TYPE,
                             Pi_Proc_Type  IN Fy_Tb_Bl_Bill_Process_Err.Proc_Type%TYPE,
                             Pi_Process_No IN Fy_Tb_Bl_Bill_Process_Err.Process_No%TYPE,
                             Pi_Acct_Group IN Fy_Tb_Bl_Bill_Process_Err.Acct_Group%TYPE,
                             Pi_User_Id    IN Fy_Tb_Bl_Bill_Process_Err.Create_User%TYPE,
                             Po_Err_Cde    OUT VARCHAR2,
                             Po_Err_Msg    OUT VARCHAR2); 
   
   /*************************************************************************
      PROCEDURE : MARKET_PKG
      PURPOSE :   MARKET_MOVE���PCYCLE ACCT_PKG �B�z
      DESCRIPTION : MARKET_MOVE���PCYCLE ACCT_PKG �B�z
      PARAMETER:
            PI_CYCLE              :�X�bCYCLE
            PI_ACCT_PKG_SEQ       :ACCT_PKG_SEQ
            PI_TRANS_DATE         :������  
            PI_PROC_TYPE          :���櫬�A �w�]�� B (B: �����X�b, T:���եX�b)
            PI_BILL_SEQ           :�X�b�Ǹ�
            PI_USER               :USER_ID    
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
            
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      4.0   2021/06/15      FOYA       MODIFY FOR �p�B�wú�B�z ADD�Ѽ�PROC_TYPE,BILL_SEQ
   **************************************************************************/
   PROCEDURE MARKET_PKG(PI_CYCLE            IN   NUMBER,
                        PI_ACCT_PKG_SEQ     IN   NUMBER,
                        PI_TRANS_DATE       IN   DATE,  
                        PI_PROC_TYPE        IN   VARCHAR2 DEFAULT 'B',  --2021/06/15 MODIFY FOR �p�B�wú�B�z
                        PI_BILL_SEQ         IN   NUMBER,      --2021/06/15 MODIFY FOR �p�B�wú�B�z   
                        PI_USER             IN   VARCHAR2,
                        PO_ERR_CDE         OUT   VARCHAR2,
                        PO_ERR_MSG         OUT   VARCHAR2);  
   
   /*************************************************************************
      PROCEDURE : QUERY_ACCT_PKG
      PURPOSE :   ACCT_PKG QUERY �B�z
      DESCRIPTION : ACCT_PKG QUERY �B�z
      PARAMETER:
            PI_ACCT_ID            :�X�b�b��   
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE QUERY_ACCT_PKG(PI_ACCT_ID            IN   NUMBER,
                            PO_ERR_CDE           OUT   VARCHAR2,
                            PO_ERR_MSG           OUT   VARCHAR2);
                             
   /*************************************************************************
      PROCEDURE : DO_RECUR
      PURPOSE :   �p��Τ�믲�O
      DESCRIPTION : �p��Τ�믲�O
      PARAMETER:
            PI_ACCT_ID            :ACCT_ID
            PI_BILL_SEQ           :�X�b�Ǹ�
            PI_CYCLE              :�X�b�g��
            PI_CYCLE_MONTH        :�X�b���  
            PI_BILL_FROM_DATE     :�X�b�_�l��
            PI_BILL_END_DATE      :�X�b�I���
            PI_BILL_DATE          :�X�b��       
            PI_FROM_DAY           :FROM_DAY  
            PI_END_DATE           :�p�O�I���
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
            
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
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
                      PO_ERR_MSG       OUT   VARCHAR2);  
                      
   /*************************************************************************
      PROCEDURE : GET_ACTIVE_DAY
      PURPOSE :   GET SUBSCR_ID ACTIVE DAY
      DESCRIPTION : GET SUBSCR_ID ACTIVE DAY
      PARAMETER:
            PI_TYPE               :DE:GET ACTIVE_DAY/RC:INSERT ACTIVE_DAY
            PI_START_DATE         :�p��}�l��
            PI_END_DATE           :�p��I���
            PI_AMY_QTY            :�p�O�ƶq 
            PI_Tab_PKG_RATES      :PBK�h�ҶO�v
            PO_ACTIVE_DAY         :�p�����ACTIVE�Ѽ�(�������ܤѼ�)
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE GET_ACTIVE_DAY(PI_TYPE             IN   VARCHAR2,
                            PI_START_DATE       IN   DATE,
                            PI_END_DATE         IN   DATE,
                            PI_AMY_QTY          IN   NUMBER,
                            PI_Tab_PKG_RATES    IN   FY_PG_BL_BILL_CI.t_PKG_RATES,
                            PO_ACTIVE_DAY      OUT   NUMBER);
   
   /*************************************************************************
      PROCEDURE : DO_RC_ACTIVE
      PURPOSE :   DO SUBSCR_ID ACTIVE DAY RC�B�z
      DESCRIPTION : DO SUBSCR_ID ACTIVE DAY RC�B�z
      PARAMETER:
            PI_START_DATE         :�p��}�l��
            PI_END_DATE           :�p��I���
            PI_AMY_QTY            :�p�O�ƶq
            PI_Tab_PKG_RATES      :PBK�h�ҶO�v
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE DO_RC_ACTIVE(PI_START_DATE       IN   DATE,
                          PI_END_DATE         IN   DATE,
                          PI_AMY_QTY          IN   NUMBER,
                          PI_Tab_PKG_RATES    IN   FY_PG_BL_BILL_CI.t_PKG_RATES);
   
   /*************************************************************************
      PROCEDURE : GET_MONTH
      PURPOSE :   �p��Ӱ_���鬰���(�p��4��)      
      DESCRIPTION : �p��Ӱ_���鬰���(�p��4��)
      PARAMETER:
            PI_START_DATE         :�p��}�l��
            PI_END_DATE           :�p��I���
            PO_ACTIVE_DAY         :�p�����ACTIVE�Ѽ�(�������ܤѼ�) 
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE GET_MONTH(PI_START_DATE       IN   DATE,
                       PI_END_DATE         IN   DATE,
                       PO_MONTH           OUT   NUMBER);
   
   /*************************************************************************
      PROCEDURE : INS_CI
      PURPOSE :   �g�p������(CI)�� BILL_CI(PKG�����I�s�ϥΡA���Q�~���I�s)     
      DESCRIPTION : �g�p������(CI)�� BILL_CI
      PARAMETER:
            PI_START_DATE              :�p��}�l��
            PI_END_DATE                :�p��I���
            PI_SOURCE                  :���ͮɾ�(UC/OC/RC/DE)  
            PI_SOURCE_CI_SEQ           :�馩�ӷ�
            PI_SOURCE_OFFER_ID         :�ӷ�OFFER �s��
            PI_SERVICE_RECEIVER_TYPE   :�O���k�ݶ��h(S:Subscr/A:ACCT/U:OU)
            PI_AMOUNT                  :���B
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE INS_CI(PI_START_DATE               IN   DATE,
                    PI_END_DATE                 IN   DATE,
                    PI_SOURCE                   IN   VARCHAR2,
                    PI_SOURCE_CI_SEQ            IN   NUMBER,
                    PI_SOURCE_OFFER_ID          IN   NUMBER,
                    PI_SERVICE_RECEIVER_TYPE    IN   VARCHAR2,
                    PI_AMOUNT                   IN   NUMBER);   
                    
   /*************************************************************************
      PROCEDURE : CHECK_MPBL
      PURPOSE :   CHECK CUST_ID�O�_��MPBL      
      DESCRIPTION : CHECK CUST_ID�O�_��MPBL  
      PARAMETER:
            PI_CUST_ID            :CUST_ID
            PO_MPBL               :Y:MPBL/N
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X���� 
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2020/06/30      FOYA       CREATE FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE CHECK_MPBL(PI_CUST_ID          IN   NUMBER,
                        PO_MPBL            OUT   VARCHAR2,
                        PO_ERR_CDE         OUT   VARCHAR2,
                        PO_ERR_MSG         OUT   VARCHAR2);                                                                                                                             

END Fy_Pg_Bl_Bill_Util;
/
