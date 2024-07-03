package com.foyatech.hgb.batch.processor;

import static org.mockito.Matchers.anyObject;
import static org.mockito.Matchers.anyString;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doReturn;

import java.math.BigDecimal;

import org.junit.Before;
import org.junit.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import com.foyatech.hgb.batch.service.PreService;
import com.foyatech.hgb.batch.service.ProceService;
import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncConfDTO;
import com.foyatech.hgb.model.sys.FYTSysSyncCommon;

public class SysDataProcessorTest {

	@InjectMocks
	private SysDataProcessor sysDataProcessor;
	
	@Mock
	private PreService preService;
	
	@Mock
	private ProceService proceService;
	
	Long acctId = Long.valueOf("123");

	BigDecimal bd = new BigDecimal(0);

	
	@Before
	public void init() throws Exception {
		
		MockitoAnnotations.initMocks(this);
		
		doReturn(acctId).when(preService).countSysFromError(anyObject());	

	}
	
	@Test
	public void test() throws Exception{
		
		String tb = "C";
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setTb(tb);
		
		sysDataProcessor.process(dto);		
	}
	
	@Test
	public void test2() throws Exception{
		
		String tb = "BB";
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setTb(tb);
		dto.setNextExecSort(bd);
		
		FYTSysSyncCommon common = new FYTSysSyncCommon();
		
		common.setAcctId(acctId);
		common.setErrCde("0000");
		
		doReturn(common).when(proceService).execProc(anyObject());
		
		doReturn(new FyTbSysSyncConfDTO()).when(preService).getSysSyncConf(anyObject());
		
		sysDataProcessor.process(dto);		
	}
	
	@Test
	public void test3() throws Exception{
		
		FYTSysSyncCommon common = new FYTSysSyncCommon();
		
		common.setAcctId(acctId);
		common.setErrCde("0000");
		
		doReturn(common).when(proceService).execProc(anyObject());
		
		String tb = "BB";
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setTb(tb);
		
		doNothing().when(preService).doExceptionCntrl(anyObject(), anyString(), anyString());
	
		sysDataProcessor.process(dto);		
	}	
	
	@Test
	public void test4() throws Exception{		
	
		FYTSysSyncCommon common = new FYTSysSyncCommon();
				
		common.setAcctId(acctId);
		common.setErrCde("0000");
		
		doReturn(common).when(proceService).execProc(anyObject());
		
		
		String tb = "E";
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setTb(tb);
		dto.setNextExecSort(bd);
		
		doReturn(new FyTbSysSyncConfDTO()).when(preService).getSysSyncConf(anyObject());
		
		sysDataProcessor.process(dto);
	}
	
	@Test
	public void test5() throws Exception{		
	
		FYTSysSyncCommon common = new FYTSysSyncCommon();
				
		common.setAcctId(acctId);
		common.setErrCde("1111");
		
		doReturn(common).when(proceService).execProc(anyObject());
		
		
		String tb = "E";
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setTb(tb);
		dto.setNextExecSort(bd);
		
		doReturn(new FyTbSysSyncConfDTO()).when(preService).getSysSyncConf(anyObject());
		
		sysDataProcessor.process(dto);
	}
	
}
