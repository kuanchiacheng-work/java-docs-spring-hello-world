CREATE OR REPLACE PACKAGE HGBBLAPPO.FY_PG_BL_BILL_CI IS
   /*
      -- Author  : FOYA
      -- Created : 2018/09/01
      -- Purpose : UBL�p�⦬�O�P�馩�AMV�馩�Ѿl���B����
      -- Version :
      --             1.0    2018/09/01 CREATE
      --             1.1    2018/09/18 modify get_month_�p����trunc(�ǤJ���)
      --             1.2    2018/09/19 modify INSERT BILL_CI TRUNC(���) & ROUND(AMOUNT,2) & ADD FY_TB_PBK_CRITERION_GROUP.REVENUE_CODE IS NULL
      --             1.3    2018/09/21 modify GET_CONTRIBUTE�ϥζq�ഫ(Byte),ROUND�B�z, QUOTA OVERWITE
      --             1.4    2018/09/28 modify add process_no=999 MV check
      --             1.5    2018/10/03 modify fy_tb_bl_bill_offer_param.param_name���k
      --             1.6    2018/10/05 modify CHARGE_ORG='DE' --> CHARGE_TYPE='DSC' & ACCT_KEY���k
      --             1.7    2018/10/08 modify DO_DISCOUNT ORDER BY OFFER_SEQ
      --             1.8    2018/10/12 modify MARKET MOVE �DPREPAYMNET �B�z
      --             1.9    2018/10/15 modify FY_TB_PBK_CRITERION_GROUP �P�O
      --             1.10   2018/10/24 modify UC ADD CHRG_DATE�B�z
      --             1.11   2018/10/30 modify TABLE SCAN INDEX�Ϊk_ACCT_KEY
      --             1.12   2018/11/28 modify Pkg_rates_Rec�ܼƪ���
      --             2.0    2018/12/03 modify FY_TB_RAT_SUMMARY/FY_TB_BL_BILL_CI.CDR_QTY(��쬰B),���@����ഫ��ADD PBK.QTY_E CHECK
      --             2.1    2019/06/30 MODIFY FY_TB_BL_BILL_CI add UC DYNAMIC_ATTRIBUTE
      --             2.2    2019/11/05 MODIFY SR219716_IOT�wú�馩�AEND_RSN��CREQ�BEND_DATE�p��BILL_DATE�ɧ馩����
      --             2.3    2019/12/12 MODIFY SR220754_AI_Star_FY_TB_BL_ACCT_PKG�W�[���MV�馩��UNION
      --             2.4    2019/12/31 MODIFY �w���p��_�W�ɶ��B�w��suspend�Ѽƭp��
      --             2.5    2020/02/14 MODIFY MV���o���X�L�b�B�������ϥΪ̪�BDE�Ѿl���B
      --             2.5    2020/02/14 MODIFY MV�����D�̫�@��SUB���Ѿl���B
      --             2.5    2020/02/14 MODIFY MV�s�W�D�̫�@��SUB���Ѿl���B=0
      --             2.5    2020/02/25 MODIFY �ư��p�O�ѼƶȤ@�Ѫ����
      --             2.6    2020/06/09 MODIFY SR226548_����(���Y)���~�ȪA�s�A�Ȩt�Ϋظm
      --             2.7    2020/06/12 MODIFY SR215584_NPEP�M�סA�w���h�O�ק�
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration �s�W�s�w�F��RC�`�B�B�z
      --             3.1    2021/02/17 MODIFY SR228032 - NPEP �M�� Phase 2.1
      --             4.0    2021/06/15 MODIFY FOR �p�B�wú�B�z 
      --             4.1    2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID �B�z    
      --             4.2    2021/10/06 MODIFY FOR �p�B�wú�B�z(�ק�PROCEDURE DO_DISCOUNT)
      --             4.3    2021/10/20 MODIFY SR239378 SDWAN_NPEP solution�ظm
      --             4.4    2022/04/07 MODIFY FOR �ץ�MV��BDE�L����y�����B�ܬ�0���D
      --             4.5    2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project
      --             4.6    2023/03/06 MODIFY FOR HGBN�w���A���O�W�v�P�_���ɶ����A����PO_MONTH�A�קK�W���u���{�H�o��
      --             4.7    2023/04/06 MODIFY FOR SR250171_ESDP_Migration_Project_Migration_���}�멳�̫�@�Ѹ��U��X�b�P�s�W/�ק惡�qDBMS
      --             5.0    2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�WCYCLE(15,20)
      --             5.1    2023/04/20 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�W��ú�w���\��
      --             5.2    2023/04/28 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�W��ú�w�����ΰh�O
      --             5.3    2023/05/03 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�u�����ʶW�L�X�b��v�T
      --             5.4    2023/07/25 MODIFY FOR SR260229_Project-M Fixed line Phase I�ASUSPEND���ưh�O���D�ץ�
      --             5.5    2023/07/25 MODIFY FOR SR250171_ESDP_Migration_Project_Migration_��ú�e�������b�椣���w�X�b��BILL_END_DATE����
      --             5.6    2023/10/16 MODIFY FOR SR263630_LSP���~��ƻݨD�}�o�A�s�W�T�~ú�w��
      --             5.7    2023/10/16 MODIFY FOR SR260229_Project-M Fixed line Phase 1.1�A�᦬DFC�h��
      --             5.8    2023/12/28 MODIFY FOR SR260229_Project-M Fixed line Phase 1.1�A�᦬DFC�h�ڡADFC������Ѧw�˷�Ѳ���
      --             5.9    2024/04/16 MODIFY FOR SR266082_ICT�M�סA�馩�����t�����B
      --             6.0    2024/06/27 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1�A�ץ�ACCT_PKG�ݰѦҥX�bSUB�W��
      --             6.1    2024/11/21 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1�A�W�[IoT�C��pkg�����s�����l��
   */
   --�O��PKG�h�ҶO�v
   TYPE Pkg_rates_Rec IS RECORD(
      ITEM_NO        number,  --1-5��
      QTY_S          number,
      QTY_E          number,
      RATES          number);

   TYPE t_Pkg_rates IS TABLE OF Pkg_rates_Rec INDEX BY BINARY_INTEGER;

   ----------------------------------------------------------------------------------------------------
   --�@���ܼ�
   ----------------------------------------------------------------------------------------------------
     gnBILL_SEQ          NUMBER;
     gnPROCESS_NO        NUMBER;
     gvACCT_GROUP        FY_TB_BL_BILL_ACCT.ACCT_GROUP%TYPE;
     gvSTEP              VARCHAR2(300);
     gvERR_CDE           VARCHAR2(4);
     gvERR_MSG           VARCHAR2(300);
     gvCI_STEP           VARCHAR2(5);
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
     gnOFFER_SEQ         FY_TB_BL_BILL_CI.OFFER_SEQ%TYPE;
     gnOFFER_ID          FY_TB_BL_BILL_CI.OFFER_ID%TYPE;
     gnOFFER_INSTANCE_ID FY_TB_BL_BILL_CI.OFFER_INSTANCE_ID%TYPE;
     gnPKG_ID            FY_TB_BL_ACCT_PKG.PKG_ID%TYPE;
     gvOFFER_LEVEL       FY_TB_BL_ACCT_PKG.OFFER_LEVEL%TYPE;
     gvOFFER_NAME        FY_TB_BL_ACCT_PKG.OFFER_NAME%TYPE;
     gnACCT_PKG_SEQ      FY_TB_BL_ACCT_PKG.ACCT_PKG_SEQ%TYPE;
     gnEND_DATE          FY_TB_BL_ACCT_PKG.END_DATE%TYPE; --2020/06/30 MODIFY FOR MPBS_Migration �馩���Ө����
     gnFUTURE_EXP_DATE   FY_TB_BL_ACCT_PKG.FUTURE_EXP_DATE%TYPE; --2020/06/30 MODIFY FOR MPBS_Migration �馩���Ө����
     gnPKG_TYPE_DTL      FY_TB_BL_ACCT_PKG.PKG_TYPE_DTL%TYPE; --20191231
     gnOFFER_LEVEL_ID    FY_TB_BL_ACCT_PKG.OFFER_LEVEL_ID%TYPE;
     gvBILL_CURRENCY     FY_TB_BL_BILL_ACCT.BILL_CURRENCY%TYPE;
     gvQTY_CONDITION     FY_TB_PBK_PKG_DISCOUNT.QTY_CONDITION%TYPE;
     gvDIS_UOM_METHOD    FY_TB_PBK_PKG_DISCOUNT.DIS_UOM_METHOD%TYPE;
     gnQUOTA             FY_TB_PBK_PKG_DISCOUNT.QUOTA%TYPE; --2022/07/05 MODIFY FOR SR250171_ESDP_Migration_Project ����HBO�馩�ƶq
     gvPRICING_TYPE      FY_TB_PBK_PKG_DISCOUNT.PRICING_TYPE%TYPE;
     gvPRORATE_METHOD    FY_TB_PBK_PKG_DISCOUNT.PRORATE_METHOD%TYPE;
     gvPAYMENT_TIMING    FY_TB_PBK_PACKAGE_RC.PAYMENT_TIMING%TYPE;
     gnFREQUENCY         FY_TB_PBK_PACKAGE_RC.FREQUENCY%TYPE;
     gvRECURRING         FY_TB_PBK_PKG_DISCOUNT.RECURRING%TYPE;
     gvCHRG_ID           FY_TB_BL_BILL_CI.CHRG_ID%TYPE;
     gvCHARGE_CODE       FY_TB_BL_BILL_CI.CHARGE_CODE%TYPE;
     gvOVERWRITE         FY_TB_BL_BILL_CI.OVERWRITE%TYPE;
     gvUSER              FY_TB_BL_BILL_CI.CREATE_USER%TYPE;
     gnROLLING_QTY       NUMBER;
     gvMARKET_LEVEL      VARCHAR2(1);
     gbHAS_BILL          BOOLEAN;--�O�_�����ͶO��
     gvTMNEWA            VARCHAR2(1); --'N':�D�s�w�F��/'Y':�s�w�F��--2020/06/30 MODIFY FOR MPBS_Migration �O�_���s�w�F��
     gnPRT_ID            NUMBER;      --2020/06/30 MODIFY FOR MPBS_Migration �s�w�F��PRT_ID�Ѽ�
     gvPRT_VALUE         FY_TB_SYS_LOOKUP_CODE.CH1%TYPE;  --2020/06/30 MODIFY FOR MPBS_Migration �s�w�F��PRT_VALUE�Ѽ�
     gvPARAM_NAME        FY_TB_SYS_LOOKUP_CODE.CH1%TYPE;  --2020/06/30 MODIFY FOR MPBS_Migration �s�w�F��PARAM_NAME�Ѽ�
     gnROUNDING          NUMBER;      --2020/06/30 MODIFY FOR MPBS_Migration �s�w�F��ROUNDING���
     gvTXN_ID            FY_TB_BL_BILL_CI.TXN_ID%TYPE;    --2020/06/30 MODIFY FOR MPBS_Migration �O�渹�X
     gdLAST_DATE         DATE  ;      --2020/06/30 MODIFY FOR MPBS_Migration �̫�ACTIVE EFF_DATE
     gvDYNAMIC_ATTRIBUTE FY_TB_BL_BILL_CI.DYNAMIC_ATTRIBUTE%TYPE;  --2020/06/30 MODIFY FOR MPBS_Migration 
     gnBILL_SUBSCR_ID    NUMBER;   --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID �B�z
     gvPREPAYMENT        FY_TB_BL_ACCT_PKG.PREPAYMENT%TYPE;  --2021/06/15 MODIFY FOR �p�B�wú�B�z
     gvPN_FLAG           VARCHAR2(1);   --'N':�DPN/'Y':PN--2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID �B�z
     gvSDWAN             VARCHAR2(1); --'N':�DSDWAN/'Y':SDWAN--2021/10/20 MODIFY SR239378 SDWAN_NPEP solution�ظm �O�_��SDWAN
     gvDFC               VARCHAR2(1); --'N':�DDEACT_FOR_CHANGE/'Y':DEACT_FOR_CHANGE--2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project �O�_��DEACT_FOR_CHANGE

   ----------------------------------------------------------------------------------------------------
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL_CI �B�z
      DESCRIPTION : BL BILL_CI �B�z
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
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration GET�s�w�F�ʦ@�ΰѼ�
      4.0   2021/06/15      FOYA       MODIFY FOR �p�B�wú�B�z Fy_Pg_Bl_Bill_Util.MARKET_PKG ADD�Ѽ�PROC_TYPE,BILL_SEQ
   **************************************************************************/
   PROCEDURE MAIN(PI_BILL_SEQ       IN   NUMBER,
                  PI_PROCESS_NO     IN   NUMBER,
                  PI_ACCT_GROUP     IN   VARCHAR2,
                  PI_PROC_TYPE      IN   VARCHAR2 DEFAULT 'B',
                  PI_USER_ID        IN   VARCHAR2,
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2);

   /*************************************************************************
      PROCEDURE : GET_UC
      PURPOSE :   GET UC DATA FOR RAT_SUMMARY
      DESCRIPTION : GET UC DATA FOR RAT_SUMMARY
      PARAMETER:
            PI_UC_FLAG            :UC���O(Y:SYNC RAT)

      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration �qFY_TB_RAT_SUMMARY ��FY_TB_RAT_SUMMARY_BILL, 
                                                                 ADD ITEM FY_TB_BL_BILL_CI.TXN_ID
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID �B�z
   **************************************************************************/
   PROCEDURE GET_UC(PI_UC_FLAG      IN   VARCHAR2);

   /*************************************************************************
      PROCEDURE : DO_RECUR
      PURPOSE :   �p��Τ�믲�O
      DESCRIPTION : �p��Τ�믲�O
      PARAMETER:


      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration �s�w�F���`�B�ޱ��B�z
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID �B�z
   **************************************************************************/
   PROCEDURE DO_RECUR;

   /*************************************************************************
      PROCEDURE : DO_DISCOUNT
      PURPOSE :   �p��Τ�馩���
      DESCRIPTION : �p��Τ�馩���
      PARAMETER:
            PI_PROC_ID             :����Ǹ�(1:ACCT_GROUP='MV'_�u����PRE_SUBSCR IS NULL/2:�u����MV)
            PI_SUBSCR_ID           :����Ǹ�=2:�����SUBSCR_ID
            PI_PRE_CYCLE           :PRE_ACCT_ID CYCLE

      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration �W�[�s�w�F�ʧP�O
      4.0   2021/06/15      FOYA       MODIFY FOR �p�B�wú�B�z
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID �B�z
   **************************************************************************/
   PROCEDURE DO_DISCOUNT(PI_PROC_ID       IN   NUMBER,
                         PI_SUBSCR_ID     IN   NUMBER,
                         PI_PRE_CYCLE     IN   NUMBER);

   /*************************************************************************
      PROCEDURE : GET_CONTRIBUTE
      PURPOSE :   �w��PBK�w�q��CONTRIBUTE�A�P�_�O�_�ŦX���
      DESCRIPTION : �w��PBK�w�q��CONTRIBUTE�A�P�_�O�_�ŦX���
      PARAMETER:
            PI_CONTRIBUTE_IN        :������s�եN�X_IN
            PI_CONTRIBUTE_EX        :������s�եN�X_EX
            PI_Tab_PKG_RATES        :PBK�h�ҶO�v
            PI_EFF_DATE             :�馩OFFER�ͮĤ�
            PO_CONTRIBUTE_CNT       :������ƶq
            PO_CRI_ORDER            :������էO

      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration �W�[�Ѽ�&�s�w�F��RC OFFER�ͮĤ饲���p��馩�ͮĤ�
      4.0   2021/06/15      FOYA       MODIFY FOR �p�B�wú�B�z
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID �B�z
   **************************************************************************/
   PROCEDURE GET_CONTRIBUTE(PI_CONTRIBUTE_IN      IN   NUMBER,
                            PI_CONTRIBUTE_EX      IN   NUMBER,
                            PI_Tab_PKG_RATES      IN   t_PKG_RATES,
                            PI_EFF_DATE           IN   DATE,
                            PO_CONTRIBUTE_CNT    OUT   NUMBER,
                            PO_CRI_ORDER         OUT   NUMBER) ;

   /*************************************************************************
      PROCEDURE : DO_ELIGIBLE
      PURPOSE :   �w��PBK�w�q��ELIGIBLE�A�p��DISCOUNT���B
      DESCRIPTION : �w��PBK�w�q��ELIGIBLE�A�p��DISCOUNT���B
      PARAMETER:
            PI_ELIGIBLE_IN        :������s�եN�X_IN
            PI_ELIGIBLE_EX        :������s�եN�X_EX
            PI_CONTRIBUTE_CNT     :������ƶq
            PI_CRI_ORDER          :������էO
            PI_FROM_DATE          :�p��_�l��
            PI_END_DATE           :�p��I���
            PI_Tab_PKG_RATES      :PBK�h�ҶO�v
            PI_MARKET             :MARKET MOVE FLAG(Y:MARKET MOVE/N)
            PI_EFF_DATE           :�馩OFFER�ͮĤ�
            PO_PKG_DISC           :�馩���B
            PO_PKG_QTY            :�i�ϥζq
            PO_PKG_USE            :�ϥζq

      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration �W�[�Ѽ�&�s�w�F��RC OFFER�ͮĤ饲���p��馩�ͮĤ�
      4.0   2021/06/15      FOYA       MODIFY FOR �p�B�wú�B�z
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID �B�z
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
                         PO_PKG_USE         OUT   NUMBER);

   /*************************************************************************
      PROCEDURE : GET_SUSPEND_DAY
      PURPOSE :   GET SUBSCR_ID SUSPEND DAY
      DESCRIPTION : GET SUBSCR_ID SUSPEND DAY
      PARAMETER:
            PI_TYPE               :RC:INSERT SUSPEND_DAY
            PI_AMY_QTY            :�p�O�ƶq
            PI_Tab_PKG_RATES      :PBK�h�ҶO�v
            PO_ACTIVE_DAY         :�p�����SUSPEND�Ѽ�
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration DO_RC_ACTIVE�s�W��ӰѼ�PI_RC_CTRL_AMT,PO_RC_AMT
   **************************************************************************/
   PROCEDURE GET_SUSPEND_DAY(PI_TYPE             IN   VARCHAR2,
                            PI_AMY_QTY          IN   NUMBER,
                            PI_Tab_PKG_RATES    IN   t_PKG_RATES,
                            PI_CUR_BILLED       IN    DATE,
                            PO_ACTIVE_DAY      OUT   NUMBER);
                            
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
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration ADD�s�w�F��GET RC�����`�B����
   **************************************************************************/
   PROCEDURE GET_ACTIVE_DAY(PI_TYPE             IN   VARCHAR2,
                            PI_START_DATE       IN   DATE,
                            PI_END_DATE         IN   DATE,
                            PI_AMY_QTY          IN   NUMBER,
                            PI_Tab_PKG_RATES    IN   t_PKG_RATES,
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
            PI_RC_CTRL_AMT        :�s�w�F������RC�`�B
            PO_RC_AMT             :����RC���B
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration �s�W��ӰѼ�PI_RC_CTRL_AMT,PO_RC_AMT
   **************************************************************************/
   PROCEDURE DO_RC_ACTIVE(PI_START_DATE       IN   DATE,
                          PI_END_DATE         IN   DATE,
                          PI_AMY_QTY          IN   NUMBER,
                          PI_Tab_PKG_RATES    IN   t_PKG_RATES,
                          PI_RC_CTRL_AMT      IN   NUMBER,    --2020/06/30 MODIFY FOR MPBS_Migration
                          PO_RC_AMT          OUT   NUMBER);   --2020/06/30 MODIFY FOR MPBS_Migration

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
      PROCEDURE : GET_MPBL_AMT
      PURPOSE :   �p��MPBL�Ө������`���(�t�ɦ�)��RC�i�����B
      DESCRIPTION : �p��MPBL�Ө������`���(�t�ɦ�)��RC�i�����B
      PARAMETER:
            PI_START_DATE         :�p��}�l��
            PI_END_DATE           :�p��I���
            PI_AMY_QTY            :�p�O�ƶq
            PI_Tab_PKG_RATES      :PBK�h�ҶO�v
            PO_MONTH              :�p���`���(�t�ɦ�)
            PO_AMT                :RC�i���`�B
      RETURN: �L
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
                          PO_AMT             OUT   NUMBER);                    

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
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration DYNAMIC_ATTRIBUTE ��PI_SOURCE='RC':�qNULL��gvDYNAMIC_ATTRIBUTE
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID �B�z
   **************************************************************************/
   PROCEDURE INS_CI(PI_START_DATE               IN   DATE,
                    PI_END_DATE                 IN   DATE,
                    PI_SOURCE                   IN   VARCHAR2,
                    PI_SOURCE_CI_SEQ            IN   NUMBER,
                    PI_SOURCE_OFFER_ID          IN   NUMBER,
                    PI_SERVICE_RECEIVER_TYPE    IN   VARCHAR2,
                    PI_AMOUNT                   IN   NUMBER);

END FY_PG_BL_BILL_CI;
/