package com.foyatech.hgb.batch.service;

import java.text.SimpleDateFormat;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.foyatech.hgb.dao.UFyTOProcedureMapper;

import com.foyatech.hgb.enums.ActvCode;
import com.foyatech.hgb.model.common.TransactionInfo;
import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;
import com.foyatech.hgb.model.sync.HEADER;
import com.foyatech.hgb.model.sync.SyncAccount;
import com.foyatech.hgb.model.sync.SyncAccountContext;
import com.foyatech.hgb.model.sync.SyncAccountInfo;
import com.foyatech.hgb.model.sync.SyncCustomer;
import com.foyatech.hgb.model.sync.SyncCustomerContext;
import com.foyatech.hgb.model.sync.SyncCustomerInfo;

import com.foyatech.hgb.model.sync.SyncOu;
import com.foyatech.hgb.model.sync.SyncOuContext;
import com.foyatech.hgb.model.sync.SyncOuInfo;
import com.foyatech.hgb.model.sync.SyncPubData;
import com.foyatech.hgb.model.sync.SyncRootEntity;
import com.foyatech.hgb.model.sync.SyncSubscriber;
import com.foyatech.hgb.model.sync.SyncSubscriberContext;
import com.foyatech.hgb.model.sync.SyncSubscriberInfo;
import com.foyatech.hgb.model.sync.SyncPubData.DATA;
import com.foyatech.hgb.model.sys.FYTSysSyncCommon;

import com.foyatech.hgb.util.SysXmlUtil;

@Service
public class ProceService {
     
	private static final Logger LOG = LoggerFactory.getLogger(ProceService.class);
	
	@Autowired
	private UFyTOProcedureMapper uFyTOProcedureMapper;
	
	@Autowired
	private SysXmlUtil syncXmlUtil;
	
	//@Transactional(propagation=Propagation.REQUIRES_NEW)
	public FYTSysSyncCommon execProc(FyTbSysSyncCntrlDTO dto) throws Exception {
		
		LOG.info("trxId : {}, execProc : {}", dto.getTrxId(), dto.getExecName());
		String newXml = dto.getContent();
		LOG.debug(newXml);
		
		SyncPubData syncData=syncXmlUtil.getSyncObject(dto.getActvCode(), newXml);
		LOG.info("trxId : {}, trans xml success ", dto.getTrxId());
	       FYTSysSyncCommon dtoCommon=new FYTSysSyncCommon();
	       DATA data=syncData.getData();
	       HEADER header=syncData.getHeader();
	       String entity_type=header.getEntityType();
	       TransactionInfo tr=data.getTransactionInfo();
	       dtoCommon.setRsnCode(tr.getRsnCode());
	   		dtoCommon.setTranId(tr.getTrxId());
	   		dtoCommon.setTrxDate(tr.getExeDate().toGregorianCalendar().getTime());
	   		SyncRootEntity entity=data.getRootEntity();
	   		SyncOu ou=entity.getOu();
	   		SyncSubscriber subscriber=entity.getSubscriber();
	   		SyncAccount account=entity.getAccount();
	   		SyncCustomer customer=entity.getCustomer();
	   		
	   		if(entity_type.equals("O")) {
	   			
	   			SyncOuContext con=ou.getOuContext();
	   			SyncOuInfo info=ou.getOuInfo();
	   			if(con.getAcctId()!=null)dtoCommon.setAcctId(con.getAcctId());
	   			
	   			if(con.getOuId()!=null)dtoCommon.setOuId(con.getOuId());
	   			if(con.getCustId()!=null)dtoCommon.setCustId(con.getCustId());
	   			
	   			dtoCommon.setEffDate(info.getEffDate())   ;
	   			dtoCommon.setEndDate(info.getEndDate());
	   			
	   			
	   		}else if(entity_type.equals("S")){
	   			SyncSubscriberContext con= subscriber.getSubscriberContext();
	   			SyncSubscriberInfo oldsub=entity.getOldSubscriberInfo();
	   			SyncSubscriberInfo info=subscriber.getSubscriberInfo();
	   			
	   			dtoCommon.setAcctId(con.getAcctId());	
	   			dtoCommon.setCustId(con.getCustId());
	   			dtoCommon.setOuId(con.getOuId());
	   			dtoCommon.setSubscrId(con.getSubscrId());
	   			dtoCommon.setEffDate(info.getInitActDate())   ; 
	   			
	   			if(dto.getActvCode().equals(ActvCode.CANCEL_SUB.name())|dto.getActvCode().equals(ActvCode.RESTORE_SUB.name())|dto.getActvCode().equals(ActvCode.SUSPEND_SUB.name())) {//CANCEL_SUB,RESTORE_SUB,SUSPEND_SUB
	   				dtoCommon.setNewValue(info.getStatus());
	   				dtoCommon.setOldValue(oldsub.getStatus());
	   			}else if(dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_DATES.name())){
	   				SimpleDateFormat df1 = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss"); 
	   				dtoCommon.setNewValue(df1.format(info.getStatusDate()) );	
	   				dtoCommon.setOldValue(df1.format(oldsub.getStatusDate()));
	   			}
	   			dtoCommon.setStatus(info.getStatus());
	   			dtoCommon.setStatusDate(info.getStatusDate());
	   			dtoCommon.setEndDate(info.getEndDate());
				//SR233414 externalID might be "4G=324565558" 
	   			if(con.getPrevSubId()!=null) {
	   				dtoCommon.setPrevSubId(con.getPrevSubId());
	   			}else if(con.getExternalId()!=null) {
	   				//dtoCommon.setPrevSubId(Long.parseLong(con.getExternalId().substring(con.getExternalId().indexOf("=")+1,con.getExternalId().length())));
						if ( con.getExternalId().indexOf("=") > 0 ) //20230221_Project M修改亞太資料中，非"="的資料會造成SYNC ERROR，而"-"號後的資料為亞太SUB，不需處理
							dtoCommon.setPrevSubId(Long.parseLong(con.getExternalId().substring(con.getExternalId().indexOf("=")+1,con.getExternalId().length())));
	   			}
	   			if(info.getSubscrType()!=null)dtoCommon.setSubscriberType(info.getSubscrType());
	   			if(dto.getActvCode().equals(ActvCode.NEW_SUB_ACTIVATION.name())) {
	   				
	   			  dtoCommon.setNewAttr((subscriber.getAttributeParamInfoList()!=null&&subscriber.getAttributeParamInfoList().getAttributeParamInfo().size()>0)?subscriber.getAttributeParamInfoList().getAttributeParamInfo():null);
					dtoCommon.setNewOffer((subscriber.getOfferInfoList()!=null&&subscriber.getOfferInfoList().getOfferInfo().size()>0)?subscriber.getOfferInfoList().getOfferInfo():null);
					dtoCommon.setNewParam((subscriber.getOfferParamList()!=null&&subscriber.getOfferParamList().getOfferParam().size()>0)?subscriber.getOfferParamList().getOfferParam():null);
					dtoCommon.setNewResource((subscriber.getResourceParamList()!=null&&subscriber.getResourceParamList().getResourceParam().size()>0)?subscriber.getResourceParamList().getResourceParam():null);
		    	 
	   			
	   			}else if(dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_EFF_DATE.name())||
						dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_END_DATE.name())||
						dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_FUTURE_END_DATE.name())||
						dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_ORIG_EFF_DATE.name())) {
	   				
	   				dtoCommon.setNewAttr((entity.getNewAttributeParamList()!=null&&entity.getNewAttributeParamList().getAttributeParamInfo().size()>0)?entity.getNewAttributeParamList().getAttributeParamInfo():null);
	   				dtoCommon.setNewOffer((subscriber.getOfferInfoList()!=null&&subscriber.getOfferInfoList().getOfferInfo().size()>0)?subscriber.getOfferInfoList().getOfferInfo():null);
					dtoCommon.setNewParam((entity.getNewOfferParamList()!=null&&entity.getNewOfferParamList().getOfferParam().size()>0)?entity.getNewOfferParamList().getOfferParam():null);
					dtoCommon.setNewResource((entity.getNewResourceParamList()!=null&&entity.getNewResourceParamList().getResourceParam().size()>0)?entity.getNewResourceParamList().getResourceParam():null);

	   			}
	   		}else if(entity_type.equals("A")){
	   			
	   			SyncAccountContext  con= account.getAccountContext();
	   			
	   			LOG.debug("==getAcctId==="+con.getAcctId().toString());
	   			SyncAccountInfo info=account.getAccountInfo();
	   			dtoCommon.setAcctId(con.getAcctId());	
	   			dtoCommon.setCustId(con.getCustId());
	   			if(con.getOuId()!=null)dtoCommon.setOuId(con.getOuId());
	   			
	   			dtoCommon.setEffDate(info.getEffDate())   ;
	   			dtoCommon.setStatus(info.getStatus());
	   			dtoCommon.setStatusDate(info.getStatusDate());
	   			if(info.getEndDate()!=null)dtoCommon.setEndDate(info.getEndDate());
	   			
	   		}else if(entity_type.equals("C")){
	   			SyncCustomerContext con= customer.getCustomerContext();
	   			SyncCustomerInfo  info=customer.getCustomerInfo();
	   			
	   			dtoCommon.setCustId(con.getCustId());
	   			
	   			LOG.debug("effdate:{}",info.getEffDate());
	   			dtoCommon.setEffDate(info.getEffDate())   ;
	   			LOG.debug("ActvCode.NEW_CUSTOMER:{}",ActvCode.NEW_CUSTOMER+"==");
	   			if(dto.getActvCode().equals(ActvCode.NEW_CUSTOMER.name())) {
	   				dtoCommon.setNewValue((info.getCycleInfo().getCycle()!=null)?info.getCycleInfo().getCycle().toString():null);
	   				LOG.debug("Cycle:{}",dtoCommon.getNewValue());
	   			}else if(dto.getActvCode().equals(ActvCode.CHGCYC.name())){
	   				dtoCommon.setNewValue((info.getCycleInfo().getNewCycle()!=null)?info.getCycleInfo().getNewCycle().toString():null);	
	   				dtoCommon.setOldValue((info.getCycleInfo().getCycle()!=null)?info.getCycleInfo().getCycle().toString():null);	
		   			
	   			}
	   			if(info.getEndDate()!=null)dtoCommon.setEndDate(info.getEndDate());
	   			
	   		}

			dtoCommon.setChargeCode(tr.getChargeCode());
			if(dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_EFF_DATE.name())) {
				dtoCommon.setDateType("EFF");	
			}else if(dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_END_DATE.name())) {
				dtoCommon.setDateType("END");	
			}else if(dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_FUTURE_END_DATE.name())) {
				dtoCommon.setDateType("FUTURE");	//dtoCommon.setDateType("FETURE");	
			}else if(dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_ORIG_EFF_DATE.name())) {
				dtoCommon.setDateType("ORIG_EFF");	
			}else if(dto.getActvCode().equals(ActvCode.CANCEL_SUB.name())) {
				dtoCommon.setDateType("CANCEL");	
			}else if(dto.getActvCode().equals(ActvCode.RESTORE_SUB.name())) {
				dtoCommon.setDateType("RESTORE");	
			}else if(dto.getActvCode().equals(ActvCode.SUSPEND_SUB.name())) {
				dtoCommon.setDateType("SUSPEND");	
			}
			
			
			
	       if(!(entity_type.equals("S")&&(dto.getActvCode().equals(ActvCode.NEW_SUB_ACTIVATION.name())||dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_EFF_DATE.name())||
					dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_END_DATE.name())||
					dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_FUTURE_END_DATE.name())||
					dto.getActvCode().equals(ActvCode.UPDATE_SUBSCRIBER_OFFER_ORIG_EFF_DATE.name())))) {
	    	   LOG.debug("NOT NEW_SUB_ACTIVATION st Offer");
	    	    
	    	    dtoCommon.setNewAttr((entity.getNewAttributeParamList()!=null&&entity.getNewAttributeParamList().getAttributeParamInfo().size()>0)?entity.getNewAttributeParamList().getAttributeParamInfo():null);
	    	    dtoCommon.setNewOffer((entity.getAddOfferInfoList()!=null&&entity.getAddOfferInfoList().getOfferInfo().size()>0)?entity.getAddOfferInfoList().getOfferInfo():null);
				dtoCommon.setNewParam((entity.getNewOfferParamList()!=null&&entity.getNewOfferParamList().getOfferParam().size()>0)?entity.getNewOfferParamList().getOfferParam():null);
				dtoCommon.setNewResource((entity.getNewResourceParamList()!=null&&entity.getNewResourceParamList().getResourceParam().size()>0)?entity.getNewResourceParamList().getResourceParam():null);
	    	   
	       }
			
			dtoCommon.setOldAttr((entity.getOldAttributeParamList()!=null&&entity.getOldAttributeParamList().getAttributeParamInfo().size()>0)?entity.getOldAttributeParamList().getAttributeParamInfo():null);
			dtoCommon.setOldOffer((entity.getRemoveOfferInfoList()!=null&&entity.getRemoveOfferInfoList().getOfferInfo().size()>0)?entity.getRemoveOfferInfoList().getOfferInfo():null);
			dtoCommon.setOldParam((entity.getOldOfferParamList()!=null&&entity.getOldOfferParamList().getOfferParam().size()>0)?entity.getOldOfferParamList().getOfferParam():null);
			
			dtoCommon.setOldResource((entity.getOldResourceParamList()!=null&&entity.getOldResourceParamList().getResourceParam().size()>0)?entity.getOldResourceParamList().getResourceParam():null);
			if(dto.getActvCode().equals(ActvCode.CHGCYC.name())){
				//將actvCode 轉換 CHGCYC->CHANGECYCLECONF
   				dtoCommon.setRemark(dto.getContent()
   						.replaceAll("CHGCYC", "BLCHANGECYCLECONF").replaceAll("chgcyc", "blchangecycleconf"));
   			}
			

			dtoCommon.setProcName(dto.getExecName());//("FETMAN.My_Test_TYPE.Test2")
			
			dtoCommon.setWaiveIndicator(tr.getWaiveIndicator());
			
		    try {
		    	
		    ObjectMapper mapper = new ObjectMapper();

		    	  //Object to JSON in String
		    String jsonInString = mapper.writeValueAsString(dtoCommon);
		    LOG.info("========= procName : {}, input :{} ==============",dto.getExecName(),jsonInString);
		    	
			uFyTOProcedureMapper.execProc(dtoCommon);		   

		    }catch(Exception e) {
		    	LOG.error(e.getMessage(), e);
		    	if(dtoCommon.getErrCde()==null) {

	    			dtoCommon.setErrCde("9998");
		    		dtoCommon.setErrMsg(e.toString().substring(0, 350));
		    		LOG.info("error :::{}",e.toString());
		    		LOG.info("errcode :::{}",dtoCommon.getErrCde());
		    		LOG.info("Msg :::{}",dtoCommon.getErrMsg());
		    			    		
		    	}		    	
		    }
            
		    //dtoCommon.setErrCde("A01")
		   // dtoCommon.setErrMsg("error 測試")
		 
		/*if(!dtoCommon.getErrCde().equals("0000")) {
			
			throw new SYSException(dtoCommon.getErrCde(),dtoCommon.getErrMsg());	
		}*/
		    
		LOG.info("poErrCde:{}",dtoCommon.getErrCde());
		LOG.info("poErrMsg:{}",dtoCommon.getErrMsg());
		
		return dtoCommon;
		
	}	
}

