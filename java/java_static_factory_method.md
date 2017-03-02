# 静态工厂方法

## 简介
在 《Effective Java》的 Item 1 中，提到了静态工厂方法，即一个返回类实例的静态方法，并补充说明和设计模式中的工厂方法模式不同。如下是 JDK1.7 源码中的一个例子：

```
public final class Boolean implements java.io.Serializable,
                                      Comparable<Boolean>
{
    // 缓存 TRUE 和 FALSE 两个对象。
    public static final Boolean TRUE = new Boolean(true);
    public static final Boolean FALSE = new Boolean(false);
 
    private final boolean value;

    public Boolean(boolean value) {
        this.value = value;
    }
 
    public static Boolean valueOf(boolean b) {
        return (b ? TRUE : FALSE);
    }
}
```

这里的 `valueOf()` 就是一个静态方法，其用来产生一个 Boolean 对象。可以看到，静态工厂方法和类的构造方法类似，都用于返回一个对象。首先思考下，为什么该方法要是静态的？稍微思考便知只有该方法是静态方法才能返回实例。那么，静态工厂方法相比构造方法有什么优缺点呢？这里参照 《Effective Java》中说明，列出其优缺点。

## 优点
- 相比构造方法而言，静态工厂方法具有更加可读的方法名。对于构造方法而言，很难知晓不同构造方法对应的各参数的类型，而使用静态工厂方法，可以通过更可读的方法名来区别多个静态工厂方法的区别。
- 静态工厂方法不需要每次调用时都创建新的对象。静态工厂方法允许不可变类使用预先初始化过的实例，或同上面 Boolean 类一样，缓存其创建的实例对象（查看各原始数据类型的封装类，基本都是通过这种方法实现的）。
- 静态工厂方法还可以返回该类型的子类对象。这让静态工厂方法的扩展性远远大于构造方法，这种情况的实例之一是 JDK 源码中的 EnumSet 类型，其根据参数中的元素个数返回不同类型的实例。
- 静态工厂方法可以简化参数化类型对象的创建过程。如下是例子：
  ```
  Map<String, List<String>> m = new HashMap<String, List<String>>();
  
  public static <K, V> HashMap<K, V> newInstance() {
         return new HashMap<K, V>();
  }
  
  Map<String, List<String>> m = HashMap.newInstance();
  ```
  第一行可以简化成第三行代码。

## 缺点
当然，静态工厂方法也是有如下一些缺点的。	
- 如果一个类的构造方法类型为 private，只提供静态工厂方法来创建对象，那么将不能使用继承的方式来扩展该类。不过一般而言，在扩展类时，优先使用组合而不是继承的方式。
- 静态工厂方法不能很好的和其他静态类区别开。若使用静态工厂方法代替构造方法，我们很难一眼认出需要使用哪个静态方法来创建对象，当然可以在 Javadoc 中说明；另外，使用注释进行说明和合理的给静态工厂方法取名，也能有效的避免这个问题。为和普通静态方法区别开来，《Effective Java》建议命名静态工厂方法时，遵循如下规则：
 - valueOf -- 返回一个返回值和参数相同的对象。这种静态方法命名通常用于类型转换。
 - of -- 和 valueOf 类似。
 - getInstance -- 根据参数返回对应的对象，该对象可能是缓存对象池中的对象。对于 Singleton 模式，使用无参的 getInstance 方法，并且总是返回同一对象。
 - newInstance -- 和 getInstance 类似，不过每次返回的都是新创建的对象。
 - get _Type_ -- 和 getInstance 类似，不过返回的对象是另外一个不同类型（_Type_ 类型）的类。
 - new _Type_ -- 和 newInstance 类似，不过每次返回的都是新创建的不同类型（_Type_ 类型）的类。



 

