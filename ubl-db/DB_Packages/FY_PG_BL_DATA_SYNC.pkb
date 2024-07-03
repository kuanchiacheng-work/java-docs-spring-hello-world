CREATE OR REPLACE PACKAGE BODY FY_PG_BL_DATA_SYNC IS

   /*************************************************************************
      PROCEDURE : NEW_ACCOUNT
      PURPOSE :   CREATE ACCOUNT SYNC
      DESCRIPTION : CREATE ACCOUNT SYNC
      PARAMETER:
            PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE NEW_ACCOUNT(PI_TRAN_ID           IN   NUMBER,
                         PI_TRX_DATE          IN   DATE,
                         PI_RSN_CODE          IN   VARCHAR2,
                         PI_ACCT_ID           IN   NUMBER,
                         PI_CUST_ID           IN   NUMBER,
                         PI_OU_ID             IN   NUMBER,
                         PI_SUBSCR_ID         IN   NUMBER,
                         PI_NEW_VALUE         IN   VARCHAR2,
                         PI_OLD_VALUE         IN   VARCHAR2,
                         PI_STATUS            IN   VARCHAR2,
                         PI_STATUS_DATE       IN   DATE,
                         PI_EFF_DATE          IN   DATE,
                         PI_END_DATE          IN   DATE,
                         PI_CHARGE_CODE       IN   VARCHAR2,
                         PI_DATE_TYPE         IN   VARCHAR2,
                         PI_WAIVE_INDICATOR   IN   VARCHAR2,
                         PI_PREV_SUB_ID       IN   NUMBER,
                         PI_SUBSCR_TYPE       IN   VARCHAR2,
                         PI_REMARK            IN   VARCHAR2,
                         PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                         PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                         PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                         PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                         PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                         PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                         PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                         PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                         PO_ERR_CDE          OUT   VARCHAR2,
                         PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err             EXCEPTION;
   BEGIN
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_STATUS_DATE; --PI_TRX_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'A';
      gnENTITY_ID   := PI_ACCT_ID;
      --GET CYCLE
      gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(gnCUST_ID)||':';
      SELECT CYCLE
        INTO gnCYCLE
        FROM FY_TB_BL_CUST_CYCLE
       WHERE CUST_ID =PI_CUST_ID
         AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                            WHERE CUST_ID  =PI_CUST_ID
                                              AND EFF_DATE<gdTRX_DATE+1);
      --INSERT BL_ACCOUNT
      gvSTEP := 'INSERT BL_ACCOUNT:';
      INSERT INTO FY_TB_BL_ACCOUNT
                 (ACCT_ID,
                  ACCT_GROUP,
                  CUST_ID,
                  BL_STATUS,
                  STATUS_DATE,
                  EFF_DATE,
                  CYCLE,
                  CREATE_DATE,
                  CREATE_USER,
                  UPDATE_DATE,
                  UPDATE_USER)
           VALUES
                 (PI_ACCT_ID,
                  'A',
                  PI_CUST_ID,
                  'OPEN',
                  PI_STATUS_DATE,
                  PI_STATUS_DATE,
                  gnCYCLE,
                  SYSDATE,
                  gvUSER,
                  SYSDATE,
                  gvUSER);
      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
         gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
         Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                       gvMPBL,
                                       gvERR_CDE,
                                       gvERR_MSG);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;

         --GET CURRECT_PEROID
         gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
         SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
           INTO gnCYCLE_MONTH, gvBILL_PERIOD
           FROM FY_TB_BL_CYCLE
          WHERE CYCLE    =gnCYCLE
            AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
                 (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration
         gvSTEP := 'CALL CREATE_CI.ACCT_ID='||TO_CHAR(PI_ACCT_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --PI_OC_ID
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END NEW_ACCOUNT;

   /*************************************************************************
      PROCEDURE : OU_SERVICE_CHANGE
      PURPOSE :   CHANGE OU OFFER SYNC
      DESCRIPTION : CHANGE OU OFFER SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE OU_SERVICE_CHANGE(PI_TRAN_ID           IN   NUMBER,
                               PI_TRX_DATE          IN   DATE,
                               PI_RSN_CODE          IN   VARCHAR2,
                               PI_ACCT_ID           IN   NUMBER,
                               PI_CUST_ID           IN   NUMBER,
                               PI_OU_ID             IN   NUMBER,
                               PI_SUBSCR_ID         IN   NUMBER,
                               PI_NEW_VALUE         IN   VARCHAR2,
                               PI_OLD_VALUE         IN   VARCHAR2,
                               PI_STATUS            IN   VARCHAR2,
                               PI_STATUS_DATE       IN   DATE,
                               PI_EFF_DATE          IN   DATE,
                               PI_END_DATE          IN   DATE,
                               PI_CHARGE_CODE       IN   VARCHAR2,
                               PI_DATE_TYPE         IN   VARCHAR2,
                               PI_WAIVE_INDICATOR   IN   VARCHAR2,
                               PI_PREV_SUB_ID       IN   NUMBER,
                               PI_SUBSCR_TYPE       IN   VARCHAR2,
                               PI_REMARK            IN   VARCHAR2,
                               PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                               PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                               PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                               PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                               PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PO_ERR_CDE          OUT   VARCHAR2,
                               PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err             EXCEPTION;
   BEGIN
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_TRX_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'O';
      gnENTITY_ID   := PI_OU_ID;
      --GET CYCLE
      gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(gnCUST_ID)||':';
      SELECT CYCLE
        INTO gnCYCLE
        FROM FY_TB_BL_CUST_CYCLE
       WHERE CUST_ID =PI_CUST_ID
         AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                            WHERE CUST_ID  =PI_CUST_ID
                                              AND EFF_DATE<gdTRX_DATE+1);

      --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
      gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
      Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                    gvMPBL,
                                    gvERR_CDE,
                                    gvERR_MSG);
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --GET CURRECT_PEROID
      gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
      SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
        INTO gnCYCLE_MONTH, gvBILL_PERIOD
        FROM FY_TB_BL_CYCLE
       WHERE CYCLE    =gnCYCLE
         AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
              (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

      --OLD DATA
      gvSTEP := 'OLD_PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('OLD',         --PI_TYPE ,
                   'PARAM',       --PARAM_TYPE
                   PI_OLD_PARAM); --PI_PARAM_OBJECT);
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      gvSTEP := 'OLD OFFER CALL CHANGE_OFFER:';
      CHANGE_OFFER('OLD',         --PI_TYPE ,
                   NULL,          --PI_DATE_TYPE
                   PI_OLD_OFFER); --PI_OFFER_OBJECT);
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --NEW DATA
      gvSTEP := 'NEW PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('NEW',          --PI_TYPE ,
                   'PARAM',        --PARAM_TYPE
                   PI_NEW_PARAM);  --PI_PARAM_OBJECT);
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      gvSTEP := 'NEW OFFER CALL CHANGE_OFFER:';
      CHANGE_OFFER('NEW',         --PI_TYPE ,
                   NULL,          --PI_DATE_TYPE
                   PI_NEW_OFFER); --PI_OFFER_OBJECT);
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         gvSTEP := 'CALL CREATE_CI.OU_ID='||TO_CHAR(PI_OU_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --PI_OC_ID
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END OU_SERVICE_CHANGE;

   /*************************************************************************
      PROCEDURE : OU_UPDATE_PARAMETER
      PURPOSE :   UPDATE_OU_OFFER PARAM SYNC
      DESCRIPTION : UPDATE_OU_OFFER PARAM SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE OU_UPDATE_PARAMETER(PI_TRAN_ID           IN   NUMBER,
                                 PI_TRX_DATE          IN   DATE,
                                 PI_RSN_CODE          IN   VARCHAR2,
                                 PI_ACCT_ID           IN   NUMBER,
                                 PI_CUST_ID           IN   NUMBER,
                                 PI_OU_ID             IN   NUMBER,
                                 PI_SUBSCR_ID         IN   NUMBER,
                                 PI_NEW_VALUE         IN   VARCHAR2,
                                 PI_OLD_VALUE         IN   VARCHAR2,
                                 PI_STATUS            IN   VARCHAR2,
                                 PI_STATUS_DATE       IN   DATE,
                                 PI_EFF_DATE          IN   DATE,
                                 PI_END_DATE          IN   DATE,
                                 PI_CHARGE_CODE       IN   VARCHAR2,
                                 PI_DATE_TYPE         IN   VARCHAR2,
                                 PI_WAIVE_INDICATOR   IN   VARCHAR2,
                                 PI_PREV_SUB_ID       IN   NUMBER,
                                 PI_SUBSCR_TYPE       IN   VARCHAR2,
                                 PI_REMARK            IN   VARCHAR2,
                                 PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                                 PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                                 PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                 PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                 PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                                 PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                                 PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                 PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                 PO_ERR_CDE          OUT   VARCHAR2,
                                 PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err             EXCEPTION;
   BEGIN
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_TRX_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'O';
      gnENTITY_ID   := PI_OU_ID;
      --OLD PARAM
      gvSTEP := 'OLD PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('OLD',         --PI_TYPE ,
                   'PARAM',       --PARAM_TYPE
                   PI_OLD_PARAM); --PI_PARAM_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      --NEW PARAM
      gvSTEP := 'NEW PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('NEW',         --PI_TYPE ,
                   'PARAM',       --PARAM_TYPE
                   PI_NEW_PARAM); --PI_PARAM_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         --GET CYCLE
         gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(gnCUST_ID)||':';
         SELECT CYCLE
           INTO gnCYCLE
           FROM FY_TB_BL_CUST_CYCLE
          WHERE CUST_ID =PI_CUST_ID
            AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                               WHERE CUST_ID  =PI_CUST_ID
                                                 AND EFF_DATE<gdTRX_DATE+1);

         --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
         gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
         Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                       gvMPBL,
                                       gvERR_CDE,
                                       gvERR_MSG);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;

         --GET CURRECT_PEROID
         gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
         SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
           INTO gnCYCLE_MONTH, gvBILL_PERIOD
           FROM FY_TB_BL_CYCLE
          WHERE CYCLE    =gnCYCLE
            AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
                 (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

         --OC處理
         gvSTEP := 'CALL CREATE_CI.OU_ID='||TO_CHAR(PI_OU_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --PI_OC_ID
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END OU_UPDATE_PARAMETER;

   /*************************************************************************
      PROCEDURE : NEW_CUSTOMER
      PURPOSE :   CREATE CUSTOMER SYNC
      DESCRIPTION : CREATE CUSTOMER SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE NEW_CUSTOMER(PI_TRAN_ID           IN   NUMBER,
                          PI_TRX_DATE          IN   DATE,
                          PI_RSN_CODE          IN   VARCHAR2,
                          PI_ACCT_ID           IN   NUMBER,
                          PI_CUST_ID           IN   NUMBER,
                          PI_OU_ID             IN   NUMBER,
                          PI_SUBSCR_ID         IN   NUMBER,
                          PI_NEW_VALUE         IN   VARCHAR2,
                          PI_OLD_VALUE         IN   VARCHAR2,
                          PI_STATUS            IN   VARCHAR2,
                          PI_STATUS_DATE       IN   DATE,
                          PI_EFF_DATE          IN   DATE,
                          PI_END_DATE          IN   DATE,
                          PI_CHARGE_CODE       IN   VARCHAR2,
                          PI_DATE_TYPE         IN   VARCHAR2,
                          PI_WAIVE_INDICATOR   IN   VARCHAR2,
                          PI_PREV_SUB_ID       IN   NUMBER,
                          PI_SUBSCR_TYPE       IN   VARCHAR2,
                          PI_REMARK            IN   VARCHAR2,
                          PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                          PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                          PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                          PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                          PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                          PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                          PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                          PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                          PO_ERR_CDE          OUT   VARCHAR2,
                          PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err             EXCEPTION;
   BEGIN
      --INSERT BL_CUST_CYCLE
      gvSTEP := 'INSERT BL_CUST_CYCLE:';
      INSERT INTO FY_TB_BL_CUST_CYCLE
                 (CUST_ID,
                  CYCLE,
                  EFF_DATE,
                  END_DATE,
                  CREATE_DATE,
                  CREATE_USER,
                  UPDATE_DATE,
                  UPDATE_USER)
           VALUES
                 (PI_CUST_ID,
                  PI_NEW_VALUE,
                  trunc(PI_EFF_DATE),
                  NULL,
                  SYSDATE,
                  gvUSER,
                  SYSDATE,
                  gvUSER);
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END NEW_CUSTOMER;

   /*************************************************************************
      PROCEDURE : CHGCYC
      PURPOSE :   CHANGE CYCLE SYNC
      DESCRIPTION : CHANGE CYCLE SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE CHGCYC(PI_TRAN_ID           IN   NUMBER,
                    PI_TRX_DATE          IN   DATE,
                    PI_RSN_CODE          IN   VARCHAR2,
                    PI_ACCT_ID           IN   NUMBER,
                    PI_CUST_ID           IN   NUMBER,
                    PI_OU_ID             IN   NUMBER,
                    PI_SUBSCR_ID         IN   NUMBER,
                    PI_NEW_VALUE         IN   VARCHAR2,
                    PI_OLD_VALUE         IN   VARCHAR2,
                    PI_STATUS            IN   VARCHAR2,
                    PI_STATUS_DATE       IN   DATE,
                    PI_EFF_DATE          IN   DATE,
                    PI_END_DATE          IN   DATE,
                    PI_CHARGE_CODE       IN   VARCHAR2,
                    PI_DATE_TYPE         IN   VARCHAR2,
                    PI_WAIVE_INDICATOR   IN   VARCHAR2,
                    PI_PREV_SUB_ID       IN   NUMBER,
                    PI_SUBSCR_TYPE       IN   VARCHAR2,
                    PI_REMARK            IN   VARCHAR2,
                    PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                    PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                    PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                    PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                    PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                    PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                    PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                    PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                    PO_ERR_CDE          OUT   VARCHAR2,
                    PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      DT_FUTURE_DATE     DATE;
      NU_CNT             NUMBER;
      On_Err             EXCEPTION;
   BEGIN
      --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
      gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
      Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                    gvMPBL,
                                    gvERR_CDE,
                                    gvERR_MSG);
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --GET CUT_DATE
      gvSTEP := 'GET OLD_CYCLE 下次出帳日:';
      --2023/08/01 MODIFY FOR SR260229_Project-M Fixed line Phase I，修正CHANGE CYCLE時間差問題
      --SELECT DECODE(FROM_DAY,1,ADD_MONTHS(TO_DATE(CURRECT_PERIOD||TO_CHAR(FROM_DAY),'YYYYMMDD'),1),
      --                         TO_DATE(CURRECT_PERIOD||TO_CHAR(FROM_DAY),'YYYYMMDD'))
      SELECT CASE WHEN TO_DATE(CURRECT_PERIOD||NAME,'YYYYMMDD') = TRUNC(SYSDATE) AND TRUNC(UPDATE_DATE) < TRUNC(SYSDATE)
      THEN
         DECODE(FROM_DAY,1,ADD_MONTHS(TO_DATE(CURRECT_PERIOD||TO_CHAR(FROM_DAY),'YYYYMMDD'),1),
                                 ADD_MONTHS(TO_DATE(CURRECT_PERIOD||TO_CHAR(FROM_DAY),'YYYYMMDD'),1))
      ELSE
         DECODE(FROM_DAY,1,ADD_MONTHS(TO_DATE(CURRECT_PERIOD||TO_CHAR(FROM_DAY),'YYYYMMDD'),1),
                                 TO_DATE(CURRECT_PERIOD||TO_CHAR(FROM_DAY),'YYYYMMDD'))
      END
        INTO DT_FUTURE_DATE
        FROM FY_TB_BL_CYCLE
       WHERE CYCLE    =PI_OLD_VALUE
         AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
              (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

      --CUST_CYCLE處理
      SELECT COUNT(1)
        INTO NU_CNT
        FROM FY_TB_BL_CUST_CYCLE
       WHERE CUST_ID=PI_CUST_ID
         AND CYCLE  =PI_OLD_VALUE
         AND END_DATE IS NULL;
      IF NU_CNT<>1 THEN
         PO_ERR_CDE := 'C001';
         gvSTEP := 'GET CUST_CYCLE.CYCLE='||TO_CHAR(PI_OLD_VALUE)||'無符合資料';
         RAISE ON_ERR;
      END IF;
      gvSTEP := 'UPDATE CUST_CYCLE:';
      UPDATE FY_TB_BL_CUST_CYCLE SET END_DATE   =DT_FUTURE_DATE,
                                     UPDATE_DATE=SYSDATE,
                                     UPDATE_USER=gvUSER
                        WHERE CUST_ID=PI_CUST_ID
                          AND CYCLE  =PI_OLD_VALUE
                          AND END_DATE IS NULL;
      gvSTEP := 'INSERT CUST_CYCLE:';
      INSERT INTO FY_TB_BL_CUST_CYCLE
                 (CUST_ID,
                  CYCLE,
                  EFF_DATE,
                  END_DATE,
                  CREATE_DATE,
                  CREATE_USER,
                  UPDATE_DATE,
                  UPDATE_USER)
           VALUES
                 (PI_CUST_ID,
                  PI_NEW_VALUE,
                  trunc(DT_FUTURE_DATE),
                  NULL,
                  SYSDATE,
                  gvUSER,
                  SYSDATE,
                  gvUSER);
      --INSERT BL_CHANGE_CYCLE
      gvSTEP := 'INSERT BL_CHANGE_CYCLE:';
      INSERT INTO FY_TB_BL_CHANGE_CYCLE
                 (CUST_ID,
                  TRX_DATE,
                  TRAN_ID,
                  OLD_CYCLE,
                  NEW_CYCLE,
                  FUTURE_EFF_DATE,
                  REMARK,
                  CREATE_DATE,
                  CREATE_USER,
                  UPDATE_DATE,
                  UPDATE_USER)
            VALUES
                 (PI_CUST_ID,
                  PI_TRX_DATE,
                  PI_TRAN_ID,
                  PI_OLD_VALUE,
                  PI_NEW_VALUE,
                  DT_FUTURE_DATE,
                  PI_REMARK,
                  SYSDATE,
                  gvUSER,
                  SYSDATE,
                  gvUSER);
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END CHGCYC;

   /*************************************************************************
      PROCEDURE NEW_SUB_ACTIVATION
      PURPOSE :   CREATE SUBSCR & SUBSCR MAIN OFFER SYNC
      DESCRIPTION : CREATE SUBSCR & SUBSCR MAIN OFFER SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE NEW_SUB_ACTIVATION(PI_TRAN_ID           IN   NUMBER,
                                PI_TRX_DATE          IN   DATE,
                                PI_RSN_CODE          IN   VARCHAR2,
                                PI_ACCT_ID           IN   NUMBER,
                                PI_CUST_ID           IN   NUMBER,
                                PI_OU_ID             IN   NUMBER,
                                PI_SUBSCR_ID         IN   NUMBER,
                                PI_NEW_VALUE         IN   VARCHAR2,
                                PI_OLD_VALUE         IN   VARCHAR2,
                                PI_STATUS            IN   VARCHAR2,
                                PI_STATUS_DATE       IN   DATE,
                                PI_EFF_DATE          IN   DATE,
                                PI_END_DATE          IN   DATE,
                                PI_CHARGE_CODE       IN   VARCHAR2,
                                PI_DATE_TYPE         IN   VARCHAR2,
                                PI_WAIVE_INDICATOR   IN   VARCHAR2,
                                PI_PREV_SUB_ID       IN   NUMBER,
                                PI_SUBSCR_TYPE       IN   VARCHAR2,
                                PI_REMARK            IN   VARCHAR2,
                                PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                                PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                                PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                                PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                                PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                PO_ERR_CDE          OUT   VARCHAR2,
                                PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      CH_STATUS          FY_TB_BL_SUB_STATUS_PERIOD.STATUS%TYPE;
      NU_CNT             NUMBER;
      On_Err             EXCEPTION;
   BEGIN
      --STATUS處理
      gvSTEP := 'SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
      SELECT COUNT(1)
        INTO NU_CNT
        FROM FY_TB_BL_SUB_STATUS_PERIOD
       WHERE SUBSCR_ID=PI_SUBSCR_ID;
      IF NU_CNT>0 THEN
         Po_Err_Cde := 'A001';
         gvSTEP := gvSTEP||'該用戶已存在';
         RAISE ON_ERR;
      END IF;
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_STATUS_DATE;  --PI_TRX_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'S';
      gnENTITY_ID   := PI_SUBSCR_ID;
      --GET CYCLE
      gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(PI_CUST_ID)||':';
      SELECT CYCLE
        INTO gnCYCLE
        FROM FY_TB_BL_CUST_CYCLE
       WHERE CUST_ID =PI_CUST_ID
         AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                            WHERE CUST_ID  =PI_CUST_ID
                                              AND EFF_DATE<gdTRX_DATE+1);

      --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
      gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
      Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                    gvMPBL,
                                    gvERR_CDE,
                                    gvERR_MSG);
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --GET CURRECT_PEROID
      gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
      SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
        INTO gnCYCLE_MONTH, gvBILL_PERIOD
        FROM FY_TB_BL_CYCLE
       WHERE CYCLE    =gnCYCLE
         AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
              (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

      --GET PRE_ACCT_ID
      IF PI_PREV_SUB_ID IS NOT NULL THEN
         gvSTEP := 'GET ACCT_ID.PREV_SUB_ID='||TO_CHAR(PI_PREV_SUB_ID)||':';
        select nvl((SELECT ACCT_ID --2020/06/30 MODIFY FOR MPBS_Migration
           FROM FY_TB_CM_SUBSCR
          WHERE SUBSCR_ID=PI_PREV_SUB_ID),0)
          INTO gnPRE_ACCT_ID
          from dual;
      ELSE
         gnPRE_ACCT_ID := NULL;
      END IF;
      gvSTEP := 'INSERT SUB_STATUS_PERIOD.SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
      INSERT INTO FY_TB_BL_SUB_STATUS_PERIOD
                 (SUBSCR_ID,
                  STATUS,
                  STATUS_DATE,
                  CREATE_DATE,
                  CREATE_USER,
                  UPDATE_DATE,
                  UPDATE_USER)
            VALUES
                 (PI_SUBSCR_ID,
                  'A',
                  PI_STATUS_DATE,
                  SYSDATE,
                  gvUSER,
                  SYSDATE,
                  gvUSER);
      ---主資費PARAM
      gvSTEP := 'NEW PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('NEW',         --PI_TYPE ,
                   'PARAM',       --PARAM_TYPE
                   PI_NEW_PARAM); --PI_PARAM_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      ---主資費OFFER
      gvSTEP := 'NEW OFFER CALL CHANGE_OFFER:';
      CHANGE_OFFER('NEW',         --PI_TYPE ,
                   NULL,          --PI_DATE_TYPE
                   PI_NEW_OFFER); --PI_OFFER_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      ---Attribute
      gvSTEP := 'Attribute CALL CHANGE_PARAM:';
      CHANGE_PARAM('NEW',         --PI_TYPE ,
                   'ATTR',        --PARAM_TYPE
                   PI_NEW_ATTR);  --PI_PARAM_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         gvSTEP := 'CALL CREATE_CI.SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --OC_ID,
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END NEW_SUB_ACTIVATION;

   /*************************************************************************
      PROCEDURE : SERVICE_CHANGE
      PURPOSE :   CHANGE SUBSCR OFFER SYNC
      DESCRIPTION : CHANGE SUBSCR OFFER SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE SERVICE_CHANGE(PI_TRAN_ID           IN   NUMBER,
                            PI_TRX_DATE          IN   DATE,
                            PI_RSN_CODE          IN   VARCHAR2,
                            PI_ACCT_ID           IN   NUMBER,
                            PI_CUST_ID           IN   NUMBER,
                            PI_OU_ID             IN   NUMBER,
                            PI_SUBSCR_ID         IN   NUMBER,
                            PI_NEW_VALUE         IN   VARCHAR2,
                            PI_OLD_VALUE         IN   VARCHAR2,
                            PI_STATUS            IN   VARCHAR2,
                            PI_STATUS_DATE       IN   DATE,
                            PI_EFF_DATE          IN   DATE,
                            PI_END_DATE          IN   DATE,
                            PI_CHARGE_CODE       IN   VARCHAR2,
                            PI_DATE_TYPE         IN   VARCHAR2,
                            PI_WAIVE_INDICATOR   IN   VARCHAR2,
                            PI_PREV_SUB_ID       IN   NUMBER,
                            PI_SUBSCR_TYPE       IN   VARCHAR2,
                            PI_REMARK            IN   VARCHAR2,
                            PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                            PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                            PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                            PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                            PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                            PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                            PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                            PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                            PO_ERR_CDE          OUT   VARCHAR2,
                            PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err             EXCEPTION;
   BEGIN
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_TRX_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'S';
      gnENTITY_ID   := PI_SUBSCR_ID;
      --GET CYCLE
      gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(PI_CUST_ID)||':';
      SELECT CYCLE
        INTO gnCYCLE
        FROM FY_TB_BL_CUST_CYCLE
       WHERE CUST_ID =PI_CUST_ID
         AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                            WHERE CUST_ID  =PI_CUST_ID
                                              AND EFF_DATE<gdTRX_DATE+1);

      --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
      gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
      Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                    gvMPBL,
                                    gvERR_CDE,
                                    gvERR_MSG);
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --GET CURRECT_PEROID
      gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
      SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
        INTO gnCYCLE_MONTH, gvBILL_PERIOD
        FROM FY_TB_BL_CYCLE
       WHERE CYCLE    =gnCYCLE
         AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
              (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration


      --GET PRE_ACCT_ID -- ADD FOR BUG FIX --2019/11/20 MODIFY SERVICE_CHANGE 取得PRE_ACCT_ID
      IF PI_PREV_SUB_ID IS NOT NULL THEN
         gvSTEP := 'GET ACCT_ID.PREV_SUB_ID='||TO_CHAR(PI_PREV_SUB_ID)||':';
        select nvl((SELECT ACCT_ID --2020/06/30 MODIFY FOR MPBS_Migration
           FROM FY_TB_CM_SUBSCR
          WHERE SUBSCR_ID=PI_PREV_SUB_ID),0)
          INTO gnPRE_ACCT_ID
          from dual;
      ELSE
         gnPRE_ACCT_ID := NULL;
      END IF;


      --OLD DATA
      gvSTEP := 'OLD_PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('OLD',         --PI_TYPE ,
                   'PARAM',       --PARAM_TYPE
                   PI_OLD_PARAM); --PI_PARAM_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      gvSTEP := 'OLD OFFER CALL CHANGE_OFFER:';
      CHANGE_OFFER('OLD',         --PI_TYPE ,
                   NULL,          --PI_DATE_TYPE
                   PI_OLD_OFFER); --PI_OFFER_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      --NEW DATA
      gvSTEP := 'NEW PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('NEW',         --PI_TYPE ,
                   'PARAM',       --PARAM_TYPE
                   PI_NEW_PARAM); --PI_PARAM_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      gvSTEP := 'NEW OFFER CALL CHANGE_OFFER:';
      CHANGE_OFFER('NEW',         --PI_TYPE ,
                   NULL,          --PI_DATE_TYPE
                   PI_NEW_OFFER); --PI_OFFER_OBJECT,

      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         gvSTEP :='CALL CREATE_CI.SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --OC_ID,
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END SERVICE_CHANGE;

   /*************************************************************************
      PROCEDURE : CHANGE_RESOURCE
      PURPOSE :   CHANGE_RESOURCE SUBSCR費用SYNC
      DESCRIPTION : CHANGE_RESOURCE SUBSCR費用SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE CHANGE_RESOURCE(PI_TRAN_ID           IN   NUMBER,
                             PI_TRX_DATE          IN   DATE,
                             PI_RSN_CODE          IN   VARCHAR2,
                             PI_ACCT_ID           IN   NUMBER,
                             PI_CUST_ID           IN   NUMBER,
                             PI_OU_ID             IN   NUMBER,
                             PI_SUBSCR_ID         IN   NUMBER,
                             PI_NEW_VALUE         IN   VARCHAR2,
                             PI_OLD_VALUE         IN   VARCHAR2,
                             PI_STATUS            IN   VARCHAR2,
                             PI_STATUS_DATE       IN   DATE,
                             PI_EFF_DATE          IN   DATE,
                             PI_END_DATE          IN   DATE,
                             PI_CHARGE_CODE       IN   VARCHAR2,
                             PI_DATE_TYPE         IN   VARCHAR2,
                             PI_WAIVE_INDICATOR   IN   VARCHAR2,
                             PI_PREV_SUB_ID       IN   NUMBER,
                             PI_SUBSCR_TYPE       IN   VARCHAR2,
                             PI_REMARK            IN   VARCHAR2,
                             PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                             PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                             PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PO_ERR_CDE          OUT   VARCHAR2,
                             PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err             EXCEPTION;
   BEGIN
      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         --公用變數
         gnTRAN_ID     := PI_TRAN_ID;
         gdTRX_DATE    := PI_TRX_DATE;
         gvRSN_CODE    := PI_RSN_CODE;
         gnCUST_ID     := PI_CUST_ID;
         gnACCT_ID     := PI_ACCT_ID;
         gnOU_ID       := PI_OU_ID;
         gvENTITY_TYPE := 'S';
         gnENTITY_ID   := PI_SUBSCR_ID;

         --GET CYCLE
         gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(PI_CUST_ID)||':';
         SELECT CYCLE
           INTO gnCYCLE
           FROM FY_TB_BL_CUST_CYCLE
          WHERE CUST_ID =PI_CUST_ID
            AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                               WHERE CUST_ID  =PI_CUST_ID
                                                 AND EFF_DATE<gdTRX_DATE+1);

         --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
         gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
         Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                       gvMPBL,
                                       gvERR_CDE,
                                       gvERR_MSG);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;

         --GET CURRECT_PEROID
         gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
         SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
           INTO gnCYCLE_MONTH, gvBILL_PERIOD
           FROM FY_TB_BL_CYCLE
          WHERE CYCLE    =gnCYCLE
            AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
                 (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

         gvSTEP := 'CALL CREATE_CI.SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --OC_ID,
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT,
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END CHANGE_RESOURCE;

   /*************************************************************************
      PROCEDURE : MOVE_SUB
      PURPOSE :    CHANGE_SUBSCR OU OFFER SYNC
      DESCRIPTION : CHANGE_SUBSCR OU OFFER SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE MOVE_SUB(PI_TRAN_ID           IN   NUMBER,
                      PI_TRX_DATE          IN   DATE,
                      PI_RSN_CODE          IN   VARCHAR2,
                      PI_ACCT_ID           IN   NUMBER,
                      PI_CUST_ID           IN   NUMBER,
                      PI_OU_ID             IN   NUMBER,
                      PI_SUBSCR_ID         IN   NUMBER,
                      PI_NEW_VALUE         IN   VARCHAR2,
                      PI_OLD_VALUE         IN   VARCHAR2,
                      PI_STATUS            IN   VARCHAR2,
                      PI_STATUS_DATE       IN   DATE,
                      PI_EFF_DATE          IN   DATE,
                      PI_END_DATE          IN   DATE,
                      PI_CHARGE_CODE       IN   VARCHAR2,
                      PI_DATE_TYPE         IN   VARCHAR2,
                      PI_WAIVE_INDICATOR   IN   VARCHAR2,
                      PI_PREV_SUB_ID       IN   NUMBER,
                      PI_SUBSCR_TYPE       IN   VARCHAR2,
                      PI_REMARK            IN   VARCHAR2,
                      PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                      PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                      PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                      PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                      PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                      PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                      PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                      PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                      PO_ERR_CDE          OUT   VARCHAR2,
                      PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err             EXCEPTION;
   BEGIN
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_TRX_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'S';
      gnENTITY_ID   := PI_SUBSCR_ID;
      --GET CYCLE
      gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(PI_CUST_ID)||':';
      SELECT CYCLE
        INTO gnCYCLE
        FROM FY_TB_BL_CUST_CYCLE
       WHERE CUST_ID =PI_CUST_ID
         AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                            WHERE CUST_ID  =PI_CUST_ID
                                              AND EFF_DATE<gdTRX_DATE+1);

      --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
      gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
      Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                    gvMPBL,
                                    gvERR_CDE,
                                    gvERR_MSG);
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --GET CURRECT_PEROID
      gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
      SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
        INTO gnCYCLE_MONTH, gvBILL_PERIOD
        FROM FY_TB_BL_CYCLE
       WHERE CYCLE    =gnCYCLE
         AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
              (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

      --OLD DATA
      gvSTEP := 'OLD_PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('OLD',         --PI_TYPE ,
                   'PARAM',       --PARAM_TYPE
                   PI_OLD_PARAM); --PI_PARAM_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      gvSTEP := 'OLD OFFER CALL CHANGE_OFFER:';
      CHANGE_OFFER('OLD',         --PI_TYPE ,
                   NULL,          --PI_DATE_TYPE
                   PI_OLD_OFFER); --PI_OFFER_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --NEW DATA
      gvSTEP := 'NEW PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('NEW',         --PI_TYPE ,
                   'PARAM',       --PARAM_TYPE
                   PI_NEW_PARAM); --PI_PARAM_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      gvSTEP := 'NEW OFFER CALL CHANGE_OFFER:';
      CHANGE_OFFER('NEW',         --PI_TYPE ,
                   NULL,          --PI_DATE_TYPE
                   PI_NEW_OFFER); --PI_OFFER_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         gvSTEP := 'CALL CREATE_CI.SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --OC_ID,
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT,
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END MOVE_SUB;

   /*************************************************************************
      PROCEDURE : UPDATE_SUB_DATE
      PURPOSE :   UPDATE SUBSCR STATUS DATE SYNC(SUSPEND/RESTORE/CANCEL)
      DESCRIPTION : UPDATE SUBSCR STATUS DATE SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE UPDATE_SUB_DATE(PI_TRAN_ID           IN   NUMBER,
                             PI_TRX_DATE          IN   DATE,
                             PI_RSN_CODE          IN   VARCHAR2,
                             PI_ACCT_ID           IN   NUMBER,
                             PI_CUST_ID           IN   NUMBER,
                             PI_OU_ID             IN   NUMBER,
                             PI_SUBSCR_ID         IN   NUMBER,
                             PI_NEW_VALUE         IN   VARCHAR2,
                             PI_OLD_VALUE         IN   VARCHAR2,
                             PI_STATUS            IN   VARCHAR2,
                             PI_STATUS_DATE       IN   DATE,
                             PI_EFF_DATE          IN   DATE,
                             PI_END_DATE          IN   DATE,
                             PI_CHARGE_CODE       IN   VARCHAR2,
                             PI_DATE_TYPE         IN   VARCHAR2,
                             PI_WAIVE_INDICATOR   IN   VARCHAR2,
                             PI_PREV_SUB_ID       IN   NUMBER,
                             PI_SUBSCR_TYPE       IN   VARCHAR2,
                             PI_REMARK            IN   VARCHAR2,
                             PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                             PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                             PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PO_ERR_CDE          OUT   VARCHAR2,
                             PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      CH_STATUS          FY_TB_BL_SUB_STATUS_PERIOD.STATUS%TYPE;
      CH_ROWID           VARCHAR2(200);
      DT_EFF_DATE        DATE;
      On_Err             EXCEPTION;
   BEGIN
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_STATUS_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'S';
      gnENTITY_ID   := PI_SUBSCR_ID;

      --SUB_STATUS_PERIOD處理
      gvSTEP := 'GET 目前STATUS:';
      SELECT STATUS, ROWID, STATUS_DATE
        INTO CH_STATUS, CH_ROWID, DT_EFF_DATE
        FROM FY_TB_BL_SUB_STATUS_PERIOD
       WHERE SUBSCR_ID=PI_SUBSCR_ID
         AND EXP_DATE IS NULL;
      IF CH_STATUS<>PI_STATUS THEN
         Po_Err_Cde := 'A001';
         gvSTEP := 'SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||',STATUS='||PI_STATUS||'非最後狀態不能修改';
         RAISE ON_ERR;
      END IF;
      gvSTEP := 'OLD_Date='||PI_OLD_VALUE;
      IF TRUNC(DT_EFF_DATE)<>TRUNC(TO_DATE(PI_OLD_VALUE,'YYYY-MM-DD HH24:MI:SS')) THEN
         Po_Err_Cde := 'A002';
         gvSTEP     := 'SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||',修改原日期='||PI_OLD_VALUE||'日期不符';
         RAISE ON_ERR;
      END IF;

      --更改前一筆的END_DATE
      gvSTEP := 'UPDATE 前一筆SUB_STATUS_PERIOD:';
      UPDATE FY_TB_BL_SUB_STATUS_PERIOD SET EXP_DATE    =TRUNC(PI_STATUS_DATE),
                                            UPDATE_DATE =SYSDATE,
                                            UPDATE_USER =gvUSER
                        WHERE SUBSCR_ID=gnENTITY_ID
                          AND EXP_DATE =DT_EFF_DATE;
      --改變STATUS DATE
      gvSTEP := 'UPDATE SUB_STATUS_PERIOD:';
      UPDATE FY_TB_BL_SUB_STATUS_PERIOD SET STATUS_DATE =TRUNC(PI_STATUS_DATE),
                                            UPDATE_DATE =SYSDATE,
                                            UPDATE_USER =gvUSER
                        WHERE ROWID=CH_ROWID;

      --修改CANCEL 需同時處理OFFER各類資訊
      IF PI_STATUS='C' THEN
         --UPDATE DATE
         gvSTEP := 'CANCEL PARAM CALL CHANGE_PARAM:';
         CHANGE_PARAM('UPDATE',      --PI_TYPE ,
                      'PARAM',       --PARAM_TYPE
                      PI_OLD_PARAM); --PI_PARAM_OBJECT
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
         gvSTEP := 'CANCEL OFFER CALL CHANGE_OFFER:';
         CHANGE_OFFER('UPDATE',      --PI_TYPE
                      PI_DATE_TYPE,
                      PI_OLD_OFFER); --PI_OFFER_OBJECT
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         --GET CYCLE
         gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(PI_CUST_ID)||':';
         SELECT CYCLE
           INTO gnCYCLE
           FROM FY_TB_BL_CUST_CYCLE
          WHERE CUST_ID =PI_CUST_ID
            AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                               WHERE CUST_ID  =PI_CUST_ID
                                                 AND EFF_DATE<gdTRX_DATE+1);

         --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
         gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
         Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                       gvMPBL,
                                       gvERR_CDE,
                                       gvERR_MSG);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;

         --GET CURRECT_PEROID
         gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
         SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
           INTO gnCYCLE_MONTH, gvBILL_PERIOD
           FROM FY_TB_BL_CYCLE
          WHERE CYCLE    =gnCYCLE
            AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
                 (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

         --OC處理
         gvSTEP := 'CALL CREATE_CI.SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --OC_ID,
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT,
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END UPDATE_SUB_DATE;

   /*************************************************************************
      PROCEDURE : UPDATE_SUB_OFFER_DATE
      PURPOSE :   UPDATE_SUBSCR_OFFER_DATE(EFF_DATE/END_DATE/FUTURE_DATE/ORIG_DATE) SYNC
      DESCRIPTION : UPDATE_SUBSCR_OFFER_DATE(EFF_DATE/END_DATE/FUTURE_DATE/ORIG_DATE) SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE UPDATE_SUB_OFFER_DATE(PI_TRAN_ID           IN   NUMBER,
                                   PI_TRX_DATE          IN   DATE,
                                   PI_RSN_CODE          IN   VARCHAR2,
                                   PI_ACCT_ID           IN   NUMBER,
                                   PI_CUST_ID           IN   NUMBER,
                                   PI_OU_ID             IN   NUMBER,
                                   PI_SUBSCR_ID         IN   NUMBER,
                                   PI_NEW_VALUE         IN   VARCHAR2,
                                   PI_OLD_VALUE         IN   VARCHAR2,
                                   PI_STATUS            IN   VARCHAR2,
                                   PI_STATUS_DATE       IN   DATE,
                                   PI_EFF_DATE          IN   DATE,
                                   PI_END_DATE          IN   DATE,
                                   PI_CHARGE_CODE       IN   VARCHAR2,
                                   PI_DATE_TYPE         IN   VARCHAR2,
                                   PI_WAIVE_INDICATOR   IN   VARCHAR2,
                                   PI_PREV_SUB_ID       IN   NUMBER,
                                   PI_SUBSCR_TYPE       IN   VARCHAR2,
                                   PI_REMARK            IN   VARCHAR2,
                                   PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                                   PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                                   PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                   PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                   PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                                   PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                                   PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                   PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                                   PO_ERR_CDE          OUT   VARCHAR2,
                                   PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err             EXCEPTION;
   BEGIN
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_TRX_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'S';
      gnENTITY_ID   := PI_SUBSCR_ID;
      --PARAM
      IF PI_DATE_TYPE IN ('EFF','END') THEN
         gvSTEP := 'UPDATE PARAM CALL CHANGE_PARAM:';
         CHANGE_PARAM('UPDATE',      --PI_TYPE ,
                      'PARAM',       --PARAM_TYPE
                      PI_NEW_PARAM); --PI_PARAM_OBJECT
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      --OFFER
      gvSTEP := 'UPDATE OFFER CALL CHANGE_OFFER:';
      CHANGE_OFFER('UPDATE',      --PI_TYPE
                   PI_DATE_TYPE,
                   PI_NEW_OFFER); --PI_OFFER_OBJECT
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;
      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         --GET CYCLE
         gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(PI_CUST_ID)||':';
         SELECT CYCLE
           INTO gnCYCLE
           FROM FY_TB_BL_CUST_CYCLE
          WHERE CUST_ID =PI_CUST_ID
            AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                               WHERE CUST_ID  =PI_CUST_ID
                                                 AND EFF_DATE<gdTRX_DATE+1);

         --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
         gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
         Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                       gvMPBL,
                                       gvERR_CDE,
                                       gvERR_MSG);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;

         --GET CURRECT_PEROID
         gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
         SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
           INTO gnCYCLE_MONTH, gvBILL_PERIOD
           FROM FY_TB_BL_CYCLE
          WHERE CYCLE    =gnCYCLE
            AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
                 (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

         --OC處理
         gvSTEP := 'CALL CREATE_CI.SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --OC_ID,
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT,
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END UPDATE_SUB_OFFER_DATE;

   /*************************************************************************
      PROCEDURE : SUB_MODI_STATUS
      PURPOSE :   SUBSCR SUSPEND/RESTORE/CANCEL SYNC
      DESCRIPTION : SUBSCR SUSPEND/RESTORE/CANCEL SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE SUB_MODI_STATUS(PI_TRAN_ID           IN   NUMBER,
                             PI_TRX_DATE          IN   DATE,
                             PI_RSN_CODE          IN   VARCHAR2,
                             PI_ACCT_ID           IN   NUMBER,
                             PI_CUST_ID           IN   NUMBER,
                             PI_OU_ID             IN   NUMBER,
                             PI_SUBSCR_ID         IN   NUMBER,
                             PI_NEW_VALUE         IN   VARCHAR2,
                             PI_OLD_VALUE         IN   VARCHAR2,
                             PI_STATUS            IN   VARCHAR2,
                             PI_STATUS_DATE       IN   DATE,
                             PI_EFF_DATE          IN   DATE,
                             PI_END_DATE          IN   DATE,
                             PI_CHARGE_CODE       IN   VARCHAR2,
                             PI_DATE_TYPE         IN   VARCHAR2,
                             PI_WAIVE_INDICATOR   IN   VARCHAR2,
                             PI_PREV_SUB_ID       IN   NUMBER,
                             PI_SUBSCR_TYPE       IN   VARCHAR2,
                             PI_REMARK            IN   VARCHAR2,
                             PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                             PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                             PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PO_ERR_CDE          OUT   VARCHAR2,
                             PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      CH_STATUS          FY_TB_BL_SUB_STATUS_PERIOD.STATUS%TYPE;
      CH_DATE_TYPE       VARCHAR2(10);
      CH_ROWID           VARCHAR2(200);
      On_Err             EXCEPTION;
   BEGIN
      SELECT DECODE(PI_STATUS,'S','SUSPEND','C','CANCEL','RESTORE')
        INTO CH_DATE_TYPE
        FROM DUAL;
      IF PI_DATE_TYPE<>CH_DATE_TYPE THEN
         Po_Err_Cde := 'A001';
         gvSTEP := 'SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||',STATUS='||PI_STATUS||'與'||PI_DATE_TYPE||'不符';
         RAISE ON_ERR;
      END IF;
      --GET CUT_DATE
      gvSTEP := 'GET 目前STATUS:';
      SELECT STATUS, ROWID
        INTO CH_STATUS, CH_ROWID
        FROM FY_TB_BL_SUB_STATUS_PERIOD
       WHERE SUBSCR_ID=PI_SUBSCR_ID
         AND EXP_DATE IS NULL;
      IF (PI_STATUS=CH_STATUS) OR
         (PI_STATUS='S' AND CH_STATUS<>'A') OR
         (PI_STATUS='A' AND CH_STATUS<>'S') THEN
         Po_Err_Cde := 'A001';
         gvSTEP := 'SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||',CURRECT_STATUS='||CH_STATUS||'與執行'||PI_STATUS||'不符';
         RAISE ON_ERR;
      END IF;
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_STATUS_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'S';
      gnENTITY_ID   := PI_SUBSCR_ID;
      --處理目前STATUS END_DATE
      gvSTEP := 'UPDATE 原BL_SUB_STATUS_PERIOD:';
      UPDATE FY_TB_BL_SUB_STATUS_PERIOD SET EXP_DATE    =TRUNC(PI_STATUS_DATE),
                                            UPDATE_DATE =SYSDATE,
                                            UPDATE_USER =gvUSER
                        WHERE ROWID=CH_ROWID;
      --新增STATUS EFF_DATE
      gvSTEP := 'INSERT BL_SUB_STATUS_PERIOD:';
      INSERT INTO FY_TB_BL_SUB_STATUS_PERIOD
                 (SUBSCR_ID,
                  STATUS,
                  STATUS_DATE,
                  CREATE_DATE,
                  CREATE_USER,
                  UPDATE_DATE,
                  UPDATE_USER)
            VALUES
                 (PI_SUBSCR_ID,
                  PI_STATUS,
                  PI_STATUS_DATE,
                  SYSDATE,
                  gvUSER,
                  SYSDATE,
                  gvUSER);
      --OFFER處理
      IF PI_DATE_TYPE='CANCEL' THEN
         --OLD DATA
         gvSTEP := 'CALL CHANGE_PARAM:';
         CHANGE_PARAM('OLD',         --PI_TYPE ,
                      'PARAM',       --PARAM_TYPE
                      PI_OLD_PARAM); --PI_PARAM_OBJECT
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
         gvSTEP := 'CALL CHANGE_OFFER:';
         CHANGE_OFFER('OLD',         --PI_TYPE ,
                      NULL,          --PI_DATE_TYPE
                      PI_OLD_OFFER); --PI_OFFER_OBJECT
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         --GET CYCLE
         gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(PI_CUST_ID)||':';
         SELECT CYCLE
           INTO gnCYCLE
           FROM FY_TB_BL_CUST_CYCLE
          WHERE CUST_ID =PI_CUST_ID
            AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                               WHERE CUST_ID  =PI_CUST_ID
                                                 AND EFF_DATE<gdTRX_DATE+1);

         --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
         gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
         Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                       gvMPBL,
                                       gvERR_CDE,
                                       gvERR_MSG);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;

         --GET CURRECT_PEROID
         gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
         SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
           INTO gnCYCLE_MONTH, gvBILL_PERIOD
           FROM FY_TB_BL_CYCLE
          WHERE CYCLE    =gnCYCLE
            AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
                 (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

         --OC處理
         gvSTEP := 'CALL CREATE_CI.SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --OC_ID,
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT,
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END SUB_MODI_STATUS;

   /*************************************************************************
      PROCEDURE : UPDATE_PARAMETERS
      PURPOSE :   UPDATE_SUBSCR_OFFER PARAM SYNC
      DESCRIPTION : UPDATE_SUBSCR_OFFER PARAM SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE UPDATE_PARAMETERS(PI_TRAN_ID           IN   NUMBER,
                               PI_TRX_DATE          IN   DATE,
                               PI_RSN_CODE          IN   VARCHAR2,
                               PI_ACCT_ID           IN   NUMBER,
                               PI_CUST_ID           IN   NUMBER,
                               PI_OU_ID             IN   NUMBER,
                               PI_SUBSCR_ID         IN   NUMBER,
                               PI_NEW_VALUE         IN   VARCHAR2,
                               PI_OLD_VALUE         IN   VARCHAR2,
                               PI_STATUS            IN   VARCHAR2,
                               PI_STATUS_DATE       IN   DATE,
                               PI_EFF_DATE          IN   DATE,
                               PI_END_DATE          IN   DATE,
                               PI_CHARGE_CODE       IN   VARCHAR2,
                               PI_DATE_TYPE         IN   VARCHAR2,
                               PI_WAIVE_INDICATOR   IN   VARCHAR2,
                               PI_PREV_SUB_ID       IN   NUMBER,
                               PI_SUBSCR_TYPE       IN   VARCHAR2,
                               PI_REMARK            IN   VARCHAR2,
                               PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                               PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                               PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                               PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                               PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                               PO_ERR_CDE          OUT   VARCHAR2,
                               PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err             EXCEPTION;
   BEGIN
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_TRX_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'S';
      gnENTITY_ID   := PI_SUBSCR_ID;
      --OLD DATA
      gvSTEP := 'OLD_PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('OLD',         --PI_TYPE ,
                   'PARAM',       --PARAM_TYPE
                    PI_OLD_PARAM); --PI_PARAM_OBJECT
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --NEW DATA
      gvSTEP := 'NEW_PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('NEW',         --PI_TYPE ,
                   'PARAM',       --PARAM_TYPE
                   PI_NEW_PARAM); --PI_PARAM_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         --GET CYCLE
         gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(gnCUST_ID)||':';
         SELECT CYCLE
           INTO gnCYCLE
           FROM FY_TB_BL_CUST_CYCLE
          WHERE CUST_ID =PI_CUST_ID
            AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                               WHERE CUST_ID  =PI_CUST_ID
                                                 AND EFF_DATE<gdTRX_DATE+1);

         --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
         gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
         Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                       gvMPBL,
                                       gvERR_CDE,
                                       gvERR_MSG);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;

         --GET CURRECT_PEROID
         gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
         SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
           INTO gnCYCLE_MONTH, gvBILL_PERIOD
           FROM FY_TB_BL_CYCLE
          WHERE CYCLE    =gnCYCLE
            AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
                 (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

         --OC處理
         gvSTEP := 'CALL CREATE_CI.SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --OC_ID,
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT,
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END UPDATE_PARAMETERS;

   /*************************************************************************
      PROCEDURE : UPDATE_SUB_ATTR
      PURPOSE :   UPDATE_SUBSCR_ATTR PARAM SYNC
      DESCRIPTION : UPDATE_SUBSCR_ATTR PARAM SYNC
      PARAMETER:
            PI_TRAN_ID            :TRAN_ID
            PI_TRX_DATE           :異動日期
            PI_RSN_CODE           :異動原因
            PI_ACCT_ID            :ACCT_ID
            PI_CUST_ID            :CUST_ID
            PI_OU_ID              :OU_ID
            PI_SUBSCR_ID          :SUBSCR_ID
            PI_NEW_VALUE          :新值
            PI_OLD_VALUE          :原值
            PI_STATUS             :SUBSCR STATUS (FOR updateSubscriberStatusDate )
            PI_STATUS_DATE        :SUBSCR STATUS DATE (FOR updateSubscriberStatusDate )
            PI_EFF_DATE           :SUBSCR EFF_DATE (FOR updateSubscriberStatusDate )
            PI_END_DATE           :SUBSCR_END_DATE (FOR updateSubscriberStatusDate )
            PI_CHARGE_CODE        :CHARGE_CODE (FOR 異動CREATE CHARGE使用)
            PI_DATE_TYPE          :修改日期類型(EFF/END/FUTURE_EXP/ORIG_EFF)
            PI_WAIVE_INDICATOR    :收費金額是否免收(Y/N/null=N)
            PI_PREV_SUB_ID        :MoveSub使用-前身
            PI_SUBSCR_TYPE        :SUBSCR_TYPE
            PI_REMARK             :UCM XSD
            PI_NEW_OFFER          :傳入ADD_OFFER_INFO OBJECT
            PI_OLD_OFFER          :傳入REMOVE_OFFER_INFO OBJECT
            PI_NEW_PARAM          :傳入NEW_PARAM_INFO OBJECT
            PI_OLD_PARAM          :傳入OLD_PARAM_INFO OBJECT
            PI_NEW_RESOURCE       :傳入NEW_RESOURCE_INFO OBJECT
            PI_OLD_RESOURCE       :傳入OLD_RESOURCE_INFO OBJECT
            PI_NEW_ATTR           :傳入NEW_ATTR_PARAM_INFO OBJECT
            PI_OLD_ATTR           :傳入OLD_ATTR_PARAM_INFO OBJECT
            PO_ERR_CDE            :錯誤代碼(0000:成功 其他:失敗)
            PO_ERR_MSG            :錯誤代碼說明
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
      3.0   2020/06/30      FOYA       MODIFY FOR MPBS_Migration
   **************************************************************************/
   PROCEDURE UPDATE_SUB_ATTR(PI_TRAN_ID           IN   NUMBER,
                             PI_TRX_DATE          IN   DATE,
                             PI_RSN_CODE          IN   VARCHAR2,
                             PI_ACCT_ID           IN   NUMBER,
                             PI_CUST_ID           IN   NUMBER,
                             PI_OU_ID             IN   NUMBER,
                             PI_SUBSCR_ID         IN   NUMBER,
                             PI_NEW_VALUE         IN   VARCHAR2,
                             PI_OLD_VALUE         IN   VARCHAR2,
                             PI_STATUS            IN   VARCHAR2,
                             PI_STATUS_DATE       IN   DATE,
                             PI_EFF_DATE          IN   DATE,
                             PI_END_DATE          IN   DATE,
                             PI_CHARGE_CODE       IN   VARCHAR2,
                             PI_DATE_TYPE         IN   VARCHAR2,
                             PI_WAIVE_INDICATOR   IN   VARCHAR2,
                             PI_PREV_SUB_ID       IN   NUMBER,
                             PI_SUBSCR_TYPE       IN   VARCHAR2,
                             PI_REMARK            IN   VARCHAR2,
                             PI_NEW_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_OLD_OFFER         IN   FY_TT_SYS_SYNC_OFFER_INFO,
                             PI_NEW_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_PARAM         IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_NEW_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                             PI_OLD_RESOURCE      IN   FY_TT_SYS_SYNC_RESOURCE,
                             PI_NEW_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PI_OLD_ATTR          IN   FY_TT_SYS_SYNC_PARAM_INFO,
                             PO_ERR_CDE          OUT   VARCHAR2,
                             PO_ERR_MSG          OUT   VARCHAR2) IS

      PRAGMA AUTONOMOUS_TRANSACTION;
      On_Err             EXCEPTION;
   BEGIN
      --公用變數
      gnTRAN_ID     := PI_TRAN_ID;
      gdTRX_DATE    := PI_TRX_DATE;
      gvRSN_CODE    := PI_RSN_CODE;
      gnCUST_ID     := PI_CUST_ID;
      gnACCT_ID     := PI_ACCT_ID;
      gnOU_ID       := PI_OU_ID;
      gvENTITY_TYPE := 'S';
      gnENTITY_ID   := PI_SUBSCR_ID;
      --OLD DATA
      gvSTEP := 'OLD_PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('OLD',          --PI_TYPE ,
                   'ATTR',         --PARAM_TYPE
                    PI_OLD_ATTR);  --PI_PARAM_OBJECT
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --NEW DATA
      gvSTEP := 'NEW_PARAM CALL CHANGE_PARAM:';
      CHANGE_PARAM('NEW',         --PI_TYPE ,
                   'ATTR',        --PARAM_TYPE
                   PI_NEW_ATTR);  --PI_PARAM_OBJECT,
      IF gvERR_CDE<>'0000' THEN
         PO_ERR_CDE := gvERR_CDE;
         gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
         RAISE ON_ERR;
      END IF;

      --費用處理
      IF PI_CHARGE_CODE IS NOT NULL THEN
         --GET CYCLE
         gvSTEP := 'GET CYCLE.CUST_ID='||TO_CHAR(gnCUST_ID)||':';
         SELECT CYCLE
           INTO gnCYCLE
           FROM FY_TB_BL_CUST_CYCLE
          WHERE CUST_ID =PI_CUST_ID
            AND EFF_DATE=(SELECT MAX(EFF_DATE) FROM FY_TB_BL_CUST_CYCLE
                                               WHERE CUST_ID  =PI_CUST_ID
                                                 AND EFF_DATE<gdTRX_DATE+1);

         --2020/06/30 MODIFY FOR MPBS_Migration -ADD CUST_TYPE判別是否為MPBL
         gvSTEP := 'CALL Fy_Pg_Bl_Bill_Util.CHECK_MPBL:';
         Fy_Pg_Bl_Bill_Util.CHECK_MPBL(PI_CUST_ID,
                                       gvMPBL,
                                       gvERR_CDE,
                                       gvERR_MSG);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;

         --GET CURRECT_PEROID
         gvSTEP := 'GET CURRECT_PERIOD CYCLE='||TO_CHAR(gnCYCLE)||':';
         SELECT TO_NUMBER(SUBSTR(CURRECT_PERIOD,-2)), CURRECT_PERIOD
           INTO gnCYCLE_MONTH, gvBILL_PERIOD
           FROM FY_TB_BL_CYCLE
          WHERE CYCLE    =gnCYCLE
            AND ((gvMPBL ='Y' AND CREATE_USER ='MPBL') OR
                 (gvMPBL<>'Y' AND CREATE_USER<>'MPBL'));  --2020/06/30 MODIFY FOR MPBS_Migration

         --OC處理
         gvSTEP := 'CALL CREATE_CI.SUBSCR_ID='||TO_CHAR(PI_SUBSCR_ID)||':';
         CREATE_CI(NULL,  --PI_OFFER_INSTANCE_ID,
                   NULL,  --PI_OFFER_ID,
                   NULL,  --PI_OFFER_SEQ,
                   gdTRX_DATE, --PI_EFF_DATE
                   NULL,  --NU_PKG_ID,
                   NULL,  --OC_ID,
                   PI_CHARGE_CODE,
                   NULL,  --AMOUNT,
                   NULL,  --NU_OVERWRITE ,
                   PI_WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            PO_ERR_CDE := gvERR_CDE;
            gvSTEP     := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
      END IF;
      COMMIT;
      Po_Err_Cde := '0000';
      Po_Err_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         ROLLBACK;
         Po_Err_Msg := gvSTEP;
      WHEN OTHERS THEN
         ROLLBACK;
         Po_Err_Cde := '9999';
         Po_Err_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END UPDATE_SUB_ATTR;

   /*************************************************************************
      PROCEDURE : CHANGE_OFFER
      PURPOSE :   CHANGE OFFER INFO SYNC
      DESCRIPTION : CHANGE OFFER INFO SYNC
      PARAMETER:
            PI_TYPE               :OLD/NEW/UPDATE
            PI_DATE_TYPE          :EFF/END/FUTURE/ORIG_EFF/NULL:PI_TYPE<>'UPDATE'
            PI_OFFER_OBJECT       :傳入OFFER PARAM OBJECT
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE CHANGE_OFFER(PI_TYPE           IN   VARCHAR2,
                          PI_DATE_TYPE      IN   VARCHAR2,
                          PI_OFFER_OBJECT   IN   FY_TT_SYS_SYNC_OFFER_INFO) IS

      CURSOR C_PK(iOFFER_ID NUMBER) IS
         SELECT PO.OFFER_ID, PO.OFFER_NAME, PO.OVERWRITE, PP.PKG_ID,
                PK.PKG_TYPE_DTL, PK.PKG_PRIORITY
           FROM FY_TB_PBK_OFFER PO,
                FY_TB_PBK_OFFER_PACKAGE PP,
                FY_TB_PBK_PACKAGE PK
          WHERE PO.OFFER_ID =iOFFER_ID
            AND PP.OFFER_ID =PO.OFFER_ID
            AND PK.PKG_ID   =PP.PKG_ID
            AND PK.PKG_TYPE_DTL IN ('RC','BDN','BDX');

      CH_RECURRING       FY_TB_PBK_PKG_DISCOUNT.RECURRING%TYPE;
      CH_PREPAYMENT      FY_TB_PBK_OFFER_PROPERTIES.PRT_VALUE%TYPE;
      NU_INIT_PKG_QTY    FY_TB_PBK_PKG_DISCOUNT.QUOTA%TYPE;
      On_Err             EXCEPTION;
   BEGIN
      IF Pi_OFFER_Object.COUNT>0 THEN
         FOR i IN 1 .. Pi_OFFER_Object.Last LOOP
            gvSTEP :='OFFER.OFFER_SEQ='||TO_CHAR(Pi_OFFER_Object(i).OFFER_SEQ)||':';
            --OFFER資料處理
            IF PI_TYPE IN ('OLD','UPDATE') THEN
               UPDATE FY_TB_BL_ACCT_PKG SET EFF_DATE =DECODE(PI_DATE_TYPE,'EFF',TRUNC(Pi_OFFER_Object(i).EFF_DATE),EFF_DATE),
                                            END_DATE =DECODE(PI_TYPE,'OLD',TRUNC(Pi_OFFER_Object(i).END_DATE),
                                                             DECODE(PI_DATE_TYPE,'END',TRUNC(Pi_OFFER_Object(i).END_DATE),END_DATE)),
                                            END_RSN  =DECODE(PI_TYPE,'OLD',gvRSN_CODE,END_RSN),
                                            FUTURE_EXP_DATE=DECODE(PI_DATE_TYPE,'FUTURE',TRUNC(Pi_OFFER_Object(i).FUTURE_END_DATE),FUTURE_EXP_DATE),
                                            ORIG_EFF_DATE  =DECODE(PI_DATE_TYPE,'ORIG_EFF',TRUNC(Pi_OFFER_Object(i).ORIG_EFF_DATE),ORIG_EFF_DATE),
                                            UPDATE_DATE    =SYSDATE,
                                            UPDATE_USER    =gvUSER
                        WHERE ACCT_ID  = gnACCT_ID
                          AND ACCT_KEY = MOD(gnACCT_ID,100)
                          AND OFFER_SEQ= Pi_OFFER_Object(i).OFFER_SEQ;
            ELSIF PI_TYPE='NEW' THEN
               --排除ENTITY_TYPE='O'&DEPLOYMENT='Y'
               IF gvENTITY_TYPE<>'O' OR NVL(Pi_OFFER_Object(i).DEPLOYMENT,'N')='N' THEN
                  --OC處理
                  CREATE_OFFER_OC(Pi_OFFER_Object(i).OFFER_INSTANCE_ID,
                                  Pi_OFFER_Object(i).OFFER_ID,
                                  Pi_OFFER_Object(i).OFFER_SEQ,
                                  Pi_OFFER_Object(i).EFF_DATE);
                  IF gvERR_CDE<>'0000' THEN
                     gvSTEP    := Substr('CALL CREARE_OFFER_OC:'||gvSTEP||gvERR_MSG, 1, 250);
                     RAISE ON_ERR;
                  END IF;

                  ----NEW OFFER資料處理
                  gvSTEP := 'INSERT '||gvSTEP;
                  IF gvENTITY_TYPE='O' OR Pi_OFFER_Object(i).PRE_OFFER_SEQ IS NULL THEN --非繼承
                     --GET PKG
                     FOR R_PK IN C_PK(Pi_OFFER_Object(i).OFFER_ID) LOOP
                        CH_RECURRING    := NULL;
                        CH_PREPAYMENT   := NULL;
                        NU_INIT_PKG_QTY := NULL;
                        IF R_PK.PKG_TYPE_DTL<>'RC' THEN
                           gvSTEP :='GET PKG_DISCOUNT.PKG_ID='||TO_CHAR(R_PK.PKG_ID)||':';
                           SELECT RECURRING, QUOTA
                             INTO CH_RECURRING, NU_INIT_PKG_QTY
                             FROM FY_TB_PBK_PKG_DISCOUNT
                            WHERE PKG_ID=R_PK.PKG_ID;
                           --GET PREPAYMENT
                           BEGIN
                           --3.1    2021/12/03 MODIFY FOR Prepayment抓取方式由properties改為rolling
                              --SELECT PRT_VALUE
                              --  INTO CH_PREPAYMENT
                              --  FROM FY_TB_PBK_OFFER_PROPERTIES
                              -- WHERE OFFER_ID = R_PK.OFFER_ID
                              --   --AND PRT_VALUE= 'Y' -- @20191231 BUG FIX
                              --   AND PRT_VALUE  IS NOT NULL
                              --   AND PRT_ID   IN (SELECT PRT_ID FROM FY_TB_PBK_PROPERTIES
                              --                       WHERE UPPER(PRT_NAME)='PREPAYMENT');
                              SELECT DECODE (rolling, 'Y', 'Y', NULL) ch_prepayment
                                INTO CH_PREPAYMENT
                                FROM fy_tb_pbk_pkg_discount
                               WHERE pkg_id IN (SELECT pkg_id
                                                  FROM fy_tb_pbk_offer_package
                                                 WHERE offer_id = R_PK.OFFER_ID) AND ROWNUM = 1;
                           EXCEPTION WHEN OTHERS THEN
                              NULL;
                           END;
                        END IF;
                        gvSTEP := 'INSERT ACCT_PKG.OFFER_SEQ='||TO_CHAR(Pi_OFFER_Object(i).OFFER_SEQ)||',PKG_ID='||TO_CHAR(R_PK.PKG_ID)||':';
                        INSERT INTO FY_TB_BL_ACCT_PKG
                                    (ACCT_PKG_SEQ,
                                     OFFER_SEQ,
                                     OFFER_ID,
                                     OFFER_INSTANCE_ID,
                                     ACCT_ID,
                                     ACCT_KEY,
                                     CUST_ID,
                                     OFFER_LEVEL,
                                     OFFER_LEVEL_ID,
                                     PKG_ID,
                                     PKG_TYPE_DTL,
                                     RECURRING,
                                     PREPAYMENT,
                                     PKG_PRIORITY,
                                     EFF_DATE,
                                     END_DATE,
                                     FUTURE_EXP_DATE,
                                     STATUS,
                                     INIT_PKG_QTY,
                                     TOTAL_DISC_AMT,
                                     CUR_QTY,
                                     CUR_USE_QTY,
                                     CUR_BAL_QTY,
                                     CUR_BILLED,
                                     VALIDITY_PERIOD,
                                     BILL_QTY,
                                     BILL_USE_QTY,
                                     BILL_BAL_QTY,
                                     BILL_DISC_AMT,
                                     TRANS_IN_QTY,
                                     FIRST_BILL_DATE,
                                     RECUR_BILLED,
                                     SYS_EFF_DATE,
                                     SYS_END_DATE,
                                     PRE_OFFER_SEQ,
                                     PRE_PKG_SEQ,
                                     TRANS_IN_DATE,
                                     ORIG_EFF_DATE,
                                     OVERWRITE,
                                     OFFER_NAME,
                                     CLEAR_FLAG,
                                     CLEAR_QTY,
                                     END_RSN,
                                     RECUR_SEQ,
                                     CREATE_DATE,
                                     CREATE_USER,
                                     UPDATE_DATE,
                                     UPDATE_USER)
                              SELECT FY_SQ_BL_ACCT_PKG.NEXTVAL,
                                     Pi_OFFER_Object(i).OFFER_SEQ,
                                     Pi_OFFER_Object(i).OFFER_ID,
                                     Pi_OFFER_Object(i).OFFER_INSTANCE_ID,
                                     gnACCT_ID,
                                     MOD(gnACCT_ID,100), --ACCT_KEY,
                                     gnCUST_ID,
                                     gvENTITY_TYPE,
                                     gnENTITY_ID,
                                     R_PK.PKG_ID,
                                     R_PK.PKG_TYPE_DTL,
                                     CH_RECURRING,
                                     CH_PREPAYMENT,
                                     R_PK.PKG_PRIORITY,
                                     TRUNC(Pi_OFFER_Object(i).EFF_DATE),
                                     TRUNC(Pi_OFFER_Object(i).END_DATE),
                                     TRUNC(Pi_OFFER_Object(i).FUTURE_END_DATE),
                                     'OPEN',  --STATUS
                                     NU_INIT_PKG_QTY,
                                     NULL,  --TOTAL_DISC_AMT,
                                     NULL,  --CUR_QTY,
                                     NULL,  --CUR_USE_QTY,
                                     NULL,  --CUR_BAL_QTY,
                                     NULL,  --CUR_BILLED,
                                     NULL,  --VALIDITY_PERIOD,
                                     NULL,  --BILL_QTY,
                                     NULL,  --BILL_USE_QTY,
                                     NULL,  --BILL_BAL_QTY,
                                     NULL,  --BILL_DISC_AMT,
                                     NULL,  --TRANS_IN_QTY,
                                     NULL,  --FIRST_BILL_DATE,
                                     NULL,  --RECUR_BILLED,
                                     NULL,  --SYS_EFF_DATE,
                                     NULL,  --SYS_END_DATE,
                                     Pi_OFFER_Object(i).PRE_OFFER_SEQ,
                                     NULL,    --PRE_PKG_SEQ,
                                     NULL,    --TRANS_IN_DATE,
                                     TRUNC(Pi_OFFER_Object(i).ORIG_EFF_DATE),
                                     R_PK.OVERWRITE,
                                     R_PK.OFFER_NAME,
                                     NULL,    --CLEAR_FLAG,
                                     NULL,    --CLEAR_QTY,
                                     NULL,    --END_RSN,
                                     NULL,    --RECUR_SEQ,
                                     SYSDATE, --CREATE_DATE,
                                     gvUSER,  --CREATE_USER,
                                     SYSDATE, --UPDATE_DATE,
                                     gvUSER   --UPDATE_USER
                                FROM DUAL;
                     END LOOP; --C_PK
                  --繼承
                  ELSE
                     gvSTEP := '繼承.PRE_OFFER_SEQ='||TO_CHAR(Pi_OFFER_Object(i).PRE_OFFER_SEQ)||':';
                     INSERT INTO FY_TB_BL_ACCT_PKG
                                    (ACCT_PKG_SEQ,
                                     OFFER_SEQ,
                                     OFFER_ID,
                                     OFFER_INSTANCE_ID,
                                     ACCT_ID,
                                     ACCT_KEY,
                                     CUST_ID,
                                     OFFER_LEVEL,
                                     OFFER_LEVEL_ID,
                                     PKG_ID,
                                     PKG_TYPE_DTL,
                                     RECURRING,
                                     PREPAYMENT,
                                     PKG_PRIORITY,
                                     EFF_DATE,
                                     END_DATE,
                                     FUTURE_EXP_DATE,
                                     STATUS,
                                     INIT_PKG_QTY,
                                     TOTAL_DISC_AMT,
                                     CUR_QTY,
                                     CUR_USE_QTY,
                                     CUR_BAL_QTY,
                                     CUR_BILLED,
                                     VALIDITY_PERIOD,
                                     BILL_QTY,
                                     BILL_USE_QTY,
                                     BILL_BAL_QTY,
                                     BILL_DISC_AMT,
                                     TRANS_IN_QTY,
                                     FIRST_BILL_DATE,
                                     RECUR_BILLED,
                                     SYS_EFF_DATE,
                                     SYS_END_DATE,
                                     PRE_OFFER_SEQ,
                                     PRE_PKG_SEQ,
                                     TRANS_IN_DATE,
                                     ORIG_EFF_DATE,
                                     OVERWRITE,
                                     OFFER_NAME,
                                     CLEAR_FLAG,
                                     CLEAR_QTY,
                                     END_RSN,
                                     RECUR_SEQ,
                                     TEST_TRANS_IN_QTY,
                                     TEST_TRANS_IN_DATE,
                                     CREATE_DATE,
                                     CREATE_USER,
                                     UPDATE_DATE,
                                     UPDATE_USER)
                              SELECT FY_SQ_BL_ACCT_PKG.NEXTVAL,
                                     Pi_OFFER_Object(i).OFFER_SEQ,
                                     Pi_OFFER_Object(i).OFFER_ID,
                                     Pi_OFFER_Object(i).OFFER_INSTANCE_ID,
                                     gnACCT_ID,
                                     MOD(gnACCT_ID,100), --ACCT_KEY,
                                     gnCUST_ID,
                                     gvENTITY_TYPE,
                                     gnENTITY_ID,
                                     AP.PKG_ID,
                                     AP.PKG_TYPE_DTL,
                                     AP.RECURRING,
                                     AP.PREPAYMENT,
                                     AP.PKG_PRIORITY,
                                     TRUNC(Pi_OFFER_Object(i).EFF_DATE),
                                     TRUNC(Pi_OFFER_Object(i).END_DATE),
                                     TRUNC(Pi_OFFER_Object(i).FUTURE_END_DATE),
                                     'OPEN',  --STATUS
                                     AP.INIT_PKG_QTY,
                                     DECODE(AP.PREPAYMENT,NULL,AP.TOTAL_DISC_AMT,NULL),
                                     NULL,  --AP.CUR_QTY
                                     NULL,  --AP.CUR_USE_QTY
                                     NULL,  --AP.CUR_BAL_QTY
                                     NULL,  --AP.CUR_BILLED
                                     DECODE(AP.PREPAYMENT,NULL,AP.VALIDITY_PERIOD,NULL),
                                     NULL,    --BILL_QTY,
                                     NULL,    --BILL_USE_QTY,
                                     NULL,    --BILL_BAL_QTY,
                                     NULL,    --BILL_DISC_AMT,
                                     DECODE(AP.PREPAYMENT,NULL,AP.CUR_BAL_QTY,NULL),  --TRANS_IN_QTY,
                                     NULL,    --FIRST_BILL_DATE,
                                     NULL,    --RECUR_BILLED,
                                     NULL,    --SYS_EFF_DATE,
                                     NULL,    --SYS_END_DATE,
                                     Pi_OFFER_Object(i).PRE_OFFER_SEQ,
                                     AP.ACCT_PKG_SEQ,  --PRE_PKG_SEQ,
                                     DECODE(AP.PREPAYMENT,NULL,TRUNC(Pi_OFFER_Object(i).EFF_DATE),NULL), --TRANS_IN_DATE,
                                     TRUNC(Pi_OFFER_Object(i).ORIG_EFF_DATE),
                                     AP.OVERWRITE,
                                     AP.OFFER_NAME,
                                     NULL,    --CLEAR_FLAG,
                                     NULL,    --CLEAR_QTY,
                                     NULL,    --END_RSN,
                                     NULL,    --RECUR_SEQ,
                                     DECODE(AP.PREPAYMENT,NULL,AP.CUR_BAL_QTY,NULL),  --TEST_TRANS_IN_QTY,
                                     DECODE(AP.PREPAYMENT,NULL,TRUNC(Pi_OFFER_Object(i).EFF_DATE),NULL), --TEST_TRANS_IN_DATE,
                                     SYSDATE, --CREATE_DATE,
                                     gvUSER,  --CREATE_USER,
                                     SYSDATE, --UPDATE_DATE,
                                     gvUSER   --UPDATE_USER
                                FROM FY_TB_BL_ACCT_PKG AP
                               WHERE OFFER_SEQ = Pi_OFFER_Object(i).PRE_OFFER_SEQ
                                 AND ACCT_ID   = gnPRE_ACCT_ID
                                 AND ACCT_KEY  = MOD(gnPRE_ACCT_ID,100);
                     --PRE_OFFER_SEQ
                     gvSTEP := 'UPDATE PRE_OFFER.PRE_OFFER_SEQ='||TO_CHAR(Pi_OFFER_Object(i).PRE_OFFER_SEQ)||':';
                     UPDATE FY_TB_BL_ACCT_PKG SET TRANS_OUT_QTY  =CUR_BAL_QTY*-1,
                                                  TRANS_OUT_DATE =TRUNC(Pi_OFFER_Object(i).EFF_DATE),
                                                  CUR_BAL_QTY    =0,
                                                  UPDATE_DATE    =SYSDATE,
                                                  UPDATE_USER    =gvUSER
                                            WHERE OFFER_SEQ = Pi_OFFER_Object(i).PRE_OFFER_SEQ
                                              AND ACCT_ID   = gnPRE_ACCT_ID
                                              AND ACCT_KEY  = MOD(gnPRE_ACCT_ID,100)
                                              AND PREPAYMENT IS NULL;
                  END IF;--NEW_OFFER
               END IF; --排除ENTITY_TYPE='O'&DEPLOYMENT='Y'
            END IF; --PI_TYPE='OLD'
         END LOOP;
      END IF;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END CHANGE_OFFER;

   /*************************************************************************
      PROCEDURE : CHANGE_PARAM
      PURPOSE :   CHANGE OFFER PARAMETER SYNC
      DESCRIPTION : CHANGE OFFER PARAMETER SYNC
      PARAMETER:
            PI_TYPE               :OLD/NEW/UPDATE
            PI_PARAM_TYPE         :PARAM/ATTR
            PI_PARAM_OBJECT       :傳入OFFER PARAM OBJECT
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE CHANGE_PARAM(PI_TYPE           IN   VARCHAR2,
                          PI_PARAM_TYPE     IN   VARCHAR2,
                          PI_PARAM_OBJECT   IN   FY_TT_SYS_SYNC_PARAM_INFO) IS

      On_Err             EXCEPTION;
   BEGIN
      IF Pi_PARAM_Object.COUNT>0 THEN
         FOR i IN 1 .. Pi_PARAM_Object.Last LOOP
            gvSTEP := 'OFFER_PARAM.SEQ_NO='||TO_CHAR(Pi_PARAM_Object(i).SEQ_NO)||':';
            --資料處理
            IF PI_PARAM_TYPE<>'ATTR' AND Pi_PARAM_Object(i).overWrite_TYPE IN ('RC','OC','BD','BL') THEN --2020/06/09 MODIFY SR226548_遠傳(遠欣)企業客服新服務系統建置
               IF PI_TYPE<>'NEW' THEN
                  gvSTEP := 'UPDATE '||gvSTEP;
                  UPDATE FY_TB_BL_OFFER_PARAM SET EFF_DATE=Pi_PARAM_Object(i).EFF_DATE,
                                                  END_DATE=Pi_PARAM_Object(i).END_DATE
                           WHERE SEQ_NO    =Pi_PARAM_Object(i).SEQ_NO
                             AND ACCT_ID   =gnACCT_ID
                             AND OFFER_SEQ =DECODE(PI_PARAM_TYPE,'ATTR',0,Pi_PARAM_Object(i).OFFER_SEQ);
               ELSE
                  gvSTEP := 'INSERT '||gvSTEP;
                  INSERT INTO FY_TB_BL_OFFER_PARAM
                              (SEQ_NO,
                               ACCT_ID,
                               OFFER_INSTANCE_ID,
                               OFFER_SEQ,
                               PARAM_NAME,
                               PARAM_VALUE,
                               EFF_DATE,
                               END_DATE,
                               OVERWRITE_TYPE,
                               CREATE_DATE,
                               CREATE_USER,
                               UPDATE_DATE,
                               UPDATE_USER)
                         VALUES
                              (Pi_PARAM_Object(i).SEQ_NO,
                               gnACCT_ID,
                               DECODE(PI_PARAM_TYPE,'ATTR',0,Pi_PARAM_Object(i).OFFER_INSTANCE_ID),
                               DECODE(PI_PARAM_TYPE,'ATTR',0,Pi_PARAM_Object(i).OFFER_SEQ),
                               Pi_PARAM_Object(i).PARAM_NAME,
                               Pi_PARAM_Object(i).PARAM_VALUE,
                               Pi_PARAM_Object(i).EFF_DATE,
                               Pi_PARAM_Object(i).END_DATE,
                               DECODE(PI_PARAM_TYPE,'ATTR',NULL,Pi_PARAM_Object(i).OVERWRITE_TYPE),
                               SYSDATE,
                               gvUSER,
                               SYSDATE,
                               gvUSER);
               END IF; --PI_TYPE='OLD'
            END IF; --overWrite_TYPE IN ('RC','OC','BD')
         END LOOP;
      END IF;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Cde := 'P001';
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END CHANGE_PARAM;

   /*************************************************************************
      PROCEDURE : CREATE_OFFER_OC
      PURPOSE :   CREATE OFFER OC_ID AMOUNT
      DESCRIPTION : CREATE OFFER OC_ID AMOUNT
      PARAMETER:
            PI_INSTANCE_ID        :OFFER INSTANCE_ID
            PI_OFFER_ID           :OFFER_ID
            PI_OFFER_SEQ          :OFFER_SEQ
            PI_EFF_DATE           :OFFER EFF_DATE
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE CREATE_OFFER_OC(PI_INSTANCE_ID    IN   NUMBER,
                             PI_OFFER_ID       IN   VARCHAR2,
                             PI_OFFER_SEQ      IN   NUMBER,
                             PI_EFF_DATE       IN   DATE) IS

      CURSOR C_OC(iTRX_DATE DATE) IS
         SELECT PP.PKG_ID, OC.OC_ID, OC.CHARGE_CODE, OC.OC_RATE
           FROM FY_TB_PBK_OFFER_PACKAGE PP,
                FY_TB_PBK_PACKAGE_OC OC
          WHERE PP.OFFER_ID                  = PI_OFFER_ID
            AND OC.PKG_ID                    = PP.PKG_ID ;
          --  AND OC.EFF_DATE                 <= iTRX_DATE
          --  AND NVL(OC.END_DATE,iTRX_DATE+1)> iTRX_DATE
         -- ORDER BY OC.EFF_DATE DESC;

      CH_PARAM_NAME      FY_TB_BL_OFFER_PARAM.PARAM_NAME%TYPE;
      NU_PARAM_VALUE     NUMBER;
      NU_OC_RATE         NUMBER;
      CH_OVERWRITE       VARCHAR2(1);
      On_Err             EXCEPTION;
   BEGIN
      FOR R_OC IN C_OC(TRUNC(gdTRX_DATE)) LOOP
         BEGIN
            -- CHECK OVERWRITE
            gvSTEP := 'CHECK OFFER_PARAM.OFFER_SEQ='||TO_CHAR(PI_OFFER_SEQ)||':';
            --2021/11/23 MODIFY SR239378 SDWAN_NPEP solution建置 (增加OC DEVICE_COUNT計算)
            SELECT SUBSTR (SUBSTR (PARAM_NAME, 1, INSTR(PARAM_NAME,'_',-1) -1),
                           INSTR (SUBSTR (PARAM_NAME,1, INSTR(PARAM_NAME,'_',-1) -1),'_') +1) PARAM_NAME,
                   DECODE((SELECT TO_NUMBER(PARAM_VALUE)
              FROM FY_TB_BL_OFFER_PARAM
             WHERE OFFER_SEQ     = PI_OFFER_SEQ
               AND OVERWRITE_TYPE='BL'
               AND PARAM_NAME = 'DEVICE_COUNT'
               AND END_DATE IS NULL),NULL,TO_NUMBER(P.PARAM_VALUE),TO_NUMBER(P.PARAM_VALUE)*(SELECT TO_NUMBER(PARAM_VALUE) 
               FROM FY_TB_BL_OFFER_PARAM
             WHERE OFFER_SEQ     = PI_OFFER_SEQ
               AND OVERWRITE_TYPE='BL'
               AND PARAM_NAME = 'DEVICE_COUNT'
               AND END_DATE IS NULL)) PARAM_VALUE
              INTO CH_PARAM_NAME, NU_OC_RATE
              FROM FY_TB_BL_OFFER_PARAM P
             WHERE OFFER_SEQ     = PI_OFFER_SEQ
               AND OVERWRITE_TYPE='OC'
               AND END_DATE IS NULL;
            CH_OVERWRITE := 'Y';
         EXCEPTION WHEN OTHERS THEN
            NU_OC_RATE   := R_OC.OC_RATE;
            CH_OVERWRITE := 'N';
         END;
         --費用處理
         gvSTEP := 'CALL CREATE_CI.OFFER_SEQ='||TO_CHAR(PI_OFFER_SEQ)||':';
         CREATE_CI(PI_INSTANCE_ID,
                   PI_OFFER_ID,
                   PI_OFFER_SEQ,
                   PI_EFF_DATE,
                   R_OC.PKG_ID,
                   R_OC.OC_ID,
                   R_OC.CHARGE_CODE,
                   NU_OC_RATE,
                   CH_OVERWRITE ,
                   'N'); --WAIVE_INDICATOR);
         IF gvERR_CDE<>'0000' THEN
            gvSTEP    := Substr(gvSTEP||gvERR_MSG, 1, 250);
            RAISE ON_ERR;
         END IF;
         EXIT;
      END LOOP;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END CREATE_OFFER_OC;

   /*************************************************************************
      PROCEDURE : CREATE_CI
      PURPOSE :   CREATE BL_BILL_CI AMOUNT
      DESCRIPTION : CREATE BL_BILL_CI AMOUNT
      PARAMETER:
            PI_INSTANCE_ID        :OFFER INSTANCE_ID
            PI_OFFER_ID           :OFFER_ID
            PI_OFFER_SEQ          :OFFER_SEQ
            PI_EFF_DATE           :OFFER EFF_DATE
            PI_PKG_ID             :PACKAGE.PKG_ID
            PI_OC_ID              :OC_ID
            PI_CHARGE_CODE        :CHARGE_CODE
            PI_AMOUNT             :金額
            PI_OVERWRITE          :Y:OVERWRITE
            PI_WAIVE_INDICATOR    :Y:異動費用不收/N:收
      RETURN: 無
      REVISION :
      VER.  DATE            Author       Description
      ------------------------------------------------------------------------
      1.0   2018/09/01      FOYA       新建
   **************************************************************************/
   PROCEDURE CREATE_CI(PI_INSTANCE_ID      IN   NUMBER,
                       PI_OFFER_ID         IN   VARCHAR2,
                       PI_OFFER_SEQ        IN   NUMBER,
                       PI_EFF_DATE         IN   DATE,
                       PI_PKG_ID           IN   NUMBER,
                       PI_OC_ID            IN   VARCHAR2,
                       PI_CHARGE_CODE      IN   VARCHAR2,
                       PI_AMOUNT           IN   NUMBER,
                       PI_OVERWRITE        IN   VARCHAR2,
                       PI_WAIVE_INDICATOR  IN   VARCHAR2) IS

      NU_CHRG_ID         FY_TB_BL_BILL_CI.CHRG_ID%TYPE;
      NU_CHRG_AMT        FY_TB_BL_BILL_CI.AMOUNT%TYPE;
      CH_CET             FY_TB_PBK_CHARGE_CODE.CET%TYPE;
      NU_CI_SEQ          NUMBER;
      On_Err             EXCEPTION;
   BEGIN
      --異動金額處理
      IF PI_OC_ID IS NULL THEN
         gvSTEP :='GET CHARGE_CODE='||PI_CHARGE_CODE||':';
         SELECT CHARGE_RATE, OC_ID, CET
           INTO NU_CHRG_AMT, NU_CHRG_ID, CH_CET
           FROM FY_TB_PBK_CHARGE_CODE
          WHERE CHARGE_CODE=PI_CHARGE_CODE;
      ELSE
         NU_CHRG_ID := PI_OC_ID;
         NU_CHRG_AMT:= PI_AMOUNT;
      END IF;
      --GET CI_SEQ
      SELECT FY_SQ_BL_BILL_CI.NEXTVAL
        INTO NU_CI_SEQ
        FROM DUAL;
      --費用處理
      gvSTEP :='INSERT BL_BILL_CI:';
      INSERT INTO FY_TB_BL_BILL_CI
                    (CI_SEQ,
                     ACCT_ID,
                     SUBSCR_ID,
                     CUST_ID,
                     OU_ID,
                     CHRG_ID,
                     CHARGE_TYPE,
                     AMOUNT,
                     OFFER_SEQ,
                     OFFER_ID,
                     OFFER_INSTANCE_ID,
                     PKG_ID,
                     CHRG_DATE,
                     CHRG_FROM_DATE,
                     CHRG_END_DATE,
                     CHARGE_CODE,
                     BILL_SEQ,
                     CYCLE,
                     CYCLE_MONTH,
                     TRX_ID,
                     TX_REASON,
                     AMT_DAY,
                     CDR_QTY,
                     CDR_ORG_AMT,
                     SOURCE,
                     SOURCE_CI_SEQ,
                     SOURCE_OFFER_ID,
                     BI_SEQ,
                     SERVICE_RECEIVER_TYPE,
                     CORRECT_SEQ,
                     CORRECT_CI_SEQ,
                     SERVICE_FILTER,
                     POINT_CLASS,
                     CET,
                     OVERWRITE,
                     DYNAMIC_ATTRIBUTE,
                     CREATE_DATE,
                     CREATE_USER,
                     UPDATE_DATE,
                     UPDATE_USER)
              VALUES
                    (NU_CI_SEQ,
                     gnACCT_ID,
                     DECODE(gvENTITY_TYPE,'O',NULL,gnENTITY_ID), --SUBSCR_ID
                     gnCUST_ID,
                     gnOU_ID,
                     NU_CHRG_ID,
                     'DBT',        --CHARGE_TYPE, --正DBT、負CRD
                     NU_CHRG_AMT,
                     PI_OFFER_SEQ,
                     PI_OFFER_ID,
                     PI_INSTANCE_ID,
                     PI_PKG_ID,
                     PI_EFF_DATE,  --CHRG_DATE,
                     NULL,         --CHRG_FROM_DATE,
                     NULL,         --CHRG_END_DATE,
                     PI_CHARGE_CODE,
                     NULL,         --BILL_SEQ,
                     gnCYCLE,
                     gnCYCLE_MONTH,
                     gnTRAN_ID,
                     gvRSN_CODE,   --TX_REASON,
                     NULL,         --AMT_DAY,
                     NULL,         --CDR_QTY,
                     NULL,         --CDR_ORG_AMT,
                     'OC',         --SOURCE,
                     NULL,         --SOURCE_CI_SEQ,
                     NULL,         --SOURCE_OFFER_ID,
                     NULL,         --BI_SEQ,
                     gvENTITY_TYPE,  --SERVICE_RECEIVER_TYPE,
                     DECODE(PI_WAIVE_INDICATOR,'Y',0,NULL),  --CORRECT_SEQ,
                     NULL,         --CORRECT_CI_SEQ,
                     NULL,         --SERVICE_FILTER,
                     NULL,         --POINT_CLASS,
                     CH_CET,
                     PI_OVERWRITE,
                     DECODE((SELECT TO_NUMBER(PARAM_VALUE) FROM FY_TB_BL_OFFER_PARAM WHERE OFFER_SEQ = PI_OFFER_SEQ AND OVERWRITE_TYPE='BL'
               AND PARAM_NAME = 'DEVICE_COUNT' AND END_DATE IS NULL),NULL,NULL,'DEVICE_COUNT='||(SELECT TO_NUMBER(PARAM_VALUE) 
               FROM FY_TB_BL_OFFER_PARAM WHERE OFFER_SEQ = PI_OFFER_SEQ AND OVERWRITE_TYPE='BL' AND PARAM_NAME = 'DEVICE_COUNT'
               AND END_DATE IS NULL)),         --DYNAMIC_ATTRIBUTE, --2022/01/13 MODIFY SR246834 SDWAN_NPEP solution建置_DYNCMIC_ATTRIBUTE增加DEVICE_COUNT
                     SYSDATE,
                     gvUSER,
                     SYSDATE,
                     gvUSER);
      IF PI_WAIVE_INDICATOR ='Y' THEN
         gvSTEP := 'WAIVE_INDICATOR INSERT BL_BILL_CI:';
         INSERT INTO FY_TB_BL_BILL_CI
                       (CI_SEQ,
                        ACCT_ID,
                        SUBSCR_ID,
                        CUST_ID,
                        OU_ID,
                        CHRG_ID,
                        CHARGE_TYPE,
                        AMOUNT,
                        OFFER_SEQ,
                        OFFER_ID,
                        OFFER_INSTANCE_ID,
                        PKG_ID,
                        CHRG_DATE,
                        CHRG_FROM_DATE,
                        CHRG_END_DATE,
                        CHARGE_CODE,
                        BILL_SEQ,
                        CYCLE,
                        CYCLE_MONTH,
                        TRX_ID,
                        TX_REASON,
                        AMT_DAY,
                        CDR_QTY,
                        CDR_ORG_AMT,
                        SOURCE,
                        SOURCE_CI_SEQ,
                        SOURCE_OFFER_ID,
                        BI_SEQ,
                        SERVICE_RECEIVER_TYPE,
                        CORRECT_SEQ,
                        CORRECT_CI_SEQ,
                        SERVICE_FILTER,
                        POINT_CLASS,
                        CET,
                        OVERWRITE,
                        DYNAMIC_ATTRIBUTE,
                        CREATE_DATE,
                        CREATE_USER,
                        UPDATE_DATE,
                        UPDATE_USER)
                 SELECT FY_SQ_BL_BILL_CI.NEXTVAL,
                        gnACCT_ID,
                        DECODE(gvENTITY_TYPE,'O',NULL,gnENTITY_ID), --SUBSCR_ID
                        gnCUST_ID,
                        gnOU_ID,
                        NU_CHRG_ID,
                        'CRD',        --CHARGE_TYPE, --正DBT、負CRD
                        NU_CHRG_AMT*-1,
                        PI_OFFER_SEQ,
                        PI_OFFER_ID,
                        PI_INSTANCE_ID,
                        PI_PKG_ID,
                        PI_EFF_DATE,  --CHRG_DATE,
                        NULL,         --CHRG_FROM_DATE,
                        NULL,         --CHRG_END_DATE,
                        PI_CHARGE_CODE,
                        NULL,         --BILL_SEQ,
                        gnCYCLE,
                        gnCYCLE_MONTH,
                        gnTRAN_ID,
                        gvRSN_CODE,   --TX_REASON,
                        NULL,         --AMT_DAY,
                        NULL,         --CDR_QTY,
                        NULL,         --CDR_ORG_AMT,
                        'OC',         --SOURCE,
                        NULL,         --SOURCE_CI_SEQ,
                        NULL,         --SOURCE_OFFER_ID,
                        NULL,         --BI_SEQ,
                        gvENTITY_TYPE,  --SERVICE_RECEIVER_TYPE,
                        1,            --CORRECT_SEQ,
                        NU_CI_SEQ,    --CORRECT_CI_SEQ,
                        NULL,         --SERVICE_FILTER,
                        NULL,         --POINT_CLASS,
                        CH_CET,
                        PI_OVERWRITE,
                     DECODE((SELECT TO_NUMBER(PARAM_VALUE) FROM FY_TB_BL_OFFER_PARAM WHERE OFFER_SEQ = PI_OFFER_SEQ AND OVERWRITE_TYPE='BL'
               AND PARAM_NAME = 'DEVICE_COUNT' AND END_DATE IS NULL),NULL,NULL,'DEVICE_COUNT='||(SELECT TO_NUMBER(PARAM_VALUE) 
               FROM FY_TB_BL_OFFER_PARAM WHERE OFFER_SEQ = PI_OFFER_SEQ AND OVERWRITE_TYPE='BL' AND PARAM_NAME = 'DEVICE_COUNT'
               AND END_DATE IS NULL)),         --DYNAMIC_ATTRIBUTE, --2022/01/13 MODIFY SR246834 SDWAN_NPEP solution建置_DYNCMIC_ATTRIBUTE增加DEVICE_COUNT
                        SYSDATE,
                        gvUSER,
                        SYSDATE,
                        gvUSER
                   FROM DUAL;
      END IF;
      gvErr_Cde := '0000';
      gvErr_Msg := NULL;
   EXCEPTION
      WHEN On_Err THEN
         gvErr_Msg := gvSTEP;
      WHEN OTHERS THEN
         gvErr_Cde := '9999';
         gvErr_Msg := Substr(gvSTEP || SQLERRM, 1, 250);
   END CREATE_CI;

END FY_PG_BL_DATA_SYNC;
/