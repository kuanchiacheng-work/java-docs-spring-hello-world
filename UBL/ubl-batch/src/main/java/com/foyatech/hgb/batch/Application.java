package com.foyatech.hgb.batch;

import org.springframework.batch.core.configuration.annotation.EnableBatchProcessing;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.embedded.tomcat.TomcatEmbeddedServletContainerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.context.annotation.PropertySource;

@SpringBootApplication
@EnableBatchProcessing
public class Application {
	
    public static void main( String[] args ) {
    	SpringApplication.run(Application.class, args);
    }
	
	@Autowired
    private GracefulShutdownTomcat gracefulShutdownTomcat;

    @Bean
    public TomcatEmbeddedServletContainerFactory servletContainer() {
    	TomcatEmbeddedServletContainerFactory tomcat = new TomcatEmbeddedServletContainerFactory();
        tomcat.addConnectorCustomizers(gracefulShutdownTomcat);
        return tomcat;
    }
    
    @Configuration
    @Profile("local")
    @PropertySource("file://${properties.path}batch_local.properties")
    static class localEnvironment {
    }
    
    @Configuration
    @Profile("dev")
    @PropertySource("file://${properties.path}batch_dev.properties")
    static class devEnvironment {
    }
    
    @Configuration
    @Profile("sit")
    @PropertySource("file://${properties.path}batch_sit.properties")
    static class sitEnvironment {
    }
    
    @Configuration
    @Profile("uat")
    @PropertySource("file://${properties.path}batch_uat.properties")
    static class uatEnvironment {
    }
    
    @Configuration
    @Profile("prod")
    @PropertySource("file://${properties.path}batch_prod.properties")
    static class prodEnvironment {
    }
}
