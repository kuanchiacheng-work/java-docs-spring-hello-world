SELECT RPAD ('CHRG', 4, ' ') chrg,
       RPAD (TRIM (bi.bi_seq), 12, ' ') charge_seq_no,
       RPAD (TRIM (bi.correct_seq), 5, ' ') charge_correction_seq_no,
       RPAD (TRIM (mast.mast_seq), 9, ' ') state_seq_no,
       RPAD (TRIM (mast.mast_seq), 9, ' ') invoice_seq_no,
       RPAD ('0', 9, ' ') tax_seq_no,
       RPAD (TRIM (bi.amount), 11, ' ') billing_amount,
       RPAD (TRIM (bi.bill_currency), 3, ' ') billing_currency,
       RPAD (' ', 8, ' ') amount_exchange_date,
       RPAD (TRIM (bi.amount), 15, ' ') customer_amount,
       RPAD (TRIM (bi.bill_currency), 3, ' ') customer_currency,
       RPAD (TRIM (ba.acct_id), 12, ' ') ba_no,
       RPAD (TRIM (ba.acct_id), 12, ' ') pay_channel_no,
       RPAD (TRIM (bi.charge_type), 3, ' ') charge_type,
       RPAD (TRIM (bi.charge_code), 15, ' ') charge_code,
       RPAD (TRIM (f.cet), 15, ' ') charge_ent_type,
       --RPAD ('OC', 2, ' ') revenue_code,--unmark 2020/7/14
       RPAD (f.REVENUE_CODE, 2, ' ') revenue_code,
       RPAD (TRIM (bi.tax_type), 6, ' ') tax_code,
       RPAD ('B', 6, ' ') invoice_type,
       RPAD (TRIM (bi.charge_code), 20, ' ') MESSAGE_CODE,
       TO_CHAR (TRUNC (bi.chrg_date), 'YYYYMMDD') effective_date,
       RPAD (TRIM (bi.service_receiver_type), 1, ' ') service_receiver_type,
       RPAD (TRIM (bi.subscr_id), 12, ' ') service_receiver_id,
       RPAD (TRIM (ba.cust_id), 12, ' ') receiver_customer,
       RPAD (NVL(TRIM (bi.offer_id),' '), 15, ' ') offer,
       RPAD (NVL(TRIM (bi.offer_seq),' '), 9, ' ') offer_instance,
       RPAD (' ', 15, ' ') offer_item,
       RPAD (TRIM (bi.charge_org), 2, ' ') charge_origin,
       RPAD (TRIM (bbam.CYCLE), 4, ' ') cycle_code,
       RPAD (TRIM (bbam.cycle_month), 2, ' ') cycle_month,
       RPAD (TRIM (SUBSTR (bbam.bill_period, 1, 4)), 4, ' ') cycle_year,
       RPAD (TRIM (bi.dynamic_attribute), 4000, ' ') dynamic_attribute
  FROM fy_tb_bl_bill_acct ba,
       fy_tb_bl_bill_bi bi,
       fy_tb_bl_bill_mast mast,
       fy_tb_bl_bill_cntrl bbam,
       fy_tb_pbk_charge_code f
 WHERE ba.bill_seq = ${billSeq}
   AND ba.bill_status = 'MA'
   AND ba.bill_seq = bi.bill_seq
   AND ba.bill_seq = mast.bill_seq
   and ba.bill_seq = bbam.bill_seq -- add by sharon
   and ba.cycle = bi.CYCLE
   and ba.cycle = mast.CYCLE
   and ba.cycle = bbam.CYCLE
   and ba.cycle_month = bi.CYCLE_month
   and ba.cycle_month = mast.CYCLE_month
   and ba.cycle_month = bbam.CYCLE_month
   AND ba.acct_key = bi.acct_key
   AND ba.acct_key = mast.acct_key
   AND ba.acct_id = bi.acct_id
   AND ba.acct_id = mast.acct_id
   AND bi.charge_org in( 'CC' , 'DE') --20200720
   AND bi.charge_type in('DBT','DSC') --20200720
   AND f.charge_code = TRIM (bi.charge_code)
   AND 'B' = ${procType}
   AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG AP WHERE AP.PREPAYMENT IS NULL and AP.OFFER_LEVEL_ID = bi.SUBSCR_ID and AP.OFFER_ID = bi.OFFER_ID and AP.ACCT_ID = bi.acct_id and AP.ACCT_KEY = bi.acct_key ) --20210823
   and ba.acct_key   =mod(ba.acct_id,100)
   AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR
        (999 =  ${processNo} AND EXISTS
                               (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                WHERE BILL_SEQ = BA.BILL_SEQ
                                AND TYPE = BA.ACCT_GROUP
                                AND ACCT_ID = BA.ACCT_ID)))
   AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT RPAD ('CHRG', 4, ' ') chrg,
       RPAD (TRIM (max(bi.bi_seq)), 12, ' ') charge_seq_no,						--20210823
       RPAD (TRIM (max(bi.correct_seq)), 5, ' ') charge_correction_seq_no,		--20210823
       RPAD (TRIM (max(mast.mast_seq)), 9, ' ') state_seq_no,					--20210823
       RPAD (TRIM (max(mast.mast_seq)), 9, ' ') invoice_seq_no,					--20210823
       RPAD ('0', 9, ' ') tax_seq_no,
       RPAD (TRIM (sum(bi.amount)), 11, ' ') billing_amount,					--20210823
       RPAD (TRIM (bi.bill_currency), 3, ' ') billing_currency,
       RPAD (' ', 8, ' ') amount_exchange_date,
       RPAD (TRIM (sum(bi.amount)), 15, ' ') customer_amount,					--20210823
       RPAD (TRIM (bi.bill_currency), 3, ' ') customer_currency,
       RPAD (TRIM (ba.acct_id), 12, ' ') ba_no,
       RPAD (TRIM (ba.acct_id), 12, ' ') pay_channel_no,
       RPAD (TRIM (bi.charge_type), 3, ' ') charge_type,
       RPAD (TRIM ('DE00000'), 15, ' ') charge_code,  							--20210823
       RPAD (TRIM ('DE_CET'), 15, ' ') charge_ent_type, 						--20210823
       --RPAD ('OC', 2, ' ') revenue_code,--unmark 2020/7/14
       RPAD ('DE', 2, ' ') revenue_code, 										--20210823
       RPAD (TRIM (bi.tax_type), 6, ' ') tax_code,
       RPAD ('B', 6, ' ') invoice_type,
       RPAD (TRIM ('DE00000'), 20, ' ') MESSAGE_CODE,							--20210823
       MAX(TO_CHAR (TRUNC (bi.chrg_date), 'YYYYMMDD')) effective_date,
       RPAD (TRIM (bi.service_receiver_type), 1, ' ') service_receiver_type,
       RPAD (TRIM (bi.subscr_id), 12, ' ') service_receiver_id,
       RPAD (TRIM (ba.cust_id), 12, ' ') receiver_customer,
       RPAD (NVL(TRIM (bi.offer_id),' '), 15, ' ') offer,
       max(RPAD (NVL(TRIM (bi.offer_seq),' '), 9, ' ')) offer_instance,
       RPAD (' ', 15, ' ') offer_item,
       RPAD (TRIM (bi.charge_org), 2, ' ') charge_origin,
       RPAD (TRIM (bbam.CYCLE), 4, ' ') cycle_code,
       RPAD (TRIM (bbam.cycle_month), 2, ' ') cycle_month,
       RPAD (TRIM (SUBSTR (bbam.bill_period, 1, 4)), 4, ' ') cycle_year,
       max(RPAD (TRIM (bi.dynamic_attribute), 4000, ' ')) dynamic_attribute
FROM fy_tb_bl_bill_acct ba,
       fy_tb_bl_bill_bi bi,
       fy_tb_bl_bill_mast mast,
       fy_tb_bl_bill_cntrl bbam,
       fy_tb_pbk_charge_code f
 WHERE ba.bill_seq = ${billSeq}
   AND ba.bill_status = 'MA'
   AND ba.bill_seq = bi.bill_seq
   AND ba.bill_seq = mast.bill_seq
   and ba.bill_seq = bbam.bill_seq -- add by sharon
   and ba.cycle = bi.CYCLE
   and ba.cycle = mast.CYCLE
   and ba.cycle = bbam.CYCLE
   and ba.cycle_month = bi.CYCLE_month
   and ba.cycle_month = mast.CYCLE_month
   and ba.cycle_month = bbam.CYCLE_month
   AND ba.acct_key = bi.acct_key
   AND ba.acct_key = mast.acct_key
   AND ba.acct_id = bi.acct_id
   AND ba.acct_id = mast.acct_id
   AND bi.charge_org in( 'DE')  --20210823
   AND bi.charge_type in('DSC') --20210823
   AND f.charge_code = TRIM (bi.charge_code)
   AND 'B' = ${procType}
   AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_PKG AP WHERE AP.PREPAYMENT IS NOT NULL and AP.OFFER_LEVEL_ID = bi.SUBSCR_ID and AP.OFFER_ID = bi.OFFER_ID and AP.ACCT_ID = bi.acct_id and AP.ACCT_KEY = bi.acct_key ) --20210823
   and ba.acct_key   =mod(ba.acct_id,100)
   AND ((999 <> ${processNo} AND BA.ACCT_GROUP = ${acctGroup}) OR
        (999 =  ${processNo} AND EXISTS
                               (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                WHERE BILL_SEQ = BA.BILL_SEQ
                                AND TYPE = BA.ACCT_GROUP
                                AND ACCT_ID = BA.ACCT_ID)))
   AND BA.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
GROUP BY ba.cust_id,ba.acct_id,bi.subscr_id, bi.offer_id, bi.bill_currency, bi.charge_type,
   bi.tax_type,bi.service_receiver_type,bi.charge_org,bbam.CYCLE,bbam.cycle_month,bbam.bill_period