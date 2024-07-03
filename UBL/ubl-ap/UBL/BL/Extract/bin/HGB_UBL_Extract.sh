#!/usr/bin/ksh
########################################################################################
# Program name : HGB_UBL_Extract.sh
# Path : /extsoft/UBL/BL/Extract/bin
#
# Date : 2018/09/20 Created by Mike Kuan
# Description : HGB UBL Extract
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
progName="HGB_UBL_Extract"
sysdt=`date +%Y%m%d%H%M%S`
BillDate=$1
ProcType=$2
Cycle=$3
HomeDir=/extsoft/UBL/BL
WorkDir=$HomeDir/Extract/bin
LogDir=$HomeDir/Extract/log
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

function HGB_UBL_Extract
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}.data <<EOF
@HGB_UBL_Extract.sql $1 $2 $3
exit
EOF`
cat ${LogDir}/${progName}.data | tee -a ${LogFile}
}

function HGB_UBL_Extract_DIO_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_DIO_Check.data <<EOF
@HGB_UBL_Extract_DIO_Check.sql $1 $2 $3 $4
exit
EOF`
cat ${LogDir}/${progName}_DIO_Check.data | tee -a ${LogFile}
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
mailx -r "HGB_UBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} Normal" -a ${LogFile} ${maillist} << EOF
Dears,
   ${progName} Bill_Date:${BillDate} CYCLE:${Cycle} Successed.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
else
mailx -r "HGB_UBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} Abnormal" -a ${LogFile} ${maillist}  << EOF
Dears,
   ${progName} Bill_Date:${BillDate} CYCLE:${Cycle} Failed, Please check!!!
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
fi
}

function sendSMS
{
type=$1
	errorMessage=" Abnormal! ${BillDate} ${Cycle} ${progName}"
	okMessage=" Normal! ${BillDate} ${Cycle} ${progName}"
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

function sendDelayMail
{
count=$1
iconv -f utf8 -t big5 -c ${LogFile} > ${LogFile}.big5
mv ${LogFile}.big5 ${LogFile}
maillist=`cat $MailList`

mailx -r "HGB_UBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} 執行時間已達${count}分鐘" -a ${LogFile} ${maillist} << EOF
Dears,
   ${progName} Bill_Date:${BillDate} CYCLE:${Cycle} 執行時間已達${count}分鐘，請確認是否正常.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
}

function sendDelaySMS
{
count=$1
	Message=" Warning! over <${count}> minutes ${BillDate} <${Cycle}> ${progName}"
	smslist=`cat $smsList`

	${smsProg} "${Message}" "${smsList}"
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
usage()
{
	echo "Usage:"
	echo " $0 <BILL_DATE> <PROC_TYPE> <CYCLE>"
	echo ""
	echo "For example: $0 20190701 B 50"
	echo "For example: $0 20190701 T 50"
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
echo "PROC_TYPE : ${ProcType}" | tee -a $LogFile
echo "CYCLE : ${Cycle}" | tee -a $LogFile
echo '' | tee -a $LogFile
cd ${WorkDir}
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Extract MAST
echo "----->>>>>-----Step 1. Run Extract MAST Process (Start...)" | tee -a $LogFile
HGB_UBL_Extract $BillDate $Cycle $ProcType
Pause
checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Extract Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
	echo "-----<<<<<-----Step 1. Run Extract MAST Process (End...Failed)" | tee -a $LogFile
	AutoWatch 1
else
	echo "waiting for 60 seconds before check DIO status" | tee -a $LogFile
	sleep 60
	run_cnt=0
	mod_cnt=1
	checkdone=0
	checkerror=0
	checkwait=0
		while [ $checkdone -eq 0 ] 
		do
			echo "----->>>>>-----Step 2. Run Extract DIO Check MAST Process (Start...)" | tee -a $LogFile
			HGB_UBL_Extract_DIO_Check $BillDate $Cycle MAST $ProcType
			sleep 60
			(( run_cnt++ ))
			mod_cnt=`expr $run_cnt % 60`
			checkdone=`cat ${LogDir}/${progName}_DIO_Check.data|grep 'Extract_DIO_Check MAST Process RETURN_CODE = 0000'|wc -l`
			checkerror=`cat ${LogDir}/${progName}_DIO_Check.data|grep -E 'ORA|ora|Extract_DIO_Check MAST Process RETURN_CODE = 9999'|wc -l`
			checkwait=`cat $LogFile|grep 'Extract_DIO_Check MAST Processing'|wc -l`
				if [[ $mod_cnt -eq 0 ]]; then
					echo "Run Count : $run_cnt" | tee -a $LogFile
					echo "!!!please check Extract DIO MAST status!!!" | tee -a $LogFile
					echo "----->>>>>-----Step 2. Run Extract DIO Check MAST Processed `expr $run_cnt / 60`hours (Need to Check...)" | tee -a $LogFile
					sendDelayMail $run_cnt
					if [[ $DB = "HGBBL" ]]; then
						sendDelaySMS $run_cnt
					fi
				fi
				
				if  [[ $checkerror -ge 1 ]]; then
					echo "Error Count : $checkerror" | tee -a $LogFile
					echo "-----<<<<<-----Step 1. Run Extract MAST Process (End...Failed)" | tee -a $LogFile
					echo "-----<<<<<-----Step 2. Run Extract DIO Check MAST Process (End... Failed)" | tee -a $LogFile
					AutoWatch 1
				else
					echo "Run Count : $run_cnt" | tee -a $LogFile
					echo "Done Count : $checkdone" | tee -a $LogFile
					echo "Error Count : $checkerror" | tee -a $LogFile
					echo "Wait Count : $checkwait" | tee -a $LogFile
					echo "---------------Step 2. Run Extract DIO Check MAST Processing" | tee -a $LogFile
					Pause
				fi
		done
	echo "-----<<<<<-----Step 1. Run Extract MAST Process (End... Successed)" | tee -a $LogFile
	echo "-----<<<<<-----Step 2. Run Extract DIO Check MAST Process (End... Successed)" | tee -a $LogFile
fi

AutoWatch 0
