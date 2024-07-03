SET serveroutput ON SIZE 1000000
set verify off
declare 
v_BILL_DATE       VARCHAR2(8)      := '&1'; 
NU_CYCLE          NUMBER(2);
CH_BILL_PERIOD    VARCHAR2(6);
NU_CYCLE_MONTH    NUMBER(2);
NU_BILL_SEQ       NUMBER;
NU_CNT            NUMBER;
CH_USER           VARCHAR2(8)  :='UBL';
CH_ERR_CDE        VARCHAR2(10);
CH_ERR_MSG        VARCHAR2(300);

  CURSOR C_CT(iBILL_SEQ NUMBER) IS
     SELECT DISTINCT TYPE
       FROM FY_TB_BL_ACCT_LIST
      WHERE BILL_SEQ=iBILL_SEQ;
       
  CURSOR C1(iBILL_SEQ NUMBER, iTYPE VARCHAR2) IS
     SELECT A.ACCT_ID, A.BILL_START_PERIOD, A.BILL_END_PERIOD, A.BILL_END_DATE, A.TYPE, A.UC_FLAG,
            B.CUST_ID, B.ACCT_GROUP
       FROM FY_TB_BL_ACCT_LIST A,
            FY_TB_BL_BILL_ACCT B
      WHERE A.BILL_SEQ=iBILL_SEQ
        AND A.TYPE    =iTYPE
        AND B.BILL_SEQ=A.BILL_SEQ
        AND B.ACCT_ID =A.ACCT_ID
        AND ((B.ACCT_GROUP='MV') OR 
             (EXISTS (SELECT 1 FROM FY_TB_BL_BILL_ACCT BA
                              WHERE BILL_SEQ=B.BILL_SEQ
                                AND CUST_ID =B.CUST_ID
                                AND NOT EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                                        WHERE BILL_SEQ=BA.BILL_SEQ
                                                          AND ACCT_ID =BA.ACCT_ID
                                                          AND TYPE    =iTYPE))
              ));
begin
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':Insert Multiple Account BEGIN'); 
   SELECT CYCLE, BILL_PERIOD, BILL_SEQ, CYCLE_MONTH
     INTO NU_CYCLE, CH_BILL_PERIOD, NU_BILL_SEQ, NU_CYCLE_MONTH
     FROM FY_TB_BL_BILL_CNTRL
    WHERE TO_CHAR(BILL_DATE,'YYYYMMDD')=v_BILL_DATE; 
   --LOOP
   FOR R_CT IN C_CT(NU_BILL_SEQ) LOOP        
      FOR R1 IN C1(NU_BILL_SEQ, R_CT.TYPE) LOOP
         IF R1.ACCT_GROUP='MV' THEN
            --INSERT 
            INSERT INTO FY_TB_BL_ACCT_LIST
                          (BILL_SEQ,
                           CYCLE,
                           CYCLE_MONTH,
                           ACCT_ID,
                           BILL_START_PERIOD,
                           BILL_END_PERIOD,
                           BILL_END_DATE,
                           TYPE,
                           HOLD_DESC,
                           UC_FLAG,
                           cust_id,
                           CREATE_DATE,
                           CREATE_USER,
                           UPDATE_DATE,
                           UPDATE_USER)        
                    SELECT NU_BILL_SEQ,
                           NU_CYCLE,
                           NU_CYCLE_MONTH,
                           ACCT_ID,
                           R1.BILL_START_PERIOD,
                           R1.BILL_END_PERIOD,
                           R1.BILL_END_DATE,
                           R1.TYPE,
                           'MUTIL_ACCT', --HOLD_DESC,
                           R1.UC_FLAG,
                           r1.cust_id,
                           SYSDATE,
                           CH_USER,
                           SYSDATE,
                           CH_USER
                      FROM (select BILL_SEQ,ACCT_ID from (select BILL_SEQ, ACCT_ID,PRE_ACCT_ID 
                                                            from FY_TB_BL_BILL_MV_SUB 
                                                           where bill_seq   =NU_BILL_SEQ
                                                             AND CYCLE      =NU_CYCLE
                                                             AND CYCLE_MONTH=NU_CYCLE_MONTH) 
                                 start WITH acct_id=R1.ACCT_ID
                               CONNECT BY PRIOR acct_ID=pre_acct_id
                            UNION
                            select BILL_SEQ,acct_id from (select BILL_SEQ, ACCT_ID,PRE_ACCT_ID 
                                                            from FY_TB_BL_BILL_MV_SUB 
                                                           where bill_seq   =NU_BILL_SEQ
                                                             AND CYCLE      =NU_CYCLE
                                                             AND CYCLE_MONTH=NU_CYCLE_MONTH) 
                                 start WITH acct_id=R1.ACCT_ID
                               CONNECT BY PRIOR PRE_acct_ID=acct_id) MV
                     WHERE NOT EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                               WHERE BILL_SEQ=MV.BILL_SEQ
                                                 AND ACCT_ID =MV.ACCT_ID
                                                 AND TYPE    =R_CT.TYPE);  
            NU_CNT := NVL(NU_CNT,0)+SQL%ROWCOUNT;                                     
         END IF; ---MV
         INSERT INTO FY_TB_BL_ACCT_LIST
                          (BILL_SEQ,
                           CYCLE,
                           CYCLE_MONTH,
                           ACCT_ID,
                           BILL_START_PERIOD,
                           BILL_END_PERIOD,
                           BILL_END_DATE,
                           TYPE,
                           HOLD_DESC,
                           UC_FLAG,
                           cust_id,
                           CREATE_DATE,
                           CREATE_USER,
                           UPDATE_DATE,
                           UPDATE_USER)        
                    SELECT NU_BILL_SEQ,
                           NU_CYCLE,
                           NU_CYCLE_MONTH,
                           ACCT_ID,
                           R1.BILL_START_PERIOD,
                           R1.BILL_END_PERIOD,
                           R1.BILL_END_DATE,
                           R1.TYPE,
                           'MUTIL_ACCT', --HOLD_DESC,
                           R1.UC_FLAG,
                           r1.cust_id,
                           SYSDATE,
                           CH_USER,
                           SYSDATE,
                           CH_USER
                      FROM FY_TB_BL_BILL_ACCT BA
                     WHERE BILL_SEQ    =NU_BILL_SEQ
                       AND CYCLE       =NU_CYCLE
                       AND CYCLE_MONTH =NU_CYCLE_MONTH
                       AND CUST_ID     =R1.CUST_ID
                       AND BILL_STATUS<>'CN'
                       AND NOT EXISTS (SELECT 1 FROM FY_TB_BL_ACCT_LIST
                                               WHERE BILL_SEQ=BA.BILL_SEQ
                                                 AND ACCT_ID =BA.ACCT_ID
                                                 AND TYPE    =R_CT.TYPE);  
         NU_CNT := NVL(NU_CNT,0)+SQL%ROWCOUNT;                                                                                              
      END LOOP;
   END LOOP;   
   commit;
   DBMS_OUTPUT.Put_Line('CNT='||TO_CHAR(NU_CNT));
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH:MI:SS')||':Insert Multiple Account END');
EXCEPTION 
   WHEN OTHERS THEN
   DBMS_OUTPUT.Put_Line('Insert Multiple Account RETURN_CODE = 9999');    
end;
/  
