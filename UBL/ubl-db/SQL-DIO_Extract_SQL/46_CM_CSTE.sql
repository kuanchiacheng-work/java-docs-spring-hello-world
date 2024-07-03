SELECT 'CSTE' DUMMY,
A.Acct_ID BA_NO,
CUST_TYPE customerType,
'' subscriber_tpye,
c.company_code
FROM FY_TB_BL_BILL_CNTRL bc,
     FY_TB_BL_BILL_MAST M, 
     FY_TB_CM_ACCOUNT A, 
	 FY_TB_CM_CUSTOMER B, 
	 FF9_COMPANY_CODE C
WHERE 'B' = ${procType}
and bc.BILL_SEQ    = ${billSeq}
and m.BILL_SEQ     = bc.bill_seq
and m.cycle        = bc.cycle
and m.cycle_month  = bc.cycle_month
and m.acct_key     = mod(a.acct_id,100)
and a.ACCT_ID      = m.ACCT_ID   
AND B.CUST_ID      = A.CUST_ID
AND C.CUSTOMER_TYPE(+) = B.CUST_TYPE
AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                      WHERE BILL_SEQ  = M.BILL_SEQ
									  and cycle       = m.cycle
									  and cycle_month = m.cycle_month
									  and acct_key    = m.acct_key
                                      AND ACCT_GROUP= ${acctGroup}
                                      AND ACCT_ID   = M.ACCT_ID)) OR
    (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                     WHERE BILL_SEQ  = M.BILL_SEQ
                                     AND TYPE      = ${acctGroup}
                                     AND ACCT_ID   = M.ACCT_ID)))
AND M.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT 'CSTE' DUMMY,
A.Acct_ID BA_NO,
CUST_TYPE customerType,
'' subscriber_tpye,
c.company_code
FROM FY_TB_BL_BILL_CNTRL bc,
     FY_TB_BL_BILL_MAST_TEST M, 
	 FY_TB_CM_ACCOUNT A, 
	 FY_TB_CM_CUSTOMER B, 
	 FF9_COMPANY_CODE C
WHERE 'T' = ${procType}
and bc.BILL_SEQ    = ${billSeq}
and m.BILL_SEQ     = bc.bill_seq
and m.cycle        = bc.cycle
and m.cycle_month  = bc.cycle_month
and m.acct_key     = mod(a.acct_id,100)
and a.ACCT_ID      = m.ACCT_ID   
AND B.CUST_ID      = A.CUST_ID
AND C.CUSTOMER_TYPE(+) = B.CUST_TYPE
AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                      WHERE BILL_SEQ  = M.BILL_SEQ
									  and cycle       = m.cycle
									  and cycle_month = m.cycle_month
									  and acct_key    = m.acct_key
                                      AND ACCT_GROUP= ${acctGroup}
                                      AND ACCT_ID   = M.ACCT_ID)) OR
    (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                     WHERE BILL_SEQ  = M.BILL_SEQ
                                     AND TYPE      = ${acctGroup}
                                     AND ACCT_ID   = M.ACCT_ID)))
AND M.ACCT_ID BETWEEN ${acctIds} and ${acctIde}