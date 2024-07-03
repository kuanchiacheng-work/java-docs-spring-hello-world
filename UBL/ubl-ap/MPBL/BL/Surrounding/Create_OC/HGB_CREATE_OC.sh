#!/usr/bin/ksh
########################################################################################
# Program name : HGB_CREATE_OC.sh
# Path : /extsoft/MPBL/BL/Preparation/bin
#
# Date : 2020/07/08 Created by Mike Kuan
# Description : HGB CREATE OC by File
########################################################################################

#---------------------------------------------------------------------------------------#
#      env
#---------------------------------------------------------------------------------------#
home="/extsoft/MPBL/BL/Surrounding/Create_OC"
sourceFileFolder="${home}/sourceFile"
sourceFile="${sourceFileFolder}/HGB_CREATE_OC.txt"
logFolder="${home}/log"
log="${logFolder}/HGB_CREATE_OC_`date +%Y%m%d%H%M%S`.log"
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

function HGB_CREATE_OC
{
`sqlplus -s ${DBID}/${DBPWD}@${DB} >> ${logFolder}/${progName}.data <<EOF
@HGB_CREATE_OC.sql $1 $2 $3 $4 $5 $6 MPBL_ML
exit
EOF`
}

####################################################
# Main
####################################################
sysdt_BEGIN=`date '+%Y/%m/%d-%H:%M:%S'`
echo '' | tee -a $LogFile
echo "${sysdt_BEGIN} ------------------------------BEGIN ${progName}------------------------------" | tee -a $LogFile
echo "HGB_DB_ENV : ${DB}" | tee -a $LogFile
echo "DBID : ${DBID}" | tee -a $LogFile
echo "DBPWD : ${DBPWD}" | tee -a $LogFile
echo "OCS_AP_ENV : ${OCS_AP}" | tee -a $LogFile
echo '' | tee -a $LogFile
cd ${home}
Pause

startDate=`date +%Y/%m/%d_%H:%M:%S`
echo "START: "$startDate | tee -a ${log}

#Check sourceFile exists
echo sourceFile exists | tee -a ${log}
echo '' | tee -a $LogFile
[ -f $sourceFile ] && echo "sourceFile exists" || exit 1
Pause

#read sourceFile to insert DB
echo "read sourceFile to insert DB" | tee -a ${log}
echo '' | tee -a $LogFile
cat ${sourceFile}|while read TYPE TYPE_ID BILL_PERIOD CHARGE_CODE AMOUNT DYNAMIC_ATTRIBUTE
do
echo ${TYPE} ${TYPE_ID} ${BILL_PERIOD} ${CHARGE_CODE} ${AMOUNT} ${DYNAMIC_ATTRIBUTE} | tee -a ${log}
HGB_CREATE_OC $TYPE $TYPE_ID $BILL_PERIOD $CHARGE_CODE $AMOUNT $DYNAMIC_ATTRIBUTE
done
Pause

#backup sourceFile to bak folder
echo "backup sourceFile to bak folder" | tee -a ${log}
echo '' | tee -a $LogFile
mv ${sourceFile} ${sourceFileFolder}/bak/HGB_CREATE_OC_`date +%Y%m%d%H%M%S`.txt
Pause

endDate=`date +%Y/%m/%d_%H:%M:%S`
echo "END: "$endDate | tee -a ${log}

