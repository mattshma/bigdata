# Java类的加载、链接及初始化

Java代码是以字节数组(byte[])的形式存储的，而在JVM需要的是[java.lang.Class](http://docs.oracle.com/javase/8/docs/api/java/lang/Class.html)类对象。将字节码转化为类对象，需要通过加载，链接和初始化这三个步骤。

## 加载
类加载器用来加载Java类到JVM中，其可分为两类，一类是系统提供的，另一类是用户自定义的。系统提供的类加载器主要有如下三个：

- Bootstrap ClassLoader         
  启动类加载器，Java类加载层次中最顶层的类加载器，负责加载JDK中的核心类库，如rt.jar, i18n.jar等。
- Extension ClassLoader      
  扩展类加载器，负责加载Java的扩展类库，默认加载JAVA_HOME/jre/lib/ext/目录下的所有jar。
- App ClassLoader     
  系统系统加载器。负责加载应用程序classpath目录下的所有jar和class文件。

用户可继承[java.lang.ClassLoader](https://docs.oracle.com/javase/8/docs/api/java/lang/ClassLoader.html)来实现自定义类加载器。在加载类的过程中，从顶至底加载类-- Bootstrap ClassLoader --> Extension ClassLoader --> App ClassLoader --> user-definde ClassLoader。

Java类加载器有两个比较重要的特性：层次组织结构和代理模式。层次组织结构指的是每个类加载器都有一个父类加载器，通过getParent()方法引用，类加载器通过这种父亲-后代的方式组织在一起，形成树状层次结构。代理模式指类加载器既可自己完成类的定义工作，也可代理给其他类加载器完成。上面说过类加载顺序是由顶至底尝试加载的，基于类加载器的树状层次结构，一般类加载器会先代理给父类加载器加载，当父类加载器加载失败时，才会尝试自己加载。这样的好处是避免重复加载，当父类加载器已经加载该类后，就没必要再加载一次了。

类加载器的一个重要用途是在JVM中为相同名称的Java类创建隔离空间。JVM在判断两个class是否相同时，不仅要判断两个类名是否相同，还要判断是否由同一个类加载器加载的。同一份字节码文件被两个不同的类加载器加载，JVM也会认为它们是不同的类。这个特性为相同名称的Java类在JVM共存创造了条件。

## 链接
链接指将类的字节码合并到JVM的运行状态中的过程。类的链接包括验证，准备和解析几个过程。验证用来确保Java类的结构正确，准备是创建Java类中的静态域，并将这些域的值设置为默认值，准备阶段不会执行代码。Java类可能包含对其他类或接口的引用，解析过程就是确保这些引用能被正确找到。


## 初始化
当类第一次被真正使用的时候，JVM会对该类进行初始化操作。初始化过程主要是执行静态代码块和初始化静态域。

## Reference
- [Loading, Linking, and Initializing](https://docs.oracle.com/javase/specs/jvms/se8/html/jvms-5.html)
- [Class ClassLoader](https://docs.oracle.com/javase/8/docs/api/java/lang/ClassLoader.html)
- [Understanding Extension Class Loading](https://docs.oracle.com/javase/tutorial/ext/basics/load.html)
- [Java深度历险（二）——Java类的加载、链接和初始化](http://www.infoq.com/cn/articles/cf-Java-class-loader?utm_source=articles_about_java-depth-adventure&utm_medium=link&utm_campaign=java-depth-adventure)
