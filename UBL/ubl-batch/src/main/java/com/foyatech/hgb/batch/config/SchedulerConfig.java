package com.foyatech.hgb.batch.config;

import org.springframework.batch.core.launch.support.SimpleJobLauncher;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.test.JobLauncherTestUtils;
import org.springframework.beans.factory.annotation.Autowired;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.SimpleAsyncTaskExecutor;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

@Configuration
@EnableScheduling
public class SchedulerConfig {
	
	@Autowired
    private JobRepository jobRepositoryFactoryBean;
	
	
	@Bean
	public SimpleJobLauncher simpleJobLauncher() throws Exception {
		SimpleJobLauncher launcher = new SimpleJobLauncher();
		launcher.setJobRepository(jobRepositoryFactoryBean);
		
		return launcher;
	}
	
	@Bean
	public TaskExecutor taskExecutor(){
		ThreadPoolTaskExecutor taskExecutor = new ThreadPoolTaskExecutor();
		taskExecutor.setMaxPoolSize(10);
		taskExecutor.afterPropertiesSet();
	    return taskExecutor;
	}
	
	
	
	
	
	@Bean
    public SimpleAsyncTaskExecutor asyncTaskExecutor() {
        return new SimpleAsyncTaskExecutor();
    }
	
	@Bean
	public JobLauncherTestUtils getJobLauncherTestUtils() {

	    return new JobLauncherTestUtils();
	}
}
