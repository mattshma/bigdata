报错
---

如下：

```
Exception in thread "main" java.lang.UnsupportedClassVersionError: org/apache/hadoop/fs/FsShell : Unsupported major.minor version 51.0
    at java.lang.ClassLoader.defineClass1(Native Method)
    at java.lang.ClassLoader.defineClassCond(ClassLoader.java:631)
    at java.lang.ClassLoader.defineClass(ClassLoader.java:615)
    at java.security.SecureClassLoader.defineClass(SecureClassLoader.java:141)
    at java.net.URLClassLoader.defineClass(URLClassLoader.java:283)
    at java.net.URLClassLoader.access$000(URLClassLoader.java:58)
    at java.net.URLClassLoader$1.run(URLClassLoader.java:197)
    at java.security.AccessController.doPrivileged(Native Method)
    at java.net.URLClassLoader.findClass(URLClassLoader.java:190)
    at java.lang.ClassLoader.loadClass(ClassLoader.java:306)
    at sun.misc.Launcher$AppClassLoader.loadClass(Launcher.java:301)
    at java.lang.ClassLoader.loadClass(ClassLoader.java:247)
Could not find the main class: org.apache.hadoop.fs.FsShell.  Program will exit.
```

解决
---
将JAVA版本从`/usr/java/jdk1.6.0_31`修改为`/usr/java/jdk1.7.0_67-cloudera`。即可解决。
