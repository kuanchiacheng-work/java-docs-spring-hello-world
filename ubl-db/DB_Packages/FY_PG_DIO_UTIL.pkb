CREATE OR REPLACE PACKAGE BODY HGBBLAPPO.Fy_Pg_Dio_Util IS

   PROCEDURE Ins_Dio_Cntrl(Pi_Sys_Id     IN Fy_Tb_Dio_Cntrl.Sys_Id%TYPE DEFAULT 'UBL',
                           Pi_Proc_Id    IN Fy_Tb_Dio_Cntrl.Proc_Id%TYPE, -- ACCTLIST, MAST, CONFIRM
                           Pi_Bill_Seq   IN Fy_Tb_Dio_Cntrl.Bill_Seq%TYPE,
                           Pi_Process_No IN Fy_Tb_Dio_Cntrl.Process_No%TYPE,
                           Pi_Proc_Type  IN Fy_Tb_Dio_Cntrl.Proc_Type%TYPE,
                           Pi_Acct_Group IN Fy_Tb_Dio_Cntrl.Acct_Group%TYPE, -- when acct_group <> 0 then must be in acct_list.type                           
                           Pi_Confirm_Id IN Fy_Tb_Dio_Cntrl.Confirm_Id%TYPE,
                           Pi_Io_Type    IN Fy_Tb_Dio_Cntrl.Io_Type%TYPE DEFAULT 'O',
                           Pi_User_Id    IN Fy_Tb_Dio_Cntrl.Create_User%TYPE,
                           Po_Err_Cde    OUT VARCHAR2,
                           Po_Err_Msg    OUT VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err EXCEPTION;
      Nu_Cntrl_Seq Fy_Tb_Dio_Cntrl.Cntrl_Seq%TYPE;
      CURSOR c_Conf IS
         SELECT Dtl.Conf_Dtl_Seq
           FROM Fy_Tb_Dio_Conf Conf, Fy_Tb_Dio_Conf_Dtl Dtl
          WHERE Conf.Conf_Seq = Dtl.Conf_Seq
            AND Conf.Sys_Id = Pi_Sys_Id
            AND Conf.Proc_Id = Pi_Proc_Id
            AND Dtl.SYS_USING ='Y'
          ORDER BY Dtl.Conf_Dtl_Seq;
      r_Conf c_Conf%ROWTYPE;
      
      NU_DATE     NUMBER;
   BEGIN
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
      IF Pi_Proc_Id IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入作業代碼';
         RAISE On_Err;
      END IF;
      IF Pi_Proc_Id NOT IN ('CUTDATE', 'ACCTLIST', 'MPACCTLIST', 'MAST', 'CONFIRM', 'MPCONFIRM') THEN --2020/06/30 MODIFY FOR MPBS_Migration 新增新安東京RC總額處理
         Po_Err_Cde := '4002';
         Po_Err_Msg := '輸入作業代碼錯誤,須為 CUTDATE:產生出帳帳號清單, ACCTLIST:重新產生出帳帳號清單, MAST:資料匯出, CONFIRM:產生立帳資料';
         RAISE On_Err;
      END IF;
      IF Pi_Bill_Seq IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入出帳編號';
         RAISE On_Err;
      END IF;
      IF Pi_Proc_Id = 'CONFIRM' AND Pi_Confirm_Id IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入帳單確認編號';
         RAISE On_Err;
      END IF;
      IF Pi_User_Id IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入執行人員代碼';
         RAISE On_Err;
      END IF;
      NU_DATE := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS'));
      
      OPEN c_Conf;
      LOOP
         FETCH c_Conf
            INTO r_Conf;
         EXIT WHEN c_Conf%NOTFOUND;
         SELECT Fy_Sq_Dio_Cntrl.Nextval INTO Nu_Cntrl_Seq FROM Dual;
         INSERT INTO Fy_Tb_Dio_Cntrl
            (Cntrl_Seq,
             Sys_Id,
             Proc_Id,
             Bill_Seq,
             Confirm_Id,
             Proc_Type,
             Acct_Group,
             Process_No,
             Io_Type,
             Status,
             Conf_Dtl_Seq,
             Create_Date,
             Create_User,
             Update_Date,
             Update_User)
         VALUES
            (Nu_Cntrl_Seq,
             Pi_Sys_Id,
             Pi_Proc_Id,
             Pi_Bill_Seq,
             NU_DATE, --Pi_Confirm_Id,
             Pi_Proc_Type,
             Pi_Acct_Group,
             Pi_Process_No,
             Pi_Io_Type,
             'A',
             r_Conf.Conf_Dtl_Seq,
             SYSDATE,
             Pi_User_Id,
             SYSDATE,
             Pi_User_Id);
      END LOOP;
      CLOSE c_Conf;
      COMMIT;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '4999';
         Po_Err_Msg := Substr('Call Fy_Pg_Bl_Bill_Util.Ins_Dio_Cntrl error:' || SQLERRM, 1, 250);
   END Ins_Dio_Cntrl;
	 
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
                           Po_Err_Msg    OUT VARCHAR2) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err EXCEPTION;
      Nu_Cntrl_Seq Fy_Tb_Dio_Cntrl.Cntrl_Seq%TYPE;
      CURSOR C1 IS
      SELECT A.BILL_SEQ, B.PROCESS_NO, B.Proc_Type, B.ACCT_GROUP
        FROM FY_TB_BL_BILL_CNTRL A,
             FY_TB_BL_BILL_PROCESS_LOG B
       WHERE A.BILL_SEQ    =PI_BILL_SEQ
         AND B.BILL_SEQ    =A.BILL_SEQ
         AND B.PROC_TYPE   =Pi_Proc_Type
         AND B.STATUS      ='MAST'
		 AND B.ACCT_GROUP != 'KEEP' --2020/06/30 MODIFY FOR MPBS_Migration -KEEP GROUP不EXTRACT
         AND NOT EXISTS (SELECT 1 FROM FY_TB_BL_BILL_PROCESS_LOG
                             WHERE BILL_SEQ  =B.BILL_SEQ
                               AND PROCESS_NO=B.PROCESS_NO
                               AND ACCT_GROUP=B.ACCT_GROUP
							   AND ACCT_GROUP != 'KEEP' --2020/06/30 MODIFY FOR MPBS_Migration -KEEP GROUP不EXTRACT
                               AND PROC_TYPE =B.PROC_TYPE
                               AND STATUS    ='CN');
      CURSOR c_Conf IS
         SELECT Dtl.Conf_Dtl_Seq
           FROM Fy_Tb_Dio_Conf Conf, Fy_Tb_Dio_Conf_Dtl Dtl
          WHERE Conf.Conf_Seq = Dtl.Conf_Seq
            AND Conf.Sys_Id = Pi_Sys_Id
            AND Conf.Proc_Id = Pi_Proc_Id
            AND Dtl.SYS_USING ='Y'
          ORDER BY Dtl.Conf_Dtl_Seq;
      r_Conf c_Conf%ROWTYPE;
      R1 C1%ROWTYPE;
      NU_DATE     NUMBER;
   BEGIN
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
      IF Pi_Proc_Id IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入作業代碼';
         RAISE On_Err;
      END IF;
      IF Pi_Bill_Seq IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入出帳編號';
         RAISE On_Err;
      END IF;
      IF Pi_User_Id IS NULL THEN
         Po_Err_Cde := '4001';
         Po_Err_Msg := '需輸入執行人員代碼';
         RAISE On_Err;
      END IF;
      NU_DATE := TO_NUMBER(TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS'));
      
			--FOR R1 IN C1 LOOP
      OPEN C1;
          LOOP
             FETCH C1
                INTO R1;
             EXIT WHEN C1%NOTFOUND;
          OPEN c_Conf;
          LOOP
             FETCH c_Conf
                INTO r_Conf;
             EXIT WHEN c_Conf%NOTFOUND;
             SELECT Fy_Sq_Dio_Cntrl.Nextval INTO Nu_Cntrl_Seq FROM Dual;
             INSERT INTO Fy_Tb_Dio_Cntrl
                (Cntrl_Seq,
                 Sys_Id,
                 Proc_Id,
                 Bill_Seq,
                 Confirm_Id,
                 Proc_Type,
                 Acct_Group,
                 Process_No,
                 Io_Type,
                 Status,
                 Conf_Dtl_Seq,
                 Create_Date,
                 Create_User,
                 Update_Date,
                 Update_User)
             VALUES
                (Nu_Cntrl_Seq,
                 Pi_Sys_Id,
                 Pi_Proc_Id,
                 Pi_Bill_Seq,
                 NU_DATE, --Pi_Confirm_Id,
                 Pi_Proc_Type,
                 R1.ACCT_GROUP,--Pi_Acct_Group,
                 R1.PROCESS_NO,--Pi_Process_No,
                 Pi_Io_Type,
                 'A',
                 r_Conf.Conf_Dtl_Seq,
                 SYSDATE,
                 Pi_User_Id,
                 SYSDATE,
                 Pi_User_Id);
          END LOOP;
          CLOSE c_Conf;
		  --4.0    2021/06/15 MODIFY FOR 小額預繳處理 MARKET_PKG ADD參數PROC_TYPE,BILL_SEQ sleep 2 minutes between insert into dio_cntrl different acct agroups
          COMMIT;
          sys.dbms_session.sleep(180);			 
      END LOOP;    
      CLOSE C1;
      COMMIT;
   EXCEPTION
      WHEN On_Err THEN
         NULL;
      WHEN OTHERS THEN
         Po_Err_Cde := '5999';
         Po_Err_Msg := Substr('Call Fy_Pg_Bl_Bill_Util.Ins_Dio_MAST error:' || SQLERRM, 1, 250);
   END Ins_Dio_MAST;

END Fy_Pg_Dio_Util;
/