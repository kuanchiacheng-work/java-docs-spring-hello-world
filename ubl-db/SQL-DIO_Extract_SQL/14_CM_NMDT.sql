SELECT
'NMDT' Dummy_Field1,
P.ENTITY_ID BA_Number,
P.link_type,
P.ELEM2 Name_Line1,
decode(P.link_type,'A',P.ELEM3||P.ELEM2,'B',P.ELEM3||P.ELEM2,null) Name_Line2,
P.ELEM1 Name_Element1,
P.ELEM2 Name_Element2,
P.ELEM3 Name_Element3,
P.ELEM4 Name_Element4,
P.ELEM5 Name_Element5,
P.ELEM6 Name_Element6
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST MAST,
     FY_TB_CM_PROF_LINK P
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
                                            AND ACCT_ID   = MAST.ACCT_ID)) OR
     (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = MAST.ACCT_ID)))
AND P.entity_type='A'
AND P.entity_id=MAST.ACCT_ID
AND P.prof_type='NAME'
AND P.Link_Type IN ('A','B')
AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT
'NMDT' Dummy_Field1,
P.ENTITY_ID BA_Number,
P.link_type,
P.ELEM2 Name_Line1,
decode(P.link_type,'A',P.ELEM3||P.ELEM2,'B',P.ELEM3||P.ELEM2,null) Name_Line2,
P.ELEM1 Name_Element1,
P.ELEM2 Name_Element2,
P.ELEM3 Name_Element3,
P.ELEM4 Name_Element4,
P.ELEM5 Name_Element5,
P.ELEM6 Name_Element6
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST_TEST MAST,
     FY_TB_CM_PROF_LINK P
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
                                            AND ACCT_ID   = MAST.ACCT_ID)) OR
     (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = MAST.ACCT_ID)))
AND P.entity_type='A'
AND P.entity_id=MAST.ACCT_ID
AND P.prof_type='NAME'
AND P.Link_Type IN ('A','B')
AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
