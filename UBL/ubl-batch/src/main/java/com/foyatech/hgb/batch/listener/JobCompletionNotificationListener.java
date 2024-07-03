package com.foyatech.hgb.batch.listener;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.BatchStatus;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.listener.JobExecutionListenerSupport;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.stereotype.Component;

import com.foyatech.hgb.batch.job.SendSysCtrl;

@Component
public class JobCompletionNotificationListener extends JobExecutionListenerSupport {

	@Autowired
	private SendSysCtrl sendSysCtrl;

	@Autowired
	private ApplicationContext applicationContext;
	
	private static final Logger LOG = LoggerFactory.getLogger(JobCompletionNotificationListener.class);
	@Override
	public void beforeJob(JobExecution jobExecution) {
		if(!sendSysCtrl.isRunning()){
			SpringApplication.exit(applicationContext);
	        ((ConfigurableApplicationContext) applicationContext).close();
	        LOG.info("##### beforeJob : shutdown #####");
		}
	}
	@Override
	public void afterJob(JobExecution jobExecution) {
		if(jobExecution.getStatus() == BatchStatus.COMPLETED) {
			LOG.info("#####afterJob");
		}
	}
}