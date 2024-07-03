--SR228930 MERG & RETN 2021/07
--SR228931 MERG & RETN 2021/07
SELECT   --cpln.elem6, a.status, TRIM (cpl.elem5 || cpl.elem1 || cpl.elem2 || cpl.elem3 || cpl.elem4)
        'MERG' DUMMY, 
         a.acct_id BA_NO, 
         a.acct_id ACCT_NO, 
         '1000' SMART_INSERT_FLAG,
         MIN (a.acct_id) OVER (PARTITION BY cpln.elem6 ORDER BY a.acct_id)  WIN_ENVELOPE_ACCT_NO,
         '1000' OLD_SMART_INSERT_FLAG
 FROM fy_tb_cm_account a,
         fy_tb_cm_prof_link cpl,
         fy_tb_cm_prof_link cpln,
         fy_tb_bl_bill_mast m,
         (SELECT  cpln.elem6,
                   TRIM (   cpl.elem5
                         || cpl.elem1
                         || cpl.elem2
                         || cpl.elem3
                         || cpl.elem4
                         || cpl.elem13
                         || cpl.elem14
                        ) address_dept,
                  TRIM (    cpln.elem3
                         || cpln.elem2
                        ) name
              FROM fy_tb_cm_account a, fy_tb_cm_prof_link cpl, fy_tb_cm_prof_link cpln, fy_tb_bl_bill_mast m
             WHERE cpl.entity_type = 'A'
               AND cpl.link_type = 'B'
               AND cpl.prof_type = 'ADDR'
               AND cpl.elem7 IN (0, 1, 5)
               AND cpln.entity_type = 'A'
               AND cpln.link_type = 'B'
               AND cpln.prof_type = 'NAME'
               AND a.status IN ('C', 'O')
               AND a.acct_id = cpl.entity_id
               AND a.acct_id = cpln.entity_id
               AND cpl.entity_id = cpln.entity_id
			   AND a.acct_Id = m.acct_id
			   AND m.bill_seq = ${billSeq}
			   AND m.INVOICE_TYPE in('N','U')
			   AND m.acct_key  = mod(m.acct_id,100)
               AND NOT EXISTS (SELECT 1
                                 FROM fet_tb_bl_bmex_list bmex
                                WHERE a.acct_id = bmex.acct_id)
               AND NOT EXISTS (SELECT 1
                                 FROM fet_tb_bl_retn_list retn
                                WHERE a.acct_id = retn.acct_id)
          GROUP BY cpln.elem6,
                   TRIM (   cpl.elem5
                         || cpl.elem1
                         || cpl.elem2
                         || cpl.elem3
                         || cpl.elem4
                         || cpl.elem13
                         || cpl.elem14
                        ),
                   TRIM (   cpln.elem3
                         || cpln.elem2
                        )
            HAVING COUNT(*) > 1) d
    WHERE cpl.entity_type = 'A'
     AND cpl.link_type = 'B'
     AND cpl.prof_type = 'ADDR'
     AND cpl.elem7 IN (0, 1, 5)
     AND cpln.entity_type = 'A'
     AND cpln.link_type = 'B'
     AND cpln.prof_type = 'NAME'
     AND a.status IN ('C', 'O')
     AND a.acct_id = cpl.entity_id
     AND a.acct_id = cpln.entity_id
     and cpl.entity_id= cpln.entity_id
     AND cpln.elem6 = d.elem6
     AND TRIM (cpl.elem5 || cpl.elem1 || cpl.elem2 || cpl.elem3 || cpl.elem4 || cpl.elem13 || cpl.elem14) = d.address_dept
     AND TRIM (cpln.elem3 || cpln.elem2) = d.name
     and a.acct_Id = m.acct_id
     and m.bill_seq = ${billSeq}
     and m.INVOICE_TYPE in('N','U')
     and m.acct_key  = mod(m.acct_id,100)
     AND NOT EXISTS (SELECT 1
                       FROM fet_tb_bl_bmex_list bmex
                      WHERE a.acct_id = bmex.acct_id)
     AND NOT EXISTS (SELECT 1
                       FROM fet_tb_bl_retn_list retn
                      WHERE a.acct_id = retn.acct_id)
ORDER BY cpln.elem6, a.acct_id