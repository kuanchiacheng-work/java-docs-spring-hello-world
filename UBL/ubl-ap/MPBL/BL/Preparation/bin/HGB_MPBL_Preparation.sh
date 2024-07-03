#!/usr/bin/ksh
########################################################################################
# Program name : HGB_MPBL_Preparation.sh
# Path : /extsoft/MPBL/BL/Preparation/bin
#
# Date : 2021/02/20 Created by Mike Kuan
# Description : SR222460_MPBS migrate to HGB
########################################################################################
# Date : 2021/02/22 Modify by Mike Kuan
# Description : SR222460_MPBS migrate to HGB - fix SMS
########################################################################################
# Date : 2021/09/02 Created by Mike Kuan
# Description : SR233414_行動裝置險月繳保費預繳專案
########################################################################################

#---------------------------------------------------------------------------------------#
#      env
#---------------------------------------------------------------------------------------#
progName="HGB_MPBL_Preparation"
sysdt=`date +%Y%m%d%H%M%S`
BillDate=$1
Cycle=$2
ProcessNo=$3
HomeDir=/extsoft/MPBL/BL
WorkDir=$HomeDir/Preparation/bin
LogDir=$HomeDir/Preparation/log
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

function HGB_MPBL_Preparation_MV_ACCT_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_MV_ACCT.data <<EOF
@HGB_MPBL_Preparation_MV_ACCT_Check.sql $1 $2
EOF`
cat ${LogDir}/${progName}_MV_ACCT.data |read ACCT
echo "MV Acct Count: ${ACCT}" | tee -a ${LogFile}
}

function HGB_MPBL_Preparation_STEP_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STEP.data <<EOF
@HGB_MPBL_Preparation_STEP_Check.sql $1 $2 $3
EOF`
cat ${LogDir}/${progName}_STEP.data |read STEP
echo "Step or Message: ${STEP}" | tee -a ${LogFile}
}

function HGB_MPBL_Preparation_STATUS_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STATUS.data <<EOF
@HGB_MPBL_Preparation_STATUS_Check.sql $1 $2 $3
EOF`
cat ${LogDir}/${progName}_STATUS.data | tee -a ${LogFile}
}

function HGB_MPBL_Preparation_CI
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_MPBL_Preparation.sql $1 $2 $3 CI
exit
EOF`
}

function HGB_MPBL_Preparation_BI
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_MPBL_Preparation.sql $1 $2 $3 BI
exit
EOF`
}

function HGB_MPBL_Preparation_AR_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_AR.data <<EOF
@HGB_MPBL_Preparation_AR_Check.sql $1 $2 $3
EOF`
cat ${LogDir}/${progName}_AR.data |read STATUS
}

function HGB_MPBL_Preparation_MAST
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_MPBL_Preparation.sql $1 $2 $3 MAST
exit
EOF`
}

function HGB_MPBL_Preparation_ERROR_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_Error.data <<EOF
@HGB_MPBL_Preparation_ERROR_Check.sql $1 $2 $3
EOF`
cat ${LogDir}/${progName}_Error.data | tee -a ${LogFile}
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
	echo "----->>>>>-----Step 888. Run Preparation MV ACCT Check Process (Start...)" | tee -a $LogFile
	HGB_MPBL_Preparation_MV_ACCT_Check $BillDate $Cycle
	checkcode=`cat ${LogDir}/${progName}_MV_ACCT.data|grep -E 'ORA|ora|Preparation_MV_ACCT_Check Process RETURN_CODE = 9999'|wc -l`
	if [[ $checkcode -ge 1 ]]; then
		echo "-----<<<<<-----Step 888. Run Preparation MV ACCT Check Process (End...Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
	if [[ ${ACCT}-${ACCT} -ne 0 ]]; then
		echo "-----<<<<<-----Step 888. Run Preparation MV ACCT Check Process (End...Get MV Acct Count Failed)" | tee -a $LogFile
		AutoWatch 1
	fi
	echo "-----<<<<<-----Step 888. Run Preparation MV ACCT Check Process (End... Succeeded)" | tee -a $LogFile
fi
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Preparation Step Check
echo "----->>>>>-----Step 0. Run Preparation Step Check Process (Start...)" | tee -a $LogFile
HGB_MPBL_Preparation_STEP_Check $BillDate $Cycle $ProcessNo
checkcode=`cat ${LogDir}/${progName}_STEP.data|grep -E 'ORA|ora|Preparation_STEP_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 0. Run Preparation Step Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 0. Run Preparation Step Check Process (End... Succeeded)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Preparation Status Check
echo "----->>>>>-----Step 1. Run Preparation Status Check Process (Start...)" | tee -a $LogFile
HGB_MPBL_Preparation_STATUS_Check $BillDate $Cycle $ProcessNo
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Preparation_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 1. Run Preparation Status Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 1. Run Preparation Status Check Process (End... Succeeded)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
if [[ ${STEP} == 'CI' ]]; then
#------------執行Preparation_CI, Preparation_BI, Preparation_MAST
	echo "----->>>>>-----Step 2. Run Preparation_CI Process (Start...)" | tee -a $LogFile
	HGB_MPBL_Preparation_CI $BillDate $Cycle $ProcessNo
	checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_CI Process RETURN_CODE = 9999'|wc -l`
		if [[ $checkcode -ge 1 ]]; then
			echo "-----<<<<<-----Step 2. Run Preparation_CI Process (End...Failed)" | tee -a $LogFile
			AutoWatch 1
		else
			echo "-----<<<<<-----Step 2. Run Preparation_CI Process (End... Succeeded)" | tee -a $LogFile
			Pause
			if [[ ${ProcessNo} -ne 999 ]]; then
				echo "----->>>>>-----Step 888. Run MV Preparation_CI Process (Start...)" | tee -a $LogFile
				if [[ ${ACCT} -ge 1 ]]; then #確認MV ACCT待process筆數
					HGB_MPBL_Preparation_CI $BillDate $Cycle 888
					checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_CI Process RETURN_CODE = 9999'|wc -l`
						if [[ $checkcode -ge 1 ]]; then
							echo "-----<<<<<-----Step 888. Run Preparation_CI Process (End...Failed)" | tee -a $LogFile
							AutoWatch 1
						fi
				else
					echo "MV Acct Count: ${ACCT}" | tee -a ${LogFile}
				fi
				echo "----->>>>>-----Step 888. Run MV Preparation_CI Process (End...)" | tee -a $LogFile
			Pause
			fi
			echo "----->>>>>-----Step 3. Run Preparation_BI Process (Start...)" | tee -a $LogFile
			HGB_MPBL_Preparation_BI $BillDate $Cycle $ProcessNo
			checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_BI Process RETURN_CODE = 9999'|wc -l`
				if [[ $checkcode -ge 1 ]]; then
					echo "-----<<<<<-----Step 3. Run Preparation_BI Process (End...Failed)" | tee -a $LogFile
					AutoWatch 1
				else
					echo "-----<<<<<-----Step 3. Run Preparation_BI Process (End... Succeeded)" | tee -a $LogFile
					Pause
					if [[ ${ProcessNo} -ne 999 ]]; then
						echo "----->>>>>-----Step 888. Run MV Preparation_BI Process (Start...)" | tee -a $LogFile
						if [[ ${ACCT} -ge 1 ]]; then #確認MV ACCT待process筆數
							HGB_MPBL_Preparation_BI $BillDate $Cycle 888
							checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_CI Process RETURN_CODE = 9999'|wc -l`
								if [[ $checkcode -ge 1 ]]; then
									echo "-----<<<<<-----Step 888. Run Preparation_BI Process (End...Failed)" | tee -a $LogFile
									AutoWatch 1
								fi
						else
							echo "MV Acct Count: ${ACCT}" | tee -a ${LogFile}
						fi
						echo "----->>>>>-----Step 888. Run MV Preparation_BI Process (End...)" | tee -a $LogFile
					fi
					Pause					
					run_cnt=0
					checkdone=0
					checkerror=0
					checkwait=0
						while [ $checkdone -eq 0 ] 
						do
							echo "----->>>>>-----Step 4. Run Preparation AR Check Process (Start...)" | tee -a $LogFile
							sleep 600
							HGB_MPBL_Preparation_AR_Check $BillDate $Cycle $ProcessNo
							checkdone=`cat ${LogDir}/${progName}_AR.data|grep 'Preparation_AR_Check Process RETURN_CODE = 0000'|wc -l`
							checkerror=`cat ${LogDir}/${progName}_AR.data|grep -E 'ORA|ora|Preparation_AR_Check Process RETURN_CODE = 9999'|wc -l`
							checkwait=`cat ${LogDir}/${progName}_AR.data|grep 'Preparation_AR_Check Processing'|wc -l`
							(( run_cnt++ ))
								if [[ $run_cnt -eq 20 ]]; then
									echo "Run Count : $run_cnt" | tee -a $LogFile
									echo "!!! please check AR Balance to BL status, then rerun $0 $1 $2 $3 !!!" | tee -a $LogFile
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Failed)" | tee -a $LogFile
									AutoWatch 1
								elif  [[ $checkerror -ge 1 ]]; then
									echo "Error Count : $checkerror"
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Failed)" | tee -a $LogFile
									AutoWatch 1
								elif [[ $checkwait -eq 1 ]]; then
									echo "Run Count : $run_cnt" | tee -a $LogFile
									echo "----->>>>>-----Step 4. Run Preparation_AR_Check Processing" | tee -a $LogFile
									Pause
								else
									echo "Run Count : $run_cnt" | tee -a $LogFile
									echo "Done Count : $checkdone" | tee -a $LogFile
									echo "Error Count : $checkerror" | tee -a $LogFile
									echo "Wait Count : $checkwait" | tee -a $LogFile
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Succeeded)" | tee -a $LogFile
									Pause
								fi
						done
					echo "----->>>>>-----Step 5. Run Preparation_MAST Process (Start...)" | tee -a $LogFile
					HGB_MPBL_Preparation_MAST $BillDate $Cycle $ProcessNo
					checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_MAST Process RETURN_CODE = 9999'|wc -l`
						if [[ $checkcode -ge 1 ]]; then
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Failed)" | tee -a $LogFile
							AutoWatch 1
						else
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Succeeded)" | tee -a $LogFile
							Pause
							if [[ ${ProcessNo} -ne 999 ]]; then
								echo "----->>>>>-----Step 888. Run MV Preparation_MAST Process (Start...)" | tee -a $LogFile
								if [[ ${ACCT} -ge 1 ]]; then #確認MV ACCT待process筆數
									HGB_MPBL_Preparation_MAST $BillDate $Cycle 888
									checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_CI Process RETURN_CODE = 9999'|wc -l`
										if [[ $checkcode -ge 1 ]]; then
											echo "-----<<<<<-----Step 888. Run Preparation_MAST Process (End...Failed)" | tee -a $LogFile
											AutoWatch 1
										fi
								else
									echo "MV Acct Count: ${ACCT}" | tee -a ${LogFile}
								fi
								echo "----->>>>>-----Step 888. Run MV Preparation_MAST Process (End...)" | tee -a $LogFile
							fi
							Pause
						fi
				fi
		fi
#----------------------------------------------------------------------------------------------------
elif [[ ${STEP} == 'BI' ]]; then
#------------執行Preparation_BI, Preparation_MAST
			echo "--------------------Before Step... 2. Run Preparation_CI Process (End... Succeeded)--------------------" | tee -a $LogFile
			Pause
			echo "----->>>>>-----Step 3. Run Preparation_BI Process (Start...)" | tee -a $LogFile
			HGB_MPBL_Preparation_BI $BillDate $Cycle $ProcessNo
			checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_BI Process RETURN_CODE = 9999'|wc -l`
				if [[ $checkcode -ge 1 ]]; then
					echo "-----<<<<<-----Step 3. Run Preparation_BI Process (End...Failed)" | tee -a $LogFile
					AutoWatch 1
				else
					echo "-----<<<<<-----Step 3. Run Preparation_BI Process (End... Succeeded)" | tee -a $LogFile
					Pause
					if [[ ${ProcessNo} -ne 999 ]]; then
						echo "----->>>>>-----Step 888. Run MV Preparation_BI Process (Start...)" | tee -a $LogFile
						if [[ ${ACCT} -ge 1 ]]; then #確認MV ACCT待process筆數
							HGB_MPBL_Preparation_BI $BillDate $Cycle 888
							checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_CI Process RETURN_CODE = 9999'|wc -l`
								if [[ $checkcode -ge 1 ]]; then
									echo "-----<<<<<-----Step 888. Run Preparation_BI Process (End...Failed)" | tee -a $LogFile
									AutoWatch 1
								fi
						else
							echo "MV Acct Count: ${ACCT}" | tee -a ${LogFile}
						fi
						echo "----->>>>>-----Step 888. Run MV Preparation_BI Process (End...)" | tee -a $LogFile
					fi
					Pause
					run_cnt=0
					checkdone=0
					checkerror=0
					checkwait=0
						while [ $checkdone -eq 0 ] 
						do
							echo "----->>>>>-----Step 4. Run Preparation AR Check Process (Start...)" | tee -a $LogFile
							sleep 600
							HGB_MPBL_Preparation_AR_Check $BillDate $Cycle $ProcessNo
							checkdone=`cat ${LogDir}/${progName}_AR.data|grep 'Preparation_AR_Check Process RETURN_CODE = 0000'|wc -l`
							checkerror=`cat ${LogDir}/${progName}_AR.data|grep -E 'ORA|ora|Preparation_AR_Check Process RETURN_CODE = 9999'|wc -l`
							checkwait=`cat ${LogDir}/${progName}_AR.data|grep 'Preparation_AR_Check Processing'|wc -l`
							(( run_cnt++ ))
								if [[ $run_cnt -eq 20 ]]; then
									echo "Run Count : $run_cnt" | tee -a $LogFile
									echo "!!! please check AR Balance to BL status, then rerun $0 $1 $2 $3 !!!" | tee -a $LogFile
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Failed)" | tee -a $LogFile
									AutoWatch 1
								elif  [[ $checkerror -ge 1 ]]; then
									echo "Error Count : $checkerror"
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Failed)" | tee -a $LogFile
									AutoWatch 1
								elif [[ $checkwait -eq 1 ]]; then
									echo "Run Count : $run_cnt" | tee -a $LogFile
									echo "----->>>>>-----Step 4. Run Preparation_AR_Check Processing" | tee -a $LogFile
									Pause
								else
									echo "Run Count : $run_cnt" | tee -a $LogFile
									echo "Done Count : $checkdone" | tee -a $LogFile
									echo "Error Count : $checkerror" | tee -a $LogFile
									echo "Wait Count : $checkwait" | tee -a $LogFile
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Succeeded)" | tee -a $LogFile
									Pause
								fi
						done
					echo "----->>>>>-----Step 5. Run Preparation_MAST Process (Start...)" | tee -a $LogFile
					HGB_MPBL_Preparation_MAST $BillDate $Cycle $ProcessNo
					checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_MAST Process RETURN_CODE = 9999'|wc -l`
						if [[ $checkcode -ge 1 ]]; then
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Failed)" | tee -a $LogFile
							AutoWatch 1
						else
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Succeeded)" | tee -a $LogFile
							Pause
							if [[ ${ProcessNo} -ne 999 ]]; then
								echo "----->>>>>-----Step 888. Run MV Preparation_MAST Process (Start...)" | tee -a $LogFile
								if [[ ${ACCT} -ge 1 ]]; then #確認MV ACCT待process筆數
									HGB_MPBL_Preparation_MAST $BillDate $Cycle 888
									checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_CI Process RETURN_CODE = 9999'|wc -l`
										if [[ $checkcode -ge 1 ]]; then
											echo "-----<<<<<-----Step 888. Run Preparation_MAST Process (End...Failed)" | tee -a $LogFile
											AutoWatch 1
										fi
								else
									echo "MV Acct Count: ${ACCT}" | tee -a ${LogFile}
								fi
								echo "----->>>>>-----Step 888. Run MV Preparation_MAST Process (End...)" | tee -a $LogFile
							fi
							Pause
						fi
				fi
#----------------------------------------------------------------------------------------------------
elif [[ ${STEP} == 'MAST' ]]; then
#------------執行Preparation_MAST
					echo "--------------------Before Step... 2. Run Preparation_CI Process (End... Succeeded)--------------------" | tee -a $LogFile
					echo "--------------------Before Step... 3. Run Preparation_BI Process (End... Succeeded)--------------------" | tee -a $LogFile
					Pause
					run_cnt=0
					checkdone=0
					checkerror=0
					checkwait=0
						while [ $checkdone -eq 0 ] 
						do
							echo "----->>>>>-----Step 4. Run Preparation AR Check Process (Start...)" | tee -a $LogFile
							sleep 600
							HGB_MPBL_Preparation_AR_Check $BillDate $Cycle $ProcessNo
							checkdone=`cat ${LogDir}/${progName}_AR.data|grep 'Preparation_AR_Check Process RETURN_CODE = 0000'|wc -l`
							checkerror=`cat ${LogDir}/${progName}_AR.data|grep -E 'ORA|ora|Preparation_AR_Check Process RETURN_CODE = 9999'|wc -l`
							checkwait=`cat ${LogDir}/${progName}_AR.data|grep 'Preparation_AR_Check Processing'|wc -l`
							(( run_cnt++ ))
								if [[ $run_cnt -eq 20 ]]; then
									echo "Run Count : $run_cnt" | tee -a $LogFile
									echo "!!! please check AR Balance to BL status, then rerun $0 $1 $2 $3 !!!" | tee -a $LogFile
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Failed)" | tee -a $LogFile
									AutoWatch 1
								elif  [[ $checkerror -ge 1 ]]; then
									echo "Error Count : $checkerror"
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Failed)" | tee -a $LogFile
									AutoWatch 1
								elif [[ $checkwait -eq 1 ]]; then
									echo "Run Count : $run_cnt" | tee -a $LogFile
									echo "----->>>>>-----Step 4. Run Preparation_AR_Check Processing" | tee -a $LogFile
									Pause
								else
									echo "Run Count : $run_cnt" | tee -a $LogFile
									echo "Done Count : $checkdone" | tee -a $LogFile
									echo "Error Count : $checkerror" | tee -a $LogFile
									echo "Wait Count : $checkwait" | tee -a $LogFile
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Succeeded)" | tee -a $LogFile
									Pause
								fi
						done
					echo "----->>>>>-----Step 5. Run Preparation_MAST Process (Start...)" | tee -a $LogFile
					HGB_MPBL_Preparation_MAST $BillDate $Cycle $ProcessNo
					checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_MAST Process RETURN_CODE = 9999'|wc -l`
						if [[ $checkcode -ge 1 ]]; then
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Failed)" | tee -a $LogFile
							AutoWatch 1
						else
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Succeeded)" | tee -a $LogFile
							Pause
							if [[ ${ProcessNo} -ne 999 ]]; then
								echo "----->>>>>-----Step 888. Run MV Preparation_MAST Process (Start...)" | tee -a $LogFile
								if [[ ${ACCT} -ge 1 ]]; then #確認MV ACCT待process筆數
									HGB_MPBL_Preparation_MAST $BillDate $Cycle 888
									checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_CI Process RETURN_CODE = 9999'|wc -l`
										if [[ $checkcode -ge 1 ]]; then
											echo "-----<<<<<-----Step 888. Run Preparation_MAST Process (End...Failed)" | tee -a $LogFile
											AutoWatch 1
										fi
								else
									echo "MV Acct Count: ${ACCT}" | tee -a ${LogFile}
								fi
								echo "----->>>>>-----Step 888. Run MV Preparation_MAST Process (End...)" | tee -a $LogFile
							fi
							Pause
						fi
else
	echo "Preparation Status not in ('CI','BI','MAST')" | tee -a $LogFile
fi		
Pause

#----------------------------------------------------------------------------------------------------
#------------執行Preparation Status Check
echo "----->>>>>-----Step 6. Run Preparation Status Check Process (Start...)" | tee -a $LogFile
HGB_MPBL_Preparation_STATUS_Check $BillDate $Cycle $ProcessNo
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Preparation_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
	echo "-----<<<<<-----Step 6. Run Preparation Status Check Process (End...Failed)" | tee -a $LogFile
	AutoWatch 1
fi
echo "-----<<<<<-----Step 6. Run Preparation Status Check Process (End... Succeeded)" | tee -a $LogFile

#----------------------------------------------------------------------------------------------------
#------------執行Preparation ERROR Check
echo "----->>>>>-----Step 7. Run Preparation Error Check Process (Start...)" | tee -a $LogFile
HGB_MPBL_Preparation_ERROR_Check $BillDate $Cycle $ProcessNo
checkcode=`cat ${LogDir}/${progName}_Error.data|grep -E 'ORA|ora|Preparation_Error_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
	echo "-----<<<<<-----Step 7. Run Preparation Error Check Process (End...Failed)" | tee -a $LogFile
	AutoWatch 1
fi
echo "-----<<<<<-----Step 7. Run Preparation Error Check Process (End... Succeeded)" | tee -a $LogFile
Pause
if [[ ${ProcessNo} -ne 999 ]]; then
	echo "----->>>>>-----Step 888. Run MV Preparation Error Check Process (Start...)" | tee -a $LogFile
		if [[ ${ACCT} -ge 1 ]]; then #確認MV ACCT待process筆數
			HGB_MPBL_Preparation_ERROR_Check $BillDate $Cycle 888
			checkcode=`cat ${LogDir}/${progName}_Error.data|grep -E 'ORA|ora|Preparation_Error_Check Process RETURN_CODE = 9999'|wc -l`
			if [[ $checkcode -ge 1 ]]; then
				echo "-----<<<<<-----Step 888. Run MV Preparation Error Check Process (End...Failed)" | tee -a $LogFile
				AutoWatch 1
			fi
		else
			echo "MV Acct Count: ${ACCT}" | tee -a ${LogFile}
		fi
	echo "----->>>>>-----Step 888. Run MV Preparation Error Check Process (End...)" | tee -a $LogFile
fi
	
AutoWatch 0
