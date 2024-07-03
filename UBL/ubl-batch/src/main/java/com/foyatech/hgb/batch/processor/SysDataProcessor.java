package com.foyatech.hgb.batch.processor;

import java.util.Date;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.item.ItemProcessor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;


import com.foyatech.hgb.batch.service.PreService;
import com.foyatech.hgb.batch.service.ProceService;
import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncConfDTO;
import com.foyatech.hgb.model.dto.FyTbSysSyncConfKeyDTO;
import com.foyatech.hgb.model.sys.FYTSysSyncCommon;

@Component
public class SysDataProcessor implements ItemProcessor<FyTbSysSyncCntrlDTO, FyTbSysSyncCntrlDTO> {

	private static final Logger LOG = LoggerFactory.getLogger(SysDataProcessor.class);

	@Autowired
	private ProceService proceService;
	
	@Autowired
	private PreService preService;
		
	@Value("${modelID}")
	private String  modelID;
	
	@Value("${sync_notifyCode}")
	private String  notifyCode;
	
	@Override
	public FyTbSysSyncCntrlDTO process(FyTbSysSyncCntrlDTO dto) throws Exception   {
		
		long s=preService.countSysFromError(dto);
		LOG.debug("query SendError");
		LOG.debug("sort:{}",dto.getSort());
		LOG.debug("S:{}",s);
		if(s>0&&dto.getTb().equals("C")) {
			dto.setStatus("P");
			dto.setCreateUser("APUSER");
			LOG.debug("insert pending ERROR");
			dto.setSendDate(new Date());
			LOG.debug("==SendDate==:{}",dto.getSendDate());
			preService.insertSysSyncError(dto);
			
			LOG.debug("insert Cntrl P to error");
			
			preService.deleteSyncCtrl(dto);
			
			LOG.debug("delete Cntrl ");
			
		} else if(s>0&&dto.getTb().equals("E")) {
			dto.setStatus("P");
			dto.setCreateUser("APUSER");
			LOG.info("error count > 0, pass process");
		} else {
			FYTSysSyncCommon common=null;
			try {
				
				LOG.debug("do PROC");
				dto.setSendDate(new Date());
				LOG.debug("==SendDate==:{}",dto.getSendDate());
				common = proceService.execProc(dto);				
			 
				if(common!=null&&common.getErrCde().equals("0000")) {
					
					LOG.debug("==common  error==:{}",common.getErrCde());
					dto.setErrCode(common.getErrCde());
					LOG.debug("==next soert==:{}",dto.getNextExecSort().toString());
					
					preService.insertSysSyncLog(dto);
					//查詢是否有下一步不等於99才有下一步
					if(dto.getNextExecSort()!=null&&dto.getNextExecSort().intValue()!=99) {
						FyTbSysSyncConfKeyDTO id=new FyTbSysSyncConfKeyDTO();
						id.setActvCode(dto.getActvCode());
						id.setModuleId(dto.getModuleId());
						id.setExecSort(dto.getNextExecSort());
						FyTbSysSyncConfDTO nextconDto=preService.getSysSyncConf(id);
						FyTbSysSyncCntrlDTO nextDto=new FyTbSysSyncCntrlDTO();
						nextDto=dto;
						nextDto.setExecName(nextconDto.getExecName());
						nextDto.setExecSort(nextconDto.getExecSort());
						nextDto.setNextExecSort(nextconDto.getNextExecSort());
						//LOG.info("==Exec2Sort==={}",nextDto.getExecName().toString());
						
						//新增sysSyncCntrl
						preService.insertSysSyncCntrl(nextDto);
					}					
				}else {//error新增error
					if(common!=null) {
					dto.setErrCode(common.getErrCde());
					dto.setErrMsg(common.getErrMsg());
					}
				    //LOG.info("errcode:"+dto.getErrCode());
				   // LOG.info("errMsg:"+dto.getErrMsg());
				   // LOG.info("sort:"+dto.getSort());
					dto.setCreateUser("APUSER");
					dto.setStatus("E");
					
					
					if(dto.getTb().equals("E")) {
					 preService.deleteSysSyncError(dto);
					}
					preService.insertSysSyncError(dto);
					LOG.debug("insert Error success ");

				}
				
				if(!dto.getTb().equals("E")) {
					preService.deleteSyncCtrl(dto);
					
				}else {
					 if(common!=null&&common.getErrCde().equals("0000")) {
						preService.deleteSysSyncError(dto);
					 }
				}
				LOG.debug(" delete sync success ");
			/*} catch (SYSException e) {
				
				LOG.info( e.getMessage() );
				common=new FYTSysSyncCommon();
				dto.setErrCode(e.getCode());
				
				dto.setErrMsg(e.getMessage().substring(0, ((e.getMessage().length()>300)?300:e.getMessage().length())));
				 LOG.info("errcode:{}",dto.getErrCode());
			    LOG.info("errMsg:{}",dto.getErrMsg());
			    //LOG.info("sort:"+dto.getSort())
				dto.setCreateUser("APUSER");
				dto.setStatus("E");				
				preService.doExceptionCntrl(dto,modelID, notifyCode);
				throw new SYSException(dto.getErrCode(),dto.getErrMsg());*/
			}catch (Exception e) {
				
				
				
				common = new FYTSysSyncCommon();
				dto.setErrCode("9999");
				//e.printStackTrace();
				LOG.error(e.toString(), e);
				dto.setErrMsg(e.toString().substring(0, ((e.toString().length()>300)?300:e.toString().length())));
				
				
			    LOG.info("errcode:{}",dto.getErrCode());
			    LOG.info("errMsg:{}",dto.getErrMsg());
			    //LOG.info("sort:"+dto.getSort())
				dto.setCreateUser("APUSER");
				dto.setStatus("E");
				preService.doExceptionCntrl(dto,modelID, notifyCode);
				//throw new SYSException(dto.getErrCode(),dto.getErrMsg());
			}
		}		
		return dto;	
	}
}
