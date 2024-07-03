#!/usr/bin/ksh
########################################################################################
# Program name : HGB_UBL_Undo.sh
# Path : /extsoft/UBL/BL/Undo/bin
#
# Date : 2018/09/19 Created by Mike Kuan
# Description : HGB UBL Undo
########################################################################################
# Date : 2018/09/28 Modify by Mike Kuan
# Description : add Status Check
########################################################################################
# Date : 2018/11/06 Modify by Mike Kuan
# Description : add grep condiation
########################################################################################
# Date : 2018/11/26 Modify by Mike Kuan
# Description : add MPC
########################################################################################
# Date : 2019/06/30 Modify by Mike Kuan
# Description : SR213344_NPEP add cycle parameter
########################################################################################
# Date : 2021/02/20 Modify by Mike Kuan
# Description : SR222460_MPBS migrate to HGB
########################################################################################

#---------------------------------------------------------------------------------------#
#      env
#---------------------------------------------------------------------------------------#
progName="HGB_UBL_Undo"
sysdt=`date +%Y%m%d%H%M%S`
BillDate=$1
ProcType=$2
ProcessNo=$3
Cycle=$4
HomeDir=/extsoft/UBL/BL
WorkDir=$HomeDir/Undo/bin
LogDir=$HomeDir/Undo/log
LogFile=$LogDir/${progName}_${sysdt}.log
AutoWatchDir=$LogDir/joblog
AutoWatchFile=$AutoWatchDir/${BillDate}_${progName}.log
MailList=$HomeDir/MailList.txt
smsList=$HomeDir/smsList.txt
smsProg=/cb/BCM/util/SendSms.sh
#---------------------------------------------------------------------------------------#
#      MPC info
#---------------------------------------------------------------------------------------#
hostname=`hostname`
case ${hostname} in
"pc-hgbap01t") #(TEST06) (PT)
DB="HGBDEV2"
OCS_AP="fetwrk26"
;;
"hgbdev01t") #(TEST06) (PT)
DB="HGBDEV3"
OCS_AP="fetwrk26"
;;
"pc-hgbap11t") #(TEST15) (SIT)
DB="HGBBLSIT"
OCS_AP="fetwrk15"
;;
"pc-hgbap21t") #(TEST02) (UAT)
DB="HGBBLUAT"
OCS_AP="fetwrk21"
;;
"pet-hgbap01p"|"pet-hgbap02p"|"idc-hgbap01p"|"idc-hgbap02p") #(PET) (PROD)
DB="HGBBL"
OCS_AP="prdbl2"
;;
*)
echo "Unknown AP Server"
exit 0
esac
DBID=`/cb/CRYPT/GetId.sh $DB`
DBPWD=`/cb/CRYPT/GetPw.sh $DB`
OCSID=`/cb/CRYPT/GetId.sh $OCS_AP`
OCSPWD=`/cb/CRYPT/GetPw.sh $OCS_AP`

#---------------------------------------------------------------------------------------#
#      function
#---------------------------------------------------------------------------------------#
function Pause #讀秒
{
for i in `seq 1 1 5`;
do
echo "." | tee -a $LogFile
sleep 1
done
}

function HGB_UBL_Undo_STEP_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STEP.data <<EOF
@HGB_UBL_Undo_STEP_Check.sql $1 $2 $3 $4
EOF`
cat ${LogDir}/${progName}_STEP.data |read STEP
echo "Step or Message: ${STEP}" | tee -a ${LogFile}
}

function HGB_UBL_Undo_STATUS_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STATUS.data <<EOF
@HGB_UBL_Undo_STATUS_Check.sql $1 $2 $3 $4
EOF`
cat ${LogDir}/${progName}_STATUS.data | tee -a ${LogFile}
}

function HGB_UBL_Undo
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_UBL_Undo.sql $1 $2 $3 $4
exit
EOF`
}

function AutoWatch
{
checksum=$1
AutoWatchDate=`date '+%Y/%m/%d-%H:%M:%S'`
touch $AutoWatchFile
if [[ $checksum -eq 1 ]]; then
   echo '' | tee -a $LogFile
   echo "Send AutoWatch (Failed)" | tee -a $LogFile
   echo "${progName},Abnormal,${AutoWatchDate}" >> $AutoWatchFile
   echo '' | tee -a $LogFile
   sendMail 0
   echo "Send Mail (Failed)" | tee -a $LogFile
   if [[ $DB = "HGBBL" ]]; then
		sendSMS 0
		echo "Send SMS (Failed)" | tee -a $LogFile
   fi
elif [[ $checksum -eq 0 ]]; then
   echo '' | tee -a $LogFile
   echo "Send AutoWatch (Successed)" | tee -a $LogFile
   echo "${progName},Normal,${AutoWatchDate}" >> $AutoWatchFile
   echo '' | tee -a $LogFile
   sendMail 1
   echo "Send Mail (Successed)" | tee -a $LogFile
   if [[ $DB = "HGBBL" ]]; then
		sendSMS 1
		echo "Send SMS (Successed)" | tee -a $LogFile
   fi
fi

#if [[ $DB = "HGBBL" ]]; then
#ftp -nv 10.68.8.37 <<EOF
#user $OCSID $OCSPW
#prompt off
#ascii
#cd /cb/AutoWatch/log/joblog
#put $AutoWatchFile
#bye
#EOF
#fi

exit 0;
}

function sendMail
{
type=$1
cd ${LogDir}
iconv -f utf8 -t big5 -c ${LogFile} > ${LogFile}.big5
mv ${LogFile}.big5 ${LogFile}
maillist=`cat $MailList`

if [[ $type -eq 1 ]]; then
mailx -r "HGB_UBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} ProcessNo:${ProcessNo} Normal" -a ${LogFile} ${maillist} << EOF
Dears,
   ${progName} CYCLE:${Cycle} Bill_Date:${BillDate} ProcessNo:${ProcessNo} Successed.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
else
mailx -r "HGB_UBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} ProcessNo:${ProcessNo} Abnormal" -a ${LogFile} ${maillist}  << EOF
Dears,
   ${progName} CYCLE:${Cycle} Bill_Date:${BillDate} ProcessNo:${ProcessNo} Failed, Please check!!!
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
fi
}

function sendSMS
{
type=$1
	errorMessage=" Abnormal! ${BillDate} ${Cycle} ${ProcessNo} ${progName}"
	okMessage=" Normal! ${BillDate} ${Cycle} ${ProcessNo} ${progName}"
	smslist=`cat $smsList`
	
echo '' | tee -a $LogFile
sysdt_END=`date '+%Y/%m/%d-%H:%M:%S'`
echo "${sysdt_END} ------------------------------END ${progName}------------------------------" | tee -a $LogFile
echo '' | tee -a $LogFile

if [[ $type -eq 1 ]]; then
	${smsProg} "${okMessage}" "${smsList}"
else
	${smsProg} "${errorMessage}" "${smsList}"
fi
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
usage()
{
	echo "Usage:"
	echo " $0 <BILL_DATE> <PROC_TYPE> <PROCESS_NO> <CYCLE>"
	echo ""
    echo "For QA example: $0 20190701 T 999 50"
    echo "For PROD example: $0 20190701 B 001 50"
    echo "For PROD example: $0 20190701 B 002 50"
    echo "For PROD example: $0 20190701 B 003 50"
    echo "For PROD example: $0 20190701 B 004 50"
    echo "For PROD example: $0 20190701 B 005 50"
    echo "For PROD example: $0 20190701 B 006 50"
    echo "For PROD example: $0 20190701 B 007 50"
    echo "For PROD example: $0 20190701 B 008 50"
    echo "For PROD example: $0 20190701 B 009 50"
    echo "For PROD example: $0 20190701 B 010 50"
    echo "For PROD_MV example: $0 20190701 B 888 50"
    echo "For HOLD example: $0 20190701 B 999 50"
	echo ""
}

if [[ $# -lt 4 ]]; then
  usage
  exit 0
fi

sysdt_BEGIN=`date '+%Y/%m/%d-%H:%M:%S'`
echo '' | tee -a $LogFile
echo "${sysdt_BEGIN} ------------------------------BEGIN ${progName}------------------------------" | tee -a $LogFile
echo "HGB_DB_ENV : ${DB}" | tee -a $LogFile
echo "OCS_AP_ENV : ${OCS_AP}" | tee -a $LogFile
echo "BILL_DATE : ${BillDate}" | tee -a $LogFile
echo "CYCLE : ${Cycle}" | tee -a $LogFile
echo "PROC_TYPE : ${ProcType}" | tee -a $LogFile
echo "PROCESS_NO : ${ProcessNo}" | tee -a $LogFile
echo '' | tee -a $LogFile
cd ${WorkDir}
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Undo Step Check
echo "----->>>>>-----Step 1. Run Undo Step Check Process (Start...)" | tee -a $LogFile
HGB_UBL_Undo_STEP_Check $BillDate $Cycle $ProcessNo $ProcType
checkcode=`cat ${LogDir}/${progName}_STEP.data|grep -E 'ORA|ora|Undo_STEP_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 1. Run Undo Step Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 1. Run Undo Step Check Process (End... Successed)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Undo STATUS Check
echo "----->>>>>-----Step 2. Run Undo STATUS Check Process (Start...)" | tee -a $LogFile
HGB_UBL_Undo_STATUS_Check $BillDate $Cycle $ProcessNo $ProcType
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Undo_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 2. Run Undo STATUS Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 2. Run Undo STATUS Check Process (End... Successed)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#if [[ ${STEP} == 'CN' || ${STEP} == 'MAST' || ${STEP} == 'BI' ]]; then
#------------執行Undo
	echo "----->>>>>-----Step 3. Run Undo Process (Start...)" | tee -a $LogFile
	HGB_UBL_Undo $BillDate $Cycle $ProcessNo $ProcType
	checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Process RETURN_CODE = 9999'|wc -l`
		if [[ $checkcode -ge 1 ]]; then
			echo "-----<<<<<-----Step 3. Run Undo Process (End...Failed)" | tee -a $LogFile
			AutoWatch 1
		else
			echo '' | tee -a $LogFile
			echo "-----<<<<<-----Step 3. Run Undo Process (End... Successed)" | tee -a $LogFile
		fi
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Undo STATUS Check
echo "----->>>>>-----Step 4. Run Undo STATUS Check Process (Start...)" | tee -a $LogFile
HGB_UBL_Undo_STATUS_Check $BillDate $Cycle $ProcessNo $ProcType
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Undo_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 4. Run Undo STATUS Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 4. Run Undo STATUS Check Process (End... Successed)" | tee -a $LogFile

AutoWatch 0
