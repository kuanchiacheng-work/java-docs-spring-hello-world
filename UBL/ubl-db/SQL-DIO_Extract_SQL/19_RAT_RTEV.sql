SELECT
    'RTEV' Entity_Name,
    --A.subscr_id Subscriber_ID,
    NVL(RTOP.PARAM_VALUE,   A.subscr_id) Subscriber_ID, --5G PN BSS project.
    TO_CHAR(A.start_time,'YYYY-MM-DD HH24:MI:SS') Network_start_time,
    A.acct_id Billing_arrangement,
    A.resource_value Calling_number,
    A.b_party Called_number,
    A.service_filter Service_filter ,
    NULL Call_forward_ind,
    A.provider_id Provider_ID,
    A.chrg_amt Charge_amount,
    A.b_party APN,
    TO_NUMBER(DECODE(service_Identifier,'6',NULL,A.qty)) Original_quantity_1,          --SR228032 NPEP Phase 2.1
    NULL Original_UOM_1 ,
    TO_NUMBER(DECODE(service_Identifier,'6',NULL,A.ROUNDED_QTY)) Original_quantity_2,    --SR228032 NPEP Phase 2.1
    NULL Event_type_ID,
    A.chrg_amt Charge_allowance,
    NULL Friends_and_family_number_ind ,
    A.period_type Period_Name ,
    A.charge_code Charge_code,
    A.cet CET_name,
    A.dis_amt  Discount_amount,
    NULL Product_ID,
    DECODE(A.ROUNDING_UOM,'K',1024,'M',1024*1024,'G',1024*1024*1024,1)*A.rounding_factor UoM_block2,
    'POST' Payment_Category,
    NULL Session_ID,
    NULL Rating_Group,
    NULL QoS,
    NULL Ofc_roaming_ind,
    NULL Subscriber_type,
    A.offer_id  Offer_ID ,
    A.End_Time, --SR228032 NPEP Phase 2.1
	A.offer_seq, --SR250171_ESDP Migration Project
	A.chrg_memo --SR250171_ESDP Migration Project
    FROM FY_TB_BL_BILL_CNTRL bc,
         FY_TB_BL_BILL_ACCT Mast,
         FY_TB_RAT_CDR A,
         (select subscr_ID,OFFER_SEQ, ACCT_ID, PARAM_VALUE from fy_Tb_rat_offer_param where PARAM_NAME='BILL_SUBSCR_ID') RTOP
    WHERE bc.cycle <> 50 and bc.create_user='UBL'
      and Bc.BILL_SEQ  = ${billSeq}
      --AND 'B' = ${procType} --20190630
      AND MAST.BILL_SEQ  = bc.bill_seq
      and mast.cycle     = bc.cycle
      and mast.cycle_month=bc.cycle_month
      AND RTOP.ACCT_ID(+) = A.ACCT_ID --SR235856_5G PN BSS project.
      AND RTOP.SUBSCR_ID(+) = A.subscr_ID --SR235856_5G PN BSS project.
      and mast.acct_key  = mod(mast.acct_id,100)
      AND ((999 <> ${processNo} AND ACCT_GROUP= ${acctGroup}) OR
           (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                              WHERE BILL_SEQ  = Mast.BILL_SEQ
                                                AND TYPE      = ${acctGroup}
                                                AND ACCT_ID   = Mast.ACCT_ID)))
      AND A.ACCT_ID     = Mast.ACCT_ID
      AND A.bill_period = bc.BILL_PERIOD
      AND A.CYCLE       = mast.CYCLE
      AND A.CYCLE_MONTH = mast.CYCLE_MONTH
      and a.acct_key    = mast.acct_key
      AND Mast.ACCT_ID BETWEEN ${acctIds} and ${acctIde} --SR261173 2024/04/22
    UNION
SELECT 'RTEV' Entity_Name,
    --A.subscr_id Subscriber_ID,
    NVL(RTOP.PARAM_VALUE,   A.subscr_id) Subscriber_ID, --5G PN BSS project.
    decode(A.provider_id,'F',TO_CHAR(A.start_time,'YYYY-MM')||'-01 00:00:00',TO_CHAR(A.start_time,'YYYY-MM-DD')||' 00:00:00') Network_start_time,
    A.acct_id Billing_arrangement,
    A.resource_value Calling_number,
    A.b_party Called_number,
    A.service_filter Service_filter ,
    NULL Call_forward_ind,
    A.provider_id Provider_ID,
    --SUM(round(A.chrg_amt,2)) AS Total_charge_amount,
	round(SUM(A.chrg_amt),2) Charge_amount,
    A.b_party APN,
    sum(DECODE(service_Identifier,'6',NULL,A.qty)) Original_quantity_1,
    NULL Original_UOM_1 ,
    sum(DECODE(service_Identifier,'6',NULL,A.ROUNDED_QTY )) Original_quantity_2,
    NULL Event_type_ID,
    --sum(round(A.chrg_amt,2)) Charge_allowance,
    round(SUM(A.chrg_amt),2) Charge_allowance,
    NULL Friends_and_family_number_ind ,
    A.period_type Period_Name ,
    A.charge_code Charge_code,
    A.cet CET_name,
    --sum(round(A.dis_amt,2))  Discount_amount,
	round(SUM(A.chrg_amt),2)  Discount_amount,
    NULL Product_ID,
    DECODE(A.ROUNDING_UOM,'K',1024,'M',1024*1024,'G',1024*1024*1024,1)*A.rounding_factor UoM_block2,
    'POST' Payment_Category,
    NULL Session_ID,
    NULL Rating_Group,
    NULL QoS,
    NULL Ofc_roaming_ind,
    NULL Subscriber_type,
    A.offer_id  Offer_ID ,
    max(A.End_Time),
 A.offer_seq,
 A.chrg_memo
    FROM FY_TB_BL_BILL_CNTRL bc,
         FY_TB_BL_BILL_ACCT Mast,
         FY_TB_RAT_CDR A,
         (select subscr_ID,OFFER_SEQ, ACCT_ID, PARAM_VALUE from fy_Tb_rat_offer_param where PARAM_NAME='BILL_SUBSCR_ID') RTOP
    WHERE bc.cycle=50 and bc.create_user='UBL'
      and Bc.BILL_SEQ  = ${billSeq}
      --AND 'B' = ${procType} --20190630
      AND MAST.BILL_SEQ  = bc.bill_seq
      and mast.cycle     = bc.cycle
      and mast.cycle_month=bc.cycle_month
      AND RTOP.ACCT_ID(+) = A.ACCT_ID --SR235856_5G PN BSS project.
      AND RTOP.SUBSCR_ID(+) = A.subscr_ID --SR235856_5G PN BSS project.
      and mast.acct_key  = mod(mast.acct_id,100)
      AND ((999 <> ${processNo} AND ACCT_GROUP= ${acctGroup}) OR
           (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                              WHERE BILL_SEQ  = Mast.BILL_SEQ
                                                AND TYPE      = ${acctGroup}
                                                AND ACCT_ID   = Mast.ACCT_ID)))
      AND A.ACCT_ID     = Mast.ACCT_ID
      AND A.bill_period = bc.BILL_PERIOD
      AND A.CYCLE       = mast.CYCLE
      AND A.CYCLE_MONTH = mast.CYCLE_MONTH
      and a.acct_key    = mast.acct_key
	  AND Mast.ACCT_ID BETWEEN ${acctIds} and ${acctIde}
GROUP BY NVL(RTOP.PARAM_VALUE,   A.subscr_id),decode(A.provider_id,'F',TO_CHAR(A.start_time,'YYYY-MM')||'-01 00:00:00',TO_CHAR(A.start_time,'YYYY-MM-DD')||' 00:00:00'),A.acct_id,A.resource_value,A.b_party,
A.period_type,A.cet,DECODE(A.ROUNDING_UOM,'K',1024,'M',1024*1024,'G',1024*1024*1024,1)*A.rounding_factor,
A.Service_filter, A.Provider_ID, 
A.Charge_code, A.Offer_ID, A.End_Time, A.offer_seq, A.chrg_memo
