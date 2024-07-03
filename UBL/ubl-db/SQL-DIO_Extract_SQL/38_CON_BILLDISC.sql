/*
SR220754：AWS 折扣安裝需求_電腦公會AI Star專案 
1.新增欄位:SERVICE_RECEIVER_TYPE
2.新增欄位:SUBSCR_TYPE
3.新增欄位:BILL_NBR (NEW JOIN FY_TB_BL_BILL_MAST MAST)
4.修正TAX_AMOUNT計算方式
*/
SELECT
CI.CUST_ID,
CI.SUBSCR_ID,
CI.ACCT_ID,
CI.OFFER_ID,
CI.CHARGE_CODE,
CI.AMOUNT,
CT.CYCLE,
SUBSTR(CT.BILL_PERIOD,5,2) CYCLE_MONTH,
SUBSTR(CT.BILL_PERIOD,1,4) CYCLE_YEAR,
--(CI.AMOUNT * CHRG.NUM1) TAX_AMOUNT, 
ROUND(CI.AMOUNT/(1+CHRG.NUM1)*CHRG.NUM1,2) TAX_AMOUNT,--SR220754
CHRG.NUM1 TAX_RATE,
CI.SOURCE_OFFER_ID,
DECODE(CI.SERVICE_RECEIVER_TYPE,'S','S','A','B','O','U') SERVICE_RECEIVER_TYPE, --SR220754
CM.SUBSCR_TYPE, --SR220754
MAST.BILL_NBR   --SR220754
FROM FY_TB_BL_BILL_CNTRL CT,
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_CI CI,
     (SELECT A.CHARGE_CODE, B.NUM1 FROM FY_TB_PBK_CHARGE_CODE A,
                                        FY_TB_SYS_LOOKUP_CODE B
                                   WHERE A.TAX_RATE = B.LOOKUP_CODE
                                     AND B.LOOKUP_TYPE ='TAX_TYPE') CHRG,
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
  AND BA.bill_status  = 'CN'
  AND CI.BILL_SEQ    = ba.BILL_SEQ
  AND CI.CYCLE       = ba.CYCLE
  AND CI.CYCLE_MONTH = ba.CYCLE_MONTH
  and ci.acct_key    = ba.acct_key
  AND CI.ACCT_ID     = BA.ACCT_ID
  AND CI.SOURCE      = 'DE'
  AND CHRG.CHARGE_CODE = CI.CHARGE_CODE
  AND CM.SUBSCR_ID = CI.SUBSCR_ID
  AND CT.BILL_SEQ = MAST.BILL_SEQ
  AND BA.ACCT_ID  = MAST.ACCT_ID  
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}