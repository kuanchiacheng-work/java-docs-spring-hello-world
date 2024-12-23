#!/usr/bin/env bash
########################################################################################
# Program name : SR260229_HGBN_Bill_Monthly_Check_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2023/05/16 Created by Mike Kuan
# Description : SR260229_HGBN_Bill_Monthly_Check_Report
########################################################################################
# Date : 2023/08/22 Created by Mike Kuan
# Description : 移除CM/RAT
########################################################################################

export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
progName=$(basename $0 .sh)
sysdt=`date +%Y%m%d%H%M%S`
sysd=`date +%Y%m --date="-1 month"`
HomeDir=/extsoft/UBL/BL
WorkDir=$HomeDir/Surrounding/RPT
ReportDir=$WorkDir/report
LogDir=$WorkDir/log
logFile=$LogDir/${progName}_${sysdt}.log
tempFile=$LogDir/${progName}_tmp_${sysdt}.log
reportFileName_BL="SR260229_HGBN_Bill_Monthly_Check_Report_BL"
reportFileName_CM="SR260229_HGBN_Bill_Monthly_Check_Report_CM"
reportFileName_RAT="SR260229_HGBN_Bill_Monthly_Check_Report_RAT"
#mailList="mikekuan@fareastone.com.tw"
mailList="mikekuan@fareastone.com.tw raetsai@fareastone.com.tw susu@fareastone.com.tw angell@fareastone.com.tw wehschiu@fareastone.com.tw"

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
;;
"pc-hgbap21t") #(TEST02) (UAT)
DB="HGBBLUAT"
RPTDB="HGBBLUAT"
OCS_AP="fetwrk21"
;;
"pet-hgbap01p"|"pet-hgbap02p"|"idc-hgbap01p"|"idc-hgbap02p") #(PET) (PROD)
DB="HGBBL"
RPTDB="HGBBLRPT"
OCS_AP="prdbl2"
;;
*)
echo "Unknown AP Server"
exit 0
esac
DBID=`/cb/CRYPT/GetId.sh $DB`
DBPWD=`/cb/CRYPT/GetPw.sh $DB`

#---------------------------------------------------------------------------------------#
#      function
#---------------------------------------------------------------------------------------#
function genReport_BLCM
{
echo "Gen Report_BL/CM Start"|tee -a ${logFile}
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${tempFile} <<EOF
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

spool SR260229_HGBN_Bill_Monthly_Check_Report_BL.dat

select 'CYCLE'||','||'客戶帳號'||','||'CA編號'||','||'費用名稱'||','||'牌價'||','||'議價數量'||','||'議價金額'||','||'計費方式'||','||'預估出帳金額'||','||'生效日'||','||'失效日'||','||'下次出帳區間'||','||'未來失效日'||','||'首次出帳日'||','||'已出帳至'||','||'charge_code'||','||'offer_level_id'||','||'offer_id'||','||'offer_seq'||','||'offer_instance_id'||','||'offer_name'||','||'recur_billed' from dual;

--SELECT   decode(cc.cycle,10,'N_Cloud05',15,'N_Cloud15',20,'NCIC01',cc.cycle) "CYCLE", a.acct_id "客戶帳號", b.resource_value "CA編號",
--         rc_charge.dscr "費用名稱", rc_charge.rate1 "牌價",
--         device_count.param_value "議價數量", rc_rate.param_value "議價金額",decode(prc.qty_condition,'D','單價*數量',decode(offer.offer_type,'PP','PP','總額')) "計費方式", 
--         decode(a.cur_billed,null,null,
--         decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
--         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0)) "預估出帳金額",
--         a.eff_date "生效日", a.end_date "失效日",
--         decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
--         decode(rc_charge.frequency,1,'月繳',
--         decode(cur_billed,null,to_char(a.eff_date,'yyyy/mm/dd')||'~'||to_char(decode(sign(add_months(a.future_exp_date,-12)-add_months(a.eff_date,12)),1,add_months(a.eff_date,12)-1,a.future_exp_date-1),'yyyy/mm/dd'),
--         to_char(a.cur_billed+1,'yyyy/mm/dd')||'~'||to_char(decode(sign(add_months(a.future_exp_date,-12)-add_months(a.cur_billed,12)),1,add_months(a.cur_billed,12),a.future_exp_date-1),'yyyy/mm/dd'))),null) "下次出帳區間",
--         a.future_exp_date "未來失效日", a.first_bill_date "首次出帳日",
--         a.cur_billed "已出帳至", rc_charge.charge_code, a.offer_level_id,
--         a.offer_id, a.offer_seq, a.offer_instance_id, a.offer_name,
--         a.recur_billed
--    FROM fy_tb_bl_acct_pkg a,fy_Tb_cm_customer cc,
--         fy_tb_cm_resource b,fy_Tb_pbk_package_rc prc,fy_tb_pbk_offer offer,
--         (SELECT *
--            FROM fy_tb_bl_offer_param
--           WHERE param_name LIKE 'RC_RATE1%') rc_rate,
--         (SELECT *
--            FROM fy_tb_bl_offer_param
--           WHERE param_name = 'DEVICE_COUNT') device_count,
--         (SELECT rc.frequency, rc.pkg_id, rc.rate1, code.charge_code, code.dscr
--            FROM fy_tb_pbk_package_rc rc, fy_tb_pbk_charge_code code
--           WHERE rc.charge_code = code.charge_code) rc_charge
--   WHERE cc.cycle in (10,15,20) and cc.cust_id = a.cust_id
--     AND a.acct_id = rc_rate.acct_id(+)
--     AND a.offer_instance_id = rc_rate.offer_instance_id(+)
--     AND a.acct_id = device_count.acct_id(+)
--     AND a.offer_instance_id = device_count.offer_instance_id(+)
--     AND a.pkg_id = rc_charge.pkg_id(+)
--     and a.pkg_id = prc.pkg_id
--     and a.offer_id=offer.offer_id
--     AND a.offer_level_id = b.subscr_id
--ORDER BY a.acct_id, b.resource_value, offer_level_id, offer_id;

SELECT   decode(cc.cycle,10,'N_Cloud05',15,'N_Cloud15',20,'NCIC01',cc.cycle) || ','
                || a.acct_id|| ','
                || b.resource_value|| ',"'
                || to_char(rc_charge.dscr)|| '",'
                || rc_charge.rate1|| ','
                || device_count.param_value|| ','
                || rc_rate.param_value|| ','
                || decode(prc.qty_condition,'D','單價*數量',decode(offer.offer_type,'PP','PP','總額'))|| ','
                ||  
         decode(a.cur_billed,null,null,
         decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
         decode(prc.qty_condition,'D',nvl(device_count.param_value,1)*nvl(rc_rate.param_value,rc_charge.rate1),nvl(rc_rate.param_value,rc_charge.rate1)),0))|| ','
                || to_char(a.eff_date,'yyyymmdd')|| ','
                || to_char(a.end_date,'yyyymmdd')|| ','
                || decode(decode(SIGN(trunc(a.cur_billed)+1-trunc(a.future_exp_date)),0,0,1),1,
         decode(rc_charge.frequency,1,'月繳',
         decode(cur_billed,null,to_char(a.eff_date,'yyyy/mm/dd')||'~'||to_char(decode(sign(add_months(a.future_exp_date,-12)-add_months(a.eff_date,12)),1,add_months(a.eff_date,12)-1,a.future_exp_date-1),'yyyy/mm/dd'),
         to_char(a.cur_billed+1,'yyyy/mm/dd')||'~'||to_char(decode(sign(add_months(a.future_exp_date,-12)-add_months(a.cur_billed,12)),1,add_months(a.cur_billed,12),a.future_exp_date-1),'yyyy/mm/dd'))),null)|| ','
                || to_char(a.future_exp_date,'yyyymmdd')|| ','
                || to_char(a.first_bill_date,'yyyymmdd')|| ','
                || to_char(a.cur_billed,'yyyymmdd')|| ','
                || rc_charge.charge_code|| ','
                || a.offer_level_id|| ','
                || a.offer_id|| ','
                || a.offer_seq|| ','
                || a.offer_instance_id|| ',"'
                || a.offer_name|| '",'
                || to_char(a.recur_billed,'yyyymmdd')
    FROM fy_tb_bl_acct_pkg a,fy_Tb_cm_customer cc,
         fy_tb_cm_resource b,fy_Tb_pbk_package_rc prc,fy_tb_pbk_offer offer,
         (SELECT *
            FROM fy_tb_bl_offer_param
           WHERE param_name LIKE 'RC_RATE1%') rc_rate,
         (SELECT *
            FROM fy_tb_bl_offer_param
           WHERE param_name = 'DEVICE_COUNT') device_count,
         (SELECT rc.frequency, rc.pkg_id, rc.rate1, code.charge_code, code.dscr
            FROM fy_tb_pbk_package_rc rc, fy_tb_pbk_charge_code code
           WHERE rc.charge_code = code.charge_code) rc_charge
   WHERE cc.cycle in (10,15,20) and cc.cust_id = a.cust_id
     AND a.acct_id = rc_rate.acct_id(+)
     AND a.offer_instance_id = rc_rate.offer_instance_id(+)
     AND a.acct_id = device_count.acct_id(+)
     AND a.offer_instance_id = device_count.offer_instance_id(+)
     AND a.pkg_id = rc_charge.pkg_id(+)
     and a.pkg_id = prc.pkg_id
     and a.offer_id=offer.offer_id
     AND a.offer_level_id = b.subscr_id;
spool off

spool SR260229_HGBN_Bill_Monthly_Check_Report_CM.dat

--select 'account'||','||'CompanyName'||','||'Name'||','||'tax_ID'||','||'address'||','||'ID_Type'||','||'Bill_Delivery_Method'||','||'email_address' from dual;

select 'account'||','||'CompanyName'||','||'ID_Type'||','||'Bill_Delivery_Method' from dual;

--select name.entity_id as account,addr.elem13 as CompanyName,name.elem2 as Name,name.elem6 as tax_ID,addr.elem1||addr.elem2||addr.elem3 as address
--,decode (name.elem5,'1','國民身分證','2','統一編號','3','稅籍編號','0','外籍人士證照號碼','19','NCIC聯絡人編號','20','EBU編號',name.elem5)as ID_Type 
--,decode (addr.elem7,'1','書面帳單','2','列印書面帳款及電子帳單','3','電子帳單(過渡期)','4','電子帳單','無')as Bill_Delivery_Method
--,addr.elem6 as email_address
--from (select * from fy_tb_cm_prof_link
--        where prof_type='ADDR') addr 
--      ,(select * from fy_tb_cm_prof_link
--       where prof_type='NAME') name
--where addr.entity_type='A'
--and name.entity_type=addr.entity_type
--and addr.link_type='B'
--and name.link_type=addr.link_type
--and name.entity_id=addr.entity_id
----and addr.entity_id=843738897
--and EXISTS (select 1 from fy_Tb_cm_customer cc, fy_tb_cm_account ca where cc.cycle=10 and cc.cust_type='N' and cc.cust_id=ca.cust_id and ca.acct_id=addr.entity_id) 
--;

select name.entity_id|| ','
                || addr.elem13|| ','
                || name.elem6|| ','
                || decode (addr.elem7,'1','書面帳單','2','列印書面帳款及電子帳單','3','電子帳單(過渡期)','4','電子帳單','無')
from (select * from fy_tb_cm_prof_link
        where prof_type='ADDR') addr 
      ,(select * from fy_tb_cm_prof_link
       where prof_type='NAME') name
where addr.entity_type='A'
and name.entity_type=addr.entity_type
and addr.link_type='B'
and name.link_type=addr.link_type
and name.entity_id=addr.entity_id
--and addr.entity_id=843738897
and EXISTS (select 1 from fy_Tb_cm_customer cc, fy_tb_cm_account ca where cc.cycle=10 and cc.cust_type='N' and cc.cust_id=ca.cust_id and ca.acct_id=addr.entity_id) 
;
spool off
exit;
EOF`
echo "Gen Report_BL/CM End"|tee -a ${logFile}
}


function genReport_RAT
{
echo "Gen Report_RAT Start"|tee -a ${logFile}
`sqlplus -s hgbrtappc/hgbrtappc_#@HGBRT1 > ${tempFile} <<EOF
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

spool SR260229_HGBN_Bill_Monthly_Check_Report_RAT.dat

select 'CA編號'||','||'客戶帳號'||','||'費用名稱'||','||'牌價'||','||'0001'||','||'起1'||','||'迄1'||','||'金1'||','||'0002'||','||'起2'||','||'迄2'||','||'金2'||','||'0003'||','||'起3'||','||'迄3'||','||'金3'||','||'0004'||','||'起4'||','||'迄4'||','||'金4'||','||'0005'||','||'起5'||','||'迄5'||','||'金5'||','||'生效日'||','||'失效日'||','||'charge_code'||','||'offer_level_id'||','||'offer_id'||','||'offer_seq'||','||'offer_instance_id'||','||'offer_name' from dual;

--SELECT   b.resource_value "CA編號",a.acct_id "客戶帳號",
--         uc_charge.dscr "費用名稱", uc_charge.rate1||','||uc_charge.rate2||','||uc_charge.rate3||','||uc_charge.rate4||','||uc_charge.rate5 "牌價",
--         uc_qtys1.param_name "0001",  uc_qtys1.param_value "起1",  uc_qtye1.param_value "迄1", uc_rate1.param_value "金1",
--         uc_qtys2.param_name "0002",  uc_qtys2.param_value "起2",  uc_qtye2.param_value "迄2", uc_rate2.param_value "金2",
--         uc_qtys3.param_name "0003",  uc_qtys3.param_value "起3",  uc_qtye3.param_value "迄3", uc_rate3.param_value "金3",
--         uc_qtys4.param_name "0004",  uc_qtys4.param_value "起4",  uc_qtye4.param_value "迄4", uc_rate4.param_value "金4",
--         uc_qtys5.param_name "0005",  uc_qtys5.param_value "起5",  uc_qtye5.param_value "迄5", uc_rate5.param_value "金5",
--         a.eff_date "生效日", a.end_date "失效日",
--         uc_charge.charge_code, a.offer_level_id,
--         a.offer_id, a.offer_seq, a.offer_instance_id, a.offer_name
--    FROM fy_tb_rat_acct_pkg a, fy_tb_cm_resource b,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_RATE1%') uc_rate1,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_QTYS1%') uc_qtys1,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_QTYE1%') uc_qtye1,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_RATE2%') uc_rate2,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_QTYS2%') uc_qtys2,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_QTYE2%') uc_qtye2,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_RATE3%') uc_rate3,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_QTYS3%') uc_qtys3,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_QTYE3%') uc_qtye3,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_RATE4%') uc_rate4,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_QTYS4%') uc_qtys4,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_QTYE4%') uc_qtye4,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_RATE5%') uc_rate5,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_QTYS5%') uc_qtys5,
--         (SELECT *
--            FROM fy_tb_rat_offer_param
--            where param_name LIKE 'UC_QTYE5%') uc_qtye5,
--         (SELECT uc.pkg_id, uc_dtl.rate1, uc_dtl.rate2, uc_dtl.rate3, uc_dtl.rate4, uc_dtl.rate5, code.charge_code, code.dscr
--  FROM fy_tb_pbk_package_uc uc,
--       fy_tb_pbk_package_uc_dtl uc_dtl,
--       fy_tb_pbk_charge_code code
-- WHERE uc.pkg_id = uc_dtl.pkg_id AND uc.charge_code = code.charge_code) uc_charge
--   WHERE a.acct_id = uc_rate1.acct_id(+)
--     AND a.offer_level_id = uc_rate1.subscr_id(+)
--     and a.offer_seq=uc_rate1.offer_seq(+)
--          AND a.acct_id = uc_qtys1.acct_id(+)
--     AND a.offer_level_id = uc_qtys1.subscr_id(+)
--     and a.offer_seq=uc_qtys1.offer_seq(+)
--          AND a.acct_id = uc_qtye1.acct_id(+)
--     AND a.offer_level_id = uc_qtye1.subscr_id(+)
--     and a.offer_seq=uc_qtye1.offer_seq(+)
--     and a.acct_id = uc_rate2.acct_id(+)
--     AND a.offer_level_id = uc_rate2.subscr_id(+)
--     and a.offer_seq=uc_rate2.offer_seq(+)
--          AND a.acct_id = uc_qtys2.acct_id(+)
--     AND a.offer_level_id = uc_qtys2.subscr_id(+)
--     and a.offer_seq=uc_qtys2.offer_seq(+)
--          AND a.acct_id = uc_qtye2.acct_id(+)
--     AND a.offer_level_id = uc_qtye2.subscr_id(+)
--     and a.offer_seq=uc_qtye2.offer_seq(+)
--     AND a.pkg_id = uc_charge.pkg_id(+)
--          and a.acct_id = uc_rate3.acct_id(+)
--     AND a.offer_level_id = uc_rate3.subscr_id(+)
--     and a.offer_seq=uc_rate3.offer_seq(+)
--          AND a.acct_id = uc_qtys3.acct_id(+)
--     AND a.offer_level_id = uc_qtys3.subscr_id(+)
--     and a.offer_seq=uc_qtys3.offer_seq(+)
--          AND a.acct_id = uc_qtye3.acct_id(+)
--     AND a.offer_level_id = uc_qtye3.subscr_id(+)
--     and a.offer_seq=uc_qtye3.offer_seq(+)
--          and a.acct_id = uc_rate4.acct_id(+)
--     AND a.offer_level_id = uc_rate4.subscr_id(+)
--     and a.offer_seq=uc_rate4.offer_seq(+)
--          AND a.acct_id = uc_qtys4.acct_id(+)
--     AND a.offer_level_id = uc_qtys4.subscr_id(+)
--     and a.offer_seq=uc_qtys4.offer_seq(+)
--          AND a.acct_id = uc_qtye4.acct_id(+)
--     AND a.offer_level_id = uc_qtye4.subscr_id(+)
--     and a.offer_seq=uc_qtye4.offer_seq(+)
--          and a.acct_id = uc_rate5.acct_id(+)
--     AND a.offer_level_id = uc_rate5.subscr_id(+)
--     and a.offer_seq=uc_rate5.offer_seq(+)
--          AND a.acct_id = uc_qtys5.acct_id(+)
--     AND a.offer_level_id = uc_qtys5.subscr_id(+)
--     and a.offer_seq=uc_qtys5.offer_seq(+)
--          AND a.acct_id = uc_qtye5.acct_id(+)
--     AND a.offer_level_id = uc_qtye5.subscr_id(+)
--     and a.offer_seq=uc_qtye5.offer_seq(+)
--     and a.cust_id in (select cust_id from fy_Tb_cm_customer cc where cc.cycle=10 and cc.cust_type='N')
--     and a.offer_level_id=b.subscr_id
--ORDER BY a.acct_id, offer_level_id, offer_id;

SELECT   b.resource_value|| ','
                || a.acct_id|| ',"'
                || uc_charge.dscr|| '","'
                || uc_charge.rate1||','||uc_charge.rate2||','||uc_charge.rate3||','||uc_charge.rate4||','||uc_charge.rate5|| '",'
                || 
         uc_qtys1.param_name|| ','
                || uc_qtys1.param_value|| ','
                || uc_qtye1.param_value|| ','
                || uc_rate1.param_value|| ','
                || 
         uc_qtys2.param_name|| ','
                || uc_qtys2.param_value|| ','
                || uc_qtye2.param_value|| ','
                || uc_rate2.param_value|| ','
                || 
         uc_qtys3.param_name|| ','
                || uc_qtys3.param_value|| ','
                || uc_qtye3.param_value|| ','
                || uc_rate3.param_value|| ','
                || 
         uc_qtys4.param_name|| ','
                || uc_qtys4.param_value|| ','
                || uc_qtye4.param_value|| ','
                || uc_rate4.param_value|| ','
                || 
         uc_qtys5.param_name|| ','
                || uc_qtys5.param_value|| ','
                || uc_qtye5.param_value|| ','
                || uc_rate5.param_value|| ','
                || 
         to_char(a.eff_date)|| ','
                || to_char(a.end_date)|| ','
                || 
         uc_charge.charge_code|| ','
                || a.offer_level_id|| ','
                || 
         a.offer_id|| ','
                || a.offer_seq|| ','
                || a.offer_instance_id|| ','
                || a.offer_name
    FROM fy_tb_rat_acct_pkg a, fy_tb_cm_resource b,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_RATE1%') uc_rate1,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_QTYS1%') uc_qtys1,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_QTYE1%') uc_qtye1,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_RATE2%') uc_rate2,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_QTYS2%') uc_qtys2,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_QTYE2%') uc_qtye2,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_RATE3%') uc_rate3,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_QTYS3%') uc_qtys3,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_QTYE3%') uc_qtye3,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_RATE4%') uc_rate4,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_QTYS4%') uc_qtys4,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_QTYE4%') uc_qtye4,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_RATE5%') uc_rate5,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_QTYS5%') uc_qtys5,
         (SELECT *
            FROM fy_tb_rat_offer_param
            where param_name LIKE 'UC_QTYE5%') uc_qtye5,
         (SELECT uc.pkg_id, uc_dtl.rate1, uc_dtl.rate2, uc_dtl.rate3, uc_dtl.rate4, uc_dtl.rate5, code.charge_code, code.dscr
  FROM fy_tb_pbk_package_uc uc,
       fy_tb_pbk_package_uc_dtl uc_dtl,
       fy_tb_pbk_charge_code code
 WHERE uc.pkg_id = uc_dtl.pkg_id AND uc.charge_code = code.charge_code) uc_charge
   WHERE a.acct_id = uc_rate1.acct_id(+)
     AND a.offer_level_id = uc_rate1.subscr_id(+)
     and a.offer_seq=uc_rate1.offer_seq(+)
          AND a.acct_id = uc_qtys1.acct_id(+)
     AND a.offer_level_id = uc_qtys1.subscr_id(+)
     and a.offer_seq=uc_qtys1.offer_seq(+)
          AND a.acct_id = uc_qtye1.acct_id(+)
     AND a.offer_level_id = uc_qtye1.subscr_id(+)
     and a.offer_seq=uc_qtye1.offer_seq(+)
     and a.acct_id = uc_rate2.acct_id(+)
     AND a.offer_level_id = uc_rate2.subscr_id(+)
     and a.offer_seq=uc_rate2.offer_seq(+)
          AND a.acct_id = uc_qtys2.acct_id(+)
     AND a.offer_level_id = uc_qtys2.subscr_id(+)
     and a.offer_seq=uc_qtys2.offer_seq(+)
          AND a.acct_id = uc_qtye2.acct_id(+)
     AND a.offer_level_id = uc_qtye2.subscr_id(+)
     and a.offer_seq=uc_qtye2.offer_seq(+)
     AND a.pkg_id = uc_charge.pkg_id(+)
          and a.acct_id = uc_rate3.acct_id(+)
     AND a.offer_level_id = uc_rate3.subscr_id(+)
     and a.offer_seq=uc_rate3.offer_seq(+)
          AND a.acct_id = uc_qtys3.acct_id(+)
     AND a.offer_level_id = uc_qtys3.subscr_id(+)
     and a.offer_seq=uc_qtys3.offer_seq(+)
          AND a.acct_id = uc_qtye3.acct_id(+)
     AND a.offer_level_id = uc_qtye3.subscr_id(+)
     and a.offer_seq=uc_qtye3.offer_seq(+)
          and a.acct_id = uc_rate4.acct_id(+)
     AND a.offer_level_id = uc_rate4.subscr_id(+)
     and a.offer_seq=uc_rate4.offer_seq(+)
          AND a.acct_id = uc_qtys4.acct_id(+)
     AND a.offer_level_id = uc_qtys4.subscr_id(+)
     and a.offer_seq=uc_qtys4.offer_seq(+)
          AND a.acct_id = uc_qtye4.acct_id(+)
     AND a.offer_level_id = uc_qtye4.subscr_id(+)
     and a.offer_seq=uc_qtye4.offer_seq(+)
          and a.acct_id = uc_rate5.acct_id(+)
     AND a.offer_level_id = uc_rate5.subscr_id(+)
     and a.offer_seq=uc_rate5.offer_seq(+)
          AND a.acct_id = uc_qtys5.acct_id(+)
     AND a.offer_level_id = uc_qtys5.subscr_id(+)
     and a.offer_seq=uc_qtys5.offer_seq(+)
          AND a.acct_id = uc_qtye5.acct_id(+)
     AND a.offer_level_id = uc_qtye5.subscr_id(+)
     and a.offer_seq=uc_qtye5.offer_seq(+)
     and a.cust_id in (select cust_id from fy_Tb_cm_customer cc where cc.cycle=10 and cc.cust_type='N')
     and a.offer_level_id=b.subscr_id
ORDER BY a.acct_id, offer_level_id, offer_id;
spool off
exit;
EOF`
echo "Gen Report_RAT End"|tee -a ${logFile}
}



function formatterReport_BL
{
grep -v '^$' ${reportFileName_BL}.dat > ${ReportDir}/${reportFileName_BL}.csv
rm ${reportFileName_BL}.dat
}

function formatterReport_CM
{
grep -v '^$' ${reportFileName_CM}.dat > ${ReportDir}/${reportFileName_CM}.csv
rm ${reportFileName_CM}.dat
}

function formatterReport_RAT
{
grep -v '^$' ${reportFileName_RAT}.dat > ${ReportDir}/${reportFileName_RAT}.csv
rm ${reportFileName_RAT}.dat
}

function sendFinalMail
{
send_msg="<SR260229_HGBN_Bill_Monthly_Check_Report> $sysd"
	iconv -f utf8 -t big5 -c ${reportFileName_BL}.csv > ${reportFileName_BL}.big5
	mv ${reportFileName_BL}.big5 ${reportFileName_BL}_$sysd.csv
	rm ${reportFileName_BL}.csv
	#iconv -f utf8 -t big5 -c ${reportFileName_CM}.csv > ${reportFileName_CM}.big5
	#mv ${reportFileName_CM}.big5 ${reportFileName_CM}_$sysd.csv
	#rm ${reportFileName_CM}.csv
	#iconv -f utf8 -t big5 -c ${reportFileName_RAT}.csv > ${reportFileName_RAT}.big5
	#mv ${reportFileName_RAT}.big5 ${reportFileName_RAT}_$sysd.csv
	#rm ${reportFileName_RAT}.csv

mailx -s "${send_msg}" -a ${reportFileName_BL}_$sysd.csv "${mailList}" <<EOF
Dears,

   SR260229_HGBN_Bill_Monthly_Check_Report已產出。
   檔名：
   ${reportFileName_BL}.csv

EOF
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
echo "Gen ${reportFileName_BL} Start" | tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
cd $ReportDir
genReport_BLCM
#genReport_RAT

#formatter Report 
echo "Formatter Report Start"|tee -a ${logFile}
formatterReport_BL
#formatterReport_CM
#formatterReport_RAT
echo "Formatter Report End"|tee -a ${logFile}

#send final mail
sendFinalMail
echo "Gen ${reportFileName_BL} End" | tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
