CREATE OR REPLACE PACKAGE FY_PG_BL_BILL_MAST IS
   /*
      -- Author  : USER
      -- Created : 2018/9/1
      -- Purpose : UBL���ͱb��P�b����B�P�_
      -- Version :
      --             1.0    2018/09/01 CREATE
      --             1.1    2018/09/20 modify ADD UPDATE BILL_CNTRL.STATUS='MA'
      --             1.2    2018/10/05 modify ACCT_KEY���k&ú�ڪ��B*-1
      --             1.3    2018/10/22 modify Dt_Credit_Card_Exp_Date ��YYYYMM
      --             1.4    2018/10/26 modify ADD PI_PERM_PRINTING_CAT CHEKC
      --             2.0    2018/11/02 modify TABLE SCAN INDEX�Ϊk & �C���B��H��ú���BCHEKC
      --             2.0    2018/11/12 modify select FET1_customer_credit(Partition table) add Partition_key
      --             2.1    2019/01/02 MODIFY select count(1) from FY_TB_BL_BILL_ACCT.BILL_STATUS NOT IN ('MAST','CN') > ('MA','CN')
      --             2.2    2019/06/30 MODIFY F6_EBU,CBU customer_type�����Ĥ@���b��('N','S') to 'N', add F6_bill_nbr
      --             2.2    2019/06/30 MODIFY F6_EBU,CBU customer_type�ư�('F','M','S','U')
      --             2.2    2019/06/30 MODIFY �ð����A�B��ú���B��0�AINVOICE_TYPE := 'A'
      --             2.3    2019/07/25 MODIFY �ð��P�_A���A�W�h�ק�
      --             2.4    2019/08/08 MODIFY INVOICE_TYPE�P�_����
      --             2.5    2019/12/31 MODIFY �������ͤ����O���x��rounding charge���ǤJinvoice amount
      --             2.5    2019/12/31 MODIFY INVOICE_TYPE �s�W�DIOT���A(F,M)�A�ư��DIOT���AS>N, Z�������ҡA�ק�S�b�污��
      --             2.5    2019/12/31 MODIFY �W�[SKIPBILL�P�_������ϥ�BDE�����B
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration �s�W�p�B�L��Ƥ����ͱb��B�z
      --             3.1    2021/04/01 MODIFY SR228032_NPEP 2.1 - Skip_Bill�ק�B�j���H
      --             3.2    2021/04/01 MODIFY SR234553_����0���B�C���B�Ĥ@������H��H
      --             4.1    2021/06/15 MODIFY FOR �p�B�wú�B�z
      --             4.2    2021/10/20 MODIFY SR239378 SDWAN_NPEP solution�ظm
      --             4.3    2022/02/08 MODIFY SR246834 SDWAN_NPEP solution�ظm_�ק�NU_LOW_AMT�P�_����
      --             4.4    2023/03/13 MODIFY FOR SR257682_SKIP BILL Rule�վ�--�����ձb�P�_
      --             5.0    2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�WCUST_TYPE='P'
   */

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
                  Po_Err_Msg    OUT VARCHAR2);

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
            PI_CUSTOMER_TYPE      :CUST���� 20190630
            PI_LAST_AMT           :�W����ú 20190725
            PI_PAID_AMT           :�W��ú�ڪ��B 20190725
            PI_ACT_AMT            :�h�ڻP�����h�ڪ��B 20190725
            PI_CHRG_AMT           :�������B
            PI_TOT_AMT            :��ú���B
            PI_LOW_AMT            :�̧C���B
            PI_TAX_ID             :�����귽�Τ@�s��
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
                          PI_CUSTOMER_TYPE        IN     FY_TB_CM_CUSTOMER.CUST_TYPE%TYPE,
                          PI_LAST_AMT             IN     NUMBER, --20190725
                          PI_PAID_AMT             IN     NUMBER, --20190725
                          PI_ACT_AMT              IN     NUMBER, --20190725
                          PI_CHRG_AMT             IN     NUMBER,
                          PI_TOT_AMT              IN     NUMBER,
                          PI_LOW_AMT              IN     NUMBER,
                          PI_TAX_ID               IN     NUMBER, --20191231
                          PI_BILL_CURRENCY        IN     FY_TB_BL_BILL_ACCT.BILL_CURRENCY%TYPE,
                          PO_INVOICE_TYPE        OUT     FY_TB_BL_BILL_MAST.INVOICE_TYPE%TYPE,
                          PO_INVOICE_DTL         OUT     FY_TB_BL_BILL_MAST.INVOICE_TYPE_DTL%TYPE,
                          PO_ERR_CDE             OUT     VARCHAR2,
                          PO_ERR_MSG             OUT     VARCHAR2) ;

END FY_PG_BL_BILL_MAST;
/