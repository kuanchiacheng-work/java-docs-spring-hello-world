--SR239378 New Extract For Offer Parameter
SELECT 'CSOP' Dummy_Field1,
sub.ACCT_ID,
sub.SUBSCR_ID,
TO_CHAR(op.EFF_DATE,'YYYYMMDD') EFF_DATE,
TO_CHAR(op.END_DATE,'YYYYMMDD') END_DATE,
so.OFFER_ID,
op.OFFER_INSTANCE_ID,
op.PARAM_NAME,
op.PARAM_VALUE,
op.OFFER_SEQ --SR250171_ESDP Migration Project
FROM fy_tb_bl_bill_cntrl bc,
     FY_TB_BL_BILL_SUB sub,
     FY_TB_CM_OFFER_PARAM op,
     FY_TB_CM_SUBSCR_OFFER so
WHERE 
  bc.BILL_SEQ  = ${billSeq}
  AND sub.BILL_SEQ  = bc.bill_seq
  and sub.cycle     = bc.cycle
  and sub.cycle_month=bc.cycle_month
  and sub.acct_key  = mod(sub.acct_id,100)
  AND ((999 <> ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT
                                          WHERE BILL_SEQ  = sub.BILL_SEQ
                                            and cycle     = sub.cycle
                                            and cycle_month=sub.cycle_month
                                            and acct_key  = sub.acct_key
                                            AND ACCT_GROUP= ${acctGroup}
                                            AND ACCT_ID   = sub.ACCT_ID)) OR
       (999 =  ${processNo} AND EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                          WHERE BILL_SEQ  = sub.BILL_SEQ
                                            AND TYPE      = ${acctGroup}
                                            AND ACCT_ID   = sub.ACCT_ID)))
  AND sub.SUBSCR_ID = op.SUBSCR_ID
  AND sub.SUBSCR_ID = so.SUBSCR_ID
  AND op.SUBSCR_ID = so.SUBSCR_ID
  AND op.OFFER_SEQ = so.OFFER_SEQ
  AND op.OFFER_INSTANCE_ID = so.OFFER_INSTANCE_ID  
  AND sub.ACCT_ID BETWEEN ${acctIds} and ${acctIde}