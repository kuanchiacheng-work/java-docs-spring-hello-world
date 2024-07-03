#!/usr/bin/env bash
####################################################
# Generate SR223576_Cloud_Service_Report
#
# Created by Sharon Lin
# Date by 2020-03-24
####################################################
home="/extsoft/UBL/BL/Surrounding/RPT"
logfolder="${home}/log"
progName=$(basename $0 .sh)
pid=$$
echo "Program Name is:${progName}"
sendmail="/usr/sbin/sendmail"
#DB info (TEST06) (PT)
#--DB_SID="HGBBLDEV"
#DB info (TEST15) (SIT)
DB_SID="HGBBLSIT"
#DB info (TEST02) (UAT)
#--DB_SID="HGBBLUAT"
#DB info (PROD)
#DB_SID="HGBBL"
DB_USER=$(/cb/CRYPT/GetId.sh ${DB_SID})
DB_PASSWD=$(/cb/CRYPT/GetPw.sh ${DB_SID})
sysdt=`date "+%Y-%m-%d %H:%M:%S"`
echo "sysdt:${sysdt}"
sysd=`date "+%Y%m%d"`
sysdtV=`date "+%Y%m%d%H%M%S"`
tmpl="${home}/template/template_SR223576_Cloud_Service_Report.html"
tmplTmp="${home}/log/SR223576_Cloud_Service_Report_template_tmp_${sysd}_${pid}.html"
sqlLogFile="${home}/log/SR223576_Cloud_Service_Report_SqlLog_${sysd}_${pid}.log"
htmlFile="${home}/log/SR223576_Cloud_Service_Report_html_${sysd}_${pid}.html"
logFile="${home}/log/${progName}_${sysd}_${pid}.log"
sqlDataFile="${home}/log/SR223576_Cloud_Service_Report_Count__${sysd}_${pid}.dat"

function executeSqlCnt
{
g1sqlsyntax=$1
echo "g1sqlsyntax:${g1sqlsyntax}"
`sqlplus -s ${DB_USER}/${DB_PASSWD}@${DB_SID} > ${sqlDataFile} <<EOF
set heading off;
set pagesize 0;
set feedback off;
set serveroutput on;

${g1sqlsyntax};
exit;
EOF`

#cat ${sqlDataFile}
read count < ${sqlDataFile}														
}

function generateReport
{
echo "Call generateReport"
g2tablename=$1
g2sqlsyntax=$2
echo "g2sqlsyntax:${g2sqlsyntax}"

#echo "<h4>${g2tablename}</h4>" >> ${sqlLogFile}
#echo "<p>語法：</p>" >> ${sqlLogFile}
#echo "<blockquote>${g2sqlsyntax}</blockquote>" >> ${sqlLogFile}
#echo "<p>&nbsp;</p>" >> ${sqlLogFile}

NLS_LANG="TRADITIONAL CHINESE_TAIWAN.AL32UTF8"

export NLS_LANG
`sqlplus -s ${DB_USER}/${DB_PASSWD}@${DB_SID} >> ${sqlLogFile} <<EOF
set tab off
SET ECHO OFF
set termout off
SET PAGESIZE 32766
SET LINESIZE 32766
SET FEEDBACK OFF
-- set NULL 'NO ROWS SELECTED'
set linesize 1024
SET TRIMSPOOL ON

spool ${htmlFile}

-- TTITLE LEFT '<h4>${g2tablename}</h4>'
set markup html on spool on TABLE "class=tb-wd-1" entmap off
column type format a10 heading 'TYPE'
${g2sqlsyntax}
/

SET MARKUP HTML OFF
spool off
exit;
EOF`
echo "<p>&nbsp;</p>" >> ${sqlLogFile}
}

function sendMail
{
echo "sender:${sender}"
echo "recipient:${recipientHJ}"

cp -p ${tmpl} ${tmplTmp}

sed -i 's|%sender%|'"${sender}"'|g' ${tmplTmp}
sed -i 's|%recipient%|'"${recipientHJ}"'|g' ${tmplTmp}
subsidiary="${subsidiaryHJ// /}"
if [ ${#subsidiary} -gt 0 ]; then
	echo "Add subsidiary"
	sed -i 's|%subsidiary%|'"Cc: ${subsidiaryHJ}"'|g' ${tmplTmp}
else
	echo "Remove subsidiary"
	sed -i '/%subsidiary%/d' ${tmplTmp}
fi
sed -i 's|%sysdt%|'"${sysdt}"'|g' ${tmplTmp}
sed -i 's|%reportTime%|'"${sysdt}"'|g' ${tmplTmp}
#sed -i 's|%BillDate%|'"${BillDate}"'|g' ${tmplTmp}
sed -i 's|%reportStartTime%|'"${reportStartTime}"'|g' ${tmplTmp}
sed -i 's|%reportEndTime%|'"${reportEndTime}"'|g' ${tmplTmp}
sed -i 's|%reportDiffTime%|'"${reportDiffTime}"'|g' ${tmplTmp}
sed -i 's|%hostname%|'"${hostname}"'|g' ${tmplTmp}
echo "sed -i '/%tablecontent%/r ${sqlLogFile}' ${tmplTmp}"
sed -i '/%tablecontent%/r '"${sqlLogFile}"'' ${tmplTmp}
sed -i '/%tablecontent%/d' ${tmplTmp}
sed -i '/%tablecontentRt%/r '"${sqlLogFileRt}"'' ${tmplTmp}
sed -i '/%tablecontentRt%/d' ${tmplTmp}
sed -i ':a;N;$!ba;s/<table class=tb-wd-1>\n<\/table>//g' ${tmplTmp}
sed -i ':a;N;$!ba;s/<table class=tb-wd-2>\n<\/table>//g' ${tmplTmp}
sed -i ':a;N;$!ba;s/<table class=tb-wd-3>\n<\/table>//g' ${tmplTmp}
sed -i ':a;N;$!ba;s/<table class=tb-wd-4>\n<\/table>//g' ${tmplTmp}
sed -i 's/width="90%"/width="90%" border="0" style="border-width:0px;"/g' ${tmplTmp}

file ${tmplTmp}

cat ${tmplTmp} | ${sendmail} -t
}

####################################################
# Main
####################################################

cd ${home}
## Initial variables
hostname="HGBBL"

echo "Connect to ${DB_USER}@${DB_SID}"

## Initial variables
startDate="`date -d "1 hour ago" +"%Y-%m-%d %H:"`00:00"
echo "Start Date is ${startDate}"
#BillDate=$1
#BillDate='20190501'
reportStartTime=${startDate}
reportEndTime=`date +"%Y-%m-%d %H:%M:%S"`
D1=$(date -d "${reportStartTime}" '+%s')
D2=$(date -d "${reportEndTime}" '+%s')
reportDiffTime=$(((D2-D1)/86400))日$(date -u -d@$((D2-D1)) +%H時%M分%S秒)
echo "reportDiffTime:${reportDiffTime}"
#exit
## Load source files
source "${home}/conf/SR223576_Cloud_Service_Report_SQL.conf"
source "${home}/conf/SR223576_Cloud_Service_Report_mail.conf"

#----------------------------------------------------------------------------------------------
isGenRpt="N"
echo "startDate:${startDate}"
IFS=',' read -ra monitorArr <<< "${monitorlist}"
for i in "${monitorArr[@]}"; do
    echo "${i}"
	var1="sqlsyntaxCnt${i}"
	sqlsyntaxCnt="${!var1}"
	var2="sqlsyntax${i}"
	sqlsyntax="${!var2}"
	var3="sqlsyntaxTb${i}"
	sqlsyntaxTb="${!var3}"
	#echo "sqlsyntaxCnt:${sqlsyntaxCnt}"
	#echo "sqlsyntax:${sqlsyntax}"
	#echo "sqlsyntaxTb:${sqlsyntaxTb}"
	unset count
	executeSqlCnt "${sqlsyntaxCnt}"
	echo "count:${count}"
	if [[ "${count}" -ne "0" ]]; then
		isGenRpt="Y"
		generateReport "${sqlsyntaxTb}" "${sqlsyntax}"
	else 
		generateReportEmpty "${sqlsyntaxTb}" "${sqlsyntaxCnt}"
	fi
done

isMail="Y"
if [[ "${isMail:=Y}" == "Y" && "${isGenRpt}" == "Y" ]]; then
	echo "Send Mail..."
	sendMail
	echo "Send Mail completed at $(date +"%Y-%m-%d %H:%M:%S")." | tee -a ${logFile}
else 
	echo "Do not need to send mail at $(date +"%Y-%m-%d %H:%M:%S")" | tee -a ${logFile}
fi
