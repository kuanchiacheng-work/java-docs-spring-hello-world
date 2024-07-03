CREATE OR REPLACE PACKAGE FY_PG_BL_BILL_CUTDATE IS

   /*
      -- Author  : FOYA
      -- Created : 2018/9/1
      -- Purpose : ���ͥX�b�Ȥ�W��AMV�Ȥ�P�_�A�Ȥ������P�_
      -- Version :
      --             1.0    2018/09/01 CREATE
      --             1.1    2018/09/25 modify CHECK ACCOUNT.EFF_DATE�ݤp��BILL_DATE
      --             1.2    2018/09/28 modify CUT_GROUP ADD PROCESS_NO=888, 999 &�̫�@���B�z
      --             1.3    2018/10/02 modify keep_acct ���O120��
      --             1.4    2018/10/05 modify ACCT_KEY���k
      --             1.5    2018/10/18 modify PERM_PRINTING_CAT ADD�B�ۤ�&�j�B�Ȥ�P�O
      --             1.6    2018/10/25 modify �Ϥ��ܼ�SUB_CNT & OUTPUT
      --             2.0    2018/10/30 modify TABLE SCAN INDEX�Ϊk_ACCT_KEY
      --             2.0    2018/11/12 modify select FET1_INVOICE(Partition table) add Partition_key
      --             2.1    2019/01/02 MODIFY select FY_TB_CM_SUBSCR.DECODE(STATUS,'C',STATUS_DATE,NULL) END_DATE,
      --             2.2    2019/06/30 MODIFY skip_bill �j�B�Ȥ�SQL
      --             2.2    2019/06/30 MODIFY FY_TB_CM_SUBSCR cancel status�ɶ��P�_
      --             2.2    2019/08/29 MODIFY skip_bill �j�B�Ȥ�SQL�A�ץ��P�@cust�U�hacct�|�~�P���@��Ȥ�
      --             2.3    2019/12/02 MODIFY mark for NPEP Project
      --             2.3    2019/12/06 MODIFY SR220754_AI Star�ץ�Pre ACCT_ID����覡
      --             2.3    2019/12/12 MODIFY SR220754_AI Star�W�[MV A2A����
      --             2.4    2019/12/31 MODIFY �s�Wcursor C2�A���X�s��Account&SUB���p
      --             2.5    2020/06/09 MODIFY SR226548_����(���Y)���~�ȪA�s�A�Ȩt�Ϋظm
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration
      --             4.0    2021/06/15 MODIFY FOR �p�B�wú�B�z
      --             4.1    2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID �B�z
      --             4.2    2023/02/21 MODIFY FOR Project M�ק�ȤӸ�Ƥ��A�D"="����Ʒ|�y��FAIL�A��"-"���᪺��Ƭ��Ȥ�SUB�A���ݳB�z
      --             5.0    2023/04/19 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�WCYCLE(15)DueDate�ݸ�ܦ���
      --             5.1    2023/08/02 MODIFY FOR SR260229_Project-M Fixed line Phase I_�ק�BILL_OFFER_PARAM����d��A�ǤJEND_DATE����BILL_FROM_DATE
      --             5.2    2023/08/21 MODIFY FOR SR260229_Project-M Fixed line Phase I_�ק�BILL_OFFER_PARAM����d��ABACKDATE�̦h6�Ӥ�
      --             5.3    2023/12/29 MODIFY FOR SR260229_Project-M Fixed line Phase 1.1�A�᦬DFC�h�ڡADFC���oBACKDATEĳ�����
   */
   ----------------------------------------------------------------------------------------------------
   --�@���ܼ�
   ----------------------------------------------------------------------------------------------------
     gnBILL_SEQ          NUMBER;
     gnCYCLE             FY_TB_BL_CYCLE.CYCLE%TYPE;--�X�b�g��(05 15 25)
     gvBILL_PERIOD       FY_TB_BL_CYCLE.CURRECT_PERIOD%TYPE;--�X�b�~��
     gnCYCLE_MONTH       FY_TB_BL_BILL_CI.CYCLE_MONTH%TYPE;
     gdBILL_FROM_DATE    DATE;
     gdBILL_END_DATE     DATE;
     gdBILL_DATE         DATE;
     gvUSER              FY_TB_BL_BILL_CI.CREATE_USER%TYPE;
     gvSTEP              VARCHAR2(300);
     gvERR_CDE           VARCHAR2(4);
     gvERR_MSG           VARCHAR2(300);
   ----------------------------------------------------------------------------------------------------

   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL CUT_DATE �B�z
      DESCRIPTION : BL CUT_DATE �B�z
      PARAMETER:
            PI_CYCLE              :�X�b�g��
            PI_BILL_PERIOD        :�X�b�~��
            PI_USER               :USER_ID
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/03/18      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE MAIN(PI_CYCLE          IN   NUMBER,
                  PI_BILL_PERIOD    IN   VARCHAR2,
                  PI_USER           IN   VARCHAR2,
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2);

   /*************************************************************************
      PROCEDURE : KEEP_ACCT
      PURPOSE :   KEEP ACCT & ACCOUNT/SUBSCR SYNC �B�z
      DESCRIPTION : KEEP ACCT & ACCOUNT/SUBSCR SYNC �B�z
      PARAMETER:

      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      3.0   2020/03/18      FOYA       MODIFY FOR MPBS_Migration
      4.0   2021/06/15      FOYA       MODIFY FOR �p�B�wú�B�z
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID �B�z
   **************************************************************************/
   PROCEDURE KEEP_ACCT;

   /*************************************************************************
      PROCEDURE : MARKET_MOVE
      PURPOSE :   MARKET_MOVE���PCYCLE ACCT_PKG �B�z
      DESCRIPTION : MARKET_MOVE���PCYCLE ACCT_PKG �B�z
      PARAMETER:

      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      4.0   2021/06/15      FOYA       MODIFY FOR �p�B�wú�B�z
   **************************************************************************/
   PROCEDURE MARKET_MOVE;

   /*************************************************************************
      PROCEDURE : CUT_GROUP
      PURPOSE :   CUT BILL_ACCT ACCT_GROUP�B�z
      DESCRIPTION : CUT BILL_ACCT ACCT_GROUP�B�z
      PARAMETER:

      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
   **************************************************************************/
   PROCEDURE CUT_GROUP;

END FY_PG_BL_BILL_CUTDATE;
/