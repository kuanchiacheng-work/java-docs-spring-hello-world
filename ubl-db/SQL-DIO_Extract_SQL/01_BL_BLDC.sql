SELECT  
'BLDC' DUMMY_FIELD2,
MT.BILL_NBR,
MT.ACCT_ID BA_NUMBER,
BA.CUST_ID,
TO_CHAR(CT.BILL_DATE,'YYYYMMDD') BILL_DATE,
MT.ACCT_ID,
MT.CYCLE,
SUBSTR(MT.BILL_PERIOD,5,2) PERIOD_MM,
SUBSTR(MT.BILL_PERIOD,1,4) PERIOD_YYYY,
'BL' DOCUMENT_TYPE, 
TO_CHAR(CT.BILL_FROM_DATE,'YYYYMMDD') BILL_FROM_DATE,
TO_CHAR(CT.BILL_END_DATE,'YYYYMMDD') BILL_END_DATE,
'P' DOCUMENT_FORMAT,
BA.PRODUCTION_TYPE, 
0 REDIRECT_OPERATOR_ID,
MT.BILL_CURRENCY, 
MT.INVOICE_TYPE  
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
'BLDC' DUMMY_FIELD2,
MT.BILL_NBR,
MT.ACCT_ID BA_NUMBER,
BA.CUST_ID,
TO_CHAR(CT.BILL_DATE,'YYYYMMDD') BILL_DATE,
MT.ACCT_ID,
MT.CYCLE,
SUBSTR(MT.BILL_PERIOD,5,2) PERIOD_MM,
SUBSTR(MT.BILL_PERIOD,1,4) PERIOD_YYYY,
'BL' DOCUMENT_TYPE, 
TO_CHAR(CT.BILL_FROM_DATE,'YYYYMMDD') BILL_FROM_DATE,
TO_CHAR(CT.BILL_END_DATE,'YYYYMMDD') BILL_END_DATE,
'P' DOCUMENT_FORMAT,
BA.PRODUCTION_TYPE, 
0 REDIRECT_OPERATOR_ID,
MT.BILL_CURRENCY, 
MT.INVOICE_TYPE  
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