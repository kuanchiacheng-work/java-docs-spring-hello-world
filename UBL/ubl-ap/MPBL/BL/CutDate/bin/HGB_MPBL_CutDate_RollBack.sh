#!/usr/bin/ksh
########################################################################################
# Program name : HGB_MPBL_CutDate_RollBack.sh
# Path : /extsoft/MPBL/BL/CutDate/bin
#
# Date : 2020/04/23 Created by Mike Kuan
# Description : SR222460_MPBS migrate to HGB only for test env
########################################################################################

#---------------------------------------------------------------------------------------#
#      env
#---------------------------------------------------------------------------------------#
progName="HGB_MPBL_CutDate_RollBack"
sysdt=`date +%Y%m%d%H%M%S`
BillSeq=$1
HomeDir=/extsoft/MPBL/BL
WorkDir=$HomeDir/CutDate/bin
LogDir=$HomeDir/CutDate/log
LogFile=$LogDir/${progName}_${sysdt}.log
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
#"pet-hgbap01p","pet-hgbap02p","idc-hgbap01p","idc-hgbap02p") #(PET) (PROD)
#DB="HGBBL"
#OCS_AP="prdbl2"
#;;
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

function HGB_MPBL_CutDate_RollBack_getCycleInfo
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${LogDir}/${progName}.data <<EOF
@HGB_MPBL_CutDate_RollBack_getCycleInfo.sql $1
EOF`
cat ${LogDir}/${progName}.data |read BillDate CYCLE
echo "BILL_DATE[${BillDate}] CycleCode[${CYCLE}]" | tee -a ${LogFile}
}

function HGB_MPBL_CutDate_AR
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_MPBL_CutDate_AR.sql $1 $2
exit
EOF`
}

function HGB_MPBL_CutDate_RollBack
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@HGB_MPBL_CutDate_RollBack.sql $1
exit
EOF`
}

function sendMail
{
type=$1
cd ${LogDir}
iconv -f utf8 -t big5 -c ${LogFile} > ${LogFile}.big5
mv ${LogFile}.big5 ${LogFile}
maillist=`cat $MailList`

if [[ $type -eq 1 ]]; then
mailx -r "HGB_MPBL" -s "${progName} BILL_SEQ:${BillSeq} Normal" -a ${LogFile} ${maillist} << EOF
Dears,
   ${progName} BILL_SEQ:${BillSeq} Successed.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
else
mailx -r "HGB_MPBL" -s "${progName} BILL_SEQ:${BillSeq} Abnormal" -a ${LogFile} ${maillist}  << EOF
Dears,
   ${progName} CYCLE:${Cycle} BILL_SEQ:${BillSeq} Failed, Please check!!!
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
fi

exit 0;
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
usage()
{
	echo "Usage:"
	echo " $0 <BILL_SEQ> "
	echo ""
	echo "For example: $0 150001"
	echo ""
}

if [[ $# -lt 1 ]]; then
  usage
  exit 0
fi

sysdt_BEGIN=`date '+%Y/%m/%d-%H:%M:%S'`
echo '' | tee -a $LogFile
echo "${sysdt_BEGIN} ------------------------------BEGIN ${progName}------------------------------" | tee -a $LogFile
echo "HGB_DB_ENV : ${DB}" | tee -a $LogFile
echo "OCS_AP_ENV : ${OCS_AP}" | tee -a $LogFile
echo "BILL_SEQ : ${BillSeq}" | tee -a $LogFile
echo '' | tee -a $LogFile
cd ${WorkDir}
Pause
#----------------------------------------------------------------------------------------------------
#------------取得Cycle資訊
echo "----->>>>>-----Step 1. Get Cycle Information (Start...)" | tee -a $LogFile
HGB_MPBL_CutDate_RollBack_getCycleInfo $BillSeq
if [[ ${CYCLE} -lt 50 || ${CYCLE} -gt 60 ]]; then
  echo "-----<<<<<-----Step 1. Get Cycle Information (End... Failed)" | tee -a $LogFile
  sendMail 0
fi
echo "-----<<<<<-----Step 1. Get Cycle Information (End... Successed)" | tee -a $LogFile
Pause
#----------------------------------------------------------------------------------------------------
#------------執行AR_CutDate
echo "----->>>>>-----Step 0. Run AR_CutDate Process (Start...)" | tee -a $LogFile
HGB_MPBL_CutDate_AR $BillDate $CYCLE
checkcode=`cat ${LogFile}|grep 'Create_AR_Table Process RETURN_CODE = 9999'|wc -l`
if [[ $checkcode -eq 1 ]]; then
  echo "-----<<<<<-----Step 0. Run AR_CutDate Process (End...Failed)" | tee -a $LogFile
  sendMail 0
fi
echo "-----<<<<<-----Step 0. Run AR_CutDate Process (End...Successed)" | tee -a $LogFile
Pause
#------------執行CutDate RollBack
echo "----->>>>>-----Step 1. Run CutDate RollBack Process (Start...)" | tee -a $LogFile
HGB_MPBL_CutDate_RollBack $BillSeq
checkcode=`cat ${LogFile}|grep 'CutDate RollBack Process RETURN_CODE = 0000'|wc -l`
if [[ $checkcode -eq 0 ]]; then
  echo "-----<<<<<-----Step 1. Run CutDate RollBack Process (End...Failed)" | tee -a $LogFile
  sendMail 0
fi
echo "-----<<<<<-----Step 1. Run CutDate RollBack Process (End...Successed)" | tee -a $LogFile

sendMail 1
