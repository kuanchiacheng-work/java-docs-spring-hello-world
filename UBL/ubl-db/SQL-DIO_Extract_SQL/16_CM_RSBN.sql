SELECT
'RSBN' Dummy_Field2,
S.ACCT_ID, --SR260229_Project-M Fixed line Phase I
S.SUBSCR_ID,
S.STATUS,
S.PRIM_RESOURCE_TP,
S.PRIM_RESOURCE_VAL,
S.SUBSCR_TYPE,
(SELECT  ELEM3||ELEM2 FROM FY_TB_CM_PROF_LINK PL WHERE entity_type='S' AND link_type='S' AND entity_id=SUBSCR_ID AND PROF_TYPE='NAME' 
and PROF_LINK_SEQ =(select max(PROF_LINK_SEQ) from FY_TB_CM_PROF_LINK where entity_type='S' AND entity_id=PL.entity_id AND PROF_TYPE='NAME' )) SUBSCR_NAME,
TO_CHAR(S.INIT_ACT_DATE,'YYYYMMDD') INIT_ACT_DATE,
S.PRIM_RES_PARAM_CD -- SR216803 2019/10
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST MAST,
     FY_TB_CM_SUBSCR S
WHERE 'B' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  AND MAST.BILL_SEQ  = bc.bill_seq
  and MAST.cycle     = bc.cycle
  and MAST.cycle_month=bc.cycle_month
  and MAST.acct_key  = mod(MAST.acct_id,100)
AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
										    and cycle     = MAST.cycle
											and cycle_month=MAST.cycle_month
											and acct_key  = MAST.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = MAST.ACCT_ID)) OR
     (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = MAST.ACCT_ID)))
AND S.ACCT_ID=MAST.ACCT_ID
and (( bc.cycle=50 and bc.create_user='UBL' and s.subscr_type='I') --SR261173 2024/08/08
                   or (mast.cycle <> 50) or ( bc.cycle=50 and bc.create_user <>'UBL' ))
AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT
'RSBN' Dummy_Field2,
S.ACCT_ID, --SR260229_Project-M Fixed line Phase I
S.SUBSCR_ID,
S.STATUS,
S.PRIM_RESOURCE_TP,
S.PRIM_RESOURCE_VAL,
S.SUBSCR_TYPE,
(SELECT  ELEM3||ELEM2 FROM FY_TB_CM_PROF_LINK PL WHERE entity_type='S' AND link_type='S' AND entity_id=SUBSCR_ID AND PROF_TYPE='NAME' 
and PROF_LINK_SEQ =(select max(PROF_LINK_SEQ) from FY_TB_CM_PROF_LINK where entity_type='S' AND entity_id=PL.entity_id AND PROF_TYPE='NAME' )) SUBSCR_NAME,
TO_CHAR(S.INIT_ACT_DATE,'YYYYMMDD') INIT_ACT_DATE,
S.PRIM_RES_PARAM_CD --SR216803 2019/10
FROM fy_tb_bl_bill_cntrl bc, 
     FY_TB_BL_BILL_MAST_TEST MAST,
     FY_TB_CM_SUBSCR S
WHERE 'T' = ${procType}
  AND Bc.BILL_SEQ  = ${billSeq}
  AND MAST.BILL_SEQ  = bc.bill_seq
  and MAST.cycle     = bc.cycle
  and MAST.cycle_month=bc.cycle_month
  and MAST.acct_key  = mod(MAST.acct_id,100)
AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
										    and cycle     = MAST.cycle
											and cycle_month=MAST.cycle_month
											and acct_key  = MAST.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = MAST.ACCT_ID)) OR
     (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = MAST.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = MAST.ACCT_ID)))
AND S.ACCT_ID=MAST.ACCT_ID
and (( bc.cycle=50 and bc.create_user='UBL' and s.subscr_type='I') --SR261173 2024/08/08
                   or (mast.cycle <> 50) or ( bc.cycle=50 and bc.create_user <>'UBL' ))
AND MAST.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
