SELECT
'RTEVEvent extract for FBF' Entity_Name,
A.subscr_id Subscriber_ID,
TO_CHAR(A.start_time,'YYYY-MM-DD HH24:MI:SS') Network_start_time,
A.acct_id Billing_arrangement,
A.resource_value Calling_number,
A.b_party Called_number,
A.service_filter Service_filter ,
NULL Call_forward_ind,
A.provider_id Provider_ID,
A.chrg_amt Charge_amount,
A.b_party APN,
A.qty Original_quantity_1,
NULL Original_UOM_1 ,
A.ROUNDED_QTY Original_quantity_2,
NULL Event_type_ID,
A.chrg_amt Charge_allowance,
NULL Friends_and_family_number_ind ,
A.period_type Period_Name ,
A.charge_code Charge_code,
A.cet CET_name,
A.dis_amt  Discount_amount,
NULL Product_ID,
DECODE(A.ROUNDING_UOM,'K',1024,'M',1024*1024,'G',1024*1024*1024,1)*A.rounding_factor UoM_block2,
'POST' Payment_Category,
NULL Session_ID,
NULL Rating_Group,
NULL QoS,
--NULL Ofc_roaming_ind,
--NULL Subscriber_type,
rpad(A.TX_ID,20,' ') tx_id,
--A.offer_id  Offer_ID ,
to_char(End_Time,'yyyymmdd') End_Time
FROM FY_TB_BL_BILL_CNTRL bc,
     FY_TB_BL_BILL_ACCT Mast,
     FY_TB_RAT_CDR A
WHERE Bc.BILL_SEQ  = ${billSeq}
  --AND 'B' = ${procType} --20190630
  AND MAST.BILL_SEQ  = bc.bill_seq
  and mast.cycle     = bc.cycle
  and mast.cycle_month=bc.cycle_month
  and mast.acct_key  = mod(mast.acct_id,100)
  AND ((999 <> ${processNo} AND ACCT_GROUP= ${acctGroup}) OR
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = Mast.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = Mast.ACCT_ID)))
  AND A.ACCT_ID     = Mast.ACCT_ID
  AND A.bill_period = bc.BILL_PERIOD
  AND A.CYCLE       = mast.CYCLE
  AND A.CYCLE_MONTH = mast.CYCLE_MONTH
  and a.acct_key    = mast.acct_key
  AND Mast.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
ORDER BY A.subscr_id  