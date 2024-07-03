package com.foyatech.hgb.batch.listener;

import static org.mockito.Matchers.anyLong;
import static org.mockito.Matchers.anyObject;
import static org.mockito.Matchers.anyString;

import org.junit.Before;
import org.junit.Test;
import org.mockito.InjectMocks;
import org.mockito.MockitoAnnotations;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.StepExecution;


public class StepExecutionNotificationListenerTest {
	
	@InjectMocks
	private StepExecutionNotificationListener stepExecutionNotificationListener;
	
	private JobExecution jobExecution = new JobExecution(11L);
	private StepExecution stepExecution = new StepExecution("testStep", jobExecution, 11L);
	
	@Before
	public void init() throws Exception {
		MockitoAnnotations.initMocks(this);	
	}
	@Test
	public void test() throws Exception{
		
		stepExecutionNotificationListener.afterStep(stepExecution);
		
		stepExecutionNotificationListener.beforeStep(stepExecution);
		
	}

}
