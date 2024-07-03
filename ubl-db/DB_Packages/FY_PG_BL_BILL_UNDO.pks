CREATE OR REPLACE PACKAGE HGBBLAPPO.FY_PG_BL_BILL_UNDO IS

   /*
      -- Author  : FOYA
      -- Created : 2018/09/01
      -- Purpose : UBL�٭�X�b�p��������
      -- Version :
      --             1.0    2018/09/01 CREATE 
      --             1.1    2018/09/19 modify PROCESS_NO<>999 & PROC_TYPE='B' FY_TB_BL_BILL_CI�R��UC
      --             1.2    2018/10/12 modify �DPREPAYMENT����M��TRNAS_DATE/TRANS_QTY
      --             1.3    2018/10/15 modify bl_bill_ci.bi_seq=null 
      --             1.4    2018/10/23 modify PROCESS_NO=999 & STATUS='CN' BACKUP�B�z
      --             2.0    2018/11/05 modify TABLE SCAN INDEX�Ϊk_ACCT_KEY & PROCESS_NO=999�Ϥ�TYPE=HOLD/CONF
      --             2.1    2020/02/25 MODIFY ��MV����SUB�|�M��TRANS_OUT_QTY�BTRANS_OUT_DATE�A�אּ�s��SUB���|�M��TRANS_OUT_QTY�BTRANS_OUT_DATE
      --             2.2    2020/05/14 MODIFY SR215584_NPEP 2.0�վ�X�bConfirm�y�{�A��Confirm�@�~�i�bUndo�������
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration �s�W�s�w�F��RC�`�B�B�z
      --             4.1    2021/06/15 MODIFY FOR �p�B�wú�B�z
   */
   
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL PROCESS_NO UNDO �B�z
      DESCRIPTION : BL BILL PROCESS_NO UNDO �B�z
      PARAMETER:
            PI_BILL_SEQ           :�X�b�Ǹ�
            PI_PROCESS_NO         :����Ǹ�
            PI_ACCT_GROUP         :�Ȥ�����OR ACCT_LIST.TYPE
            PI_PROC_TYPE          :���櫬�A �w�]�� B (B: �����X�b, T:���եX�b)  
            PI_USER               :����USER_ID         
            PO_ERR_CDE            :���~�N�X(0000:���\ ��L:����)
            PO_ERR_MSG            :���~�N�X����
      RETURN: �L
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       �s��
      4.1   2021/06/15      FOYA       MODIFY FOR �p�B�wú�B�z
   **************************************************************************/
   PROCEDURE MAIN(PI_BILL_SEQ       IN   NUMBER,
                  PI_PROCESS_NO     IN   NUMBER,
                  PI_ACCT_GROUP     IN   VARCHAR2,
                  PI_PROC_TYPE      IN   VARCHAR2 DEFAULT 'B',  
                  PI_USER           IN   VARCHAR2, 
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2);               
                  
END FY_PG_BL_BILL_UNDO;
/