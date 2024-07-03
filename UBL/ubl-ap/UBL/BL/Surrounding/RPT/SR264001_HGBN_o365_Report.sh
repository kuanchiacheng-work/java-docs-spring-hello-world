#!/usr/bin/env bash
########################################################################################
# Program name : SR264001_HGBN_o365_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2023/08/24 Created by Mike Kuan
# Description : SR264001_客戶o365 產品數量暨到期日資訊報表
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
reportFileName_BL="SR264001_HGBN_o365_Report"
mailList="mikekuan@fareastone.com.tw rayyang2@fareastone.com.tw"
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
function genReport_BL
{
echo "Gen Report_BL Start"|tee -a ${logFile}
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

spool SR264001_HGBN_o365_Report.dat

select '客戶編號'||','||'客戶名稱'||','||'統編'||','||'微軟租戶帳號'||','||'負責業務員'||','||'產品品項'||','||'產品ChargeStartDate'||','||'產品ChargeEndDate'||','||'週期性收費月份'||','||'產品數量'||','||'收入單價'||','||'收入總金額'||','||'bill_Seq'||','||'acct_id'||','||'subscr_id'||','||'offer_seq' from dual;

--SELECT distinct
--    TO_CHAR(h.subscr_id) AS "客戶編號",
--    e.elem2 AS "客戶名稱",
--    e.elem6 AS "統編",
--    f.param_value AS "微軟租戶帳號",
--    h.sales AS "負責業務員",
--    offer.offer_name AS "產品品項",
--    to_char(a.bill_from_date,'yyyymmdd') AS "產品ChargeStartDate",
--    to_char(a.bill_end_date,'yyyymmdd') AS "產品ChargeEndDate",
--    a.bill_period AS "週期性收費月份",
--    device_count.param_value AS "產品數量",
--    rc_rate.param_value AS "收入單價",
--    g.amount AS "收入總金額",
--    a.bill_Seq,
--    c.acct_id,
--    c.subscr_id,
--    g.offer_seq
--FROM
--    fy_tb_bl_bill_cntrl a
--JOIN
--    fy_tb_cm_subscr c ON a.CYCLE in (10,15,20) and a.CREATE_USER = 'UBL' and a.bill_period = to_char(trunc(add_months(sysdate,-1)),'yyyymm')
--JOIN
--    fy_tb_cm_prof_link e ON c.acct_id = e.entity_id AND e.entity_type = 'A' AND e.prof_type = 'NAME' AND e.link_type = 'A'
--JOIN
--    fy_Tb_cm_offer_param f ON c.acct_id = f.acct_id and c.subscr_id = f.subscr_id and f.param_name = 'NAME'
--JOIN
--    (
--        SELECT
--            bill_seq,
--            cycle,
--            SUM(amount) amount,
--            subscr_id,
--            offer_id,
--            offer_seq
--        FROM
--            fy_tb_bl_bill_ci
--        WHERE
--            source = 'RC'
--        GROUP BY
--            bill_seq,
--            cycle,
--            subscr_id,
--            offer_id,
--            offer_seq
--    ) g ON a.bill_seq = g.bill_seq AND a.CYCLE = g.CYCLE and c.subscr_id = g.subscr_id
--JOIN
--    fy_tb_bl_bill_offer_param rc_rate ON c.acct_id = rc_rate.acct_id and g.offer_seq = rc_rate.offer_seq and rc_rate.param_name LIKE 'RC_RATE1%'
--JOIN
--    fy_tb_bl_bill_offer_param device_count ON c.acct_id = device_count.acct_id and g.offer_seq = device_count.offer_seq and device_count.param_name = 'DEVICE_COUNT'
--JOIN
--    fy_tb_pbk_offer offer ON g.offer_id = offer.offer_id
--LEFT JOIN
--    (
--        SELECT
--            TO_NUMBER(vsub.billing_subscr_id) AS "BILLING_SUBSCR_ID",
--            TO_CHAR(vsub.subscr_id) AS "SUBSCR_ID",
--            TO_CHAR(vsub.sales_id || '-' || vsub.sales_name_cht) AS "SALES",
--            vsub.prod_name
--        FROM
--            v_subscr_info vsub
--        WHERE
--            vsub.prod_name LIKE '%365%'
--        GROUP BY
--            vsub.billing_subscr_id,
--            vsub.subscr_id,
--            TO_CHAR(vsub.sales_id || '-' || vsub.sales_name_cht),
--            vsub.prod_name
--    ) h ON c.subscr_id = h.billing_subscr_id
--ORDER BY
--    e.elem2,
--    c.subscr_id;

SELECT distinct
    TO_CHAR(h.subscr_id) || ',' ||
    e.elem2 || ',' ||
    e.elem6 || ',' ||
    f.param_value || ',' ||
    h.sales || ',"' ||
    offer.offer_name || '",' ||
    to_char(a.bill_from_date,'yyyymmdd') || ',' ||
    to_char(a.bill_end_date,'yyyymmdd') || ',' ||
    a.bill_period || ',' ||
    device_count.param_value || ',' ||
    rc_rate.param_value || ',' ||
    g.amount || ',' ||
    a.bill_Seq || ',' ||
    c.acct_id || ',' ||
    c.subscr_id || ',' ||
    g.offer_seq
FROM
    fy_tb_bl_bill_cntrl a
JOIN
    fy_tb_cm_subscr c ON a.CYCLE in (10,15,20) and a.CREATE_USER = 'UBL' and a.bill_period = to_char(trunc(add_months(sysdate,-1)),'yyyymm')
JOIN
    fy_tb_cm_prof_link e ON c.acct_id = e.entity_id AND e.entity_type = 'A' AND e.prof_type = 'NAME' AND e.link_type = 'A'
JOIN
    fy_Tb_cm_offer_param f ON c.acct_id = f.acct_id and c.subscr_id = f.subscr_id and f.param_name = 'NAME'
JOIN
    (
        SELECT
            bill_seq,
            cycle,
            SUM(amount) amount,
            subscr_id,
            offer_id,
            offer_seq
        FROM
            fy_tb_bl_bill_ci
        WHERE
            source = 'RC'
        GROUP BY
            bill_seq,
            cycle,
            subscr_id,
            offer_id,
            offer_seq
    ) g ON a.bill_seq = g.bill_seq AND a.CYCLE = g.CYCLE and c.subscr_id = g.subscr_id
JOIN
    fy_tb_bl_bill_offer_param rc_rate ON c.acct_id = rc_rate.acct_id and g.offer_seq = rc_rate.offer_seq and rc_rate.param_name LIKE 'RC_RATE1%'
JOIN
    fy_tb_bl_bill_offer_param device_count ON c.acct_id = device_count.acct_id and g.offer_seq = device_count.offer_seq and device_count.param_name = 'DEVICE_COUNT'
JOIN
    fy_tb_pbk_offer offer ON g.offer_id = offer.offer_id
LEFT JOIN
    (
        SELECT
            TO_NUMBER(vsub.billing_subscr_id) AS "BILLING_SUBSCR_ID",
            TO_CHAR(vsub.subscr_id) AS "SUBSCR_ID",
            TO_CHAR(vsub.sales_id || '-' || vsub.sales_name_cht) AS "SALES",
            vsub.prod_name
        FROM
            v_subscr_info vsub
        WHERE
            vsub.prod_name LIKE '%365%'
        GROUP BY
            vsub.billing_subscr_id,
            vsub.subscr_id,
            TO_CHAR(vsub.sales_id || '-' || vsub.sales_name_cht),
            vsub.prod_name
    ) h ON c.subscr_id = h.billing_subscr_id
;

spool off

exit;
EOF`
echo "Gen Report_BL End"|tee -a ${logFile}
}


function formatterReport_BL
{
grep -v '^$' ${reportFileName_BL}.dat > ${ReportDir}/${reportFileName_BL}.csv
rm ${reportFileName_BL}.dat
}

function sendFinalMail
{
send_msg="<SR264001_HGBN_o365_Report> $sysd"
	iconv -f utf8 -t big5 -c ${reportFileName_BL}.csv > ${reportFileName_BL}.big5
	mv ${reportFileName_BL}.big5 ${reportFileName_BL}_$sysd.csv
	rm ${reportFileName_BL}.csv

mailx -s "${send_msg}" -a ${reportFileName_BL}_$sysd.csv "${mailList}" <<EOF
Dears,

   SR264001_客戶o365產品數量暨到期日資訊報表已產出。
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
genReport_BL

#formatter Report 
echo "Formatter Report Start"|tee -a ${logFile}
formatterReport_BL
echo "Formatter Report End"|tee -a ${logFile}

#send final mail
sendFinalMail
echo "Gen ${reportFileName_BL} End" | tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
