SELECT 'BKOT' bkot,
       RPAD(NVL(TRIM(v.acct_id),' '), 12, ' ') billing_arrangement_id,
       RPAD(NVL(TRIM(v.acct_id),' '), 12, ' ') cm_pay_channel_id,
       RPAD(NVL(TRIM(v.activity_type),' '), 5, ' ') activity_type,
       RPAD(NVL(TRIM(v.reason_code),' '), 10, ' ') reason_code,
       RPAD(NVL(TRIM(v.original_amount),' '), 23, ' ') original_amount,
       RPAD(NVL(TRIM(v.amount),' '), 23, ' ') amount,
       RPAD(NVL(TRIM(v.payment_method),' '), 3, ' ') payment_method,
       RPAD(NVL(TRIM(v.payment_sub_method),' '), 2, ' ') payment_sub_method,
       RPAD(NVL(TRIM(v.reversal_reason),' '), 10, ' ') reversal_reason,
       RPAD(NVL(TRIM(v.check_no),' '), 15, ' ') check_no,
       RPAD(NVL(TRIM(v.credit_card_number),' '), 100, ' ') credit_card_number,
       RPAD(NVL(TRIM(v.payment_source_type),' '), 1, ' ') payment_source_type,
       RPAD(NVL(TRIM(v.payment_source_id),' '), 8, ' ') payment_source_id,
       RPAD(NVL(TRIM(v.bank_account_number),' '), 100, ' ') bank_account_number,
       RPAD(NVL(TRIM(v.payment_id),' '), 12, ' ') payment_id,
       TO_CHAR (TRUNC (v.deposit_date), 'YYYYMMDD') deposit_date,
       TO_CHAR (TRUNC (v.activity_date), 'YYYYMMDD') activity_date,
       RPAD(NVL(TRIM (v.funds_transfer_reason),' '), 10, ' ') funds_transfer_reason
  FROM (SELECT ba.acct_id, fet1_payment_activity.activity_type,
               fet1_payment_activity.reason_code,
               fet1_payment.original_amount, fet1_payment_activity.amount,
               fet1_payment_details.payment_method,
               fet1_payment_details.payment_sub_method,
               fet1_payment_details.reversal_reason,
               fet1_payment_details.check_no,
               fet1_payment_details.credit_card_number,
               fet1_payment_details.payment_source_type,
               fet1_payment_details.payment_source_id,
               fet1_payment_details.bank_account_number,
               fet1_payment.payment_id,
               TRUNC (fet1_payment_details.deposit_date) deposit_date,
               TRUNC (fet1_payment.activity_date) activity_date,
               fet1_payment_activity.funds_transfer_reason
          FROM fet1_account,
               fy_tb_bl_bill_acct ba, fy_tb_BL_bill_CNTRL BC,
               fet1_payment_activity,
               fet1_payment_details,
               fet1_payment
         WHERE ba.bill_seq = ${billSeq}
		   AND ba.bill_seq = bc.bill_seq
		   AND BA.CYCLE = BC.CYCLE
		   AND BA.CYCLE_MONTH = BC.CYCLE_MONTH 
           AND ba.bill_status = 'MA'
           AND ba.bill_seq = fet1_payment_activity.bill_seq_no
           AND ba.acct_id = fet1_account.account_id
		   AND fet1_account.partition_id = fet1_payment_activity.partition_id
           AND fet1_account.account_id = fet1_payment_activity.account_id
           AND fet1_payment.credit_id = fet1_payment_activity.credit_id
           AND fet1_payment_details.payment_id = fet1_payment.payment_id
           AND fet1_payment_activity.activity_type IN ('BCK', 'FTF', 'FNTT')
           AND NVL (fet1_payment_details.payment_sub_method, ' ') != 'DEP'
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
		   ) v