SELECT
'PYCH' Dummy_Field3,
M.ACCT_ID Payment_Channel_Number,
M.ACCT_ID BA_Number,
M.PAYMENT_CATEGORY,
M.PAYMENT_METHOD,
M.PAYMENT_TYPE,
M.BANK_CODE,
M.BANK_ACCT_NO,
M.BANK_ACCT_TYPE,
TO_CHAR(LAST_DAY(TO_DATE(CREDIT_CARD_EXP_DATE,'YYYYMM')),'YYYYMMDD') CREDIT_CARD_EXP_DATE,
M.HOLDER_NAME HOLDER_ID,
M.CREDIT_CARD_NO,
M.BANK_BRANCH_NO
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST M
WHERE 'B' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  AND M.BILL_SEQ  = bc.bill_seq
  and M.cycle     = bc.cycle
  and M.cycle_month=bc.cycle_month
  and M.acct_key  = mod(M.acct_id,100)
AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = M.BILL_SEQ
										    and cycle     = M.cycle
											and cycle_month=M.cycle_month
											and acct_key  = M.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = M.ACCT_ID)) OR
     (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = M.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = M.ACCT_ID)))
AND M.ACCT_ID=M.ACCT_ID
AND M.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT
'PYCH' Dummy_Field3,
M.ACCT_ID Payment_Channel_Number,
M.ACCT_ID BA_Number,
M.PAYMENT_CATEGORY,
M.PAYMENT_METHOD,
M.PAYMENT_TYPE,
M.BANK_CODE,
M.BANK_ACCT_NO,
M.BANK_ACCT_TYPE,
TO_CHAR(LAST_DAY(TO_DATE(CREDIT_CARD_EXP_DATE,'YYYYMM')),'YYYYMMDD') CREDIT_CARD_EXP_DATE, --
M.HOLDER_NAME HOLDER_ID,
M.CREDIT_CARD_NO,
M.BANK_BRANCH_NO
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST_TEST M
WHERE 'T' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  AND M.BILL_SEQ  = bc.bill_seq
  and M.cycle     = bc.cycle
  and M.cycle_month=bc.cycle_month
  and M.acct_key  = mod(M.acct_id,100)
AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = M.BILL_SEQ
										    and cycle     = M.cycle
											and cycle_month=M.cycle_month
											and acct_key  = M.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = M.ACCT_ID)) OR
     (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = M.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = M.ACCT_ID)))
AND M.ACCT_ID BETWEEN ${acctIds} and ${acctIde}

