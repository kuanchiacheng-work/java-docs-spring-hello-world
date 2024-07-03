package com.foyatech.hgb.batch.config;

import static org.mockito.Mockito.doReturn;

import java.beans.PropertyVetoException;

import org.junit.Before;
import org.junit.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import com.foyatech.hgb.util.CmdExecContext;
import com.foyatech.hgb.util.CmdExecUtil;

public class ConfigTest {

	@InjectMocks
	private MybatisConfig mybatisConfig;
	
	@InjectMocks
	private	SchedulerConfig schedulerConfig;
	
	@InjectMocks
	private NotifyConfig notifyConfig;
	
	@Mock
	private CmdExecUtil cmdExecUtil;
	
	@Before
	public void init() throws Exception {
		MockitoAnnotations.initMocks(this);	
	}	
	
	@Test
    public void testSchedulerConfig() throws Exception {
		
		schedulerConfig.simpleJobLauncher();
		schedulerConfig.asyncTaskExecutor();
		schedulerConfig.simpleJobLauncher();
		schedulerConfig.taskExecutor();
		schedulerConfig.getJobLauncherTestUtils();
	}
	
	@Test
	public void testNotifyConfig(){		
		
		notifyConfig.notifyService();
	}
	
}
