--########################################################################################
--# Program name : HGB_UBL_CutDate.sh
--# SQL name : HGB_UBL_getCycleInfo.sql
--# Path : /extsoft/UBL/BL/CutDate/bin
--#
--# Date : 2018/09/06 Created by FY
--# Description : HGB UBL CutDate
--########################################################################################
--# Date : 2019/06/30 Modify by Mike Kuan
--# Description : SR213344_NPEP add cycle parameter
--########################################################################################
--# Date : 2021/02/20 Modify by Mike Kuan
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
		and create_user = 'UBL'
    ;

exit
