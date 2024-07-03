
SELECT 'BCFG' DUMMY,REVENUE_CODE CODE_TYPE, CHARGE_CODE CODE, 'L' SUBSCRIBER_TYPE, 'Net' AMOUNT_TYPE, '' RC_VOLUME, '' EXTRA_VOLUME, UNIT, BILL_CATEGORY BILL_CATEGORY,                              
'' PRIORITY, 'N' REPLACE_FLAG, DSCR DESCRIPTION, '' OTHER_CHRG_FLAG                                                                                                                                     
FROM FY_TB_PBK_CHARGE_CODE                                                                                                                                                                              
UNION                                                                                                                                                                                                   
SELECT 'BCFG' DUMMY,REVENUE_CODE CODE_TYPE, CHARGE_CODE CODE, 'G' SUBSCRIBER_TYPE, 'Gross' AMOUNT_TYPE, '' RC_VOLUME, '' EXTRA_VOLUME, UNIT, BILL_CATEGORY BILL_CATEGORY,                            
'' PRIORITY, 'N' REPLACE_FLAG, DSCR DESCRIPTION, '' OTHER_CHRG_FLAG                                                                                                                                     
FROM FY_TB_PBK_CHARGE_CODE                                                                                                                                                                              
                                                                                                                                                                                                        
                                                                                                                                                                                                        

