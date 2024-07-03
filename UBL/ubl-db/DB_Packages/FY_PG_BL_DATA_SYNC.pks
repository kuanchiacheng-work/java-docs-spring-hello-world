CREATE OR REPLACE PACKAGE FY_PG_BL_DATA_SYNC IS

   /*
      -- Author  : USER
      -- Created : 2018/9/1
      -- Purpose : ����BL����DATA SYNC�B�z��
      -- Version :
      --             1.0    2018/09/01 CREATE 
      --             1.1    2018/09/14 modify FY_TB_BL_BILL_CI.CHRG_DATE=OFFER.EFF_DATE
      --             1.2    2018/10/01 modify FY_TB_RAT_CUST_CYCLE trunc(eff_date)
      --             1.3    2018/10/03 modify fy_tb_bl_bill_offer_param.param_name���k
      --             1.4    2018/10/05 modify ACCT_KEY���k
      --             1.5    2018/10/22 modify PI_ATTR_OBJECT & DT_FUTURE_DATE�B�z
      --             2.0    2018/10/30 modify TABLE SCAN INDEX�Ϊk_ACCT_KEY
      --             2.1    2019/11/20 MODIFY SERVICE_CHANGE ���oPRE_ACCT_ID
      --             2.2    2020/06/09 MODIFY SR226548_����(���Y)���~�ȪA�s�A�Ȩt�Ϋظm
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration FY_TB_BL_CYCLE P_KEY�קאּCYCLE+CREATE_USER
      --             3.1    2021/12/03 MODIFY FOR Prepayment����覡��properties�אּrolling
      --             4.3    2021/10/20 MODIFY SR239378 SDWAN_NPEP solution�ظm
      --             4.4    2022/01/13 MODIFY SR246834 SDWAN_NPEP solution�ظm_DYNCMIC_ATTRIBUTE�W�[DEVICE_COUNT
      --             5.0    2023/08/01 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�ץ�CHANGE CYCLE�ɶ��t���D
   */
   ----------------------------------------------------------------------------------------------------
   --�@���ܼ�
   ----------------------------------------------------------------------------------------------------
     gnTRAN_ID           FY_TB_BL_CHANGE_CYCLE.TRAN_ID%TYPE;
     gdTRX_DATE          FY_TB_BL_CHANGE_CYCLE.TRX_DATE%TYPE;
     gvRSN_CODE          FY_TB_BL_ACCT_PKG.END_RSN%TYPE;
     gnCYCLE             FY_TB_BL_CYCLE.CYCLE%TYPE;--�X�b�g��(05 15 25)     
     gnCYCLE_MONTH       FY_TB_BL_BILL_CI.CYCLE_MONTH%TYPE;
     gvBILL_PERIOD       FY_TB_BL_CYCLE.CURRECT_PERIOD%TYPE;
     gnACCT_ID           FY_TB_BL_BILL_ACCT.ACCT_ID%TYPE;
     gnPRE_ACCT_ID       FY_TB_BL_BILL_ACCT.ACCT_ID%TYPE;
     gnCUST_ID           FY_TB_BL_BILL_ACCT.CUST_ID%TYPE;
     gnOU_ID             FY_TB_BL_BILL_ACCT.OU_ID%TYPE;
     gvENTITY_TYPE       VARCHAR2(1);  --A/O/S
     gnENTITY_ID         NUMBER;       --ACCT_ID/OU_ID/SUBSCR_ID
     gvUSER              FY_TB_BL_BILL_CI.CREATE_USER%TYPE   := 'UBL';
     gvSTEP              VARCHAR2(300);
     gvERR_CDE           VARCHAR2(4);
     gvERR_MSG           VARCHAR2(300);
     gvMPBL              VARCHAR2(1);  --Y/N --2020/06/30 MODIFY FOR MPBS_Migration 
   ----------------------------------------------------------------------------------------------------

   /*************************************************************************
      PROCEDURE : NEW_ACCOUNT
      PURPOSE :   CREATE ACCOUNT SYNC
      DESCRIPTION : CREATE ACCOUNT SYNC
      PARAMETER:
            PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 
   **************************************************************************/
   PROCEDURE NEW_ACCOUNT(PI_TRAN_ID           IN   NUMBER,
                         PI_TRX_DATE          IN   DATE,
                         PI_RSN_CODE          IN   VARCHAR2,
                         PI_ACCT_ID           IN   NUMBER,
                         PI_CUST_ID           IN   NUMBER,
                         PI_OU_ID             IN   NUMBER,
                         PI_SUBSCR_ID         IN   NUMBER,
                         PI_NEW_VALUE         IN   VARCHAR2,
                         PI_OLD_VALUE         IN   VARCHAR2,
                         PI_STATUS            IN   VARCHAR2,
                         PI_STATUS_DATE       IN   DATE,
                         PI_EFF_DATE          IN   DATE,
                         PI_END_DATE          IN   DATE,
                         PI_CHARGE_CODE       IN   VARCHAR2,
                         PI_DATE_TYPE         IN   VARCHAR2,
                         PI_WAIVE_INDICATOR   IN   VARCHAR2,
                         PI_PREV_SUB_ID       IN   NUMBER,
                         PI_SUBSCR_TYPE       IN   VARCHAR2,
                         PI_REMARK            IN   VARCHAR2,
                         PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                         PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                         PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                         PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                         PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                         PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                         PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                         PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                         PO_ERR_CDE          OUT   VARCHAR2,
                         PO_ERR_MSG          OUT   VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : OU_SERVICE_CHANGE
      PURPOSE :   CHANGE OU OFFER SYNC
      DESCRIPTION : CHANGE OU OFFER SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 
   **************************************************************************/
   PROCEDURE OU_SERVICE_CHANGE(PI_TRAN_ID           IN   NUMBER,
                               PI_TRX_DATE          IN   DATE,
                               PI_RSN_CODE          IN   VARCHAR2,
                               PI_ACCT_ID           IN   NUMBER,
                               PI_CUST_ID           IN   NUMBER,
                               PI_OU_ID             IN   NUMBER,
                               PI_SUBSCR_ID         IN   NUMBER,
                               PI_NEW_VALUE         IN   VARCHAR2,
                               PI_OLD_VALUE         IN   VARCHAR2,
                               PI_STATUS            IN   VARCHAR2,
                               PI_STATUS_DATE       IN   DATE,
                               PI_EFF_DATE          IN   DATE,
                               PI_END_DATE          IN   DATE,
                               PI_CHARGE_CODE       IN   VARCHAR2,
                               PI_DATE_TYPE         IN   VARCHAR2,
                               PI_WAIVE_INDICATOR   IN   VARCHAR2,
                               PI_PREV_SUB_ID       IN   NUMBER,
                               PI_SUBSCR_TYPE       IN   VARCHAR2,
                               PI_REMARK            IN   VARCHAR2,
                               PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                               PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                               PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                               PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                               PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                               PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                               PO_ERR_CDE          OUT   VARCHAR2,
                               PO_ERR_MSG          OUT   VARCHAR2); 
   
   /*************************************************************************
      PROCEDURE : OU_UPDATE_PARAMETER
      PURPOSE :   UPDATE_OU_OFFER PARAM SYNC
      DESCRIPTION : UPDATE_OU_OFFER PARAM SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 
   **************************************************************************/
   PROCEDURE OU_UPDATE_PARAMETER(PI_TRAN_ID           IN   NUMBER,
                                 PI_TRX_DATE          IN   DATE,
                                 PI_RSN_CODE          IN   VARCHAR2,
                                 PI_ACCT_ID           IN   NUMBER,
                                 PI_CUST_ID           IN   NUMBER,
                                 PI_OU_ID             IN   NUMBER,
                                 PI_SUBSCR_ID         IN   NUMBER,
                                 PI_NEW_VALUE         IN   VARCHAR2,
                                 PI_OLD_VALUE         IN   VARCHAR2,
                                 PI_STATUS            IN   VARCHAR2,
                                 PI_STATUS_DATE       IN   DATE,
                                 PI_EFF_DATE          IN   DATE,
                                 PI_END_DATE          IN   DATE,
                                 PI_CHARGE_CODE       IN   VARCHAR2,
                                 PI_DATE_TYPE         IN   VARCHAR2,
                                 PI_WAIVE_INDICATOR   IN   VARCHAR2,
                                 PI_PREV_SUB_ID       IN   NUMBER,
                                 PI_SUBSCR_TYPE       IN   VARCHAR2,
                                 PI_REMARK            IN   VARCHAR2,
                                 PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                                 PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                                 PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                 PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                 PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                                 PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                                 PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                                 PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                                 PO_ERR_CDE          OUT   VARCHAR2,
                                 PO_ERR_MSG          OUT   VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : NEW_CUSTOMER
      PURPOSE :   CREATE CUSTOMER SYNC
      DESCRIPTION : CREATE CUSTOMER SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE NEW_CUSTOMER(PI_TRAN_ID           IN   NUMBER,
                          PI_TRX_DATE          IN   DATE,
                          PI_RSN_CODE          IN   VARCHAR2,
                          PI_ACCT_ID           IN   NUMBER,
                          PI_CUST_ID           IN   NUMBER,
                          PI_OU_ID             IN   NUMBER,
                          PI_SUBSCR_ID         IN   NUMBER,
                          PI_NEW_VALUE         IN   VARCHAR2,
                          PI_OLD_VALUE         IN   VARCHAR2,
                          PI_STATUS            IN   VARCHAR2,
                          PI_STATUS_DATE       IN   DATE,
                          PI_EFF_DATE          IN   DATE,
                          PI_END_DATE          IN   DATE,
                          PI_CHARGE_CODE       IN   VARCHAR2,
                          PI_DATE_TYPE         IN   VARCHAR2,
                          PI_WAIVE_INDICATOR   IN   VARCHAR2,
                          PI_PREV_SUB_ID       IN   NUMBER,
                          PI_SUBSCR_TYPE       IN   VARCHAR2,
                          PI_REMARK            IN   VARCHAR2,
                          PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                          PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                          PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                          PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                          PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                          PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                          PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                          PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                          PO_ERR_CDE          OUT   VARCHAR2,
                          PO_ERR_MSG          OUT   VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : CHGCYC
      PURPOSE :   CHANGE CYCLE SYNC
      DESCRIPTION : CHANGE CYCLE SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE CHGCYC(PI_TRAN_ID           IN   NUMBER,
                    PI_TRX_DATE          IN   DATE,
                    PI_RSN_CODE          IN   VARCHAR2,
                    PI_ACCT_ID           IN   NUMBER,
                    PI_CUST_ID           IN   NUMBER,
                    PI_OU_ID             IN   NUMBER,
                    PI_SUBSCR_ID         IN   NUMBER,
                    PI_NEW_VALUE         IN   VARCHAR2,
                    PI_OLD_VALUE         IN   VARCHAR2,
                    PI_STATUS            IN   VARCHAR2,
                    PI_STATUS_DATE       IN   DATE,
                    PI_EFF_DATE          IN   DATE,
                    PI_END_DATE          IN   DATE,
                    PI_CHARGE_CODE       IN   VARCHAR2,
                    PI_DATE_TYPE         IN   VARCHAR2,
                    PI_WAIVE_INDICATOR   IN   VARCHAR2,
                    PI_PREV_SUB_ID       IN   NUMBER,
                    PI_SUBSCR_TYPE       IN   VARCHAR2,
                    PI_REMARK            IN   VARCHAR2,
                    PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                    PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                    PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                    PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                    PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                    PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                    PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                    PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                    PO_ERR_CDE          OUT   VARCHAR2,
                    PO_ERR_MSG          OUT   VARCHAR2);
   
   /*************************************************************************
      PROCEDURE NEW_SUB_ACTIVATION
      PURPOSE :   CREATE SUBSCR & SUBSCR MAIN OFFER SYNC
      DESCRIPTION : CREATE SUBSCR & SUBSCR MAIN OFFER SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 
   **************************************************************************/
   PROCEDURE NEW_SUB_ACTIVATION(PI_TRAN_ID           IN   NUMBER,
                                PI_TRX_DATE          IN   DATE,
                                PI_RSN_CODE          IN   VARCHAR2,
                                PI_ACCT_ID           IN   NUMBER,
                                PI_CUST_ID           IN   NUMBER,
                                PI_OU_ID             IN   NUMBER,
                                PI_SUBSCR_ID         IN   NUMBER,
                                PI_NEW_VALUE         IN   VARCHAR2,
                                PI_OLD_VALUE         IN   VARCHAR2,
                                PI_STATUS            IN   VARCHAR2,
                                PI_STATUS_DATE       IN   DATE,
                                PI_EFF_DATE          IN   DATE,
                                PI_END_DATE          IN   DATE,
                                PI_CHARGE_CODE       IN   VARCHAR2,
                                PI_DATE_TYPE         IN   VARCHAR2,
                                PI_WAIVE_INDICATOR   IN   VARCHAR2,
                                PI_PREV_SUB_ID       IN   NUMBER,
                                PI_SUBSCR_TYPE       IN   VARCHAR2,
                                PI_REMARK            IN   VARCHAR2,
                                PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                                PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                                PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                                PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                                PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                                PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                                PO_ERR_CDE          OUT   VARCHAR2,
                                PO_ERR_MSG          OUT   VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : SERVICE_CHANGE
      PURPOSE :   CHANGE SUBSCR OFFER SYNC
      DESCRIPTION : CHANGE SUBSCR OFFER SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE SERVICE_CHANGE(PI_TRAN_ID           IN   NUMBER,
                            PI_TRX_DATE          IN   DATE,
                            PI_RSN_CODE          IN   VARCHAR2,
                            PI_ACCT_ID           IN   NUMBER,
                            PI_CUST_ID           IN   NUMBER,
                            PI_OU_ID             IN   NUMBER,
                            PI_SUBSCR_ID         IN   NUMBER,
                            PI_NEW_VALUE         IN   VARCHAR2,
                            PI_OLD_VALUE         IN   VARCHAR2,
                            PI_STATUS            IN   VARCHAR2,
                            PI_STATUS_DATE       IN   DATE,
                            PI_EFF_DATE          IN   DATE,
                            PI_END_DATE          IN   DATE,
                            PI_CHARGE_CODE       IN   VARCHAR2,
                            PI_DATE_TYPE         IN   VARCHAR2,
                            PI_WAIVE_INDICATOR   IN   VARCHAR2,
                            PI_PREV_SUB_ID       IN   NUMBER,
                            PI_SUBSCR_TYPE       IN   VARCHAR2,
                            PI_REMARK            IN   VARCHAR2,
                            PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                            PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                            PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                            PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                            PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                            PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                            PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                            PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                            PO_ERR_CDE          OUT   VARCHAR2,
                            PO_ERR_MSG          OUT   VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : CHANGE_RESOURCE
      PURPOSE :   CHANGE_RESOURCE SUBSCR�O��SYNC
      DESCRIPTION : CHANGE_RESOURCE SUBSCR�O��SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 
   **************************************************************************/
   PROCEDURE CHANGE_RESOURCE(PI_TRAN_ID           IN   NUMBER,
                             PI_TRX_DATE          IN   DATE,
                             PI_RSN_CODE          IN   VARCHAR2,
                             PI_ACCT_ID           IN   NUMBER,
                             PI_CUST_ID           IN   NUMBER,
                             PI_OU_ID             IN   NUMBER,
                             PI_SUBSCR_ID         IN   NUMBER,
                             PI_NEW_VALUE         IN   VARCHAR2,
                             PI_OLD_VALUE         IN   VARCHAR2,
                             PI_STATUS            IN   VARCHAR2,
                             PI_STATUS_DATE       IN   DATE,
                             PI_EFF_DATE          IN   DATE,
                             PI_END_DATE          IN   DATE,
                             PI_CHARGE_CODE       IN   VARCHAR2,
                             PI_DATE_TYPE         IN   VARCHAR2,
                             PI_WAIVE_INDICATOR   IN   VARCHAR2,
                             PI_PREV_SUB_ID       IN   NUMBER,
                             PI_SUBSCR_TYPE       IN   VARCHAR2,
                             PI_REMARK            IN   VARCHAR2,
                             PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                             PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                             PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                             PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                             PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                             PO_ERR_CDE          OUT   VARCHAR2,
                             PO_ERR_MSG          OUT   VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : MOVE_SUB
      PURPOSE :    CHANGE_SUBSCR OU OFFER SYNC
      DESCRIPTION : CHANGE_SUBSCR OU OFFER SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 
   **************************************************************************/
   PROCEDURE MOVE_SUB(PI_TRAN_ID           IN   NUMBER,
                      PI_TRX_DATE          IN   DATE,
                      PI_RSN_CODE          IN   VARCHAR2,
                      PI_ACCT_ID           IN   NUMBER,
                      PI_CUST_ID           IN   NUMBER,
                      PI_OU_ID             IN   NUMBER,
                      PI_SUBSCR_ID         IN   NUMBER,
                      PI_NEW_VALUE         IN   VARCHAR2,
                      PI_OLD_VALUE         IN   VARCHAR2,
                      PI_STATUS            IN   VARCHAR2,
                      PI_STATUS_DATE       IN   DATE,
                      PI_EFF_DATE          IN   DATE,
                      PI_END_DATE          IN   DATE,
                      PI_CHARGE_CODE       IN   VARCHAR2,
                      PI_DATE_TYPE         IN   VARCHAR2,
                      PI_WAIVE_INDICATOR   IN   VARCHAR2,
                      PI_PREV_SUB_ID       IN   NUMBER,
                      PI_SUBSCR_TYPE       IN   VARCHAR2,
                      PI_REMARK            IN   VARCHAR2,
                      PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                      PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                      PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                      PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                      PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                      PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                      PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                      PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                      PO_ERR_CDE          OUT   VARCHAR2,
                      PO_ERR_MSG          OUT   VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : UPDATE_SUB_DATE
      PURPOSE :   UPDATE SUBSCR STATUS DATE SYNC(SUSPEND/RESTORE/CANCEL)
      DESCRIPTION : UPDATE SUBSCR STATUS DATE SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE UPDATE_SUB_DATE(PI_TRAN_ID           IN   NUMBER,
                             PI_TRX_DATE          IN   DATE,
                             PI_RSN_CODE          IN   VARCHAR2,
                             PI_ACCT_ID           IN   NUMBER,
                             PI_CUST_ID           IN   NUMBER,
                             PI_OU_ID             IN   NUMBER,
                             PI_SUBSCR_ID         IN   NUMBER,
                             PI_NEW_VALUE         IN   VARCHAR2,
                             PI_OLD_VALUE         IN   VARCHAR2,
                             PI_STATUS            IN   VARCHAR2,
                             PI_STATUS_DATE       IN   DATE,
                             PI_EFF_DATE          IN   DATE,
                             PI_END_DATE          IN   DATE,
                             PI_CHARGE_CODE       IN   VARCHAR2,
                             PI_DATE_TYPE         IN   VARCHAR2,
                             PI_WAIVE_INDICATOR   IN   VARCHAR2,
                             PI_PREV_SUB_ID       IN   NUMBER,
                             PI_SUBSCR_TYPE       IN   VARCHAR2,
                             PI_REMARK            IN   VARCHAR2,
                             PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                             PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                             PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                             PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                             PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                             PO_ERR_CDE          OUT   VARCHAR2,
                             PO_ERR_MSG          OUT   VARCHAR2);  
   
   /*************************************************************************
      PROCEDURE : UPDATE_SUB_OFFER_DATE
      PURPOSE :   UPDATE_SUBSCR_OFFER_DATE(EFF_DATE/END_DATE/FUTURE_DATE/ORIG_DATE) SYNC
      DESCRIPTION : UPDATE_SUBSCR_OFFER_DATE(EFF_DATE/END_DATE/FUTURE_DATE/ORIG_DATE) SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE UPDATE_SUB_OFFER_DATE(PI_TRAN_ID           IN   NUMBER,
                                   PI_TRX_DATE          IN   DATE,
                                   PI_RSN_CODE          IN   VARCHAR2,
                                   PI_ACCT_ID           IN   NUMBER,
                                   PI_CUST_ID           IN   NUMBER,
                                   PI_OU_ID             IN   NUMBER,
                                   PI_SUBSCR_ID         IN   NUMBER,
                                   PI_NEW_VALUE         IN   VARCHAR2,
                                   PI_OLD_VALUE         IN   VARCHAR2,
                                   PI_STATUS            IN   VARCHAR2,
                                   PI_STATUS_DATE       IN   DATE,
                                   PI_EFF_DATE          IN   DATE,
                                   PI_END_DATE          IN   DATE,
                                   PI_CHARGE_CODE       IN   VARCHAR2,
                                   PI_DATE_TYPE         IN   VARCHAR2,
                                   PI_WAIVE_INDICATOR   IN   VARCHAR2,
                                   PI_PREV_SUB_ID       IN   NUMBER,
                                   PI_SUBSCR_TYPE       IN   VARCHAR2,
                                   PI_REMARK            IN   VARCHAR2,
                                   PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                                   PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                                   PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                   PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                   PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                                   PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                                   PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                                   PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                                   PO_ERR_CDE          OUT   VARCHAR2,
                                   PO_ERR_MSG          OUT   VARCHAR2); 
   
   /*************************************************************************
      PROCEDURE : SUB_MODI_STATUS
      PURPOSE :   SUBSCR SUSPEND/RESTORE/CANCEL SYNC
      DESCRIPTION : SUBSCR SUSPEND/RESTORE/CANCEL SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE SUB_MODI_STATUS(PI_TRAN_ID           IN   NUMBER,
                             PI_TRX_DATE          IN   DATE,
                             PI_RSN_CODE          IN   VARCHAR2,
                             PI_ACCT_ID           IN   NUMBER,
                             PI_CUST_ID           IN   NUMBER,
                             PI_OU_ID             IN   NUMBER,
                             PI_SUBSCR_ID         IN   NUMBER,
                             PI_NEW_VALUE         IN   VARCHAR2,
                             PI_OLD_VALUE         IN   VARCHAR2,
                             PI_STATUS            IN   VARCHAR2,
                             PI_STATUS_DATE       IN   DATE,
                             PI_EFF_DATE          IN   DATE,
                             PI_END_DATE          IN   DATE,
                             PI_CHARGE_CODE       IN   VARCHAR2,
                             PI_DATE_TYPE         IN   VARCHAR2,
                             PI_WAIVE_INDICATOR   IN   VARCHAR2,
                             PI_PREV_SUB_ID       IN   NUMBER,
                             PI_SUBSCR_TYPE       IN   VARCHAR2,
                             PI_REMARK            IN   VARCHAR2,
                             PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                             PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                             PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                             PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                             PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                             PO_ERR_CDE          OUT   VARCHAR2,
                             PO_ERR_MSG          OUT   VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : UPDATE_PARAMETERS
      PURPOSE :   UPDATE_SUBSCR_OFFER PARAM SYNC
      DESCRIPTION : UPDATE_SUBSCR_OFFER PARAM SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE UPDATE_PARAMETERS(PI_TRAN_ID           IN   NUMBER,
                               PI_TRX_DATE          IN   DATE,
                               PI_RSN_CODE          IN   VARCHAR2,
                               PI_ACCT_ID           IN   NUMBER,
                               PI_CUST_ID           IN   NUMBER,
                               PI_OU_ID             IN   NUMBER,
                               PI_SUBSCR_ID         IN   NUMBER,
                               PI_NEW_VALUE         IN   VARCHAR2,
                               PI_OLD_VALUE         IN   VARCHAR2,
                               PI_STATUS            IN   VARCHAR2,
                               PI_STATUS_DATE       IN   DATE,
                               PI_EFF_DATE          IN   DATE,
                               PI_END_DATE          IN   DATE,
                               PI_CHARGE_CODE       IN   VARCHAR2,
                               PI_DATE_TYPE         IN   VARCHAR2,
                               PI_WAIVE_INDICATOR   IN   VARCHAR2,
                               PI_PREV_SUB_ID       IN   NUMBER,
                               PI_SUBSCR_TYPE       IN   VARCHAR2,
                               PI_REMARK            IN   VARCHAR2,
                               PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                               PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                               PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                               PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                               PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                               PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                               PO_ERR_CDE          OUT   VARCHAR2,
                               PO_ERR_MSG          OUT   VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : UPDATE_SUB_ATTR
      PURPOSE :   UPDATE_SUBSCR_ATTR PARAM SYNC
      DESCRIPTION : UPDATE_SUBSCR_ATTR PARAM SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :���ʤ��
            PI_RSN_CODE           :���ʭ�]
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :�s��
            PI_OLD_VALUE          :���
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR ����CREATE CHARGE�ϥ�)
            PI_DATE_TYPE          :�ק�������(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :���O���B�O�_�K��(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub�ϥ�-�e��
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :�ǤJADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :�ǤJREMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :�ǤJNEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :�ǤJOLD_PARAM_INFO OBJECT 
            PI_NEW_RESOURCE       :�ǤJNEW_RESOURCE_INFO OBJECT 
            PI_OLD_RESOURCE       :�ǤJOLD_RESOURCE_INFO OBJECT 
            PI_NEW_ATTR           :�ǤJNEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :�ǤJOLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE UPDATE_SUB_ATTR(PI_TRAN_ID           IN   NUMBER,
                             PI_TRX_DATE          IN   DATE,
                             PI_RSN_CODE          IN   VARCHAR2,
                             PI_ACCT_ID           IN   NUMBER,
                             PI_CUST_ID           IN   NUMBER,
                             PI_OU_ID             IN   NUMBER,
                             PI_SUBSCR_ID         IN   NUMBER,
                             PI_NEW_VALUE         IN   VARCHAR2,
                             PI_OLD_VALUE         IN   VARCHAR2,
                             PI_STATUS            IN   VARCHAR2,
                             PI_STATUS_DATE       IN   DATE,
                             PI_EFF_DATE          IN   DATE,
                             PI_END_DATE          IN   DATE,
                             PI_CHARGE_CODE       IN   VARCHAR2,
                             PI_DATE_TYPE         IN   VARCHAR2,
                             PI_WAIVE_INDICATOR   IN   VARCHAR2,
                             PI_PREV_SUB_ID       IN   NUMBER,
                             PI_SUBSCR_TYPE       IN   VARCHAR2,
                             PI_REMARK            IN   VARCHAR2,
                             PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,  
                             PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,  
                             PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE, 
                             PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                             PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,  
                             PO_ERR_CDE          OUT   VARCHAR2,
                             PO_ERR_MSG          OUT   VARCHAR2);                                                                                                                                                                                

   /*************************************************************************
      PROCEDURE : CHANGE_OFFER
      PURPOSE :   CHANGE OFFER INFO SYNC
      DESCRIPTION : CHANGE OFFER INFO SYNC
      PARAMETER:
            PI_TYPE               :OLD/NEW/UPDATE
            PI_DATE_TYPE          :EFF/END/FUTURE/ORIG_EFF/NULL:PI_TYPE<>'UPDATE'
            PI_OFFER_OBJECT       :�ǤJOFFER PARAM OBJECT
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE CHANGE_OFFER(PI_TYPE           IN   VARCHAR2, 
                          PI_DATE_TYPE      IN   VARCHAR2,                     
                          PI_OFFER_OBJECT   IN   FY_TT_SYS_SYNC_OFFER_INFO);
   
   /*************************************************************************
      PROCEDURE : CHANGE_PARAM
      PURPOSE :   CHANGE OFFER PARAMETER SYNC
      DESCRIPTION : CHANGE OFFER PARAMETER SYNC
      PARAMETER:
            PI_TYPE               :OLD/NEW/UPDATE
            PI_PARAM_TYPE         :PARAM/ATTR
            PI_PARAM_OBJECT       :�ǤJOFFER PARAM OBJECT
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE CHANGE_PARAM(PI_TYPE           IN   VARCHAR2, 
                          PI_PARAM_TYPE     IN   VARCHAR2,                       
                          PI_PARAM_OBJECT   IN   FY_TT_SYS_SYNC_PARAM_INFO);
   
   /*************************************************************************
      PROCEDURE : CREATE_OFFER_OC
      PURPOSE :   CREATE OFFER OC_ID AMOUNT
      DESCRIPTION : CREATE OFFER OC_ID AMOUNT
      PARAMETER:
            PI_INSTANCE_ID        :OFFER INSTANCE_ID
            PI_OFFER_ID           :OFFER_ID
            PI_OFFER_SEQ          :OFFER_SEQ
            PI_EFF_DATE           :OFFER EFF_DATE
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE CREATE_OFFER_OC(PI_INSTANCE_ID    IN   NUMBER,
                             PI_OFFER_ID       IN   VARCHAR2,
                             PI_OFFER_SEQ      IN   NUMBER,
                             PI_EFF_DATE       IN   DATE) ;
   
   /*************************************************************************
      PROCEDURE : CREATE_CI
      PURPOSE :   CREATE BL_BILL_CI AMOUNT
      DESCRIPTION : CREATE BL_BILL_CI AMOUNT
      PARAMETER:
            PI_INSTANCE_ID        :OFFER INSTANCE_ID
            PI_OFFER_ID           :OFFER_ID
            PI_OFFER_SEQ          :OFFER_SEQ
            PI_EFF_DATE           :OFFER EFF_DATE
            PI_PKG_ID             :PACKAGE.PKG_ID            
            PI_OC_ID              :OC_ID
            PI_CHARGE_CODE        :CHARGE_CODE  
            PI_AMOUNT             :���B
            PI_OVERWRITE          :Y:OVERWRITE
            PI_WAIVE_INDICATOR    :Y:���ʶO�Τ���/N:��            
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE CREATE_CI(PI_INSTANCE_ID      IN   NUMBER,
                       PI_OFFER_ID         IN   VARCHAR2,
                       PI_OFFER_SEQ        IN   NUMBER,
                       PI_EFF_DATE         IN   DATE,
                       PI_PKG_ID           IN   NUMBER,
                       PI_OC_ID            IN   VARCHAR2,
                       PI_CHARGE_CODE      IN   VARCHAR2,
                       PI_AMOUNT           IN   NUMBER,
                       PI_OVERWRITE        IN   VARCHAR2,
                       PI_WAIVE_INDICATOR  IN   VARCHAR2);                    
                       
END FY_PG_BL_DATA_SYNC;
/