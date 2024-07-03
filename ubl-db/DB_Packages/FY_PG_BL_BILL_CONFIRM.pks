CREATE OR REPLACE PACKAGE HGBBLAPPO.FY_PG_BL_BILL_CONFIRM IS

   /*
      -- Author  : FOYA
      -- Created : 2018/09/01
      -- Purpose : UBL立帳處理
      -- Version :
      --             1.0    2018/09/01 CREATE 
      --             1.1    2018/09/20 modify 改為PROCESS_NO執行方式
      --             1.2    2018/09/26 modify UPDATE BILL_PROCESS_LOD.END_DATE
      --             1.3    2018/10/02 modify fy_tb_bl_acct_pkg.test_xxxx清為null
      --             1.4    2018/10/05 modify ACCT_KEY取法
      --             1.5    2018/10/12 modify CHANGE CYCLE INSERT FY_TB_CM_SYNC_SEND_PUB
      --             1.6    2018/10/16 modify ACCT_PKG.STATUS 判別(含EFF_DATE=END_DATE)
      --             2.0    2018/10/29 modify TABLE SCAN INDEX用法_ACCT_KEY
      --             2.1    2019/12/12 MODIFY SR220754_僅PKG_TYPE_DTL='RC'可壓FY_TB_BL_ACCT_PKG.CUR_BILLED
      --             2.2    2020/02/25 MODIFY 取消SR220754_僅PKG_TYPE_DTL='RC'可壓FY_TB_BL_ACCT_PKG.CUR_BILLED
      --             2.2    2020/02/25 MODIFY 當期無使用時，回放原值
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration
      --             4.0    2021/10/06 MODIFY FOR 小額預繳處理(修改PROCEDURE MAIN)
      --             4.5    2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project
      --             5.0    2023/04/19 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CYCLE(15,20)
      --             5.1    2023/07/13 MODIFY FOR SR260229_Project-M Fixed line Phase I_增加月繳預收停用不可CLOSE
   */
   ----------------------------------------------------------------------------------------------------
   --共用變數
   ----------------------------------------------------------------------------------------------------
     gvUSER              FY_TB_BL_BILL_CI.CREATE_USER%TYPE;
   ----------------------------------------------------------------------------------------------------
   
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL_CONFIRM 處理
      DESCRIPTION : BL BILL_CONFIRM 處理
      PARAMETER:
            PI_BILL_SEQ           :出帳序號
            PI_PROCESS_NO         :執行序號
            PI_ACCT_GROUP         :客戶類型
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)  
            PI_USER_ID            :執行USER_ID        
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      1.1   2018/09/20      FOYA       MODIFY 改為PROCESS_NO執行方式
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

