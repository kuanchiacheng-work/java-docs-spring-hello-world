#!/usr/bin/env bash
########################################################################################
# Program name : SR225879_HGB_MPBL_Unbill_OC_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2021/01/29 Create by Mike Kuan
# Description : SR225879_因應MPBS Migrate To HGB Project之財務報表需求
########################################################################################
# Date : 2021/02/24 Modify by Mike Kuan
# Description : add prod ftp
########################################################################################
# Date : 2023/07/12 Modify by Mike Kuan
# Description : 因CUSDATE後無法抓取未出帳OC，故修改AND (bbc.bill_seq IS NULL or bbc.bi_seq is null)，同時濾除HGBN
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
reportFileName="HGB_Unbill_OC_`date +%Y%m%d`_`date +%Y%m%d%H%M%S`"
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
putpath1=/AR/payment/ARBATCH90/HGB_UnbillOC/work

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

select 'Cycle_Code'||';'||'Charge_Code'||';'||'Charge_Type'||';'||'Charge_Amount'||';'||'Tax_Amount'||';'||'Tax_Rate'||';'||'Subscriber_Id'||';'||'Subscriber_Type'||';'||'Account_Id'||';'||'Account_Category'||';'||'Customer_Type'||';'||'Customer_Sub_Type' from dual;

--SELECT bbc.CYCLE "Cycle_Code", bbc.charge_code "Charge_Code",
--       bbc.charge_type "Charge_Type", to_char(amount-ROUND(bbc.amount/1.05*slc.num1,2)) "Charge_Amount",
--       ROUND (bbc.amount / 1.05 * slc.num1, 2) "Tax_Amount",
--       slc.num1 "Tax_Rate", bbc.subscr_id "Subscriber_Id",
--       cs.subscr_type "Subscriber_Type", bbc.acct_id "Account_Id",
--       ca.acct_category "Account_Category", cc.cust_type "Customer_Type", cc.cust_sub_type "Customer_Sub_Type"
--  FROM fy_tb_bl_bill_ci bbc,
--       fy_tb_pbk_charge_code pcc,
--       fy_tb_sys_lookup_code slc,
--       fy_tb_cm_subscr cs,
--       fy_tb_cm_account ca,
--       fy_tb_cm_customer cc
-- WHERE bbc.SOURCE = 'OC'
--   AND slc.lookup_type = 'TAX_TYPE'
--   AND bbc.bill_seq IS NULL
--   AND bbc.charge_code = pcc.charge_code
--   AND pcc.tax_rate = slc.lookup_code
--   AND bbc.subscr_id = cs.subscr_id
--   AND bbc.acct_id = ca.acct_id
--   AND bbc.cust_id = cc.cust_id
--;

SELECT bbc.CYCLE||';'||bbc.charge_code||';'||
       bbc.charge_type||';'||to_char(amount-ROUND(bbc.amount/1.05*slc.num1,2))||';'||
       ROUND (bbc.amount / 1.05 * slc.num1, 2)||';'||
       slc.num1||';'||bbc.subscr_id||';'||
       cs.subscr_type||';'||bbc.acct_id||';'||
       ca.acct_category||';'||cc.cust_type||';'||cc.cust_sub_type
  FROM fy_tb_bl_bill_ci bbc,
       fy_tb_pbk_charge_code pcc,
       fy_tb_sys_lookup_code slc,
       fy_tb_cm_subscr cs,
       fy_tb_cm_account ca,
       fy_tb_cm_customer cc
 WHERE bbc.SOURCE = 'OC'
   AND slc.lookup_type = 'TAX_TYPE'
   AND (bbc.bill_seq IS NULL or bbc.bi_seq is null)
   AND bbc.cycle not in (10,15,20)
   AND bbc.charge_code = pcc.charge_code
   AND pcc.tax_rate = slc.lookup_code
   AND bbc.subscr_id = cs.subscr_id
   AND bbc.acct_id = ca.acct_id
   AND bbc.cust_id = cc.cust_id
;

spool off

exit;

EOF`

echo "Gen Report End"|tee -a ${logFile}
}

function ftpReport2
{
ftp -i -n -v $1<<EOF
user $2 $3
pass
cd $4
mput $5
bye
EOF
}

function formatterReport
{
grep -v '^$' ${reportFileName}.dat > ${ReportDir}/${reportFileName}.txt
rm ${reportFileName}.dat
}

function sendFinalMail
{
send_msg="<SR225879_HGB_MPBL_Unbill_OC_Report> $sysd"
	#iconv -f utf8 -t big5 -c ${reportFileName}.txt > ${reportFileName}.big5
	#mv ${reportFileName}.big5 ${reportFileName}.txt
	#rm ${reportFileName}.dat
mailx -s "${send_msg}" -a ${reportFileName}.txt ${mailList} <<EOF
Dears,

   SR225879_HGB_MPBL_Unbill_OC_Report已產出。
   檔名：
   ${reportFileName}.txt
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

function sendGenTempErrorMail
{
send_msg="<SR225879_HGB_MPBL_Unbill_OC_Report> $sysd"
mailx -s "${send_msg} Gen Data Have Abnormal " ${mailList} <<EOF
Dear All,
  
  SR225879_HGB_MPBL_Unbill_OC_Report未產出。
  
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
echo "Gen ${reportFileName1} Start" | tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
cd $ReportDir
genReport
sleep 5
#formatter Report 
echo "Formatter Report Start"|tee -a ${logFile}
formatterReport
echo "Formatter Report End"|tee -a ${logFile}


#check gen report
filecnt1=`ls ${ReportDir}/${reportFileName}.txt|wc -l`
sleep 5
if [[ (${filecnt1} = 0 ) ]] ; then
	echo "${progName} Generated Report Have Abnormal"|tee -a ${logFile}
	sendGenTempErrorMail
	exit 0
else
	echo "FTP Report"|tee -a ${logFile}
	echo "Run Command: ${ftpProg} ${putip1} ${putuser1} ******** ${ReportDir} ${putpath1} ${reportFileName}.txt 0" | tee -a ${logFile}
		#${ftpProg} ${putip1} ${putuser1} ${putpass1} ${ReportDir} ${putpath1} ${ReportDir}/${reportFileName}.txt 0
		
		cd ${ReportDir}
	ftpReport2 ${putip1} ${putuser1} ${putpass1} ${putpath1} "${reportFileName}.txt"
		
	echo "send SR225879_HGB_MPBL_Unbill_OC_Report"|tee -a ${logFile}

	echo "Move Report TO Bak"|tee -a ${logFile}
	mv "${reportFileName}.txt" ${ReportDirBak}
	#send final mail
	sendFinalMail
fi
sleep 5

echo "Gen ${reportFileName1} End" | tee -a ${logFile}
echo $sysdate|tee -a ${logFile}
