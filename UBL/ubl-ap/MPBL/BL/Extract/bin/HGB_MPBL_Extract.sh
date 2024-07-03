#!/usr/bin/ksh
########################################################################################
# Program name : HGB_MPBL_Extract.sh
# Path : /extsoft/MPBL/BL/Extract/bin
#
# Date : 2021/02/20 Created by Mike Kuan
# Description : SR222460_MPBS migrate to HGB
########################################################################################
# Date : 2021/02/22 Modify by Mike Kuan
# Description : SR222460_MPBS migrate to HGB - fix SMS
########################################################################################
# Date : 2021/10/26 Modify by Mike Kuan
# Description : SR239378_SD-WAN 移除ProcessNo
########################################################################################

#---------------------------------------------------------------------------------------#
#      env
#---------------------------------------------------------------------------------------#
progName="HGB_MPBL_Extract"
sysdt=`date +%Y%m%d%H%M%S`
BillDate=$1
Cycle=$2
HomeDir=/extsoft/MPBL/BL
WorkDir=$HomeDir/Extract/bin
LogDir=$HomeDir/Extract/log
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

function HGB_MPBL_Extract
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}.data <<EOF
@HGB_MPBL_Extract.sql $1 $2 $3
exit
EOF`
cat ${LogDir}/${progName}.data | tee -a ${LogFile}
}

function HGB_MPBL_Extract_Ready
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_Ready.data <<EOF
@HGB_MPBL_Extract_Ready.sql $1 $2
exit
EOF`
cat ${LogDir}/${progName}_Ready.data | tee -a ${LogFile}
}

function HGB_MPBL_Extract_DIO_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_DIO_Check.data <<EOF
@HGB_MPBL_Extract_DIO_Check.sql $1 $2 $3 $4
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
   echo "Send AutoWatch (Successed)" | tee -a $LogFile
   echo "${progName},Normal,${AutoWatchDate}" >> $AutoWatchFile
   echo '' | tee -a $LogFile
   if [[ $DB = "HGBBL" ]]; then
   		echo "Send SMS (Successed)" | tee -a $LogFile
		sendSMS 1
		echo "FTP Command: ${ftpProg} ${putip1} ${putuser1} ******** ${AutoWatchDir} ${putpath1} ${AutoWatchFileName} 0" | tee -a ${logFile}
		${ftpProg} ${putip1} ${putuser1} ${putpass1} ${AutoWatchDir} ${putpath1} ${AutoWatchFileName} 0
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
tar zcvf ${progName}_${sysdt}.tar.tgz ${progName}_${sysdt}.log
maillist=`cat $MailList`

if [[ $type -eq 1 ]]; then
mailx -r "HGB_MPBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} Normal" -a ${progName}_${sysdt}.tar.tgz ${maillist} << EOF
Dears,
   ${progName} CYCLE:${Cycle} Bill_Date:${BillDate} Successed.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
sysdt_END=`date '+%Y/%m/%d-%H:%M:%S'`
echo "${sysdt_END} ------------------------------END ${progName}------------------------------" | tee -a $LogFile
elif [[ $type -eq 2 ]]; then
mailx -r "HGB_MPBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} Start" ${maillist} << EOF
Dears,
   ${progName} CYCLE:${Cycle} Bill_Date:${BillDate} Start.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
else
mailx -r "HGB_MPBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} Abnormal" -a ${progName}_${sysdt}.tar.tgz ${maillist}  << EOF
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

if [[ $type -eq 1 ]]; then
	${smsProg} "${okMessage}" "${smslist}"
elif [[ $type -eq 2 ]]; then
	${smsProg} "${startMessage}" "${smslist}"
else
	${smsProg} "${errorMessage}" "${smslist}"
fi
}

function sendDelayMail
{
count=$1
iconv -f utf8 -t big5 -c ${LogFile} > ${LogFile}.big5
mv ${LogFile}.big5 ${LogFile}
maillist=`cat $MailList`

mailx -r "HGB_MPBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} 執行時間已達${count}分鐘" -a ${LogFile} ${maillist} << EOF
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

	${smsProg} "${Message}" "${smslist}"
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
usage()
{
	echo "Usage:"
	echo " $0 <BILL_DATE> <CYCLE>"
	echo ""
    echo "For example: $0 20210301 50"
    echo "For example: $0 20210303 51"
    echo "For example: $0 20210305 52"
    echo "For example: $0 20210308 53"
    echo "For example: $0 20210311 54"
    echo "For example: $0 20210314 55"
    echo "For example: $0 20210317 56"
    echo "For example: $0 20210220 57"
    echo "For example: $0 20210223 58"
    echo "For example: $0 20210225 59"
	echo "For example: $0 20210227 60"
	echo ""
}

if [[ $# -lt 2 ]]; then
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
#------------執行Extract MPMAST
echo "----->>>>>-----Step 1. Run Extract MPMAST Process (Start...)" | tee -a $LogFile
HGB_MPBL_Extract $BillDate $Cycle
Pause
checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Extract Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
	echo "-----<<<<<-----Step 1. Run Extract MPMAST Process (End...Failed)" | tee -a $LogFile
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
			echo "----->>>>>-----Step 2. Run Extract DIO Check MPMAST Process (Start...)" | tee -a $LogFile
			HGB_MPBL_Extract_DIO_Check $BillDate $Cycle MPMAST
			sleep 60
			(( run_cnt++ ))
			mod_cnt=`expr $run_cnt % 60`
			checkdone=`cat ${LogDir}/${progName}_DIO_Check.data|grep 'Extract_DIO_Check MPMAST Process RETURN_CODE = 0000'|wc -l`
			checkerror=`cat ${LogDir}/${progName}_DIO_Check.data|grep -E 'ORA|ora|Extract_DIO_Check MPMAST Process RETURN_CODE = 9999'|wc -l`
			checkwait=`cat $LogFile|grep 'Extract_DIO_Check MPMAST Processing'|wc -l`
				if [[ $mod_cnt -eq 0 ]]; then
					echo "Run Count : $run_cnt" | tee -a $LogFile
					echo "!!!please check Extract DIO MPMAST status!!!" | tee -a $LogFile
					echo "----->>>>>-----Step 2. Run Extract DIO Check MPMAST Processed `expr $run_cnt / 60`hours (Need to Check...)" | tee -a $LogFile
					sendDelayMail $run_cnt
					if [[ $DB = "HGBBL" ]]; then
						sendDelaySMS $run_cnt
					fi
				fi
				
				if  [[ $checkerror -ge 1 ]]; then
					echo "Error Count : $checkerror" | tee -a $LogFile
					echo "-----<<<<<-----Step 1. Run Extract MPMAST Process (End...Failed)" | tee -a $LogFile
					echo "-----<<<<<-----Step 2. Run Extract DIO Check MPMAST Process (End... Failed)" | tee -a $LogFile
					AutoWatch 1
				else
					echo "Run Count : $run_cnt" | tee -a $LogFile
					echo "Done Count : $checkdone" | tee -a $LogFile
					echo "Error Count : $checkerror" | tee -a $LogFile
					echo "Wait Count : $checkwait" | tee -a $LogFile
					echo "---------------Step 2. Run Extract DIO Check MPMAST Processing" | tee -a $LogFile
					Pause
				fi
		done
	echo "-----<<<<<-----Step 1. Run Extract MPMAST Process (End... Successed)" | tee -a $LogFile
	echo "-----<<<<<-----Step 2. Run Extract DIO Check MPMAST Process (End... Successed)" | tee -a $LogFile
fi
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Extract MPREADY
echo "----->>>>>-----Step 3. Run Extract MPREADY Process (Start...)" | tee -a $LogFile
HGB_MPBL_Extract_Ready $BillDate $Cycle
Pause
checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Extract MPREADY Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
	echo "-----<<<<<-----Step 3. Run Extract MPREADY Process (End...Failed)" | tee -a $LogFile
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
			echo "----->>>>>-----Step 4. Run Extract DIO Check MPREADY Process (Start...)" | tee -a $LogFile
			HGB_MPBL_Extract_DIO_Check $BillDate $Cycle MPREADY
			sleep 60
			(( run_cnt++ ))
			mod_cnt=`expr $run_cnt % 60`
			checkdone=`cat ${LogDir}/${progName}_DIO_Check.data|grep 'Extract_DIO_Check MPREADY Process RETURN_CODE = 0000'|wc -l`
			checkerror=`cat ${LogDir}/${progName}_DIO_Check.data|grep -E 'ORA|ora|Extract_DIO_Check MPREADY Process RETURN_CODE = 9999'|wc -l`
			checkwait=`cat $LogFile|grep 'Extract_DIO_Check MPREADY Processing'|wc -l`
				if [[ $mod_cnt -eq 0 ]]; then
					echo "Run Count : $run_cnt" | tee -a $LogFile
					echo "!!!please check Extract DIO status!!!" | tee -a $LogFile
					echo "----->>>>>-----Step 4. Run Extract DIO Check MPREADY Processed `expr $run_cnt / 60`hours (Need to Check...)" | tee -a $LogFile
					sendDelayMail $run_cnt
					if [[ $DB = "HGBBL" ]]; then
						sendDelaySMS $run_cnt
					fi
				fi
				
				if  [[ $checkerror -ge 1 ]]; then
					echo "Error Count : $checkerror" | tee -a $LogFile
					echo "-----<<<<<-----Step 3. Run Extract MPREADY Process (End...Failed)" | tee -a $LogFile
					echo "-----<<<<<-----Step 4. Run Extract DIO Check MPREADY Process (End... Failed)" | tee -a $LogFile
					AutoWatch 1
				else
					echo "Run Count : $run_cnt" | tee -a $LogFile
					echo "Done Count : $checkdone" | tee -a $LogFile
					echo "Error Count : $checkerror" | tee -a $LogFile
					echo "Wait Count : $checkwait" | tee -a $LogFile
					Pause
				fi
		done
	echo "-----<<<<<-----Step 3. Run Extract MPREADY Process (End... Successed)" | tee -a $LogFile
	echo "-----<<<<<-----Step 4. Run Extract DIO Check MPREADY Process (End... Successed)" | tee -a $LogFile
fi

AutoWatch 0
