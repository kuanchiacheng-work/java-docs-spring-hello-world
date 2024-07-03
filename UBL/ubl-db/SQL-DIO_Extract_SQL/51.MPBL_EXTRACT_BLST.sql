SELECT 'BLST' blst, RPAD (TRIM (mast.mast_seq), 9, ' ') state_seq_no,
       RPAD (' ', 12, ' ') document_seq_no,
       RPAD (TRIM (ba.acct_id), 12, ' ') ba_no,
       RPAD (TRIM (ba.acct_id), 12, ' ') pay_channel_no,
       TO_CHAR (TRUNC (mast.update_date), 'YYYYMMDD') statement_date,
       RPAD (TRIM (mast.bill_nbr), 60, ' ') legal_invoice_no,
       TO_CHAR (TRUNC (mast.due_date), 'YYYYMMDD') due_date,
       RPAD (TRIM (mast.last_amt), 13, ' ') prev_balance_amt,
       RPAD (TRIM (mast.tot_amt), 13, ' ') total_amt_due,
       RPAD (TRIM (mast.payment_method), 3, ' ') payment_method,
       RPAD (TRIM (mast.paid_amt), 13, ' ') total_finance_act,
       RPAD (TRIM (mast.org_tax_amt), 13, ' ') tax_total_inv_amt,
       RPAD (TRIM (mast.mast_seq), 9, ' ') invoice_seq_no,
       RPAD (TRIM (mast.chrg_amt), 13, ' ') total_invoice_amt
  FROM fy_tb_bl_bill_mast mast,
       fy_tb_bl_bill_acct ba
 WHERE ba.bill_seq = ${billSeq}
   AND ba.bill_status = 'MA'
   AND ba.bill_seq = mast.bill_seq
   AND ba.acct_key = mast.acct_key
   AND ba.acct_id = mast.acct_id
   AND ba.cycle = mast.cycle
   AND ba.cycle_month = mast.cycle_month  
   AND 'B' = ${procType}
   AND ba.acct_key  = mod(ba.acct_id,100)
   AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR 
        (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                         WHERE BILL_SEQ = BA.BILL_SEQ
                                         AND TYPE = ${acctGroup}
                                         AND ACCT_ID = BA.ACCT_ID)))
   AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}  