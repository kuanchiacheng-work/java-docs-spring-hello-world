package com.foyatech.hgb.batch.partitioner;

import org.junit.Before;
import org.junit.Test;
import org.mockito.InjectMocks;
import org.mockito.MockitoAnnotations;

public class ModPartitionerTest {

	@InjectMocks
	private ModPartitioner modPartitioner;
	
	@Before
	public void init() throws Exception {
		MockitoAnnotations.initMocks(this);	
	}
	
	@Test
	public void test(){
				
		int gridSize = 123;
		
		modPartitioner.partition(gridSize);
		
		
	}
	
}
