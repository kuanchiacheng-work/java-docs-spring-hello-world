--########################################################################################
--# Program name : HGB_MPBL_CutDate.sh
--# SQL name : HGB_MPBL_getCycleInfo.sql
--# Path : /extsoft/MPBL/BL/CutDate/bin
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

set heading off
set feedback off
set verify off
set pagesize 0

SELECT CYCLE, CURRECT_PERIOD
     FROM FY_TB_BL_CYCLE
    WHERE currect_period IS NOT NULL
    AND TO_DATE(CURRECT_PERIOD||FROM_DAY,'YYYYMMDD') =
        DECODE(SUBSTR('&1',-2),'01',ADD_MONTHS(TO_DATE('&1','YYYYMMDD'),-1),TO_DATE('&1','YYYYMMDD')) 
		and cycle = '&2'
		and create_user = 'MPBL'
    ;

exit
