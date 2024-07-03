#!/usr/bin/ksh
########################################################################################
# Program name : HGB_Insert_Multiple_Account.sh
# Path : /extsoft/UBL/BL/Surrounding/Insert_Multiple_Account/bin
#
# Date : 2018/09/28 Created by Mike Kuan
# Description : HGB Insert Multiple Account
########################################################################################
# Date : 
# Description : 
########################################################################################
# Date : 2018/11/26 Modify by Mike Kuan
# Description : add MPC
########################################################################################

#---------------------------------------------------------------------------------------#
#      env
#---------------------------------------------------------------------------------------#
progName="HGB_Insert_Multiple_Account"
sysdt=`date +%Y%m%d%H%M%S`
BillDate=$1
HomeDir=/extsoft/UBL/BL
WorkDir=$HomeDir/Surrounding/Insert_Multiple_Account/bin
LogDir=$HomeDir/Surrounding/Insert_Multiple_Account/log
LogFile=$LogDir/${progName}_${sysdt}.log
AutoWatchDir=$LogDir/joblog
AutoWatchFile=$AutoWatchDir/${BillDate}_HGB_Insert_Multiple_Account.log
MailList=$HomeDir/MailList.txt
#DB info (TEST06) (PT)
#--DB="HGBBLDEV"
#DB info (TEST15) (SIT)
#--DB="HGBBLSIT"
#DB info (TEST02) (UAT)
#--DB="HGBBLUAT"
#DB info (PROD)
DB="HGBBL"

DBID=`/cb/CRYPT/GetId.sh $DB`
DBPWD=`/cb/CRYPT/GetPw.sh $DB`

#---------------------------------------------------------------------------------------#
#      function
#---------------------------------------------------------------------------------------#
function Pause #讀秒
{
for i in `seq 1 1 3`;
do
echo "$i" | tee -a $LogFile
sleep 1
done
}

function HGB_Insert_Multiple_Account
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_Insert_Multiple_Account.sql $1
exit
EOF`
Pause
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
   echo "Send Mail (Failed)" | tee -a $LogFile
   sendMail 0
elif [[ $checksum -eq 0 ]]; then
   echo '' | tee -a $LogFile
   echo "Send AutoWatch (Successed)" | tee -a $LogFile
   echo "${progName},Normal,${AutoWatchDate}" >> $AutoWatchFile
   echo '' | tee -a $LogFile
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

echo '' | tee -a $LogFile
sysdt_END=`date '+%Y/%m/%d-%H:%M:%S'`
echo "${sysdt_END} ------------------------------END ${progName}------------------------------" | tee -a $LogFile
echo '' | tee -a $LogFile

if [[ $type -eq 1 ]]; then
mailx -r "HGB" -s "HGB_Insert_Multiple_Account $BillDate Normal" -a ${LogFile} ${maillist} << EOF
Dears,
   HGB_Insert_Multiple_Account $BillDate Successed.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
else
mailx -r "HGB" -s "HGB_Insert_Multiple_Account $BillDate Abnormal" -a ${LogFile} ${maillist}  << EOF
Dears,
   HGB_Insert_Multiple_Account $BillDate Failed, Please check!!!
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
fi
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
usage()
{
	echo "Usage:"
	echo " $0 <BillDate>"
	echo ""
    echo "For example: $0 20181201"
	echo ""
}

if [[ $# -lt 1 ]]; then
  usage
  exit 0
fi

sysdt_BEGIN=`date '+%Y/%m/%d-%H:%M:%S'`
echo '' | tee -a $LogFile
echo "${sysdt_BEGIN} ------------------------------BEGIN ${progName}------------------------------" | tee -a $LogFile
echo "ENV : ${DB}" | tee -a $LogFile
echo '' | tee -a $LogFile
cd ${WorkDir}

#----------------------------------------------------------------------------------------------------
#------------執行Insert_Multiple_Account
	echo "----------Step 1. Run Insert_Multiple_Account Process (Start...)" | tee -a $LogFile
	HGB_Insert_Multiple_Account $1
	checkcode=`cat ${LogFile}|grep 'Insert_Multiple_Account Process RETURN_CODE = 9999'|wc -l`
		if [[ $checkcode -eq 1 ]]; then
			echo "----------Step 1. Run Insert_Multiple_Account Process (End...Failed)" | tee -a $LogFile
			AutoWatch 1
		else
			echo "----------Step 1. Run Insert_Multiple_Account Process (End... Successed)" | tee -a $LogFile
		fi	
echo '' | tee -a $LogFile

AutoWatch 0
