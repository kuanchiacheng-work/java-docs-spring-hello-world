--########################################################################################
--# Program name : HGB_UBL_Confirm.sh
--# Path : /extsoft/UBL/BL/Confirm/bin
--# SQL name : HGB_UBL_Confirm_USED_UP.sql
--#
--# Date : 2019/06/30 Modify by Mike Kuan
--# Description : SR213344_NPEP add cycle parameter
--########################################################################################
--# Date : 2019/11/07 Modify by Mike Kuan
--# Description : SR219716_IoT預繳折扣需求，另寫入FY_TB_CM_SYNC_SEND_CNTRL需區分CUST_TYPE
--########################################################################################
--# Date : 2020/04/14 Modify by Mike Kuan
--# Description : SR219716_IoT預繳折扣需求，update CM9_OFFER_EXPIRATION_HOM
--########################################################################################

SET serveroutput ON SIZE 1000000
set verify off

declare 
v_BILL_DATE       VARCHAR2(8)  := '&1'; 
v_PROCESS_NO      NUMBER(3)    := '&2'; 
v_CYCLE           NUMBER(2)    := '&3'; 
NU_CYCLE          NUMBER(2);
CH_BILL_PERIOD    VARCHAR2(6);
NU_CYCLE_MONTH    NUMBER(2);
NU_BILL_SEQ       NUMBER;
CH_ACCT_GROUP     FY_TB_BL_CYCLE_PROCESS.ACCT_GROUP%TYPE;
CH_USER           VARCHAR2(8)  :='UBL';
ch_remark         FY_TB_SYS_SYNC_CNTRL.CONTENT%type;
nu_seq            number;
CH_ERR_CDE        VARCHAR2(10);
CH_ERR_MSG        VARCHAR2(300);
On_Err            EXCEPTION;
cursor c1(ibill_seq number, icycle number, icycle_month number, iacct_group varchar2) is
   select b.acct_id,  
          b.eff_date,
          b.end_date,          
          b.offer_id,
          b.offer_instance_id,
          b.offer_level_id subscr_id,
          b.cust_id,
          c.CUST_TYPE
     from fy_tb_bl_acct_pkg_log a,
          fy_tb_bl_acct_pkg b,
          fy_tb_bl_bill_acct al,
          FY_TB_CM_CUSTOMER c
    where a.bill_seq   =ibill_seq
     -- and a.cycle      =icycle
     -- and a.cycle_month=icycle_month
      and a.RECUR_SEQ  =a.bill_seq
      and a.pkg_type_dtl in ('BDX','BDN')
      and a.PREPAYMENT is not null
	  and a.CUST_ID = c.CUST_ID
      and b.acct_pkg_seq=a.acct_pkg_seq
      AND B.ACCT_KEY    =MOD(A.ACCT_ID,100) 
      and b.end_date is null
      and b.status      ='CLOSE'
      and al.bill_seq   =a.bill_seq
      AND AL.cycle     =icycle
      and AL.cycle_month=icycle_month    
      AND AL.ACCT_KEY   =MOD(A.ACCT_ID,100)  
      and al.acct_id    =a.acct_id
      and al.bill_status='CN'
      and nvl(al.CONFIRM_ID,0)<>999
      and ((v_PROCESS_NO<>999 and al.acct_group=Iacct_group) or
           (v_PROCESS_NO=999 and exists  (select 1 from fy_tb_bl_acct_list
                                          where bill_seq=a.bill_seq and type=Iacct_group and acct_id=a.acct_id)
          ));
begin
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS')||':CONFIRM USED_UP BEGIN');
   CH_ERR_MSG := 'GET BILL_CNTRL:';
   SELECT A.CYCLE, A.BILL_PERIOD, A.BILL_SEQ, A.CYCLE_MONTH, B.ACCT_GROUP
     INTO NU_CYCLE, CH_BILL_PERIOD, NU_BILL_SEQ, NU_CYCLE_MONTH, CH_ACCT_GROUP
     FROM FY_TB_BL_BILL_CNTRL A,
          FY_TB_BL_CYCLE_PROCESS B
    WHERE TO_CHAR(A.BILL_DATE,'YYYYMMDD')=v_BILL_DATE
	  and b.cycle=v_CYCLE
      AND B.CYCLE     =A.CYCLE
	  AND A.CREATE_USER = CH_USER
      AND B.PROCESS_NO=v_PROCESS_NO;
   IF v_PROCESS_NO=999 THEN 
      SELECT MAX(ACCT_GROUP) 
        INTO CH_ACCT_GROUP
        FROM FY_TB_BL_BILL_PROCESS_LOG A
       WHERE BILL_SEQ   =NU_BILL_SEQ
         AND PROCESS_NO =v_PROCESS_NO
         AND ACCT_GROUP LIKE 'CONF%'
         AND PROC_TYPE  ='B'
         AND STATUS     ='CN';
   END IF;         
   DBMS_OUTPUT.Put_Line('CH_ACCT_GROUP - '||CH_ACCT_GROUP);
   FOR r1 IN c1(nu_bill_seq, nu_cycle, nu_cycle_month, ch_acct_group) LOOP 
   DBMS_OUTPUT.Put_Line('r1.subscr_id - '||r1.subscr_id);
   DBMS_OUTPUT.Put_Line('r1.acct_id - '||r1.acct_id);
   DBMS_OUTPUT.Put_Line('r1.offer_id - '||r1.offer_id);
   DBMS_OUTPUT.Put_Line('r1.offer_instance_id - '||r1.offer_instance_id);
   
   IF R1.CUST_TYPE='D' THEN
      CH_REMARK := '<?xml version="1.0" encoding="UTF-8" ?>'||
          '<TRB_TRX xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'||
              '<HEADER ReqNotf="N" TransactionCode="CM9_OFFER_EXPIRATION" PublisherApplID="CM" PublisherApplThreadID="1" IssueDate="'||to_char(r1.eff_date,'yyyy-mm-dd')||'T'||to_char(r1.eff_date,'hh24:mi:ss')|| --2017-12-19T23:59:59
                 '" EffectiveDate="'||to_char(r1.eff_date,'yyyy-mm-dd')||'T'||to_char(r1.eff_date,'hh24:mi:ss')|| --2017-12-19T23:59:59
                 '" RoutingId="'||to_char(r1.subscr_id)|| --345601122
                 '" DistributionType="ALL" BulkTransaction="N" EntityId="'||to_char(r1.subscr_id)|| --345601122
                 '" EntityType="SUBSCRIBER"/>'||
              '<DATA>'||
                  '<CmHeaderTransaction>'||
                      '<TransactionRsn>CREQ</TransactionRsn>'||
                      '<TransactionId>'||to_char(r1.acct_id)||'</TransactionId>'||
                      '<ActivityPath>CM9_OFFER_EXPIRATION</ActivityPath>'||
                      '<ActivityPcn xsi:nil="true"/>'||
                      '<WaiveIndicator xsi:nil="true"/>'||
                      '<WaiveReason xsi:nil="true"/>'||
                      '<ActivityGroupId xsi:nil="true"/>'||
                      '<LoadInd></LoadInd>'||
                  '</CmHeaderTransaction>'||
                  '<OfferExpirationInfo>'||
                      '<SubscriberID>'||to_char(r1.subscr_id)||'</SubscriberID>'||
                      '<OfferID>'||to_char(r1.offer_id)||'</OfferID>'||
                      '<ExpirationDate>'||to_char(sysdate,'yyyy-mm-dd')||'T'||to_char(sysdate,'hh24:mi:ss')||'</ExpirationDate>'||
                      '<OfferInstanceId>'||to_char(r1.offer_instance_id)||'</OfferInstanceId>'||
                      '<AgreementID>'||to_char(r1.subscr_id)||'</AgreementID>'||
                      '<OfferLevel>S</OfferLevel>'||
                      '<PaymentCategory>POST</PaymentCategory>'||
                      '<MessageType>Discount Expiration</MessageType>'||
                      '<MessageId>DISC_EXP_001</MessageId>'||
                      '<Entity_Name>FET Bill Discount Expiration</Entity_Name>'||
                  '</OfferExpirationInfo>'||
              '</DATA>'||
          '</TRB_TRX>';
	ELSE
      CH_REMARK := '<?xml version="1.0" encoding="UTF-8" ?>'||
          '<TRB_TRX xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'||
              '<HEADER ReqNotf="N" TransactionCode="CM9_OFFER_EXPIRATION_HOM" PublisherApplID="CM" PublisherApplThreadID="1" IssueDate="'||to_char(r1.eff_date,'yyyy-mm-dd')||'T'||to_char(r1.eff_date,'hh24:mi:ss')|| --2017-12-19T23:59:59
                 '" EffectiveDate="'||to_char(r1.eff_date,'yyyy-mm-dd')||'T'||to_char(r1.eff_date,'hh24:mi:ss')|| --2017-12-19T23:59:59
                 '" RoutingId="'||to_char(r1.subscr_id)|| --345601122
                 '" DistributionType="ALL" BulkTransaction="N" EntityId="'||to_char(r1.subscr_id)|| --345601122
                 '" EntityType="SUBSCRIBER"/>'||
              '<DATA>'||
                  '<CmHeaderTransaction>'||
                      '<TransactionRsn>CREQ</TransactionRsn>'||
                      '<TransactionId>'||to_char(r1.acct_id)||'</TransactionId>'||
                      '<ActivityPath>CM9_OFFER_EXPIRATION_HOM</ActivityPath>'||
                      '<ActivityPcn xsi:nil="true"/>'||
                      '<WaiveIndicator xsi:nil="true"/>'||
                      '<WaiveReason xsi:nil="true"/>'||
                      '<ActivityGroupId xsi:nil="true"/>'||
                      '<LoadInd></LoadInd>'||
                  '</CmHeaderTransaction>'||
                  '<OfferExpirationInfo>'||
                      '<SubscriberID>'||to_char(r1.subscr_id)||'</SubscriberID>'||
                      '<OfferID>'||to_char(r1.offer_id)||'</OfferID>'||
                      '<ExpirationDate>'||to_char(sysdate,'yyyy-mm-dd')||'T'||to_char(sysdate,'hh24:mi:ss')||'</ExpirationDate>'||
                      '<OfferInstanceId>'||to_char(r1.offer_instance_id)||'</OfferInstanceId>'||
                      '<AgreementID>'||to_char(r1.subscr_id)||'</AgreementID>'||
                      '<OfferLevel>S</OfferLevel>'||
                      '<PaymentCategory>POST</PaymentCategory>'||
                      '<MessageType>Discount Expiration</MessageType>'||
                      '<MessageId>DISC_EXP_001</MessageId>'||
                      '<Entity_Name>FET Bill Discount Expiration</Entity_Name>'||
                  '</OfferExpirationInfo>'||
              '</DATA>'||
          '</TRB_TRX>';
	END IF;
      --
      select fy_sq_cm_trx.nextval
        into nu_seq
        from dual;
      CH_ERR_MSG :='INSERT DATA_SYNC.SUB_ID='||TO_CHAR(R1.SUBSCR_ID)||':'; 
	  IF R1.CUST_TYPE='D' THEN
      INSERT INTO FY_TB_CM_SYNC_SEND_CNTRL
                        (TRX_ID, 
                         SVC_CODE, 
                         ACTV_CODE, 
                         MODULE_ID, 
                         SORT, 
                         ENTITY_TYPE, 
                         ENTITY_ID, 
                         HEAD_CONTENT, 
                         CREATE_DATE, 
                         CREATE_USER, 
                         UPDATE_DATE, 
                         UPDATE_USER, 
                         CONTENT, 
                         ROUTE_ID)
                   Values
                        (nu_seq,
                         '27',
                         'CM9_OFFER_EXPIRATION',
                         'EMS', 
                         1,
                         'S',
                         r1.subscr_id, 
                         'TRX_ID='||to_char(nu_seq)||',ACTV_CODE=CM9_OFFER_EXPIRATION,BE_ID=110154,SUBSCRIBER_ID='||to_char(r1.subscr_id),
                         sysdate,
                         'UBL',
                         sysdate,
                         'UBL',
                         ch_remark, 
                         r1.cust_id);
		ELSE
	  INSERT INTO FY_TB_CM_SYNC_SEND_CNTRL
                   (TRX_ID, 
                    SVC_CODE, 
                    ACTV_CODE, 
                    MODULE_ID, 
                    SORT, 
                    ENTITY_TYPE, 
                    ENTITY_ID, 
                    HEAD_CONTENT, 
                    CREATE_DATE, 
                    CREATE_USER, 
                    UPDATE_DATE, 
                    UPDATE_USER, 
                    CONTENT, 
                    ROUTE_ID)
              Values
                   (nu_seq,
                    '28',
                    'CM9_OFFER_EXPIRATION_HOM',
                    'EMS', 
                    1,
                    'S',
                    r1.subscr_id, 
                    'TRX_ID='||to_char(nu_seq)||',ACTV_CODE=CM9_OFFER_EXPIRATION_HOM,BE_ID=110154,SUBSCRIBER_ID='||to_char(r1.subscr_id),
                    sysdate,
                    'UBL',
                    sysdate,
                    'UBL',
                    ch_remark, 
                    r1.cust_id);
	  END IF;			 
      update fy_tb_bl_bill_acct set CONFIRM_ID=999
                         where bill_seq=nu_bill_seq
                           and acct_id =r1.acct_id; 
   commit;						   
   end loop;
   DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS')||':CONFIRM USED_UP END');                     
   DBMS_OUTPUT.Put_Line('Confirm_USED_UP Process RETURN_CODE = 0000'); 
EXCEPTION
    WHEN OTHERS THEN
         ROLLBACK;
         DBMS_OUTPUT.Put_Line('Confirm_USED_UP Process RETURN_CODE = 9999');
END;
/