package com.foyatech.hgb.batch.until;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;

public class XmlUtil {

	
	public static String getFileContent(String path) throws IOException {
		Resource resource = new ClassPathResource(path);
		StringBuilder sb = new StringBuilder();
		BufferedReader reader = new BufferedReader( new InputStreamReader(resource.getInputStream()));
		reader.lines().forEach(sb::append);
        return sb.toString();
	}
}
