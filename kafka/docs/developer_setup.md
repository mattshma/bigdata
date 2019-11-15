# Kafka 源码环境配置
## 环境配置
- 安装 Scala 插件   
  过程：点击 Menu Item File | Settings -> Plugins -> Browse Repositories -> Search for Scala，安装。重启 IntelliJ
- 创建 Kafka 分支  
  这里以 1.0 为例：
  ```
  git clone git@github.com:apache/kafka.git
  cd kafka
  git checkout -b 1.0 remotes/origin/1.0
  ```
- 安装 Gradle   
  在 shell 中安装 Gradle。
- 生成 Intellij 项目文件  
  ```
  cd <kafka.project.dir>
  gradle
  ./gradlew idea 
  ```

##　参考
- [Developer Setup](https://cwiki.apache.org/confluence/display/KAFKA/Developer+Setup)
