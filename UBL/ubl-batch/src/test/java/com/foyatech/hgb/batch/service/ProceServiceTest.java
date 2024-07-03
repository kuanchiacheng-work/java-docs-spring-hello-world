package com.foyatech.hgb.batch.service;

import static org.mockito.Matchers.anyObject;
import static org.mockito.Matchers.anyString;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.Date;

import javax.xml.bind.Unmarshaller;

import org.junit.Before;
import org.junit.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import com.foyatech.hgb.dao.UFyTOProcedureMapper;
import com.foyatech.hgb.enums.ActvCode;
import com.foyatech.hgb.model.common.TransactionInfo;
import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;
import com.foyatech.hgb.model.sync.HEADER;
import com.foyatech.hgb.model.sync.SyncAccount;
import com.foyatech.hgb.model.sync.SyncAccountContext;
import com.foyatech.hgb.model.sync.SyncAccountInfo;
import com.foyatech.hgb.model.sync.SyncPubData;
import com.foyatech.hgb.model.sync.SyncPubData.DATA;
import com.foyatech.hgb.model.sync.SyncRootEntity;
import com.foyatech.hgb.model.sync.SyncSubscriber;
import com.foyatech.hgb.model.sync.SyncSubscriberContext;
import com.foyatech.hgb.model.sync.SyncSubscriberInfo;
import com.foyatech.hgb.util.SysXmlUtil;

public class ProceServiceTest {

	@InjectMocks
	private ProceService service;
	
	@Mock
	private SysXmlUtil sysXmlUtil;
	
	@Mock
	private Unmarshaller unmarshaller;
	
	@Mock
	private UFyTOProcedureMapper uFyTOProcedureMapper;

	Long acctId = Long.valueOf("123");
	Long routeId = new Long("11223");
	String moduleId = "Test";
	Long trxId = new Long("123");
	String svcCode = "T";
	String actvCode = "E";
	String entityType = "S";
	Long entityId = new Long("13");
	String errMesg = "TEST";
	
	BigDecimal bd = new BigDecimal(0);
	String tb = "A";
	
	String content = "123";
	
	Date nowDate = new Date();
	DATA data = new DATA(); 	
	
	@Before
	public void init() throws Exception {	
		
		MockitoAnnotations.initMocks(this);
	}
	
	@Test
	public void test2() throws Exception {
		
		SyncRootEntity syncRootEntity = new SyncRootEntity();

//		FYTSysSyncCommon execProc(FyTbSysSyncCntrlDTO dto)
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setActvCode("A");
		
		SyncPubData syncData = new SyncPubData();
		
		DATA data = new DATA();
		//data.setAuthInfo(authInfo);
		//data.setRootEntity(rootEntity);
		
		TransactionInfo transactionInfo = new TransactionInfo();
		
		Date date = new Date();
		
		transactionInfo.setExeDate(date);
		
		data.setTransactionInfo(transactionInfo);	
		
		
		HEADER header = new HEADER();
		
		syncData.setHeader(header);
		
		when(sysXmlUtil.getSyncObject(anyString(), anyString())).thenReturn(syncData);
		  
		doReturn(null).when(uFyTOProcedureMapper).execProc(anyObject());
		
		//
		header.setEntityType("S");		

		dto.setActvCode("CANCEL_SUB");
		
		SyncSubscriberInfo syncSubscriberInfo = new SyncSubscriberInfo();
		
		syncSubscriberInfo.setStatusDate(nowDate);
		
		syncRootEntity.setOldSubscriberInfo(syncSubscriberInfo);
		
		data.setRootEntity(syncRootEntity);		
		
		//
		syncData.setData(data);
		
		service.execProc(dto);		
		
	}

	@Test
	public void test() throws Exception {
		
		SyncRootEntity syncRootEntity = new SyncRootEntity();
		SyncAccount syncAccount = new SyncAccount();
		SyncAccountContext syncAccountContext = new SyncAccountContext();		
		
//		FYTSysSyncCommon execProc(FyTbSysSyncCntrlDTO dto)
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setActvCode("A");
		
		SyncPubData syncData = new SyncPubData();
		
		DATA data = new DATA();
		//data.setAuthInfo(authInfo);
		//data.setRootEntity(rootEntity);
		
		TransactionInfo transactionInfo = new TransactionInfo();
		
		Date date = new Date();
		
		transactionInfo.setExeDate(date);
		
		data.setTransactionInfo(transactionInfo);
		
		syncData.setData(data);
		
		HEADER header = new HEADER();
		header.setEntityType("O");
		
		syncData.setHeader(header);
		
		when(sysXmlUtil.getSyncObject(anyString(), anyString())).thenReturn(syncData);
		  
		doReturn(null).when(uFyTOProcedureMapper).execProc(anyObject());
		
		
		service.execProc(dto);		
		
		//
		header.setEntityType("S");		

		service.execProc(dto);		
		
		//		
		syncAccountContext.setAcctId(acctId);
		syncAccountContext.setBeId(actvCode);
		syncAccountContext.setCustId(acctId);
		syncAccountContext.setExternalId(actvCode);
		syncAccountContext.setOuId(acctId);
		
		syncAccount.setAccountContext(syncAccountContext);
		
		SyncAccountInfo syncAccountInfo = new SyncAccountInfo();
		syncAccountInfo.setEffDate(nowDate);
		syncAccountInfo.setStatus("A");
		syncAccountInfo.setCurrency(actvCode);
		syncAccountInfo.setStatusDate(nowDate);
		
		syncAccount.setAccountInfo(syncAccountInfo);
		
		syncRootEntity.setAccount(syncAccount);
		
		data.setRootEntity(syncRootEntity);
		
		header.setEntityType("A");
		
		service.execProc(dto);	
		
		//
		header.setEntityType("C");		
		
		dto.setActvCode(ActvCode.NEW_CUSTOMER.name());		
		service.execProc(dto);	
		
		//
		dto.setActvCode(ActvCode.CHGCYC.name());	
		dto.setContent("CHGCYC");
		
		service.execProc(dto);	
	}
	
	@Test
	public void testOther1() throws Exception {
		
		SyncPubData syncData = new SyncPubData();
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setActvCode("A");
		
		HEADER header = new HEADER();

		header.setEntityType("S");	
		
		//
		TransactionInfo transactionInfo = new TransactionInfo();
		
		Date date = new Date();
		
		transactionInfo.setExeDate(date);
		
		data.setTransactionInfo(transactionInfo);		
		
		//		
		dto.setActvCode("UPDATE_SUBSCRIBER_DATES");		
		
		//
		SyncSubscriberInfo syncSubscriberInfo = new SyncSubscriberInfo();
		SyncRootEntity syncRootEntity = new SyncRootEntity();					
		syncSubscriberInfo.setStatusDate(nowDate);
		
		syncRootEntity.setOldSubscriberInfo(syncSubscriberInfo);
		
		SyncSubscriber syncSubscriber = new SyncSubscriber();
	
		syncSubscriberInfo.setStatusDate(nowDate);
		syncSubscriber.setSubscriberInfo(syncSubscriberInfo);
		
		SyncSubscriberContext syncSubscriberContext = new SyncSubscriberContext();
		syncSubscriberContext.setAcctId(acctId);
		syncSubscriberContext.setBeId("123");
		syncSubscriberContext.setCustId(acctId);
		syncSubscriberContext.setExternalId(actvCode);
		syncSubscriberContext.setOuId(acctId);
		syncSubscriberContext.setPrevSubId(acctId);
		
		syncSubscriber.setSubscriberContext(syncSubscriberContext);
		
		syncRootEntity.setSubscriber(syncSubscriber);

		data.setRootEntity(syncRootEntity);	


		syncData.setData(data);
		syncData.setHeader(header);
		
		when(sysXmlUtil.getSyncObject(anyString(), anyString())).thenReturn(syncData);	
		
		service.execProc(dto);	
	}
	
	@Test
	public void testOther2() throws Exception {
		
		SyncPubData syncData = new SyncPubData();
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setActvCode("A");
		
		HEADER header = new HEADER();

		header.setEntityType("S");	
		
		//
		TransactionInfo transactionInfo = new TransactionInfo();
		
		Date date = new Date();
		
		transactionInfo.setExeDate(date);
		
		data.setTransactionInfo(transactionInfo);		

		//
		SyncSubscriberInfo syncSubscriberInfo = new SyncSubscriberInfo();
		SyncRootEntity syncRootEntity = new SyncRootEntity();					
		syncSubscriberInfo.setStatusDate(nowDate);
		
		syncRootEntity.setOldSubscriberInfo(syncSubscriberInfo);
		
		SyncSubscriber syncSubscriber = new SyncSubscriber();
	
		syncSubscriberInfo.setStatusDate(nowDate);
		syncSubscriber.setSubscriberInfo(syncSubscriberInfo);
		
		SyncSubscriberContext syncSubscriberContext = new SyncSubscriberContext();
		syncSubscriberContext.setAcctId(acctId);
		syncSubscriberContext.setBeId("123");
		syncSubscriberContext.setCustId(acctId);
		syncSubscriberContext.setExternalId(actvCode);
		syncSubscriberContext.setOuId(acctId);
		syncSubscriberContext.setPrevSubId(acctId);
		
		syncSubscriber.setSubscriberContext(syncSubscriberContext);
		
		syncRootEntity.setSubscriber(syncSubscriber);

		data.setRootEntity(syncRootEntity);	


		syncData.setData(data);
		syncData.setHeader(header);
		
		when(sysXmlUtil.getSyncObject(anyString(), anyString())).thenReturn(syncData);	
		
		dto.setActvCode(ActvCode.NEW_SUB_ACTIVATION.name());		
		service.execProc(dto);	
		
		dto.setActvCode(ActvCode.UPDATE_SUBSCRIBER_OFFER_EFF_DATE.name());
		service.execProc(dto);	
		
		dto.setActvCode(ActvCode.UPDATE_SUBSCRIBER_OFFER_END_DATE.name());
		service.execProc(dto);	
		
		dto.setActvCode(ActvCode.UPDATE_SUBSCRIBER_OFFER_FUTURE_END_DATE.name());
		service.execProc(dto);	
		
		dto.setActvCode(ActvCode.UPDATE_SUBSCRIBER_OFFER_ORIG_EFF_DATE.name());
		service.execProc(dto);	
		
		dto.setActvCode(ActvCode.RESTORE_SUB.name());
		service.execProc(dto);	
		
		dto.setActvCode(ActvCode.SUSPEND_SUB.name());
		service.execProc(dto);	
		
		dto.setActvCode(ActvCode.CANCEL_SUB.name());
		service.execProc(dto);	
		
		dto.setActvCode(ActvCode.RESTORE_SUB.name());
		service.execProc(dto);	
	}
	
}
