# Spring Introduce

## IoC 简介
所有的被注入对象和依赖对象由 IoC Service Provider 统一管理。被注入对象通过如下方式通知 IoC Service Provider 为其提供服务：
- 构造方法注入
优点是对象在构造完成之后即可使用，缺点是依赖对象较多时，构造方法的参数列表比较长。而且在 Java 中，构造方法无法被继承，无法设置默认值。
- setter方法注入
因为方法可以命名，所以setter方法注入在描述性上要比构造方法注入好一些。 另外，setter方法可以被继承，允许设置默认值，而且有良好的IDE支持。缺点当然就是对象无法在构造完成后马上进入就绪状态。
- 接口注入
需要实现被注入对象对应的接口，这个接口声明一个 injectXXX 方法(方法名随意)，该方法的参数，就是所依赖对象的类型。这种方式由于较繁琐且侵入性强，目前不太提倡使用了。

综上所述，构造方法注入和setter方法注入因为其侵入性较弱，且易于理解和使用，所以是现在使用最多的注入方式;而接口注入因为侵入性较强，近年来已经不流行了。

## Spring IoC 容器
上面说了几种 IoC Service Provider 实现方式，那 Spring 中是如何做的呢？

Spring IoC 容器是一个 IoC Service Provider，但是，这只是它被冠以IoC之名的部分原因，我们不能忽略的是“容器”。Spring的IoC容器是一个提供IoC支持的轻量级容器，除了基本的IoC支持，它作为轻量级容器还提供了IoC之外的支持。如在Spring的IoC容器之上，Spring还提供了相应的AOP框架支持、企业级服务集成等服务。

Spring提供了两种容器类型: BeanFactory 和 ApplicationContext。

### BeanFactory
基础类型IoC容器，提供完整的IoC服务支持。如果没有特殊指定，默认采用延迟初始化策略(lazy-load)。只有当客户端对象需要访问容器中的某个受管对象的时候，才对该受管对象进行初始化以及依赖注入操作。所以，相对来说，容器启动初期速度较快，所需要的资源有限。对于资源有限，并且功能要求不是很严格的场景，BeanFactory是比较合适的IoC容器选择。

#### BeanFactory 的对象注册与依赖绑定方式
- 直接编码
BeanFactory 接口只定义如何访问容器内管理的Bean 的方法，各个BeanFactory的具体实现类负责具体Bean的注册以及管理工作。 BeanDefinitionRegistry 接口定义抽象了 Bean 的注册逻辑。
- 外部配置文件方式
Spring的IoC容器支持两种配置文件格式:Properties文件格式和XML文件格式。
- 注解方式
使用@Autowired以及@Component对相关类进行标记。

> @Autowired vs @Resource
> @Resource的作用相当于@Autowired，均可标注在字段或属性的setter方法上。不过仍存在下列区别：
> 1. @Resource默认是按照名称来装配注入的，只有当找不到与名称匹配的bean才会按照类型来装配注入；
> 2. @Autowired默认是按照类型装配注入的，如果想按照名称来转配注入，则需要结合@Qualifier一起使用；
> 3. @Resource注解由 J2EE 提供，而@Autowired是由spring提供，故减少系统对spring的依赖建议使用@Resource的方式；

这里总结下注解声明和注入 Bean 的方式：
- 声明 Bean 的注解：
    - @Component 
    组件，没有明确角色
    - @Controller
    在展现层（MVC -> Spring MVC）使用
    - @Service 
    在业务逻辑层（service层）使用
    - @Repository 
    在数据访问层（dao层）使用
- 注入 Bean 的注解，一般情况下通用：
    - @Autowired 
    Spring 提供的注解
    - @Inject
    JSR-330 提供的注解
    - @Resource
    JSR-250 提供的注解

#### <beans> 和 <bean>
<bean> 有 id, name, class 等属性。针对构造方法注入，使用 <constructor-arg>，针对 setting 方法注入，使用<property>。

除了可以通过配置明确指定bean之间的依赖关系，Spirng还提供了根据bean定义的某些特点将相互依赖的某些bean直接自动绑定的功能。通过<bean>的autowire属性，可以指定当前bean定义采用某种类型的自动绑定模式。这样，你就无需手工明确指定该bean定义相关的依赖关系，从而也可以免去一些手工输入的工作量.
Spring提供了5种自动绑定模式，即no、byName、byType、constructor和autodetect。 

#### bean scope
scope即容器中的对象所应该处的限定场景或者说该对象的存活时间。Spring容器最初提供了两种bean的scope类型:singleton 和prototype，但发布2.0之后，又引入了另外三种scope类型，即request、session 和 global session类型。不过这三种类型有所限制，只能在Web 应用中使用。

- singleton scope
一个容器中只存在一个共享实例，所有对该类型bean的依赖都引用这一单一实例。从容器启动，到它第一次被请求而实例化开始，只要容器不销毁或者退出，该类型bean的单一实例就会一直存活。

- prototype scope
针对声明为拥有prototype scope的bean定义，容器在接到该类型对象的请求的时候，会每次都重新生成一个新的对象实例给请求方。

### ApplicationContext
ApplicationContext 在 BeanFactory 的基础上构建，是相对比较高级的容器实现，除了拥有 BeanFactory的所有支持，ApplicationContext还提供了其他高级特性，比如事件发布、国际化信息支持等。ApplicationContext 所管理 的对象，在该类型容器启动之后，默认全部初始化并绑定完成。所以，相对于 BeanFactory来说，ApplicationContext 要求更多的系统资源，同时，因为在启动时就完成所有初始化，容器启动时间较之 BeanFactory 也会长一些。在那些系统资源充足，并且要求更多功能的场景中，ApplicationContext 类型的容器是比较合适的选择。

