SELECT 'CRRV' crrv, RPAD (TRIM (ba.acct_id), 12, ' ') billing_arrangement_id,
       RPAD (TRIM (ba.acct_id), 12, ' ') cm_pay_channel_id,
       TO_CHAR (TRUNC (fet1_customer_credit.credit_date),'YYYYMMDD') credit_date,
       TO_CHAR (TRUNC (fet1_customer_credit.reversal_date),'YYYYMMDD') reversal_date,
       RPAD (NVL(TRIM(fet1_customer_credit.amount),' '), 23, ' ') amount,
       RPAD (NVL(TRIM(fet1_customer_credit.charge_code),' '), 15, ' ') charge_code,
       RPAD (NVL(TRIM(fet1_customer_credit.chg_revenue_code),' '), 6,' ') chg_revenue_code,
       RPAD (NVL(TRIM(fet1_customer_credit.tax_amount),' '), 20, ' ') tax_amount,
       RPAD (NVL(TRIM(fet1_customer_credit.invoice_reversal_number),' '), 12, ' ') invoice_reversal_number,
	   RPAD (NVL(TRIM(fet1_customer_credit.reversal_reason),' '), 10, ' ') reversal_reason,
       RPAD (NVL(TRIM(fet1_customer_credit.credit_id),' '), 12, ' ') credit_id,
       RPAD (NVL(TRIM(fet1_customer_credit.l9_service_receiver_type),' '), 1, ' ') l9_service_receiver_type,
       RPAD (NVL(TRIM(fet1_customer_credit.l9_service_receiver_id),' '), 12, ' ') l9_service_receiver_id,
       RPAD (TRIM(DECODE (NVL (fet1_customer_credit.invoice_id, 0), 0, fet1_customer_credit.transaction_id, fet1_customer_credit.invoice_id)),12,' ') invoice_id,
       RPAD ('TX2', 6, ' ') tax_code
  FROM fy_tb_bl_bill_acct ba, fy_tb_BL_bill_CNTRL BC,
       fet1_account,
       fet1_customer_credit
 WHERE ba.bill_seq =  ${billSeq}
   AND ba.bill_seq = bc.bill_seq
   AND BA.CYCLE = BC.CYCLE
   AND BA.CYCLE_MONTH = BC.CYCLE_MONTH
   AND ba.bill_status = 'MA'
   AND ba.bill_seq = fet1_customer_credit.reversal_bill_seq_no
   AND ba.acct_id = fet1_account.account_id
   AND fet1_account.partition_id = fet1_customer_credit.partition_id
   AND fet1_account.account_id = fet1_customer_credit.account_id
   AND fet1_customer_credit.credit_reason IS NOT NULL
   AND 'B' = ${procType}
  and BA.acct_key  = mod(BA.acct_id,100)
  AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = BA.BILL_SEQ
										    and cycle     = BA.cycle
											and cycle_month=BA.cycle_month
											and acct_key  = BA.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = BA.ACCT_ID)) OR 
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = BA.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = BA.ACCT_ID)))  
  AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}