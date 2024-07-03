package com.foyatech.hgb.batch.writer;

import java.util.ArrayList;
import java.util.List;

import org.junit.Before;
import org.junit.Test;
import org.mockito.InjectMocks;
import org.mockito.MockitoAnnotations;

import com.foyatech.hgb.model.dto.FyTbSysSyncCntrlDTO;

public class SendCntrlWriterTest {

	@InjectMocks
	private SendCntrlWriter sendCntrlWriter;
	
	@Before
	public void init() throws Exception {	
		
		MockitoAnnotations.initMocks(this);
	}
	
	@Test
	public void test() throws Exception{
		
		List<? extends FyTbSysSyncCntrlDTO> items = new ArrayList<>();
		
		sendCntrlWriter.write(items);
	}
	
}
