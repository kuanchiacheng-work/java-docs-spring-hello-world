#!/usr/bin/env bash
########################################################################################
# Program name : SR259699_ESDP_FSS_RPT_Non-monthlyPayment_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2023/02/24 Create by Mike Kuan
# Description : SR259699_ESDP Migration非月繳續約報表
########################################################################################
# Date : 2023/04/18 Modify by Mike Kuan
# Description : SR260229_Project-M Fixed line Phase I_新增CYCLE(15,20)
########################################################################################
# Date : 2025/04/02 Modify by Mike Kuan
# Description : SR273784_Project M Fixed Line Phase II 整合專案，新增reportFileName2
########################################################################################

export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
progName=$(basename $0 .sh)
sysdt=`date +%Y%m%d%H%M%S`
sysd=`date +%Y%m --date="-1 month"`
HomeDir=/extsoft/UBL/BL
WorkDir=$HomeDir/Surrounding/RPT
ReportDir=$WorkDir/report
ReportDirBak=$ReportDir/bak
LogDir=$WorkDir/log
logFile=$LogDir/${progName}_${sysdt}.log
tempFile=$LogDir/${progName}_tmp_${sysdt}.log
reportFileName="FSS_RPT_Non-monthlyPayment_`date +%Y%m --date="-0 month"`_`date +%Y%m%d%H%M%S`"
reportFileName2="APT_FSS_RPT_Non-monthlyPayment_`date +%Y%m --date="-0 month"`_`date +%Y%m%d%H%M%S`"
utilDir=/cb/BCM/util
ftpProg=${utilDir}/Ftp2Remote.sh
#mailList="keroh@fareastone.com.tw mikekuan@fareastone.com.tw"
mailList="mikekuan@fareastone.com.tw"

#---------------------------------------------------------------------------------------#
#      MPC info
#---------------------------------------------------------------------------------------#
hostname=`hostname`
case ${hostname} in
"pc-hgbap01t") #(TEST06) (PT)
DB="HGBDEV2"
RPTDB="HGBDEV2"
OCS_AP="fetwrk26"
;;
"hgbdev01t") #(TEST06) (PT)
DB="HGBDEV3"
RPTDB="HGBDEV3"
OCS_AP="fetwrk26"
;;
"pc-hgbap11t") #(TEST15) (SIT)
DB="HGBBLSIT"
RPTDB="HGBBLSIT"
OCS_AP="fetwrk15"
putip1=10.64.16.58
putpass1=unix11
;;
"pc-hgbap21t") #(TEST02) (UAT)
DB="HGBBLUAT"
RPTDB="HGBBLUAT"
OCS_AP="fetwrk21"
putip1=10.64.18.122
putpass1=unix11
;;
"pet-hgbap01p"|"pet-hgbap02p") #(PET)
DB="HGBBL"
RPTDB="HGBBLRPT"
OCS_AP="prdbl2"
putip1=10.64.18.123
putpass1=unix11
;;
"idc-hgbap01p"|"idc-hgbap02p") #(PROD)
DB="HGBBL"
RPTDB="HGBBLRPT"
OCS_AP="prdbl2"
putip1=10.68.59.130
putpass1=`/cb/CRYPT/GetPw.sh UBL_UAR_FTP`
;;
*)
echo "Unknown AP Server"
exit 0
esac
DBID=`/cb/CRYPT/GetId.sh $DB`
DBPWD=`/cb/CRYPT/GetPw.sh $DB`
#FTP
putuser1=ublftp
putpath1=/AR/payment/ARBATCH90/Batch_ESDP_FSS_RPT/DIO_INPUT

#---------------------------------------------------------------------------------------#
#      function
#---------------------------------------------------------------------------------------#
function genReport
{
echo "Gen Report Start"|tee -a ${logFile}
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${logFile} <<EOF
set colsep ','
set echo off
set feedback off
set linesize 9999
set pagesize 50000
set sqlprompt ''
set trimspool on
set trimout on
set headsep off
set heading off

spool ${reportFileName}.dat

select 'ACCOUNT_ID'||';'||'SUBSCRIBER_NO'||';'||'SUBSCRIBER_TYPE'||';'||'CHARGE_CODE'||';'||'CHARGE_TYPE'||';'||'REVENUE_CODE'||';'||'EFF_DATE'||';'||'END_DATE'||';'||'BILL_END_DATE'||';'||'BILL_AMOUNT'||';'||'ACCRUAL'||';'||'MONTHLY_AMOUNT' from dual;

--SELECT   a.acct_id "ACCOUNT_ID", a.offer_level_id "SUBSCRIBER_NO", cs.subscr_type "SUBSCRIBER_TYPE", rc_charge.charge_code, 'DBT' "CHARGE_TYPE", rc_charge.dscr "ChargeCodeDesc", a.pkg_type_dtl "REVENUE_CODE", cpl.elem2 "AcctName",
--         TO_CHAR (a.eff_date, 'YYYY/MM/DD') "EFF_DATE",TO_CHAR (a.end_date, 'YYYY/MM/DD') "END_DATE", TO_CHAR (add_months(a.eff_date,12)-1, 'YYYY/MM/DD') "BILL_END_DATE",
--         decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
--         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0) "BILL_AMOUNT",
--         DECODE(SIGN(nvl(a.end_date,a.eff_date) - a.eff_date - 15), -1, 'Y', 'N') "ACCRUAL",
--         round(decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
--         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)/12,0) "MONTHLY_AMOUNT"
--    FROM fy_tb_bl_acct_pkg a, fy_Tb_pbk_package_rc prc,fy_tb_pbk_offer offer,fy_tb_bl_bill_cntrl cntrl, fy_Tb_cm_prof_link cpl, fy_tb_cm_subscr cs,
--         (SELECT *
--            FROM fy_tb_bl_offer_param
--           WHERE param_name LIKE 'RC_RATE1%') rc_rate,
--         (SELECT *
--            FROM fy_tb_bl_offer_param
--           WHERE param_name = 'DEVICE_COUNT') device_count,
--         (SELECT rc.frequency, rc.pkg_id, rc.rate1, code.charge_code, code.dscr
--            FROM fy_tb_pbk_package_rc rc, fy_tb_pbk_charge_code code
--           WHERE rc.charge_code = code.charge_code) rc_charge
--   WHERE   cntrl.bill_period = ${sysd} --202302
--   AND cntrl.CYCLE in (10, 15, 20) --SR260229_Project-M Fixed line Phase I_新增CYCLE(15,20)
--   and a.eff_date >= cntrl.bill_from_date --to_date(20230201,'yyyymmdd')
--   and a.eff_date <= cntrl.bill_end_date --to_date(20230228,'yyyymmdd')
--   and a.cur_billed is null
--   and a.first_bill_date is null
--   and a.future_exp_date >= add_months(a.eff_date,12)
--   and add_months(a.future_exp_date,-12) > a.eff_date
--   --and a.end_rsn != 'DFC'
--   --and offer.offer_type != 'PP'
--   and prc.payment_timing='D'
--     AND a.acct_id = rc_rate.acct_id(+)
--     AND a.offer_instance_id = rc_rate.offer_instance_id(+)
--     AND a.acct_id = device_count.acct_id(+)
--     AND a.offer_instance_id = device_count.offer_instance_id(+)
--     AND a.pkg_id = rc_charge.pkg_id(+)
--     and a.pkg_id = prc.pkg_id
--     and a.offer_id=offer.offer_id
--     and a.acct_id = cpl.entity_id
--     and a.offer_level_id = cs.subscr_id
--     and cpl.entity_type='A'
--     and cpl.prof_type='NAME'
--     and cpl.link_type='A'
--union all
--SELECT   a.acct_id "ACCOUNT_ID", a.offer_level_id "SUBSCRIBER_NO", cs.subscr_type "SUBSCRIBER_TYPE", rc_charge.charge_code, 'DBT' "CHARGE_TYPE", rc_charge.dscr "ChargeCodeDesc", a.pkg_type_dtl "REVENUE_CODE", cpl.elem2 "AcctName",
--         TO_CHAR (a.eff_date, 'YYYY/MM/DD') "EFF_DATE",TO_CHAR (a.end_date, 'YYYY/MM/DD') "END_DATE", TO_CHAR (add_months(a.eff_date,12)-1, 'YYYY/MM/DD') "BILL_END_DATE",
--         decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
--         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0) "BILL_AMOUNT",
--         DECODE(SIGN(nvl(a.end_date,a.eff_date) - a.eff_date - 15), -1, 'Y', 'N') "ACCRUAL",
--         round(decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
--         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)/12,0) "MONTHLY_AMOUNT"
--    FROM fy_tb_bl_acct_pkg a, fy_Tb_pbk_package_rc prc,fy_tb_pbk_offer offer,fy_tb_bl_bill_cntrl cntrl, fy_Tb_cm_prof_link cpl, fy_tb_cm_subscr cs,
--         (SELECT *
--            FROM fy_tb_bl_offer_param
--           WHERE param_name LIKE 'RC_RATE1%') rc_rate,
--         (SELECT *
--            FROM fy_tb_bl_offer_param
--           WHERE param_name = 'DEVICE_COUNT') device_count,
--         (SELECT rc.frequency, rc.pkg_id, rc.rate1, code.charge_code, code.dscr
--            FROM fy_tb_pbk_package_rc rc, fy_tb_pbk_charge_code code
--           WHERE rc.charge_code = code.charge_code) rc_charge
--   WHERE   cntrl.bill_period = ${sysd} --202302
--   AND cntrl.CYCLE in (10, 15, 20) --SR260229_Project-M Fixed line Phase I_新增CYCLE(15,20)
--   and a.eff_date < cntrl.bill_from_date --to_date(20230201,'yyyymmdd')
--   --and a.eff_date <= cntrl.bill_end_date --to_date(20230228,'yyyymmdd')
--   and a.cur_billed between to_date(20230201,'yyyymmdd') and to_date(20230228,'yyyymmdd')
--   and a.first_bill_date is not null
--   and a.future_exp_date >= add_months(a.eff_date,12)
--   and add_months(a.future_exp_date,-12) > a.eff_date
--   --and a.end_rsn != 'DFC'
--   --and offer.offer_type != 'PP'
--   and prc.payment_timing='D'
--     AND a.acct_id = rc_rate.acct_id(+)
--     AND a.offer_instance_id = rc_rate.offer_instance_id(+)
--     AND a.acct_id = device_count.acct_id(+)
--     AND a.offer_instance_id = device_count.offer_instance_id(+)
--     AND a.pkg_id = rc_charge.pkg_id(+)
--     and a.pkg_id = prc.pkg_id
--     and a.offer_id=offer.offer_id
--     and a.acct_id = cpl.entity_id
--	 and a.offer_level_id = cs.subscr_id
--     and cpl.entity_type='A'
--     and cpl.prof_type='NAME'
--     and cpl.link_type='A';

SELECT   a.acct_id|| ';' ||a.offer_level_id|| ';' ||cs.subscr_type|| ';' ||rc_charge.charge_code|| ';' ||'DBT'|| ';' ||a.pkg_type_dtl|| ';' ||TO_CHAR (a.eff_date, 'YYYY/MM/DD')|| ';' ||TO_CHAR (a.end_date, 'YYYY/MM/DD')|| ';' ||TO_CHAR (add_months(a.eff_date,12)-1, 'YYYY/MM/DD')|| ';' ||
         decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)|| ';' ||
         DECODE(SIGN(nvl(a.end_date,a.eff_date) - a.eff_date - 15), -1, 'Y', 'N')|| ';' ||
         round(decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)/12,0)
    FROM fy_tb_bl_acct_pkg a, fy_Tb_pbk_package_rc prc,fy_tb_pbk_offer offer,fy_tb_bl_bill_cntrl cntrl, fy_Tb_cm_prof_link cpl, fy_tb_cm_subscr cs,fy_tb_cm_customer cust,
         (SELECT *
            FROM fy_tb_bl_offer_param
           WHERE param_name LIKE 'RC_RATE1%') rc_rate,
         (SELECT *
            FROM fy_tb_bl_offer_param
           WHERE param_name = 'DEVICE_COUNT') device_count,
         (SELECT rc.frequency, rc.pkg_id, rc.rate1, code.charge_code, code.dscr
            FROM fy_tb_pbk_package_rc rc, fy_tb_pbk_charge_code code
           WHERE rc.charge_code = code.charge_code) rc_charge
   WHERE   cntrl.bill_period = ${sysd} --202301
   AND cntrl.CYCLE in (10, 15) --SR260229_Project-M Fixed line Phase I_新增CYCLE(15,20) --SR273784_移除Cycle 20
   and a.eff_date >= cntrl.bill_from_date --to_date(20230201,'yyyymmdd')
   and a.eff_date <= cntrl.bill_end_date --to_date(20230228,'yyyymmdd')
   and a.cur_billed is null
   and a.first_bill_date is null
   and a.future_exp_date >= add_months(a.eff_date,12)
   and add_months(a.future_exp_date,-12) > a.eff_date
   --and a.end_rsn != 'DFC'
   --and offer.offer_type != 'PP'
   and prc.payment_timing='D'
     AND a.acct_id = rc_rate.acct_id(+)
     AND a.offer_instance_id = rc_rate.offer_instance_id(+)
     AND a.acct_id = device_count.acct_id(+)
     AND a.offer_instance_id = device_count.offer_instance_id(+)
     AND a.pkg_id = rc_charge.pkg_id(+)
     and a.pkg_id = prc.pkg_id
     and a.offer_id=offer.offer_id
     and a.acct_id = cpl.entity_id
     and a.offer_level_id = cs.subscr_id
	 and cs.cust_id = cust.cust_id
	 and cust.cust_type != 'P' --SR273784_非APT
     and cpl.entity_type='A'
     and cpl.prof_type='NAME'
     and cpl.link_type='A' 
union all
SELECT   a.acct_id|| ';' ||a.offer_level_id|| ';' ||cs.subscr_type|| ';' ||rc_charge.charge_code|| ';' ||'DBT'|| ';' ||a.pkg_type_dtl|| ';' ||TO_CHAR (a.eff_date, 'YYYY/MM/DD')|| ';' ||TO_CHAR (a.end_date, 'YYYY/MM/DD')|| ';' ||TO_CHAR (add_months(a.eff_date,12)-1, 'YYYY/MM/DD')|| ';' ||
         decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)|| ';' ||
         DECODE(SIGN(nvl(a.end_date,a.eff_date) - a.eff_date - 15), -1, 'Y', 'N')|| ';' ||
         round(decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)/12,0)
    FROM fy_tb_bl_acct_pkg a, fy_Tb_pbk_package_rc prc,fy_tb_pbk_offer offer,fy_tb_bl_bill_cntrl cntrl, fy_Tb_cm_prof_link cpl, fy_tb_cm_subscr cs,fy_tb_cm_customer cust,
         (SELECT *
            FROM fy_tb_bl_offer_param
           WHERE param_name LIKE 'RC_RATE1%') rc_rate,
         (SELECT *
            FROM fy_tb_bl_offer_param
           WHERE param_name = 'DEVICE_COUNT') device_count,
         (SELECT rc.frequency, rc.pkg_id, rc.rate1, code.charge_code, code.dscr
            FROM fy_tb_pbk_package_rc rc, fy_tb_pbk_charge_code code
           WHERE rc.charge_code = code.charge_code) rc_charge
   WHERE   cntrl.bill_period = ${sysd} --202301
   AND cntrl.CYCLE in (10, 15) --SR260229_Project-M Fixed line Phase I_新增CYCLE(15,20) --SR273784_移除Cycle 20
   and a.eff_date < cntrl.bill_from_date --to_date(20230201,'yyyymmdd')
   --and a.eff_date <= cntrl.bill_end_date --to_date(20230228,'yyyymmdd')
   and a.cur_billed between cntrl.bill_from_date and cntrl.bill_end_date --to_date(20230201,'yyyymmdd') and to_date(20230228,'yyyymmdd')
   and a.first_bill_date is not null
   and a.future_exp_date >= add_months(a.eff_date,12)
   and add_months(a.future_exp_date,-12) > a.eff_date
   --and a.end_rsn != 'DFC'
   --and offer.offer_type != 'PP'
   and prc.payment_timing='D'
     AND a.acct_id = rc_rate.acct_id(+)
     AND a.offer_instance_id = rc_rate.offer_instance_id(+)
     AND a.acct_id = device_count.acct_id(+)
     AND a.offer_instance_id = device_count.offer_instance_id(+)
     AND a.pkg_id = rc_charge.pkg_id(+)
     and a.pkg_id = prc.pkg_id
     and a.offer_id=offer.offer_id
     and a.acct_id = cpl.entity_id
	 and a.offer_level_id = cs.subscr_id
	 and cs.cust_id = cust.cust_id
	 and cust.cust_type != 'P' --SR273784_非APT
     and cpl.entity_type='A'
     and cpl.prof_type='NAME'
     and cpl.link_type='A';

spool off

exit;

EOF`

echo "Gen Report End"|tee -a ${logFile}
}

function genReport2
{
echo "Gen Report2 Start"|tee -a ${logFile}
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${logFile} <<EOF
set colsep ','
set echo off
set feedback off
set linesize 9999
set pagesize 50000
set sqlprompt ''
set trimspool on
set trimout on
set headsep off
set heading off

spool ${reportFileName2}.dat

select 'ACCOUNT_ID'||';'||'SUBSCRIBER_NO'||';'||'SUBSCRIBER_TYPE'||';'||'CHARGE_CODE'||';'||'CHARGE_TYPE'||';'||'REVENUE_CODE'||';'||'EFF_DATE'||';'||'END_DATE'||';'||'BILL_END_DATE'||';'||'BILL_AMOUNT'||';'||'ACCRUAL'||';'||'MONTHLY_AMOUNT' from dual;

SELECT   a.acct_id|| ';' ||a.offer_level_id|| ';' ||cs.subscr_type|| ';' ||rc_charge.charge_code|| ';' ||'DBT'|| ';' ||a.pkg_type_dtl|| ';' ||TO_CHAR (a.eff_date, 'YYYY/MM/DD')|| ';' ||TO_CHAR (a.end_date, 'YYYY/MM/DD')|| ';' ||TO_CHAR (add_months(a.eff_date,12)-1, 'YYYY/MM/DD')|| ';' ||
         decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)|| ';' ||
         DECODE(SIGN(nvl(a.end_date,a.eff_date) - a.eff_date - 15), -1, 'Y', 'N')|| ';' ||
         round(decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)/12,0)
    FROM fy_tb_bl_acct_pkg a, fy_Tb_pbk_package_rc prc,fy_tb_pbk_offer offer,fy_tb_bl_bill_cntrl cntrl, fy_Tb_cm_prof_link cpl, fy_tb_cm_subscr cs,fy_tb_cm_customer cust,
         (SELECT *
            FROM fy_tb_bl_offer_param
           WHERE param_name LIKE 'RC_RATE1%') rc_rate,
         (SELECT *
            FROM fy_tb_bl_offer_param
           WHERE param_name = 'DEVICE_COUNT') device_count,
         (SELECT rc.frequency, rc.pkg_id, rc.rate1, code.charge_code, code.dscr
            FROM fy_tb_pbk_package_rc rc, fy_tb_pbk_charge_code code
           WHERE rc.charge_code = code.charge_code) rc_charge
   WHERE   cntrl.bill_period = ${sysd} --202301
   AND cntrl.CYCLE in (10, 15)
   and a.eff_date >= cntrl.bill_from_date --to_date(20230201,'yyyymmdd')
   and a.eff_date <= cntrl.bill_end_date --to_date(20230228,'yyyymmdd')
   and a.cur_billed is null
   and a.first_bill_date is null
   and a.future_exp_date >= add_months(a.eff_date,12)
   and add_months(a.future_exp_date,-12) > a.eff_date
   --and a.end_rsn != 'DFC'
   --and offer.offer_type != 'PP'
   and prc.payment_timing='D'
     AND a.acct_id = rc_rate.acct_id(+)
     AND a.offer_instance_id = rc_rate.offer_instance_id(+)
     AND a.acct_id = device_count.acct_id(+)
     AND a.offer_instance_id = device_count.offer_instance_id(+)
     AND a.pkg_id = rc_charge.pkg_id(+)
     and a.pkg_id = prc.pkg_id
     and a.offer_id=offer.offer_id
     and a.acct_id = cpl.entity_id
     and a.offer_level_id = cs.subscr_id
	 and cs.cust_id = cust.cust_id
	 and cust.cust_type = 'P' --SR273784_APT
     and cpl.entity_type='A'
     and cpl.prof_type='NAME'
     and cpl.link_type='A' 
union all
SELECT   a.acct_id|| ';' ||a.offer_level_id|| ';' ||cs.subscr_type|| ';' ||rc_charge.charge_code|| ';' ||'DBT'|| ';' ||a.pkg_type_dtl|| ';' ||TO_CHAR (a.eff_date, 'YYYY/MM/DD')|| ';' ||TO_CHAR (a.end_date, 'YYYY/MM/DD')|| ';' ||TO_CHAR (add_months(a.eff_date,12)-1, 'YYYY/MM/DD')|| ';' ||
         decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)|| ';' ||
         DECODE(SIGN(nvl(a.end_date,a.eff_date) - a.eff_date - 15), -1, 'Y', 'N')|| ';' ||
         round(decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)/12,0)
    FROM fy_tb_bl_acct_pkg a, fy_Tb_pbk_package_rc prc,fy_tb_pbk_offer offer,fy_tb_bl_bill_cntrl cntrl, fy_Tb_cm_prof_link cpl, fy_tb_cm_subscr cs,fy_tb_cm_customer cust,
         (SELECT *
            FROM fy_tb_bl_offer_param
           WHERE param_name LIKE 'RC_RATE1%') rc_rate,
         (SELECT *
            FROM fy_tb_bl_offer_param
           WHERE param_name = 'DEVICE_COUNT') device_count,
         (SELECT rc.frequency, rc.pkg_id, rc.rate1, code.charge_code, code.dscr
            FROM fy_tb_pbk_package_rc rc, fy_tb_pbk_charge_code code
           WHERE rc.charge_code = code.charge_code) rc_charge
   WHERE   cntrl.bill_period = ${sysd} --202301
   AND cntrl.CYCLE in (10, 15)
   and a.eff_date < cntrl.bill_from_date --to_date(20230201,'yyyymmdd')
   --and a.eff_date <= cntrl.bill_end_date --to_date(20230228,'yyyymmdd')
   and a.cur_billed between cntrl.bill_from_date and cntrl.bill_end_date --to_date(20230201,'yyyymmdd') and to_date(20230228,'yyyymmdd')
   and a.first_bill_date is not null
   and a.future_exp_date >= add_months(a.eff_date,12)
   and add_months(a.future_exp_date,-12) > a.eff_date
   --and a.end_rsn != 'DFC'
   --and offer.offer_type != 'PP'
   and prc.payment_timing='D'
     AND a.acct_id = rc_rate.acct_id(+)
     AND a.offer_instance_id = rc_rate.offer_instance_id(+)
     AND a.acct_id = device_count.acct_id(+)
     AND a.offer_instance_id = device_count.offer_instance_id(+)
     AND a.pkg_id = rc_charge.pkg_id(+)
     and a.pkg_id = prc.pkg_id
     and a.offer_id=offer.offer_id
     and a.acct_id = cpl.entity_id
	 and a.offer_level_id = cs.subscr_id
	 and cs.cust_id = cust.cust_id
	 and cust.cust_type = 'P' --SR273784_APT
     and cpl.entity_type='A'
     and cpl.prof_type='NAME'
     and cpl.link_type='A';

spool off

exit;

EOF`

echo "Gen Report2 End"|tee -a ${logFile}
}

function formatterReport
{
iconv -f utf8 -t big5 -c ${reportFileName}.dat > ${reportFileName}.big5
mv ${reportFileName}.big5 ${reportFileName}.dat
grep -v '^$' ${reportFileName}.dat > ${ReportDir}/${reportFileName}.csv
rm ${reportFileName}.dat
sleep 5
iconv -f utf8 -t big5 -c ${reportFileName2}.dat > ${reportFileName2}.big5
mv ${reportFileName2}.big5 ${reportFileName2}.dat
grep -v '^$' ${reportFileName2}.dat > ${ReportDir}/${reportFileName2}.csv
rm ${reportFileName2}.dat
#iconv -f utf8 -t big5 -c ${ReportDir}/${reportFileName}.csv > ${ReportDir}/${reportFileName}.big5
}

function sendFinalMail
{
send_msg="<SR259699_FSS_RPT_Non-monthlyPayment_Report> $sysd"
	#iconv -f utf8 -t big5 -c ${reportFileName}.txt > ${reportFileName}.big5
	#mv ${reportFileName}.big5 ${reportFileName}.txt
	#rm ${reportFileName}.dat
mailx -s "${send_msg}" -a ${ReportDirBak}/${reportFileName}.csv ${mailList} <<EOF
Dears,

   SR259699_FSS_RPT_Non-monthlyPayment_Report已產出。
   檔名：
   ${reportFileName}.csv
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF

send_msg="<SR259699_FSS_RPT_Non-monthlyPayment_Report> $sysd"
	#iconv -f utf8 -t big5 -c ${reportFileName}.txt > ${reportFileName}.big5
	#mv ${reportFileName}.big5 ${reportFileName}.txt
	#rm ${reportFileName}.dat
mailx -s "${send_msg}" -a ${ReportDirBak}/${reportFileName2}.csv ${mailList} <<EOF
Dears,

   SR259699_FSS_RPT_Non-monthlyPayment_Report已產出。
   檔名：
   ${reportFileName2}.csv
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

function sendGenTempErrorMail
{
send_msg="<SR259699_FSS_RPT_Non-monthlyPayment_Report> $sysd"
mailx -s "${send_msg} Gen Data Have Abnormal " ${mailList} <<EOF
Dear All,
  
  SR259699_FSS_RPT_Non-monthlyPayment_Report未產出。
  
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
echo "Gen ${reportFileName} Start" | tee -a ${logFile}
echo $sysdt|tee -a ${logFile}
cd $ReportDir
genReport
sleep 5
echo "Gen ${reportFileName2} Start" | tee -a ${logFile}
echo $sysdt|tee -a ${logFile}
cd $ReportDir
genReport2
sleep 5
#formatter Report 
echo "Formatter Report Start"|tee -a ${logFile}
formatterReport
echo "Formatter Report End"|tee -a ${logFile}


#check gen report
filecnt1=`ls ${ReportDir}/${reportFileName2}.csv|wc -l`
sleep 5
if [[ (${filecnt1} = 0 ) ]] ; then
	echo "${progName} Generated Report Have Abnormal"|tee -a ${logFile}
	sendGenTempErrorMail
	exit 0
else
cd ${ReportDir}
	echo "FTP Report"|tee -a ${logFile}
	echo "Run Command: ${ftpProg} ${putip1} ${putuser1} ******** ${ReportDir} ${putpath1} ${reportFileName}.csv 0" | tee -a ${logFile}
		${ftpProg} ${putip1} ${putuser1} ${putpass1} ${ReportDir} ${putpath1} ${reportFileName}.csv 0
	echo "Run Command: ${ftpProg} ${putip1} ${putuser1} ******** ${ReportDir} ${putpath1} ${reportFileName2}.csv 0" | tee -a ${logFile}
		${ftpProg} ${putip1} ${putuser1} ${putpass1} ${ReportDir} ${putpath1} ${reportFileName2}.csv 0
		
		#cd ${ReportDir}
	#ftpReport2 ${putip1} ${putuser1} ${putpass1} ${putpath1} "${reportFileName}.txt"
		
	echo "send SR259699_FSS_RPT_Non-monthlyPayment_Report"|tee -a ${logFile}

	echo "Move Report TO Bak"|tee -a ${logFile}
	mv "${reportFileName}.csv" ${ReportDirBak}
	mv "${reportFileName2}.csv" ${ReportDirBak}
	#send final mail
	sendFinalMail
fi
sleep 5

echo "Gen ${reportFileName} End" | tee -a ${logFile}
echo "Gen ${reportFileName2} End" | tee -a ${logFile}
echo $sysdt|tee -a ${logFile}
