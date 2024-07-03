CREATE OR REPLACE PACKAGE HGBBLAPPO.FY_PG_BL_BILL_UNDO IS

   /*
      -- Author  : FOYA
      -- Created : 2018/09/01
      -- Purpose : UBL還原出帳計算相關資料
      -- Version :
      --             1.0    2018/09/01 CREATE 
      --             1.1    2018/09/19 modify PROCESS_NO<>999 & PROC_TYPE='B' FY_TB_BL_BILL_CI刪除UC
      --             1.2    2018/10/12 modify 非PREPAYMENT不能清除TRNAS_DATE/TRANS_QTY
      --             1.3    2018/10/15 modify bl_bill_ci.bi_seq=null 
      --             1.4    2018/10/23 modify PROCESS_NO=999 & STATUS='CN' BACKUP處理
      --             2.0    2018/11/05 modify TABLE SCAN INDEX用法_ACCT_KEY & PROCESS_NO=999區分TYPE=HOLD/CONF
      --             2.1    2020/02/25 MODIFY 原MV僅舊SUB會清空TRANS_OUT_QTY、TRANS_OUT_DATE，改為新舊SUB都會清空TRANS_OUT_QTY、TRANS_OUT_DATE
      --             2.2    2020/05/14 MODIFY SR215584_NPEP 2.0調整出帳Confirm流程，使Confirm作業可在Undo之後執行
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration 新增新安東京RC總額處理
      --             4.1    2021/06/15 MODIFY FOR 小額預繳處理
   */
   
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL PROCESS_NO UNDO 處理
      DESCRIPTION : BL BILL PROCESS_NO UNDO 處理
      PARAMETER:
            PI_BILL_SEQ           :出帳序號
            PI_PROCESS_NO         :執行序號
            PI_ACCT_GROUP         :客戶類型OR ACCT_LIST.TYPE
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)  
            PI_USER               :執行USER_ID         
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      4.1   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
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