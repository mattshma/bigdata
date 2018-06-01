# 对象的组合

前面介绍了线程安全与同步的一些基础知识，不过我们并不希望每次对内存访问都进行分析以确保线程安全，而是希望将一些现有的线程安全组件组合为更大规模的组件。本章将会介绍一些组合模式，用于使一个类更容易成为线程安全的类。

## 设计线程安全的类
设计线程安全类的过程中，需要包含以下三个基本要素：
- 找出构成对象状态的所有变量。
- 找出约束状态变更的不变性条件。
- 建立对象状态的并发访问管理策略。

第一点容易理解。第二点中，要确保类的线程安全性，就需要确保它的不变性条件不会在并发访问的过程中被破坏，有时还要考虑其先验条件和后验条件。第三点看接下来的小章节。

> 注：
> - 先验条件：比如不能从空列队中移除一个元素。
> - 后验条件：比如统计网站 pv 数，当天下一个 pv 总数一定比上一个 pv 数大。
> - 一致性条件：若定义 long 类型的变量，则其取值只能为 Long.MIN_VALUE - Long.MAX_VALUE。

## 实例封闭
如果某对象不是线程安全的，那么可能通过多种技术使其在多线程程序中安全的使用，你可以确保该对象只能由单个线程访问（即上一章说的线程封闭），或者通过一个锁来保护对该对象的所有访问，即将数据封装在对象内部，然后将对象的访问限制在对象的方法上，从而更容易确保线程在访问数据时总能持有正确的锁，这种方式被称为实例封闭机制（Instance Confinement）。对象可以封闭在类的一个实例中（例如做为类的一个私有成员），或者封闭在某个作用域内（例如做为一个局部变量），或者封闭在线程内（例如在某个线程中将对象从一个方法传递到另一个方法，而不是在多线程中共享该对象）。通过将封闭机制与合适的加锁策略结合起来，可以确保以线程安全的方式来使用非线程安全的对象。如下[例子](http://jcip.net/listings/PersonSet.java)：
```
@ThreadSafe
public class PersonSet {
    @GuardedBy("this") private final Set<Person> mySet = new HashSet<Person>();

    public synchronized void addPerson(Person p) {
        mySet.add(p);
    }

    public synchronized boolean containsPerson(Person p) {
        return mySet.contains(p);
    }

    interface Person {
    }
}
```

PersonSet 的对象状态由 HashSet 管理，而 HashSet 并非线程安全。但由于 mySet 是私有的且不会逸出，因此 HashSet 被封闭在 PersonSet 中，唯一能访问 mySet 的代码是 `addPerson` 和 `containsPerson`，而在执行这两个成员方法时都要获得 PersonSet 的锁，因此通过封闭机制与合适的加锁，即使 PersonSet 对象由非线程安全的 HashSet 管理，其仍是线程安全的类。

总体而言，实例封闭的要点如下：
- 将对象的属性私有化
- 控制该对象的访问方法
- 加上适当的锁机制

从上面说的线程封闭原则可得出 Java 监视器模式，遵循 Java 监视器模式的对象会把对象的所有可变状态都封闭起来，并由对象的内置锁保护，或由任何一种锁对象保护，只要自始至终都使用该锁对象即可。一般而言，优先使用私有的锁对象而不是对象的内置锁，因为私有的锁对象可以将锁封装起来，使客户代码只能通过公有方法获得锁。若使用对象的内置锁的话，如果客户端错误的使用了其他对象的内置锁，可能会产生活跃性问题，并且此时若要检查锁是否被正确使用，则需要检查整个程序，而不仅仅是单个类了。

## 线程安全性的委托
先介绍下委托的概念：在一个无状态的类 A 中增加一个线程安全类 B 的域，并且得到的组合仍是线程安全的，我们可以说类 A 将它的线程安全性委托给 B 来保证--之所以说 A 是安全的，是因为 B 是线程安全的。

从头开始构建一个类，或将多个非线程安全的类组合为一个类时，Java 监视器模式是非常有用的，但如果类中的各个组件已经是线程安全的，那么组合形成的类是否也是线程安全的呢？这个要分情况而定：
- 如果一个类是由多个独立且线程安全的状态变量组成，并且在所有的操作中都不包含无效状态转换，那么可以将线程安全性委托给底层的状态变量。
- 如果类的多个状态变量之间存在某些不变性条件，则需要加锁机制来维护不变性条件以确保其线程安全性。如以下例子：
```
public class NumberRange {
    // INVARIANT: lower <= upper
    private final AtomicInteger lower = new AtomicInteger(0);
    private final AtomicInteger upper = new AtomicInteger(0);

    public void setLower(int i) {
        // Warning -- unsafe check-then-act
        if (i > upper.get())
            throw new IllegalArgumentException("can't set lower to " + i + " > upper");
        lower.set(i);
    }

    public void setUpper(int i) {
        // Warning -- unsafe check-then-act
        if (i < lower.get())
            throw new IllegalArgumentException("can't set upper to " + i + " < lower");
        upper.set(i);
    }

    public boolean isInRange(int i) {
        return (i >= lower.get() && i <= upper.get());
    }
}
```

虽然 AtomicInteger 是线程安全的，但由于状态变量 lower 和 upper 不是彼此独立的（lower<=upper），因此 NumberRnage 不能将线程安全性委托给它的线程安全变量，还需要通过锁机制维护不变性条件来确保其线程安全性。此外还得避免发布 lower 和 upper，以免外界代码破坏其不变性条件。

## 在现有的线程安全类中添加功能
Java 类库中包含许多有用的“基础模块”类。在现在的线程安全类能支持我们需要的操作时，应优先选用这些类。但更多时候，现在的线程安全类不能完全满足我们的需求。

- 要添加一个新的原子操作，最安全的方法是修改原始类，但这经常无法做到，因为可能无法访问或修改类的源码，不过这种方式意味着实现同步策略的所有代码都在一个源文件中，从而更容易理解与维护。
- 另外一种方法是扩展原始类，但并非所有的类都将状态向子类公开，因此部分场景也无法使用这种方式，另外这种方式将同步策略分布在多个单独维护的源代码文件中，如果底层的类改变了同步策略并选择不同的锁来保护它的状态变量，那么子类会被破坏。
- 第三种方式是客户端加锁机制，即将扩展代码放到一个“辅助类”中，而不是扩展类本身中。这种方式需要注意加锁的对象务必是正确的，比如针对 `List` 添加 `pubIfAbsent` 功能，如下错误的代码示范：
```
@NotThreadSafe
class ListHelper <E> {
    public List<E> list = Collections.synchronizedList(new ArrayList<E>());

    public synchronized boolean putIfAbsent(E x) {
        boolean absent = !list.contains(x);
        if (absent)
            list.add(x);
        return absent;
    }
}
```

虽然 `ListHelper` 已经声明了 `synchronized`，只是带来了同步的假象，因为`synchronized` 针对的是 `ListHelper`，而非 List 本身，这两者是不同的锁，此时的 `pubIfAbsent` 相对于 List 的其他操作并不是原子的。要想 `putIfAbsent` 正常运行，必须使 List 在客户端加锁或外部加锁时使用同一个锁。即**对于使用某个对象 X 的客户端代码，使用 X 本身用于保护其状态的锁来保护这段客户端代码。要使用客户端加锁，必须知道对象 X 使用的是哪一个锁**。

通过添加原子操作来扩展原始类是脆弱的，因为它将类的加锁代码分布在多个文件中。然而，客户端加锁却更加脆弱，因为它将原始类的加锁代码放到与原始类完全无关的其他类中了。
- 组合。相比前面几种机制，这是一种更好的方法。其实现对应类的接口，并添加原子的额外操作。如[代码](http://jcip.net/listings/ImprovedList.java)中所示：
```
@ThreadSafe
public class ImprovedList<T> implements List<T> {
    private final List<T> list;

    public ImprovedList(List<T> list) { this.list = list; }

    public synchronized boolean putIfAbsent(T x) {
        boolean contains = list.contains(x);
        if (contains)
            list.add(x);
        return !contains;
    }

    // Plain vanilla delegation for List methods.
    // Mutative methods must be synchronized to ensure atomicity of putIfAbsent.
    
    public synchronized boolean add(T e) {
        return list.add(e);
    }

    public synchronized boolean remove(Object o) {
        return list.remove(o);
    }

    public int size() {
        return list.size();
    }

    ...
}
```
ImprovedList 通过自身的内置锁增加了一层额外的锁，其并不关心底层的 List 是否是线程安全的，即使 List 不是线程安全的，ImprovedList 也会提供一致的加锁机制来实现线程安全性。虽然额外的加锁可能导致轻微的性能损失，但与模拟另一个对象的加锁策略相比，ImprovedList 更加健壮。

## 将同步策略文档化
在维护线程安全性时，文档是最强大的工具之一。`synchronized`、`volatile`或任何一个线程安全类都对应于某种同步策略，这种策略是程序设计的要素之一，因此应该将其文档化。

如果某个类没有明确声明是线程安全的，那么就不要假设它是线程安全的。

## 小结
在前两章介绍线程安全性和对象的共享后，本章介绍了如何设计线程安全的类。设计线程安全的类，需要包含的三要素：对象的所有变量；维护这些变量的不变性条件；建立对象的并发访问管理策略。整合成一句话即维护对象所有变更的不变性条件并建立对象的并发访问管理策略。具体到方法上，根据原始类是否线程安全可分为如下几种情况：
- 对于非线程安全的类，可以通过实例封闭(将数据封装在对象内部，将对象的访问限制在对象的方法上) 或 Java 监视器模式来组成线程安全的类；
- 对于线程安全的类，若状态变量是线程安全且独立的，则组合成的类也是线程安全的；若状态变量是线程安全但相互不独立，则需通过加锁来维护状态变量之间的不变性条件。
- 若想在 Java 类库现有的安全类中添加功能可采用四种策略：修改原始类；扩展原始类；客户端加锁；组合。其中扩展原始类和客户端加锁会将加锁代码分布在多个类中，都是比较脆弱的做法。组合是在原始类的基础上又增加了一层额外的锁，虽然会带来轻微的性能损失，不过还是建议优先使用。


