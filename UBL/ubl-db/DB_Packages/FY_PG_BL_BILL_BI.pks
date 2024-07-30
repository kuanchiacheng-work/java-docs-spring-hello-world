CREATE OR REPLACE PACKAGE FY_PG_BL_BILL_BI IS
   /*
      -- Author  : FOYA
      -- Created : 2018/09/01
      -- Purpose : UBL計算ROUNDING by TAX_TYPE，外幣處理，DYNAMIC_ATTRIBUTE組合
      -- Version :
      --             1.0    2018/09/01 CREATE 
      --             1.1    2018/09/25 modify 0元不處理，幣別不同匯率處理
      --             1.2    2018/09/26 modify CET GET FY_TB_PBK_CHARGE_CODE需區分
      --             1.3    2018/10/02 modify GET_BI. CHARGE_ORG (RA/CC/DE/IN)
      --             1.4    2018/10/08 modify CHARGE_ORG='DE' --> CHARGE_TYPE='DSC' & DYNAMIC_ATTRIBUTE處理, CHARGE_ORG
      --             1.5    2018/10/09 modify DYNAMIC_ATTRIBUTE改放OFFER_INSTANCE_ID
      --             1.6    2018/10/24 modify UC GROUP BY 從CET改為CHARGE_CODE & ADD UC CHRG_DATE處理
      --             2.0    2018/10/29 modify TABLE SCAN INDEX用法_ACCT_KEY
      --             2.0    2018/11/07 modify Remaining=bill_qty未使用前金額
      --             2.1    2019/06/30 MODIFY FY_TB_BL_BILL_BI add UC DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
      --             2.2    2019/11/11 MODIFY SR219716_IOT預繳折扣 ADD DE DYNAMIC_ATTRIBUTE from FY_TB_BL_BILL_CI
      --             2.3    2019/12/31 MODIFY 計算台幣至DYNAMIC_ATTRIBUTE，美金產生不收費的台幣rounding charge
      --             2.3    2019/12/31 MODIFY overwrite SUB TAX_TYPE & LOOKUP_CODE TAX_RATE ACCOUNT (CANCEL)
      --             3.0    2020/06/30 MODIFY FOR MPBS_Migration 新增保單號碼處理
      --             3.1    2021/02/23 MODIFY FOR MPBS_Migration 修正同回壓CI.BI_SEQ準確性
      --             3.2    2021/04/29 MODIFY MODIFY FOR SR237202_AWS在HGB 設定美金零稅率(特殊專案設定) 
      --             4.0    2021/06/15 MODIFY FOR 小額預繳處理
      --             4.1    2021/07/01 MODIFY FOR PN BILL_SUBSCR_ID 處理
      --             4.1    2022/04/08 MODIFY FOR 425帳單4G預繳餘額顯示
      --             4.2    2022/10/14 SR255529_PN折扣對應修改
      --             5.0    2023/04/18 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增CYCLE(15,20)
      --             5.1    2023/04/20 MODIFY FOR SR260229_Project-M Fixed line Phase I，新增電信業者轉換稅率功能
      --             5.2    2024/07/30 MODIFY FOR SR261173_#5385 Home grown CMP project -Phase1，修改折扣group條件
   */
   
   ----------------------------------------------------------------------------------------------------
   --共用變數
   ----------------------------------------------------------------------------------------------------
     gnBILL_SEQ          NUMBER;
     gnPROCESS_NO        NUMBER;
     gvACCT_GROUP        FY_TB_BL_BILL_ACCT.ACCT_GROUP%TYPE;
     gvSTEP              VARCHAR2(300);
     gvERR_CDE           VARCHAR2(4);
     gvERR_MSG           VARCHAR2(300);
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
     gvUSER              FY_TB_BL_BILL_CI.CREATE_USER%TYPE;
     gvROUND_TX1         FY_TB_BL_BILL_CI.CHARGE_CODE%TYPE;
     gnRATE_TX1          NUMBER;
     gvROUND_TX2         FY_TB_BL_BILL_CI.CHARGE_CODE%TYPE;
     gnRATE_TX2          NUMBER;
     gvROUND_TX3         FY_TB_BL_BILL_CI.CHARGE_CODE%TYPE;
     gnRATE_TX3          NUMBER;
     gvBILL_CURRENCY     FY_TB_BL_BILL_ACCT.BILL_CURRENCY%TYPE;
     gnRATE_SCALE        NUMBER; --匯率計算小數位數  
     gvDYNAMIC_ATTRIBUTE FY_TB_BL_BILL_BI.DYNAMIC_ATTRIBUTE%TYPE;
   ----------------------------------------------------------------------------------------------------
   
   /*************************************************************************
      PROCEDURE : MAIN
      PURPOSE :   BL BILL_BI 處理
      DESCRIPTION : BL BILL_BI 處理
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
   **************************************************************************/
   PROCEDURE MAIN(PI_BILL_SEQ       IN   NUMBER,
                  PI_PROCESS_NO     IN   NUMBER,
                  PI_ACCT_GROUP     IN   VARCHAR2,
                  PI_PROC_TYPE      IN   VARCHAR2 DEFAULT 'B',  
                  PI_USER_ID        IN   VARCHAR2, 
                  PO_ERR_CDE       OUT   VARCHAR2,
                  PO_ERR_MSG       OUT   VARCHAR2); 
                  
   /*************************************************************************
      PROCEDURE : GEN_BI
      PURPOSE :   針對CI SUMMARY TO BI (FOR UC/OC)
      DESCRIPTION : 針對CI SUMMARY TO BI (FOR UC/OC)
      PARAMETER:
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      4.1   2021/07/01      FOYA       MODIFY FOR PN BILL_SUBSCR_ID 處理
   **************************************************************************/
   PROCEDURE GEN_BI;
   
   /*************************************************************************
      PROCEDURE : INS_BI
      PURPOSE :   寫計價項目(BI)至 BILL_BI  
      DESCRIPTION : 寫計價項目(BI)至 BILL_BI
      PARAMETER:
            PI_CHARGE_CODE             :帳單項目
            PI_CHARGE_ORG              :RA/CC/DE/IN
            PI_AMOUNT                  :金額
            PI_TAX_AMT                 :稅額(PI_CHARGE_ORG=IN)
            PI_OFFER_INSTANCE_ID       :OFFER_INSTANCE_ID
            PI_OFFER_SEQ               :OFFER_SEQ
            PI_OFFER_ID                :OFFER 編號
            PI_PKG_ID                  :PKG_ID
            PI_SOURCE                  :RC/OC/UC/DE/IN
            PI_CHRG_DATE               :計費日期
            PI_CHRG_FROM_DATE          :計費起始日
            PI_CHRG_END_DATE           :計費截止日
            PI_CHARGE_DESCR            :中文說明(CHARGE_CODE)
            PI_SERVICE_RECEIVER_TYPE   :費用歸屬階層(A/O/S)
            PI_DYNAMIC_ATTRIBUTE       :DYNAMIC_ATTRIBUTE 
            PI_CORRECT_SEQ             :MAX(CORRECT_SEQ)
            PI_CI_SEQ                  :CI_SEQ
            PO_BI_SEQ                  :BI_SEQ            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
      4.0   2021/06/15      FOYA       MODIFY FOR 小額預繳處理
   **************************************************************************/
   PROCEDURE INS_BI(PI_CHARGE_CODE             IN    VARCHAR2,
                    PI_CHARGE_ORG              IN    VARCHAR2,
                    PI_AMOUNT                  IN    NUMBER,
                    PI_TAX_AMT                 IN    NUMBER,
                    PI_OFFER_INSTANCE_ID       IN    NUMBER,
                    PI_OFFER_SEQ               IN    NUMBER,
                    PI_OFFER_ID                IN    NUMBER,
                    PI_PKG_ID                  IN    NUMBER,
                    PI_SOURCE                  IN    VARCHAR2, 
                    PI_CHRG_DATE               IN    DATE,
                    PI_CHRG_FROM_DATE          IN    DATE,
                    PI_CHRG_END_DATE           IN    DATE,
                    PI_CHARGE_DESCR            IN    VARCHAR2,
                    PI_SERVICE_RECEIVER_TYPE   IN    VARCHAR2,
                    PI_DYNAMIC_ATTRIBUTE       IN    VARCHAR2,
                    PI_CORRECT_SEQ             IN    NUMBER,
                    PI_CI_SEQ                  IN    NUMBER,
                    PO_BI_SEQ                 OUT    NUMBER);
   
   /*************************************************************************
      PROCEDURE : DO_ROUND
      PURPOSE :   BL BILL_BI ROUND 處理
      DESCRIPTION : BL BILL_BI ROUND 處理
      PARAMETER:
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE DO_ROUND ;

   /*************************************************************************
      PROCEDURE : DO_ROUND_FIX
      PURPOSE :   BL BILL_BI ROUND 處理帳單金額因TAX_RATE導致的誤差
      DESCRIPTION : 當帳單內容同時有不同TAX_RATE時，summary金額>=0.5&<1時補1元rounding charge，summary金額>=1&<1.5時補-1元rounding charge，避免造成客訴
      PARAMETER:
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2019/12/31      MikeKuan     新建
   **************************************************************************/
   PROCEDURE DO_ROUND_FIX ;
   
      /*************************************************************************
      PROCEDURE : DO_NTD_ROUND
      PURPOSE :   BL BILL_BI ROUND 處理
      DESCRIPTION : 美金換算台幣rounding charge
      PARAMETER:
            
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2019/12/31      MikeKuan       新建
   **************************************************************************/
   PROCEDURE DO_NTD_ROUND ;
   
   /*************************************************************************
      PROCEDURE : GET_CURRENCY
      PURPOSE :   外幣金額換算處理
      DESCRIPTION : 外幣金額換算處理
      PARAMETER:
            PI_BILL_CURRENCY      :換算幣別
            PI_AMOUNT             :金額 
            PO_BILL_AMT           :換算匯率
            PO_BILL_RATE          :換算金額     
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE GET_CURRENCY(PI_BILL_CURRENCY    IN    VARCHAR2,
                          PI_AMOUNT           IN    NUMBER, 
                          PO_BILL_AMT        OUT    NUMBER,
                          PO_BILL_RATE       OUT    NUMBER,
                          PO_ERR_CDE         OUT   VARCHAR2,
                          PO_ERR_MSG         OUT   VARCHAR2);

   /*************************************************************************
      PROCEDURE : GET_NTD_CURRENCY
      PURPOSE :   台幣金額換算處理
      DESCRIPTION : 台幣金額換算處理
      PARAMETER:
            PI_BILL_CURRENCY      :換算幣別
            PI_AMOUNT             :金額 
            PO_BILL_AMT           :換算匯率
            PO_BILL_RATE          :換算金額     
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2019/12/31      MikeKuan       新建
   **************************************************************************/
   PROCEDURE GET_NTD_CURRENCY(PI_BILL_CURRENCY    IN    VARCHAR2,
                              PI_AMOUNT           IN    NUMBER, 
                              NU_TAX_AMT          IN    NUMBER, 
                              PO_BILL_AMT        OUT    NUMBER,
                              PO_BILL_TAX_AMT    OUT    NUMBER,
                              PO_BILL_RATE       OUT    NUMBER,
                              PO_ERR_CDE         OUT   VARCHAR2,
                              PO_ERR_MSG         OUT   VARCHAR2);
                
END;
/