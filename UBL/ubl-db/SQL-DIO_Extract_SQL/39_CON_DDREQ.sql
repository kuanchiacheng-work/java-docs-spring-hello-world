SELECT
MAST.ACCT_ID,
MAST.BILL_NBR, --SR222460 MPBS migrate to HGB
MAST.PAYMENT_METHOD,
MAST.TOT_AMT,
TO_CHAR(MAST.DUE_DATE, 'YYYYMMDD') DUE_DATE,
MAST.BANK_BRANCH_NO, --SR222460 MPBS migrate to HGB
MAST.BANK_CODE,
MAST.BANK_ACCT_NO,
MAST.HOLDER_ID,
MAST.CREDIT_CARD_TYPE,
MAST.CREDIT_CARD_NO,
MAST.CREDIT_CARD_EXP_DATE CREDIT_CARD_EXP_DATE,
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
  AND MAST.BILL_SEQ  = BA.BILL_SEQ
  AND MAST.CYCLE     = BA.CYCLE
  AND MAST.CYCLE_MONTH = BA.CYCLE_MONTH
  and mast.acct_key  = ba.acct_key
  AND MAST.ACCT_ID   = BA.ACCT_ID
  AND MAST.PAYMENT_METHOD IN('CC','DD')
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}