SELECT
'RSVA' Dummy_Field1,
OU.OU_ID Agreement_No,
OU.OFFER_ID SOC,
OU.OFFER_INSTANCE_ID SOC_Seq_No,
TO_CHAR(OU.EFF_DATE,'YYYYMMDD') Effective_Date ,
null Source_Agr_No,
TO_CHAR(OU.END_DATE,'YYYYMMDD') Expiration_Date,
null Dealer_Code,
null Effective_Issue_Date,
null Expiration_Issue_Date,
null SOC_Status,
null SOC_Status_Date,
null SOC_Status_Issue_Date,
null SOC_Status_Last_Act,
OU.OFFER_RSN_CODE SOC_Status_RSN_CD,
OU.TRX_ID,
999999999 Ins_TRX_ID,
null Conv_Run_No,
OU.OFFER_SEQ Source_Agr_SOC_Seq_No,
(SELECT DSCR FROM FY_TB_PBK_OFFER WHERE OFFER_ID=OU.OFFER_ID) Offer_Description,
TO_CHAR(FUTURE_END_DATE,'YYYYMMDD') Ftr_Expiration_Date,
'U' Agreement_Type,
NULL CLOUD_ACCT_NAME, --20190630 AWS
NULL HA_NO, --SR228032 NPEP Phase 2.1
(SELECT OFFER_TYPE FROM FY_TB_PBK_OFFER WHERE OFFER_ID=OU.OFFER_ID) Offer_Type --SR228032 NPEP Phase 2.1
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_ACCT Mast,
     FY_TB_CM_OU_OFFER OU
WHERE
  --'B' = ${procType} 20190630 Fix
  Bc.BILL_SEQ  = ${billSeq}
  AND MAST.BILL_SEQ  = bc.bill_seq
  and mast.cycle     = bc.cycle
  and mast.cycle_month=bc.cycle_month
  and mast.acct_key  = mod(mast.acct_id,100)
  AND ((999 <> ${processNo} AND ACCT_GROUP= ${acctGroup}) OR
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = Mast.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = Mast.ACCT_ID)))
  AND OU.ACCT_ID=Mast.ACCT_ID
  AND Mast.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
UNION
SELECT 'RSVA' Dummy_Field1,
SO.SUBSCR_ID Agreement_No,
SO.OFFER_ID SOC,
SO.OFFER_INSTANCE_ID SOC_Seq_No,
TO_CHAR(SO.EFF_DATE,'YYYYMMDD') Effective_Date ,
SO.OU_OFFER_SEQ Source_Agr_No,
TO_CHAR(SO.END_DATE,'YYYYMMDD')  Expiration_Date,
null Dealer_Code,
null Effective_Issue_Date,
null Expiration_Issue_Date,
CASE nvl(SO.END_DATE,to_date('1000/01/01','yyyy/mm/dd')) WHEN
             to_date('1000/01/01','yyyy/mm/dd') THEN CM.STATUS ELSE 'C' END SOC_Status,
TO_CHAR(CM.STATUS_DATE,'YYYYMMDD') SOC_Status_Date,
null SOC_Status_Issue_Date,
null SOC_Status_Last_Act,
SO.OFFER_RSN_CODE SOC_Status_RSN_CD,
SO.TRX_ID,
999999999 Ins_TRX_ID,
null Conv_Run_No,
SO.OFFER_SEQ Source_Agr_SOC_Seq_No,
(SELECT DSCR FROM FY_TB_PBK_OFFER WHERE OFFER_ID=SO.OFFER_ID) Offer_Description,
TO_CHAR(FUTURE_END_DATE,'YYYYMMDD') Ftr_Expiration_Date,
'S' Agreement_Type,
CMOP.PARAM_VALUE CLOUD_ACCT_NAME,
CMHA.PARAM_VALUE HA_NO, --SR228032 NPEP Phase 2.1
(SELECT OFFER_TYPE FROM FY_TB_PBK_OFFER WHERE OFFER_ID=SO.OFFER_ID) Offer_Type --SR228032 NPEP Phase 2.1
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_SUB Mast,
     FY_TB_CM_SUBSCR_OFFER SO,
     FY_TB_CM_SUBSCR CM,
   (select subscr_ID,OFFER_SEQ, ACCT_ID, PARAM_VALUE from fy_Tb_cm_offer_param where PARAM_NAME='AWSname' or PARAM_NAME='NAME') CMOP, --20190630 AWS
   (select subscr_ID,OFFER_SEQ, ACCT_ID, PARAM_VALUE from fy_Tb_cm_offer_param where PARAM_NAME='HANO_BILL') CMHA --SR228032 NPEP Phase 2.1
WHERE --'B' = ${procType} 20190630
  Bc.BILL_SEQ  = ${billSeq}
  AND MAST.BILL_SEQ  = bc.bill_seq
  and mast.cycle     = bc.cycle
  and mast.cycle_month=bc.cycle_month
  and mast.acct_key  = mod(mast.acct_id,100)
  AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = Mast.BILL_SEQ
                                            and cycle     = mast.cycle
                                            and cycle_month=mast.cycle_month
                                            and acct_key  = mast.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = Mast.ACCT_ID)) OR
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = Mast.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = Mast.ACCT_ID)))
  AND SO.SUBSCR_ID = Mast.SUBSCR_ID
  AND CM.subscr_ID = Mast.subscr_ID
  AND CMOP.subscr_ID(+) = Mast.subscr_ID --20190630 AWS
  --and cmop.OFFER_SEQ(+) = so.OFFER_SEQ --20190630 AWS
  --AND CMOP.ACCT_ID(+) = Mast.ACCT_ID --20190630 AWS
  AND CMHA.subscr_ID(+) = Mast.subscr_ID --SR228032 NPEP Phase 2.1
  AND Mast.ACCT_ID BETWEEN ${acctIds} and ${acctIde}