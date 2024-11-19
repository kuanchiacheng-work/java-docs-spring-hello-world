#!/usr/bin/env bash
########################################################################################
# Program name : SR276169.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2024/10/23 Create by Mike Kuan
# Description : SR276169_HGBN_BA_Close_Report
########################################################################################

export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
progName=$(basename $0 .sh)
sysdt=`date +%Y%m%d%H%M%S`
sysd=`date +%Y%m --date="-1 month"`
#sysd=202303
HomeDir=/extsoft/UBL/BL
WorkDir=$HomeDir/Surrounding/RPT
ReportDir=$WorkDir/report
ReportDirBak=$ReportDir/bak
LogDir=$WorkDir/log
logFile=$LogDir/${progName}_${sysdt}.log
tempFile=$LogDir/${progName}_tmp_${sysdt}.log
reportFileName="P276169_HGBN_BA_Close_Report_`date +%Y%m%d`"
utilDir=/cb/BCM/util
ftpProg=${utilDir}/Ftp2Remote.sh
mailList="huwechang@fareastone.com.tw chimihsu@fareastone.com.tw esung@fareastone.com.tw mikekuan@fareastone.com.tw"
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
"pet-hgbap01p"|"pet-hgbap02p") #(PET)
DB="HGBBL"
RPTDB="HGBBLRPT"
OCS_AP="prdbl2"
;;
"idc-hgbap01p"|"idc-hgbap02p") #(PROD)
DB="HGBBL"
RPTDB="HGBBLRPT"
OCS_AP="prdbl2"
#putpass1=`/cb/CRYPT/GetPw.sh UBL_UAR_FTP`
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

select 'CYCLE'||','||'ACCT_ID'||','||'AR_BALANCE'||','||'CREDIT_DATE'||','||'AMOUNT'||','||'CHARGE_CODE'||','||'CREDIT_REASON'||','||'CREDIT_ID' from dual;

--SELECT DISTINCT ba.cycle, ba.acct_id, fet1_account.ar_balance,
--                TO_CHAR (fet1_customer_credit.credit_date, 'YYYY/MM/DD'),
--                decode(fet1_customer_credit.tax_rate,0.05,round(fet1_customer_credit.amount*1.05,2),fet1_customer_credit.amount) AS amount,
--                fet1_customer_credit.charge_code AS charge_code,
--                fet1_customer_credit.credit_reason AS credit_reason,
--                TO_CHAR(fet1_customer_credit.credit_id) AS credit_id
--FROM (
--    SELECT * 
--    FROM fy_tb_bl_account ba
--    WHERE ba.BL_STATUS = 'CLOSE'
--) ba
--JOIN fy_Tb_bl_cycle bc ON bc.CYCLE = ba.CYCLE
--JOIN fet1_account ON ba.acct_id = fet1_account.account_id
--JOIN fet1_customer_credit ON fet1_account.partition_id = fet1_customer_credit.partition_id
--                         AND fet1_account.account_id = fet1_customer_credit.account_id
--JOIN fet1_credit_reason ON fet1_customer_credit.credit_reason = fet1_credit_reason.credit_reason_code
--WHERE bc.cycle IN (10, 15, 20)
--  AND fet1_customer_credit.credit_reason IS NOT NULL
--  AND fet1_customer_credit.credit_reason NOT IN (
--      SELECT refund_reason_code
--      FROM fet1_refund_reason
--      WHERE reversal_indicator = 'Y'
--  )
--  AND (
--      (fet1_credit_reason.category_code = 'D' AND fet1_customer_credit.credit_reason IN ('DP-0', 'DP-8'))
--      OR fet1_credit_reason.category_code != 'D'
--  )
--  AND fet1_customer_credit.credit_date >= trunc(add_months(sysdate, -1), 'MM')
--  AND fet1_customer_credit.charge_code not like 'ROUND%'
--UNION
--SELECT DISTINCT ba.cycle, ba.acct_id, fet1_account.ar_balance, TO_CHAR (ci.chrg_date, 'YYYY/MM/DD'), ci.amount, ci.charge_code,
--                'OC' credit_reason, 'N/A' credit_id
--           FROM (
--    SELECT * 
--    FROM fy_tb_bl_account ba
--    WHERE ba.BL_STATUS = 'CLOSE'
--) ba
--JOIN fy_Tb_bl_cycle bc ON bc.CYCLE = ba.CYCLE
--JOIN fy_tb_bl_bill_ci ci ON ba.acct_id = ci.acct_id
--JOIN fet1_account ON ba.acct_id = fet1_account.account_id
--            AND ci.bill_seq IS NULL
--            AND ci.chrg_date >= trunc(add_months(sysdate, -1), 'MM');

SELECT DISTINCT ba.cycle || ',' || ba.acct_id || ',' || fet1_account.ar_balance || ',' ||
                TO_CHAR (fet1_customer_credit.credit_date, 'YYYY/MM/DD') || ',' ||
                decode(fet1_customer_credit.tax_rate,0.05,round(fet1_customer_credit.amount*1.05,2),fet1_customer_credit.amount) || ',' ||
                fet1_customer_credit.charge_code || ',' ||
                fet1_customer_credit.credit_reason || ',' ||
                TO_CHAR(fet1_customer_credit.credit_id) xx
FROM (
    SELECT * 
    FROM fy_tb_bl_account ba
    WHERE ba.BL_STATUS = 'CLOSE'
) ba
JOIN fy_Tb_bl_cycle bc ON bc.CYCLE = ba.CYCLE
JOIN fet1_account ON ba.acct_id = fet1_account.account_id
JOIN fet1_customer_credit ON fet1_account.partition_id = fet1_customer_credit.partition_id
                         AND fet1_account.account_id = fet1_customer_credit.account_id
JOIN fet1_credit_reason ON fet1_customer_credit.credit_reason = fet1_credit_reason.credit_reason_code
WHERE bc.cycle IN (10, 15, 20)
  AND fet1_customer_credit.credit_reason IS NOT NULL
  AND fet1_customer_credit.credit_reason NOT IN (
      SELECT refund_reason_code
      FROM fet1_refund_reason
      WHERE reversal_indicator = 'Y'
  )
  AND (
      (fet1_credit_reason.category_code = 'D' AND fet1_customer_credit.credit_reason IN ('DP-0', 'DP-8'))
      OR fet1_credit_reason.category_code != 'D'
  )
  AND fet1_customer_credit.credit_date >= trunc(add_months(sysdate, -1), 'MM')
  AND fet1_customer_credit.charge_code not like 'ROUND%'
UNION
SELECT DISTINCT ba.cycle || ',' || ba.acct_id || ',' || fet1_account.ar_balance || ',' || TO_CHAR (ci.chrg_date, 'YYYY/MM/DD') || ',' || ci.amount || ',' || ci.charge_code || ',' || 'OC' || ',' || 'N/A' xx
           FROM (
    SELECT * 
    FROM fy_tb_bl_account ba
    WHERE ba.BL_STATUS = 'CLOSE'
) ba
JOIN fy_Tb_bl_cycle bc ON bc.CYCLE = ba.CYCLE
JOIN fy_tb_bl_bill_ci ci ON ba.acct_id = ci.acct_id
JOIN fet1_account ON ba.acct_id = fet1_account.account_id
            AND ci.bill_seq IS NULL
            AND ci.chrg_date >= trunc(add_months(sysdate, -1), 'MM');

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
send_msg="<SR276169>HGBN_BA_Close_Report $sysd"
	#iconv -f utf8 -t big5 -c ${reportFileName}.txt > ${reportFileName}.big5
	#mv ${reportFileName}.big5 ${reportFileName}.txt
	#rm ${reportFileName}.dat
mailx -s "${send_msg}" -a ${ReportDirBak}/${reportFileName}.csv ${mailList} <<EOF
Dears,

   SR276169已產出。
   檔名：
   ${reportFileName}.csv
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

function sendGenTempErrorMail
{
send_msg="<SR276169>HGBN_BA_Close_Report $sysd"
mailx -s "${send_msg} Gen Data Have Abnormal " ${mailList} <<EOF
Dear All,
  
  SR276169未產出。
  
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
#formatter Report 
echo "Formatter Report Start"|tee -a ${logFile}
formatterReport
echo "Formatter Report End"|tee -a ${logFile}


#check gen report
filecnt1=`ls ${ReportDir}/${reportFileName}.csv|wc -l`
sleep 5
if [[ (${filecnt1} = 0 ) ]] ; then
	echo "${progName} Generated Report Have Abnormal"|tee -a ${logFile}
	sendGenTempErrorMail
	exit 0
else
	echo "Move Report TO Bak"|tee -a ${logFile}
	mv "${reportFileName}.csv" ${ReportDirBak}
	sendFinalMail
fi
sleep 5

echo "Gen ${reportFileName} End" | tee -a ${logFile}
echo $sysdt|tee -a ${logFile}
