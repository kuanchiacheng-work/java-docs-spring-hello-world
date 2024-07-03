SELECT
'ADDT' Dummy_Field,
P.ENTITY_ID,
DECODE(P.link_type,'O','A',P.link_type),
P.ELEM5||P.ELEM1||P.ELEM2||P.ELEM3||P.ELEM4 Address_Line1,
P.ELEM11||P.ELEM7||P.ELEM8||P.ELEM9||P.ELEM10 Address_Line2,
P.ELEM13||P.ELEM14 Address_Line3,
'' Address_Line4,
P.ELEM1 Address_Element1,
P.ELEM2 Address_Element2,
P.ELEM3 Address_Element3,
P.ELEM4 Address_Element4,
P.ELEM5 Address_Element5,
P.ELEM6 Address_Element6,
decode(P.link_type,'B',P.ELEM7,null) Address_Element7,
decode(P.link_type,'B',P.ELEM8,null) Address_Element8,
decode(P.link_type,'B',P.ELEM9,null) Address_Element9,
decode(P.link_type,'O',P.ELEM10,null) Address_Element10,
decode(P.link_type,'B',P.ELEM11,null) Address_Element11,
P.ELEM12 Address_Element12,
P.ELEM13 Address_Element13,
P.ELEM14 Address_Element14,
P.ELEM15 Address_Element15
FROM fy_tb_bl_bill_cntrl bc,
     fy_tB_BL_BILL_MAST MAST,
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
AND P.entity_id = MAST.acct_id
AND P.prof_type='ADDR'
AND P.Link_Type IN ('O','B')
AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT
'ADDT' Dummy_Field,
P.ENTITY_ID,
DECODE(P.link_type,'O','A',P.link_type),
P.ELEM5||P.ELEM1||P.ELEM2||P.ELEM3||P.ELEM4 Address_Line1,
P.ELEM11||P.ELEM7||P.ELEM8||P.ELEM9||P.ELEM10 Address_Line2,
P.ELEM13||P.ELEM14 Address_Line3,
'' Address_Line4,
P.ELEM1 Address_Element1,
P.ELEM2 Address_Element2,
P.ELEM3 Address_Element3,
P.ELEM4 Address_Element4,
P.ELEM5 Address_Element5,
P.ELEM6 Address_Element6,
decode(P.link_type,'B',P.ELEM7,null) Address_Element7,
decode(P.link_type,'B',P.ELEM8,null) Address_Element8,
decode(P.link_type,'B',P.ELEM9,null) Address_Element9,
decode(P.link_type,'O',P.ELEM10,null) Address_Element10,
decode(P.link_type,'B',P.ELEM11,null) Address_Element11,
P.ELEM12 Address_Element12,
P.ELEM13 Address_Element13,
P.ELEM14 Address_Element14,
P.ELEM15 Address_Element15
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
AND P.entity_id = MAST.acct_id
AND P.prof_type='ADDR'
AND P.Link_Type IN ('O','B')
AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}