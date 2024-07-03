package com.foyatech.hgb.batch.job;

import javax.sql.DataSource;

import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.batch.core.configuration.annotation.JobBuilderFactory;
import org.springframework.batch.core.configuration.annotation.StepBuilderFactory;
import org.springframework.batch.core.launch.support.SimpleJobLauncher;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.SimpleAsyncTaskExecutor;
import org.springframework.core.task.TaskExecutor;

import com.foyatech.hgb.batch.listener.JobCompletionNotificationListener;
import com.foyatech.hgb.batch.listener.StepExecutionNotificationListener;

@Configuration
public class BaseJob {
	
	@Autowired
	protected SimpleJobLauncher simpleJobLauncher;
	
    @Autowired
    protected JobBuilderFactory jobBuilderFactory;

    @Autowired
    protected StepBuilderFactory stepBuilderFactory;
    
    @Autowired
    protected JobCompletionNotificationListener jobListener;
    
    @Autowired
    protected StepExecutionNotificationListener stepListener;
    
    @Autowired
    protected DataSource dataSource;
    
    @Autowired
    protected SimpleAsyncTaskExecutor asyncTaskExecutor;
    
    @Autowired
    protected TaskExecutor taskExecutor;
    
    @Autowired
    protected SqlSessionFactory sqlSessionFactory;

}