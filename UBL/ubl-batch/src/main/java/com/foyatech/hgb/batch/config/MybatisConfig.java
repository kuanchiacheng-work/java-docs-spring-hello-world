package com.foyatech.hgb.batch.config;

import java.beans.PropertyVetoException;

import javax.sql.DataSource;

import org.apache.commons.lang3.StringUtils;
import org.apache.ibatis.io.VFS;
import org.apache.ibatis.session.SqlSessionFactory;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.annotation.MapperScan;
import org.mybatis.spring.boot.autoconfigure.SpringBootVFS;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.repository.support.JobRepositoryFactoryBean;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;

import com.foyatech.hgb.util.CmdExecContext;
import com.foyatech.hgb.util.CmdExecUtil;
import com.mchange.v2.c3p0.ComboPooledDataSource;

@Configuration
@EnableTransactionManagement(order = Ordered.HIGHEST_PRECEDENCE)
@MapperScan(basePackages = "com.foyatech.hgb.dao", sqlSessionFactoryRef = "sqlSessionFactory")
public class MybatisConfig {

	private static final Logger LOG = LoggerFactory.getLogger(MybatisConfig.class);
	// dataSource
	@Value("${spring.datasource.driver-class-name}")
	private String driverClass;
	@Value("${spring.datasource.url}")
	private String jdbcUrl;
	@Value("${spring.datasource.username}")
	private String user;
	@Value("${spring.datasource.password}")
	private String password;
	@Value("${spring.datasource.maxPoolSize}")
	private int maxPoolSize;
	@Value("${spring.datasource.minPoolSize}")
	private int minPoolSize;
	@Value("${spring.datasource.initialPoolSize}")
	private int initialPoolSize;
	@Value("${spring.datasource.prefix}")
	private String prefix;
	@Value("${spring.datasource.getIdCmd}")
	private String getIdCmd;
	@Value("${spring.datasource.getPwCmd}")
	private String getPwCmd;
	@Value("${spring.datasource.maxIdleTime}")
	private int maxIdleTime;
	
	
	private static final int TIMEOUT = 10000;

	// jndi
	//@Value("${spring.datasource.jndi-name}")
	//private String jndiName;
	
	
	@Autowired
    private PlatformTransactionManager transactionManager;

	@Bean
	public SqlSessionFactory sqlSessionFactory(DataSource dataSource) throws Exception {
		SqlSessionFactoryBean factoryBean = new SqlSessionFactoryBean();
		factoryBean.setDataSource(dataSource);
		
		VFS.addImplClass(SpringBootVFS.class);
		factoryBean.setTypeAliasesPackage("com.foyatech.hgb.model");
		return factoryBean.getObject();
	}

	// local datasource
	@Bean
	public DataSource dataSource() throws PropertyVetoException {
		ComboPooledDataSource dataSource = new ComboPooledDataSource();
		dataSource.setDriverClass(driverClass);
		dataSource.setJdbcUrl(jdbcUrl);
		//dataSource.setUser(user);
		//dataSource.setPassword(password);
		CmdExecContext getIdResult = CmdExecUtil.executeCommand(new String[] {getIdCmd, prefix}, TIMEOUT);
		dataSource.setUser(StringUtils.trim(getIdResult.getExecContent()));
		
		CmdExecContext getPwResult = CmdExecUtil.executeCommand(new String[] {getPwCmd, prefix}, TIMEOUT);
		dataSource.setPassword(StringUtils.trim(getPwResult.getExecContent()));
		
		dataSource.setInitialPoolSize(initialPoolSize);
		dataSource.setMaxPoolSize(maxPoolSize);
		dataSource.setMinPoolSize(minPoolSize);
		dataSource.setAcquireRetryAttempts(30);
		dataSource.setAcquireRetryDelay(1000);
		
		 dataSource.setMaxIdleTime(maxIdleTime);
		return dataSource;
	}
	
	
	
	/*@Bean
	public DataSourceTransactionManager transactionManager() throws PropertyVetoException {
		
		DataSourceTransactionManager ds=new DataSourceTransactionManager();
		ds.setDataSource(this.dataSource());
		return ds;
		
	}*/
	
	
	
	
	
	@Bean
	public JobRepository jobRepositoryFactoryBean() throws Exception {
	    JobRepositoryFactoryBean fb = new JobRepositoryFactoryBean();
	    fb.setDatabaseType("Oracle");
	    fb.setDataSource(this.dataSource());
	    fb.setTransactionManager(transactionManager);
	    fb.setIsolationLevelForCreate("ISOLATION_READ_COMMITTED");
	    
    	LOG.info("*************set jobRepositoryFactoryBean*****************"+fb.getJobRepository().toString());
	    return fb.getObject();
	}

	
	
	
	

	// jndi
	/*
	 * @Bean public DataSource dataSource() throws PropertyVetoException {
	 * JndiDataSourceLookup dataSourceLookup = new JndiDataSourceLookup();
	 * DataSource dataSource = dataSourceLookup.getDataSource(jndiName); return
	 * dataSource; }
	 */
}