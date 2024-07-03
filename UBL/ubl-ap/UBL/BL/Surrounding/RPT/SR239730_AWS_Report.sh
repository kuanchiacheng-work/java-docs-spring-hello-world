#!/usr/bin/env bash
########################################################################################
# Program name : SR239730_HGBN_AWS_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2021/08/09 Created by Mike Kuan
# Description : SR239730_AWS_Report
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
reportFileName="SR239730_HGBN_AWS_Report"
mailList="EBU-SIPMD-CLDITSM-HBDCLD@local.fareastone.com.tw mikekuan@fareastone.com.tw"
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

spool SR239730_HGBN_AWS_Report.dat

select '客戶名稱'||','||'用戶編號'||','||'比例/百分比%'||','||'統一編號'||','||'Account_ID'||','||'服務類型'||','||'業務員'||','||'出帳年月'||','||'營收(含稅)'||','||'出帳起'||','||'出帳迄'||','||'HSR起'||','||'HSR迄'||','||'BILLING用戶編號' from dual;

--SELECT   e.elem2 AS "客戶名稱", TO_CHAR (h.subscr_id) AS "用戶編號",
--         h.fee_percent AS "比例/百分比%", e.elem6 AS "統一編號",
--         to_char(d.RESOURCE_VALUE) AS "AWS_Account ID", h.po_name AS "服務類型",
--         h.sales AS "業務員", g.bill_period AS "出帳年月",
--         g.tot_amt AS "營收(含稅)", a.bill_from_date AS "出帳起", a.bill_end_date AS "出帳迄",
--         h.hsr_from_date AS "HSR起", h.hsr_end_date AS "HSR迄", c.subscr_id AS "BILLING用戶編號"
--    FROM fy_tb_bl_bill_cntrl a,
--         fy_tb_cm_subscr c,
--         fy_tb_cm_resource d,
--         fy_tb_cm_prof_link e,
--         fy_tb_bl_bill_mast g,
--         (SELECT   distinct TO_NUMBER (vsub.billing_subscr_id) AS "BILLING_SUBSCR_ID",
--         TO_CHAR (vsub.subscr_id) AS "SUBSCR_ID",
--         TO_CHAR (vsub.sales_id || '-' || vsub.sales_name_cht) AS "SALES",
--         vaws.po_name, vaws.fee_percent,
--         MAX (TRUNC (vaws.start_date)) AS "HSR_FROM_DATE",
--         TRUNC (vaws.stop_date) AS "HSR_END_DATE"
--    FROM v_subscr_info vsub, (select * from (
--select a.*,row_number() over (PARTITION BY subscr_id order by start_date desc) sn from v_aws_info a) R
--where r.sn=1
--order by r.subscr_id) vaws
--   WHERE vsub.subscr_id = vaws.subscr_id
--GROUP BY vsub.billing_subscr_id,
--         vsub.subscr_id,
--         TO_CHAR (vsub.sales_id || '-' || vsub.sales_name_cht),
--         vaws.po_name,
--         vaws.fee_percent,
--         vaws.stop_date) h
--   WHERE c.acct_id = e.entity_id
--     AND e.entity_type = 'A'
--     AND e.prof_type = 'NAME'
--     AND e.link_type = 'A'
--     AND c.subscr_id = d.subscr_id
--     AND c.acct_id = g.acct_id
--     AND d.resource_prm_cd IN ('AWSID')
--     AND g.CYCLE = 10
--     AND a.CYCLE = g.CYCLE
--     AND a.bill_seq = g.bill_seq
--     AND h.hsr_from_date(+) <= a.bill_end_date
--     AND DECODE (h.hsr_end_date(+), NULL, a.bill_end_date, h.hsr_end_date(+))
--            > a.bill_from_date
--     AND c.subscr_id = h.billing_subscr_id(+)
--     AND g.bill_period = to_char(add_months(trunc(sysdate,'mm'),-1),'yyyymm')
----AND TO_NUMBER (c.subscr_id) = 300001147
--ORDER BY e.elem2,c.subscr_id

--SELECT   e.elem2 AS "客戶名稱", TO_CHAR (h.subscr_id) AS "用戶編號",
--         h.fee_percent AS "比例/百分比%", e.elem6 AS "統一編號",
--         to_char(d.RESOURCE_VALUE) AS "AWS_Account ID", h.po_name AS "服務類型",
--         h.sales AS "業務員", a.bill_period AS "出帳年月",
--         g.amount AS "營收(含稅)", a.bill_from_date AS "出帳起", a.bill_end_date AS "出帳迄",
--         h.hsr_from_date AS "HSR起", h.hsr_end_date AS "HSR迄", c.subscr_id AS "BILLING用戶編號"
--    FROM fy_tb_bl_bill_cntrl a,
--         fy_tb_cm_subscr c,
--         fy_tb_cm_resource d,
--         fy_tb_cm_prof_link e,
--         (select bill_seq,cycle,sum(amount) amount,subscr_id from fy_tb_bl_bill_ci where source='UC' group by bill_seq,cycle,subscr_id) g,
--         (SELECT   distinct TO_NUMBER (vsub.billing_subscr_id) AS "BILLING_SUBSCR_ID",
--         TO_CHAR (vsub.subscr_id) AS "SUBSCR_ID",
--         TO_CHAR (vsub.sales_id || '-' || vsub.sales_name_cht) AS "SALES",
--         vaws.po_name, vaws.fee_percent,
--         MAX (TRUNC (vaws.start_date)) AS "HSR_FROM_DATE",
--         TRUNC (vaws.stop_date) AS "HSR_END_DATE"
--    FROM v_subscr_info vsub, (select * from (
--select a.*,row_number() over (PARTITION BY subscr_id order by start_date desc) sn from v_aws_info a) R
--where r.sn=1
--order by r.subscr_id) vaws
--   WHERE vsub.subscr_id = vaws.subscr_id
--GROUP BY vsub.billing_subscr_id,
--         vsub.subscr_id,
--         TO_CHAR (vsub.sales_id || '-' || vsub.sales_name_cht),
--         vaws.po_name,
--         vaws.fee_percent,
--         vaws.stop_date) h
--   WHERE c.acct_id = e.entity_id
--     AND e.entity_type = 'A'
--     AND e.prof_type = 'NAME'
--     AND e.link_type = 'A'
--     AND c.subscr_id = d.subscr_id
--     AND c.subscr_id = g.subscr_id
--     AND d.resource_prm_cd IN ('AWSID')
--     AND g.CYCLE = 10
--     AND a.CYCLE = g.CYCLE
--     AND a.bill_seq = g.bill_seq
--     --and g.source='UC'
--     AND h.hsr_from_date(+) <= a.bill_end_date
--     AND DECODE (h.hsr_end_date(+), NULL, a.bill_end_date, h.hsr_end_date(+))
--            > a.bill_from_date
--     AND c.subscr_id = h.billing_subscr_id(+)
--     AND a.bill_period = to_char(add_months(trunc(sysdate,'mm'),-1),'yyyymm')
----AND TO_NUMBER (c.subscr_id) = 300001147
----group by e.elem2 , TO_CHAR (h.subscr_id),
----         h.fee_percent , e.elem6 ,
----         d.RESOURCE_VALUE , h.po_name ,
----         h.sales, a.bill_period,
----         a.bill_from_date, a.bill_end_date ,
----         h.hsr_from_date, h.hsr_end_date , c.subscr_id 
--ORDER BY e.elem2,c.subscr_id

SELECT      e.elem2
         || ','
         || TO_CHAR (h.subscr_id)
         || ','
         || h.fee_percent
         || ','
         || '="'||to_char(e.elem6)||'"'
         || ','
         || '="'||to_char(d.RESOURCE_VALUE)||'"'
         || ','
         || h.po_name
         || ','
         || h.sales
         || ','
         || a.bill_period
         || ','
         || g.amount
         || ','
         || a.bill_from_date
         || ','
         || a.bill_end_date
         || ','
         || h.hsr_from_date
         || ','
         || h.hsr_end_date
         || ','
         || c.subscr_id
    FROM fy_tb_bl_bill_cntrl a,
         fy_tb_cm_subscr c,
         fy_tb_cm_resource d,
         fy_tb_cm_prof_link e,
         (select bill_seq,cycle,sum(amount) amount,subscr_id from fy_tb_bl_bill_ci where source='UC' group by bill_seq,cycle,subscr_id) g,
         (SELECT   distinct TO_NUMBER (vsub.billing_subscr_id) AS "BILLING_SUBSCR_ID",
         TO_CHAR (vsub.subscr_id) AS "SUBSCR_ID",
         TO_CHAR (vsub.sales_id || '-' || vsub.sales_name_cht) AS "SALES",
         vaws.po_name, vaws.fee_percent,
         MAX (TRUNC (vaws.start_date)) AS "HSR_FROM_DATE",
         TRUNC (vaws.stop_date) AS "HSR_END_DATE"
    FROM v_subscr_info vsub, (select * from (
select a.*,row_number() over (PARTITION BY subscr_id order by start_date desc) sn from v_aws_info a) R
where r.sn=1
order by r.subscr_id) vaws
   WHERE vsub.subscr_id = vaws.subscr_id
GROUP BY vsub.billing_subscr_id,
         vsub.subscr_id,
         TO_CHAR (vsub.sales_id || '-' || vsub.sales_name_cht),
         vaws.po_name,
         vaws.fee_percent,
         vaws.stop_date) h
   WHERE c.acct_id = e.entity_id
     AND e.entity_type = 'A'
     AND e.prof_type = 'NAME'
     AND e.link_type = 'A'
     AND c.subscr_id = d.subscr_id
     AND c.subscr_id = g.subscr_id
     AND d.resource_prm_cd IN ('AWSID')
     AND g.CYCLE = 10
     AND a.CYCLE = g.CYCLE
     AND a.bill_seq = g.bill_seq
     AND h.hsr_from_date(+) <= a.bill_end_date
     AND DECODE (h.hsr_end_date(+), NULL, a.bill_end_date, h.hsr_end_date(+))
            > a.bill_from_date
     AND c.subscr_id = h.billing_subscr_id(+)
     AND a.bill_period = to_char(add_months(trunc(sysdate,'mm'),-1),'yyyymm')
ORDER BY e.elem2,c.subscr_id
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
send_msg="<SR239730_HGBN_AWS_Report> $sysd"
	iconv -f utf8 -t big5 -c ${reportFileName}.csv > ${reportFileName}.big5
	mv ${reportFileName}.big5 ${reportFileName}_$sysd.csv
	rm ${reportFileName}.csv
mailx -s "${send_msg}" -a ${reportFileName}_$sysd.csv "${mailList}" <<EOF
Dears,

   SR239730_HGBN_AWS_Report已產出。
   檔名：
   ${reportFileName}.csv

EOF
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
echo "Gen ${reportFileName} Start" | tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
cd $ReportDir
genReport

#formatter Report 
echo "Formatter Report Start"|tee -a ${logFile}
formatterReport
echo "Formatter Report End"|tee -a ${logFile}

#send final mail
sendFinalMail
echo "Gen ${reportFileName} End" | tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
