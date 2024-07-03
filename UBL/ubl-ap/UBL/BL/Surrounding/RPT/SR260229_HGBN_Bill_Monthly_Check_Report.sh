#!/usr/bin/env bash
########################################################################################
# Program name : SR266082_HGBN_UBL_ICT_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2024/03/05 Create by Mike Kuan
# Description : SR266082_P266082 專案結束額度結餘報表、P266082-1 當月扣抵額度之ICT折扣動支明細表
########################################################################################

export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
progName=$(basename $0 .sh)
sysdt=`date +%Y%m%d%H%M%S`
sysd=`date +%Y%m --date="-1 month"`
#sysd=202303
HomeDir=/extsoft/UBL/BL
WorkDir=$HomeDir/Surrounding/RPT
ReportDir=$WorkDir/report
ReportDirBak=$ReportDir/bak
LogDir=$WorkDir/log
logFile=$LogDir/${progName}_${sysdt}.log
tempFile=$LogDir/${progName}_tmp_${sysdt}.log
reportFileName="P266082_ICT_Project_balance_of_own_service_`date +%Y%m%d`_HGBN"
reportFileName2="P266082-1_Own_service_changes_in_ICT_Project_`date +%Y%m%d`_HGBN"
utilDir=/cb/BCM/util
ftpProg=${utilDir}/Ftp2Remote.sh
#mailList="keroh@fareastone.com.tw mikekuan@fareastone.com.tw"
mailList="mikekuan@fareastone.com.tw"

#---------------------------------------------------------------------------------------#
#      MPC info
#---------------------------------------------------------------------------------------#
hostname=`hostname`
case ${hostname} in
"pc-hgbap01t") #(TEST06) (PT)
DB="HGBDEV2"
RPTDB="HGBDEV2"
OCS_AP="fetwrk26"
;;
"hgbdev01t") #(TEST06) (PT)
DB="HGBDEV3"
RPTDB="HGBDEV3"
OCS_AP="fetwrk26"
;;
"pc-hgbap11t") #(TEST15) (SIT)
DB="HGBBLSIT"
RPTDB="HGBBLSIT"
OCS_AP="fetwrk15"
putip1=10.64.16.58
#putpass1=unix11
;;
"pc-hgbap21t") #(TEST02) (UAT)
DB="HGBBLUAT"
RPTDB="HGBBLUAT"
OCS_AP="fetwrk21"
putip1=10.64.18.122
#putpass1=unix11
;;
"pet-hgbap01p"|"pet-hgbap02p") #(PET)
DB="HGBBL"
RPTDB="HGBBLRPT"
OCS_AP="prdbl2"
putip1=10.64.18.123
#putpass1=unix11
;;
"idc-hgbap01p"|"idc-hgbap02p") #(PROD)
DB="HGBBL"
RPTDB="HGBBLRPT"
OCS_AP="prdbl2"
putip1=10.64.16.102
#putpass1=`/cb/CRYPT/GetPw.sh UBL_UAR_FTP`
;;
*)
echo "Unknown AP Server"
exit 0
esac
DBID=`/cb/CRYPT/GetId.sh $DB`
DBPWD=`/cb/CRYPT/GetPw.sh $DB`
#FTP
putuser1=fareastone/cabsftp
putpass1=CabsQAws!!22
putpath1=/FTPService/Accounting/P266082

#---------------------------------------------------------------------------------------#
#      function
#---------------------------------------------------------------------------------------#
function genReport
{
echo "Gen Report Start"|tee -a ${logFile}
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${logFile} <<EOF
set colsep ','
set echo off
set feedback off
set linesize 9999
set pagesize 50000
set sqlprompt ''
set trimspool on
set trimout on
set headsep off
set heading off

spool P266082.dat

select '系統別'||','||'Proposal ID'||','||'客戶名稱'||','||'Account ID'||','||'Service Type訖日'||','||'總信用額度'||','||'已使用信用額度'||','||'剩餘額度' from dual;

--/* Formatted on 2024/03/05 15:07 (Formatter Plus v4.8.8) */
--SELECT DECODE (d.CYCLE, 10, 'HGBN', 15, 'HGBN', 20, 'HGBN') "系統別",
--       va.proposal_id "Proposal ID", f.elem2 "客戶名稱", a.acct_id "Account ID",
--       DECODE (a.cur_bal_qty,
--               0, NVL (TO_CHAR (a.end_date, 'YYYY/MM/DD'),
--                       TO_CHAR (a.update_date, 'YYYY/MM/DD')
--                      ),
--               TO_CHAR (a.end_date, 'YYYY/MM/DD')
--              ) "Service Type訖日",
--       DECODE (init_pkg_qty,
--               0, (SELECT param_value
--                     FROM fy_tb_bl_offer_param
--                    WHERE param_name = 'BD_QUOTA_0001'
--                      AND acct_id = a.acct_id
--                      AND offer_instance_id = a.offer_instance_id),
--               init_pkg_qty
--              ) "總信用額度",
--       NVL (a.total_disc_amt, 0) "已使用信用額度",
--       NVL (a.cur_bal_qty,
--              DECODE (init_pkg_qty,
--                      0, (SELECT param_value
--                            FROM fy_tb_bl_offer_param
--                           WHERE param_name = 'BD_QUOTA_0001'
--                             AND acct_id = a.acct_id
--                             AND offer_instance_id = a.offer_instance_id),
--                      init_pkg_qty
--                     )
--            - NVL (a.total_disc_amt, 0)
--           ) "剩餘額度"
--  FROM fy_tb_bl_acct_pkg a,
--       fy_tb_cm_subscr b,
--       fy_tb_pbk_offer c,
--       fy_tb_cm_customer d,
--       (SELECT *
--          FROM fy_tb_cm_prof_link
--         WHERE link_type = 'A' AND prof_type = 'NAME') f,
--       (SELECT   CYCLE, MAX (bill_from_date) bill_from_date
--            FROM fy_tb_bl_bill_cntrl
--           WHERE CYCLE IN (10, 15, 20)
--        GROUP BY CYCLE) cntrl,
--       v_account va
-- WHERE a.offer_level = 'S'
--   AND d.CYCLE IN (10, 15, 20)
--   AND a.prepayment IS NOT NULL
--   AND a.offer_level_id = b.subscr_id
--   AND a.offer_id = c.offer_id
--   AND a.cust_id = d.cust_id
--   AND a.acct_id = f.entity_id
--   AND a.acct_id = va.account_id(+)
--   AND d.CYCLE = cntrl.CYCLE
----and (a.end_date >= cntrl.bill_from_date or a.end_date is null)
--;

SELECT    DECODE (d.CYCLE, 10, 'HGBN', 15, 'HGBN', 20, 'HGBN')
       || ','
       || va.proposal_id
       || ','
       || f.elem2
       || ','
       || a.acct_id
       || ','
       || DECODE (a.cur_bal_qty,
                  0, NVL (TO_CHAR (a.end_date, 'YYYY/MM/DD'),
                          TO_CHAR (a.update_date, 'YYYY/MM/DD')
                         ),
                  TO_CHAR (a.end_date, 'YYYY/MM/DD')
                 )
       || ','
       || DECODE (init_pkg_qty,
                  0, (SELECT param_value
                        FROM fy_tb_bl_offer_param
                       WHERE param_name = 'BD_QUOTA_0001'
                         AND acct_id = a.acct_id
                         AND offer_instance_id = a.offer_instance_id),
                  init_pkg_qty
                 )
       || ','
       || NVL (a.total_disc_amt, 0)
       || ','
       || NVL (a.cur_bal_qty,
                 DECODE (init_pkg_qty,
                         0, (SELECT param_value
                               FROM fy_tb_bl_offer_param
                              WHERE param_name = 'BD_QUOTA_0001'
                                AND acct_id = a.acct_id
                                AND offer_instance_id = a.offer_instance_id),
                         init_pkg_qty
                        )
               - NVL (a.total_disc_amt, 0)
              )
  FROM fy_tb_bl_acct_pkg a,
       fy_tb_cm_subscr b,
       fy_tb_pbk_offer c,
       fy_tb_cm_customer d,
       (SELECT *
          FROM fy_tb_cm_prof_link
         WHERE link_type = 'A' AND prof_type = 'NAME') f,
       (SELECT   CYCLE, MAX (bill_from_date) bill_from_date
            FROM fy_tb_bl_bill_cntrl
           WHERE CYCLE IN (10, 15, 20)
        GROUP BY CYCLE) cntrl,
       v_account va
 WHERE a.offer_level = 'S'
   AND d.CYCLE IN (10, 15, 20)
   AND a.prepayment IS NOT NULL
   AND a.offer_level_id = b.subscr_id
   AND a.offer_id = c.offer_id
   AND a.cust_id = d.cust_id
   AND a.acct_id = f.entity_id
   AND a.acct_id = va.account_id(+)
   AND d.CYCLE = cntrl.CYCLE;

spool off

exit;

EOF`

echo "Gen Report End"|tee -a ${logFile}
}

function genReport2
{
echo "Gen Report Start"|tee -a ${logFile}
`sqlplus -s ${DBID}/${DBPWD}@${DB} > ${logFile} <<EOF
set colsep ','
set echo off
set feedback off
set linesize 9999
set pagesize 50000
set sqlprompt ''
set trimspool on
set trimout on
set headsep off
set heading off

spool P266082-1.dat

select '系統別'||','||'Proposal ID'||','||'客戶名稱'||','||'Account ID'||','||'跑帳日'||','||'折抵信用額度' from dual;

--/* Formatted on 2024/03/05 15:17 (Formatter Plus v4.8.8) */
--SELECT DECODE (d.CYCLE, 10, 'HGBN', 15, 'HGBN', 20, 'HGBN') "系統別",
--       va.proposal_id "Proposal ID", f.elem2 "客戶名稱", a.acct_id "Account ID",
--       TO_CHAR (cntrl.bill_date, 'YYYY/MM/DD') "跑帳日",
--       NVL ((SELECT SUM (bb.amount) * -1
--               FROM fy_tb_bl_bill_cntrl aa, fy_tb_bl_bill_ci bb
--              WHERE aa.bill_period =
--                                   TO_CHAR (ADD_MONTHS (SYSDATE, -2),
--                                            'yyyymm')
--                AND aa.bill_seq = bb.bill_seq
--                AND bb.SOURCE = 'DE'
--                AND bb.subscr_id = a.offer_level_id
--                AND bb.offer_id = a.offer_id
--                AND bb.offer_instance_id = a.offer_instance_id),
--            0
--           ) "折抵信用額度"
--  FROM fy_tb_bl_acct_pkg a,
--       fy_tb_cm_subscr b,
--       fy_tb_pbk_offer c,
--       fy_tb_cm_customer d,
--       (SELECT *
--          FROM fy_tb_cm_prof_link
--         WHERE link_type = 'A' AND prof_type = 'NAME') f,
--       (SELECT   CYCLE, ADD_MONTHS (MAX (bill_date), -2) bill_date
--            FROM fy_tb_bl_bill_cntrl
--           WHERE CYCLE IN (10, 15, 20)
--        GROUP BY CYCLE) cntrl,
--       v_account va
-- WHERE a.offer_level = 'S'
--   AND d.CYCLE IN (10, 15, 20)
--   AND a.prepayment IS NOT NULL
--   AND a.offer_level_id = b.subscr_id
--   AND a.offer_id = c.offer_id
--   AND a.cust_id = d.cust_id
--   AND a.acct_id = f.entity_id
--   AND a.acct_id = va.account_id(+)
--   AND d.CYCLE = cntrl.CYCLE;

/* Formatted on 2024/03/05 15:17 (Formatter Plus v4.8.8) */
SELECT    DECODE (d.CYCLE, 10, 'HGBN', 15, 'HGBN', 20, 'HGBN')
       || ','
       || va.proposal_id
       || ','
       || f.elem2
       || ','
       || a.acct_id
       || ','
       || TO_CHAR (cntrl.bill_date, 'YYYY/MM/DD')
       || ','
       || NVL ((SELECT SUM (bb.amount) * -1
                  FROM fy_tb_bl_bill_cntrl aa, fy_tb_bl_bill_ci bb
                 WHERE aa.bill_period =
                                   TO_CHAR (ADD_MONTHS (SYSDATE, -2),
                                            'yyyymm')
                   AND aa.bill_seq = bb.bill_seq
                   AND bb.SOURCE = 'DE'
                   AND bb.subscr_id = a.offer_level_id
                   AND bb.offer_id = a.offer_id
                   AND bb.offer_instance_id = a.offer_instance_id),
               0
              )
  FROM fy_tb_bl_acct_pkg a,
       fy_tb_cm_subscr b,
       fy_tb_pbk_offer c,
       fy_tb_cm_customer d,
       (SELECT *
          FROM fy_tb_cm_prof_link
         WHERE link_type = 'A' AND prof_type = 'NAME') f,
       (SELECT   CYCLE, ADD_MONTHS (MAX (bill_date), -2) bill_date
            FROM fy_tb_bl_bill_cntrl
           WHERE CYCLE IN (10, 15, 20)
        GROUP BY CYCLE) cntrl,
       v_account va
 WHERE a.offer_level = 'S'
   AND d.CYCLE IN (10, 15, 20)
   AND a.prepayment IS NOT NULL
   AND a.offer_level_id = b.subscr_id
   AND a.offer_id = c.offer_id
   AND a.cust_id = d.cust_id
   AND a.acct_id = f.entity_id
   AND a.acct_id = va.account_id(+)
   AND d.CYCLE = cntrl.CYCLE;

spool off

exit;

EOF`

echo "Gen Report End"|tee -a ${logFile}
}

function ftpReport2
{
ftp -i -n -v $1<<EOF
user $2 $3
pass
cd $4
mput $5
bye
EOF
}

function formatterReport
{
grep -v '^$' P266082.dat > ${ReportDir}/${reportFileName}.csv
rm P266082.dat
iconv -f utf8 -t big5 -c ${ReportDir}/${reportFileName}.csv > ${ReportDir}/${reportFileName}.big5
mv ${ReportDir}/${reportFileName}.big5 ${ReportDir}/${reportFileName}.csv
sleep 5
grep -v '^$' P266082-1.dat > ${ReportDir}/${reportFileName2}.csv
rm P266082-1.dat
iconv -f utf8 -t big5 -c ${ReportDir}/${reportFileName2}.csv > ${ReportDir}/${reportFileName2}.big5
mv ${ReportDir}/${reportFileName2}.big5 ${ReportDir}/${reportFileName2}.csv
}

function sendFinalMail
{
send_msg="<SR266082_HGBN_UBL_ICT_Report_P266082> $sysd"
	#iconv -f utf8 -t big5 -c ${reportFileName}.txt > ${reportFileName}.big5
	#mv ${reportFileName}.big5 ${reportFileName}.txt
	#rm ${reportFileName}.dat
mailx -s "${send_msg}" -a ${ReportDirBak}/${reportFileName}.csv ${mailList} <<EOF
Dears,

   SR266082_HGBN_UBL_ICT_Report_P266082已產出。
   檔名：
   ${reportFileName}.csv
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF

send_msg="<SR266082_HGBN_UBL_ICT_Report_P266082-1> $sysd"
	#iconv -f utf8 -t big5 -c ${reportFileName}.txt > ${reportFileName}.big5
	#mv ${reportFileName}.big5 ${reportFileName}.txt
	#rm ${reportFileName}.dat
mailx -s "${send_msg}" -a ${ReportDirBak}/${reportFileName2}.csv ${mailList} <<EOF
Dears,

   SR266082_HGBN_UBL_ICT_Report_P266082-1已產出。
   檔名：
   ${reportFileName2}.csv
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

function sendGenTempErrorMail
{
send_msg="<SR266082_HGBN_UBL_ICT_Report_P266082> $sysd"
mailx -s "${send_msg} Gen Data Have Abnormal " ${mailList} <<EOF
Dear All,
  
  SR266082_HGBN_UBL_ICT_Report_P266082未產出。
  
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF

send_msg="<SR266082_HGBN_UBL_ICT_Report_P266082-1> $sysd"
mailx -s "${send_msg} Gen Data Have Abnormal " ${mailList} <<EOF
Dear All,
  
  SR266082_HGBN_UBL_ICT_Report_P266082-1未產出。
  
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

#---------------------------------------------------------------------------------------#
#      main
#---------------------------------------------------------------------------------------#
echo "Gen ${reportFileName} Start" | tee -a ${logFile}
echo $sysdt|tee -a ${logFile}
cd $ReportDir
genReport
sleep 5
echo "Gen ${reportFileName2} Start" | tee -a ${logFile}
genReport2
sleep 5
#formatter Report 
echo "Formatter Report Start"|tee -a ${logFile}
formatterReport
echo "Formatter Report End"|tee -a ${logFile}


#check gen report
filecnt1=`ls ${ReportDir}/${reportFileName}.csv|wc -l`
sleep 5
if [[ (${filecnt1} = 0 ) ]] ; then
	echo "${progName} Generated Report Have Abnormal"|tee -a ${logFile}
	sendGenTempErrorMail
	exit 0
else
cd ${ReportDir}
	echo "FTP Report"|tee -a ${logFile}
	echo "Run Command: ${ftpProg} ${putip1} ${putuser1} ******** ${ReportDir} ${putpath1} ${reportFileName}.csv 0" | tee -a ${logFile}
		${ftpProg} ${putip1} ${putuser1} ${putpass1} ${ReportDir} ${putpath1} ${reportFileName}.csv 0
	echo "Run Command: ${ftpProg} ${putip1} ${putuser1} ******** ${ReportDir} ${putpath1} ${reportFileName2}.csv 0" | tee -a ${logFile}
		${ftpProg} ${putip1} ${putuser1} ${putpass1} ${ReportDir} ${putpath1} ${reportFileName2}.csv 0
	
		#cd ${ReportDir}
	#ftpReport2 ${putip1} ${putuser1} ${putpass1} ${putpath1} "${reportFileName}.txt"
		
	echo "send SR250171_HGB_ESDP_UNBILL_Report"|tee -a ${logFile}

	echo "Move Report TO Bak"|tee -a ${logFile}
	mv "${reportFileName}.csv" ${ReportDirBak}
	mv "${reportFileName2}.csv" ${ReportDirBak}
	#send final mail
	sendFinalMail
fi
sleep 5

echo "Gen ${reportFileName} End" | tee -a ${logFile}
echo "Gen ${reportFileName2} End" | tee -a ${logFile}
echo $sysdt|tee -a ${logFile}
