--########################################################################################
--# Program name : HGB_MPBL_CutDate_RollBack.sh
--# SQL name : HGB_MPBL_CutDate_RollBack_getCycleInfo.sql
--# Path : /extsoft/MPBL/BL/CutDate/bin
--#
--# Date : 2021/02/20 Created by Mike Kuan
--# Description : SR222460_MPBS migrate to HGB
--########################################################################################

set heading off
set feedback off
set verify off
set pagesize 0

select to_char(bill_date,'yyyymmdd') billdate,cycle from fy_tb_Bl_bill_cntrl where bill_seq='&1';

exit
