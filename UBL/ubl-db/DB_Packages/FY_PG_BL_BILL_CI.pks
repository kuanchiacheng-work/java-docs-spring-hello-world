CREATE OR REPLACE PACKAGE HGBBLAPPO.FY_PG_BL_BILL_CI IS
   /*
      -- Author  : FOYA
      -- Created : 2018/09/01
      -- Purpose : UBL計算收費與折扣，MV折扣剩餘金額移轉
      -- Version :
      --             1.0    2018/09/01 CREATE
      --             1.1    2018/09/18 modify get_month_計算月數trunc(傳入日期)
      --             1.2    2018/09/19 modify INSERT BILL_CI TRUNC(日期) & ROUND(AMOUNT,2) & ADD FY_TB_PBK_CRITERION_GROUP.REVENUE_CODE IS NULL
      --             1.3    2018/09/21 modify GET_CONTRIBUTE使用量轉換(Byte),ROUND處理, QUOTA OVERWITE
      --             1.4    2018/09/28 modify add process_no=999 MV check
      --             1.5    2018/10/03 modify fy_tb_bl_bill_offer_param.param_name取法
      --             1.6    2018/10/05 modify CHARGE_ORG='DE' --> CHARGE_TYPE='DSC' & ACCT_KEY取法
      --             1.7    2018/10/08 modify DO_DISCOUNT ORDER BY OFFER_SEQ
      --             1.8    2018/10/12 modify MARKET MOVE 非PREPAYMNET 處理
      --             1.9    2018/10/15 modify FY_TB_PBK_CRITERION_GROUP 判別
      --             1.10   2018/10/24 modify UC ADD CHRG_DATE處理
      --             1.11   2018/10/30 modify TABLE SCAN INDEX用法_ACCT_KEY
      --             1.12   2018/11/28 modify Pkg_rates_Rec變數長度
      --             2.0    2018/12/03 modify FY_TB_RAT_SUMMARY/FY_TB_BL_BILL_CI.CDR_QTY(單位為B),須作單位轉換及ADD PBK.QTY_E CHECK
      --             2.1    2019/06/30 MODIFY FY_TB_BL_BILL_CI add UC DYNAMIC_ATTRIBUTE
      --             2.2    2019/11/05 MODIFY SR219716_IOT預繳折扣，END_RSN為CREQ且END_DATE小於BILL_DATE時折扣不給
      --             2.3    2019/12/12 MODIFY SR220754_AI_Star_FY_TB_BL_ACCT_PKG增加抓取MV折扣的UNION
      --             2.4    2019/12/31 MODIFY 預收計算起訖時間、預收suspend天數計算
      --             2.5    2020/02/14 MODIFY MV取得有出過帳且本期未使用者的BDE剩餘金額
      --             2.5    2020/02/14 MODIFY MV取消非最後一筆SUB的剩餘金額
      --             2.5    2020/02/14 MODIFY MV新增非最後一筆SUB的剩餘金額=0
      --             2.5    2020/02/25 MODIFY 排除計費天數僅一天的資料
      --             2.6    2020/06/09 MODIFY SR226548_遠傳(遠欣)企業客服新服務系統建置
      --             2.7    2020/06/12 MODIFY SR215584_NPEP專案，預收退費修改
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration 新增新安東京RC總額處理
      --             3.1    2021/02/17 MODIFY SR228032 - NPEP 專案 Phase 2.1
      --             4.0    2021/06/15 MODIFY FOR 小額預繳處理 
      --             4.1    2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理    
      --             4.2    2021/10/06 MODIFY FOR 小額預繳處理(修改PROCEDURE DO_DISCOUNT)
      --             4.3    2021/10/20 MODIFY SR239378 SDWAN_NPEP solution建置
      --             4.4    2022/04/07 MODIFY FOR 修正MV但BDE無移轉造成金額變為0問題
      --             4.5    2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project
      --             4.6    2023/03/06 MODIFY FOR HGBN預收，收費頻率與起迄時間比對，控制PO_MONTH，避免超收短收現象發生
      --             4.7    2023/04/06 MODIFY FOR SR250171_ESDP_Migration_Project_Migration_重開月底最後一天落下月出帳與新增/修改此段DBMS
      --             5.0    2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CYCLE(15,20)
      --             5.1    2023/04/20 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增月繳預收功能
      --             5.2    2023/04/28 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增月繳預收停用退費
      --             5.3    2023/05/03 MODIFY FOR SR260229_Project-M Fixed line Phase I，席次異動超過出帳日影響
      --             5.4    2023/07/25 MODIFY FOR SR260229_Project-M Fixed line Phase I，SUSPEND重複退費問題修正
      --             5.5    2023/07/25 MODIFY FOR SR250171_ESDP_Migration_Project_Migration_月繳前收次期帳單不受已出帳至BILL_END_DATE限制
      --             5.6    2023/10/16 MODIFY FOR SR263630_LSP產品制式化需求開發，新增三年繳預收
      --             5.7    2023/10/16 MODIFY FOR SR260229_Project-M Fixed line Phase 1.1，後收DFC退款
      --             5.8    2023/12/28 MODIFY FOR SR260229_Project-M Fixed line Phase 1.1，後收DFC退款，DFC忽略當天安裝當天移除
      --             5.9    2024/04/16 MODIFY FOR SR266082_ICT專案，折扣不折抵負項金額
      --             6.0    2024/06/27 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1，修正ACCT_PKG需參考出帳SUB名單
      --             6.1    2024/11/21 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1，增加IoT每個pkg都重新抓取初始值
   */
   --記錄PKG多皆費率
   TYPE Pkg_rates_Rec IS RECORD(
      ITEM_NO        number,  --1-5皆
      QTY_S          number,
      QTY_E          number,
      RATES          number);

   TYPE t_Pkg_rates IS TABLE OF Pkg_rates_Rec INDEX BY BINARY_INTEGER;

   ----------------------------------------------------------------------------------------------------
   --共用變數
   ----------------------------------------------------------------------------------------------------
     gnBILL_SEQ          NUMBER;
     gnPROCESS_NO        NUMBER;
     gvACCT_GROUP        FY_TB_BL_BILL_ACCT.ACCT_GROUP%TYPE;
     gvSTEP              VARCHAR2(300);
     gvERR_CDE           VARCHAR2(4);
     gvERR_MSG           VARCHAR2(300);
     gvCI_STEP           VARCHAR2(5);
     gvPROC_TYPE         VARCHAR2(1);--'T'表示是測試 'B'表示是正式
     gdBILL_DATE         DATE;--出帳日期
     gdBILL_FROM_DATE    DATE;--出帳記帳起始日
     gdBILL_END_DATE     DATE;--出帳記帳結束日
     gnFROM_DAY          FY_TB_BL_CYCLE.FROM_DAY%TYPE;
     gnCYCLE             FY_TB_BL_CYCLE.CYCLE%TYPE;--出帳週期(05 15 25)
     gvBILL_PERIOD       FY_TB_BL_CYCLE.CURRECT_PERIOD%TYPE;--出帳年月
     gnACCT_ID           FY_TB_BL_BILL_ACCT.ACCT_ID%TYPE;--目前出到的帳號
     gnACCT_OU_ID        FY_TB_BL_BILL_CI.OU_ID%TYPE;
     gnCUST_ID           FY_TB_BL_BILL_ACCT.CUST_ID%TYPE;--目前出到的証號
     gnSUBSCR_ID         FY_TB_BL_BILL_CI.SUBSCR_ID%TYPE;--目前出到的用戶
     gnOU_ID             FY_TB_BL_BILL_CI.OU_ID%TYPE;
     gnCYCLE_MONTH       FY_TB_BL_BILL_CI.CYCLE_MONTH%TYPE;
     gnOFFER_SEQ         FY_TB_BL_BILL_CI.OFFER_SEQ%TYPE;
     gnOFFER_ID          FY_TB_BL_BILL_CI.OFFER_ID%TYPE;
     gnOFFER_INSTANCE_ID FY_TB_BL_BILL_CI.OFFER_INSTANCE_ID%TYPE;
     gnPKG_ID            FY_TB_BL_ACCT_PKG.PKG_ID%TYPE;
     gvOFFER_LEVEL       FY_TB_BL_ACCT_PKG.OFFER_LEVEL%TYPE;
     gvOFFER_NAME        FY_TB_BL_ACCT_PKG.OFFER_NAME%TYPE;
     gnACCT_PKG_SEQ      FY_TB_BL_ACCT_PKG.ACCT_PKG_SEQ%TYPE;
     gnEND_DATE          FY_TB_BL_ACCT_PKG.END_DATE%TYPE; --2020/06/30 MODIFY FOR MPBS_Migration 折扣未來到期日
     gnFUTURE_EXP_DATE   FY_TB_BL_ACCT_PKG.FUTURE_EXP_DATE%TYPE; --2020/06/30 MODIFY FOR MPBS_Migration 折扣未來到期日
     gnPKG_TYPE_DTL      FY_TB_BL_ACCT_PKG.PKG_TYPE_DTL%TYPE; --20191231
     gnOFFER_LEVEL_ID    FY_TB_BL_ACCT_PKG.OFFER_LEVEL_ID%TYPE;
     gvBILL_CURRENCY     FY_TB_BL_BILL_ACCT.BILL_CURRENCY%TYPE;
     gvQTY_CONDITION     FY_TB_PBK_PKG_DISCOUNT.QTY_CONDITION%TYPE;
     gvDIS_UOM_METHOD    FY_TB_PBK_PKG_DISCOUNT.DIS_UOM_METHOD%TYPE;
     gnQUOTA             FY_TB_PBK_PKG_DISCOUNT.QUOTA%TYPE; --2022/07/05 MODIFY FOR SR250171_ESDP_Migration_Project 提供HBO折扣數量
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
     gbHAS_BILL          BOOLEAN;--是否有產生費用
     gvTMNEWA            VARCHAR2(1); --'N':非新安東京/'Y':新安東京--2020/06/30 MODIFY FOR MPBS_Migration 是否有新安東京
     gnPRT_ID            NUMBER;      --2020/06/30 MODIFY FOR MPBS_Migration 新安東京PRT_ID參數
     gvPRT_VALUE         FY_TB_SYS_LOOKUP_CODE.CH1%TYPE;  --2020/06/30 MODIFY FOR MPBS_Migration 新安東京PRT_VALUE參數
     gvPARAM_NAME        FY_TB_SYS_LOOKUP_CODE.CH1%TYPE;  --2020/06/30 MODIFY FOR MPBS_Migration 新安東京PARAM_NAME參數
     gnROUNDING          NUMBER;      --2020/06/30 MODIFY FOR MPBS_Migration 新安東京ROUNDING位數
     gvTXN_ID            FY_TB_BL_BILL_CI.TXN_ID%TYPE;    --2020/06/30 MODIFY FOR MPBS_Migration 保單號碼
     gdLAST_DATE         DATE  ;      --2020/06/30 MODIFY FOR MPBS_Migration 最後ACTIVE EFF_DATE
     gvDYNAMIC_ATTRIBUTE FY_TB_BL_BILL_CI.DYNAMIC_ATTRIBUTE%TYPE;  --2020/06/30 MODIFY FOR MPBS_Migration 
     gnBILL_SUBSCR_ID    NUMBER;   --2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
     gvPREPAYMENT        FY_TB_BL_ACCT_PKG.PREPAYMENT%TYPE;  --2021/06/15 MODIFY FOR 小額預繳處理
     gvPN_FLAG           VARCHAR2(1);   --'N':非PN/'Y':PN--2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
     gvSDWAN             VARCHAR2(1); --'N':非SDWAN/'Y':SDWAN--2021/10/20 MODIFY SR239378 SDWAN_NPEP solution建置 是否有SDWAN
     gvDFC               VARCHAR2(1); --'N':非DEACT_FOR_CHANGE/'Y':DEACT_FOR_CHANGE--2022/06/27 MODIFY FOR SR250171_ESDP_Migration_Project 是否有DEACT_FOR_CHANGE

   ----------------------------------------------------------------------------------------------------
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL_CI 處理
      DESCRIPTION : BL BILL_CI 處理
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
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration GET新安東京共用參數
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理 Fy_Pg_Bl_Bill_Util.MARKET_PKG ADD參數PROC_TYPE,BILL_SEQ
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
            PI_UC_FLAG            :UC註記(Y:SYNC RAT)

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 從FY_TB_RAT_SUMMARY →FY_TB_RAT_SUMMARY_BILL, 
                                                                 ADD ITEM FY_TB_BL_BILL_CI.TXN_ID
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE GET_UC(PI_UC_FLAG      IN   VARCHAR2);

   /*************************************************************************
      PROCEDURE : DO_RECUR
      PURPOSE :   計算用戶月租費
      DESCRIPTION : 計算用戶月租費
      PARAMETER:


      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 新安東京總額管控處理
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE DO_RECUR;

   /*************************************************************************
      PROCEDURE : DO_DISCOUNT
      PURPOSE :   計算用戶折扣資料
      DESCRIPTION : 計算用戶折扣資料
      PARAMETER:
            PI_PROC_ID             :執行序號(1:ACCT_GROUP='MV'_只執行PRE_SUBSCR IS NULL/2:只執行MV)
            PI_SUBSCR_ID           :執行序號=2:執行該SUBSCR_ID
            PI_PRE_CYCLE           :PRE_ACCT_ID CYCLE

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 增加新安東京判別
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE DO_DISCOUNT(PI_PROC_ID       IN   NUMBER,
                         PI_SUBSCR_ID     IN   NUMBER,
                         PI_PRE_CYCLE     IN   NUMBER);

   /*************************************************************************
      PROCEDURE : GET_CONTRIBUTE
      PURPOSE :   針對PBK定義之CONTRIBUTE，判斷是否符合資格
      DESCRIPTION : 針對PBK定義之CONTRIBUTE，判斷是否符合資格
      PARAMETER:
            PI_CONTRIBUTE_IN        :資格條件群組代碼_IN
            PI_CONTRIBUTE_EX        :資格條件群組代碼_EX
            PI_Tab_PKG_RATES        :PBK多皆費率
            PI_EFF_DATE             :折扣OFFER生效日
            PO_CONTRIBUTE_CNT       :資格條件數量
            PO_CRI_ORDER            :資格條件組別

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 增加參數&新安東京RC OFFER生效日必須小於折扣生效日
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE GET_CONTRIBUTE(PI_CONTRIBUTE_IN      IN   NUMBER,
                            PI_CONTRIBUTE_EX      IN   NUMBER,
                            PI_Tab_PKG_RATES      IN   t_PKG_RATES,
                            PI_EFF_DATE           IN   DATE,
                            PO_CONTRIBUTE_CNT    OUT   NUMBER,
                            PO_CRI_ORDER         OUT   NUMBER) ;

   /*************************************************************************
      PROCEDURE : DO_ELIGIBLE
      PURPOSE :   針對PBK定義之ELIGIBLE，計算DISCOUNT金額
      DESCRIPTION : 針對PBK定義之ELIGIBLE，計算DISCOUNT金額
      PARAMETER:
            PI_ELIGIBLE_IN        :資格條件群組代碼_IN
            PI_ELIGIBLE_EX        :資格條件群組代碼_EX
            PI_CONTRIBUTE_CNT     :資格條件數量
            PI_CRI_ORDER          :資格條件組別
            PI_FROM_DATE          :計算起始日
            PI_END_DATE           :計算截止日
            PI_Tab_PKG_RATES      :PBK多皆費率
            PI_MARKET             :MARKET MOVE FLAG(Y:MARKET MOVE/N)
            PI_EFF_DATE           :折扣OFFER生效日
            PO_PKG_DISC           :折扣金額
            PO_PKG_QTY            :可使用量
            PO_PKG_USE            :使用量

      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 增加參數&新安東京RC OFFER生效日必須小於折扣生效日
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
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
            PI_AMY_QTY            :計費數量
            PI_Tab_PKG_RATES      :PBK多皆費率
            PO_ACTIVE_DAY         :計算期間SUSPEND天數
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration DO_RC_ACTIVE新增兩個參數PI_RC_CTRL_AMT,PO_RC_AMT
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
            PI_START_DATE         :計算開始日
            PI_END_DATE           :計算截止日
            PI_AMY_QTY            :計費數量
            PI_Tab_PKG_RATES      :PBK多皆費率
            PO_ACTIVE_DAY         :計算期間ACTIVE天數(扣除停話天數)
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration ADD新安東京GET RC應收總額控制
   **************************************************************************/
   PROCEDURE GET_ACTIVE_DAY(PI_TYPE             IN   VARCHAR2,
                            PI_START_DATE       IN   DATE,
                            PI_END_DATE         IN   DATE,
                            PI_AMY_QTY          IN   NUMBER,
                            PI_Tab_PKG_RATES    IN   t_PKG_RATES,
                            PO_ACTIVE_DAY      OUT   NUMBER);  

   /*************************************************************************
      PROCEDURE : DO_RC_ACTIVE
      PURPOSE :   DO SUBSCR_ID ACTIVE DAY RC處理
      DESCRIPTION : DO SUBSCR_ID ACTIVE DAY RC處理
      PARAMETER:
            PI_START_DATE         :計算開始日
            PI_END_DATE           :計算截止日
            PI_AMY_QTY            :計費數量
            PI_Tab_PKG_RATES      :PBK多皆費率
            PI_RC_CTRL_AMT        :新安東京應收RC總額
            PO_RC_AMT             :應收RC金額
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration 新增兩個參數PI_RC_CTRL_AMT,PO_RC_AMT
   **************************************************************************/
   PROCEDURE DO_RC_ACTIVE(PI_START_DATE       IN   DATE,
                          PI_END_DATE         IN   DATE,
                          PI_AMY_QTY          IN   NUMBER,
                          PI_Tab_PKG_RATES    IN   t_PKG_RATES,
                          PI_RC_CTRL_AMT      IN   NUMBER,    --2020/06/30 MODIFY FOR MPBS_Migration
                          PO_RC_AMT          OUT   NUMBER);   --2020/06/30 MODIFY FOR MPBS_Migration

   /*************************************************************************
      PROCEDURE : GET_MONTH
      PURPOSE :   計算該起迄日為月數(小數4位)
      DESCRIPTION : 計算該起迄日為月數(小數4位)
      PARAMETER:
            PI_START_DATE         :計算開始日
            PI_END_DATE           :計算截止日
            PO_ACTIVE_DAY         :計算期間ACTIVE天數(扣除停話天數)
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE GET_MONTH(PI_START_DATE       IN   DATE,
                       PI_END_DATE         IN   DATE,
                       PO_MONTH           OUT   NUMBER);
                       
   /*************************************************************************
      PROCEDURE : GET_MPBL_AMT
      PURPOSE :   計算MPBL該其應收總月數(含補收)及RC可收金額
      DESCRIPTION : 計算MPBL該其應收總月數(含補收)及RC可收金額
      PARAMETER:
            PI_START_DATE         :計算開始日
            PI_END_DATE           :計算截止日
            PI_AMY_QTY            :計費數量
            PI_Tab_PKG_RATES      :PBK多皆費率
            PO_MONTH              :計算總月數(含補收)
            PO_AMT                :RC可收總額
      RETURN: 無
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
      PURPOSE :   寫計價項目(CI)至 BILL_CI(PKG本身呼叫使用，不被外部呼叫)
      DESCRIPTION : 寫計價項目(CI)至 BILL_CI
      PARAMETER:
            PI_START_DATE              :計算開始日
            PI_END_DATE                :計算截止日
            PI_SOURCE                  :產生時機(UC/OC/RC/DE)
            PI_SOURCE_CI_SEQ           :折扣來源
            PI_SOURCE_OFFER_ID         :來源OFFER 編號
            PI_SERVICE_RECEIVER_TYPE   :費用歸屬階層(S:Subscr/A:ACCT/U:OU)
            PI_AMOUNT                  :金額
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration DYNAMIC_ATTRIBUTE 當PI_SOURCE='RC':從NULL→gvDYNAMIC_ATTRIBUTE
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
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