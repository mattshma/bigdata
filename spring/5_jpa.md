# Spring Data JPA

Spring Data JPA 是 Spring 基于 ORM 框架、JPA 规范的基础上封装的一套JPA应用框架。

## 基本查询
基本查询分两种，一种是 Spring Data 默认已在生成的 CRUD 方法，如 `findAll()`、`save()`等。另外一种是自定义简单查询，形式为 `findXxxByxxx`等。基本查询一般分为四步：
- 声明一个继承自 Repository 的接口，同时标记其要处理的类和 ID 类型：
`interface PersonRepository extends Repository<Person, Long> { … }`
- 声明接口中的查询方法：
```
interface PersonRepository extends Repository<Person, Long> {
  List<Person> findByLastname(String lastname);
}
```
- 配置 Spring 针对接口创建代理实例，有两种方法：JavaConfig：
```
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@EnableJpaRepositories
class Config {}
```
或 XML configuration:
```
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
   xmlns:jpa="http://www.springframework.org/schema/data/jpa"
   xsi:schemaLocation="http://www.springframework.org/schema/beans
     http://www.springframework.org/schema/beans/spring-beans.xsd
     http://www.springframework.org/schema/data/jpa
     http://www.springframework.org/schema/data/jpa/spring-jpa.xsd">

   <jpa:repositories base-package="com.acme.repositories"/>

</beans>
```
- 获取 Repository 实例并使用之：
```
public class SomeClient {

  @Autowired
  private PersonRepository repository;

  public void doSomething() {
    List<Person> persons = repository.findByLastname("Matthews");
  }
}
```

## 复杂查询
实际工作中经常会遇到分页，join等操作，这里分别说明下。
### 分页
Spring Data JPA 已经帮我们实现了分页的功能，在查询的方法中，需要传入参数Pageable，当查询中有多个参数的时候Pageable建议做为最后一个参数传入：
```
Page<User> findALL(Pageable pageable);
Page<User> findByUserName(String userName,Pageable pageable);
```

### JPQL
对于部分复杂需求，可通过自定义 JPQL 来实现。对于 join 操作，一般还需指定 `@OneToMany` 和 `@ManyToOne` ，通过 `mappedBy` 来指明关联对象。指定关系后，通过如下两种方式或获取数据。
### JPA NamedQueries
### @Query
在方法中调用 @Query。
### EntityManager
```
EntityManager em = this.emf.createEntityManager();
        try {
            Query query = em.createQuery("from Product as p where p.category = ?1");
            query.setParameter(1, category);
            return query.getResultList();
        }
        finally {
            if (em != null) {
                em.close();
            }
        }
```

### Projection
若不希望部分属性返回，可通过 projection 减少属性返回，如下：
```
@Entity
public class Person {
  @Id @GeneratedValue
  private Long id;
  private String firstName, lastName;

  @OneToOne
  private Address address;
}

@Entity
public class Address {
  @Id @GeneratedValue
  private Long id;
  private String street, state, country;
}
```

若只希望返回 firstName 和 lastName，新建接口：
```
interface NoAddresses {  
  String getFirstName(); 
  String getLastName();  
}
```
Repository 如下：
```
interface PersonRepository extends CrudRepository<Person, Long> {
  NoAddresses findByFirstName(String firstName);
}
```

Projection 需要通过属性的 getter 方法来获取属性，即属性为 firstName，即其 getter 方法需为 getFirstName，否则 Spring Data 将无法找到原始属性。

### Join
对于 join 操作，需要使用 @OneToOne, @ManyToOne, @OneToMany 和 @ManyToMany 等。
使用 @OneToMany 时还需要指定 mappedBy 属性。使用 @ManyToOne 一般还需要配合 @JoinColumn 来注释属性。
相关 SQL 语句可写在 @Query 中，由于通过 @JoinColumn 等进行了绑定，所以 join 后的 on 语句可省略。

## 报错
- could not resolve property
```
Caused by: org.hibernate.QueryException: could not resolve property: project of: persistence.entity.DppHBaseTable [SELECT t.hbaseCluster, t.tableName FROM dpp.persistence.entity.DppHBaseTable t join t.project p on t.proName = p.proName]
    at org.hibernate.QueryException.generateQueryException(QueryException.java:137)
```

有人说：[CHEN Xiaoyu’s blog: Intellij中spring jpa entity "cannot resolve symbol"](http://jschenxiaoyu.blogspot.com/2016/12/intellijspring-jpa-entity-cannot.html)

