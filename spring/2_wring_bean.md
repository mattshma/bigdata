# 装配 Bean

Spring 提供了三种主要的装配 Bean 的机制:
- 在 XML 中进行显式配置；
- 在 Java 中进行显式配置；
- 隐式的 bean 发现机制和自动装配。

虽然 Spring 提供了多种方案来配置 bean，不过还是推荐尽可能的使用自动装配的机制。当必须使用显式配置时，优先使用 JavaConfig 的方式进行配置，最后当想使用便利的 XML 命名空间，并且在 JavaConfig 中没有同样的实例时，才应该使用 XML。

## 自动装配 bean

Spring 从两个角度来实现自动化装配：
- 组件扫描（component scan）: Spring 自动发现 ApplicationContext 中创建的 bean。
- 自动装配（autowiring）：Spring 自动满足 bean 之间的依赖。

Spring 使用 `@Component` 注解申明类为组件类，并知知 Spring 要为这个类创建 bean。尽管我们没有明确为目标类设置 ID，但 Spring 会根据类名为其指定一个 ID，规则是将类名的每一个大写字母改为小写字母。如果想为类设置不同的 ID，可将 ID 传递给 `@Component` 注解，如 `@Component("testClass")`。另外 Java 还提供了一种 `@Named` 的注解，两者有细微的差异，但大多数场景，两者可互相替换。

Spring 使用 `@ComponentScan` 来进行组件扫描。默认情况下，`@ComponentScan` 以配置类所在的包作为基础包来扫描组件。若希望扫描不同的包，可指定 `@ComponentScan` 中的 value 属性，如 `@ComponentScan("testClass")`。如果想更加清楚的表明设置的是基础包，可设置 `basePackages` 属性：`@ComponentScan(basePackages={AClass.class, BClass.class})`。

Spring 使用 `@Autowired` 注解来实现组件的自动装配。如果有且只有一个 bean 匹配依赖需求的话，那么这个 bean 会被装配进来；如果没有匹配的 bean，那么 Spring 会抛出一个异常，为避免抛出异常，可将 `@Autowired` 的 `required` 属性设置为 false，不过此时需进行 null 检查，防止使用该未装配的状态而导致 NullPointerException；如果有多个 bean 满足依赖关系，则需明确指定使用哪个 bean 进行自动装配：可将可选的某个 bean 设为首选(设置为 `@Primary`)的 bean，或使用限定符(`@Qualifier`)来将可选 bean 的范围缩小到只有一个 bean。若多个有歧义的 bean 都设置为了 `@Primary`，则需使用限定符这种方式了。

### 通过 Java 代码装配 bean
尽管多数场景下通过组件扫描和自动装配能实现 Spring 的自动化装配，但部分场景自动化配置的方案是行不通的，需要明确配置 Spring。比如想将第三方库中的组件装配到你的应用中，此时没有办法在它的类上添加 `@Component` 和 `@Autowired` 注解，此时必须采用显式装配的方式。

`@ComponentScan` 和显式配置能同时使用，但这里关注显式配置，因此下面说下显式配置移除 `@ComponentScan` 后的组件扫描方法。
