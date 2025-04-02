#!/usr/bin/env bash
########################################################################################
# Program name : SR250171_HGB_UBL_ESDP_UNBILL_Report.sh
# Path : /extsoft/UBL/BL/Surrounding/RPT
#
# Date : 2022/06/22 Create by Mike Kuan
# Description : SR250171_ESDP Migraion估計報表、未實現報表
########################################################################################
# Date : 2022/07/18 Create by Mike Kuan
# Description : 修改檔名月份
########################################################################################
# Date : 2022/11/18 Create by Mike Kuan
# Description : 修改sysd日期，每月產生前月資料
########################################################################################
# Date : 2023/05/02 Create by Mike Kuan
# Description : 修改月份進位從無條件捨去改為小數兩位
########################################################################################
# Date : 2023/04/24 Modify by Mike Kuan
# Description : SR260229_Project-M Fixed line Phase I_新增CYCLE(15,20)
########################################################################################
# Date : 2024/10/28 Modify by Mike Kuan
# Description : 修改estimate_costs為0
########################################################################################
# Date : 2025/04/02 Modify by Mike Kuan
# Description : SR273784_Project M Fixed Line Phase II 整合專案，新增reportFileName3,4
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
reportFileName="ESDP_`date +%Y%m --date="-0 month"`_`date +%Y%m%d%H%M%S`"
reportFileName2="HGB_ESDP_UNBILL2_`date +%Y%m --date="-0 month"`_`date +%Y%m%d%H%M%S`"
reportFileName3="APT_ESDP_`date +%Y%m --date="-0 month"`_`date +%Y%m%d%H%M%S`"
reportFileName4="APT_HGB_ESDP_UNBILL2_`date +%Y%m --date="-0 month"`_`date +%Y%m%d%H%M%S`"
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
putpass1=unix11
;;
"pc-hgbap21t") #(TEST02) (UAT)
DB="HGBBLUAT"
RPTDB="HGBBLUAT"
OCS_AP="fetwrk21"
putip1=10.64.18.122
putpass1=unix11
;;
"pet-hgbap01p"|"pet-hgbap02p") #(PET)
DB="HGBBL"
RPTDB="HGBBLRPT"
OCS_AP="prdbl2"
putip1=10.64.18.123
putpass1=unix11
;;
"idc-hgbap01p"|"idc-hgbap02p") #(PROD)
DB="HGBBL"
RPTDB="HGBBLRPT"
OCS_AP="prdbl2"
putip1=10.68.59.130
putpass1=`/cb/CRYPT/GetPw.sh UBL_UAR_FTP`
;;
*)
echo "Unknown AP Server"
exit 0
esac
DBID=`/cb/CRYPT/GetId.sh $DB`
DBPWD=`/cb/CRYPT/GetPw.sh $DB`
#FTP
putuser1=ublftp
putpath1=/AR/payment/ARBATCH90/Batch_ESDP_FSS_RPT/DIO_INPUT

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

spool ${reportFileName}.dat

select 'CUSTOMER_ID'||';'||'SUBSCRIBER_NO'||';'||'ACCOUNT_ID'||';'||'CYCLE_CODE'||';'||'CYCLE_MONTH'||';'||'CYCLE_YEAR'||';'||'BILLINVNUM'||';'||'CHARGE_TYPE'||';'||'CHARGE_CODE'||';'||'CHARGEAMT'||';'||'TAX_AMOUNT'||';'||'TAX_RATE'||';'||'TAX_CODE'||';'||'SERVICE_RECEIVER_TYPE'||';'||'SUBSCRIBER_TYPE'||';'||'CYCLE_ST_DT'||';'||'CYCLE_ED_DT'||';'||'CHARGE_ST_DT'||';'||'CHARGE_ED_DT'||';'||'GUI'||';'||'END_DATE'||';'||'estimate_days'||';'||'estimate_costs' from dual;

--/* Formatted on 2022/07/08 11:21 (Formatter Plus v4.8.8) */
--SELECT bi_seq, charge_org, subscr.cust_id, bi.subscr_id, bi.acct_id, bi.CYCLE,
--       bi.cycle_month, SUBSTR (cntrl.bill_period, 1, 4), mast.bill_nbr,
--       bi.charge_type, bi.charge_code, (bi.amount - bi.tax_amt), bi.tax_amt,
--       DECODE (bi.tax_type, 'TX1', 5, 0) tax_rate, bi.tax_type,
--       bi.service_receiver_type, subscr.subscr_type, cntrl.bill_from_date,
--       cntrl.bill_end_date,
--       TO_CHAR
--          (TO_DATE (DECODE (bi.charge_org,
--                            'RA', REGEXP_SUBSTR
--                                              (bi.dynamic_attribute,
--                                               '.*First_Event_Date=([^#]*).*',
--                                               1,
--                                               1,
--                                               NULL,
--                                               1
--                                              ),
--                            NVL (TO_CHAR (bi.chrg_from_date, 'yyyy/mm/dd'),
--                                 TO_CHAR (cntrl.bill_from_date, 'yyyy/mm/dd')
--                                )
--                           ),
--                    'yyyy/mm/dd'
--                   ),
--           'yyyy/mm/dd'
--          ) chrg_from_date,
--       TO_CHAR
--          (TO_DATE (DECODE (bi.charge_org,
--                            'RA', REGEXP_SUBSTR
--                                               (bi.dynamic_attribute,
--                                                '.*Last_Event_Date=([^#]*).*',
--                                                1,
--                                                1,
--                                                NULL,
--                                                1
--                                               ),
--                            NVL (TO_CHAR (bi.chrg_end_date, 'yyyy/mm/dd'),
--                                 TO_CHAR (cntrl.bill_end_date, 'yyyy/mm/dd')
--                                )
--                           ),
--                    'yyyy/mm/dd'
--                   ),
--           'yyyy/mm/dd'
--          ) chrg_end_date,
--       LINK.elem6, pkg.end_date,
--       CASE
--          WHEN pkg.end_date IS NOT NULL
--             THEN (pkg.end_date - 1 - bi.chrg_end_date)
--          WHEN (SUBSTR (TO_CHAR (cntrl.bill_end_date, 'yyyymmdd'), 5, 2)
--               ) IN ('01', '03', '05', '07', '08', '10', '12')
--             THEN 31             ---(bi.chrg_from_date - cntrl.bill_from_date)
--          WHEN (SUBSTR (TO_CHAR (cntrl.bill_end_date, 'yyyymmdd'), 5, 2)) IN
--                                                                       ('02')
--             THEN 28             ---(bi.chrg_from_date - cntrl.bill_from_date)
--          ELSE 30                ---(bi.chrg_from_date - cntrl.bill_from_date)
--       END AS estimate_days,
--       ROUND
--          (  (  (bi.amount - bi.tax_amt)
--              / (  TO_DATE
--                      (DECODE (bi.charge_org,
--                               'RA', REGEXP_SUBSTR
--                                               (bi.dynamic_attribute,
--                                                '.*Last_Event_Date=([^#]*).*',
--                                                1,
--                                                1,
--                                                NULL,
--                                                1
--                                               ),
--                               NVL (TO_CHAR (bi.chrg_end_date, 'yyyy/mm/dd'),
--                                    TO_CHAR (cntrl.bill_end_date,
--                                             'yyyy/mm/dd')
--                                   )
--                              ),
--                       'yyyy/mm/dd'
--                      )
--                 - TO_DATE
--                      (DECODE (bi.charge_org,
--                               'RA', REGEXP_SUBSTR
--                                              (bi.dynamic_attribute,
--                                               '.*First_Event_Date=([^#]*).*',
--                                               1,
--                                               1,
--                                               NULL,
--                                               1
--                                              ),
--                               NVL (TO_CHAR (bi.chrg_from_date, 'yyyy/mm/dd'),
--                                    TO_CHAR (cntrl.bill_from_date,
--                                             'yyyy/mm/dd'
--                                            )
--                                   )
--                              ),
--                       'yyyy/mm/dd'
--                      )
--                 + 1
--                )          --* (cntrl.bill_end_date - cntrl.bill_end_date + 1)
--             )
--           * CASE
--                WHEN pkg.end_date IS NOT NULL
--                   THEN (pkg.end_date - 1 - bi.chrg_end_date)
--                WHEN (SUBSTR (TO_CHAR (cntrl.bill_end_date, 'yyyymmdd'), 5, 2)
--                     ) IN ('01', '03', '05', '07', '08', '10', '12')
--                   THEN 31       ---(bi.chrg_from_date - cntrl.bill_from_date)
--                WHEN (SUBSTR (TO_CHAR (cntrl.bill_end_date, 'yyyymmdd'), 5, 2)
--                     ) IN ('02')
--                   THEN 28       ---(bi.chrg_from_date - cntrl.bill_from_date)
--                ELSE 30          ---(bi.chrg_from_date - cntrl.bill_from_date)
--             END
--          ) estimate_costs
--  FROM fy_tb_bl_bill_bi bi,
--       fy_tb_bl_acct_pkg pkg,
--       fy_tb_bl_bill_mast mast,
--       fy_tb_cm_subscr subscr,
--       fy_tb_bl_bill_cntrl cntrl,
--       (SELECT entity_id, elem6
--          FROM fy_tb_cm_prof_link
--         WHERE entity_type = 'A' AND link_type = 'A' AND prof_type = 'NAME'
--                                                                           --and elem5=2
--       ) LINK
-- WHERE bi.bill_seq = cntrl.bill_seq
--   AND bi.bill_seq = mast.bill_seq
--   AND bi.CYCLE = cntrl.CYCLE
--   AND bi.CYCLE = mast.CYCLE
--   AND bi.acct_id = mast.acct_id
--   AND bi.acct_id = pkg.acct_id(+)
--   AND bi.acct_id = subscr.acct_id
--   AND bi.acct_id = LINK.entity_id
--   AND bi.subscr_id = subscr.subscr_id
--   AND bi.subscr_id = pkg.offer_level_id(+)
--   AND bi.offer_id = pkg.offer_id(+)
--   AND bi.offer_seq = pkg.offer_seq(+)
--   AND cntrl.bill_period = 202205
--   AND cntrl.CYCLE = 10
--   --and bi.BILL_SEQ=150053
--   AND bi.charge_org NOT IN ('IN', 'NN')
--   AND NVL (bi.chrg_end_date, cntrl.bill_end_date) <= cntrl.bill_end_date;

/* Formatted on 2022/07/08 11:20 (Formatter Plus v4.8.8) */
SELECT    subscr.cust_id
       || ';'
       || bi.subscr_id
       || ';'
       || bi.acct_id
       || ';'
       || bi.CYCLE
       || ';'
       || bi.cycle_month
       || ';'
       || SUBSTR (cntrl.bill_period, 1, 4)
       || ';'
       || mast.bill_nbr
       || ';'
       || bi.charge_type
       || ';'
       || bi.charge_code
       || ';'
       || (bi.amount - bi.tax_amt)
       || ';'
       || bi.tax_amt
       || ';'
       || DECODE (bi.tax_type, 'TX1', 5, 0)
       || ';'
       || bi.tax_type
       || ';'
       || bi.service_receiver_type
       || ';'
       || subscr.subscr_type
       || ';'
       || TO_CHAR (cntrl.bill_from_date, 'YYYY/MM/DD')
       || ';'
       || TO_CHAR (cntrl.bill_end_date, 'YYYY/MM/DD')
       || ';'
       || TO_CHAR
             (TO_DATE
                     (DECODE (bi.charge_org,
                              'RA', REGEXP_SUBSTR
                                              (bi.dynamic_attribute,
                                               '.*First_Event_Date=([^#]*).*',
                                               1,
                                               1,
                                               NULL,
                                               1
                                              ),
                              NVL (TO_CHAR (bi.chrg_from_date, 'yyyy/mm/dd'),
                                   TO_CHAR (cntrl.bill_from_date,
                                            'yyyy/mm/dd')
                                  )
                             ),
                      'yyyy/mm/dd'
                     ),
              'yyyy/mm/dd'
             )
       || ';'
       || TO_CHAR
             (TO_DATE (DECODE (bi.charge_org,
                               'RA', REGEXP_SUBSTR
                                               (bi.dynamic_attribute,
                                                '.*Last_Event_Date=([^#]*).*',
                                                1,
                                                1,
                                                NULL,
                                                1
                                               ),
                               NVL (TO_CHAR (bi.chrg_end_date, 'yyyy/mm/dd'),
                                    TO_CHAR (cntrl.bill_end_date,
                                             'yyyy/mm/dd')
                                   )
                              ),
                       'yyyy/mm/dd'
                      ),
              'yyyy/mm/dd'
             )
       || ';'
       || LINK.elem6
       || ';'
       || TO_CHAR (pkg.end_date, 'YYYY/MM/DD')
       || ';'
       || CASE
             WHEN pkg.end_date IS NOT NULL
                THEN (pkg.end_date - 1 - bi.chrg_end_date)
             WHEN (SUBSTR (TO_CHAR (cntrl.bill_end_date, 'yyyymmdd'), 5, 2)) IN
                                   ('01', '03', '05', '07', '08', '10', '12')
                THEN 31          ---(bi.chrg_from_date - cntrl.bill_from_date)
             WHEN (SUBSTR (TO_CHAR (cntrl.bill_end_date, 'yyyymmdd'), 5, 2)) IN
                                                                       ('02')
                THEN 28          ---(bi.chrg_from_date - cntrl.bill_from_date)
             ELSE 30             ---(bi.chrg_from_date - cntrl.bill_from_date)
          END
       || ';'
       || 0
  FROM fy_tb_bl_bill_bi bi,
       fy_tb_bl_acct_pkg pkg,
       fy_tb_bl_bill_mast mast,
       fy_tb_cm_subscr subscr,
       fy_tb_bl_bill_cntrl cntrl,
       (SELECT entity_id, elem6
          FROM fy_tb_cm_prof_link
         WHERE entity_type = 'A' AND link_type = 'A' AND prof_type = 'NAME'
                                                                           --and elem5=2
       ) LINK,
	   fy_tb_cm_customer cust
 WHERE bi.bill_seq = cntrl.bill_seq
   AND bi.bill_seq = mast.bill_seq
   AND bi.CYCLE = cntrl.CYCLE
   AND bi.CYCLE = mast.CYCLE
   AND bi.acct_id = mast.acct_id
   AND bi.acct_id = pkg.acct_id(+)
   AND bi.acct_id = subscr.acct_id
   AND bi.acct_id = LINK.entity_id
   AND bi.subscr_id = subscr.subscr_id
   AND bi.subscr_id = pkg.offer_level_id(+)
   AND bi.offer_id = pkg.offer_id(+)
   AND bi.offer_seq = pkg.offer_seq(+)
   AND cntrl.bill_period = ${sysd}
   AND cntrl.CYCLE IN (10, 15) --SR260229_Project-M Fixed line Phase I_新增CYCLE(15,20) --SR273784_移除Cycle 20
   AND subscr.cust_id = cust.cust_id
   AND cust.cust_type != 'P' --SR273784_非APT
   --and bi.BILL_SEQ=150053
   AND bi.charge_org NOT IN ('IN', 'NN')
   AND NVL (bi.chrg_end_date, cntrl.bill_end_date) <= cntrl.bill_end_date;

spool off

exit;

EOF`

echo "Gen Report End"|tee -a ${logFile}
}

function genReport3
{
echo "Gen Report3 Start"|tee -a ${logFile}
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

spool ${reportFileName3}.dat

select 'CUSTOMER_ID'||';'||'SUBSCRIBER_NO'||';'||'ACCOUNT_ID'||';'||'CYCLE_CODE'||';'||'CYCLE_MONTH'||';'||'CYCLE_YEAR'||';'||'BILLINVNUM'||';'||'CHARGE_TYPE'||';'||'CHARGE_CODE'||';'||'CHARGEAMT'||';'||'TAX_AMOUNT'||';'||'TAX_RATE'||';'||'TAX_CODE'||';'||'SERVICE_RECEIVER_TYPE'||';'||'SUBSCRIBER_TYPE'||';'||'CYCLE_ST_DT'||';'||'CYCLE_ED_DT'||';'||'CHARGE_ST_DT'||';'||'CHARGE_ED_DT'||';'||'GUI'||';'||'END_DATE'||';'||'estimate_days'||';'||'estimate_costs' from dual;

/* Formatted on 2022/07/08 11:20 (Formatter Plus v4.8.8) */
SELECT    subscr.cust_id
       || ';'
       || bi.subscr_id
       || ';'
       || bi.acct_id
       || ';'
       || bi.CYCLE
       || ';'
       || bi.cycle_month
       || ';'
       || SUBSTR (cntrl.bill_period, 1, 4)
       || ';'
       || mast.bill_nbr
       || ';'
       || bi.charge_type
       || ';'
       || bi.charge_code
       || ';'
       || (bi.amount - bi.tax_amt)
       || ';'
       || bi.tax_amt
       || ';'
       || DECODE (bi.tax_type, 'TX1', 5, 0)
       || ';'
       || bi.tax_type
       || ';'
       || bi.service_receiver_type
       || ';'
       || subscr.subscr_type
       || ';'
       || TO_CHAR (cntrl.bill_from_date, 'YYYY/MM/DD')
       || ';'
       || TO_CHAR (cntrl.bill_end_date, 'YYYY/MM/DD')
       || ';'
       || TO_CHAR
             (TO_DATE
                     (DECODE (bi.charge_org,
                              'RA', REGEXP_SUBSTR
                                              (bi.dynamic_attribute,
                                               '.*First_Event_Date=([^#]*).*',
                                               1,
                                               1,
                                               NULL,
                                               1
                                              ),
                              NVL (TO_CHAR (bi.chrg_from_date, 'yyyy/mm/dd'),
                                   TO_CHAR (cntrl.bill_from_date,
                                            'yyyy/mm/dd')
                                  )
                             ),
                      'yyyy/mm/dd'
                     ),
              'yyyy/mm/dd'
             )
       || ';'
       || TO_CHAR
             (TO_DATE (DECODE (bi.charge_org,
                               'RA', REGEXP_SUBSTR
                                               (bi.dynamic_attribute,
                                                '.*Last_Event_Date=([^#]*).*',
                                                1,
                                                1,
                                                NULL,
                                                1
                                               ),
                               NVL (TO_CHAR (bi.chrg_end_date, 'yyyy/mm/dd'),
                                    TO_CHAR (cntrl.bill_end_date,
                                             'yyyy/mm/dd')
                                   )
                              ),
                       'yyyy/mm/dd'
                      ),
              'yyyy/mm/dd'
             )
       || ';'
       || LINK.elem6
       || ';'
       || TO_CHAR (pkg.end_date, 'YYYY/MM/DD')
       || ';'
       || CASE
             WHEN pkg.end_date IS NOT NULL
                THEN (pkg.end_date - 1 - bi.chrg_end_date)
             WHEN (SUBSTR (TO_CHAR (cntrl.bill_end_date, 'yyyymmdd'), 5, 2)) IN
                                   ('01', '03', '05', '07', '08', '10', '12')
                THEN 31          ---(bi.chrg_from_date - cntrl.bill_from_date)
             WHEN (SUBSTR (TO_CHAR (cntrl.bill_end_date, 'yyyymmdd'), 5, 2)) IN
                                                                       ('02')
                THEN 28          ---(bi.chrg_from_date - cntrl.bill_from_date)
             ELSE 30             ---(bi.chrg_from_date - cntrl.bill_from_date)
          END
       || ';'
       || 0
  FROM fy_tb_bl_bill_bi bi,
       fy_tb_bl_acct_pkg pkg,
       fy_tb_bl_bill_mast mast,
       fy_tb_cm_subscr subscr,
       fy_tb_bl_bill_cntrl cntrl,
       (SELECT entity_id, elem6
          FROM fy_tb_cm_prof_link
         WHERE entity_type = 'A' AND link_type = 'A' AND prof_type = 'NAME'
                                                                           --and elem5=2
       ) LINK,
	   fy_tb_cm_customer cust
 WHERE bi.bill_seq = cntrl.bill_seq
   AND bi.bill_seq = mast.bill_seq
   AND bi.CYCLE = cntrl.CYCLE
   AND bi.CYCLE = mast.CYCLE
   AND bi.acct_id = mast.acct_id
   AND bi.acct_id = pkg.acct_id(+)
   AND bi.acct_id = subscr.acct_id
   AND bi.acct_id = LINK.entity_id
   AND bi.subscr_id = subscr.subscr_id
   AND bi.subscr_id = pkg.offer_level_id(+)
   AND bi.offer_id = pkg.offer_id(+)
   AND bi.offer_seq = pkg.offer_seq(+)
   AND cntrl.bill_period = ${sysd}
   AND cntrl.CYCLE IN (10, 15)
   AND subscr.cust_id = cust.cust_id
   AND cust.cust_type = 'P' --SR273784_APT
   --and bi.BILL_SEQ=150053
   AND bi.charge_org NOT IN ('IN', 'NN')
   AND NVL (bi.chrg_end_date, cntrl.bill_end_date) <= cntrl.bill_end_date;

spool off

exit;

EOF`

echo "Gen Report3 End"|tee -a ${logFile}
}

function genReport2
{
echo "Gen Report2 Start"|tee -a ${logFile}
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

spool ${reportFileName2}.dat

select 'CUSTOMER_ID'||';'||'SUBSCRIBER_NO'||';'||'ACCOUNT_ID'||';'||'CYCLE_CODE'||';'||'CYCLE_MONTH'||';'||'CYCLE_YEAR'||';'||'BILLINVNUM'||';'||'CHARGE_TYPE'||';'||'CHARGE_CODE'||';'||'CHARGEAMT'||';'||'TAX_AMOUNT'||';'||'TAX_RATE'||';'||'TAX_CODE'||';'||'SERVICE_RECEIVER_TYPE'||';'||'SUBSCRIBER_TYPE'||';'||'CYCLE_ST_DT'||';'||'CYCLE_ED_DT'||';'||'CHARGE_ST_DT'||';'||'CHARGE_ED_DT'||';'||'GUI'||';'||'END_DATE'||';'||'months_diff'||';'||'months_diff2'||';'||'months_diff3'||';'||'m1'||';'||'m2' from dual;

--/* Formatted on 2022/06/23 14:52 (Formatter Plus v4.8.8) */
--SELECT subscr.cust_id, bi.subscr_id, bi.acct_id, bi.CYCLE, bi.cycle_month,
--       SUBSTR (cntrl.bill_period, 1, 4), mast.bill_nbr, bi.charge_type,
--       bi.charge_code, (bi.amount - bi.tax_amt), bi.tax_amt,
--       DECODE (bi.tax_type, 'TX1', 5, 0) tax_rate, bi.tax_type,
--       bi.service_receiver_type, subscr.subscr_type, cntrl.bill_from_date,
--       cntrl.bill_end_date, bi.chrg_from_date, bi.chrg_end_date, LINK.elem6,
--       pkg.end_date,
--       CASE
--          WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
--                - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
--               ) >= 0.5
--             THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                           bi.chrg_from_date)
--                          )
--                  + 1
--          ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
--       END AS months_diff,
--       CASE
--          WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
--                                  bi.chrg_from_date
--                                 )
--                - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
--                                         bi.chrg_from_date
--                                        )
--                        )
--               ) >= 0.5
--             THEN   TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
--                                           bi.chrg_from_date
--                                          )
--                          )
--                  + 1
--          ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
--                                      bi.chrg_from_date
--                                     )
--                     )
--       END AS months_diff2,
--       (  CASE
--             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
--                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                            bi.chrg_from_date
--                                           )
--                           )
--                  ) >= 0.5
--                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                              bi.chrg_from_date
--                                             )
--                             )
--                     + 1
--             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
--          END
--        - CASE
--             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
--                                     bi.chrg_from_date
--                                    )
--                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
--                                                        1),
--                                            bi.chrg_from_date
--                                           )
--                           )
--                  ) >= 0.5
--                THEN   TRUNC
--                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
--                                                         1
--                                                        ),
--                                             bi.chrg_from_date
--                                            )
--                            )
--                     + 1
--             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
--                                         bi.chrg_from_date
--                                        )
--                        )
--          END
--       ) AS months_diff3,
--       ROUND
--          (  (bi.amount - bi.tax_amt)
--           / CASE
--                WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
--                      - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                               bi.chrg_from_date
--                                              )
--                              )
--                     ) >= 0.5
--                   THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                                 bi.chrg_from_date
--                                                )
--                                )
--                        + 1
--                ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                            bi.chrg_from_date
--                                           )
--                           )
--             END
--          ) m1,
--       ROUND
--          (  (bi.amount - bi.tax_amt)
--           / CASE
--                WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
--                      - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                               bi.chrg_from_date
--                                              )
--                              )
--                     ) >= 0.5
--                   THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                                 bi.chrg_from_date
--                                                )
--                                )
--                        + 1
--                ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                            bi.chrg_from_date
--                                           )
--                           )
--             END
--          )
--           *        (  CASE
--             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
--                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                            bi.chrg_from_date
--                                           )
--                           )
--                  ) >= 0.5
--                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
--                                              bi.chrg_from_date
--                                             )
--                             )
--                     + 1
--             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
--          END
--        - CASE
--             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
--                                     bi.chrg_from_date
--                                    )
--                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
--                                                        1),
--                                            bi.chrg_from_date
--                                           )
--                           )
--                  ) >= 0.5
--                THEN   TRUNC
--                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
--                                                         1
--                                                        ),
--                                             bi.chrg_from_date
--                                            )
--                            )
--                     + 1
--             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
--                                         bi.chrg_from_date
--                                        )
--                        )
--          END
--       ) m2
--  FROM fy_tb_bl_bill_bi bi,
--       fy_tb_bl_acct_pkg pkg,
--       fy_tb_bl_bill_mast mast,
--       fy_tb_cm_subscr subscr,
--       fy_tb_bl_bill_cntrl cntrl,
--       (SELECT entity_id, elem6
--          FROM fy_tb_cm_prof_link
--         WHERE entity_type = 'A' AND link_type = 'A' AND prof_type = 'NAME'
--                                                                           --and elem5=2
--       ) LINK
-- WHERE bi.bill_seq = cntrl.bill_seq
--   AND bi.bill_seq = mast.bill_seq
--   AND bi.CYCLE = cntrl.CYCLE
--   AND bi.CYCLE = mast.CYCLE
--   AND bi.acct_id = mast.acct_id
--   AND bi.acct_id = pkg.acct_id(+)
--   AND bi.acct_id = subscr.acct_id
--   AND bi.acct_id = LINK.entity_id
--   AND bi.subscr_id = subscr.subscr_id
--   AND bi.subscr_id = pkg.offer_level_id(+)
--   AND bi.offer_id = pkg.offer_id(+)
--   AND bi.offer_seq = pkg.offer_seq(+)
--   AND cntrl.bill_period = 202005
--   AND cntrl.CYCLE = 10
--   --and bi.BILL_SEQ=150053
--   AND bi.charge_org NOT IN ('IN', 'NN')
--   AND NVL (bi.chrg_end_date, cntrl.bill_end_date) > cntrl.bill_end_date;

/* Formatted on 2022/06/23 14:52 (Formatter Plus v4.8.8) */
SELECT subscr.cust_id||';'||bi.subscr_id||';'||bi.acct_id||';'||bi.CYCLE||';'||bi.cycle_month||';'||
       SUBSTR (cntrl.bill_period, 1, 4)||';'||mast.bill_nbr||';'||bi.charge_type||';'||
       bi.charge_code||';'||(bi.amount - bi.tax_amt)||';'||bi.tax_amt||';'||
       DECODE (bi.tax_type, 'TX1', 5, 0)||';'||bi.tax_type||';'||
       bi.service_receiver_type||';'||subscr.subscr_type||';'||TO_CHAR (cntrl.bill_from_date, 'YYYY/MM/DD')||';'||
       TO_CHAR (cntrl.bill_end_date, 'YYYY/MM/DD')||';'||TO_CHAR (bi.chrg_from_date, 'YYYY/MM/DD')||';'||TO_CHAR (bi.chrg_end_date, 'YYYY/MM/DD')||';'||LINK.elem6||';'||
       TO_CHAR (pkg.end_date, 'YYYY/MM/DD')||';'||
       CASE
          WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
               ) >= 0.5
             THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                           bi.chrg_from_date)
                          )
                  + 1
          ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
       END||';'||
       CASE
          WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                  bi.chrg_from_date
                                 )
                - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
               ) >= 0.5
             THEN   TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                           bi.chrg_from_date
                                          )
                          )
                  + 1
          ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                      bi.chrg_from_date
                                     )
                     )
       END||';'||
       decode(sign(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),1,(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),0)||';'||
       decode(sign(decode(sign(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),1,(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),0)),0,ROUND((bi.amount - bi.tax_amt),0),ROUND
          (  (bi.amount - bi.tax_amt)
           / CASE
                WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                      - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                               bi.chrg_from_date
                                              )
                              )
                     ) >= 0.5
                   THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                                 bi.chrg_from_date
                                                )
                                )
                        + 1
                ELSE ROUND (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           ,2)
             END
          ))||';'||
       ROUND(ROUND
          (  (bi.amount - bi.tax_amt)
           / CASE
                WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                      - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                               bi.chrg_from_date
                                              )
                              )
                     ) >= 0.5
                   THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                                 bi.chrg_from_date
                                                )
                                )
                        + 1
                ELSE ROUND (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           ,2)
             END
          )
           *        decode(sign(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),1,(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),0),0)
  FROM fy_tb_bl_bill_bi bi,
       fy_tb_bl_acct_pkg pkg,
       fy_tb_bl_bill_mast mast,
       fy_tb_cm_subscr subscr,
       fy_tb_bl_bill_cntrl cntrl,
       (SELECT entity_id, elem6
          FROM fy_tb_cm_prof_link
         WHERE entity_type = 'A' AND link_type = 'A' AND prof_type = 'NAME'
                                                                           --and elem5=2
       ) LINK,
	   fy_tb_cm_customer cust
 WHERE bi.bill_seq = cntrl.bill_seq
   AND bi.bill_seq = mast.bill_seq
   AND bi.CYCLE = cntrl.CYCLE
   AND bi.CYCLE = mast.CYCLE
   AND bi.acct_id = mast.acct_id
   AND bi.acct_id = pkg.acct_id(+)
   AND bi.acct_id = subscr.acct_id
   AND bi.acct_id = LINK.entity_id
   AND bi.subscr_id = subscr.subscr_id
   AND bi.subscr_id = pkg.offer_level_id(+)
   AND bi.offer_id = pkg.offer_id(+)
   AND bi.offer_seq = pkg.offer_seq(+)
   AND cntrl.bill_period = ${sysd}
   AND cntrl.CYCLE IN (10, 15) --SR260229_Project-M Fixed line Phase I_新增CYCLE(15,20) --SR273784_移除Cycle 20
   AND subscr.cust_id = cust.cust_id
   AND cust.cust_type != 'P' --SR273784_非APT
   --and bi.BILL_SEQ=150053
   AND bi.charge_org NOT IN ('IN', 'NN')
   AND NVL (bi.chrg_end_date, cntrl.bill_end_date) > cntrl.bill_end_date;

spool off

exit;

EOF`

echo "Gen Report2 End"|tee -a ${logFile}
}

function genReport4
{
echo "Gen Report4 Start"|tee -a ${logFile}
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

spool ${reportFileName4}.dat

select 'CUSTOMER_ID'||';'||'SUBSCRIBER_NO'||';'||'ACCOUNT_ID'||';'||'CYCLE_CODE'||';'||'CYCLE_MONTH'||';'||'CYCLE_YEAR'||';'||'BILLINVNUM'||';'||'CHARGE_TYPE'||';'||'CHARGE_CODE'||';'||'CHARGEAMT'||';'||'TAX_AMOUNT'||';'||'TAX_RATE'||';'||'TAX_CODE'||';'||'SERVICE_RECEIVER_TYPE'||';'||'SUBSCRIBER_TYPE'||';'||'CYCLE_ST_DT'||';'||'CYCLE_ED_DT'||';'||'CHARGE_ST_DT'||';'||'CHARGE_ED_DT'||';'||'GUI'||';'||'END_DATE'||';'||'months_diff'||';'||'months_diff2'||';'||'months_diff3'||';'||'m1'||';'||'m2' from dual;

/* Formatted on 2022/06/23 14:52 (Formatter Plus v4.8.8) */
SELECT subscr.cust_id||';'||bi.subscr_id||';'||bi.acct_id||';'||bi.CYCLE||';'||bi.cycle_month||';'||
       SUBSTR (cntrl.bill_period, 1, 4)||';'||mast.bill_nbr||';'||bi.charge_type||';'||
       bi.charge_code||';'||(bi.amount - bi.tax_amt)||';'||bi.tax_amt||';'||
       DECODE (bi.tax_type, 'TX1', 5, 0)||';'||bi.tax_type||';'||
       bi.service_receiver_type||';'||subscr.subscr_type||';'||TO_CHAR (cntrl.bill_from_date, 'YYYY/MM/DD')||';'||
       TO_CHAR (cntrl.bill_end_date, 'YYYY/MM/DD')||';'||TO_CHAR (bi.chrg_from_date, 'YYYY/MM/DD')||';'||TO_CHAR (bi.chrg_end_date, 'YYYY/MM/DD')||';'||LINK.elem6||';'||
       TO_CHAR (pkg.end_date, 'YYYY/MM/DD')||';'||
       CASE
          WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
               ) >= 0.5
             THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                           bi.chrg_from_date)
                          )
                  + 1
          ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
       END||';'||
       CASE
          WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                  bi.chrg_from_date
                                 )
                - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
               ) >= 0.5
             THEN   TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                           bi.chrg_from_date
                                          )
                          )
                  + 1
          ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                      bi.chrg_from_date
                                     )
                     )
       END||';'||
       decode(sign(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),1,(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),0)||';'||
       decode(sign(decode(sign(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),1,(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),0)),0,ROUND((bi.amount - bi.tax_amt),0),ROUND
          (  (bi.amount - bi.tax_amt)
           / CASE
                WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                      - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                               bi.chrg_from_date
                                              )
                              )
                     ) >= 0.5
                   THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                                 bi.chrg_from_date
                                                )
                                )
                        + 1
                ELSE ROUND (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           ,2)
             END
          ))||';'||
       ROUND(ROUND
          (  (bi.amount - bi.tax_amt)
           / CASE
                WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                      - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                               bi.chrg_from_date
                                              )
                              )
                     ) >= 0.5
                   THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                                 bi.chrg_from_date
                                                )
                                )
                        + 1
                ELSE ROUND (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           ,2)
             END
          )
           *        decode(sign(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),1,(  CASE
             WHEN (  MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date)
                   - TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC (MONTHS_BETWEEN (bi.chrg_end_date,
                                              bi.chrg_from_date
                                             )
                             )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (bi.chrg_end_date, bi.chrg_from_date))
          END
        - CASE
             WHEN (  MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                     bi.chrg_from_date
                                    )
                   - TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                        1),
                                            bi.chrg_from_date
                                           )
                           )
                  ) >= 0.5
                THEN   TRUNC
                            (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date,
                                                         1
                                                        ),
                                             bi.chrg_from_date
                                            )
                            )
                     + 1
             ELSE TRUNC (MONTHS_BETWEEN (ADD_MONTHS (cntrl.bill_end_date, 1),
                                         bi.chrg_from_date
                                        )
                        )
          END
       ),0),0)
  FROM fy_tb_bl_bill_bi bi,
       fy_tb_bl_acct_pkg pkg,
       fy_tb_bl_bill_mast mast,
       fy_tb_cm_subscr subscr,
       fy_tb_bl_bill_cntrl cntrl,
       (SELECT entity_id, elem6
          FROM fy_tb_cm_prof_link
         WHERE entity_type = 'A' AND link_type = 'A' AND prof_type = 'NAME'
                                                                           --and elem5=2
       ) LINK,
	   fy_tb_cm_customer cust
 WHERE bi.bill_seq = cntrl.bill_seq
   AND bi.bill_seq = mast.bill_seq
   AND bi.CYCLE = cntrl.CYCLE
   AND bi.CYCLE = mast.CYCLE
   AND bi.acct_id = mast.acct_id
   AND bi.acct_id = pkg.acct_id(+)
   AND bi.acct_id = subscr.acct_id
   AND bi.acct_id = LINK.entity_id
   AND bi.subscr_id = subscr.subscr_id
   AND bi.subscr_id = pkg.offer_level_id(+)
   AND bi.offer_id = pkg.offer_id(+)
   AND bi.offer_seq = pkg.offer_seq(+)
   AND cntrl.bill_period = ${sysd}
   AND cntrl.CYCLE IN (10, 15)
   AND subscr.cust_id = cust.cust_id
   AND cust.cust_type = 'P' --SR273784_APT
   --and bi.BILL_SEQ=150053
   AND bi.charge_org NOT IN ('IN', 'NN')
   AND NVL (bi.chrg_end_date, cntrl.bill_end_date) > cntrl.bill_end_date;

spool off

exit;

EOF`

echo "Gen Report4 End"|tee -a ${logFile}
}

# function ftpReport2
# {
# ftp -i -n -v $1<<EOF
# user $2 $3
# pass
# cd $4
# mput $5
# bye
# EOF
# }

function formatterReport
{
grep -v '^$' ${reportFileName}.dat > ${ReportDir}/${reportFileName}.csv
rm ${reportFileName}.dat
sleep 5
grep -v '^$' ${reportFileName2}.dat > ${ReportDir}/${reportFileName2}.csv
rm ${reportFileName2}.dat
}
grep -v '^$' ${reportFileName3}.dat > ${ReportDir}/${reportFileName3}.csv
rm ${reportFileName3}.dat
}
grep -v '^$' ${reportFileName4}.dat > ${ReportDir}/${reportFileName4}.csv
rm ${reportFileName4}.dat
}

function sendFinalMail
{
send_msg="<SR250171_HGB_ESDP_UNBILL_Report> $sysd"
	#iconv -f utf8 -t big5 -c ${reportFileName}.txt > ${reportFileName}.big5
	#mv ${reportFileName}.big5 ${reportFileName}.txt
	#rm ${reportFileName}.dat
mailx -s "${send_msg}" -a ${ReportDirBak}/${reportFileName}.csv ${mailList} <<EOF
Dears,

   SR250171_HGB_ESDP_UNBILL_Report已產出。
   檔名：
   ${reportFileName}.csv
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF

send_msg="<SR250171_HGB_ESDP_UNBILL2_Report> $sysd"
	#iconv -f utf8 -t big5 -c ${reportFileName}.txt > ${reportFileName}.big5
	#mv ${reportFileName}.big5 ${reportFileName}.txt
	#rm ${reportFileName}.dat
mailx -s "${send_msg}" -a ${ReportDirBak}/${reportFileName2}.csv ${mailList} <<EOF
Dears,

   SR250171_HGB_ESDP_UNBILL2_Report已產出。
   檔名：
   ${reportFileName2}.csv
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

send_msg="<SR250171_HGB_ESDP_UNBILL3_Report> $sysd"
	#iconv -f utf8 -t big5 -c ${reportFileName}.txt > ${reportFileName}.big5
	#mv ${reportFileName}.big5 ${reportFileName}.txt
	#rm ${reportFileName}.dat
mailx -s "${send_msg}" -a ${ReportDirBak}/${reportFileName3}.csv ${mailList} <<EOF
Dears,

   SR250171_HGB_ESDP_UNBILL3_Report已產出。
   檔名：
   ${reportFileName3}.csv
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

send_msg="<SR250171_HGB_ESDP_UNBILL4_Report> $sysd"
	#iconv -f utf8 -t big5 -c ${reportFileName}.txt > ${reportFileName}.big5
	#mv ${reportFileName}.big5 ${reportFileName}.txt
	#rm ${reportFileName}.dat
mailx -s "${send_msg}" -a ${ReportDirBak}/${reportFileName4}.csv ${mailList} <<EOF
Dears,

   SR250171_HGB_ESDP_UNBILL4_Report已產出。
   檔名：
   ${reportFileName4}.csv
   
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

function sendGenTempErrorMail
{
send_msg="<SR250171_HGB_ESDP_UNBILL_Report> $sysd"
mailx -s "${send_msg} Gen Data Have Abnormal " ${mailList} <<EOF
Dear All,
  
  SR250171_HGB_ESDP_UNBILL_Report未產出。
  
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF

send_msg="<SR250171_HGB_ESDP_UNBILL2_Report> $sysd"
mailx -s "${send_msg} Gen Data Have Abnormal " ${mailList} <<EOF
Dear All,
  
  SR250171_HGB_ESDP_UNBILL2_Report未產出。
  
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

send_msg="<SR250171_HGB_ESDP_UNBILL3_Report> $sysd"
mailx -s "${send_msg} Gen Data Have Abnormal " ${mailList} <<EOF
Dear All,
  
  SR250171_HGB_ESDP_UNBILL3_Report未產出。
  
(請注意：此郵件為系統自動傳送，請勿直接回覆！)
(Note: Please do not reply to messages sent automatically.)
EOF
}

send_msg="<SR250171_HGB_ESDP_UNBILL4_Report> $sysd"
mailx -s "${send_msg} Gen Data Have Abnormal " ${mailList} <<EOF
Dear All,
  
  SR250171_HGB_ESDP_UNBILL4_Report未產出。
  
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
echo "Gen ${reportFileName3} Start" | tee -a ${logFile}
genReport3
sleep 5
echo "Gen ${reportFileName4} Start" | tee -a ${logFile}
genReport4
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
	echo "Run Command: ${ftpProg} ${putip1} ${putuser1} ******** ${ReportDir} ${putpath1} ${reportFileName3}.csv 0" | tee -a ${logFile}
		${ftpProg} ${putip1} ${putuser1} ${putpass1} ${ReportDir} ${putpath1} ${reportFileName3}.csv 0
	echo "Run Command: ${ftpProg} ${putip1} ${putuser1} ******** ${ReportDir} ${putpath1} ${reportFileName4}.csv 0" | tee -a ${logFile}
		${ftpProg} ${putip1} ${putuser1} ${putpass1} ${ReportDir} ${putpath1} ${reportFileName4}.csv 0

		#cd ${ReportDir}
	#ftpReport2 ${putip1} ${putuser1} ${putpass1} ${putpath1} "${reportFileName}.txt"
		
	echo "send SR250171_HGB_ESDP_UNBILL_Report"|tee -a ${logFile}

	echo "Move Report TO Bak"|tee -a ${logFile}
	mv "${reportFileName}.csv" ${ReportDirBak}
	mv "${reportFileName2}.csv" ${ReportDirBak}
	mv "${reportFileName3}.csv" ${ReportDirBak}
	mv "${reportFileName4}.csv" ${ReportDirBak}
	#send final mail
	sendFinalMail
fi
sleep 5

echo "Gen ${reportFileName} End" | tee -a ${logFile}
echo "Gen ${reportFileName2} End" | tee -a ${logFile}
echo "Gen ${reportFileName3} End" | tee -a ${logFile}
echo "Gen ${reportFileName4} End" | tee -a ${logFile}
echo $sysdt|tee -a ${logFile}
