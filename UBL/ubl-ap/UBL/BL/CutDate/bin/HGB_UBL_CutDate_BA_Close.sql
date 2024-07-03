--########################################################################################
--# Program name : HGB_UBL_CutDate.sh
--# Path : /extsoft/UBL/BL/CutDate/bin
--# SQL name : HGB_BL_Close.sql
--#
--# Date : 2019/12/03 Created by Mike Kuan
--# Description : HGB UBL CutDate
--########################################################################################
--# Date : 2020/11/10 Created by Mike Kuan
--# Description : SR232859_修改IoTHGBN BA Close & NHGB Account Close的條件
--#               remove TOT_AMT<=0, add final bill status check, for HGBN&HGB both
--########################################################################################
--# Date : 2023/04/17 Modify by Mike Kuan
--# Description : SR260229_Project-M Fixed line Phase I_新增CUST_TYPE='P'
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off
declare 
   v_BILL_DATE       VARCHAR2(8)  := '&1'; 
   v_CYCLE           NUMBER(2)    := '&2'; 
   NU_CYCLE          NUMBER(2);
   CH_BILL_PERIOD    VARCHAR2(6);
   CH_USER           VARCHAR2(8)  := 'UBL';
   nu_CTRL_CNT       number       :=0;
   NU_CNT            NUMBER;
   CH_ERR_CDE        VARCHAR2(10);
   CH_ERR_MSG        VARCHAR2(300);
   On_Err            EXCEPTION;
   CURSOR c1(iCYCLE NUMBER) IS
	SELECT acct_id, pre_bill_seq, pre_bill_nbr
	  FROM fy_tb_bl_account ba, fy_tb_cm_customer cc
	 WHERE ba.cust_id = cc.cust_id
	  AND ba.CYCLE = icycle
	  AND ba.bl_status <> 'CLOSE'
	  AND ba.last_bill_seq IS NOT NULL
	  AND ADD_MONTHS (ba.eff_date, -6) < TRUNC (SYSDATE)
	  AND cc.cust_type IN ('N', 'D', 'P'); --SR260229_Project-M Fixed line Phase I_新增CUST_TYPE='P'
begin
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN BA_CLOSE Process...'); 
   CH_ERR_MSG := 'GET CYCLE.BILL_DATE='||V_BILL_DATE||':';
   SELECT CYCLE, CURRECT_PERIOD
     INTO NU_CYCLE, CH_BILL_PERIOD
     FROM FY_TB_BL_CYCLE
    WHERE currect_period IS NOT NULL
      AND cycle = v_CYCLE
	  AND CREATE_USER = CH_USER
      AND TO_DATE(CURRECT_PERIOD||FROM_DAY,'YYYYMMDD') =
          DECODE(SUBSTR(v_BILL_DATE,-2),'01',ADD_MONTHS(TO_DATE(v_BILL_DATE,'YYYYMMDD'),-1),TO_DATE(v_BILL_DATE,'YYYYMMDD'));
        
   for R1 in c1(NU_CYCLE) loop
      NU_CTRL_CNT := NU_CTRL_CNT+1;
      begin
         CH_ERR_MSG := 'GET FY_TB_CM_ACCOUNT.ACCT_ID='||TO_CHAR(R1.ACCT_ID)||':';
         SELECT COUNT(1)
           INTO NU_CNT
           FROM FY_TB_CM_ACCOUNT
          where ACCT_ID = R1.ACCT_ID
            AND STATUS='C'
            AND EFF_DATE<add_months(to_date(to_char(sysdate, 'yyyymm')||'01', 'yyyymmdd'), -6);
         IF NU_CNT=0 THEN
            RAISE ON_ERR;
         END IF;   

         CH_ERR_MSG := 'GET FY_TB_BL_BILL_CI.ACCT_ID='||TO_CHAR(R1.ACCT_ID)||':';
         SELECT COUNT(1)
           INTO NU_CNT
           FROM FY_TB_BL_BILL_CI
          WHERE ACCT_ID =R1.ACCT_ID
            AND BILL_SEQ IS NULL;
         IF NU_CNT>0 THEN
            RAISE ON_ERR;
         END IF;               
      
         SELECT COUNT(1)
           INTO NU_CNT  
           FROM FY_TB_BL_BILL_MAST a, FY_TB_BL_BILL_ACCT b
          WHERE a.BILL_SEQ=R1.PRE_BILL_SEQ
		    AND a.BILL_SEQ=b.BILL_SEQ
            AND a.ACCT_ID =R1.ACCT_ID
			and a.ACCT_ID=b.ACCT_ID
            AND a.BILL_NBR=R1.PRE_BILL_NBR
			AND b.PRODUCTION_TYPE in ('FN','RF')
            AND CHRG_AMT<=0;
         IF NU_CNT>0 THEN   
            UPDATE FY_TB_BL_ACCOUNT SET  BL_STATUS  ='CLOSE',
                                         STATUS_DATE=SYSDATE,
                                         UPDATE_DATE=SYSDATE,
                                         UPDATE_USER='UBL'
                                   WHERE ACCT_ID=R1.ACCT_ID;
			DBMS_OUTPUT.Put_Line('CLOSE ACCOUNT='|| R1.ACCT_ID);
         END IF;
      EXCEPTION
         WHEN ON_ERR THEN
            NULL;
         WHEN OTHERS THEN
            NULL;
      END;
   END LOOP;  
   COMMIT;
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' END BA_CLOSE Process...');  
   DBMS_OUTPUT.Put_Line('CutDate_BA_Close Process RETURN_CODE = 0000');    
EXCEPTION 
   WHEN OTHERS THEN
      DBMS_OUTPUT.Put_Line('CutDate_BA_Close Process RETURN_CODE = 9999');
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||SUBSTR(' END BA_CLOSE Process... '||SQLERRM,1,250));         
end;
/
exit
