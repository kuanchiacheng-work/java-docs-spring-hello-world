package com.foyatech.hgb.batch.listener;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.ExitStatus;
import org.springframework.batch.core.StepExecution;
import org.springframework.batch.core.listener.StepExecutionListenerSupport;
import org.springframework.stereotype.Component;

@Component
public class StepExecutionNotificationListener extends StepExecutionListenerSupport{
	
	private static final Logger LOG = LoggerFactory.getLogger(StepExecutionNotificationListener.class);

	@Override
	public ExitStatus afterStep(StepExecution stepExecution) {
		LOG.info("After step");
		return super.afterStep(stepExecution);
	}

	@Override
	public void beforeStep(StepExecution stepExecution) {
		LOG.info("Before step");
		super.beforeStep(stepExecution);
	}
}