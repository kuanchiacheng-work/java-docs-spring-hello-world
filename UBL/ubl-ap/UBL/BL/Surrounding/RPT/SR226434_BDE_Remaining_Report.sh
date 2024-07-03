#!/usr/bin/env bash
########################################################################################
# Program name : SR226434_HGB_BDE_Remaining_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2020/06/10 Modify by Mike Kuan
# Description : 新增HGB預繳餘額報表含IOT、MPBL
########################################################################################
# Date : 2020/10/16 Modify by Mike Kuan
# Description : SR230767 - HGB設定IoT企業專網折扣for ICT專案扣抵 (新增ACCT_NAME)
########################################################################################
# Date : 2021/11/05 Modify by Mike Kuan
# Description : 修改本期折扣金額抓取方式
########################################################################################
# Date : 2022/04/11 Modify by Mike Kuan
# Description : 修改mail收件人
########################################################################################
# Date : 2022/12/05 Modify by Mike Kuan
# Description : 修改已過期資料不顯示
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
reportFileName="SR226434_HGB_BDE_Remaining_Report"
mailList="melichen@fareastone.com.tw abbychen4@fareastone.com.tw mikekuan@fareastone.com.tw"
#mailList="mikekuan@fareastone.com.tw"

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
function genReport
{
echo "Gen Report Start"|tee -a ${logFile}
`sqlplus -s ${DBID}/${DBPWD}@${RPTDB} > ${logFile} <<EOF
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

spool SR226434_HGB_BDE_Remaining_Report.dat

select 'CYCLE','CUST','ACCT','ACCT_NAME','門號','門號類型','SUB','SUB狀態','OFFER','OFFER名稱','OFFER生效日期','BDE安裝金額','BDE當期使用金額','BDE總使用金額','BDE剩餘金額','OFFER_RSN_CODE','OFFER狀態','CATEGORY' from dual;

SELECT DECODE (d.CYCLE,
               10, 'N_Cloud05',
               15, 'N_Cloud15',
               20, 'NCIC01',
               50, 'M01',
               51, 'M03',
               52, 'M05',
               53, 'M08',
               54, 'M11',
               55, 'M14',
               56, 'M17',
               57, 'M20',
               58, 'M23',
               59, 'M25',
               60, 'M27'
              )||','||
       a.cust_id||','||a.acct_id||','||f.elem2||','||to_char(b.prim_resource_val)||','||
       b.prim_res_param_cd||','||b.subscr_id||','||b.status||','||
       a.offer_id||','||to_char(c.offer_name)||','||TO_CHAR (a.eff_date, 'YYYY/MM/DD')||','||
       DECODE (init_pkg_qty,
               0, (SELECT param_value
                     FROM fy_tb_bl_offer_param
                    WHERE param_name = 'BD_QUOTA_0001'
                      AND acct_id = a.acct_id
                      AND offer_instance_id = a.offer_instance_id),
               init_pkg_qty
              )||','||
       --NVL ((SELECT SUM (bb.amount) * -1
       --        FROM fy_tb_bl_bill_cntrl aa, fy_tb_bl_bill_ci bb
       --       WHERE aa.bill_period =
       --                            TO_CHAR (ADD_MONTHS (SYSDATE, -1),
       --                                     'yyyymm')
       --         AND aa.bill_seq = bb.bill_seq
       --         AND bb.SOURCE = 'DE'
       --         AND bb.subscr_id = a.offer_level_id
       --         AND bb.offer_id = a.offer_id
       --         AND bb.offer_instance_id = a.offer_instance_id),
       --     0
       --    )||','||
       NVL(NVL (a.bill_use_qty,
            a.cur_use_qty
           ),0)||','||
       a.total_disc_amt||','||a.cur_bal_qty||','||
       e.offer_rsn_code||','||DECODE (e.end_date, NULL, 'A', 'C')||','||DECODE(d.cust_type,'D','I','N',DECODE(d.CYCLE,20,'D','A'),'M')
  FROM fy_tb_bl_acct_pkg a,
       fy_tb_cm_subscr b,
       fy_tb_pbk_offer c,
       fy_tb_cm_customer d,
       fy_tb_cm_subscr_offer e,
       (SELECT *
            FROM fy_tb_cm_prof_link
           WHERE link_type = 'A' AND prof_type = 'NAME') f
 WHERE a.offer_level = 'S'
   AND d.cust_type != 'N'
   AND a.prepayment IS NOT NULL
   AND a.offer_level_id = b.subscr_id
   AND a.offer_level_id = e.subscr_id
   AND a.acct_id = f.entity_id
   AND a.offer_id = c.offer_id
   AND a.offer_id = e.offer_id
   AND a.offer_instance_id = e.offer_instance_id
   AND a.cust_id = d.cust_id
   and add_months(a.cur_billed,2) >= sysdate --2022/12/05過期資料不顯示
;

spool off

exit;

EOF`

echo "Gen Report End"|tee -a ${logFile}
}

function formatterReport
{
grep -v '^$' ${reportFileName}.dat > ${ReportDir}/${reportFileName}.csv
rm ${reportFileName}.dat
}

function sendFinalMail
{
send_msg="<SR226434_HGB_BDE_Remaining_Report> $sysd"
	iconv -f utf8 -t big5 -c ${reportFileName}.csv > ${reportFileName}.big5
	mv ${reportFileName}.big5 ${reportFileName}_$sysd.csv
	rm ${reportFileName}.csv
mailx -s "${send_msg}" -a ${reportFileName}_$sysd.csv "${mailList}" <<EOF
Dears,

   SR226434_HGB_BDE_Remaining_Report已產出。
   檔名：
   ${reportFileName}.csv

EOF
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
echo "Gen ${reportFileName1} Start" | tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
cd $ReportDir
genReport

#formatter Report 
echo "Formatter Report Start"|tee -a ${logFile}
formatterReport
echo "Formatter Report End"|tee -a ${logFile}

#send final mail
sendFinalMail
echo "Gen ${reportFileName1} End" | tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
