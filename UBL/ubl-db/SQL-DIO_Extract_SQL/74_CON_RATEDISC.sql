SELECT /*+opt_param(''optimizer_adaptive_reporting_only'', ''TRUE'')*/ 
CI.CUST_ID,
CI.offer_level_ID as SUBSCRIBER_NO,
CI.ACCT_ID as ACCOUNT_ID,
CI.OFFER_ID as RATE_OFFER_ID,
null as CHARGE_CODE,
CI.DIS_AMT as amount,
CI.CYCLE as cycle_code,
SUBSTR(CI.BILL_PERIOD,1,4) CYCLE_YEAR,
SUBSTR(CI.BILL_PERIOD,5,2) CYCLE_MONTH,
null as TAX_AMOUNT,
null as TAX_RATE,
CI.PKG_ID as SOURCE_OFFER_ID,
DECODE(CI.offer_level,''SUB'',''S'',''ACCT'',''B'',''O'',''U'') SERVICE_RECEIVER_TYPE, 
CM.SUBSCR_TYPE, 
MAST.BILL_NBR  
FROM FY_TB_BL_BILL_CNTRL CT,
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_RAT_ACCT_PKG_DTL CI,
     FY_TB_CM_SUBSCR CM,
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
  AND BA.bill_status  = ''CN''
  AND CI.CYCLE       = ba.CYCLE
  AND CI.CYCLE_MONTH = ba.CYCLE_MONTH
  and ci.acct_key    = ba.acct_key
  AND CI.ACCT_ID     = BA.ACCT_ID
  AND CM.SUBSCR_ID = CI.offer_level_ID
  AND CT.BILL_SEQ = MAST.BILL_SEQ
  AND BA.ACCT_ID  = MAST.ACCT_ID  
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
    AND DIS_AMT > 0'