#!/usr/bin/ksh
########################################################################################
# Program name : HGB_MPBL_Undo.sh
# Path : /extsoft/MPBL/BL/Undo/bin
#
# Date : 2021/02/20 Created by Mike Kuan
# Description : SR222460_MPBS migrate to HGB
########################################################################################
# Date : 2021/02/22 Modify by Mike Kuan
# Description : SR222460_MPBS migrate to HGB - fix SMS
########################################################################################
# Date : 2021/02/24 Modify by Mike Kuan
# Description : SR222460_MPBS migrate to HGB - add UPDATE_ACCT_LIST
########################################################################################
# Date : 2021/09/02 Modify by Mike Kuan
# Description : SR233414_行動裝置險月繳保費預繳專案
########################################################################################
# Date : 2021/09/09 Modify by Mike Kuan
# Description : 增加正式環境Undo筆數檢核，避免無筆數時Process Log遭刪除，使BLE2空等
########################################################################################

#---------------------------------------------------------------------------------------#
#      env
#---------------------------------------------------------------------------------------#
progName="HGB_MPBL_Undo"
sysdt=`date +%Y%m%d%H%M%S`
BillDate=$1
Cycle=$2
ProcessNo=$3
HomeDir=/extsoft/MPBL/BL
WorkDir=$HomeDir/Undo/bin
LogDir=$HomeDir/Undo/log
LogFile=$LogDir/${progName}_${sysdt}.log
AutoWatchDir=$LogDir/joblog
AutoWatchFile=$AutoWatchDir/${BillDate}_${progName}.log
AutoWatchFileName=${BillDate}_${progName}.log
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
#      FTP
#---------------------------------------------------------------------------------------# 
utilDir="/cb/BCM/util"
ftpProg="${utilDir}/Ftp2Remote.sh"
putip1='10.68.8.37'
putuser1=$OCSID
putpass1=$OCSPWD
putpath1=/cb/AutoWatch/log/joblog

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

function HGB_MPBL_Undo_MV_ACCT_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_MV_ACCT.data <<EOF
@HGB_MPBL_Undo_MV_ACCT_Check.sql $1 $2
EOF`
cat ${LogDir}/${progName}_MV_ACCT.data |read ACCT
echo "MV Acct Count: ${ACCT}" | tee -a ${LogFile}
}

function HGB_MPBL_Undo_STEP_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STEP.data <<EOF
@HGB_MPBL_Undo_STEP_Check.sql $1 $2 $3
EOF`
cat ${LogDir}/${progName}_STEP.data |read STEP
echo "Step or Message: ${STEP}" | tee -a ${LogFile}
}

function HGB_MPBL_Undo_Pre
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_Pre.data <<EOF
@HGB_MPBL_Undo_Pre.sql $1 $2 $3
EOF`
cat ${LogDir}/${progName}_Pre.data | tee -a ${LogFile}
}

function HGB_MPBL_UPDATE_ACCT_LIST
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_UPDATE_ACCT_LIST.data <<EOF
@HGB_MPBL_UPDATE_ACCT_LIST.sql $1 $2
EOF`
cat ${LogDir}/${progName}_UPDATE_ACCT_LIST.data | tee -a ${LogFile}
}

function HGB_MPBL_Undo_STATUS_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STATUS.data <<EOF
@HGB_MPBL_Undo_STATUS_Check.sql $1 $2 $3
EOF`
cat ${LogDir}/${progName}_STATUS.data | tee -a ${LogFile}
}

function HGB_MPBL_Undo
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_MPBL_Undo.sql $1 $2 $3
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
   if [[ $DB = "HGBBL" ]]; then
   		echo "Send SMS (Failed)" | tee -a $LogFile
		sendSMS 0
		echo "FTP Command: ${ftpProg} ${putip1} ${putuser1} ******** ${AutoWatchDir} ${putpath1} ${AutoWatchFileName} 0" | tee -a ${logFile}
		${ftpProg} ${putip1} ${putuser1} ${putpass1} ${AutoWatchDir} ${putpath1} ${AutoWatchFileName} 0
   fi
   echo "Send Mail (Failed)" | tee -a $LogFile
   sendMail 0
elif [[ $checksum -eq 0 ]]; then
   echo '' | tee -a $LogFile
   echo "Send AutoWatch (Succeeded)" | tee -a $LogFile
   echo "${progName},Normal,${AutoWatchDate}" >> $AutoWatchFile
   echo '' | tee -a $LogFile
   if [[ $DB = "HGBBL" ]]; then
   		echo "Send SMS (Succeeded)" | tee -a $LogFile
		sendSMS 1
		echo "FTP Command: ${ftpProg} ${putip1} ${putuser1} ******** ${AutoWatchDir} ${putpath1} ${AutoWatchFileName} 0" | tee -a ${logFile}
		${ftpProg} ${putip1} ${putuser1} ${putpass1} ${AutoWatchDir} ${putpath1} ${AutoWatchFileName} 0
   fi
   echo "Send Mail (Succeeded)" | tee -a $LogFile
   sendMail 1
fi
exit 0;
}

function sendMail
{
type=$1
cd ${LogDir}
iconv -f utf8 -t big5 -c ${LogFile} > ${LogFile}.big5
mv ${LogFile}.big5 ${LogFile}
tar zcvf ${progName}_${sysdt}.tar.tgz ${progName}_${sysdt}.log
maillist=`cat $MailList`

if [[ $type -eq 1 ]]; then
mailx -r "HGB_MPBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} ProcessNo:${ProcessNo} Normal" -a ${progName}_${sysdt}.tar.tgz ${maillist} << EOF
Dears,
   ${progName} CYCLE:${Cycle} Bill_Date:${BillDate} ProcessNo:${ProcessNo} Succeeded.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
sysdt_END=`date '+%Y/%m/%d-%H:%M:%S'`
echo "${sysdt_END} ------------------------------END ${progName}------------------------------" | tee -a $LogFile
elif [[ $type -eq 2 ]]; then
mailx -r "HGB_MPBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} ProcessNo:${ProcessNo} Start" ${maillist} << EOF
Dears,
   ${progName} CYCLE:${Cycle} Bill_Date:${BillDate} ProcessNo:${ProcessNo} Start.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
else
mailx -r "HGB_MPBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} ProcessNo:${ProcessNo} Abnormal" -a ${progName}_${sysdt}.tar.tgz ${maillist}  << EOF
Dears,
   ${progName} CYCLE:${Cycle} Bill_Date:${BillDate} ProcessNo:${ProcessNo} Failed, Please check!!!
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
sysdt_END=`date '+%Y/%m/%d-%H:%M:%S'`
echo "${sysdt_END} ------------------------------END ${progName}------------------------------" | tee -a $LogFile
fi
}

function sendSMS
{
type=$1
	errorMessage=" Abnormal! ${BillDate} ${Cycle} ${ProcessNo} ${progName}"
	okMessage=" Normal! ${BillDate} ${Cycle} ${ProcessNo} ${progName}"
	startMessage=" Start! ${BillDate} ${Cycle} ${ProcessNo} ${progName}"
	smslist=`cat $smsList`
	
echo '' | tee -a $LogFile

if [[ $type -eq 1 ]]; then
	${smsProg} "${okMessage}" "${smslist}"
elif [[ $type -eq 2 ]]; then
	${smsProg} "${startMessage}" "${smslist}"
else
	${smsProg} "${errorMessage}" "${smslist}"
fi
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
usage()
{
	echo "Usage:"
	echo " $0 <BILL_DATE> <CYCLE> <PROCESS_NO> "
	echo ""
    echo "For PROD example: $0 20210301 50 001"
    echo "For PROD example: $0 20210303 51 001"
    echo "For PROD example: $0 20210305 52 001"
    echo "For PROD example: $0 20210308 53 001"
    echo "For PROD example: $0 20210311 54 001"
    echo "For PROD example: $0 20210314 55 001"
    echo "For PROD example: $0 20210317 56 001"
    echo "For PROD example: $0 20210220 57 001"
    echo "For PROD example: $0 20210223 58 001"
    echo "For PROD example: $0 20210225 59 001"
	echo "For PROD example: $0 20210227 60 001"
    echo "For HOLD example: $0 20210301 50 999"
    echo "For HOLD example: $0 20210303 51 999"
    echo "For HOLD example: $0 20210305 52 999"
    echo "For HOLD example: $0 20210308 53 999"
    echo "For HOLD example: $0 20210311 54 999"
    echo "For HOLD example: $0 20210314 55 999"
    echo "For HOLD example: $0 20210317 56 999"
    echo "For HOLD example: $0 20210220 57 999"
    echo "For HOLD example: $0 20210223 58 999"
    echo "For HOLD example: $0 20210225 59 999"
	echo "For HOLD example: $0 20210227 60 999"
	echo ""
}

if [[ $# -lt 3 ]]; then
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
echo "PROCESS_NO : ${ProcessNo}" | tee -a $LogFile
echo '' | tee -a $LogFile

if [[ $DB = "HGBBL" ]]; then
	echo "Send SMS (Start)" | tee -a $LogFile
	sendSMS 2
	Pause
	echo "Send Mail (Start)" | tee -a $LogFile
	sendMail 2
else
	echo "Send Mail (Start)" | tee -a $LogFile
	sendMail 2
fi

cd ${WorkDir}
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Preparation MV ACCT Check
if [[ ${ProcessNo} -ne 999 ]]; then
	echo "----->>>>>-----Step 888. Run Undo MV ACCT Check Process (Start...)" | tee -a $LogFile
	HGB_MPBL_Undo_MV_ACCT_Check $BillDate $Cycle
	checkcode=`cat ${LogDir}/${progName}_MV_ACCT.data|grep -E 'ORA|ora|Undo_MV_ACCT_Check Process RETURN_CODE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 888. Run Undo MV ACCT Check Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
	if [[ ${ACCT}-${ACCT} -ne 0 ]]; then
		echo "-----<<<<<-----Step 888. Run Undo MV ACCT Check Process (End...Get MV Acct Count Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
	echo "-----<<<<<-----Step 888. Run Undo MV ACCT Check Process (End... Succeeded)" | tee -a $LogFile
fi
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Undo Step Check
echo "----->>>>>-----Step 1. Run Undo Step Check Process (Start...)" | tee -a $LogFile
HGB_MPBL_Undo_STEP_Check $BillDate $Cycle $ProcessNo
checkcode=`cat ${LogDir}/${progName}_STEP.data|grep -E 'ORA|ora|Undo_STEP_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 1. Run Undo Step Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 1. Run Undo Step Check Process (End... Succeeded)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Pre Undo
echo "----->>>>>-----Step 2. Run Undo Pre Process (Start...)" | tee -a $LogFile
HGB_MPBL_Undo_Pre $BillDate $Cycle $ProcessNo
checkcode=`cat ${LogDir}/${progName}_Pre.data|grep -E 'ORA|ora|Undo_Pre Process RETURN_CODE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 2. Run Undo Pre Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
echo "-----<<<<<-----Step 2. Run Undo Pre Process (End... Succeeded)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行UPDATE ACCT LIST
echo "----->>>>>-----Step 3. Run UPDATE ACCT LIST Process (Start...)" | tee -a $LogFile
HGB_MPBL_UPDATE_ACCT_LIST $BillDate $Cycle
checkcode=`cat ${LogDir}/${progName}_UPDATE_ACCT_LIST.data|grep -E 'ORA|ora|update FY_TB_BL_ACCT_LIST.TYPE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 3. Run UPDATE ACCT LIST Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
	if [[ $DB = "HGBBL" ]]; then
	HOLD_COUNT=`cat ${LogDir}/${progName}_UPDATE_ACCT_LIST.data | grep "HOLD_COUNT=" | awk -F'=' '{print $2}'| awk -F' ' '{print $1}'`
		if [[ $HOLD_COUNT -eq 0 ]]; then
			echo "HOLD_COUNT: ${HOLD_COUNT}" | tee -a ${LogFile}
			echo "-----<<<<<-----Step 3. Run UPDATE ACCT LIST Process (End...No Processed Data Found)" | tee -a $LogFile
			AutoWatch 0
		else
			echo "HOLD_COUNT: ${HOLD_COUNT}" | tee -a ${LogFile}
		fi
	fi
echo "-----<<<<<-----Step 3. Run UPDATE ACCT LIST Process (End... Succeeded)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Undo STATUS Check
echo "----->>>>>-----Step 4. Run Undo STATUS Check Process (Start...)" | tee -a $LogFile
HGB_MPBL_Undo_STATUS_Check $BillDate $Cycle $ProcessNo
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Undo_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 4. Run Undo STATUS Check Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
echo "-----<<<<<-----Step 4. Run Undo STATUS Check Process (End... Succeeded)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#if [[ ${STEP} == 'CN' || ${STEP} == 'MAST' || ${STEP} == 'BI' ]]; then
#------------執行Undo
echo "----->>>>>-----Step 5. Run Undo Process (Start...)" | tee -a $LogFile
HGB_MPBL_Undo $BillDate $Cycle $ProcessNo
checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Undo Process RETURN_CODE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 5. Run Undo Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	else
		echo '' | tee -a $LogFile
		echo "-----<<<<<-----Step 5. Run Undo Process (End... Succeeded)" | tee -a $LogFile
	fi
Pause
#----------------------------------------------------------------------------------------------------
#if [[ ${STEP} == 'CN' || ${STEP} == 'MAST' || ${STEP} == 'BI' ]]; then
#------------執行MV Undo
if [[ ${ProcessNo} -ne 999 ]]; then
	echo "----->>>>>-----Step 888. Run MV Undo Process (Start...)" | tee -a $LogFile
		if [[ ${ACCT} -ge 1 ]]; then #確認MV ACCT待undo筆數
			HGB_MPBL_Undo $BillDate $Cycle 888
			checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Undo Process RETURN_CODE = 9999'|wc -l`
				if [[ $checkcode -ge 1 ]]; then
					echo "-----<<<<<-----Step 888. Run MV Undo Process (End...Failed)" | tee -a $LogFile
					AutoWatch 1
				fi
		else
			echo "MV ACCT is : ${ACCT}" | tee -a $LogFile
		fi
	echo '' | tee -a $LogFile
	echo "-----<<<<<-----Step 888. Run MV Undo Process (End... Succeeded)" | tee -a $LogFile
fi
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Undo STATUS Check
echo "----->>>>>-----Step 6. Run Undo STATUS Check Process (Start...)" | tee -a $LogFile
HGB_MPBL_Undo_STATUS_Check $BillDate $Cycle $ProcessNo
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Undo_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 6. Run Undo STATUS Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 6. Run Undo STATUS Check Process (End... Succeeded)" | tee -a $LogFile

AutoWatch 0
