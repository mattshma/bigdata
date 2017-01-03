# Log4j介绍

log4j有1.x和2.x之分，1.x已不再更新，不过由于Hadoop系统大部分服务仍使用log4j 1.x做为日志配置文件，所以这里简要说明下log4j 1.x，以下log4j均指log4j 1.x。

## 主要组件
Log4j有三个主要的组件：logger, appender 和 layout，这三个组件共同定义了log4j的日志信息格式。

### Logger
logger组件负责获取日志信息，并将日志信息存储在日志命名空间中。logger命名大小写敏感，且遵循分层命名规则：**祖先与后代与`.`做分隔**，如"com.foo"，"com"是"foo"的祖先。根logger位于logger层级最上去，其一直存在，且不能通过name调用，需使用静态方法[getRootLogger](http://logging.apache.org/log4j/1.2/apidocs/org/apache/log4j/Logger.html#getRootLogger)调用。

logger可以指定级别，这些级别在[Level](http://logging.apache.org/log4j/1.2/apidocs/org/apache/log4j/Level.html)中定义，有如下几种级别：

- ALL
- TRACE
- TRACE_INT
- DEBUG
- INFO
- WARN
- ERROR
- FATAL
- OFF

还可以通过继承Level类自定义logger级别。如果一个logger对象没有指定日志级别，则其继承它最近的祖先logger的日志级别。为保证所有logger最终都有各自日志级别，因此root logger须指定一个日志级别。

### Appender
appender组件负责将日志信息发往不同的目的地，一般而言，有如下几种appender：
- console
- file
- GUI
- Remote socket server
- JMS
- NT Event Loggers
- Remote UNIX Syslog Daemon

每个logger对象能分发一个或多个appender。appender有个特性：append累加性（appender additivity）-- logger指定appender后，logger后代也会继承该appender。

log4j提供了如下appender:

- AppenderSkeleton
- AsyncAppender
- ConsoleAppender
- DailyRollingFileAppender
- ExternallyRolledFileAppender
- FileAppender
- JDBCAppender
- JMSAppender
- LF5Appender
- NTEventLogAppender
- NullAppender
- RollingFileAppender
- SMTPAppender
- SocketAppender
- SocketHubAppender
- SyslogAppender
- TelnetAppender
- WriterAppender

appender都有如下通用属性：

  属性   | 描述
---------|-------------
 layout  | appender使用layout等格式化日志信息
 target  | appender目的地
 level   | 日志级别
 threshold | appender可脱离日志级别定义一个阈值信息，appender会忽略的已有级别低于阀值级别的日志
 filter   | filter在级别基础上分析日志信息，来过滤某些日志记录

对于较常见的FileAppender，其还有如下属性：

  属性   | 描述
---------|------------
 immediateFlush | 每条日志立即刷新到文件中，默认为true
 encoding   |  编码方式
 File  | 日志文件名
 Append  | 日志追加到文件末尾，默认为true
 bufferedIO  | 是否打开缓冲区写，默认为false
 bufferSize  | 缓冲区大小，默认为8kb 
  
若需要按大小将日志分为多个文件，可使用RollingFileAppender，额外属性如下：

 属性   | 描述
---------|------------
maxFileSize | 日志文件最大值，默认10MB
maxBackupIndex | 文件备份数，默认为1

若需要按天将日志分成多个文件，可使用DailyRollingFileAppender，额外属性如下：

属性   | 描述
---------|----------
DatePattern | 在什么时间滚动日志文件，并约定文件名，默认是每天凌晨滚动

### Layout
layout用设置日志信息格式。有如下种layout：
- DateLayout
- HTMLLayout
- PatternLayout
- SimpleLayout
- XMLLayout

HTMLLayout是一种很简单的Layout对象，其有如下属性：

  属性   | 描述
---------|----------
 Title   |  设置html文件的标题
 LocationInfo | 设置日志事件的地域信息
 ContentType | 设置HTML的内容类型，默认为text/html

PatternLayout是最常用的Layout对象，其属性如下：

  属性   | 描述
---------|----------
 conversionPattern | 设置转换模式，设置为`%r [%t] %p %c %x - %m%n`

关于模式转换字符，含义如下：

 转换字符  | 含义
-----------|---------
  c      | 为输出日志事件分类，允许使用%c{数字}进行分类（从右往左数），对于分类`a.b.c`，`%c` 输出`a.b.c`，`%c{1}`输出`c`
  C      | 输出日志请求的类的命名，对于类`com.log4j.Log4jTest`，`%C{2}`输出`log4j.Log4jTest`
  d      | 输出记录日志的日期，如`%d{HH:mm:ss, SSSS}`
  F      | 记录日志时输出文件名
  l      | 输出生成日志调用者的地域信息
  L      | 使用它输出发起日志请求的行号
  m      | 输出应用提供的信息
  M      | 输出日志请求的方法名 
  n      | 输出平台相关的换行符
  p      | 输出日志事件的优先级
  r      | 输出从构建布局到生成日志事件所花费的时间，以毫秒为单位
  t      | 输出生成日志事件的线程名
  x      | 输出和生成日志事件线程相关的嵌套诊断上下文
  %      | 使用 `%%` 输出`%`

另外，还可以设置上述参数内容的最小长度：在%和参数符号之间加最小长度数字，正数表示右对齐，负数表示左对齐，数字表示最小宽度，不够的地方用空格补上。如`%10p`表示右对齐日志级别，`%-10p`表示左齐日志级别。还可以使用 **小数点+数字** 的方式设置最大宽度，超出最大宽度的地位会被截断，如`%0.30p`。

## 参考
- [log4j manual](http://logging.apache.org/log4j/1.2/manual.html)
- [log4j faq](http://logging.apache.org/log4j/1.2/faq.html)
