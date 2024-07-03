#!/usr/bin/ksh
########################################################################################
# Program name : HGB_BMEX_RETN_file_loader.sh
# Path : /extsoft/UBL/BL/Surrounding/BMEX_RETN
#
# Date : 2021/06/11 Created by Mike Kuan
# Description : SR228930_紙本帳單整合交寄功能HGB&HGBN
#               SR228931_紙本帳單攔回 HGB及HGBN
########################################################################################
# Date : 2023/01/10 Created by Mike Kuan
# Description : CR23015954_cabsftp 帳號密碼變更
########################################################################################

#---------------------------------------------------------------------------------------#
#      env
#---------------------------------------------------------------------------------------#
BillDate=`date +%Y%m%d`
home="/extsoft/UBL/BL/Surrounding/BMEX_RETN"
dataFolder="${home}/data"
bakFolder="${dataFolder}/bak"
dataFile="${dataFolder}/HGB_BMEX_RETN_$BillDate.txt"
dataFile_HGB_BMEX="${dataFolder}/HGB_BMEX_list.txt"
dataFile_HGBN_BMEX="${dataFolder}/HGBN_BMEX_list.txt"
dataFile_HGB_RETN="${dataFolder}/HGB_RETN_list.txt"
dataFile_HGBN_RETN="${dataFolder}/HGBN_RETN_list.txt"
LogDir="${home}/log"
LogFile="${LogDir}/HGB_BMEX_RETN_$BillDate.log"
MailList=/extsoft/UBL/BL/MailList.txt
progName=$(basename $0 .sh)
echo "Program Name is:${progName}"

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
OCSID=fareastone/cabsftp
OCSPWD=CabsQAws!!22

#---------------------------------------------------------------------------------------#
#      FTP
#---------------------------------------------------------------------------------------# 
utilDir="/cb/BCM/util"
ftpPROG="${utilDir}/Ftp2Remote.sh"
ftpIP='10.64.16.102'
ftpUSER=$OCSID
ftpPWD=$OCSPWD
ftpPATH=/FTPService/Unmask_MSISDN
ftpFILE_HGB_BMEX=HGB_BMEX_list.txt
ftpFILE_HGBN_BMEX=HGBN_BMEX_list.txt
ftpFILE_HGB_RETN=HGB_RETN_list.txt
ftpFILE_HGBN_RETN=HGBN_RETN_list.txt

#---------------------------------------------------------------------------------------#
#      function
#---------------------------------------------------------------------------------------#
function Pause #讀秒
{
for i in `seq 1 1 5`;
do
echo "." | tee -a ${LogFile}
sleep 1
done
}

function getFile
{
getFileDate=`date '+%Y/%m/%d-%H:%M:%S'`
   echo '' | tee -a ${LogFile}
   echo "getting BMEX & RETN files..." | tee -a ${LogFile}
   echo '' | tee -a ${LogFile}
   if [[ ${hostname} = "idc-hgbap01p" ]]; then
		echo "FTP Command: ${ftpPROG} ${ftpIP} ${ftpUSER} ******** ${dataFolder} ${ftpPATH} ${ftpFILE_HGB_BMEX} 1" | tee -a ${logFile}
		${ftpPROG} ${ftpIP} ${ftpUSER} ${ftpPWD} ${dataFolder} ${ftpPATH} ${ftpFILE_HGB_BMEX} 1
		echo "FTP Command: ${ftpPROG} ${ftpIP} ${ftpUSER} ******** ${dataFolder} ${ftpPATH} ${ftpFILE_HGBN_BMEX} 1" | tee -a ${logFile}
		${ftpPROG} ${ftpIP} ${ftpUSER} ${ftpPWD} ${dataFolder} ${ftpPATH} ${ftpFILE_HGBN_BMEX} 1
		echo "FTP Command: ${ftpPROG} ${ftpIP} ${ftpUSER} ******** ${dataFolder} ${ftpPATH} ${ftpFILE_HGB_RETN} 1" | tee -a ${logFile}
		${ftpPROG} ${ftpIP} ${ftpUSER} ${ftpPWD} ${dataFolder} ${ftpPATH} ${ftpFILE_HGB_RETN} 1		
		echo "FTP Command: ${ftpPROG} ${ftpIP} ${ftpUSER} ******** ${dataFolder} ${ftpPATH} ${ftpFILE_HGBN_RETN} 1" | tee -a ${logFile}
		${ftpPROG} ${ftpIP} ${ftpUSER} ${ftpPWD} ${dataFolder} ${ftpPATH} ${ftpFILE_HGBN_RETN} 1
	else
		echo "host=${hostname}" | tee -a ${logFile}
   fi
}

function truncateDB
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${LogFile} <<EOF
@${home}/truncate_BMEX_RETN.sql
exit
EOF`
}

function insertDB
{
file=$1
echo "Call insertDB"
NLS_LANG="TRADITIONAL CHINESE_TAIWAN.AL32UTF8"
export NLS_LANG
`sqlplus -s ${DBID}/${DBPWD}@${DB}<<EOF
set tab off
SET ECHO OFF
set termout off
SET PAGESIZE 32766
SET LINESIZE 32766
SET FEEDBACK OFF
-- set NULL 'NO ROWS SELECTED'
set linesize 1024
SET TRIMSPOOL ON

@${home}/data/HGB_BMEX_RETN_$BillDate.sql

exit;
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
mailx -r "HGB_UBL" -s "${progName} Date:${BillDate} Normal" -a ${LogFile} ${maillist} << EOF
Dears,
   ${progName} Date:${BillDate} Successed.
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
sysdt_END=`date '+%Y/%m/%d-%H:%M:%S'`
echo "${sysdt_END} ------------------------------END ${progName}------------------------------" | tee -a ${LogFile}
else
mailx -r "HGB_UBL" -s "${progName} Date:${BillDate} Abnormal" -a ${LogFile} ${maillist}  << EOF
Dears,
   ${progName} Date:${BillDate} Failed, Please check!!!
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
EOF
sysdt_END=`date '+%Y/%m/%d-%H:%M:%S'`
echo "${sysdt_END} ------------------------------END ${progName}------------------------------" | tee -a ${LogFile}
exit 0;
fi
}

########################################################################################
# Main
########################################################################################

cd ${home}
startDate=`date +%Y%m%d_%H%M%S`
echo $startDate > ${LogFile}

## get files as FTP
echo "get files as FTP" | tee -a ${LogFile}
getFile
Pause

## check file exists
[ -f $dataFile_HGB_BMEX -a -f $dataFile_HGBN_BMEX -a -f $dataFile_HGB_RETN -a -f $dataFile_HGBN_RETN ] && echo "all files exists" | tee -a ${LogFile} || sendMail 0
Pause

## truncate table HGB_BMEX, HGBN_BMEX, HGB_RETN, HGBN_RETN
[ -f truncate_BMEX_RETN.sql ] && echo "truncate SQL file exists" | tee -a ${LogFile} || sendMail 0
truncateDB
Pause

## preparing HGB_BMEX insert data into sql file
IFS="," #改變DATA FILE分隔符號從預設空白改為逗號
cat ${dataFile_HGB_BMEX}|while read NAME ACCT_ID EFF_DATE
do
echo "INSERT INTO fet_tb_bl_bmex_list VALUE
   (SELECT '${NAME}' "NAME", ${ACCT_ID} "ACCT_ID", 50 "CYCLE",
           TO_DATE (${EFF_DATE}, 'yyyymmdd') "EFF_DATE", SYSDATE create_date,
           'UBL' create_user, SYSDATE update_date, 'UBL' update_user
      FROM DUAL);" >> ${home}/data/HGB_BMEX_RETN_$BillDate.sql
#echo "IID[${PRIM_RESOURCE_VAL}] COUNT[${COUNT}]" | tee -a ${logFile}
done < $dataFile_HGB_BMEX
Pause

## preparing HGBN_BMEX insert data into sql file
cat ${dataFile_HGBN_BMEX}|while read NAME ACCT_ID EFF_DATE
do
echo "INSERT INTO fet_tb_bl_bmex_list VALUE
   (SELECT '${NAME}' "NAME", ${ACCT_ID} "ACCT_ID", 10 "CYCLE",
           TO_DATE (${EFF_DATE}, 'yyyymmdd') "EFF_DATE", SYSDATE create_date,
           'UBL' create_user, SYSDATE update_date, 'UBL' update_user
      FROM DUAL);" >> ${home}/data/HGB_BMEX_RETN_$BillDate.sql
#echo "IID[${PRIM_RESOURCE_VAL}] COUNT[${COUNT}]" | tee -a ${logFile}
done < $dataFile_HGBN_BMEX
Pause

## preparing HGB_RETN insert data into sql file
cat ${dataFile_HGB_RETN}|while read ACCT_ID SYS_IND CYCLE PRINT_IND
do
echo "INSERT INTO fet_tb_bl_retn_list VALUE
   (SELECT ${ACCT_ID} "ACCT_ID", 50 "CYCLE", '${SYS_IND}' "SYS_IND", '${PRINT_IND}' "PRINT_IND", 
           SYSDATE create_date,
           'UBL' create_user, SYSDATE update_date, 'UBL' update_user
      FROM DUAL);" >> ${home}/data/HGB_BMEX_RETN_$BillDate.sql
done < $dataFile_HGB_RETN
Pause

## preparing HGBN_RETN insert data into sql file
cat ${dataFile_HGBN_RETN}|while read ACCT_ID SYS_IND CYCLE PRINT_IND
do
echo "INSERT INTO fet_tb_bl_retn_list VALUE
   (SELECT ${ACCT_ID} "ACCT_ID", 10 "CYCLE", '${SYS_IND}' "SYS_IND", '${PRINT_IND}' "PRINT_IND", 
           SYSDATE create_date,
           'UBL' create_user, SYSDATE update_date, 'UBL' update_user
      FROM DUAL);" >> ${home}/data/HGB_BMEX_RETN_$BillDate.sql
done < $dataFile_HGBN_RETN
Pause

## insert data to db
echo "Connect to ${DBID}@${DB}" | tee -a ${LogFile}
insertDB
Pause

echo "Move file to bak" | tee -a ${LogFile}
mv ${dataFolder}/*$BillDate* ${dataFolder}/bak
mv ${dataFile_HGB_BMEX} ${dataFolder}/bak/${ftpFILE_HGB_BMEX}_$BillDate
mv ${dataFile_HGBN_BMEX} ${dataFolder}/bak/${ftpFILE_HGBN_BMEX}_$BillDate
mv ${dataFile_HGB_RETN} ${dataFolder}/bak/${ftpFILE_HGB_RETN}_$BillDate
mv ${dataFile_HGBN_RETN} ${dataFolder}/bak/${ftpFILE_HGBN_RETN}_$BillDate

endDate=`date +%Y%m%d_%H%M%S`
echo $endDate | tee -a ${LogFile}

sendMail 1
