package com.foyatech.hgb.batch.service;

import java.math.BigDecimal;

import org.junit.Before;
import org.junit.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.mockito.Spy;
import org.springframework.context.MessageSource;

import com.foyatech.hgb.dao.UFyTOProcedureMapper;
import com.foyatech.hgb.dao.UFyTbSysSyncCntrlMapper;
import com.foyatech.hgb.dao.UFyTbSysSyncConfMapper;
import com.foyatech.hgb.dao.UFyTbSysSyncErrorMapper;
import com.foyatech.hgb.dao.UFyTbSysSyncLogMapper;
import com.foyatech.hgb.model.batch.CntrlReadConditionDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncConfKeyDTO;
import com.foyatech.hgb.model.sys.FYTSysSyncCommon;
import com.foyatech.hgb.service.NotifyService;

public class PreServiceTest {
	
	@InjectMocks
	@Spy
	private PreService service;

	@Mock
	private UFyTOProcedureMapper uFyTOProcedureMapper;	
	@Mock
	private UFyTbSysSyncConfMapper  uFyTbSysSyncConfMapper;
	@Mock
	private UFyTbSysSyncCntrlMapper uFyTbSysSyncCntrlMapper;
	@Mock
	private UFyTbSysSyncLogMapper uFyTbSysSyncLogMapper;
	@Mock
	private UFyTbSysSyncErrorMapper uFyTbSysSyncErrorMapper;

	@Mock
	private NotifyService notifyService;
	@Mock
	protected MessageSource ms;

	protected FYTSysSyncCommon dto;
	
	Long routeId = new Long("11223");
	String moduleId = "Test";
	Long trxId = new Long("123");
	String svcCode = "T";
	String actvCode = "E";
	String entityType = "S";
	Long entityId = new Long("13");
	String errMesg = "TEST";
	
	BigDecimal bd = new BigDecimal(0);
	String tb = "A";
	
	@Before
	public void init() throws Exception {		
		
		MockitoAnnotations.initMocks(this);

	}

	@Test
	public void test() throws Exception {
		
		//insertSysPending(FyTbSysSyncCntrlDTO dto)
		
		FyTbSysSyncCntrlDTO dto = new FyTbSysSyncCntrlDTO();
		
		dto.setModuleId(moduleId);
		dto.setTrxId(trxId);
		dto.setActvCode(actvCode);
		dto.setEntityType(entityType);
		dto.setEntityId(entityId);
		dto.setErrMsg(errMesg);
		
		dto.setRouteId(routeId);
		dto.setModuleId(moduleId);
		
		dto.setTb(tb);
		
		service.insertSysPending(dto);
		
		//List<FyTbSysSyncCntrlDTO> countSysPending(String Modul_Id)
		
		service.countSysPending(dto.getModuleId());
		
		//Other	
		service.insertSysSyncLog(dto);
		service.countSysFromError(dto);
		service.deleteSyncCtrl(dto);
		service.deleteSysSyncError(dto);
		service.doExceptionCntrl(dto, moduleId, moduleId);

		dto.setTb("E");
		service.doExceptionCntrl(dto, moduleId, moduleId);
		service.insertSysSyncCntrl(dto);
		
		CntrlReadConditionDTO cntrlReadConditionDTO = new CntrlReadConditionDTO();
		
		cntrlReadConditionDTO.setModSize(10);
		cntrlReadConditionDTO.setModNum(0);
		cntrlReadConditionDTO.setModNum(3);
		cntrlReadConditionDTO.setModuleId(moduleId);
		cntrlReadConditionDTO.setRownum(3);
		
		service.querySysSyncCntrl(cntrlReadConditionDTO);
		
		FyTbSysSyncConfKeyDTO syncConfKeyDTO = new FyTbSysSyncConfKeyDTO();
		
		syncConfKeyDTO.setActvCode(actvCode);
		syncConfKeyDTO.setExecSort(bd);
		
		service.getSysSyncConf(syncConfKeyDTO);

	}

}
