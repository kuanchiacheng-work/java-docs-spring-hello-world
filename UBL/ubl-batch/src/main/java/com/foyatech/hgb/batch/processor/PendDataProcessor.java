package com.foyatech.hgb.batch.processor;

import org.springframework.batch.item.ItemProcessor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;


import com.foyatech.hgb.batch.service.PreService;

import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;



@Component
public class PendDataProcessor implements ItemProcessor<FyTbSysSyncCntrlDTO, FyTbSysSyncCntrlDTO> {

private static final Logger LOG = LoggerFactory.getLogger(SysDataProcessor.class);

	
	
	@Autowired
	private PreService preService;
	
	@Value("${modelID}")
	private String modelID;
	
	@Override
	public FyTbSysSyncCntrlDTO process(FyTbSysSyncCntrlDTO dto) throws Exception  {
		
		
		//LOG.info("==pending process=="+modelID);
		preService.insertSysPending(dto);
		
		
		return dto;
		
		
	}
	
	
	
	
	
	
	
   
	
	
	
	
	
	
	
	
	
	
	
}
