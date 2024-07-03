#!/usr/bin/ksh
########################################################################################
# Program name : HGB_UBL_CutDate.sh
# Path : /extsoft/UBL/BL/CutDate/bin
#
# Date : 2018/09/06 Created by Mike Kuan
# Description : HGB UBL CutDate
########################################################################################
# Date : 2018/10/01 Modify by Mike Kuan
# Description : add Status Check
########################################################################################
# Date : 2018/11/06 Modify by Mike Kuan
# Description : add grep condiation
########################################################################################
# Date : 2018/11/26 Modify by Mike Kuan
# Description : add MPC
########################################################################################
# Date : 2018/12/04 Modify by Mike Kuan
# Description : adj BillDate to sysdate
########################################################################################
# Date : 2019/06/30 Modify by Mike Kuan
# Description : SR213344_NPEP add cycle parameter、關閉取得ERP匯率
########################################################################################
# Date : 2019/08/29 Modify by Mike Kuan
# Description : SR213344_NPEP modify bill_date
########################################################################################
# Date : 2020/11/10 Modify by Mike Kuan
# Description : SR232859_修改IoT&HGBN BA Close的條件
########################################################################################
# Date : 2021/02/20 Modify by Mike Kuan
# Description : SR222460_MPBS migrate to HGB
########################################################################################
# Date : 2021/10/26 Modify by Mike Kuan
# Description : SR239378_SD-WAN 調整function sendSMS,sendMail，增加start提醒
########################################################################################

#---------------------------------------------------------------------------------------#
#      env
#---------------------------------------------------------------------------------------#
progName="HGB_UBL_CutDate"
sysdt=`date +%Y%m%d%H%M%S`
#BillDate=$1
#BillDate=`date +%Y%m%d` #20190829
#BillDate=`date +%Y%m01` #20190829
#Cycle=$1
HomeDir=/extsoft/UBL/BL
WorkDir=$HomeDir/CutDate/bin
LogDir=$HomeDir/CutDate/log
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

function HGB_UBL_getCycleInfo
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}.data <<EOF
@HGB_UBL_getCycleInfo.sql $1 $2
EOF`
cat ${LogDir}/${progName}.data |read CYCLE CURRECT_PERIOD
echo "CycleCode[${CYCLE}] PeriodKey[${CURRECT_PERIOD}]" | tee -a ${LogFile}
}

function HGB_UBL_CutDate_BA_Close
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_BA_Close.data <<EOF
@HGB_UBL_CutDate_BA_Close.sql $1 $2
exit
EOF`
cat ${LogDir}/${progName}_BA_Close.data | tee -a ${LogFile}
}

function HGB_UBL_CutDate_Pre
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_UBL_CutDate_Pre.sql $1 $2 $3
exit
EOF`
}

function HGB_UBL_CutDate
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_UBL_CutDate.sql $1 $2
exit
EOF`
}

function HGB_UBL_CutDate_STATUS_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STATUS.data <<EOF
@HGB_UBL_CutDate_STATUS_Check.sql $1 $2
exit
EOF`
cat ${LogDir}/${progName}_STATUS.data | tee -a ${LogFile}
}

function HGB_UBL_CutDate_ERP
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_UBL_CutDate_ERP.sql $1
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
		sendSMS 0
		echo "Send SMS (Failed)" | tee -a $LogFile
   fi
   echo "Send Mail (Failed)" | tee -a $LogFile
   sendMail 0
elif [[ $checksum -eq 0 ]]; then
   echo '' | tee -a $LogFile
   echo "Send AutoWatch (Successed)" | tee -a $LogFile
   echo "${progName},Normal,${AutoWatchDate}" >> $AutoWatchFile
   echo '' | tee -a $LogFile
   if [[ $DB = "HGBBL" ]]; then
		sendSMS 1
		echo "Send SMS (Successed)" | tee -a $LogFile
   fi
   echo "Send Mail (Successed)" | tee -a $LogFile
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
maillist=`cat $MailList`

if [[ $type -eq 1 ]]; then
mailx -r "HGB_UBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} Normal" -a ${LogFile} ${maillist} << EOF
Dears,
   ${progName} CYCLE:${Cycle} Bill_Date:${BillDate} Successed.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
sysdt_END=`date '+%Y/%m/%d-%H:%M:%S'`
echo "${sysdt_END} ------------------------------END ${progName}------------------------------" | tee -a $LogFile
elif [[ $type -eq 2 ]]; then
mailx -r "HGB_UBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} Start" ${maillist} << EOF
Dears,
   ${progName} CYCLE:${Cycle} Bill_Date:${BillDate} Start.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
else
mailx -r "HGB_UBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} Abnormal" -a ${LogFile} ${maillist}  << EOF
Dears,
   ${progName} CYCLE:${Cycle} Bill_Date:${BillDate} Failed, Please check!!!
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
sysdt_END=`date '+%Y/%m/%d-%H:%M:%S'`
echo "${sysdt_END} ------------------------------END ${progName}------------------------------" | tee -a $LogFile
fi
}

function sendSMS
{
type=$1
	errorMessage=" Abnormal! ${BillDate} ${Cycle} ${progName}"
	okMessage=" Normal! ${BillDate} ${Cycle} ${progName}"
	startMessage=" Start! ${BillDate} ${Cycle} ${progName}"
	smslist=`cat $smsList`
	
echo '' | tee -a $LogFile
sysdt_END=`date '+%Y/%m/%d-%H:%M:%S'`
echo "${sysdt_END} ------------------------------END ${progName}------------------------------" | tee -a $LogFile
echo '' | tee -a $LogFile

if [[ $type -eq 1 ]]; then
	${smsProg} "${okMessage}" "${smsList}"
elif [[ $type -eq 2 ]]; then
	${smsProg} "${startMessage}" "${smslist}"
else
	${smsProg} "${errorMessage}" "${smsList}"
fi
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
if [[ $DB != "HGBBL" ]]; then
	BillDate=$1
	Cycle=$2
	usage()
	{
		echo "Usage:"
		echo " $0 <BILL_DATE> "
		echo ""
		echo "For example: $0 20190701 10"
		echo "For example: $0 20190701 50"
		echo ""
	}

	if [[ $# -lt 2 ]]; then
		usage
		exit 0
	fi
else
	BillDate=`date +%Y%m01`
	Cycle=$1
	if [[ $# -lt 1 ]]; then
		usage
		exit 0
	fi
fi

sysdt_BEGIN=`date '+%Y/%m/%d-%H:%M:%S'`
echo '' | tee -a $LogFile
echo "${sysdt_BEGIN} ------------------------------BEGIN ${progName}------------------------------" | tee -a $LogFile
echo "HGB_DB_ENV : ${DB}" | tee -a $LogFile
echo "OCS_AP_ENV : ${OCS_AP}" | tee -a $LogFile
echo "BILL_DATE : ${BillDate}" | tee -a $LogFile
echo "CYCLE : ${Cycle}" | tee -a $LogFile
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
#------------取得Cycle資訊
echo "----->>>>>-----Step 1. Get Cycle Information (Start...)" | tee -a $LogFile
HGB_UBL_getCycleInfo $BillDate $Cycle
if [[ ${CYCLE} -lt 10 || ${CYCLE} -gt 60 ]]; then
  echo "-----<<<<<-----Step 1. Get Cycle Information (End... Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 1. Get Cycle Information (End... Successed)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行CutDate BA Close
if [[ $DB = "HGBBL" ]]; then
	echo "----->>>>>-----Step 2. Run CutDate BA Close Process (Start...)" | tee -a $LogFile
	HGB_UBL_CutDate_BA_Close $BillDate $CYCLE
	checkcode=`cat ${LogDir}/${progName}_BA_Close.data|grep -E 'ORA|ora|CutDate_BA_Close Process RETURN_CODE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 2. Run CutDate BA Close Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
	echo "-----<<<<<-----Step 2. Run CutDate BA Close Process (End... Successed)" | tee -a $LogFile
	Pause
fi
##----------------------------------------------------------------------------------------------------
#------------執行Pre_CutDate
echo "----->>>>>-----Step 3. Run Pre_CutDate Process (Start...)" | tee -a $LogFile
echo $BillDate
echo $CYCLE
HGB_UBL_CutDate_Pre $BillDate $CYCLE Y
checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Pre_CutDate Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  error_cnt=`cat ${LogFile}|grep -Eo 'ERROR_CNT = [0-9]'|grep '[0-9]'|awk '{print $3}'`
  if  [[ $error_cnt -ne 0 ]]; then
	echo "error list:"
	cat ${LogFile}|grep 'ACCT_ID='
	cat ${LogFile}|grep 'SUBSCR_ID='
  fi
  checkdone=0
  rerun_cnt=1
  while [ $checkdone -eq 0 ] 
  do
    sleep 2
	    echo "ReRun:$rerun_cnt Pre_CutDate Process (Start...)" | tee -a $LogFile
    HGB_UBL_CutDate_Pre $BillDate $CYCLE N
	checkdone=`cat ${LogFile}|grep 'Pre_CutDate Process RETURN_CODE = 0000'|wc -l`
		(( rerun_cnt++ ))
		if [[ $rerun_cnt -eq 11 ]]; then
		  echo "-----<<<<<-----Step 3. Run Pre_CutDate Process (End... Failed)" | tee -a $LogFile
		  AutoWatch 1
		fi
  done  
fi
echo "-----<<<<<-----Step 3. Run Pre_CutDate Process (End... Successed)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行CutDate
echo "----->>>>>-----Step 4. Run CutDate Process (Start...)" | tee -a $LogFile
HGB_UBL_CutDate $CYCLE $CURRECT_PERIOD
checkcode=`cat ${LogFile}|grep -E 'ORA|ora|CutDate Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -eq 1 ]]; then
  echo "-----<<<<<-----Step 4. Run CutDate Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 4. Run CutDate Process (End...Successed)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行CutDate STATUS Check
echo "----->>>>>-----Step 5. Run CutDate STATUS Check Process (Start...)" | tee -a $LogFile
HGB_UBL_CutDate_STATUS_Check $BillDate $CYCLE
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|CutDate_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 5. Run CutDate STATUS Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 5. Run CutDate STATUS Check Process (End... Successed)" | tee -a $LogFile
Pause
##----------------------------------------------------------------------------------------------------
##------------取得ERP匯率
#echo "----->>>>>-----Step 5. Get ERP (Start...)" | tee -a $LogFile
#HGB_UBL_CutDate_ERP $BillDate
#checkcode=`cat ${LogFile}|grep 'Get ERP RETURN_CODE = 0000'|wc -l`
#if [[ $checkcode -eq 0 ]]; then
#  echo "-----<<<<<-----Step 5. Get ERP (End... Failed)" | tee -a $LogFile
#  AutoWatch 1
#fi
#echo "-----<<<<<-----Step 5. Get ERP (End... Successed)" | tee -a $LogFile

AutoWatch 0
