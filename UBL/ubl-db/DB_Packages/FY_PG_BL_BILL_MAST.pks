CREATE OR REPLACE PACKAGE FY_PG_BL_BILL_MAST IS
   /*
      -- Author  : USER
      -- Created : 2018/9/1
      -- Purpose : UBL產生帳單與帳單金額判斷
      -- Version :
      --             1.0    2018/09/01 CREATE
      --             1.1    2018/09/20 modify ADD UPDATE BILL_CNTRL.STATUS='MA'
      --             1.2    2018/10/05 modify ACCT_KEY取法&繳款金額*-1
      --             1.3    2018/10/22 modify Dt_Credit_Card_Exp_Date 為YYYYMM
      --             1.4    2018/10/26 modify ADD PI_PERM_PRINTING_CAT CHEKC
      --             2.0    2018/11/02 modify TABLE SCAN INDEX用法 & 低金額改以應繳金額CHEKC
      --             2.0    2018/11/12 modify select FET1_customer_credit(Partition table) add Partition_key
      --             2.1    2019/01/02 MODIFY select count(1) from FY_TB_BL_BILL_ACCT.BILL_STATUS NOT IN ('MAST','CN') > ('MA','CN')
      --             2.2    2019/06/30 MODIFY F6_EBU,CBU customer_type不落第一期帳單('N','S') to 'N', add F6_bill_nbr
      --             2.2    2019/06/30 MODIFY F6_EBU,CBU customer_type排除('F','M','S','U')
      --             2.2    2019/06/30 MODIFY 永停狀態且應繳金額為0，INVOICE_TYPE := 'A'
      --             2.3    2019/07/25 MODIFY 永停判斷A狀態規則修改
      --             2.4    2019/08/08 MODIFY INVOICE_TYPE判斷順序
      --             2.5    2019/12/31 MODIFY 美金產生不收費的台幣rounding charge不納入invoice amount
      --             2.5    2019/12/31 MODIFY INVOICE_TYPE 新增非IOT狀態(F,M)，排除非IOT狀態S>N, Z部分情境，修改S帳單情境
      --             2.5    2019/12/31 MODIFY 增加SKIPBILL判斷當期有使用BDE的金額
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration 新增小額無資料不產生帳單處理
      --             3.1    2021/04/01 MODIFY SR228032_NPEP 2.1 - Skip_Bill修改、強制交寄
      --             3.2    2021/04/01 MODIFY SR234553_首期0元、低金額第一期不交寄交寄
      --             4.1    2021/06/15 MODIFY FOR 小額預繳處理
      --             4.2    2021/10/20 MODIFY SR239378 SDWAN_NPEP solution建置
      --             4.3    2022/02/08 MODIFY SR246834 SDWAN_NPEP solution建置_修改NU_LOW_AMT判斷條件
      --             4.4    2023/03/13 MODIFY FOR SR257682_SKIP BILL Rule調整--移除調帳判斷
      --             5.0    2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CUST_TYPE='P'
   */

   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL_MAST 處理
      DESCRIPTION : BL BILL_MAST 處理
      PARAMETER:
            PI_BILL_SEQ           :出帳序號
            PI_PROCESS_NO         :執行序號
            PI_ACCT_GROUP         :客戶類型
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)
            PI_USER               :執行USER_ID
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
      4.1   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
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
      PURPOSE :   INVOICE_TYPE / INVOICE_TYPE_DTL 處理
      DESCRIPTION : INVOICE_TYPE/INVOICE_TYPE_DTL 處理
      PARAMETER:
            PI_BILL_SEQ           :出帳序號
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)
            PI_CYCLE              :週期
            PI_BILL_PERIOD        :出帳年月
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_PRE_BILL_NBR       :上期帳單
            PI_PERM_PRINTING_CAT  :客戶類型
            PI_PRODUCTION_TYPE    :帳單類型
            PI_CUSTOMER_TYPE      :CUST類型 20190630
            PI_LAST_AMT           :上期應繳 20190725
            PI_PAID_AMT           :上期繳款金額 20190725
            PI_ACT_AMT            :退款與取消退款金額 20190725
            PI_CHRG_AMT           :本期金額
            PI_TOT_AMT            :應繳金額
            PI_LOW_AMT            :最低金額
            PI_TAX_ID             :內部資源統一編號
            PO_INVOICE_TYPE       :Invoice類型
            PO_INVOICE_DTL        :Invoice類型細項
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
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