SELECT
MAST.ACCT_ID ACCOUNT_NO,
TO_CHAR(MAST.DUE_DATE, 'YYYYMMDD') DUE_DATE,
MAST.CHRG_AMT TOTAL_INVOICE_AMT,
MAST.BILL_NBR LEGAL_INVOICE_NO,
TO_CHAR(CT.BILL_DATE, 'YYYYMMDD') BILL_DATE,
MAST.BILL_SEQ,
MAST.INVOICE_TYPE PRODUCTION_TYPE,
MAST.BILL_CURRENCY,
MAST.CYCLE,
SUBSTR(MAST.BILL_PERIOD,5,2) CYCLE_MONTH,
SUBSTR(MAST.BILL_PERIOD,1,4) CYCLE_YEAR,
TO_CHAR(CT.BILL_FROM_DATE,  'YYYYMMDD') BILL_FROM_DATE,
TO_CHAR(CT.BILL_END_DATE,   'YYYYMMDD') BILL_END_DATE,
MAST.INVOICE_TYPE L9_DOC_PRODUCE_IND,
'110154' BE,
BA.ACCT_CATEGORY SUB_BE
FROM FY_TB_BL_BILL_CNTRL CT,
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_MAST MAST
WHERE ct.BILL_SEQ   = ${billSeq}
  and ba.bill_seq   = ct.bill_seq
  and ba.cycle      = ct.cycle
  and ba.cycle_month= ct.cycle_month
  and ba.acct_key  = mod(ba.acct_id,100)
  AND ((${processNo}<>999 and acct_group=${acctGroup}) or
       (${processNo}=999 and exists (select 1 from fy_tb_bl_acct_list
                                         where bill_seq   =ba.bill_seq
                                           and cycle      =ba.cycle
                                           and cycle_month=ba.cycle_month
                                           and type       =${acctGroup}
                                           and acct_id    =ba.acct_id)))
  AND BA.bill_status  = 'CN'
  AND MAST.BILL_SEQ   = BA.BILL_SEQ
  AND MAST.CYCLE      = BA.CYCLE
  AND MAST.CYCLE_MONTH= BA.CYCLE_MONTH
  and mast.acct_key   = ba.acct_key
  AND MAST.ACCT_ID    = BA.ACCT_ID
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}


