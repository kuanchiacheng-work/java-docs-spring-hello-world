UPDATE FY_TB_BL_BILL_ACCT

--procType=B
SET BALANCE = ?
--procType=T
SET BALANCE_TEST =?

WHERE BILL_SEQ = ${billSeq} AND ACCT_GROUP = ${acctGroup} 
AND ((${confirmId} IS NULL) OR (${confirmId} IS NOT NULL AND AT.CONFIRM_ID = ${confirmId}))
AND (('B' = ${procType} AND BILL_STATUS = ${billStatus}) OR ('T' = ${procType} AND BILL_STATUS <> 'CN')) 
AND ACCT_ID = ${acctIds}