package com.foyatech.hgb.batch.service;

import java.util.Date;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import com.foyatech.hgb.dao.UFyTbSysSyncCntrlMapper;
import com.foyatech.hgb.dao.UFyTbSysSyncConfMapper;
import com.foyatech.hgb.dao.UFyTbSysSyncErrorMapper;
import com.foyatech.hgb.dao.UFyTbSysSyncLogMapper;

import com.foyatech.hgb.exception.SYSException;
import com.foyatech.hgb.model.batch.CntrlReadConditionDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlKeyDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncConfDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncConfKeyDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncErrorDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncErrorExampleDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncErrorKeyDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncLogDTO;

@Service
public class PreService {
     
	private static final Logger LOG = LoggerFactory.getLogger(PreService.class);
	
	@Autowired
	private UFyTbSysSyncConfMapper  uFyTbSysSyncConfMapper;
	
	
	
	@Autowired
	private UFyTbSysSyncCntrlMapper uFyTbSysSyncCntrlMapper;
	
	
	@Autowired
	private UFyTbSysSyncLogMapper uFyTbSysSyncLogMapper;
	
	@Autowired
	private UFyTbSysSyncErrorMapper uFyTbSysSyncErrorMapper;
	
	
	/**
	 * 先將CNTRL檔內同一EntityID的ERROR檔的資料移至ERROR檔Pending，避免CNTRL檔資料過多
	 * @throws Exception 
	 */
	public void insertSysPending(FyTbSysSyncCntrlDTO dto) throws Exception {
		
		
			LOG.info("===insertPendingByModuleToError : trxId = {}, entityId = {}, routeId = {}, actvCode = {} ====",
					dto.getTrxId(), dto.getEntityId(), dto.getRouteId(), dto.getActvCode());
			dto.setStatus("P");
			dto.setSendDate(new Date());
			
			this.insertSysSyncError(dto);
			
			FyTbSysSyncCntrlKeyDTO key=new  FyTbSysSyncCntrlKeyDTO();
			key.setTrxId(dto.getTrxId());
			key.setActvCode(dto.getActvCode());
			key.setModuleId(dto.getModuleId());
			key.setExecName(dto.getExecName());
			key.setEntityId(dto.getEntityId());
			uFyTbSysSyncCntrlMapper.deleteByPrimaryKey(key);
		
	}
	public List<FyTbSysSyncCntrlDTO> countSysPending(String Modul_Id) throws Exception {
		
		List<FyTbSysSyncCntrlDTO>  ls=uFyTbSysSyncCntrlMapper.selectPendingByModule(Modul_Id);
		
		
	
		return ls;
		
	}
	
	/**
	 * 刪除原本sys error 資料
	 * @return
	 */
	public FyTbSysSyncErrorKeyDTO deleteSysSyncError (FyTbSysSyncCntrlDTO cdto) {
		
		FyTbSysSyncErrorKeyDTO key=new FyTbSysSyncErrorKeyDTO();
		key.setTrxId(cdto.getTrxId());
		key.setActvCode(cdto.getActvCode());
		key.setModuleId(cdto.getModuleId());
		key.setExecName(cdto.getExecName());
		key.setEntityId(cdto.getEntityId());
		uFyTbSysSyncErrorMapper.deleteByPrimaryKey(key);
		return key;
		
	}
	@Transactional(propagation=Propagation.REQUIRES_NEW)
	public void  doExceptionCntrl(FyTbSysSyncCntrlDTO record,String modelID,String notifyCode) throws SYSException {
		
		if(record.getTb().equals("E")) {
			 this.deleteSysSyncError(record);
			}else {
			this.deleteSyncCtrl(record);	
		}		
		this.insertSysSyncError(record);
		LOG.info("insert Error success ");

		
	}
	
	
	public FyTbSysSyncCntrlDTO  insertSysSyncCntrl(FyTbSysSyncCntrlDTO record) {
		
		uFyTbSysSyncCntrlMapper.insert(record);
		
		return record;
	
	}
	
	public FyTbSysSyncConfDTO  getSysSyncConf(FyTbSysSyncConfKeyDTO id) throws  SYSException {
	
		return uFyTbSysSyncConfMapper.getSysSyncConf(id);
	}
	
	
	public List<FyTbSysSyncCntrlDTO>   querySysSyncCntrl(CntrlReadConditionDTO cond) throws Exception {
		
		
		
		List<FyTbSysSyncCntrlDTO> lsdto=uFyTbSysSyncCntrlMapper.querySysSyncCntrlBymudelId(cond);
		
		return lsdto;
	
	}
	
	public FyTbSysSyncLogDTO  insertSysSyncLog(FyTbSysSyncCntrlDTO record) {
		
		FyTbSysSyncLogDTO recordlog=new FyTbSysSyncLogDTO();
		recordlog.setActvCode(record.getActvCode());
		recordlog.setContent(record.getContent());
		recordlog.setCreateDate(record.getCreateDate());
		recordlog.setCreateUser(record.getCreateUser());
		recordlog.setEntityId(record.getEntityId());
		recordlog.setEntityType(record.getEntityType());
		recordlog.setExecName(record.getExecName());
		recordlog.setExecSort(record.getExecSort());
		recordlog.setModuleId(record.getModuleId());
		recordlog.setNextExecSort(record.getNextExecSort());
		recordlog.setRouteId(record.getRouteId());
		recordlog.setSort(record.getSort());
		recordlog.setSvcCode(record.getSvcCode());
		recordlog.setTrxId(record.getTrxId());
		recordlog.setUpdateDate(new Date());
		recordlog.setUpdateUser(record.getCreateUser());
		uFyTbSysSyncLogMapper.insertAutoKey(recordlog);
		
		return recordlog;
	
	}
	
	public FyTbSysSyncErrorDTO  insertSysSyncError(FyTbSysSyncCntrlDTO record) {
		
		FyTbSysSyncErrorDTO  error=new  FyTbSysSyncErrorDTO();
		error.setActvCode(record.getActvCode());
		error.setContent(record.getContent());
		error.setCreateDate(record.getCreateDate());
		error.setCreateUser(record.getCreateUser());
		error.setEntityId(record.getEntityId());
		error.setEntityType(record.getEntityType());
		error.setErrCode(record.getErrCode());
		error.setErrMesg(record.getErrMsg());
		error.setExecName(record.getExecName());
		error.setExecSort(record.getExecSort());
		error.setModuleId(record.getModuleId());
		error.setNextExecSort(record.getNextExecSort());
		error.setSendDate(record.getSendDate());
		error.setSort(record.getSort());
		error.setStatus(record.getStatus());
		error.setSvcCode(record.getSvcCode());
		error.setTrxId(record.getTrxId());
		error.setRouteId(record.getRouteId());
		error.setUpdateDate(new Date());	
		error.setUpdateUser(record.getCreateUser());
		uFyTbSysSyncErrorMapper.insert(error);
		
		return error;
	
	}
	
	public FyTbSysSyncCntrlKeyDTO deleteSyncCtrl (FyTbSysSyncCntrlDTO cdto) {
		
		FyTbSysSyncCntrlKeyDTO key=new FyTbSysSyncCntrlKeyDTO();
		key.setTrxId(cdto.getTrxId());
		key.setActvCode(cdto.getActvCode());
		key.setModuleId(cdto.getModuleId());
		key.setExecName(cdto.getExecName());
		key.setEntityId(cdto.getEntityId());
		uFyTbSysSyncCntrlMapper.deleteByPrimaryKey(key);
		return key;
		
	}
	public long countSysFromError(FyTbSysSyncCntrlDTO dto) {
	
		FyTbSysSyncErrorExampleDTO example=new FyTbSysSyncErrorExampleDTO();
		com.foyatech.hgb.model.dto.FyTbSysSyncErrorExampleDTO.Criteria cr=example.createCriteria();
		cr.andEntityTypeEqualTo(dto.getEntityType());
		cr.andRouteIdEqualTo(dto.getRouteId());
		cr.andModuleIdEqualTo(dto.getModuleId());
		cr.andStatusEqualTo("E");
		long s=uFyTbSysSyncErrorMapper.countByExample(example );
		return  s;
	}
	
}

