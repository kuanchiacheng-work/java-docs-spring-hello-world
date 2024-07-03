package com.foyatech.hgb.batch.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import com.foyatech.hgb.service.NotifyService;
import com.foyatech.hgb.util.SysXmlUtil;

@Configuration
@EnableScheduling
public class NotifyConfig {
	
	 @Bean
	 public NotifyService notifyService() {
	     return new NotifyService(); 
	 }	
	 
	 @Bean
	 public SysXmlUtil syncXmlUtil() {
	     return new SysXmlUtil(); 
	 }	
}
