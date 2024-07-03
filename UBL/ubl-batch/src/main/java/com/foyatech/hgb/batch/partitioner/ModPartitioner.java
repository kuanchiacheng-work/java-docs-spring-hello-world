package com.foyatech.hgb.batch.partitioner;

import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.partition.support.Partitioner;
import org.springframework.batch.item.ExecutionContext;

public class ModPartitioner implements Partitioner {
	
	private static final Logger LOG = LoggerFactory.getLogger(ModPartitioner.class);

	  @Override
	  public Map<String, ExecutionContext> partition(int gridSize) {
		  LOG.info("partition called gridsize= " + gridSize);
	 
	    Map<String, ExecutionContext> result
	        = new HashMap<String, ExecutionContext>();	 
	 
	    for (int i = 0; i < gridSize; i++) {
	      ExecutionContext value = new ExecutionContext();	 
	      value.putInt("modNum", i);
	 
	      result.put("partition" + i, value);
	 
	    }
	    return result;
	  }
	}
