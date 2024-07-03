SET serveroutput ON SIZE 1000000
set verify off
declare 
v_BILL_DATE                  VARCHAR2(8)  := '&1'; 
NU_CYCLE          NUMBER(2);
CH_BILL_PERIOD    VARCHAR2(6);
NU_CYCLE_MONTH    NUMBER(2);
NU_BILL_SEQ       NUMBER;
DT_BILL_END_DATE DATE;
CH_USER           VARCHAR2(8)  :='UBL';
CH_ERR_CDE        VARCHAR2(10);
CH_ERR_MSG        VARCHAR2(300);
begin
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':GET ERP BEGIN'); 
   SELECT CYCLE, BILL_PERIOD, BILL_SEQ, CYCLE_MONTH, BILL_END_DATE
     INTO NU_CYCLE, CH_BILL_PERIOD, NU_BILL_SEQ, NU_CYCLE_MONTH, DT_BILL_END_DATE
     FROM FY_TB_BL_BILL_CNTRL
    WHERE TO_CHAR(BILL_DATE,'YYYYMMDD')=V_BILL_DATE;   
   --DT_BILL_END_DATE CHECK
   IF TO_NUMBER(TO_CHAR(DT_BILL_END_DATE,'DD'))>25 THEN
      DT_BILL_END_DATE := TO_DATE(TO_CHAR(DT_BILL_END_DATE,'YYYYMM')||'25','YYYYMMDD');
   ELSE
      DT_BILL_END_DATE := TO_DATE(TO_CHAR(ADD_MONTHS(DT_BILL_END_DATE,-1),'YYYYMM')||'25','YYYYMMDD');
   END IF;             
   --GET ERP 
   --gvSTEP := 'INSERT BL_BILL_RATES:';
   INSERT INTO FY_TB_BL_BILL_RATES
                       (BILL_SEQ,
                        CYCLE,
                        CYCLE_MONTH,
                        FROM_CURRENCY,
                        TO_CURRENCY,
                        CONVERSION_DATE,
                        CONVERSION_TYPE,
                        CONVERSION_RATE,
                        CREATE_DATE,
                        CREATE_USER,
                        UPDATE_DATE,
                        UPDATE_USER)
                 SELECT NU_BILL_SEQ,
                        NU_CYCLE,
                        NU_CYCLE_MONTH,
                        decode(FROM_CURRENCY,'TWD','NTD',FROM_CURRENCY),
                        decode(TO_CURRENCY,'TWD','NTD',TO_CURRENCY),
                        CONVERSION_DATE,
                        CONVERSION_TYPE,
                        CONVERSION_RATE,
                        SYSDATE,
                        CH_USER,
                        SYSDATE,
                        CH_USER
                   FROM APPS.ERP_PO_DAILY_RATES_V@HGB2ERP.ERP
                  where TRUNC(CONVERSION_DATE)=DT_BILL_END_DATE ;
   IF SQL%ROWCOUNT=0 THEN
      DBMS_OUTPUT.Put_Line('Get ERP RETURN_CODE = 9999'); 
   ELSE   
      DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':GET ERP END'); 
      DBMS_OUTPUT.Put_Line('Get ERP RETURN_CODE = 0000'||NULL); 
	  COMMIT;
   END IF;   
EXCEPTION 
   WHEN OTHERS THEN
       DBMS_OUTPUT.Put_Line('Get ERP RETURN_CODE = 9999'); 
end;
/   
    