SELECT 
'OUOF' DUMMY, 
OU.ACCT_ID, 
OU.OU_ID, 
OU.OFFER_ID, 
OU.OFFER_INSTANCE_ID,
CASE nvl(OU.end_date,to_date('1000/01/01','yyyy/mm/dd')) WHEN 
to_date('1000/01/01','yyyy/mm/dd') THEN 'A' ELSE 'C' END SOC_STATUS,
'U' AGREEMENT_TYPE, 
TO_CHAR(OU.EFF_DATE,'YYYYMMDD') EFF_DATE,  
TO_CHAR(OU.END_DATE, 'YYYYMMDD') END_DATE,
TO_CHAR(OU.FUTURE_END_DATE, 'YYYYMMDD') FUTURE_END_DATE, 
TO_CHAR(nvl(OU.END_DATE,OU.EFF_DATE), 'YYYYMMDD') SOC_STATUS_DATE,
OU.OU_ID, 
OU.OFFER_RSN_CODE
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST Mast,
     FY_TB_CM_OU_OFFER OU
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
  AND OU.ACCT_ID=Mast.ACCT_ID                                             
  AND Mast.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT 
'OUOF' DUMMY, 
OU.ACCT_ID, 
OU.OU_ID, 
OU.OFFER_ID, 
OU.OFFER_INSTANCE_ID,
CASE nvl(OU.end_date,to_date('1000/01/01','yyyy/mm/dd')) WHEN 
to_date('1000/01/01','yyyy/mm/dd') THEN 'A' ELSE 'C' END SOC_STATUS,
'U' AGREEMENT_TYPE, 
TO_CHAR(OU.EFF_DATE,'YYYYMMDD') EFF_DATE,  
TO_CHAR(OU.END_DATE, 'YYYYMMDD') END_DATE,
TO_CHAR(OU.FUTURE_END_DATE, 'YYYYMMDD') FUTURE_END_DATE, 
TO_CHAR(nvl(OU.END_DATE,OU.EFF_DATE), 'YYYYMMDD') SOC_STATUS_DATE,
OU.OU_ID, 
OU.OFFER_RSN_CODE
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_MAST_TEST Mast,
     FY_TB_CM_OU_OFFER OU
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
  AND OU.ACCT_ID=Mast.ACCT_ID                                             
  AND Mast.ACCT_ID BETWEEN ${acctIds} and ${acctIde}