SELECT 'PARF' parf, RPAD (TRIM (ba.acct_id), 12, ' ') billing_arrangement_id,
       RPAD (TRIM (ba.acct_id), 12, ' ') cm_pay_channel_id,
       TO_CHAR (TRUNC (fet1_refund_request.activity_date),
                'YYYYMMDD'
               ) activity_date,
       RPAD (TRIM (fet1_refund_request.amount), 23, ' ') amount,
       RPAD (TRIM (fet1_refund_request.reversal_date), 8, ' ') reversal_date,
       RPAD (TRIM (fet1_refund_request.reversal_reason),
             10,
             ' '
            ) reversal_reason
  FROM fy_tb_bl_bill_acct ba,fy_tb_BL_bill_CNTRL BC,
       fet1_payment_activity,
       fet1_refund_request,
       fet1_account,
       fet1_payment
 WHERE ba.bill_seq =  ${billSeq}
   AND ba.bill_seq = bc.bill_seq
   AND BA.CYCLE = BC.CYCLE
   AND BA.CYCLE_MONTH = BC.CYCLE_MONTH 
   AND ba.bill_status = 'MA'
   AND ba.bill_seq = fet1_payment_activity.bill_seq_no
   AND ba.acct_id = fet1_account.account_id
   AND fet1_account.partition_id = fet1_refund_request.partition_id
   AND fet1_account.account_id = fet1_refund_request.account_id
   AND fet1_refund_request.credit_id = fet1_payment.credit_id
   AND fet1_payment.credit_id = fet1_payment_activity.credit_id
   AND fet1_refund_request.reversal_trans_id = fet1_payment_activity.transaction_id
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