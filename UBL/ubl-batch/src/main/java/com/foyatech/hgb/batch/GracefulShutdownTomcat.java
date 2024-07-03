package com.foyatech.hgb.batch;

import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import org.apache.catalina.connector.Connector;
import org.apache.coyote.http11.Http11NioProtocol;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.context.embedded.tomcat.TomcatConnectorCustomizer;
import org.springframework.context.ApplicationContext;
import org.springframework.context.ApplicationListener;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.event.ContextClosedEvent;
import org.springframework.stereotype.Component;

import com.foyatech.hgb.batch.job.SendSysCtrl;

@Component
public class GracefulShutdownTomcat implements TomcatConnectorCustomizer, ApplicationListener<ContextClosedEvent> {
	
	private static final Logger LOG = LoggerFactory.getLogger(GracefulShutdownTomcat.class);

	@Autowired
	private ApplicationContext applicationContext;

	@Autowired
	private SendSysCtrl sendSysCtrl;	

    private volatile Connector connector;
    
    private static final int WAITTIME = 30;
    
    private static final int RETRY_CHK = 3;
    
    @Override
    public void customize(Connector connector) {
        this.connector = connector;
    }
    @Override
    public void onApplicationEvent(ContextClosedEvent contextClosedEvent) {
    	LOG.info("####### ( kill PID ) onApplicationEvent Process To Close..... #######");
    	sendSysCtrl.stop();
    	boolean Jobfinish=false;
    	int n=1;
    	while(!Jobfinish) {
    		Jobfinish=sendSysCtrl.getJobStatus();
    		if(Jobfinish){
    			break;
    		}
    		try {
         		LOG.info("====== Jobfinish : {}, retry : {}, WaitSecond : {} =======",Jobfinish, n, RETRY_CHK);
				Thread.sleep(RETRY_CHK*1000);
				
			} catch (InterruptedException e) {				
				LOG.info("==end ineterExeption==", e);
			}
    		 n++;
    	}
    	LOG.info("##### Job Has Been Shutdown few seconds ago !! #####");	
        try {
			this.connector.pause();
		} catch (Exception e) {
			
			LOG.info(e.toString());
		}    	
    	
    	LOG.info("======================  Do Shutdown Start  ====================");
		SpringApplication.exit(applicationContext);
        ((ConfigurableApplicationContext) applicationContext).close();
        Http11NioProtocol protocol = (Http11NioProtocol) connector.getProtocolHandler();
        Executor executor =protocol.getExecutor();
        if (executor instanceof ThreadPoolExecutor) {
            try {
                ThreadPoolExecutor threadPoolExecutor = (ThreadPoolExecutor) executor;                
                threadPoolExecutor.shutdown();
                
                if (!threadPoolExecutor.awaitTermination(WAITTIME, TimeUnit.SECONDS)) {
                	LOG.info("Tomcat thread pool did not shut down gracefully within {} seconds. Proceeding with forceful shutdown", WAITTIME);
                }
               
            } catch (InterruptedException ex) {
            	LOG.error(ex.getMessage(), ex);
                Thread.currentThread().interrupt();
            }
        }
       
    }
}
