#!/usr/bin/env bash
########################################################################################
# Program name : SR265840_Azure_Product_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2023/12/22 Modify by Mike Kuan
# Description : new

export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
WorkDir="/extsoft/UBL/BL/Surrounding/RPT"
logDir=${WorkDir}/log
ReportDir=${WorkDir}/report
ReportDirBak=${ReportDir}/bak
cycleInfoDir=${WorkDir}/cycleInfos
progName=$(basename $0 .sh)
echo "Program Name is:${progName}"
sysd=`date "+%Y%m%d"`
logFile=${logDir}/"${progName}_${sysd}.log"
processCycle=`date +%Y%m15`
#processCycle=$1
utilDir="/cb/BCM/util"
ftpProg="${utilDir}/Ftp2Remote.sh"
tempFile1=${logDir}/"${progName}_tmp_${sysd}.log"
reportFileName1="SR265840_Azure_Product_Report"
sysdate=$(date +"%Y%m%d%H%M%S")
#DB info (TEST06) (PT)
#--DB="HGBBLDEV"
#--DB="HGBDEV2"
#DB info (TEST15) (SIT)
#--DB="HGBBLSIT"
#--RPTDB_SID="HGBBLSIT"
#DB info (TEST02) (UAT)
#--DB="HGBBLUAT"
#--RPTDB_SID="HGBBLUAT"
#DB info (PROD)
DB="HGBBL"
RPTDB_SID="HGBBLRPT"
DBID=`/cb/CRYPT/GetId.sh $DB`
DBPWD=`/cb/CRYPT/GetPw.sh $DB`
#Ftp 
#putip1='10.68.57.184'
putip1='10.68.158.197'
putuser1=hgftp
putpass1=hgftp123
putpath1=/HomeGrown
#MAIL
mailList="mikekuan@fareastone.com.tw PeterChen1@fareastone.com.tw"
#mailList="mikekuan@fareastone.com.tw"

function genSettlementReport
{
`sqlplus -s ${DBID}/${DBPWD}@${RPTDB_SID} > ${tempFile1} <<EOF
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

spool output.dat

select 'ACCT_ID','HAID','SUBSCR_ID','客戶名稱','統編','產品品項','產品ChargeStartDate','產品ChargeEndDate','週期性收費月份','產品數量','收入單價','BILL_NBR','收入總金額','上期已繳款' from dual;

--SELECT distinct
--    c.acct_id,
--    to_char(re.RESOURCE_VALUE) AS "HAID",
--    c.subscr_id,
--    --g.offer_seq,
--    e.elem6 AS "統編",
--    --h.sales AS "負責業務員",
--    offer.offer_name AS "產品品項",
--    to_char(a.bill_from_date,'yyyymmdd') AS "產品ChargeStartDate",
--    to_char(a.bill_end_date,'yyyymmdd') AS "產品ChargeEndDate",
--    a.bill_period AS "週期性收費月份",
--    device_count.param_value AS "產品數量",
--    rc_rate.param_value AS "收入單價",
--    ma.bill_nbr,
--    g.amount AS "收入總金額",
--    decode(ma.paid_amt,0,'N','Y') "上期已繳款"
--    --a.bill_Seq
--FROM
--    fy_tb_bl_bill_cntrl a
--JOIN
--    fy_tb_cm_subscr c ON a.CYCLE in (15) and a.CREATE_USER = 'UBL' and a.bill_period = to_char(trunc(add_months(sysdate,-1)),'yyyymm')
--JOIN    
--    fy_tb_cm_resource re ON c.subscr_id = re.subscr_id
--JOIN
--    fy_tb_cm_prof_link e ON c.acct_id = e.entity_id AND e.entity_type = 'A' AND e.prof_type = 'NAME' AND e.link_type = 'A'
--JOIN
--    fy_tb_bl_bill_mast ma ON c.acct_id = ma.acct_id AND a.bill_seq = ma.bill_seq AND a.CYCLE = ma.CYCLE    
--JOIN
--    (
--        SELECT
--            bill_seq,
--            cycle,
--            amount,
--            subscr_id,
--            offer_id,
--            offer_seq
--        FROM
--            fy_tb_bl_bill_ci
--    ) g ON a.bill_seq = g.bill_seq AND a.CYCLE = g.CYCLE and c.subscr_id = g.subscr_id
--LEFT JOIN
--    fy_tb_bl_bill_offer_param rc_rate ON c.acct_id = rc_rate.acct_id and g.offer_seq = rc_rate.offer_seq and rc_rate.param_name LIKE 'RC_RATE1%'
--LEFT JOIN
--    fy_tb_bl_bill_offer_param device_count ON c.acct_id = device_count.acct_id and g.offer_seq = device_count.offer_seq and device_count.param_name = 'DEVICE_COUNT'
--JOIN
--    fy_tb_pbk_offer offer ON g.offer_id = offer.offer_id and offer_name like '%Azure%'
--ORDER BY
--    e.elem2,
--    c.subscr_id;

SELECT distinct
    TO_CHAR(c.acct_id) || ',' ||
    TO_CHAR(re.RESOURCE_VALUE) || ',' ||
    TO_CHAR(c.subscr_id) || ',''' ||
    e.elem2 || ''',' ||
    e.elem6 || ',''' ||
    offer.offer_name || ''',' ||
    to_char(a.bill_from_date,'yyyymmdd') || ',' ||
    to_char(a.bill_end_date,'yyyymmdd') || ',' ||
    TO_CHAR(a.bill_period) || ',' ||
    TO_CHAR(device_count.param_value) || ',' ||
    TO_CHAR(rc_rate.param_value) || ',' ||
    ma.bill_nbr || ',' ||
    TO_CHAR(g.amount) || ',' ||
    decode(ma.paid_amt,0,'N','Y')
FROM
    fy_tb_bl_bill_cntrl a
JOIN
    fy_tb_cm_subscr c ON a.CYCLE in (15) and a.CREATE_USER = 'UBL' and a.bill_period = to_char(trunc(add_months(sysdate,-1)),'yyyymm')
JOIN    
    fy_tb_cm_resource re ON c.subscr_id = re.subscr_id
JOIN
    fy_tb_cm_prof_link e ON c.acct_id = e.entity_id AND e.entity_type = 'A' AND e.prof_type = 'NAME' AND e.link_type = 'A'
JOIN
    fy_tb_bl_bill_mast ma ON c.acct_id = ma.acct_id AND a.bill_seq = ma.bill_seq AND a.CYCLE = ma.CYCLE    
JOIN
    (
        SELECT
            bill_seq,
            cycle,
            amount,
            subscr_id,
            offer_id,
            offer_seq
        FROM
            fy_tb_bl_bill_ci
    ) g ON a.bill_seq = g.bill_seq AND a.CYCLE = g.CYCLE and c.subscr_id = g.subscr_id
LEFT JOIN
    fy_tb_bl_bill_offer_param rc_rate ON c.acct_id = rc_rate.acct_id and g.offer_seq = rc_rate.offer_seq and rc_rate.param_name LIKE 'RC_RATE1%'
LEFT JOIN
    fy_tb_bl_bill_offer_param device_count ON c.acct_id = device_count.acct_id and g.offer_seq = device_count.offer_seq and device_count.param_name = 'DEVICE_COUNT'
JOIN
    fy_tb_pbk_offer offer ON g.offer_id = offer.offer_id and offer_name like '%Azure%'
;

spool off

exit;

EOF`

echo "Gen Azure_Product_Report SQL End"|tee -a ${logFile}
}

function formatterSettlementReport
{
grep -v '^$' output.dat > ${ReportDir}/${reportFileName1}_${processCycle}.csv
}

#function sendFinalMail
#{
#mailx -s "[${processCycle}]${progName} Finished " ${mailList} <<EOF
#Dear All,
#  
#  Please check SR265840_Azure_Product_Report at ${WorkDir}/report/bak !!!
#  
#(請注意：此郵件為系統自動傳送，請勿直接回覆！)
#(Note: Please do not reply to messages sent automatically.)
#EOF
#}

function sendFinalMail
{
send_msg="<SR265840_Azure_Product_Report> $sysd"
	iconv -f utf8 -t big5 -c ${ReportDir}/${reportFileName1}_${processCycle}.csv > ${ReportDir}/${reportFileName1}_${processCycle}.big5
	mv ${ReportDir}/${reportFileName1}_${processCycle}.big5 ${ReportDir}/${reportFileName1}_${processCycle}_$sysd.csv
	rm ${ReportDir}/${reportFileName1}_${processCycle}.csv

mailx -s "${send_msg}" -a ${ReportDir}/${reportFileName1}_${processCycle}_$sysd.csv "${mailList}" <<EOF
Dears,

   SR265840_Azure_Product_Report已產出。
   檔名：
   ${reportFileName_BL}.csv

EOF
}

function sendGenTempErrorMail
{
mailx -s "[${processCycle}]${progName} Gen Data Have Abnormal " ${mailList} <<EOF
Dear All,
  
  Please check ${progName} Flow !!!
  
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

###########################################################
#      main
###########################################################
echo "Gen SR265840_Azure_Product_Report Start" | tee -a ${logFile}
echo $sysdate|tee -a ${logFile}

#Step1. split param
cycleYear=$(echo $processCycle | cut -c1-4)
cycleMonth=$(echo $processCycle | cut -c5-6)
cycleDate=$(echo $processCycle | cut -c7-8)
echo "CycleYear:"${cycleYear} "CycleMonth:"${cycleMonth} | tee -a ${logFile}

#Step 5.chek genTempData if have Error
grep -E 'ERROR|error|ORA|ora' ${logFile} | wc -l | read ora_err_cnt
if [[ ${ora_err_cnt} -eq 0 ]] ; then
	echo "database check success" | tee -a ${logFile}
	#Step 5.1 gen Report 1&2&3
	echo "Generate Real SR265840_Azure_Product_Report Report" | tee -a ${logFile} 
	cd $ReportDir
	 genSettlementReport $processCycle
else 
	#Step 5.2 send genTmep error message
	echo "Send GenTempDate Abnormal message"| tee -a ${logFile} 
	sendGenTempErrorMail
	exit 0
fi

#Step 6.formatter Report 
echo "Formatter formatterSettlementReport"|tee -a ${logFile}
formatterSettlementReport

echo "Check Generate Report"|tee -a ${logFile}

#Step 7.check gen report
filecnt1=`ls ${ReportDir}/${reportFileName1}_${processCycle}.csv|wc -l`
file1=${ReportDir}/${reportFileName1}_${processCycle}.csv

if [[ (${filecnt1} = 0 ) ]] ; then
	echo "${progName} Generated Report Have Abnormal"|tee -a ${logFile}
	sendGenTempErrorMail
	exit 0
else
	echo "FTP Report"|tee -a ${logFile}
	#echo "Run Command: ${ftpProg} ${putip1} ${putuser1} ******** ${ReportDir} ${putpath1} ${reportFileName1}_${processCycle}.csv 0" | tee -a ${logFile}
	#	${ftpProg} ${putip1} ${putuser1} ${putpass1} ${ReportDir} ${putpath1} ${reportFileName1}_${processCycle}.csv 0
	echo "send SR213344_NPEP_Settlement_Report"|tee -a ${logFile}
	#Step 8. send final mail
	sendFinalMail
	echo "Move Report TO Bak"|tee -a ${logFile}
	mv ${ReportDir}/"${reportFileName1}_${processCycle}_$sysd.csv" ${ReportDirBak}
fi

echo "Gen SR265840_Azure_Product_Report End"|tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
