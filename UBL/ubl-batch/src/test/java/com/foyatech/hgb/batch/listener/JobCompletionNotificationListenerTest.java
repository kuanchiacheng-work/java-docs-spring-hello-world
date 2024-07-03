package com.foyatech.hgb.batch.listener;

import org.junit.Before;
import org.junit.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.mockito.Spy;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.batch.core.BatchStatus;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.listener.JobExecutionListenerSupport;

public class JobCompletionNotificationListenerTest {

	@InjectMocks
	private JobCompletionNotificationListener jobCompletionNotificationListener;
	
	private JobExecution jobExecution = new JobExecution(11L);
	
	@Before
	public void init() throws Exception {
		MockitoAnnotations.initMocks(this);	
	}
	
	@Test
	public void test(){

		jobExecution.setStatus(BatchStatus.COMPLETED);
		
		jobCompletionNotificationListener.afterJob(jobExecution);
	}
	
}
