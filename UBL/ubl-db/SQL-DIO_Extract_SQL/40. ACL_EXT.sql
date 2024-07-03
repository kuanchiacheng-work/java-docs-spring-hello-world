SELECT   AT.acct_id, AT.bill_seq, 
         TO_CHAR (cn.bill_date, 'YYYYMMDD') bill_date,
         TO_CHAR (cn.bill_from_date, 'YYYYMMDD') bill_from_date,
         TO_CHAR (cn.bill_end_date, 'YYYYMMDD') bill_end_date, 
         '110154' be, 
		 AT.ACCT_CATEGORY sub_be
    FROM fy_tb_bl_bill_cntrl cn,
	     fy_tb_bl_bill_acct AT
   WHERE cn.bill_seq = ${billSeq}
     and at.bill_seq = cn.bill_seq
	 and at.cycle    = cn.cycle
	 and at.cycle_month=cn.cycle_month
	 and at.acct_key = mod(at.acct_id,100)
     AND AT.acct_group = ${acctGroup}
     AND 999 <> ${processNo}
     AND (   ('B' = ${procType} AND AT.bill_status = ${billStatus})
          OR (    'T' = ${procType}
              AND AT.bill_status <> 'CN'
              AND NOT EXISTS (
                     SELECT 1
                       FROM fy_tb_bl_bill_process_err
                      WHERE bill_seq = AT.bill_seq
                        AND process_no = ${processNo}
                        AND acct_group = AT.acct_group
                        AND proc_type = ${procType}
                        AND acct_id = AT.acct_id)
             )
         )
     AND AT.acct_id BETWEEN ${acctIds} AND ${acctIde}
UNION
SELECT  AT.acct_id, AT.bill_seq, 
        TO_CHAR (cn.bill_date, 'YYYYMMDD'),
        TO_CHAR (cn.bill_from_date, 'YYYYMMDD') bill_from_date,
        TO_CHAR (cn.bill_end_date, 'YYYYMMDD') bill_end_date, 
         '110154' be, 
		 AT.ACCT_CATEGORY sub_be
    FROM fy_tb_bl_bill_cntrl cn,
	     fy_tb_bl_acct_list al, 
	     fy_tb_bl_bill_acct AT
   WHERE cn.bill_seq = ${billSeq}
	 and al.bill_seq = cn.bill_seq
     AND al.TYPE = ${acctGroup}
	 and at.bill_seq = cn.bill_seq
	 and at.cycle    = cn.cycle
	 and at.cycle_month=cn.cycle_month
	 and at.acct_key = mod(al.acct_id,100)
     AND AT.acct_id = al.acct_id
     AND 999 = ${processNo}
     AND (   ('B' = ${procType} AND AT.bill_status = ${billStatus})
          OR (    'T' = ${procType}
              AND AT.bill_status <> 'CN'
              AND NOT EXISTS (
                     SELECT 1
                       FROM fy_tb_bl_bill_process_err
                      WHERE bill_seq = al.bill_seq
                        AND process_no = 999
                        AND acct_group = al.TYPE
                        AND proc_type = ${procType}
                        AND acct_id = al.acct_id)
             )
         )
     AND Al.acct_id   BETWEEN ${acctIds} AND ${acctIde}
ORDER BY acct_id