#!/usr/bin/env bash
########################################################################################
# Program name : SR213344_NPEP_Settlement_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2019/05/23 Modify by Mike Kuan
# Description : new
########################################################################################
# Date : 2019/06/24 Modify by Mike Kuan
# Description : add ftp information
########################################################################################
# Date : 2019/08/07 Modify by Mike Kuan
# Description : modify processCycle for cronjob
########################################################################################
# Date : 2019/08/27 Modify by Mike Kuan
# Description : modify date format
########################################################################################
# Date : 2019/09/17 Modify by Mike Kuan
# Description : modify CI condition
########################################################################################
# Date : 2019/10/17 Modify by Mike Kuan
# Description : add GCPID & GCPname
########################################################################################
# Date : 2023/09/15 Modify by Mike Kuan
# Description : add Azure, change FTP IP address
########################################################################################
# Date : 2023/12/22 Modify by Mike Kuan
# Description : adj report format
########################################################################################
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
processCycle=`date +%Y%m01`
#processCycle=$1
utilDir="/cb/BCM/util"
ftpProg="${utilDir}/Ftp2Remote.sh"
tempFile1=${logDir}/"${progName}_tmp_${sysd}.log"
reportFileName1="NPEP_Settlement_Report"
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

select 'CI_SEQ','RESOURCE_VALUE','ACCOUNT_NAME','OFFER_ID','MSISDN','AGREEMENT_NO','ACCOUNT_ID','INVOICE_ID','BILLING_INVOICE_NUMBER','INVOICE_CREATION_DATE','CHARGE_CODE','CHARGE_TYPE','AMOUNT','COVERAGE_PERIOD_START_DATE','COVERAGE_PERIOD_END_DATE','CYCLE_SEQ_NO','CYCLE_START_DATE','CYCLE_END_DATE','CYCLE_YEAR','CYCLE_MONTH','CYCLE_CODE' from dual;

SELECT DISTINCT to_char(f.ci_seq)||','|| d.resource_value||','''||to_char(d1.param_value)||''','||f.offer_id||','||
                d.resource_value||','||f.subscr_id||','||
                b.acct_id||','||b.mast_seq||','||
                to_char(b.bill_nbr)||','||
                TO_CHAR (b.create_date, 'yyyymmdd')||','||
                f.charge_code||','||f.charge_type||','||f.amount||','||
                CASE
                   WHEN f.SOURCE = 'RC'
                      THEN TO_CHAR (f.chrg_from_date, 'yyyymmdd')
                   WHEN f.SOURCE = 'OC'
                      THEN TO_CHAR (f.create_date, 'yyyymmdd')
                   WHEN f.SOURCE = 'UC'
                      THEN REGEXP_SUBSTR (f.dynamic_attribute,
                                             '.*First_Event_Date=([^#]*).*',
                                             1,
                                             1,
                                             NULL,
                                             1
                                            )
                END||','||
                CASE
                   WHEN f.SOURCE = 'RC'
                      THEN TO_CHAR (f.chrg_end_date, 'yyyymmdd')
                   WHEN f.SOURCE = 'OC'
                      THEN TO_CHAR (f.create_date, 'yyyymmdd')
                   WHEN f.SOURCE = 'UC'
                      THEN REGEXP_SUBSTR (f.dynamic_attribute,
                                             '.*Last_Event_Date=([^#]*).*',
                                             1,
                                             1,
                                             NULL,
                                             1)
                END||','||
                a.bill_seq||','||
                TO_CHAR (a.bill_from_date, 'yyyymmdd')||','||
                TO_CHAR (a.bill_end_date, 'yyyymmdd')||','||
                SUBSTR (a.bill_period, 1, 4)||','||
                SUBSTR (a.bill_period, 5, 3)||','||a.CYCLE
           FROM fy_tb_bl_bill_cntrl a,
                fy_tb_bl_bill_mast b,
                fy_tb_cm_subscr c,
                fy_tb_cm_resource d,
                (SELECT DISTINCT subscr_id, offer_seq, acct_id,
                FIRST_VALUE (param_value) OVER (PARTITION BY subscr_id ORDER BY seq_no DESC)
                                                                       AS param_value
           FROM fy_tb_cm_offer_param
          WHERE param_name in ('AWSname','NAME')) d1,
                fy_tb_bl_bill_ci f
          WHERE a.CYCLE = b.CYCLE
            AND a.bill_period = b.bill_period
            AND a.bill_seq = b.bill_seq
            and a.bill_seq = f.bill_seq
            AND b.acct_id = c.acct_id
            AND c.subscr_id = d.subscr_id
            and c.subscr_id = d1.subscr_id(+)
            AND c.subscr_id(+) = f.subscr_id
            and b.acct_id = f.acct_id
            AND d.resource_prm_cd in ('AWSID','GCPID')
            AND a.CYCLE = 10
            AND a.bill_date = TO_DATE ($1, 'yyyymmdd')
union all
SELECT DISTINCT to_char(f.ci_seq)||','|| d.resource_value||','||to_char(d.resource_value)||','||f.offer_id||','||
                d.resource_value||','||f.subscr_id||','||
                b.acct_id||','||b.mast_seq||','||
                to_char(b.bill_nbr)||','||
                TO_CHAR (b.create_date, 'yyyymmdd')||','||
                f.charge_code||','||f.charge_type||','||f.amount||','||
                CASE
                   WHEN f.SOURCE = 'RC'
                      THEN TO_CHAR (f.chrg_from_date, 'yyyymmdd')
                   WHEN f.SOURCE = 'OC'
                      THEN TO_CHAR (f.create_date, 'yyyymmdd')
                   WHEN f.SOURCE = 'UC'
                      THEN REGEXP_SUBSTR (f.dynamic_attribute,
                                             '.*First_Event_Date=([^#]*).*',
                                             1,
                                             1,
                                             NULL,
                                             1
                                            )
                END||','||
                CASE
                   WHEN f.SOURCE = 'RC'
                      THEN TO_CHAR (f.chrg_end_date, 'yyyymmdd')
                   WHEN f.SOURCE = 'OC'
                      THEN TO_CHAR (f.create_date, 'yyyymmdd')
                   WHEN f.SOURCE = 'UC'
                      THEN REGEXP_SUBSTR (f.dynamic_attribute,
                                             '.*Last_Event_Date=([^#]*).*',
                                             1,
                                             1,
                                             NULL,
                                             1)
                END||','||
                a.bill_seq||','||
                TO_CHAR (a.bill_from_date, 'yyyymmdd')||','||
                TO_CHAR (a.bill_end_date, 'yyyymmdd')||','||
                SUBSTR (a.bill_period, 1, 4)||','||
                SUBSTR (a.bill_period, 5, 3)||','||a.CYCLE
           FROM fy_tb_bl_bill_cntrl a,
                fy_tb_bl_bill_mast b,
                fy_tb_cm_subscr c,
                                fy_tb_cm_subscr_offer c2,
                fy_tb_cm_resource d,
                fy_tb_bl_bill_ci f
          WHERE a.CYCLE = b.CYCLE
            AND a.bill_period = b.bill_period
            AND a.bill_seq = b.bill_seq
            and a.bill_seq = f.bill_seq
            AND b.acct_id = c.acct_id
            AND c.subscr_id = d.subscr_id
            and c.subscr_id = c2.subscr_id
            AND c.subscr_id(+) = f.subscr_id
            and b.acct_id = f.acct_id
            AND d.resource_prm_cd in ('HAID')
            and c2.OFFER_ID = 203763
            AND a.CYCLE = 15
            AND a.bill_date = TO_DATE ($1, 'yyyymmdd')
;

spool off

exit;

EOF`

echo "Gen Settlement Report End"|tee -a ${logFile}
}

function formatterSettlementReport
{
grep -v '^$' output.dat > ${ReportDir}/${reportFileName1}_${processCycle}.csv
}

function sendFinalMail
{
mailx -s "[${processCycle}]${progName} Finished " ${mailList} <<EOF
Dear All,
  
  Please check SR213344_NPEP_Settlement_Report at ${WorkDir}/report/bak !!!
  
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
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
echo "Gen SR213344_NPEP_Settlement_Report Start" | tee -a ${logFile}
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
	echo "Generate Real Settlement Report" | tee -a ${logFile} 
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
	echo "Run Command: ${ftpProg} ${putip1} ${putuser1} ******** ${ReportDir} ${putpath1} ${reportFileName1}_${processCycle}.csv 0" | tee -a ${logFile}
		${ftpProg} ${putip1} ${putuser1} ${putpass1} ${ReportDir} ${putpath1} ${reportFileName1}_${processCycle}.csv 0
	echo "send SR213344_NPEP_Settlement_Report"|tee -a ${logFile}

	echo "Move Report TO Bak"|tee -a ${logFile}
	mv ${ReportDir}/"${reportFileName1}_${processCycle}.csv" ${ReportDirBak}
fi

#Step 8. send final mail
sendFinalMail
echo "Gen SR213344_NPEP_Settlement_Report End"|tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
