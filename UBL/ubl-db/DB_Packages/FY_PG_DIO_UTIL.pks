CREATE OR REPLACE PACKAGE HGBBLAPPO.Fy_Pg_Dio_Util IS

   -- Author  : USER
   -- Created : 2018/9/21 下午 04:38:16
   -- Purpose : 新增控制資料
   -- Version :
   --             1.0    2018/09/01 CREATE
   --             3.0    2020/06/30 MODIFY FOR MPBS_Migration 新增新安東京RC總額處理
   --             4.0    2021/06/15 MODIFY FOR 小額預繳處理 MARKET_PKG ADD參數PROC_TYPE,BILL_SEQ
      
   PROCEDURE Ins_Dio_Cntrl(Pi_Sys_Id     IN Fy_Tb_Dio_Cntrl.Sys_Id%TYPE DEFAULT 'UBL',
                           Pi_Proc_Id    IN Fy_Tb_Dio_Cntrl.Proc_Id%TYPE, -- CUTDATE, ACCTLIST, MAST, CONFIRM
                           Pi_Bill_Seq   IN Fy_Tb_Dio_Cntrl.Bill_Seq%TYPE,
                           Pi_Process_No IN Fy_Tb_Dio_Cntrl.Process_No%TYPE,
                           Pi_Proc_Type  IN Fy_Tb_Dio_Cntrl.Proc_Type%TYPE,
                           Pi_Acct_Group IN Fy_Tb_Dio_Cntrl.Acct_Group%TYPE,
                           Pi_Confirm_Id IN Fy_Tb_Dio_Cntrl.Confirm_Id%TYPE,
                           Pi_Io_Type    IN Fy_Tb_Dio_Cntrl.Io_Type%TYPE DEFAULT 'O',
                           Pi_User_Id    IN Fy_Tb_Dio_Cntrl.Create_User%TYPE,
                           Po_Err_Cde    OUT VARCHAR2,
                           Po_Err_Msg    OUT VARCHAR2);
													 
	 PROCEDURE Ins_Dio_MAST(Pi_Sys_Id     IN Fy_Tb_Dio_Cntrl.Sys_Id%TYPE DEFAULT 'UBL',
                           Pi_Proc_Id    IN Fy_Tb_Dio_Cntrl.Proc_Id%TYPE, -- ACCTLIST, MAST, CONFIRM
                           Pi_Bill_Seq   IN Fy_Tb_Dio_Cntrl.Bill_Seq%TYPE,
                        --   Pi_Process_No IN Fy_Tb_Dio_Cntrl.Process_No%TYPE,
                           Pi_Proc_Type  IN Fy_Tb_Dio_Cntrl.Proc_Type%TYPE,
                        --   Pi_Acct_Group IN Fy_Tb_Dio_Cntrl.Acct_Group%TYPE, -- when acct_group <> 0 then must be in acct_list.type
                        --   Pi_Confirm_Id IN Fy_Tb_Dio_Cntrl.Confirm_Id%TYPE,
                           Pi_Io_Type    IN Fy_Tb_Dio_Cntrl.Io_Type%TYPE DEFAULT 'O',
                           Pi_User_Id    IN Fy_Tb_Dio_Cntrl.Create_User%TYPE,
                           Po_Err_Cde    OUT VARCHAR2,
                           Po_Err_Msg    OUT VARCHAR2);       

END Fy_Pg_Dio_Util;
/