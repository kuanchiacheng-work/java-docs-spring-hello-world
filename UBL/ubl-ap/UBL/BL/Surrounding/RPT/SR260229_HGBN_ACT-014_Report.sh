#!/usr/bin/env bash
########################################################################################
# Program name : SR260229_HGBN_ACT-014_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2023/05/09 Created by Mike Kuan
# Description : SR260229_Project-M Fixed line Phase I_ACT-014_新增線路明細
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
reportFileName="SR260229_HGBN_ACT-014_Report"
#mailList="emmachuang@fareastone.com.tw mikekuan@fareastone.com.tw"
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

spool SR260229_HGBN_ACT-014_Report.dat

select 'OFFER_SEQ'||','||'BI_SEQ'||','||'用戶名稱'||','||'用戶帳號'||','||'ACCOUNT_NO'||','||'帳單號碼'||','||'帳單日期'||','||'繳款截止日'||','||'服務號碼'||','||'服務項目'||','||'服務啟用日期'||','||'CHARGE_TYPE'||','||'CHARGE_ORG'||','||'CHARGE_AMT'||','||'帳單金額(含稅)' from dual;

/* Formatted on 2023/05/08 13:43 (Formatter Plus v4.8.8) */
--SELECT   distinct so.offer_seq, bi.bi_seq, g.bill_seq, e.elem2 AS "用戶名稱",
--         c.subscr_id AS "用戶帳號", g.acct_id "ACCOUNT_NO",
--         g.bill_nbr "帳單號碼", a.bill_date "帳單日期",
--         g.due_date "繳款截止日",
--                                 TO_CHAR (d.resource_value) AS "服務號碼",
--         bi.charge_descr "服務項目", so.eff_date "服務啟用日期", bi.charge_type "CHARGE_TYPE",decode(bi.charge_org,'RA','UC','CC','RC','DE') CHARGE_ORG,
--         bi.amount "CHARGE_AMT",
--         g.tot_amt AS "帳單金額(含稅)"
--    FROM fy_tb_bl_bill_cntrl a,
--         fy_tb_cm_subscr c,
--         fy_tb_cm_resource d,
--         fy_tb_cm_subscr_offer so,
--         fy_tb_cm_prof_link e,
--         fy_tb_bl_bill_mast g,
--         fy_tb_bl_bill_bi bi
--   WHERE c.acct_id = e.entity_id
--     AND e.entity_type = 'A'
--     AND e.prof_type = 'NAME'
--     AND e.link_type = 'A'
--     AND c.subscr_id = d.subscr_id
--     AND c.subscr_id = bi.subscr_id
--     AND c.subscr_id = so.subscr_id
--     AND c.acct_id = g.acct_id
--     AND c.acct_id = bi.acct_id(+)
--     AND bi.offer_id = so.offer_id
--     AND (bi.offer_seq is null or bi.offer_seq = so.offer_seq)
--     --AND d.resource_prm_cd IN ('AWSID','HAID')
--     AND bi.charge_code NOT IN ('ROUNDCHG5', 'ROUNDCHG0')
--     AND g.CYCLE IN (10, 15, 20)
--     AND a.CYCLE = g.CYCLE
--     AND a.CYCLE = bi.CYCLE(+)
--     AND a.bill_seq = g.bill_seq
--     AND a.bill_seq = bi.bill_seq(+)
--     AND so.eff_date >= TO_CHAR (ADD_MONTHS (TRUNC (SYSDATE, 'mm'), -2))
--     AND so.eff_date < TO_CHAR (ADD_MONTHS (TRUNC (SYSDATE, 'mm'), -1))
--     AND g.bill_period =
--                     TO_CHAR (ADD_MONTHS (TRUNC (SYSDATE, 'mm'), -2),
--                              'yyyymm')
----AND g.acct_id in (864835746)
--ORDER BY g.acct_id, e.elem2, c.subscr_id

SELECT DISTINCT    so.offer_seq
                || ','
                || g.bill_seq
                || ','
                || e.elem2
                || ','
                || c.subscr_id
                || ','
                || g.acct_id
                || ','
                || TO_NUMBER (g.bill_nbr)
                || ','
                || TO_CHAR (a.bill_date, 'yyyy/mm/dd')
                || ','
                || TO_CHAR (g.due_date, 'yyyy/mm/dd')
                || ','
                || TO_CHAR (d.resource_value)
                || ',"'
                || TO_CHAR (bi.charge_descr)
                || '",'
                || TO_CHAR (so.eff_date, 'yyyy/mm/dd')
                || ','
                || bi.charge_type
                || ','
                || DECODE (bi.charge_org, 'RA', 'UC', 'CC', 'RC', 'DE')
                || ','
                || bi.amount
                || ','
                || g.tot_amt
           FROM fy_tb_bl_bill_cntrl a,
                fy_tb_cm_subscr c,
                fy_tb_cm_resource d,
                fy_tb_cm_subscr_offer so,
                fy_tb_cm_prof_link e,
                fy_tb_bl_bill_mast g,
                fy_tb_bl_bill_bi bi
          WHERE c.acct_id = e.entity_id
            AND e.entity_type = 'A'
            AND e.prof_type = 'NAME'
            AND e.link_type = 'A'
            AND c.subscr_id = d.subscr_id
            AND c.subscr_id = bi.subscr_id
            AND c.subscr_id = so.subscr_id
            AND c.acct_id = g.acct_id
            AND c.acct_id = bi.acct_id(+)
            AND bi.offer_id = so.offer_id
            AND (bi.offer_seq IS NULL OR bi.offer_seq = so.offer_seq)
            --AND d.resource_prm_cd IN ('AWSID','HAID')
            AND bi.charge_code NOT IN ('ROUNDCHG5', 'ROUNDCHG0')
            AND g.CYCLE IN (10, 15, 20)
            AND a.CYCLE = g.CYCLE
            AND a.CYCLE = bi.CYCLE(+)
            AND a.bill_seq = g.bill_seq
            AND a.bill_seq = bi.bill_seq(+)
            AND so.eff_date >= TO_CHAR (ADD_MONTHS (TRUNC (SYSDATE, 'mm'), -2))
            AND so.eff_date < TO_CHAR (ADD_MONTHS (TRUNC (SYSDATE, 'mm'), -1))
            AND g.bill_period =
                     TO_CHAR (ADD_MONTHS (TRUNC (SYSDATE, 'mm'), -2),
                              'yyyymm');

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
send_msg="<SR260229_HGBN_ACT-014_Report> $sysd"
	iconv -f utf8 -t big5 -c ${reportFileName}.csv > ${reportFileName}.big5
	mv ${reportFileName}.big5 ${reportFileName}_$sysd.csv
	rm ${reportFileName}.csv
mailx -s "${send_msg}" -a ${reportFileName}_$sysd.csv "${mailList}" <<EOF
Dears,

   SR260229_HGBN_ACT-014_Report已產出。
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
