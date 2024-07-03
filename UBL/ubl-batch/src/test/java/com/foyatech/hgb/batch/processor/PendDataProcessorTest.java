package com.foyatech.hgb.batch.processor;

import static org.mockito.Matchers.anyObject;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doReturn;

import java.math.BigDecimal;
import java.util.Date;

import org.junit.Assert;
import org.junit.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.mockito.Spy;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

import com.foyatech.hgb.batch.service.PreService;
import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;

import org.junit.Before;

public class PendDataProcessorTest {

	@InjectMocks
    private PendDataProcessor pendDataProcessor;
	
	@Mock
	private PreService preService;
	
	
	@Before
	public void init() throws Exception{
		
		MockitoAnnotations.initMocks(this);
		
		doNothing().when(preService).insertSysPending(anyObject());
	}
	
	
	@Test
	@Transactional
	public void test() throws Exception {
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setActvCode("ABC");
		dto.setContent("ABC");
		dto.setCreateDate(new Date());
		dto.setCreateUser("APUSER");
		dto.setEntityId(System.currentTimeMillis());
		dto.setEntityType("1");
		dto.setExecName("123");
		dto.setExecSort(new BigDecimal(99));
		dto.setModuleId("123");
		dto.setNextExecSort(new BigDecimal(99));
		dto.setRouteId(System.currentTimeMillis());
		dto.setSort(new Short("1"));
		dto.setSvcCode("123");
		dto.setTrxId(System.currentTimeMillis());
		dto.setUpdateDate(new Date());
		dto.setUpdateUser("ABC");
		
		pendDataProcessor.process(dto);
		
//        Assert.assertNotNull(pendDataProcessor.process(dto));
	}

}
