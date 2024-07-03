SELECT 
'PYMT' Dummy_Field6, 
MAST.ACCT_ID, 
MAST.ACCT_ID,
RPAD(trim(PAY.ORIGINAL_AMOUNT),23,' ') ORIGINAL_AMOUNT, 
RPAD(trim(PAYD.PAYMENT_METHOD),3,' ') PAYMENT_METHOD, 
RPAD(trim(PAYD.PAYMENT_SUB_METHOD),2,' ') PAYMENT_SUB_METHOD, 
RPAD(trim(PAYD.CHECK_NO),15,' ') CHECK_NO, 
RPAD(trim(PAYD.PAYMENT_SOURCE_TYPE),1,' ') PAYMENT_SOURCE_TYPE, 
RPAD(trim(PAYD.PAYMENT_SOURCE_ID),8,' ') PAYMENT_SOURCE_ID, 
RPAD(trim(PAYD.BANK_CODE),6,' ') BANK_CODE, 
TO_CHAR(TRUNC(PAYD.DEPOSIT_DATE), 'YYYYMMDD') DEPOSIT_DATE, 
TO_CHAR(TRUNC(PAY.ACTIVITY_DATE), 'YYYYMMDD') ACTIVITY_DATE, 
RPAD(trim(PAYD.CREDIT_CARD_NUMBER),100,' ') CREDIT_CARD_NUMBER, 
RPAD(trim(PAY.PAYMENT_ID),12,' ') PAYMENT_ID 
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST MAST, 
     FET1_PAYMENT_DETAILS PAYD, 
     FET1_PAYMENT PAY 
WHERE 'B' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  and mast.bill_seq  = bc.bill_seq
  and mast.cycle     = bc.cycle
  and mast.cycle_month= bc.cycle_month
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
  AND PAY.BILL_SEQ_NO = MAST.BILL_SEQ
  and pay.Partition_Id =mod(mast.acct_ID,10)
  and pay.period_key = bc.bill_period
  AND PAY.ACCOUNT_ID = mast.acct_id
  AND PAYD.PAYMENT_ID = PAY.PAYMENT_ID
  and PAYD.Partition_Id= pay.Partition_Id
  and PAYD.period_key  = pay.period_key
  AND NVL(PAYD.PAYMENT_SUB_METHOD,' ') != 'DEP' 
  AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION 
SELECT 
'PYMT' Dummy_Field6, 
MAST.ACCT_ID, 
MAST.ACCT_ID,
RPAD(trim(PAY.ORIGINAL_AMOUNT),23,' ') ORIGINAL_AMOUNT, 
RPAD(trim(PAYD.PAYMENT_METHOD),3,' ') PAYMENT_METHOD, 
RPAD(trim(PAYD.PAYMENT_SUB_METHOD),2,' ') PAYMENT_SUB_METHOD, 
RPAD(trim(PAYD.CHECK_NO),15,' ') CHECK_NO, 
RPAD(trim(PAYD.PAYMENT_SOURCE_TYPE),1,' ') PAYMENT_SOURCE_TYPE, 
RPAD(trim(PAYD.PAYMENT_SOURCE_ID),8,' ') PAYMENT_SOURCE_ID, 
RPAD(trim(PAYD.BANK_CODE),6,' ') BANK_CODE, 
TO_CHAR(TRUNC(PAYD.DEPOSIT_DATE), 'YYYYMMDD') DEPOSIT_DATE, 
TO_CHAR(TRUNC(PAY.ACTIVITY_DATE), 'YYYYMMDD') ACTIVITY_DATE, 
RPAD(trim(PAYD.CREDIT_CARD_NUMBER),100,' ') CREDIT_CARD_NUMBER, 
RPAD(trim(PAY.PAYMENT_ID),12,' ') PAYMENT_ID 
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST_TEST MAST, 
     FET1_PAYMENT_DETAILS PAYD, 
     FET1_PAYMENT PAY 
WHERE 'T' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  and mast.bill_seq  = bc.bill_seq
  and mast.cycle     = bc.cycle
  and mast.cycle_month= bc.cycle_month
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
  AND PAY.BILL_SEQ_NO = MAST.BILL_SEQ
  and pay.Partition_Id =mod(mast.acct_ID,10)
  and pay.period_key = bc.bill_period
  AND PAY.ACCOUNT_ID = mast.acct_id
  AND PAYD.PAYMENT_ID = PAY.PAYMENT_ID
  and PAYD.Partition_Id= pay.Partition_Id
  and PAYD.period_key  = pay.period_key
  AND NVL(PAYD.PAYMENT_SUB_METHOD,' ') != 'DEP' 
  AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}