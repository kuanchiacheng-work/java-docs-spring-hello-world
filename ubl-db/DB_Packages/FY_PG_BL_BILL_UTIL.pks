CREATE OR REPLACE PACKAGE HGBBLAPPO.Fy_Pg_Bl_Bill_Util IS
   
   /*
      -- Author  : USER
      -- Created : 2018/9/1
      -- Purpose : 出帳公用程式
      -- Version :
      --             1.0    2018/09/01 CREATE 
      --             1.1    2018/09/20 modify Ins_Process_LOG add status='CN'處理
      --             1.2    2018/10/03 modify format
      --             1.3    2018/10/30 modify CUSDATE INSERT PROCESS_LOG
      --             2.0    2018/11/14 modify ADD RC試算
      --             2.1    2020/06/09 MODIFY SR226548_遠傳(遠欣)企業客服新服務系統建置
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration ADD PROCEDURE:CHECK_MPBL
      --             4.0    2021/06/15 MODIFY FOR 小額預繳處理 MARKET_PKG ADD參數PROC_TYPE,BILL_SEQ
   */
   --記錄OFFER多筆
   TYPE OFFER_Rec IS RECORD(
      OFFER_SEQ        number);

   TYPE OFFER_CUR IS TABLE OF OFFER_Rec INDEX BY BINARY_INTEGER;
   
   ----------------------------------------------------------------------------------------------------
   --共用變數
   ----------------------------------------------------------------------------------------------------
     gnBILL_SEQ          NUMBER;
     gvSTEP              VARCHAR2(300);
     gvERR_CDE           VARCHAR2(4);
     gvERR_MSG           VARCHAR2(300);
     gvCI_STEP           VARCHAR2(5);
     gdBILL_DATE         DATE;--出帳日期
     gdBILL_FROM_DATE    DATE;--出帳記帳起始日
     gdBILL_END_DATE     DATE;--出帳記帳結束日
     gnFROM_DAY          FY_TB_BL_CYCLE.FROM_DAY%TYPE;
     gnCYCLE             FY_TB_BL_CYCLE.CYCLE%TYPE;--出帳週期(05 15 25)
     gnACCT_ID           FY_TB_BL_BILL_ACCT.ACCT_ID%TYPE;--目前出到的帳號
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
     gnOFFER_LEVEL_ID    FY_TB_BL_ACCT_PKG.OFFER_LEVEL_ID%TYPE;
     gvQTY_CONDITION     FY_TB_PBK_PKG_DISCOUNT.QTY_CONDITION%TYPE;
     gvPRICING_TYPE      FY_TB_PBK_PKG_DISCOUNT.PRICING_TYPE%TYPE;
     gvPRORATE_METHOD    FY_TB_PBK_PKG_DISCOUNT.PRORATE_METHOD%TYPE;
     gvPAYMENT_TIMING    FY_TB_PBK_PACKAGE_RC.PAYMENT_TIMING%TYPE;
     gnFREQUENCY         FY_TB_PBK_PACKAGE_RC.FREQUENCY%TYPE;
     gvRECURRING         FY_TB_PBK_PKG_DISCOUNT.RECURRING%TYPE;
     gvCHRG_ID           FY_TB_BL_BILL_CI.CHRG_ID%TYPE; 
     gvCHARGE_CODE       FY_TB_BL_BILL_CI.CHARGE_CODE%TYPE; 
     gvOVERWRITE         FY_TB_BL_BILL_CI.OVERWRITE%TYPE; 
     gvUSER              FY_TB_BL_BILL_CI.CREATE_USER%TYPE;
   
   ----------------------------------------------------------------------------------------------------
   
   /*************************************************************************
      PROCEDURE : Ins_Process_Err
      PURPOSE :   出帳程式Ins_Process_ERR 處理
      DESCRIPTION : 出帳程式Ins_Process_ERR 處理
      PARAMETER:
            PI_BILL_SEQ           :出帳序號
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)  
            Pi_Acct_Id            :ACCT_ID
            Pi_SUBSCR_Id          :SUBSCR_ID
            PI_PROCESS_NO         :執行序號
            PI_ACCT_GROUP         :客戶類型OR ACCT_LIST.TYPE
            PI_PG_NAME            :執行程式代號
            PI_USER_ID            :執行USER_ID    
            PI_ERR_CDE            :執行ERR_CODE
            PI_ERR_MSG            :執行ERR_MSG     
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/ 
   PROCEDURE Ins_Process_Err(Pi_Bill_Seq   IN Fy_Tb_Bl_Bill_Process_Err.Bill_Seq%TYPE,
                             Pi_Proc_Type  IN Fy_Tb_Bl_Bill_Process_Err.Proc_Type%TYPE,
                             Pi_Acct_Id    IN Fy_Tb_Bl_Bill_Process_Err.Acct_Id%TYPE,
                             Pi_Subscr_Id  IN Fy_Tb_Bl_Bill_Process_Err.Subscr_Id%TYPE,
                             Pi_Process_No IN Fy_Tb_Bl_Bill_Process_Err.Process_No%TYPE,
                             Pi_Acct_Group IN Fy_Tb_Bl_Bill_Process_Err.Acct_Group%TYPE,
                             Pi_Pg_Name    IN Fy_Tb_Bl_Bill_Process_Err.Pg_Name%TYPE,
                             Pi_User_Id    IN Fy_Tb_Bl_Bill_Process_Err.Create_User%TYPE,
                             Pi_Err_Cde    IN Fy_Tb_Bl_Bill_Process_Err.Err_Cde%TYPE,
                             Pi_Err_Msg    IN Fy_Tb_Bl_Bill_Process_Err.Err_Msg%TYPE,
                             Po_Err_Cde    OUT VARCHAR2,
                             Po_Err_Msg    OUT VARCHAR2);
   
   /*************************************************************************
      PROCEDURE : Ins_Process_LOG
      PURPOSE :   出帳程式Ins_Process_LOG 處理
      DESCRIPTION : 出帳程式Ins_Process_LOG 處理
      PARAMETER:
            PI_STATUS             :出帳狀態CI/BI/MAST/CN
            PI_BILL_SEQ           :出帳序號
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)  
            PI_PROCESS_NO         :執行序號
            PI_ACCT_GROUP         :客戶類型OR ACCT_LIST.TYPE
            PI_USER_ID            :執行USER_ID         
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/   
   PROCEDURE Ins_Process_LOG(PI_STATUS     IN FY_TB_BL_BILL_PROCESS_LOG.STATUS%TYPE,
                             Pi_Bill_Seq   IN Fy_Tb_Bl_Bill_Process_Err.Bill_Seq%TYPE,
                             Pi_Proc_Type  IN Fy_Tb_Bl_Bill_Process_Err.Proc_Type%TYPE,
                             Pi_Process_No IN Fy_Tb_Bl_Bill_Process_Err.Process_No%TYPE,
                             Pi_Acct_Group IN Fy_Tb_Bl_Bill_Process_Err.Acct_Group%TYPE,
                             Pi_User_Id    IN Fy_Tb_Bl_Bill_Process_Err.Create_User%TYPE,
                             Po_Err_Cde    OUT VARCHAR2,
                             Po_Err_Msg    OUT VARCHAR2); 
   
   /*************************************************************************
      PROCEDURE : MARKET_PKG
      PURPOSE :   MARKET_MOVE不同CYCLE ACCT_PKG 處理
      DESCRIPTION : MARKET_MOVE不同CYCLE ACCT_PKG 處理
      PARAMETER:
            PI_CYCLE              :出帳CYCLE
            PI_ACCT_PKG_SEQ       :ACCT_PKG_SEQ
            PI_TRANS_DATE         :移轉日期  
            PI_PROC_TYPE          :執行型態 預設值 B (B: 正式出帳, T:測試出帳)
            PI_BILL_SEQ           :出帳序號
            PI_USER               :USER_ID    
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理 ADD參數PROC_TYPE,BILL_SEQ
   **************************************************************************/
   PROCEDURE MARKET_PKG(PI_CYCLE            IN   NUMBER,
                        PI_ACCT_PKG_SEQ     IN   NUMBER,
                        PI_TRANS_DATE       IN   DATE,  
                        PI_PROC_TYPE        IN   VARCHAR2 DEFAULT 'B',  --2021/06/15 MODIFY FOR 小額預繳處理
                        PI_BILL_SEQ         IN   NUMBER,      --2021/06/15 MODIFY FOR 小額預繳處理   
                        PI_USER             IN   VARCHAR2,
                        PO_ERR_CDE         OUT   VARCHAR2,
                        PO_ERR_MSG         OUT   VARCHAR2);  
   
   /*************************************************************************
      PROCEDURE : QUERY_ACCT_PKG
      PURPOSE :   ACCT_PKG QUERY 處理
      DESCRIPTION : ACCT_PKG QUERY 處理
      PARAMETER:
            PI_ACCT_ID            :出帳帳戶   
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE QUERY_ACCT_PKG(PI_ACCT_ID            IN   NUMBER,
                            PO_ERR_CDE           OUT   VARCHAR2,
                            PO_ERR_MSG           OUT   VARCHAR2);
                             
   /*************************************************************************
      PROCEDURE : DO_RECUR
      PURPOSE :   計算用戶月租費
      DESCRIPTION : 計算用戶月租費
      PARAMETER:
            PI_ACCT_ID            :ACCT_ID
            PI_BILL_SEQ           :出帳序號
            PI_CYCLE              :出帳週期
            PI_CYCLE_MONTH        :出帳月份  
            PI_BILL_FROM_DATE     :出帳起始日
            PI_BILL_END_DATE      :出帳截止日
            PI_BILL_DATE          :出帳日       
            PI_FROM_DAY           :FROM_DAY  
            PI_END_DATE           :計費截止日
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE DO_RECUR(PI_ACCT_ID        IN   NUMBER,
                      PI_BILL_SEQ       IN   NUMBER,
                      PI_CYCLE          IN   NUMBER,
                      PI_CYCLE_MONTH    IN   NUMBER,
                      PI_BILL_FROM_DATE IN   DATE,
                      PI_BILL_END_DATE  IN   DATE,
                      PI_BILL_DATE      IN   DATE,
                      PI_FROM_DAY       IN   NUMBER,
                      PI_END_DATE       IN   DATE,
                      PO_ERR_CDE       OUT   VARCHAR2,
                      PO_ERR_MSG       OUT   VARCHAR2);  
                      
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
   **************************************************************************/
   PROCEDURE GET_ACTIVE_DAY(PI_TYPE             IN   VARCHAR2,
                            PI_START_DATE       IN   DATE,
                            PI_END_DATE         IN   DATE,
                            PI_AMY_QTY          IN   NUMBER,
                            PI_Tab_PKG_RATES    IN   FY_PG_BL_BILL_CI.t_PKG_RATES,
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
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE DO_RC_ACTIVE(PI_START_DATE       IN   DATE,
                          PI_END_DATE         IN   DATE,
                          PI_AMY_QTY          IN   NUMBER,
                          PI_Tab_PKG_RATES    IN   FY_PG_BL_BILL_CI.t_PKG_RATES);
   
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
   **************************************************************************/
   PROCEDURE INS_CI(PI_START_DATE               IN   DATE,
                    PI_END_DATE                 IN   DATE,
                    PI_SOURCE                   IN   VARCHAR2,
                    PI_SOURCE_CI_SEQ            IN   NUMBER,
                    PI_SOURCE_OFFER_ID          IN   NUMBER,
                    PI_SERVICE_RECEIVER_TYPE    IN   VARCHAR2,
                    PI_AMOUNT                   IN   NUMBER);   
                    
   /*************************************************************************
      PROCEDURE : CHECK_MPBL
      PURPOSE :   CHECK CUST_ID是否為MPBL      
      DESCRIPTION : CHECK CUST_ID是否為MPBL  
      PARAMETER:
            PI_CUST_ID            :CUST_ID
            PO_MPBL               :Y:MPBL/N
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明 
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2020/06/30      FOYA       CREATE FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE CHECK_MPBL(PI_CUST_ID          IN   NUMBER,
                        PO_MPBL            OUT   VARCHAR2,
                        PO_ERR_CDE         OUT   VARCHAR2,
                        PO_ERR_MSG         OUT   VARCHAR2);                                                                                                                             

END Fy_Pg_Bl_Bill_Util;
/
