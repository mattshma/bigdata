# Intro

## 代码结构

- 将 Java 类文件放在包中。
- 将主程序入口放 root 包下，同其他包平级。
- 优先使用注解配置
- 使用将 `@SpringBootApplication` 或 `@EnableAutoConfiguration` 中一个来选择自动配置。

## 使用 `@SpringBootApplication` 注解
`@SpringBootApplication` 提供如下功能：
- `@EnableAutoConfiguration`
- `@ComponentScan`
- `@Configuration`

上述三个注解并不是一定需要的，可以选择其中一个或两个来代替 `@SpringBootApplication` 。
