CREATE OR REPLACE PACKAGE FY_PG_BL_BILL_BI IS
   /*
      -- Author  : FOYA
      -- Created : 2018/09/01
      -- Purpose : UBL�p��ROUNDING by TAX_TYPE�A�~���B�z�ADYNAMIC_ATTRIBUTE�զX
      -- Version :
      --             1.0    2018/09/01 CREATE 
      --             1.1    2018/09/25 modify 0�����B�z�A���O���P�ײv�B�z
      --             1.2    2018/09/26 modify CET GET FY_TB_PBK_CHARGE_CODE�ݰϤ�
      --             1.3    2018/10/02 modify GET_BI. CHARGE_ORG (RA/CC/DE/IN)
      --             1.4    2018/10/08 modify CHARGE_ORG='DE' --> CHARGE_TYPE='DSC' & DYNAMIC_ATTRIBUTE�B�z, CHARGE_ORG
      --             1.5    2018/10/09 modify DYNAMIC_ATTRIBUTE���OFFER_INSTANCE_ID
      --             1.6    2018/10/24 modify UC GROUP BY �qCET�אּCHARGE_CODE & ADD UC CHRG_DATE�B�z
      --             2.0    2018/10/29 modify TABLE SCAN INDEX�Ϊk_ACCT_KEY
      --             2.0    2018/11/07 modify Remaining=bill_qty���ϥΫe���B
      --             2.1    2019/06/30 MODIFY FY_TB_BL_BILL_BI add UC DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
      --             2.2    2019/11/11 MODIFY SR219716_IOT�wú�馩 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
      --             2.3    2019/12/31 MODIFY �p��x����DYNAMIC_ATTRIBUTE�A�������ͤ����O���x��rounding charge
      --             2.3    2019/12/31 MODIFY overwrite SUB TAX_TYPE & LOOKUP_CODE TAX_RATE ACCOUNT (CANCEL)
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration �s�W�O�渹�X�B�z
      --             3.1    2021/02/23 MODIFY FOR MPBS_Migration �ץ��P�^��CI.BI_SEQ�ǽT��
      --             3.2    2021/04/29 MODIFY MODIFY FOR SR237202_AWS�bHGB �]�w�����s�|�v(�S��M�׳]�w) 
      --             4.0    2021/06/15 MODIFY FOR �p�B�wú�B�z
      --             4.1    2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID �B�z
      --             4.1    2022/04/08 MODIFY FOR 425�b��4G�wú�l�B���
      --             4.2    2022/10/14 SR255529_PN�馩�����ק�
      --             5.0    2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�WCYCLE(15,20)
      --             5.1    2023/04/20 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�W�q�H�~���ഫ�|�v�\��
      --             5.2    2024/07/30 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1�A�ק�馩group����
   */
   
   ----------------------------------------------------------------------------------------------------
   --�@���ܼ�
   ----------------------------------------------------------------------------------------------------
     gnBILL_SEQ          NUMBER;
     gnPROCESS_NO        NUMBER;
     gvACCT_GROUP        FY_TB_BL_BILL_ACCT.ACCT_GROUP%TYPE;
     gvSTEP              VARCHAR2(300);
     gvERR_CDE           VARCHAR2(4);
     gvERR_MSG           VARCHAR2(300);
     gvPROC_TYPE         VARCHAR2(1);--'T'��ܬO���� 'B'��ܬO����
     gdBILL_DATE         DATE;--�X�b���
     gdBILL_FROM_DATE    DATE;--�X�b�O�b�_�l��
     gdBILL_END_DATE     DATE;--�X�b�O�b������
     gnFROM_DAY          FY_TB_BL_CYCLE.FROM_DAY%TYPE;
     gnCYCLE             FY_TB_BL_CYCLE.CYCLE%TYPE;--�X�b�g��(05 15 25)
     gvBILL_PERIOD       FY_TB_BL_CYCLE.CURRECT_PERIOD%TYPE;--�X�b�~��
     gnACCT_ID           FY_TB_BL_BILL_ACCT.ACCT_ID%TYPE;--�ثe�X�쪺�b��
     gnACCT_OU_ID        FY_TB_BL_BILL_CI.OU_ID%TYPE;
     gnCUST_ID           FY_TB_BL_BILL_ACCT.CUST_ID%TYPE;--�ثe�X�쪺����
     gnSUBSCR_ID         FY_TB_BL_BILL_CI.SUBSCR_ID%TYPE;--�ثe�X�쪺�Τ�
     gnOU_ID             FY_TB_BL_BILL_CI.OU_ID%TYPE;
     gnCYCLE_MONTH       FY_TB_BL_BILL_CI.CYCLE_MONTH%TYPE;
     gvUSER              FY_TB_BL_BILL_CI.CREATE_USER%TYPE;
     gvROUND_TX1         FY_TB_BL_BILL_CI.CHARGE_CODE%TYPE;
     gnRATE_TX1          NUMBER;
     gvROUND_TX2         FY_TB_BL_BILL_CI.CHARGE_CODE%TYPE;
     gnRATE_TX2          NUMBER;
     gvROUND_TX3         FY_TB_BL_BILL_CI.CHARGE_CODE%TYPE;
     gnRATE_TX3          NUMBER;
     gvBILL_CURRENCY     FY_TB_BL_BILL_ACCT.BILL_CURRENCY%TYPE;
     gnRATE_SCALE        NUMBER; --�ײv�p��p�Ʀ��  
     gvDYNAMIC_ATTRIBUTE FY_TB_BL_BILL_BI.DYNAMIC_ATTRIBUTE%TYPE;
   ----------------------------------------------------------------------------------------------------
   
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL_BI �B�z
      DESCRIPTION : BL BILL_BI �B�z
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
   **************************************************************************/
   PROCEDURE MAIN(PI_BILL_SEQ       IN   NUMBER,
                  PI_PROCESS_NO     IN   NUMBER,
                  PI_ACCT_GROUP     IN   VARCHAR2,
                  PI_PROC_TYPE      IN   VARCHAR2 DEFAULT 'B',  
                  PI_USER_ID        IN   VARCHAR2, 
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2); 
                  
   /*************************************************************************
      PROCEDURE : GEN_BI
      PURPOSE :   �w��CI SUMMARY TO BI (FOR UC/OC)
      DESCRIPTION : �w��CI SUMMARY TO BI (FOR UC/OC)
      PARAMETER:
            
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID �B�z
   **************************************************************************/
   PROCEDURE GEN_BI;
   
   /*************************************************************************
      PROCEDURE : INS_BI
      PURPOSE :   �g�p������(BI)�� BILL_BI  
      DESCRIPTION : �g�p������(BI)�� BILL_BI
      PARAMETER:
            PI_CHARGE_CODE             :�b�涵��
            PI_CHARGE_ORG              :RA/CC/DE/IN
            PI_AMOUNT                  :���B
            PI_TAX_AMT                 :�|�B(PI_CHARGE_ORG=IN)
            PI_OFFER_INSTANCE_ID       :OFFER_INSTANCE_ID
            PI_OFFER_SEQ               :OFFER_SEQ
            PI_OFFER_ID                :OFFER �s��
            PI_PKG_ID                  :PKG_ID
            PI_SOURCE                  :RC/OC/UC/DE/IN
            PI_CHRG_DATE               :�p�O���
            PI_CHRG_FROM_DATE          :�p�O�_�l��
            PI_CHRG_END_DATE           :�p�O�I���
            PI_CHARGE_DESCR            :���廡��(CHARGE_CODE)
            PI_SERVICE_RECEIVER_TYPE   :�O���k�ݶ��h(A/O/S)
            PI_DYNAMIC_ATTRIBUTE       :DYNAMIC_ATTRIBUTE 
            PI_CORRECT_SEQ             :MAX(CORRECT_SEQ)
            PI_CI_SEQ                  :CI_SEQ
            PO_BI_SEQ                  :BI_SEQ            
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
      4.0   2021/06/15      FOYA       MODIFY FOR �p�B�wú�B�z
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
                    PO_BI_SEQ                 OUT    NUMBER);
   
   /*************************************************************************
      PROCEDURE : DO_ROUND
      PURPOSE :   BL BILL_BI ROUND �B�z
      DESCRIPTION : BL BILL_BI ROUND �B�z
      PARAMETER:
            
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE DO_ROUND ;

   /*************************************************************************
      PROCEDURE : DO_ROUND_FIX
      PURPOSE :   BL BILL_BI ROUND �B�z�b����B�]TAX_RATE�ɭP���~�t
      DESCRIPTION : ��b�椺�e�P�ɦ����PTAX_RATE�ɡAsummary���B>=0.5&<1�ɸ�1��rounding charge�Asummary���B>=1&<1.5�ɸ�-1��rounding charge�A�קK�y���ȶD
      PARAMETER:
            
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2019/12/31      MikeKuan     �s��
   **************************************************************************/
   PROCEDURE DO_ROUND_FIX ;
   
      /*************************************************************************
      PROCEDURE : DO_NTD_ROUND
      PURPOSE :   BL BILL_BI ROUND �B�z
      DESCRIPTION : ��������x��rounding charge
      PARAMETER:
            
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2019/12/31      MikeKuan       �s��
   **************************************************************************/
   PROCEDURE DO_NTD_ROUND ;
   
   /*************************************************************************
      PROCEDURE : GET_CURRENCY
      PURPOSE :   �~�����B����B�z
      DESCRIPTION : �~�����B����B�z
      PARAMETER:
            PI_BILL_CURRENCY      :������O
            PI_AMOUNT             :���B 
            PO_BILL_AMT           :����ײv
            PO_BILL_RATE          :������B     
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE GET_CURRENCY(PI_BILL_CURRENCY    IN    VARCHAR2,
                          PI_AMOUNT           IN    NUMBER, 
                          PO_BILL_AMT        OUT    NUMBER,
                          PO_BILL_RATE       OUT    NUMBER,
                          PO_ERR_CDE         OUT   VARCHAR2,
                          PO_ERR_MSG         OUT   VARCHAR2);

   /*************************************************************************
      PROCEDURE : GET_NTD_CURRENCY
      PURPOSE :   �x�����B����B�z
      DESCRIPTION : �x�����B����B�z
      PARAMETER:
            PI_BILL_CURRENCY      :������O
            PI_AMOUNT             :���B 
            PO_BILL_AMT           :����ײv
            PO_BILL_RATE          :������B     
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2019/12/31      MikeKuan       �s��
   **************************************************************************/
   PROCEDURE GET_NTD_CURRENCY(PI_BILL_CURRENCY    IN    VARCHAR2,
                              PI_AMOUNT           IN    NUMBER, 
                              NU_TAX_AMT          IN    NUMBER, 
                              PO_BILL_AMT        OUT    NUMBER,
                              PO_BILL_TAX_AMT    OUT    NUMBER,
                              PO_BILL_RATE       OUT    NUMBER,
                              PO_ERR_CDE         OUT   VARCHAR2,
                              PO_ERR_MSG         OUT   VARCHAR2);
                
END;
/