SELECT 'PYMT' pymt, RPAD (TRIM (ba.acct_id), 12, ' ') billing_arrangement_id,
       RPAD (TRIM (ba.acct_id), 12, ' ') cm_pay_channel_id,
       RPAD (TRIM (fet1_payment.original_amount), 23, ' ') original_amount,
       RPAD (NVL(TRIM (fet1_payment_details.payment_method),' '), 3, ' ') payment_method,
       RPAD (NVL(TRIM (fet1_payment_details.payment_sub_method),' '), 2,' ') payment_sub_method,
       RPAD (NVL(TRIM (fet1_payment_details.check_no),' '), 15, ' ') check_no,
       RPAD(NVL(TRIM (fet1_payment_details.payment_source_type),' '),1,' ') payment_source_type,
       RPAD (NVL(TRIM (fet1_payment_details.payment_source_id),' ' ),8, ' ') payment_source_id,
       RPAD (NVL(TRIM (fet1_payment_details.bank_code),' '), 6, ' ') bank_code,
       TO_CHAR (TRUNC (fet1_payment_details.deposit_date),'YYYYMMDD') deposit_date,
       TO_CHAR (TRUNC (fet1_payment.activity_date), 'YYYYMMDD') activity_date,
       RPAD (NVL(TRIM(fet1_payment_details.credit_card_number),' '), 100, ' ') credit_card_number,
       RPAD (NVL(TRIM(fet1_payment.payment_id), ' '), 12, ' ') payment_id
  FROM fy_tb_bl_bill_acct ba, fy_tb_BL_bill_CNTRL BC,
       fet1_account,
       fet1_payment,
       fet1_payment_details
 WHERE ba.bill_seq =  ${billSeq}
   AND ba.bill_seq = bc.bill_seq
   AND BA.CYCLE = BC.CYCLE
   AND BA.CYCLE_MONTH = BC.CYCLE_MONTH   
   AND ba.bill_status = 'MA'
   AND ba.bill_seq = fet1_payment.bill_seq_no
   AND ba.acct_id = fet1_account.account_id
   AND fet1_account.partition_id = fet1_payment.partition_id
   AND fet1_account.account_id = fet1_payment.account_id
   AND fet1_payment.pymdt_partition_id = fet1_payment_details.partition_id
   AND fet1_payment.pymdt_period_key = fet1_payment_details.period_key
   AND fet1_payment.payment_id = fet1_payment_details.payment_id
   and ACTIVITY_INDICATOR ='P' --20200908
   AND NVL (fet1_payment_details.payment_sub_method, ' ') != 'DEP'
   AND 'B' = ${procType}
     and ba.acct_key  = mod(ba.acct_id,100)
  AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = ba.BILL_SEQ
										    and cycle     = ba.cycle
											and cycle_month=ba.cycle_month
											and acct_key  = ba.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = ba.ACCT_ID)) OR 
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = ba.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = ba.ACCT_ID))) 
  AND ba.ACCT_ID BETWEEN ${acctIds} and ${acctIde}