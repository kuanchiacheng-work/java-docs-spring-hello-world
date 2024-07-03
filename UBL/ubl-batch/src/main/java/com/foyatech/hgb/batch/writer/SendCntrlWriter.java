package com.foyatech.hgb.batch.writer;

import java.util.List;

import org.springframework.batch.item.ItemWriter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;


import com.foyatech.hgb.dao.UFyTbSysSyncCntrlMapper;
import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;


@Service
public class SendCntrlWriter implements ItemWriter<FyTbSysSyncCntrlDTO> {

	@Autowired  
	private UFyTbSysSyncCntrlMapper sendCntrlMapper;	
	
	@Override
	public void write(List<? extends FyTbSysSyncCntrlDTO> items) throws Exception {
		
	}
}