CREATE OR REPLACE PACKAGE FY_PG_BL_BILL_CUTDATE IS

   /*
      -- Author  : FOYA
      -- Created : 2018/9/1
      -- Purpose : 產生出帳客戶名單，MV客戶判斷，客戶類型判斷
      -- Version :
      --             1.0    2018/09/01 CREATE
      --             1.1    2018/09/25 modify CHECK ACCOUNT.EFF_DATE需小於BILL_DATE
      --             1.2    2018/09/28 modify CUT_GROUP ADD PROCESS_NO=888, 999 &最後一筆處理
      --             1.3    2018/10/02 modify keep_acct 念費120天
      --             1.4    2018/10/05 modify ACCT_KEY取法
      --             1.5    2018/10/18 modify PERM_PRINTING_CAT ADD詐欺戶&大額客戶判別
      --             1.6    2018/10/25 modify 區分變數SUB_CNT & OUTPUT
      --             2.0    2018/10/30 modify TABLE SCAN INDEX用法_ACCT_KEY
      --             2.0    2018/11/12 modify select FET1_INVOICE(Partition table) add Partition_key
      --             2.1    2019/01/02 MODIFY select FY_TB_CM_SUBSCR.DECODE(STATUS,'C',STATUS_DATE,NULL) END_DATE,
      --             2.2    2019/06/30 MODIFY skip_bill 大額客戶SQL
      --             2.2    2019/06/30 MODIFY FY_TB_CM_SUBSCR cancel status時間判斷
      --             2.2    2019/08/29 MODIFY skip_bill 大額客戶SQL，修正同一cust下多acct會誤判為一般客戶
      --             2.3    2019/12/02 MODIFY mark for NPEP Project
      --             2.3    2019/12/06 MODIFY SR220754_AI Star修正Pre ACCT_ID抓取方式
      --             2.3    2019/12/12 MODIFY SR220754_AI Star增加MV A2A條件
      --             2.4    2019/12/31 MODIFY 新增cursor C2，取出新舊Account&SUB關聯
      --             2.5    2020/06/09 MODIFY SR226548_遠傳(遠欣)企業客服新服務系統建置
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration
      --             4.0    2021/06/15 MODIFY FOR 小額預繳處理
      --             4.1    2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
      --             4.2    2023/02/21 MODIFY FOR Project M修改亞太資料中，非"="的資料會造成FAIL，而"-"號後的資料為亞太SUB，不需處理
      --             5.0    2023/04/19 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CYCLE(15)DueDate需跨至次月
      --             5.1    2023/08/02 MODIFY FOR SR260229_Project-M Fixed line Phase I_修改BILL_OFFER_PARAM抓取範圍，納入END_DATE等於BILL_FROM_DATE
      --             5.2    2023/08/21 MODIFY FOR SR260229_Project-M Fixed line Phase I_修改BILL_OFFER_PARAM抓取範圍，BACKDATE最多6個月
      --             5.3    2023/12/29 MODIFY FOR SR260229_Project-M Fixed line Phase 1.1，後收DFC退款，DFC取得BACKDATE議價資料
   */
   ----------------------------------------------------------------------------------------------------
   --共用變數
   ----------------------------------------------------------------------------------------------------
     gnBILL_SEQ          NUMBER;
     gnCYCLE             FY_TB_BL_CYCLE.CYCLE%TYPE;--出帳週期(05 15 25)
     gvBILL_PERIOD       FY_TB_BL_CYCLE.CURRECT_PERIOD%TYPE;--出帳年月
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
      PURPOSE :   BL CUT_DATE 處理
      DESCRIPTION : BL CUT_DATE 處理
      PARAMETER:
            PI_CYCLE              :出帳週期
            PI_BILL_PERIOD        :出帳年月
            PI_USER               :USER_ID
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/03/18      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE MAIN(PI_CYCLE          IN   NUMBER,
                  PI_BILL_PERIOD    IN   VARCHAR2,
                  PI_USER           IN   VARCHAR2,
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2);

   /*************************************************************************
      PROCEDURE : KEEP_ACCT
      PURPOSE :   KEEP ACCT & ACCOUNT/SUBSCR SYNC 處理
      DESCRIPTION : KEEP ACCT & ACCOUNT/SUBSCR SYNC 處理
      PARAMETER:

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/03/18      FOYA       MODIFY FOR MPBS_Migration
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE KEEP_ACCT;

   /*************************************************************************
      PROCEDURE : MARKET_MOVE
      PURPOSE :   MARKET_MOVE不同CYCLE ACCT_PKG 處理
      DESCRIPTION : MARKET_MOVE不同CYCLE ACCT_PKG 處理
      PARAMETER:

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
   **************************************************************************/
   PROCEDURE MARKET_MOVE;

   /*************************************************************************
      PROCEDURE : CUT_GROUP
      PURPOSE :   CUT BILL_ACCT ACCT_GROUP處理
      DESCRIPTION : CUT BILL_ACCT ACCT_GROUP處理
      PARAMETER:

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE CUT_GROUP;

END FY_PG_BL_BILL_CUTDATE;
/