SELECT
BI.ACCT_ID,
MAST.BILL_NBR,
BI.BI_SEQ,
BI.CORRECT_SEQ,
DECODE(BI.CHARGE_ORG,'DE','DSC',BI.CHARGE_TYPE) CHARGE_TYPE,
TO_CHAR(BI.CHRG_DATE,'YYYYMMDD') CHRG_DATE,
BI.BILL_CURRENCY,
(BI.AMOUNT-BI.TAX_AMT) AMOUNT,
BI.TAX_AMT,
(SELECT NUM1 FROM FY_TB_SYS_LOOKUP_CODE WHERE LOOKUP_TYPE ='TAX_TYPE' AND LOOKUP_CODE = BI.TAX_TYPE) TAX_RATE,
BI.CHARGE_CODE,
(CASE WHEN BI.CHARGE_ORG='UC' THEN
   'UC'
 ELSE   
   (SELECT REVENUE_CODE FROM FY_TB_PBK_CHARGE_CODE WHERE CHARGE_CODE=BI.CHARGE_CODE AND REVENUE_CODE<>'CET') 
 END)  REVENUE_CODE, 
BI.TAX_TYPE,
DECODE(BI.SERVICE_RECEIVER_TYPE,'S','S','A','B','O','U') SERVICE_RECEIVER_TYPE,
CASE SERVICE_RECEIVER_TYPE
WHEN 'S' THEN BI.SUBSCR_ID
WHEN 'A' THEN BI.ACCT_ID
WHEN 'O' THEN BI.OU_ID
ELSE NULL END SERVICE_RECEIVER_ID,
BI.OFFER_ID,
BI.CHARGE_ORG,
BA.CONFIRM_ID,
BA.CYCLE,
SUBSTR(CT.BILL_PERIOD,5,2) CYCLE_MONTH,
SUBSTR(CT.BILL_PERIOD,1,4) CYCLE_YEAR,
CASE 
  WHEN (BI.CHARGE_ORG = 'DE' AND BI.CHARGE_TYPE = 'CRD') OR BI.CHARGE_ORG = 'RA'
  THEN substrb(bi.dynamic_attribute,
               instrb(bi.dynamic_attribute, '=', instrb(bi.dynamic_attribute,'TX_ID',1,1), 1)+1,
               instrb(bi.dynamic_attribute, '#', instrb(bi.dynamic_attribute,'TX_ID',1,1), 1)-instrb(bi.dynamic_attribute, '=', 
               instrb(bi.dynamic_attribute,'TX_ID',1,1), 1)-1
              )  
  WHEN BI.CHARGE_ORG = 'DE' AND BI.CHARGE_TYPE = 'DSC'
   --THEN (SELECT to_char(ORG.CI_SEQ) FROM FY_TB_BL_BILL_CI CI,
   THEN (SELECT decode(org.source,'UC',to_char(org.txn_id),to_char(ORG.CI_SEQ)) FROM FY_TB_BL_BILL_CI CI, --20241023修正UC折扣TXNID不一致
                                              FY_TB_BL_BILL_CI ORG
                                      WHERE CI.CI_SEQ =BI.CI_SEQ
                                        and ci.cycle=bi.cycle and ci.cycle_month=bi.cycle_month and ci.acct_key=bi.acct_key
                                        AND ORG.CI_SEQ=CI.SOURCE_CI_SEQ
                                        and org.cycle=ci.cycle and org.cycle_month=ci.cycle_month and org.acct_key=ci.acct_key)
  WHEN BI.CHARGE_ORG = 'CC'
  THEN to_char(bi.ci_seq)                                       
END AS TXN_ID,
'' CSP_SERVICE_ID,
SUB.PRIM_RESOURCE_VAL,
(SELECT PKG_ID FROM FY_TB_BL_BILL_CI 
      WHERE CI_SEQ = BI.CI_SEQ and cycle=bi.cycle and cycle_month=bi.cycle_month and acct_key=bi.acct_key ) PKG_ID,
BI.OFFER_SEQ,
(CASE WHEN BI.CHARGE_ORG<>'DE' THEN
    NULL
 ELSE
    (SELECT 'SOURCE_BI_SEQ='||ORG.BI_SEQ FROM FY_TB_BL_BILL_CI CI,
                                              FY_TB_BL_BILL_CI ORG
                                      WHERE CI.CI_SEQ =BI.CI_SEQ
									    and ci.cycle=bi.cycle and ci.cycle_month=bi.cycle_month and ci.acct_key=bi.acct_key
                                        AND ORG.CI_SEQ=CI.SOURCE_CI_SEQ
										and org.cycle=ci.cycle and org.cycle_month=ci.cycle_month and org.acct_key=ci.acct_key)                                         
 END) DYNAMIC_ATTRIBUTE,
SUB.SUBSCR_TYPE
FROM FY_TB_BL_BILL_CNTRL CT,
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_BI BI,
     FY_TB_BL_BILL_MAST MAST,
     FY_TB_CM_SUBSCR SUB
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
  AND BA.bill_status = 'CN'
  AND MAST.BILL_SEQ = BA.BILL_SEQ
  AND MAST.CYCLE    = BA.CYCLE
  AND MAST.CYCLE_MONTH = BA.CYCLE_MONTH
  and mast.acct_key = ba.acct_key
  AND MAST.ACCT_ID  = BA.ACCT_ID
  AND BI.BILL_SEQ   = MAST.BILL_SEQ
  AND BI.CYCLE      = MAST.CYCLE
  AND BI.CYCLE_MONTH= MAST.CYCLE_MONTH
  and bi.acct_key   = mast.acct_key
  AND BI.ACCT_ID    = MAST.ACCT_ID
  AND SUB.SUBSCR_ID(+) = BI.SUBSCR_ID
  --AND SUB.PRIM_RESOURCE_TP='C'
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
 ORDER BY BI.ACCT_ID,BI.BI_SEQ 
