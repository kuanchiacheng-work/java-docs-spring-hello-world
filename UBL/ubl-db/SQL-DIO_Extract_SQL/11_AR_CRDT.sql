SELECT  
    'CRDT' Dummy_Field6, 
    MAST.ACCT_ID,
	MAST.ACCT_ID,
    TO_CHAR(TRUNC(CC.CREDIT_DATE), 'YYYYMMDD') CREDIT_DATE, 
    RPAD(trim(CC.AMOUNT),23,' ') AMOUNT, 
    RPAD(trim(CC.CHARGE_CODE),15,' ') CHARGE_CODE, 
    RPAD(trim(CC.CHG_REVENUE_CODE),6,' ') CHG_REVENUE_CODE, 
    RPAD(trim(CC.TAX_AMOUNT),20,' ') TAX_AMOUNT, 
    RPAD(trim(CC.CREDIT_REASON),10,' ') CREDIT_REASON, 
    RPAD(trim(CC.CREDIT_ID),12,' ') CREDIT_ID, 
    RPAD(trim(CC.L9_SERVICE_RECEIVER_TYPE),1,' ') L9_SERVICE_RECEIVER_TYPE, 
    RPAD(trim(CC.L9_SERVICE_RECEIVER_ID),12,' ') L9_SERVICE_RECEIVER_ID, 
    RPAD(trim(DECODE(NVL(CC.INVOICE_ID,0),0,CC.TRANSACTION_ID,CC.INVOICE_ID)),12,' ') INVOICE_ID, 
    RPAD(trim(PCC.TAX_RATE),6,' ') TAX_CODE 
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST MAST, 
     FET1_CUSTOMER_CREDIT CC, 
     FET1_CREDIT_REASON CR,
	 FY_TB_PBK_CHARGE_CODE PCC
WHERE 'B' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  AND MAST.BILL_SEQ  = bc.bill_seq
  and mast.cycle     = bc.cycle
  and mast.cycle_month=bc.cycle_month
  and mast.acct_key  = mod(mast.acct_id,100)
  AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
										    and cycle     = mast.cycle
											and cycle_month=mast.cycle_month
											and acct_key  = mast.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = MAST.ACCT_ID)) OR 
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = MAST.ACCT_ID))) 
  AND CC.BILL_SEQ_NO=MAST.BILL_SEQ  
  AND CC.ACCOUNT_ID = MAST.ACCT_ID
  and cc.Partition_Id=mod(mast.acct_id,10)
  --and cc.period_key  =bc.bill_period
  AND CC.CREDIT_REASON IS NOT NULL
  AND CC.CREDIT_REASON NOT IN (SELECT REFUND_REASON_CODE FROM FET1_REFUND_REASON 
                                                        WHERE REVERSAL_INDICATOR = 'Y')   
  AND CR.CREDIT_REASON_CODE = CC.CREDIT_REASON
  AND CC.CHARGE_CODE = PCC.CHARGE_CODE
  AND (CR.CATEGORY_CODE != 'D' OR 
       (CR.CATEGORY_CODE='D' AND CC.CREDIT_REASON IN ('DP-0','DP-8')))
  AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION 
SELECT  
    'CRDT' Dummy_Field6, 
    MAST.ACCT_ID,
	MAST.ACCT_ID,
    TO_CHAR(TRUNC(CC.CREDIT_DATE), 'YYYYMMDD') CREDIT_DATE, 
    RPAD(trim(CC.AMOUNT),23,' ') AMOUNT, 
    RPAD(trim(CC.CHARGE_CODE),15,' ') CHARGE_CODE, 
    RPAD(trim(CC.CHG_REVENUE_CODE),6,' ') CHG_REVENUE_CODE, 
    RPAD(trim(CC.TAX_AMOUNT),20,' ') TAX_AMOUNT, 
    RPAD(trim(CC.CREDIT_REASON),10,' ') CREDIT_REASON, 
    RPAD(trim(CC.CREDIT_ID),12,' ') CREDIT_ID, 
    RPAD(trim(CC.L9_SERVICE_RECEIVER_TYPE),1,' ') L9_SERVICE_RECEIVER_TYPE, 
    RPAD(trim(CC.L9_SERVICE_RECEIVER_ID),12,' ') L9_SERVICE_RECEIVER_ID, 
    RPAD(trim(DECODE(NVL(CC.INVOICE_ID,0),0,CC.TRANSACTION_ID,CC.INVOICE_ID)),12,' ') INVOICE_ID, 
    RPAD(trim(PCC.TAX_RATE),6,' ') TAX_CODE
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST_TEST MAST, 
     FET1_CUSTOMER_CREDIT CC, 
     FET1_CREDIT_REASON CR,
	FY_TB_PBK_CHARGE_CODE PCC	 
WHERE 'T' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  AND MAST.BILL_SEQ  = bc.bill_seq
  and mast.cycle     = bc.cycle
  and mast.cycle_month=bc.cycle_month
  and mast.acct_key  = mod(mast.acct_id,100)
  AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
										    and cycle     = mast.cycle
											and cycle_month=mast.cycle_month
											and acct_key  = mast.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = MAST.ACCT_ID)) OR 
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = MAST.ACCT_ID)))  
  AND CC.BILL_SEQ_NO=MAST.BILL_SEQ  
  AND CC.ACCOUNT_ID = MAST.ACCT_ID
  and cc.Partition_Id=mod(mast.acct_id,10)
  --and cc.period_key  =bc.bill_period
  AND CC.CREDIT_REASON IS NOT NULL
  AND CC.CREDIT_REASON NOT IN (SELECT REFUND_REASON_CODE FROM FET1_REFUND_REASON 
                                                        WHERE REVERSAL_INDICATOR = 'Y')   
  AND CR.CREDIT_REASON_CODE = CC.CREDIT_REASON
  AND CC.CHARGE_CODE = PCC.CHARGE_CODE
  AND (CR.CATEGORY_CODE != 'D' OR 
       (CR.CATEGORY_CODE='D' AND CC.CREDIT_REASON IN ('DP-0','DP-8')))
  AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}