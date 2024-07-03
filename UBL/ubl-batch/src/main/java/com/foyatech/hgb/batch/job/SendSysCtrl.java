package com.foyatech.hgb.batch.job;


import java.util.concurrent.atomic.AtomicBoolean;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.JobParameters;
import org.springframework.batch.core.JobParametersBuilder;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.batch.core.launch.support.RunIdIncrementer;
import org.springframework.batch.core.partition.PartitionHandler;
import org.springframework.batch.core.partition.support.TaskExecutorPartitionHandler;
import org.springframework.batch.item.ItemProcessor;
import org.springframework.batch.item.ItemReader;
import org.springframework.batch.item.support.ListItemReader;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.scheduling.annotation.Scheduled;

import com.foyatech.hgb.batch.config.SchedulerConfig;

import com.foyatech.hgb.batch.partitioner.ModPartitioner;
import com.foyatech.hgb.dao.UFyTbSysSyncCntrlMapper;
import com.foyatech.hgb.model.batch.CntrlReadConditionDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;




@Configuration
@Import({SchedulerConfig.class})
public class SendSysCtrl extends BaseJob {
	
	private static final Logger LOG = LoggerFactory.getLogger(SendSysCtrl.class);
	
	
	
	@Autowired
	private com.foyatech.hgb.batch.service.PreService preService;
	
	@Autowired
	private UFyTbSysSyncCntrlMapper uFyTbSysSyncCntrlMapper;
	
	@Value("${modelID}")
	private String modelID;

	@Value("${modsize}")
	private Integer modsize;

	@Value("${rownum}")
	private Integer rownum;
	
	private boolean lowCount = false;
	private static boolean jobFinish = true;
	
	protected final AtomicBoolean enabled = new AtomicBoolean(true);

	public boolean isRunning() {
		return enabled.get();
	}

	public void start() {
		enabled.set(true);
	}

	public void stop() {
		
		//this.jobExecution.stop();
		enabled.set(false);
	}
	
	public boolean getJobStatus() {
		
		return jobFinish;
	}
   // @Scheduled(cron = "1 * * * * *")
	@Scheduled(initialDelay = 1000, fixedDelayString  = "${SendSysCtrlJob.scheduled.fixedDelay}")
    public void perform() throws Exception {
		if(!isRunning()){
			return;
		}
		
		jobFinish=false;
		long count = uFyTbSysSyncCntrlMapper.count(modelID); 
		if(count == 0){
			LOG.info("##### SendSysCtrl data count = 0 #####");
			jobFinish=true;
			return;
		}else{
			if(count > 50) {
				lowCount = false;
			}else{
				lowCount = true;
			}
			LOG.info("##### SendSysCtrl data count = {} , Process Start ! #####", count);
		}
		
    	String JobId = SendSysCtrl.class.getSimpleName() + String.valueOf(System.currentTimeMillis());
        JobParameters param = new JobParametersBuilder()
        		.addString("JobId", JobId)
        		.toJobParameters();
       
        LOG.info("#####" + JobId + " : NEW job :" );        
        
        JobExecution execution = simpleJobLauncher.run(BLSendSysCtrlJob(), param);
        LOG.info("##### Job finished with status = {}, data count = {}" , 
        		execution.getStatus(), uFyTbSysSyncCntrlMapper.count(modelID));
        jobFinish=true;
    }
  
    
 
    
    @Bean
    @StepScope
    public   ItemReader<FyTbSysSyncCntrlDTO> pendDataReader() throws Exception {
    	   
     	
    		LOG.info("======"+modelID+" insert Pending=========");
    		//preService.insertSysPending(moduleId);
    		
   		
			return new ListItemReader<FyTbSysSyncCntrlDTO>(preService.countSysPending(modelID));
    		

		
    }

    @Bean
    @StepScope
    public   ItemReader<FyTbSysSyncCntrlDTO> SyncDataReader(@Value("#{stepExecutionContext[modNum]}") int modNum) throws Exception {
    	LOG.info("======= {} Query Reader : modNum = {}, modsize = {}, rownum = {} =======", modelID, modNum, modsize, rownum);

		CntrlReadConditionDTO cond = new CntrlReadConditionDTO();
		cond.setRownum(rownum);
		cond.setModSize(modsize);
		cond.setModNum(modNum);
		cond.setModuleId(modelID);
			return new ListItemReader<FyTbSysSyncCntrlDTO>(preService.querySysSyncCntrl(cond));
		
    }
    
    
    
    
    @Bean
    public ItemProcessor<FyTbSysSyncCntrlDTO, FyTbSysSyncCntrlDTO> Processor() throws Exception {
    	
    	
    	//LOG.info("======BL    insert Pending=========");
    	//preService.insertSysPending(moduleId);
    	
        return new com.foyatech.hgb.batch.processor.SysDataProcessor();
    }
    @Bean
    public ItemProcessor<FyTbSysSyncCntrlDTO, FyTbSysSyncCntrlDTO> pendDataProcessor() throws Exception {
    	
    	 	
        
        return new com.foyatech.hgb.batch.processor.PendDataProcessor();
    } 
    
	@Bean
	public Step masterStep4Bl() throws Exception {
		return stepBuilderFactory.get("masterStep4Bl").partitioner(BLSyncData().getName(), modPartitioner4Bl())
				.partitionHandler(masterSlaveHandler4Bl()).build();
	}

	@Bean
	public PartitionHandler masterSlaveHandler4Bl() throws Exception {
		TaskExecutorPartitionHandler handler = new TaskExecutorPartitionHandler();
		handler.setGridSize((modsize==null || lowCount) ? 1 : modsize);
		handler.setTaskExecutor(asyncTaskExecutor);
		handler.setStep(BLSyncData());
		handler.afterPropertiesSet();
		
		return handler;
	}

	@Bean
	public ModPartitioner modPartitioner4Bl() {
		return new ModPartitioner();
	}
    
    @Bean
    public Job BLSendSysCtrlJob() throws Exception {
    	LOG.info("============SYNC "+modelID+"======　");
        return jobBuilderFactory.get("BLSendSysCtrlJob")
                .incrementer(new RunIdIncrementer())
                .listener(jobListener)
                /*.flow(SyncData())*/
                .flow(BLPendSyncData())
                .next(masterStep4Bl())
                .end()
                .build();
    }
    
  
	@Bean
    public Step BLSyncData() throws Exception {
        return stepBuilderFactory.get("BLSyncData")
                .<FyTbSysSyncCntrlDTO, FyTbSysSyncCntrlDTO> chunk(1)// I / O
                .reader(SyncDataReader(0))
                .processor(Processor())
                //.writer(sendCntrlWriter)
                .listener(stepListener)
                .throttleLimit(1)
                .build();
    
       
    } 
	
	@Bean
    public Step BLPendSyncData() throws Exception {
        return stepBuilderFactory.get("BLPendSyncData")
                .<FyTbSysSyncCntrlDTO, FyTbSysSyncCntrlDTO> chunk(1)// I / O
                .reader(pendDataReader())
                .processor(pendDataProcessor())
                //.writer(sendCntrlWriter)
                .taskExecutor(taskExecutor)
                .listener(stepListener)
                .throttleLimit(1)
                .build();
    
       
    } 
	
   
    

}