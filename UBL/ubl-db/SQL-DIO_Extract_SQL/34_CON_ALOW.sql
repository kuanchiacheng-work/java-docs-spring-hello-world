SELECT 
'ALOWAllowance billing record' Entry_Name, 
A.acct_id, 
A.offer_level_id Service_receiver_ID, 
A.cust_id Customer_ID, 
A.pkg_id Item_ID, 
A.offer_id Offer_ID, 
A.OFFER_INSTANCE_ID Offer_instance, 
NULL Period_name, 
A.cur_qty Total_units, 
A.use_qty Used_units, 
A.bal_qty Left_units, 
NULL UOM_code, 
NULL Expiration_date, 
NULL Allowance_ID, 
A.dis_amt Allowance_amount, 
'POST' Payment_category, 
NULL Used_balance_amount, 
NULL Remaining_balance_amount, 
NULL COP_Quota
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST Mast,
     FY_TB_RAT_ACCT_PKG_DTL A
WHERE 'B' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  AND MAST.BILL_SEQ  = bc.bill_seq
  and mast.cycle     = bc.cycle
  and mast.cycle_month=bc.cycle_month
  and mast.acct_key  = mod(mast.acct_id,100)
  AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
										    and cycle     = mast.cycle
											and cycle_month=mast.cycle_month
											and acct_key  = mast.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = Mast.ACCT_ID)) OR
     (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = Mast.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = Mast.ACCT_ID)))
  AND A.CYCLE       = Mast.CYCLE
  AND A.CYCLE_MONTH = Mast.CYCLE_MONTH
  and a.acct_key    = mast.acct_key
  AND A.ACCT_ID     = Mast.ACCT_ID
  AND A.DIS_TYPE    ='AW'
  AND Mast.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT 
'ALOWAllowance billing record' Entry_Name, 
A.acct_id, 
A.offer_level_id Service_receiver_ID, 
A.cust_id Customer_ID, 
A.pkg_id Item_ID, 
A.offer_id Offer_ID, 
A.OFFER_INSTANCE_ID Offer_instance, 
NULL Period_name, 
A.cur_qty Total_units, 
A.use_qty Used_units, 
A.bal_qty Left_units, 
NULL UOM_code, 
NULL Expiration_date, 
NULL Allowance_ID, 
A.dis_amt Allowance_amount, 
'POST' Payment_category, 
NULL Used_balance_amount, 
NULL Remaining_balance_amount, 
NULL COP_Quota 
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST_TEST Mast,
     FY_TB_RAT_ACCT_PKG_DTL A
WHERE 'T' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  AND MAST.BILL_SEQ  = bc.bill_seq
  and mast.cycle     = bc.cycle
  and mast.cycle_month=bc.cycle_month
  and mast.acct_key  = mod(mast.acct_id,100)
  AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
										    and cycle     = mast.cycle
											and cycle_month=mast.cycle_month
											and acct_key  = mast.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = Mast.ACCT_ID)) OR
     (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = Mast.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = Mast.ACCT_ID)))
  AND A.CYCLE       = Mast.CYCLE
  AND A.CYCLE_MONTH = Mast.CYCLE_MONTH
  and a.acct_key    = mast.acct_key
  AND A.ACCT_ID     = Mast.ACCT_ID
  AND A.DIS_TYPE    ='AW'
  AND Mast.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
