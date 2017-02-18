# Java Reflection
当程序运行在 JVM 中时，经常需要检查或修改程序运行时的行为，对于这种需求，Java 提供了 **反射** 这一特性。通过反射，能获取到类的如下一些信息：
- Class对象
- 类名
- 修饰符
- 包信息
- 父类
- 构造器
- 方法
- 变量
- ...

更多信息可参考 [java.lang.Class](http://docs.oracle.com/javase/6/docs/api/java/lang/Class.html)。这里简单介绍下反射的相关内容。

## Class
Java 对象有两种类型：基础类型（如 int, char 等）和引用类型（如 String, Double, Serializable），对于每种类型的对象，JVM 实例化一个与之关联的 [java.lang.Class](http://docs.oracle.com/javase/6/docs/api/java/lang/Class.html) 对象，Class 提供了创建类和对象的方法，同时该实例是所有反射 API 的入口。

### Object.getClass()

如果一个对象继承自 [Object](https://docs.oracle.com/javase/8/docs/api/java/lang/Object.html) 且其实例可用，获取它的 Class 对象最简单的方法是调用 [Object.getClass()](https://docs.oracle.com/javase/8/docs/api/java/lang/Object.html#getClass--)，如下：

```
Class c = "foo".getClass();
```

### .class 语法

如果对象还未被实例化，获取 Class 即获取类型的 Class，此时需使用类型后加 `.class` 方法，如下：
```
boolean b;
Class c = b.getClass();   // compile-time error

Class c = boolean.class;  // correct
```
对于基础类型，这是最简单获取 Class 的方法。

### Class.forName()
如果类的全名（即包括包名）可用，可使用 [Class.forName()](https://docs.oracle.com/javase/8/docs/api/java/lang/Class.html#forName-java.lang.String-) 获取 Class ，这种方式不能用于基础类型。

```
Class c = Class.forName("com.duke.MyLocaleServiceProvider");
```
### 基础类型的 TYPE 属性
除了 `.class` 获取基础类型的 Class，还可以通过基础类型的 TYPE 属性，如`Class c = Double.TYPE;`

### 返回 Classes 的方法
如 [Class.getSuperclass()](https://docs.oracle.com/javase/8/docs/api/java/lang/Class.html#getSuperclass--) 和 [Class.getClasses()](https://docs.oracle.com/javase/8/docs/api/java/lang/Class.html#getClasses--) 等均能返回 class 对象。

## Constructor

获取到 Class 对象后，可通过 [getDeclaredConstructors()](https://docs.oracle.com/javase/8/docs/api/java/lang/Class.html#getDeclaredConstructors--) 和 [getConstructors](https://docs.oracle.com/javase/8/docs/api/java/lang/Class.html#getConstructors--) 获取类的 Constructor 数组。当然，如果知道要访问的构造函数的方法参数类型，可将相应参数的 Class 对象做为参数传给 getDeclaredConstructors() 或 getConstructors() 以得到指定构造方法，如下：
```
Constructor constructor =
  aClass.getConstructor(new Class[]{String.class}, bClass.class);
```
获取到 Constructor 对象后，可使用 [newInstance()](https://docs.oracle.com/javase/8/docs/api/java/lang/reflect/Constructor.html#newInstance-java.lang.Object...-) 实例化一个类，该方法的参数需对应构造方法的参数类型。如对于上述构造方法，可使用如下方法实例化类：
```
AClass aClass2 = aClass.newInstance("String1", new BClass(param1, param2));
```

## Field

获取到 Class 对象，可通过 [getFields](https://docs.oracle.com/javase/8/docs/api/java/lang/Class.html#getFields--) 和 [getField(String name)](https://docs.oracle.com/javase/8/docs/api/java/lang/Class.html#getField-java.lang.String-) 来取得 [Field](https://docs.oracle.com/javase/8/docs/api/java/lang/reflect/Field.html) 变量，取得 Field 对象后，即可取得变量相关的内容。


## References
- [Trail: The Reflection API](https://docs.oracle.com/javase/tutorial/reflect/index.html)

