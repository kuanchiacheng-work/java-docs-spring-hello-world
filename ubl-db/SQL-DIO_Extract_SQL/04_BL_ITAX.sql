SELECT 
'ITAX' Dummy_Field1, 
BI.ACCT_ID, 
BI.TAX_AMT, 
NULL Tax_Relation,
NULL Tax_Item_Seq, 
NULL Tax_Auth, 
BI.TAX_TYPE, 
nvl((select LTRIM(nvl(TO_CHAR(ROUND(num1*100,4),'999,990.9999'),0)) from FY_TB_SYS_LOOKUP_CODE 
      where lookup_type='TAX_TYPE' and lookup_code=BI.TAX_TYPE),0) TAX_RATE, 
BI.TAX_AMT, 
BI.AMOUNT, 
BI.BI_SEQ
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_BI BI
WHERE 'B' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  and ba.bill_seq  = bc.bill_seq
  and ba.cycle     = bc.cycle
  and ba.cycle_month= bc.cycle_month
  and ba.acct_key  = mod(ba.acct_id,100)
  AND BA.BILL_STATUS = 'MA'
  AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR 
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ = BA.BILL_SEQ
                                            AND TYPE = ${acctGroup}
                                            AND ACCT_ID = BA.ACCT_ID)))     
  AND BI.BILL_SEQ = BA.BILL_SEQ
  AND BI.CYCLE    = BA.CYCLE
  AND BI.CYCLE_MONTH = BA.CYCLE_MONTH
  and bi.acct_key   = ba.acct_key
  AND BI.ACCT_ID  = BA.ACCT_ID
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT 
'ITAX' Dummy_Field1, 
BI.ACCT_ID, 
BI.TAX_AMT, 
NULL Tax_Relation,
NULL Tax_Item_Seq, 
NULL Tax_Auth, BI.TAX_TYPE, 
nvl((select LTRIM(nvl(TO_CHAR(ROUND(num1*100,4),'999,990.9999'),0)) from FY_TB_SYS_LOOKUP_CODE 
      where lookup_type='TAX_TYPE' and lookup_code=BI.TAX_TYPE),0) TAX_RATE, 
BI.TAX_AMT, BI.AMOUNT, BI.BI_SEQ
FROM fy_tb_bl_bill_cntrl bc,
     fY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_BI_TEST BI
WHERE 'T' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  and ba.bill_seq  = bc.bill_seq
  and ba.cycle     = bc.cycle
  and ba.cycle_month= bc.cycle_month
  and ba.acct_key  = mod(ba.acct_id,100)
  AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_MAST_TEST
                       WHERE BILL_SEQ=BA.BILL_SEQ
                         AND CYCLE   =BA.CYCLE
                         AND CYCLE_MONTH=BA.CYCLE_MONTH
						 and acct_key   =ba.acct_key
                         AND ACCT_ID =BA.ACCT_ID)
  AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR 
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ = BA.BILL_SEQ
                                            AND TYPE = ${acctGroup}
                                            AND ACCT_ID = BA.ACCT_ID)))     
  AND BI.BILL_SEQ = BA.BILL_SEQ
  AND BI.CYCLE    = BA.CYCLE
  AND BI.CYCLE_MONTH = BA.CYCLE_MONTH
  and bi.acct_key    = ba.acct_key
  AND BI.ACCT_ID  = BA.ACCT_ID
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
