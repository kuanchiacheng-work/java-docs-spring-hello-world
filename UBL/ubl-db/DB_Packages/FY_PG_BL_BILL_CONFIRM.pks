CREATE OR REPLACE PACKAGE HGBBLAPPO.FY_PG_BL_BILL_CONFIRM IS

   /*
      -- Author  : FOYA
      -- Created : 2018/09/01
      -- Purpose : UBL�߱b�B�z
      -- Version :
      --             1.0    2018/09/01 CREATE 
      --             1.1    2018/09/20 modify �אּPROCESS_NO����覡
      --             1.2    2018/09/26 modify UPDATE BILL_PROCESS_LOD.END_DATE
      --             1.3    2018/10/02 modify fy_tb_bl_acct_pkg.test_xxxx�M��null
      --             1.4    2018/10/05 modify ACCT_KEY���k
      --             1.5    2018/10/12 modify CHANGE CYCLE INSERT FY_TB_CM_SYNC_SEND_PUB
      --             1.6    2018/10/16 modify ACCT_PKG.STATUS �P�O(�tEFF_DATE=END_DATE)
      --             2.0    2018/10/29 modify TABLE SCAN INDEX�Ϊk_ACCT_KEY
      --             2.1    2019/12/12 MODIFY SR220754_��PKG_TYPE_DTL='RC'�i��FY_TB_BL_ACCT_PKG.CUR_BILLED
      --             2.2    2020/02/25 MODIFY ����SR220754_��PKG_TYPE_DTL='RC'�i��FY_TB_BL_ACCT_PKG.CUR_BILLED
      --             2.2    2020/02/25 MODIFY ����L�ϥήɡA�^����
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration
      --             4.0    2021/10/06 MODIFY FOR �p�B�wú�B�z(�ק�PROCEDURE MAIN)
      --             4.5    2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project
      --             5.0    2023/04/19 MODIFY FOR SR260229_Project-M Fixed line Phase I�A�s�WCYCLE(15,20)
      --             5.1    2023/07/13 MODIFY FOR SR260229_Project-M Fixed line Phase I_�W�[��ú�w�����Τ��iCLOSE
   */
   ----------------------------------------------------------------------------------------------------
   --�@���ܼ�
   ----------------------------------------------------------------------------------------------------
     gvUSER              FY_TB_BL_BILL_CI.CREATE_USER%TYPE;
   ----------------------------------------------------------------------------------------------------
   
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL_CONFIRM �B�z
      DESCRIPTION : BL BILL_CONFIRM �B�z
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
                  PO_ERR_MSG       OUT   VARCHAR2); 
                  
END FY_PG_BL_BILL_CONFIRM; 
/

