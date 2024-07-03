SELECT 
    'OPRF' Dummy_Field3, 
    MAST.ACCT_ID,
	MAST.ACCT_ID,
    TO_CHAR(TRUNC(RR.ACTIVITY_DATE), 'YYYYMMDD') ACTIVITY_DATE, 
    RPAD(trim(RR.AMOUNT),23,' ') AMOUNT, 
    RPAD(trim(RR.REFUND_REASON),10,' ') REFUND_REASON 
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST MAST,
     FET1_INVOICE INV, 
     FET1_REFUND_REQUEST RR 
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
  AND INV.BILL_SEQ_NO = MAST.BILL_SEQ
  AND INV.ACCOUNT_ID  = MAST.ACCT_ID
  and inv.Partition_Id =mod(MAST.ACCT_ID,10)
  --and inv.period_key  = bc.bill_period
  AND RR.ACCOUNT_ID   = INV.ACCOUNT_ID 
  AND RR.INVOICE_ID   = INV.INVOICE_ID 
  AND RR.TRANSACTION_ID = INV.TRANSACTION_ID    
  AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION ALL
SELECT 
    'OPRF' Dummy_Field3, 
    MAST.ACCT_ID,
	MAST.ACCT_ID,
    TO_CHAR(TRUNC(RR.ACTIVITY_DATE), 'YYYYMMDD') ACTIVITY_DATE, 
    RPAD(trim(RR.AMOUNT),23,' ') AMOUNT, 
    RPAD(trim(RR.REFUND_REASON),10,' ') REFUND_REASON 
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST_TEST MAST,
     FET1_INVOICE INV, 
     FET1_REFUND_REQUEST RR 
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
  AND INV.BILL_SEQ_NO = MAST.BILL_SEQ
  AND INV.ACCOUNT_ID  = MAST.ACCT_ID
  and inv.Partition_Id =mod(MAST.ACCT_ID,10)
  --and inv.period_key  = bc.bill_period
  AND RR.ACCOUNT_ID   = INV.ACCOUNT_ID 
  AND RR.INVOICE_ID   = INV.INVOICE_ID 
  AND RR.TRANSACTION_ID = INV.TRANSACTION_ID    
  AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}