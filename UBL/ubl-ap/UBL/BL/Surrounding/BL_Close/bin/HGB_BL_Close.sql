SET serveroutput ON SIZE 1000000
set verify off
declare 
   v_BILL_DATE       VARCHAR2(8)  := '&1'; 
   NU_CYCLE          NUMBER(2);
   CH_BILL_PERIOD    VARCHAR2(6);
   CH_USER           VARCHAR2(8)  :='UBL';
   nu_CTRL_CNT       number       :=0;
   NU_CNT            NUMBER;
   CH_ERR_CDE        VARCHAR2(10);
   CH_ERR_MSG        VARCHAR2(300);
   On_Err            EXCEPTION;
   CURSOR c1(iCYCLE NUMBER) IS
      select * 
        from fy_tb_bl_account 
       where cycle     = iCYCLE
         and bl_status<>'CLOSE'
         and LAST_BILL_SEQ is not null  --SUBSCRIBER.STATUS = ‘C’
         and add_months(eff_date,-6)< TRUNC(SYSDATE); --TO_DATE(V_BILL_DATE,'YYYYMMDD');  --< 6個月
begin
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||' BEGIN BA_CLOSE Process...'); 
   CH_ERR_MSG := 'GET CYCLE.BILL_DATE='||V_BILL_DATE||':';
   SELECT CYCLE, CURRECT_PERIOD
     INTO NU_CYCLE, CH_BILL_PERIOD
     FROM FY_TB_BL_CYCLE
    WHERE currect_period IS NOT NULL
      AND TO_DATE(CURRECT_PERIOD||FROM_DAY,'YYYYMMDD') =
          DECODE(SUBSTR(v_BILL_DATE,-2),'01',ADD_MONTHS(TO_DATE(v_BILL_DATE,'YYYYMMDD'),-1),TO_DATE(v_BILL_DATE,'YYYYMMDD'));
        
   for R1 in c1(NU_CYCLE) loop
      NU_CTRL_CNT := NU_CTRL_CNT+1;
      begin
         --CSM_PAY_CHANNEL.PCN_STATUS = ‘C’ & STATUS_DATE < 6個月
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
         
         --AR1_ACCOUNT.LAST_ACTIVITY_STATUS_DATE < 6個月 & AR_BALANCE <= 0
         CH_ERR_MSG := 'GET AR1_ACCOUNT.ACCT_ID='||TO_CHAR(R1.ACCT_ID)||':';
         select count(1) 
           into NU_CNT
           from ar1_account@HGB_UAR_REF
          where account_id = R1.ACCT_ID
            and (last_activity_status_date >= add_months(to_date(to_char(sysdate, 'yyyymm')||'01', 'yyyymmdd'), -6) OR
                 ar_balance > 0 ); 
         IF NU_CNT>0 THEN
            RAISE ON_ERR;
         END IF;  
         
         --CHEKC 有未出帳OC
         CH_ERR_MSG := 'GET FY_TB_BL_BILL_CI.ACCT_ID='||TO_CHAR(R1.ACCT_ID)||':';
         SELECT COUNT(1)
           INTO NU_CNT
           FROM FY_TB_BL_BILL_CI
          WHERE ACCT_ID =R1.ACCT_ID
            AND BILL_SEQ IS NULL;
         IF NU_CNT>0 THEN
            RAISE ON_ERR;
         END IF;               
      
         --最近一期出帳資料PREV_BALANCE_AMT <= 0 & TOTAL_AMT_DUE <= 0 & TOTAL_FINANCE_ACT = 0
         SELECT COUNT(1)
           INTO NU_CNT  
           FROM FY_TB_BL_BILL_MAST
          WHERE BILL_SEQ=R1.PRE_BILL_SEQ
            AND ACCT_ID =R1.ACCT_ID
            AND BILL_NBR=R1.PRE_BILL_NBR
            AND LAST_AMT<=0 
            AND TOT_AMT <=0
            AND PAID_AMT =0;
         IF NU_CNT>0 THEN   
            UPDATE FY_TB_BL_ACCOUNT SET  BL_STATUS  ='CLOSE',
                                         STATUS_DATE=SYSDATE,
                                         UPDATE_DATE=SYSDATE,
                                         UPDATE_USER='UBL'
                                   WHERE ACCT_ID=R1.ACCT_ID;     
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
   DBMS_OUTPUT.Put_Line('0000');    
EXCEPTION 
   WHEN OTHERS THEN
      DBMS_OUTPUT.Put_Line('Pre_CutDate Process RETURN_CODE = 9999');
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY/MM/DD-HH:MI:SS')||SUBSTR(' END BA_CLOSE Process... '||SQLERRM,1,250));         
end;
/
exit
