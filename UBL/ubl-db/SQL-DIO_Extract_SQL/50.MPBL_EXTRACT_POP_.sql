SELECT DISTINCT BA.acct_id
FROM fy_tb_bl_bill_acct BA, fy_tb_BL_bill_CNTRL BC
WHERE BA.bill_seq = ${billSeq}
AND ba.bill_seq = bc.bill_seq
AND BA.CYCLE = BC.CYCLE
AND BA.CYCLE_MONTH = BC.CYCLE_MONTH
AND BA.bill_status = 'MA'
AND 999 <> ${processNo}
AND (   ( 'B' = ${procType} AND 
          BA.bill_status = ${billStatus})
     OR 
        ( 'T' = ${procType} AND
          BA.bill_status <> 'CN' AND
          NOT EXISTS (
                      SELECT 1
                      FROM fy_tb_bl_bill_process_err
                      WHERE bill_seq = BA.bill_seq
                      AND process_no = ${processNo}
                      AND acct_group = BA.acct_group
                      AND proc_type  = ${procType}
                      AND acct_id    = BA.acct_id)
        )
     )
AND BA.acct_id BETWEEN ${acctIds} AND ${acctIde}