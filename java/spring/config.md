# 配置文件             
## Web.xml 结构说明
- web-app            
该元素是部署描述的根元素。
- display-name          
定义 web 应用的名称。
- context-param          
用做 servlet 上下文初始化参数。在 web 应用的整个生命周期都存在，任意 servlet 和 jsp 均能访问它。 `param-name`即参数名，`param-value`即参数值。若不配置 context-param，则默认配置路经为 `/WEB-INF/applicationContext.xml`。若需自定义文件名可指定 `contextConfigLocation`这个参数，若值为 `classpath*:applicationContext.xml`则加入所有 jar 中 classpath 中的 applicationContext.xml 文件；若值为 `classpath:applicationContext.xml`则只加入本项目 classpath 中的 applicationContext.xml 文件。
- listener          
listener 是在 application, session, request 三个对象创建，销毁，或者修改删除属性时自动执行代码的功能组件。在 context-param 中配置`contextConfigLocation`，还需在 listener 中配置相应 lisenter-class。
- session-config       
设置容量 session 参数。
- filter         
既对用户请求进行预处理，也能对服务器响应进行后处理。一般有解码Filter，日志Filter等。
- servlet          
配置 Servlet 时，需要配置 servlet 和 servlet-mapping，servlet 中可配置 init-param 子元素，用于将初始化参数传递给 servlet。init-param 与 context-param 具有相同的元素描述符。servlet 中配置的 load-on-startup 表示是否在容器启动时加载这个 servelt，若大于等于 0 则加载，值越小越优先加载；小于0或未指定则表示需要时再加载。

## `<servletName>-servlet.xml` 
- <context:annotation-config />             
隐式的向Spring容器注册 AutowiredAnnotationBeanPostProcessor（用于使用 @Autowired 注解）、CommonAnnotationBeanPostProcessor（用于使用 @Resource、@PostConstruct 等注解）、PersistenceAnnotationBeanPostProcessor（用于使用 @PersistenceContext 注解。）、RequiredAnnotationBeanPostProcessor（用于使用 @Required 注解）这 4 个BeanPostProcessor。
- <context:component-scan base-package="xxx" />       
扫描 base-package 下的 Java 文件，若扫描到 @Component、@Controller、@Service、@Repository 等注解，则将这些类注册为 bean。因此使用 <context:component-scan /> 后，可去掉 <context:annotation-config />。
- <mvc:annotation-driven />              
注册了一个 `RequestMappingHandlerMapping`, `RequestMappingHandlerAdapter`, `ExceptionHandlerExceptionResolver`，同时开启了 @NumberFormat、@DateTimeFormat 等功能的支持。具体见 https://docs.spring.io/spring/docs/current/spring-framework-reference/html/mvc.html#mvc-config-enable 。
- <mvc:default-servlet-handler />        
在springMVC-servlet.xml中配置 `<mvc:default-servlet-handler />` 后，会在Spring MVC上下文中定义一个org.springframework.web.servlet.resource.DefaultServletHttpRequestHandler，它会像一个检查员，对进入 DispatcherServlet 的 URL 进行筛查，如果发现是静态资源的请求，就将该请求转由 Web 应用服务器默认的 Servlet 处理，如果不是静态资源的请求，才由DispatcherServlet 继续处理。
- <mvc:argument-resolvers />         
参数解析器。
- <context:property-placeholder />         
将配置文件放在单独的文件中，使用该标签可以访问配置文件，配置文件路径同 location 指定。
- <aop:aspectj-autoproxy />    
自动为 spring 容器中那些配置 @aspectJ 切面的 bean 创建代理，调用切面。

`<aop:aspectj-autoproxy proxy-target-class="true" />`：
如果proxy-target-class 属性值被设置为true，那么基于类的代理将起作用（这时需要cglib库）。如果proxy-target-class属值被设置为false或者这个属性被省略，那么标准的JDK 基于接口的代理将起作用。

## 分析
目前有生产和测试两个环境，其中测试配置文件有 db-test.xml 和 db-test.properties，内容如下：
```
// db-test.xml
<context:property-placeholder location="classpath*:db-test.properties"/>
<jpa:repositories base-package="com.x.y.repository"/>
<jpa:auditing/>
<tx:annotation-driven transaction-manager="transactionManager"/>
<bean id="dataSource" class="com.mchange.v2.c3p0.ComboPooledDataSource">
    <property name="driverClass" value="${jdbc.driver}"/>
    <property name="jdbcUrl" value="${jdbc.url}"/>
    <property name="user" value="${jdbc.username}"/>
    <property name="password" value="${jdbc.password}"/>
</bean>

// db-test.properties
jdbc.driver=com.mysql.jdbc.Driver
jdbc.url=jdbc:mysql://X
jdbc.username=Y
jdbc.password=Z
```

生产配置文件为 db-prod.xml 和 db-properties，内容如下：
```
// db-prod.xml
<context:property-placeholder location="classpath*:db-prod.properties"/>
<jpa:repositories base-package="com.x.y.repository"/>
<jpa:auditing/>
<tx:annotation-driven transaction-manager="transactionManager"/>
<bean id="dataSource" class="com.mchange.v2.c3p0.ComboPooledDataSource">
    <property name="driverClass" value="${jdbc.driver}"/>
    <property name="jdbcUrl" value="${jdbc.url}"/>
    <property name="user" value="${jdbc.username}"/>
    <property name="password" value="${jdbc.password}"/>
</bean>

// db-prod.properties
jdbc.driver=com.mysql.jdbc.Driver
jdbc.url=jdbc:mysql://A
jdbc.username=B
jdbc.password=C
```

在 applicationContext.xml 文件中，有如下语句：
```
<context:property-placeholder location="classpath*:*.properties"/>

<!--<import resource="classpath*:db-prod.xml"/>-->
<import resource="classpath*:db-test.xml"/>
```
如上所示，在运行测试环境时，注释掉 import db-prod 后，实际数据库连接仍为 db-prod.properties，很明显，由于配置`<context:property-placeholder location="classpath*:*.properties"/>`，导致 db-prod.properties 覆盖了 db-test.properties 的配置。此时自然而然的想到有两种方法来解决这个问题：
1. 只加载需要的 db-test.properties 文件；     
2. 同时 db-test.xml 文件和 db-test.properties 文件中的属性名，和 db-prod.xml 中同名属性区分，即将 `jdbc.url`、`jdbc.username`、`jdbc.password` 分别修改为 `jdbc.url.test`、`jdbc.username.test`、`jdbc.password.test`。这里依次尝试这 2 种方法。

使用方法1：将`<context:property-placeholder location="classpath*:*.properties"/>` 修改为
```
//导入其它文件
<context:property-placeholder location="classpath:X.properties"/>
//导入db-test.properties 
<context:property-placeholder location="classpath:config.properties"/>
```
此时报错：`Invalid bean definition with name 'dataSource' defined in URL [jar:file....]. Could not resolve placeholder 'jdbc.url.test' in string value "${jdbc.url.test}"`，很奇怪，明明定义了该属性却找不到，查看 tomcat log，知 db-test.properties 并未加载。参考 [关于 context:property-placeholder 的一个有趣现象](http://www.iteye.com/topic/1131688) 和 [Multiple Spring PropertyPlaceholderConfigurer at the same time](https://stackoverflow.com/questions/18697050/multiple-spring-propertyplaceholderconfigurer-at-the-same-time)，修改上述配置为：
```
//导入其它文件
<context:property-placeholder location="classpath:X.properties" ignore-unresolvable="true"/>
//导入db-test.properties
<context:property-placeholder location="classpath:config.properties"/>
```
即除最后一个`context:property-placeholder`外，其余`context:property-placeholder`均加`ignore-unresolvable="true"`这个属性。问题解决。

使用方法2修改相同属性名，然后将所有db-test.properties 和 db-prod.properties 合并为一个文件。该方法不需要`<context:property-placeholder location="classpath*:*.properties"/>`。可解决问题。

以上两种方法，方法2优于方法1，一是所有配置合为一处，二是可能方法2需要配置多个<context:property-placeholder location="X" ignore-unresolvable="true">，略显繁琐。
