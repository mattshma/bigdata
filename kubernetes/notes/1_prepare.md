# 准备工作

由于当前 kubernetes 最新版本为 1.13，所以这里以 1.13 版本来学习 kubernetes 的代码。

```
git clone https://github.com/kubernetes/kubernetes.git
git checkout -b release-1.13 remotes/origin/release-1.13
```

## 结构分析
从 kubectl 发起请求到容器启动/关闭的过程来看下源码，整个流程：kubectl --> api server --> scheduler --> kubelet start/stop pod.

由于从 kubectl 发起请求开始阅读源码，所以在正式开始之前，先简单介绍下 kubectl 使用的命令行工具 cobra 。

## Cobra 简介
[cobra](https://github.com/spf13/cobra) 是一个用来创建现代 CLI 接口的 Golang 库，广泛用在一些知名的 Golang 项目中，比如 Kubernetes、etcd、Docker 等。在阅读 Kubernete 源码前，先大致了解下 cobra 的概念。如下内容基于 cobra readme 整理。

cobra 基于如下三个概念：
- commands   
  表示操作。
- arguments   
  被操作的对象。
- flags   
  对操作的变更。

一般常见的命令模式为：`APPNAME COMMAND ARG --FLAG`，如 git 的 `git clone URL --bare`，cobra 的命令模式类似。

通常基于 cobra 的应用会遵循如下组织结构：
```
▾ appName/
  ▾ cmd/
      add.go
      your.go
      commands.go
      here.go
    main.go
```
而 main.go 文件通常也非常简单，仅用于初始化 cobra：
```
package main

import (
  "{pathToYourApp}/cmd"
)

func main() {
  cmd.Execute()
}
```

### 使用 cobra 
若需要使用 cobra，需要创建一个 main.go 文件和一个 rootCmd 文件。

#### 创建 rootCmd
cobra 不需要任何构造函数，理想情况下 rootCmd 文件为 app/cmd/root.go ：
```
var rootCmd = &cobra.Command{
  Use:   "hugo",
  Short: "Hugo is a very fast static site generator",
  Long: `A Fast and Flexible Static Site Generator built with
                love by spf13 and friends in Go.
                Complete documentation is available at http://hugo.spf13.com`,
  Run: func(cmd *cobra.Command, args []string) {
    // Do Stuff Here
  },
}

func Execute() {
  if err := rootCmd.Execute(); err != nil {
    fmt.Println(err)
    os.Exit(1)
  }
}
```
从上可以看到创建出 command，然后执行其 `Executoe()` 函数即可。另外，我们可能还需要在 `init()` 函数中定义额外的 flag 和配置。

参考 [Command](https://godoc.org/github.com/spf13/cobra#Command)，其结构大致如下：
```
type Command struct {
    Use string  	       // 一行 usage 信息
    Aliases []string    
    SuggestFor []string
    Short string               // 'help' command 的简短描述
    Long string                // 'help <this-command>' 的具体描述
    Example string             // 命令样例
    ValidArgs []string          
    Args PositionalArgs        // 接收的参数
    ArgAliases []string        // ValidArgs 的别名
    BashCompletionFunction string
    Deprecated string          // Deprecated 声明
    Hidden bool                // 是否隐藏该命令
    Annotations map[string]string
    Version string

    //  *Run 函数的执行顺序:
    //   * PersistentPreRun()
    //   * PreRun()
    //   * Run()
    //   * PostRun()
    //   * PersistentPostRun()
    //
    PersistentPreRun func(cmd *Command, args []string)
    PersistentPreRunE func(cmd *Command, args []string) error
    PreRun func(cmd *Command, args []string)
    PreRunE func(cmd *Command, args []string) error
    Run func(cmd *Command, args []string)       // 实际起作用的函数，大部分命令仅需要实现它。
    RunE func(cmd *Command, args []string) error // 同 Run 方法，不过还会返回 error 信息
    PostRun func(cmd *Command, args []string)
    PostRunE func(cmd *Command, args []string) error
    PersistentPostRun func(cmd *Command, args []string)
    PersistentPostRunE func(cmd *Command, args []string) error

    SilenceErrors bool
    SilenceUsage bool
    DisableFlagParsing bool
    DisableAutoGenTag bool
    DisableFlagsInUseLine bool       //
    DisableSuggestions bool
    SuggestionsMinimumDistance int
    TraverseChildren bool
    FParseErrWhitelist FParseErrWhitelist
}
```

从这里看出，我们需要重点关注的逻辑，都会在 `Run` 字段中实现。

#### 创建 main.go
当 rootCmd 创建好后，还需要通过 `main()` 来执行。main.go 一般仅用于初始化 cobra。

#### 创建其他命令
其他命令通常定义在 `cmd` 目录下各自的文件中，如想创建一个 version 命令，创建 `cmd/version.go` 如下：
```
package cmd

import (
  "fmt"

  "github.com/spf13/cobra"
)

func init() {
  rootCmd.AddCommand(versionCmd)
}

var versionCmd = &cobra.Command{
  Use:   "version",
  Short: "Print the version number of Hugo",
  Long:  `All software has versions. This is Hugo's`,
  Run: func(cmd *cobra.Command, args []string) {
    fmt.Println("Hugo Static Site Generator v0.9 -- HEAD")
  },
}
```

### flags
flags 提供了控制 command 行为的修饰语。

#### 为 command 指定 flags
有两种方式指定 flags，如下：

- Persistent Flags     
  `PersistentFlags` 意思着该 flag 能用于所有 command，适用于全局 flag。如 `rootCmd.PersistentFlags().BoolVarP(&Verbose, "verbose", "v", false, "verbose output")`。
- Local Flags       
  `Flags` 仅作用在指定它的 command 上，即局部 flag。如：`rootCmd.Flags().StringVarP(&Source, "source", "s", "", "Source directory to read from")`。默认情况下 cobra 只解析当前 command 上的局部 flags，而忽略父 command 的局部 flags，通过开启 `Command.TraverseChildren` 可在执行目标 command 前解析该command 继承关系链上每个 command 的局部 flag。

默认情况下 flags 是可选的，若需设为必选，可通过 `MarkFlagRequired` 标记：`rootCmd.MarkFlagRequired("region")`。
  
### Positional and Custom Arguments
通过指定 command 中的 `Args` 字段，可以对 positional argument 进行验证。

内置的验证器如下：
- `NoArgs`   
  如有任何 positional args，command 将报错。
- `ArbitraryArgs`    
  command 将接收任何 args。
- `OnlyValidArgs`      
  如果 positional args 不在 `ValidArgs` 字段中则报错。
- `MinimumNArgs(int)`   
  positional args 数目少于 N 个则报错。
- `MaximumNArgs(int)`   
  positional args 数目多于 N 个则报错。
- `ExactArgs(int)`  
  positional args 数目不等于 N 个则报错。
- `ExactValidArgs(int)`   
  positional args 数目不等于 N 个**或** positional args 不在 `ValidArgs` 中则报错。
- `RangeArgs(min, max)`   
  args 数目不在 (min, max) 范围内则报错。

若需自定义验证器，需为 command 的 `Args` 字段指定自定义函数，如下：
```
var cmd = &cobra.Command{
  Short: "hello",
  Args: func(cmd *cobra.Command, args []string) error {
    if len(args) < 1 {
      return errors.New("requires at least one arg")
    }
    if myapp.IsValidColor(args[0]) {
      return nil
    }
    return fmt.Errorf("invalid color specified: %s", args[0])
  },
  Run: func(cmd *cobra.Command, args []string) {
    fmt.Println("Hello, World!")
  },
}
```

### Help Command
若应用有子 command 时，cobra 会自动添加 help command，通过执行`app help`可调用。若需自定义 help command，可使用如下函数：
```
cmd.SetHelpCommand(cmd *Command)
cmd.SetHelpFunc(f func(*Command, []string))
cmd.SetHelpTemplate(s string)
```

cobra 的知识就大概介绍到这，接下来开始学习 kubectl 的源码。

## 参考
- [A few things I've learned about Kubernetes](https://jvns.ca/blog/2017/06/04/learning-about-kubernetes/)
- [A Tour of the Kubernetes Source Code Part One: From kubectl to API Server](https://developer.ibm.com/opentech/2017/06/21/tour-kubernetes-source-code-part-one-kubectl-api-server/)

