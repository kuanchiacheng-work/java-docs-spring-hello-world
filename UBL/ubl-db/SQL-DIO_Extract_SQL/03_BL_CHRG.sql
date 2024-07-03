SELECT 'CHRG' Dummy_Field1,
BI.BI_SEQ,
0 Charge_Correction_Seq,
SUBSTR(MT.BILL_NBR,3,10) Statement_Seq,
SUBSTR(MT.BILL_NBR,3,10) Invoice_Seq,
BI.BI_SEQ Tax_Sequence_Number,
(BI.AMOUNT-BI.TAX_AMT) Bill_Currency_Amt, BI.BILL_CURRENCY, NULL Amount_Exchange_Date,
(BI.AMOUNT-BI.TAX_AMT) Customer_Currency_Amount, BI.BILL_CURRENCY Customer_Currency, BI.ACCT_ID BA_Num, BI.ACCT_ID Pay_Channel_Num, BI.CHARGE_TYPE, BI.CHARGE_CODE, 
CHRG.CET,
CHRG.REVENUE_CODE,
BI.TAX_TYPE,
'B' Invoice_Type,
BI.CHARGE_DESCR,
TO_CHAR(BI.CHRG_DATE,'YYYYMMDD') CHRG_DATE,
decode(BI.SERVICE_RECEIVER_TYPE,'A','B','O','U',BI.SERVICE_RECEIVER_TYPE)
SERVICE_RECEIVER_TYPE,
CASE BI.SERVICE_RECEIVER_TYPE
WHEN 'S' THEN BI.SUBSCR_ID
WHEN 'A' THEN BI.ACCT_ID
WHEN 'O' THEN BI.OU_ID
ELSE NULL
END AS SERVICE_RECEIVER_ID,
BA.CUST_ID,
BI.OFFER_ID,
(CASE WHEN bi.ci_seq IS NOT NULL THEN
     (SELECT OFFER_INSTANCE_ID
       FROM FY_TB_BL_bill_ci
      WHERE bill_seq   =bi.bill_seq
        and cycle      =bi.cycle
        and cycle_month=bi.cycle_month
		and acct_key = bi.acct_key
		and acct_id = bi.acct_id
        and ci_seq     =bi.ci_seq)
 ELSE
    null
 END) OFFER_INSTANCE_ID,
NULL Offer_Item,
BI.CHARGE_ORG,
BA.CYCLE,
SUBSTR(CT.BILL_PERIOD,5,2) PERIOD_MM,
SUBSTR(CT.BILL_PERIOD,1,4) PERIOD_YYYY,
BI.DYNAMIC_ATTRIBUTE
FROM fy_tb_bl_bill_cntrl ct,
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_MAST MT,
     FY_TB_BL_BILL_BI BI,
     FY_TB_PBK_CHARGE_CODE CHRG
WHERE 'B' = ${procType}
  and ct.BILL_SEQ  = ${billSeq}
  AND BA.BILL_SEQ  = ct.bill_seq
  AND ba.cycle     = ct.cycle
  and ba.cycle_month=ct.cycle_month
  and ba.acct_key   =mod(ba.acct_id,100)
  AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR
       (999 =  ${processNo} AND EXISTS
								(SELECT 1
FROM FY_TB_BL_ACCT_LIST
                                 WHERE BILL_SEQ = BA.BILL_SEQ
                                 AND TYPE = ${acctGroup}
                                 AND ACCT_ID = BA.ACCT_ID)))
  AND MT.BILL_SEQ = BA.BILL_SEQ
  AND MT.CYCLE    = BA.CYCLE
  AND MT.CYCLE_MONTH = BA.CYCLE_MONTH
  and mt.acct_key    = ba.acct_key
  AND MT.ACCT_ID  = BA.ACCT_ID
  AND BI.BILL_SEQ = MT.BILL_SEQ
  AND BI.CYCLE    = MT.CYCLE
  AND BI.CYCLE_MONTH = MT.CYCLE_MONTH
  and bi.acct_key    = mt.acct_key
  AND BI.ACCT_ID  = MT.ACCT_ID
  AND CHRG.CHARGE_CODE = BI.CHARGE_CODE
  AND CHRG.REVENUE_CODE<>'CET'
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
--SR241001 2021/12/31
UNION  
SELECT 'CHRG' Dummy_Field1,
MT.MAST_SEQ,
0 Charge_Correction_Seq,
SUBSTR(MT.BILL_NBR,3,10) Statement_Seq,
SUBSTR(MT.BILL_NBR,3,10) Invoice_Seq,
MT.MAST_SEQ Tax_Sequence_Number,
0 Bill_Currency_Amt, 
MT.BILL_CURRENCY, 
NULL Amount_Exchange_Date,
0 Customer_Currency_Amount, 
MT.BILL_CURRENCY Customer_Currency, 
AP.ACCT_ID BA_Num, 
AP.ACCT_ID Pay_Channel_Num, 
'CRD' CHARGE_TYPE, 
'RC_DISCOUNT' CHARGE_CODE, -- pbk charge code
'DISCOUNT' CET,            -- pbk CET
'RC' REVENUE_CODE,
decode ((select count(1) from fy_tb_cm_attribute_param where entity_type = 'A' and attribute_name = 'CHANGE_ZERO_TAX' and attribute_value = 'Y' and entity_id = AP.ACCT_ID),0,'TX1','TX2') TAX_TYPE,            --pbk charge code --SR265840_ProjectM 1.1
'B' Invoice_Type,
AP.OFFER_NAME CHARGE_DESCR,--pbk charge code
TO_CHAR(CT.BILL_DATE,'YYYYMMDD') CHRG_DATE,
decode(AP.OFFER_LEVEL,'A','B','O','U',AP.OFFER_LEVEL) SERVICE_RECEIVER_TYPE,
AP.OFFER_LEVEL_ID SERVICE_RECEIVER_ID,
BA.CUST_ID,
AP.OFFER_ID,
AP.OFFER_INSTANCE_ID,
NULL Offer_Item,
'DE' CHARGE_ORG,          --DE
BA.CYCLE,
SUBSTR(CT.BILL_PERIOD,5,2) PERIOD_MM,
SUBSTR(CT.BILL_PERIOD,1,4) PERIOD_YYYY,
'TotalRolloverAmount='  ||NVL(AP.CUR_BAL_QTY,AP.BILL_BAL_QTY)      ||'#'|| --SR265840_ProjectM 1.1
'Discount package ID='  ||AP.PKG_ID           ||'#'||  --PKG_ID
'Remaining='            ||AP.BILL_BAL_QTY     ||'#'||
'Discount offer ID='    ||AP.OFFER_ID         ||'#'||
'Discount offer Seq No='||AP.OFFER_INSTANCE_ID||'#'||  --OFFER_INSTANCE_ID
'CycleSeqNo='           ||CT.BILL_SEQ         ||'#'||  
'OccurrenceInd=N#'                                 ||
'ProratedInd=N#' DYNAMIC_ATTRIBUTE
FROM fy_tb_bl_bill_cntrl ct,
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_MAST MT,
     FY_TB_BL_ACCT_PKG AP
WHERE 'B' = ${procType}
  and ct.BILL_SEQ  = ${billSeq}
  AND BA.BILL_SEQ  = ct.bill_seq
  AND ba.cycle     = ct.cycle
  and ba.cycle_month=ct.cycle_month
  and ba.acct_key   =mod(ba.acct_id,100)
  AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR
       (999 =  ${processNo} AND EXISTS
                                (SELECT 1
                                 FROM FY_TB_BL_ACCT_LIST
                                 WHERE BILL_SEQ = BA.BILL_SEQ
                                 AND TYPE = ${acctGroup}
                                 AND ACCT_ID = BA.ACCT_ID)))
  AND MT.BILL_SEQ = BA.BILL_SEQ
  AND MT.CYCLE    = BA.CYCLE
  AND MT.CYCLE_MONTH = BA.CYCLE_MONTH
  and mt.acct_key    = ba.acct_key
  AND MT.ACCT_ID  = BA.ACCT_ID
  and AP.acct_key    = mt.acct_key
  AND AP.ACCT_ID  = MT.ACCT_ID
  and ba.acct_key   =mod(ba.acct_id,100)
  and AP.PKG_TYPE_DTL = 'BDN' -- effective BDE 
  and AP.STATUS ='OPEN'  -- effective BDE 
  and AP.BILL_BAL_QTY > 0 -- effective BDE 
  and (AP.END_DATE is null or to_char(AP.END_DATE,'yyyymmdd') >= to_char(ct.BILL_FROM_DATE,'yyyymmdd') ) -- effective BDE  
  and not exists (
    select 1 from fy_Tb_bl_bill_bi bi 
    where bi.bill_seq = mt.bill_seq 
    and bi.acct_id= mt.acct_id 
    and bi.cycle=mt.cycle 
    and bi.cycle_month = mt.cycle_month 
	AND BI.OFFER_ID = AP.OFFER_ID
    AND BI.OFFER_SEQ = AP.OFFER_SEQ
    and bi.acct_key = mt.acct_key)
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT 'CHRG' Dummy_Field1, BI.BI_SEQ,
0 Charge_Correction_Seq,
SUBSTR(MT.BILL_NBR,3,10) Statement_Seq,
SUBSTR(MT.BILL_NBR,3,10) Invoice_Seq,
BI.BI_SEQ,
(BI.AMOUNT-BI.TAX_AMT) Bill_Currency_Amt, BI.BILL_CURRENCY, NULL Amount_Exchange_Date,
(BI.AMOUNT-BI.TAX_AMT) Customer_Currency_Amount, BI.BILL_CURRENCY Customer_Currency, BI.ACCT_ID BA_Num, BI.ACCT_ID Pay_Channel_Num, BI.CHARGE_TYPE, BI.CHARGE_CODE,
CHRG.CET,
CHRG.REVENUE_CODE,
BI.TAX_TYPE,
'B' Invoice_Type,
BI.CHARGE_DESCR,
TO_CHAR(BI.CHRG_DATE,'YYYYMMDD') CHRG_DATE,
decode(BI.SERVICE_RECEIVER_TYPE,'A','B','O','U',BI.SERVICE_RECEIVER_TYPE)
SERVICE_RECEIVER_TYPE,
CASE BI.SERVICE_RECEIVER_TYPE
WHEN 'S' THEN BI.SUBSCR_ID
WHEN 'A' THEN BI.ACCT_ID
WHEN 'O' THEN BI.OU_ID
ELSE NULL
END AS SERVICE_RECEIVER_ID,
BA.CUST_ID,
BI.OFFER_ID,
(CASE WHEN bi.ci_seq IS NOT NULL THEN
     (SELECT OFFER_INSTANCE_ID
       FROM FY_TB_BL_bill_ci_test
      WHERE bill_seq   =bi.bill_seq
        and cycle      =bi.cycle
        and cycle_month=bi.cycle_month
		and acct_key   =bi.acct_key
		and acct_id    =bi.acct_id
        and ci_seq     =bi.ci_seq)
 ELSE
    null
 END) OFFER_INSTANCE_ID,
NULL Offer_Item,
BI.CHARGE_ORG,
BA.CYCLE,
SUBSTR(CT.BILL_PERIOD,5,2) PERIOD_MM,
SUBSTR(CT.BILL_PERIOD,1,4) PERIOD_YYYY,
BI.DYNAMIC_ATTRIBUTE
FROM fy_tb_bl_bill_cntrl ct,
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_MAST_TEST MT,
     FY_TB_BL_BILL_BI_TEST BI,
     FY_TB_PBK_CHARGE_CODE CHRG
WHERE 'T' = ${procType}
  and ct.BILL_SEQ  = ${billSeq}
  AND BA.BILL_SEQ  = ct.bill_seq
  AND ba.cycle     = ct.cycle
  and ba.cycle_month=ct.cycle_month
  and ba.acct_key   =mod(ba.acct_id,100)
  AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR
       (999 =  ${processNo} AND EXISTS
	                           (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                WHERE BILL_SEQ = BA.BILL_SEQ
                                AND TYPE = ${acctGroup}
                                AND ACCT_ID = BA.ACCT_ID)))
  AND MT.BILL_SEQ = BA.BILL_SEQ
  AND MT.CYCLE    = BA.CYCLE
  AND MT.CYCLE_MONTH = BA.CYCLE_MONTH
  and mt.acct_key    = ba.acct_key
  AND MT.ACCT_ID  = BA.ACCT_ID
  AND BI.BILL_SEQ = MT.BILL_SEQ
  AND BI.CYCLE    = MT.CYCLE
  AND BI.CYCLE_MONTH = MT.CYCLE_MONTH
  and bi.acct_key    = mt.acct_key
  AND BI.ACCT_ID  = MT.ACCT_ID
  AND CHRG.CHARGE_CODE = BI.CHARGE_CODE
  AND CHRG.REVENUE_CODE<>'CET'
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION --20220207
SELECT 'CHRG' Dummy_Field1,
MT.MAST_SEQ,
0 Charge_Correction_Seq,
SUBSTR(MT.BILL_NBR,3,10) Statement_Seq,
SUBSTR(MT.BILL_NBR,3,10) Invoice_Seq,
MT.MAST_SEQ Tax_Sequence_Number,
0 Bill_Currency_Amt, 
MT.BILL_CURRENCY, 
NULL Amount_Exchange_Date,
0 Customer_Currency_Amount, 
MT.BILL_CURRENCY Customer_Currency, 
AP.ACCT_ID BA_Num, 
AP.ACCT_ID Pay_Channel_Num, 
'CRD' CHARGE_TYPE, 
'RC_DISCOUNT' CHARGE_CODE, -- pbk charge code
'DISCOUNT' CET,            -- pbk CET
'RC' REVENUE_CODE,
decode ((select count(1) from fy_tb_cm_attribute_param where entity_type = 'A' and attribute_name = 'CHANGE_ZERO_TAX' and attribute_value = 'Y' and entity_id = AP.ACCT_ID),0,'TX1','TX2') TAX_TYPE,            --pbk charge code --SR265840_ProjectM 1.1
'B' Invoice_Type,
AP.OFFER_NAME CHARGE_DESCR,--pbk charge code
TO_CHAR(CT.BILL_DATE,'YYYYMMDD') CHRG_DATE,
decode(AP.OFFER_LEVEL,'A','B','O','U',AP.OFFER_LEVEL) SERVICE_RECEIVER_TYPE,
AP.OFFER_LEVEL_ID SERVICE_RECEIVER_ID,
BA.CUST_ID,
AP.OFFER_ID,
AP.OFFER_INSTANCE_ID,
NULL Offer_Item,
'DE' CHARGE_ORG,          --DE
BA.CYCLE,
SUBSTR(CT.BILL_PERIOD,5,2) PERIOD_MM,
SUBSTR(CT.BILL_PERIOD,1,4) PERIOD_YYYY,
'TotalRolloverAmount='  ||NVL(AP.TEST_QTY,AP.TEST_BAL_QTY)         ||'#'|| --SR265840_ProjectM 1.1
'Discount package ID='  ||AP.PKG_ID           ||'#'||  --PKG_ID
'Remaining='            ||AP.TEST_BAL_QTY     ||'#'||
'Discount offer ID='    ||AP.OFFER_ID         ||'#'||
'Discount offer Seq No='||AP.OFFER_INSTANCE_ID||'#'||  --OFFER_INSTANCE_ID
'CycleSeqNo='           ||CT.BILL_SEQ         ||'#'||  
'OccurrenceInd=N#'                                 ||
'ProratedInd=N#' DYNAMIC_ATTRIBUTE
FROM fy_tb_bl_bill_cntrl ct,
     FY_TB_BL_BILL_ACCT BA,
     FY_TB_BL_BILL_MAST_TEST MT,
     FY_TB_BL_ACCT_PKG AP
WHERE 'T' = ${procType}
  and ct.BILL_SEQ  = ${billSeq}
  AND BA.BILL_SEQ  = ct.bill_seq
  AND ba.cycle     = ct.cycle
  and ba.cycle_month=ct.cycle_month
  and ba.acct_key   =mod(ba.acct_id,100)
  AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR
       (999 =  ${processNo} AND EXISTS
                                (SELECT 1
                                 FROM FY_TB_BL_ACCT_LIST
                                 WHERE BILL_SEQ = BA.BILL_SEQ
                                 AND TYPE = ${acctGroup}
                                 AND ACCT_ID = BA.ACCT_ID)))
  AND MT.BILL_SEQ = BA.BILL_SEQ
  AND MT.CYCLE    = BA.CYCLE
  AND MT.CYCLE_MONTH = BA.CYCLE_MONTH
  and mt.acct_key    = ba.acct_key
  AND MT.ACCT_ID  = BA.ACCT_ID
  and AP.acct_key    = mt.acct_key
  AND AP.ACCT_ID  = MT.ACCT_ID
  and ba.acct_key   =mod(ba.acct_id,100)
  and AP.PKG_TYPE_DTL = 'BDN' -- effective BDE 
  and AP.STATUS ='OPEN'  -- effective BDE 
  and AP.BILL_BAL_QTY > 0 -- effective BDE 
  and (AP.END_DATE is null or to_char(AP.END_DATE,'yyyymmdd') >= to_char(ct.BILL_FROM_DATE,'yyyymmdd') ) -- effective BDE  
  and not exists (
    select 1 from fy_Tb_bl_bill_bi bi 
    where bi.bill_seq = mt.bill_seq 
    and bi.acct_id= mt.acct_id 
    and bi.cycle=mt.cycle 
    and bi.cycle_month = mt.cycle_month
	AND BI.OFFER_ID = AP.OFFER_ID
    AND BI.OFFER_SEQ = AP.OFFER_SEQ
    and bi.acct_key = mt.acct_key)
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}