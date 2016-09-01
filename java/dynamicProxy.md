反向与代理
===

按时代理的创建时间，代理分为静态代理和动态代理，静态代理是指程序运行前，代理类的.class文件就已经存在，而动态代理是指程序运行时，通过反射机制动态创建而成的。

### 静态代理

![静态代理](img/staticProxy.gif)

静态代理较简单，需被代理类与代理类有共同接口。以下是一个Demo实现：

```
public class ProxyDemo {
    public static void main(String args[]){
        RealSubject subject = new RealSubject();
        Proxy p = new Proxy(subject);
        p.request();
    }
}

interface Subject{
    void request();
}

class RealSubject implements Subject{
    public void request(){
        System.out.println("request");
    }
}

class Proxy implements Subject{
    private Subject subject;
    public Proxy(Subject subject){
        this.subject = subject;
    }
    public void request(){
        System.out.println("PreProcess");
        subject.request();
        System.out.println("PostProcess");
    }
}
```

### 反射
在介绍动态代理前，先说下反射。反射简单的讲是在程序运动期间还可以实例化对象，调用方法和set/get属性值。

使用反射时首先需要获取类的Class对象。如果在编译期知道类名的话，通过`Class myObjectClass = MyObject.class;`来获取对象；如果在编译期不知道类名，但在运行期可获得类名的话，可通过`Class myObjectClass = Class.forName(className);`来获取class对象。在使用`Class.forName()`方法时，必须提供类的全名，该全名包括类所在的包的名字。如MyObject类位于com.test包中，则全名为com.test.MyObject，否则会招聘`ClassNotFoundException`。

在取得class对象后，即可获取类名，包信息，构造器，各方法及属性等信息。这里简单说下反射获取方法的信息。

```
// 获取Class对象
Class aClass = ... 

// 获取所有声明为public的方法集合
Method[] methods = aClass.getMethods();

// 已和方法名及其参数获取方法
Method method = aClass.getMethod("doSomething", new Class[]{String.class});

// 通过Method对象调用方法
Object returnValue = method.invoke(myObject, "parameter1")
```


### 动态代理
利用Java反射机制能在程序运行时动态的创建接口的实现。Java.lang.reflect.Proxy类实现了这一功能，这就是为什么把动态接口实现叫做动态代理的原因。

可以通过Proxy.newProxyInstance()方法生成一个动态代理实例，newProxyInstance()方法有三个参数：

- ClassLoader 用来加载动态代理类。
- 代理类要实现的接口数组。
- 一个InvocationHandler实现把所有方法的调用转到代理上。

InvocationHandler接口只有一个方法：`invoke(Object proxy, Method method, Object[] args)`。proxy是代理对象，method是被代理对象需要调用的方法，args是该方法的参数列表。在代理类调用方法时，会调用InvocationHandler实例的invoke方法。所以一般而言，InvocationHandler实例的invoke方法会通过Method对象调用方法：`Object returnValue = method.invoke(myObject, "parameter1")`。以下是一个例子：

```
public class DynamicProxyDemo {
    public static void main(String[] args) {
        RealSubject realSubject = new RealSubject();                                  //1.创建委托对象
        ProxyHandler handler = new ProxyHandler(realSubject);                         //2.创建调用处理器对象
        Subject proxySubject = (Subject)Proxy.newProxyInstance(RealSubject.class.getClassLoader(),
                                      RealSubject.class.getInterfaces(), handler);    //3.动态生成代理对象
        proxySubject.request();                                                       //4.通过代理对象调用方法
    }
}

interface Subject{
    void request();
}

class RealSubject implements Subject{
    public void request(){
        System.out.println("RealSubject Request");
    }
}

class ProxyHandler implements InvocationHandler{
    private Subject subject;
    public ProxyHandler(Subject subject){
        this.subject = subject;
    }
    @Override
    public Object invoke(Object proxy, Method method, Object[] args)
            throws Throwable {
        Object result = method.invoke(subject, args);
        return result;
    }
}
```

动态代理类继承自Proxy类，由于Java的单继承性，所有只能针对接口创建代理类，不能针对类创建代理类。

### 参考

- [Interface InvocationHandler](https://docs.oracle.com/javase/7/docs/api/java/lang/reflect/InvocationHandler.html)
- [Class Proxy](https://docs.oracle.com/javase/7/docs/api/java/lang/reflect/Proxy.html#newProxyInstance(java.lang.ClassLoader,%20java.lang.Class[],%20java.lang.reflect.InvocationHandler))
- [Java Reflection Tutorial](http://tutorials.jenkov.com/java-reflection/index.html)
