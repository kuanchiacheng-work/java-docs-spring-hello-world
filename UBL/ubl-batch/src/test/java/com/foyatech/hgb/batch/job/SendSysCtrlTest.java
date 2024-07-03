package com.foyatech.hgb.batch.job;

import static org.mockito.Matchers.anyObject;

import static org.mockito.Matchers.anyString;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.mock;

import org.junit.Before;
import org.junit.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.configuration.annotation.JobBuilderFactory;
import org.springframework.batch.core.launch.support.SimpleJobLauncher;
import org.springframework.beans.factory.annotation.Autowired;

import com.foyatech.hgb.dao.UFyTbSysSyncCntrlMapper;

import org.springframework.batch.core.Job;


public class SendSysCtrlTest {

	@Mock
	private com.foyatech.hgb.batch.service.PreService preService;
	
	@Mock
	private UFyTbSysSyncCntrlMapper uFyTbSysSyncCntrlMapper;
	
	@Mock
	private SimpleJobLauncher simpleJobLauncher;
	
	@Mock
	private JobBuilderFactory jobBuilderFactory;
	
	@InjectMocks
	private SendSysCtrl sendSysCtrl;
	
	@Before
	public void init() throws Exception{
		
		MockitoAnnotations.initMocks(this);
		
//		doReturn(mock(JobExecution.class)).when(simpleJobLauncher).run(anyObject(), anyObject());
		
//		doNothing().when(jobBuilderFactory).get(anyString());
		
	}
	
	@Test
	public void test() throws Exception{		
		
//		long count = uFyTbSysSyncCntrlMapper.count(modelID)
		
		long count = Long.valueOf("123");
		
		doReturn(count).when(uFyTbSysSyncCntrlMapper).count(anyString());
		
		try{
		
			sendSysCtrl.perform();
			
		}catch(Exception e){
			
		}
		
	}
	
	@Test
	public void testOther() throws Exception{
		
		sendSysCtrl.pendDataReader();
		
		sendSysCtrl.Processor();
		
		sendSysCtrl.pendDataProcessor();
		
//		sendSysCtrl.masterStep4Bl();
		
//		sendSysCtrl.masterSlaveHandler4Bl();
		
		sendSysCtrl.modPartitioner4Bl();
	}
	
	@Test
	public void testsyncDataReader() throws Exception{
		
		int modNum = 123;
		
		sendSysCtrl.SyncDataReader( modNum );
	}	
}
