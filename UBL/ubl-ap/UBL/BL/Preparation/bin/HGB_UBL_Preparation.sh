#!/usr/bin/ksh
########################################################################################
# Program name : HGB_UBL_Preparation.sh
# Path : /extsoft/UBL/BL/Preparation/bin
#
# Date : 2018/09/17 Created by Mike Kuan
# Description : HGB UBL Preparation
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
progName="HGB_UBL_Preparation"
sysdt=`date +%Y%m%d%H%M%S`
BillDate=$1
ProcType=$2
ProcessNo=$3
Cycle=$4
HomeDir=/extsoft/UBL/BL
WorkDir=$HomeDir/Preparation/bin
LogDir=$HomeDir/Preparation/log
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

function HGB_UBL_Preparation_STEP_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STEP.data <<EOF
@HGB_UBL_Preparation_STEP_Check.sql $1 $2 $3 $4
EOF`
cat ${LogDir}/${progName}_STEP.data |read STEP
echo "Step or Message: ${STEP}" | tee -a ${LogFile}
}

function HGB_UBL_Preparation_STATUS_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_STATUS.data <<EOF
@HGB_UBL_Preparation_STATUS_Check.sql $1 $2 $3 $4
EOF`
cat ${LogDir}/${progName}_STATUS.data | tee -a ${LogFile}
}

function HGB_UBL_Preparation_CI
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_UBL_Preparation.sql $1 $2 $3 CI $4
exit
EOF`
}

function HGB_UBL_Preparation_BI
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_UBL_Preparation.sql $1 $2 $3 BI $4
exit
EOF`
}

function HGB_UBL_Preparation_AR_Check
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}_AR.data <<EOF
@HGB_UBL_Preparation_AR_Check.sql $1 $2 $3 $4
EOF`
cat ${LogDir}/${progName}_AR.data |read STEP
}

function HGB_UBL_Preparation_MAST
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_UBL_Preparation.sql $1 $2 $3 MAST $4
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
#------------執行Preparation Step Check
echo "----->>>>>-----Step 0. Run Preparation Step Check Process (Start...)" | tee -a $LogFile
HGB_UBL_Preparation_STEP_Check $BillDate $Cycle $ProcessNo $ProcType
checkcode=`cat ${LogDir}/${progName}_STEP.data|grep -E 'ORA|ora|Preparation_STEP_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 0. Run Preparation Step Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 0. Run Preparation Step Check Process (End... Successed)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行Preparation Status Check
echo "----->>>>>-----Step 1. Run Preparation Status Check Process (Start...)" | tee -a $LogFile
HGB_UBL_Preparation_STATUS_Check $BillDate $Cycle $ProcessNo $ProcType
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Preparation_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 1. Run Preparation Status Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 1. Run Preparation Status Check Process (End... Successed)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
if [[ ${STEP} == 'CI' ]]; then
#------------執行Preparation_CI, Preparation_BI, Preparation_MAST
	echo "----->>>>>-----Step 2. Run Preparation_CI Process (Start...)" | tee -a $LogFile
	HGB_UBL_Preparation_CI $BillDate $Cycle $ProcessNo $ProcType
	checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_CI Process RETURN_CODE = 9999'|wc -l`
		if [[ $checkcode -ge 1 ]]; then
			echo "-----<<<<<-----Step 2. Run Preparation_CI Process (End...Failed)" | tee -a $LogFile
			AutoWatch 1
		else
			echo "-----<<<<<-----Step 2. Run Preparation_CI Process (End... Successed)" | tee -a $LogFile
			Pause
			echo "----->>>>>-----Step 3. Run Preparation_BI Process (Start...)" | tee -a $LogFile
			HGB_UBL_Preparation_BI $BillDate $Cycle $ProcessNo $ProcType
			checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_BI Process RETURN_CODE = 9999'|wc -l`
				if [[ $checkcode -ge 1 ]]; then
					echo "-----<<<<<-----Step 3. Run Preparation_BI Process (End...Failed)" | tee -a $LogFile
					AutoWatch 1
				else
					echo "-----<<<<<-----Step 3. Run Preparation_BI Process (End... Successed)" | tee -a $LogFile
					Pause
					run_cnt=0
					checkdone=0
					checkerror=0
					checkwait=0
						while [ $checkdone -eq 0 ] 
						do
							echo "----->>>>>-----Step 4. Run Preparation AR Check Process (Start...)" | tee -a $LogFile
							sleep 60
							HGB_UBL_Preparation_AR_Check $BillDate $Cycle $ProcessNo $ProcType
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
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Successed)" | tee -a $LogFile
									Pause
								fi
						done
					echo "----->>>>>-----Step 5. Run Preparation_MAST Process (Start...)" | tee -a $LogFile
					HGB_UBL_Preparation_MAST $BillDate $Cycle $ProcessNo $ProcType
					checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_MAST Process RETURN_CODE = 9999'|wc -l`
						if [[ $checkcode -ge 1 ]]; then
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Failed)" | tee -a $LogFile
							AutoWatch 1
						else
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Successed)" | tee -a $LogFile
						fi
				fi
		fi
#----------------------------------------------------------------------------------------------------
elif [[ ${STEP} == 'BI' ]]; then
#------------執行Preparation_BI, Preparation_MAST
			echo "--------------------Before Step... 2. Run Preparation_CI Process (End... Successed)--------------------" | tee -a $LogFile
			Pause
			echo "----->>>>>-----Step 3. Run Preparation_BI Process (Start...)" | tee -a $LogFile
			HGB_UBL_Preparation_BI $BillDate $Cycle $ProcessNo $ProcType
			checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_BI Process RETURN_CODE = 9999'|wc -l`
				if [[ $checkcode -ge 1 ]]; then
					echo "-----<<<<<-----Step 3. Run Preparation_BI Process (End...Failed)" | tee -a $LogFile
					AutoWatch 1
				else
					echo "-----<<<<<-----Step 3. Run Preparation_BI Process (End... Successed)" | tee -a $LogFile
					Pause
					run_cnt=0
					checkdone=0
					checkerror=0
					checkwait=0
						while [ $checkdone -eq 0 ] 
						do
							echo "----->>>>>-----Step 4. Run Preparation AR Check Process (Start...)" | tee -a $LogFile
							sleep 60
							HGB_UBL_Preparation_AR_Check $BillDate $Cycle $ProcessNo $ProcType
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
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Successed)" | tee -a $LogFile
									Pause
								fi
						done
					echo "----->>>>>-----Step 5. Run Preparation_MAST Process (Start...)" | tee -a $LogFile
					HGB_UBL_Preparation_MAST $BillDate $Cycle $ProcessNo $ProcType
					checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_MAST Process RETURN_CODE = 9999'|wc -l`
						if [[ $checkcode -ge 1 ]]; then
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Failed)" | tee -a $LogFile
							AutoWatch 1
						else
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Successed)" | tee -a $LogFile
						fi
				fi
#----------------------------------------------------------------------------------------------------
elif [[ ${STEP} == 'MAST' ]]; then
#------------執行Preparation_MAST
					echo "--------------------Before Step... 2. Run Preparation_CI Process (End... Successed)--------------------" | tee -a $LogFile
					echo "--------------------Before Step... 3. Run Preparation_BI Process (End... Successed)--------------------" | tee -a $LogFile
					Pause
					run_cnt=0
					checkdone=0
					checkerror=0
					checkwait=0
						while [ $checkdone -eq 0 ] 
						do
							echo "----->>>>>-----Step 4. Run Preparation AR Check Process (Start...)" | tee -a $LogFile
							sleep 60
							HGB_UBL_Preparation_AR_Check $BillDate $Cycle $ProcessNo $ProcType
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
									echo "-----<<<<<-----Step 4. Run Preparation AR Check Process (End... Successed)" | tee -a $LogFile
									Pause
								fi
						done
					echo "----->>>>>-----Step 5. Run Preparation_MAST Process (Start...)" | tee -a $LogFile
					HGB_UBL_Preparation_MAST $BillDate $Cycle $ProcessNo $ProcType
					checkcode=`cat ${LogFile}|grep -E 'ORA|ora|Preparation_MAST Process RETURN_CODE = 9999'|wc -l`
						if [[ $checkcode -ge 1 ]]; then
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Failed)" | tee -a $LogFile
							AutoWatch 1
						else
							echo "-----<<<<<-----Step 5. Run Preparation_MAST Process (End...Successed)" | tee -a $LogFile
						fi
else
	echo "Preparation Status not in ('CI','BI','MAST')" | tee -a $LogFile
fi		
Pause

#----------------------------------------------------------------------------------------------------
#------------執行Preparation Status Check
echo "----->>>>>-----Step 6. Run Preparation Status Check Process (Start...)" | tee -a $LogFile
HGB_UBL_Preparation_STATUS_Check $BillDate $Cycle $ProcessNo $ProcType
checkcode=`cat ${LogDir}/${progName}_STATUS.data|grep -E 'ORA|ora|Preparation_STATUS_Check Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -ge 1 ]]; then
  echo "-----<<<<<-----Step 6. Run Preparation Status Check Process (End...Failed)" | tee -a $LogFile
  AutoWatch 1
fi
echo "-----<<<<<-----Step 6. Run Preparation Status Check Process (End... Successed)" | tee -a $LogFile

AutoWatch 0
