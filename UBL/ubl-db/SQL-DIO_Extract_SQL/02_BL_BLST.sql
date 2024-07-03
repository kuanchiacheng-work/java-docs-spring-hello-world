SELECT 
'BLST' Dummy_Field1, 
SUBSTR(MT.BILL_NBR,3,9) Statement_Seq, 
MT.BILL_NBR Document_Seq, 
MT.ACCT_ID, 
MT.ACCT_ID Pay_Channel_Number, 
TO_CHAR(CT.BILL_DATE,'YYYYMMDD') BILL_DATE, 
MT.BILL_NBR, 
TO_CHAR(MT.DUE_DATE,'YYYYMMDD') DUE_DATE, 
MT.LAST_AMT,
MT.TOT_AMT, 
MT.PAYMENT_METHOD, 
MT.PAID_AMT, 
MT.ORG_TAX_AMT, 
SUBSTR(MT.BILL_NBR,3,10) Invoice_Seq, 
MT.CHRG_AMT
FROM FY_TB_BL_BILL_CNTRL CT, 
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_MAST MT
WHERE 'B' = ${procType}
  AND ct.BILL_SEQ   = ${billSeq}
  and ba.bill_seq   = ct.bill_seq
  and ba.cycle      = ct.cycle
  and ba.cycle_month= ct.cycle_month
  and ba.acct_key  = mod(ba.acct_id,100)
  AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR 
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ = BA.BILL_SEQ
                                            AND TYPE = ${acctGroup}
                                            AND ACCT_ID = BA.ACCT_ID)))
  AND MT.BILL_SEQ = BA.BILL_SEQ
  AND MT.CYCLE    = BA.CYCLE
  AND MT.CYCLE_MONTH = BA.CYCLE_MONTH
  and mt.acct_key = ba.acct_key
  AND MT.ACCT_ID  = BA.ACCT_ID 
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}    
UNION
SELECT 
'BLST' Dummy_Field1, 
SUBSTR(MT.BILL_NBR,3,9) Statement_Seq, 
MT.BILL_NBR Document_Seq, 
MT.ACCT_ID, 
MT.ACCT_ID Pay_Channel_Number, 
TO_CHAR(CT.BILL_DATE,'YYYYMMDD') BILL_DATE, 
MT.BILL_NBR, 
TO_CHAR(MT.DUE_DATE,'YYYYMMDD') DUE_DATE,  
MT.LAST_AMT,
MT.TOT_AMT, 
MT.PAYMENT_METHOD, 
MT.PAID_AMT, 
MT.ORG_TAX_AMT, 
SUBSTR(MT.BILL_NBR,3,10) Invoice_Seq, 
MT.CHRG_AMT
FROM FY_TB_BL_BILL_CNTRL CT, 
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_MAST_TEST MT
WHERE 'T' = ${procType}
  AND ct.BILL_SEQ   = ${billSeq}
  and ba.bill_seq   = ct.bill_seq
  and ba.cycle      = ct.cycle
  and ba.cycle_month= ct.cycle_month
  and ba.acct_key  = mod(ba.acct_id,100)
  AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR 
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ = BA.BILL_SEQ
                                            AND TYPE = ${acctGroup}
                                            AND ACCT_ID = BA.ACCT_ID)))
  AND MT.BILL_SEQ = BA.BILL_SEQ
  AND MT.CYCLE    = BA.CYCLE
  AND MT.CYCLE_MONTH = BA.CYCLE_MONTH
  and mt.acct_key = ba.acct_key
  AND MT.ACCT_ID  = BA.ACCT_ID 
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}