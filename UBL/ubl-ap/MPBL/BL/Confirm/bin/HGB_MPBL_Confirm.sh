#!/usr/bin/ksh
########################################################################################
# Program name : HGB_MPBL_Confirm.sh
# Path : /extsoft/MPBL/BL/Confirm/bin
#
# Date : 2021/02/20 Created by Mike Kuan
# Description : SR222460_MPBS migrate to HGB
########################################################################################
# Date : 2021/02/24 Modify by Mike Kuan
# Description : SR222460_MPBS migrate to HGB - add UPDATE_ACCT_LIST
########################################################################################
# Date : 2021/09/02 Created by Mike Kuan
# Description : SR233414_行動裝置險月繳保費預繳專案
########################################################################################

#---------------------------------------------------------------------------------------#
#      env
#---------------------------------------------------------------------------------------#
progName="HGB_MPBL_Confirm"
sysdt=`date +%Y%m%d%H%M%S`
BillDate=$1
Cycle=$2
ProcessNo=$3
HomeDir=/extsoft/MPBL/BL
WorkDir=$HomeDir/Confirm/bin
LogDir=$HomeDir/Confirm/log
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

function HGB_MPBL_Confirm_MV_ACCT_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_MV_ACCT.data <<EOF
@HGB_MPBL_Confirm_MV_ACCT_Check.sql $1 $2
EOF`
cat ${LogDir}/${progName}_MV_ACCT.data |read ACCT
echo "MV Acct Count: ${ACCT}" | tee -a ${LogFile}
}

function HGB_MPBL_Confirm_STEP_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STEP.data <<EOF
@HGB_MPBL_Confirm_STEP_Check.sql $1 $2 $3
EOF`
cat ${LogDir}/${progName}_STEP.data |read STEP
echo "Step or Message: ${STEP}" | tee -a ${LogFile}
}

function HGB_MPBL_UPDATE_ACCT_LIST
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_UPDATE_ACCT_LIST.data <<EOF
@HGB_MPBL_UPDATE_ACCT_LIST.sql $1 $2
EOF`
cat ${LogDir}/${progName}_UPDATE_ACCT_LIST.data | tee -a ${LogFile}
}

function HGB_MPBL_Confirm_STATUS_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STATUS.data <<EOF
@HGB_MPBL_Confirm_STATUS_Check.sql $1 $2 $3 $4
EOF`
cat ${LogDir}/${progName}_STATUS.data | tee -a ${LogFile}
}

function HGB_MPBL_Confirm
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_MPBL_Confirm.sql $1 $2 $3
exit
EOF`
}

function HGB_MPBL_Confirm_OCS_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_OCS_Check.data <<EOF
@HGB_MPBL_Confirm_OCS_Check.sql $1 $2
EOF`
cat ${LogDir}/${progName}_OCS_Check.data |read COUNT
}

function HGB_MPBL_Confirm_DIO_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_DIO_Check.data <<EOF
@HGB_MPBL_Confirm_DIO_Check.sql $1 $2 $3 $4
exit
EOF`
cat ${LogDir}/${progName}_DIO_Check.data | tee -a ${LogFile}
}

function HGB_MPBL_Confirm_Patch_Change_Cycle
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_Patch_Change_Cycle.data <<EOF
@HGB_MPBL_Confirm_Patch_Change_Cycle.sql $1 $2
EOF`
cat ${LogDir}/${progName}_Patch_Change_Cycle.data | tee -a ${LogFile}
}

function HGB_MPBL_Confirm_USED_UP
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_MPBL_Confirm_USED_UP.sql $1 $2 $3
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

function sendDelayMail
{
count=$1
iconv -f utf8 -t big5 -c ${LogFile} > ${LogFile}.big5
mv ${LogFile}.big5 ${LogFile}
maillist=`cat $MailList`

mailx -r "HGB_MPBL" -s "${progName} Bill_Date:${BillDate} CYCLE:${Cycle} OCS_Confirm執行時間已達${count}分鐘" -a ${LogFile} ${maillist} << EOF
Dears,
   ${progName} Bill_Date:${BillDate} CYCLE:${Cycle} OCS_Confirm執行時間已達${count}分鐘，請確認是否正常.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
}

function sendDelaySMS
{
count=$1
	Message=" Warning! OCS_Confirm runtime over <${count}> minutes ${BillDate} <${Cycle}> ${progName}"
	smslist=`cat $smsList`

	${smsProg} "${Message}" "${smslist}"
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
#------------執行Confirm MV ACCT Check
if [[ ${ProcessNo} -ne 999 ]]; then
	echo "----->>>>>-----Step 888. Run Confirm MV ACCT Check Process (Start...)" | tee -a $LogFile
	HGB_MPBL_Confirm_MV_ACCT_Check $BillDate $Cycle
	checkcode=`cat ${LogDir}/${progName}_MV_ACCT.data|grep -E 'ORA|ora|Confirm_MV_ACCT_Check Process RETURN_CODE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 888. Run Confirm MV ACCT Check Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
	if [[ ${ACCT}-${ACCT} -ne 0 ]]; then
		echo "-----<<<<<-----Step 888. Run Confirm MV ACCT Check Process (End...Get MV Acct Count Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
	echo "-----<<<<<-----Step 888. Run Confirm MV ACCT Check Process (End... Succeeded)" | tee -a $LogFile
fi
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Confirm Step Check
echo "----->>>>>-----Step 0. Run Confirm Step Check Process (Start...)" | tee -a $LogFile
HGB_MPBL_Confirm_STEP_Check $BillDate $Cycle $ProcessNo
checkcode=`cat ${LogDir}/${progName}_STEP.data|grep -E 'ORA|ora|Confirm_STEP_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 0. Run Confirm Step Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 0. Run Confirm Step Check Process (End... Succeeded)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行UPDATE ACCT LIST
if [[ $ProcessNo -eq 999 ]]; then
	echo "----->>>>>-----Step 1. Run UPDATE ACCT LIST Process (Start...)" | tee -a $LogFile
	HGB_MPBL_UPDATE_ACCT_LIST $BillDate $Cycle
	checkcode=`cat ${LogDir}/${progName}_UPDATE_ACCT_LIST.data|grep -E 'ORA|ora|update FY_TB_BL_ACCT_LIST.TYPE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
	echo "-----<<<<<-----Step 1. Run UPDATE ACCT LIST Process (End...Failed)" | tee -a $LogFile
	AutoWatch 1
	fi
	echo "-----<<<<<-----Step 1. Run UPDATE ACCT LIST Process (End... Succeeded)" | tee -a $LogFile
fi
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Confirm STATUS Check
echo "----->>>>>-----Step 2. Run Confirm STATUS Check Process (Start...)" | tee -a $LogFile
HGB_MPBL_Confirm_STATUS_Check $BillDate $Cycle $ProcessNo BEFORE
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Confirm_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 2. Run Confirm STATUS Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 2. Run Confirm STATUS Check Process (End... Succeeded)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
if [[ ${STEP} == 'CN' ]]; then
#------------執行Confirm
	if [[ $DB = "HGBBL" ]]; then
	run_cnt=0
	mod_cnt=1
	checkdone=0
	checkerror=0
	checkwait=0
		while [ $checkdone -eq 0 ] 
		do
			echo "----->>>>>-----Step 3. Run Confirm OCS Check Process (Start...)" | tee -a $LogFile
			HGB_MPBL_Confirm_OCS_Check $BillDate $Cycle
			sleep 60
			(( run_cnt++ ))
			mod_cnt=`expr $run_cnt % 60`
			checkdone=`cat ${LogDir}/${progName}_OCS_Check.data|grep 'Confirm_OCS_Check Process RETURN_CODE = 0000'|wc -l`
			checkerror=`cat ${LogDir}/${progName}_OCS_Check.data|grep -E 'ORA|ora|Confirm_OCS_Check Process RETURN_CODE = 9999'|wc -l`
			checkwait=`cat ${LogDir}/${progName}_OCS_Check.data|grep 'Confirm_OCS_Check Processing'|wc -l`
				if [[ $mod_cnt -eq 0 ]]; then
					echo "Run Count : $run_cnt" | tee -a $LogFile
					echo "!!!please check Confirm OCS Status!!!" | tee -a $LogFile
					echo "-----<<<<<-----Step 3. Run Confirm OCS Check `expr $run_cnt / 60`hours (Need to Check...)" | tee -a $LogFile
					sendDelayMail $run_cnt
					sendDelaySMS $run_cnt
				fi
				
				if  [[ $checkerror -ge 1 ]]; then
					echo "Error Count : $checkerror" | tee -a $LogFile
					echo "-----<<<<<-----Step 3. Run Confirm OCS Check Process (End...Failed)" | tee -a $LogFile
					AutoWatch 1
				elif [[ $checkwait -eq 1 ]]; then
					echo "Run Count : $run_cnt" | tee -a $LogFile
					echo "-----<<<<<-----Step 3. Run Confirm OCS Check Processing" | tee -a $LogFile
					Pause
				else
					echo "Run Count : $run_cnt" | tee -a $LogFile
					echo "Done Count : $checkdone" | tee -a $LogFile
					echo "Error Count : $checkerror" | tee -a $LogFile
					echo "Wait Count : $checkwait" | tee -a $LogFile
					echo "-----<<<<<-----Step 3. Run Confirm OCS Check Process (End...Succeeded)" | tee -a $LogFile
					Pause
				fi
		done
	else
		echo "----->>>>>-----Step 3. Run Confirm OCS Check Process (TEST ENV PASS...)" | tee -a $LogFile
	fi
	
	echo "----->>>>>-----Step 4. Run Confirm Process (Start...)" | tee -a $LogFile
	Pause
	HGB_MPBL_Confirm $BillDate $Cycle $ProcessNo
	checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Confirm Process RETURN_CODE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 4. Run Confirm Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	else
		echo "waiting for 60 seconds before check DIO status" | tee -a $LogFile
		run_cnt=0
		mod_cnt=1
		checkdone=0
		checkerror=0
		checkwait=0
			while [ $checkdone -eq 0 ] 
			do
				echo "----->>>>>-----Step 5. Run Confirm DIO Check MPCONFIRM Process (Start...)" | tee -a $LogFile
				HGB_MPBL_Confirm_DIO_Check $BillDate $Cycle MPCONFIRM $ProcessNo
				sleep 60
				(( run_cnt++ ))
				mod_cnt=`expr $run_cnt % 60`
				checkdone=`cat ${LogDir}/${progName}_DIO_Check.data|grep 'Confirm_DIO_Check MPCONFIRM Process RETURN_CODE = 0000'|wc -l`
				checkerror=`cat ${LogDir}/${progName}_DIO_Check.data|grep -E 'ORA|ora|Confirm_DIO_Check MPCONFIRM Process RETURN_CODE = 9999'|wc -l`
				checkwait=`cat ${LogDir}/${progName}_DIO_Check.data|grep 'Confirm_DIO_Check MPCONFIRM Processing'|wc -l`
					if [[ $mod_cnt -eq 0 ]]; then
						echo "Run Count : $run_cnt" | tee -a $LogFile
						echo "!!!please check Confirm DIO MPCONFIRM status!!!" | tee -a $LogFile
						echo "----->>>>>-----Step 5. Run Confirm DIO Check MPCONFIRM Processed `expr $run_cnt / 60`hours (Need to Check...)" | tee -a $LogFile
						sendDelayMail $run_cnt
						if [[ $DB = "HGBBL" ]]; then
							sendDelaySMS $run_cnt
						fi
					fi
					
					if  [[ $checkerror -ge 1 ]]; then
						echo "Error Count : $checkerror" | tee -a $LogFile
						echo "-----<<<<<-----Step 4. Run Confirm Process (End...Failed)" | tee -a $LogFile
						echo "-----<<<<<-----Step 5. Run Confirm DIO Check MPCONFIRM Process (End... Failed)" | tee -a $LogFile
						AutoWatch 1
					elif [[ $checkwait -eq 1 ]]; then
						echo "Run Count : $run_cnt" | tee -a $LogFile
						echo "-----<<<<<-----Step 5. Run Confirm DIO Check MPCONFIRM Processing" | tee -a $LogFile
						Pause
					else
						echo "Run Count : $run_cnt" | tee -a $LogFile
						echo "Done Count : $checkdone" | tee -a $LogFile
						echo "Error Count : $checkerror" | tee -a $LogFile
						echo "Wait Count : $checkwait" | tee -a $LogFile
						echo "-----<<<<<-----Step 5. Run Confirm DIO Check MPCONFIRM Process (End... Succeeded)" | tee -a $LogFile
						Pause
					fi
			done
		echo "-----<<<<<-----Step 4. Run Confirm Process (End... Succeeded)" | tee -a $LogFile
		Pause
		echo "----->>>>>-----Step 6. Run Confirm_USED_UP Process (Start...)" | tee -a $LogFile
		HGB_MPBL_Confirm_USED_UP $BillDate $ProcessNo $Cycle
		checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Confirm_USED_UP Process RETURN_CODE = 9999'|wc -l`
		if [[ $checkcode -eq 1 ]]; then
			echo "-----<<<<<-----Step 6. Run Confirm_USED_UP Process (End...Failed)" | tee -a $LogFile
			AutoWatch 1
		else
			echo "-----<<<<<-----Step 6. Run Confirm_USED_UP Process (End...Successed)" | tee -a $LogFile
		fi
	fi

	if [[ ${ProcessNo} -ne 999 ]]; then
		if [[ ${ACCT} -ge 1 ]]; then #確認MV ACCT待confirm筆數
			echo "----->>>>>-----Step 7. Run MV Confirm Process (Start...)" | tee -a $LogFile
			Pause
			HGB_MPBL_Confirm $BillDate $Cycle 888
			checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Confirm Process RETURN_CODE = 9999'|wc -l`
			if [[ $checkcode -ge 1 ]]; then
				echo "-----<<<<<-----Step 7. Run MV Confirm Process (End...Failed)" | tee -a $LogFile
				AutoWatch 1
			else
				echo "waiting for 60 seconds before check DIO status" | tee -a $LogFile
				run_cnt=0
				mod_cnt=1
				checkdone=0
				checkerror=0
				checkwait=0
					while [ $checkdone -eq 0 ] 
					do
						echo "----->>>>>-----Step 8. Run MV Confirm DIO Check MPCONFIRM Process (Start...)" | tee -a $LogFile
						HGB_MPBL_Confirm_DIO_Check $BillDate $Cycle MPCONFIRM 888
						sleep 60
						(( run_cnt++ ))
						mod_cnt=`expr $run_cnt % 60`
						checkdone=`cat ${LogDir}/${progName}_DIO_Check.data|grep 'Confirm_DIO_Check MPCONFIRM Process RETURN_CODE = 0000'|wc -l`
						checkerror=`cat ${LogDir}/${progName}_DIO_Check.data|grep -E 'ORA|ora|Confirm_DIO_Check MPCONFIRM Process RETURN_CODE = 9999'|wc -l`
						checkwait=`cat ${LogDir}/${progName}_DIO_Check.data|grep 'Confirm_DIO_Check MPCONFIRM Processing'|wc -l`
							if [[ $mod_cnt -eq 0 ]]; then
								echo "Run Count : $run_cnt" | tee -a $LogFile
								echo "!!!please check Confirm DIO MPCONFIRM status!!!" | tee -a $LogFile
								echo "----->>>>>-----Step 8. Run MV Confirm DIO Check MPCONFIRM Processed `expr $run_cnt / 60`hours (Need to Check...)" | tee -a $LogFile
								sendDelayMail $run_cnt
								if [[ $DB = "HGBBL" ]]; then
									sendDelaySMS $run_cnt
								fi
							fi
							
							if  [[ $checkerror -ge 1 ]]; then
								echo "Error Count : $checkerror" | tee -a $LogFile
								echo "-----<<<<<-----Step 7. Run MV Confirm Process (End...Failed)" | tee -a $LogFile
								echo "-----<<<<<-----Step 8. Run MV Confirm DIO Check MPCONFIRM Process (End... Failed)" | tee -a $LogFile
								AutoWatch 1
							elif [[ $checkwait -eq 1 ]]; then
								echo "Run Count : $run_cnt" | tee -a $LogFile
								echo "-----<<<<<-----Step 8. Run MV Confirm DIO Check MPCONFIRM Processing" | tee -a $LogFile
								Pause
							else
								echo "Run Count : $run_cnt" | tee -a $LogFile
								echo "Done Count : $checkdone" | tee -a $LogFile
								echo "Error Count : $checkerror" | tee -a $LogFile
								echo "Wait Count : $checkwait" | tee -a $LogFile
								echo "-----<<<<<-----Step 8. Run MV Confirm DIO Check MPCONFIRM Process (End... Succeeded)" | tee -a $LogFile
								Pause
							fi
					done		
				echo "-----<<<<<-----Step 7. Run MV Confirm Process (End... Succeeded)" | tee -a $LogFile
				Pause
				echo "----->>>>>-----Step 9. Run Confirm_USED_UP Process (Start...)" | tee -a $LogFile
				HGB_MPBL_Confirm_USED_UP $BillDate 888 $Cycle
				checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Confirm_USED_UP Process RETURN_CODE = 9999'|wc -l`
				if [[ $checkcode -eq 1 ]]; then
					echo "-----<<<<<-----Step 9. Run Confirm_USED_UP Process (End...Failed)" | tee -a $LogFile
					AutoWatch 1
				else
					echo "-----<<<<<-----Step 9. Run Confirm_USED_UP Process (End...Successed)" | tee -a $LogFile
				fi
			fi
		else
			echo "MV ACCT is : ${ACCT}" | tee -a $LogFile
		fi
	fi
else
	echo "Confirm Status not in ('CN')" | tee -a $LogFile
fi		
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Confirm STATUS Check
echo "----->>>>>-----Step 10. Run Confirm STATUS Check Process (Start...)" | tee -a $LogFile
HGB_MPBL_Confirm_STATUS_Check $BillDate $Cycle $ProcessNo AFTER
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Confirm_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 10. Run Confirm STATUS Check Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
echo "-----<<<<<-----Step 10. Run Confirm STATUS Check Process (End... Succeeded)" | tee -a $LogFile
Pause
echo "----->>>>>-----Step 11. Run Confirm MV STATUS Check Process (Start...)" | tee -a $LogFile
if [[ ${ACCT} -ge 1 ]]; then #確認MV ACCT已confirm狀態
HGB_MPBL_Confirm_STATUS_Check $BillDate $Cycle 888 AFTER
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Confirm_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 11. Run Confirm MV STATUS Check Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
echo "-----<<<<<-----Step 11. Run Confirm MV STATUS Check Process (End... Succeeded)" | tee -a $LogFile
fi
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Patch Change Cycle
echo "----->>>>>-----Step 12. Run Confirm Patch Change Cycle Process (Start...)" | tee -a $LogFile
HGB_MPBL_Confirm_Patch_Change_Cycle $BillDate $Cycle
checkcode=`cat ${LogDir}/${progName}_Patch_Change_Cycle.data|grep -E 'ORA|ora|Confirm_Patch_Change_Cycle Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 12. Run Confirm Patch Change Cycle Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 12. Run Confirm Patch Change Cycle Process (End... Succeeded)" | tee -a $LogFile

AutoWatch 0
