
KDC
---
KDC在逻辑上可分为3个部分：Database, AS(Authentication Server), TGS(Ticket Granting Server)。

### Database
凭证(entry)用于用户与服务之间联系，而database是这些entry的容器(container)。entry包括如下信息：  
- The principal to which the entry is associated
- The encryption key and related kvno
- The maximum validity duration for a ticket associated to the principal
- The maximum time a ticket associated to the principal may be renewed (only Kerberos 5)
- The attributes or flags characterizing the behavior of the tickets
- The password expiration date
- The expiration date of the principal, after which no tickets will be issued

### AS
当client端向KDC发送一个初始化验证请求时，如果该client还没被验证，则需输入密码验证。接收到请求后，AS会回复一个TGT给client端。如果client是真正发送请求的client，其接下来可以通过TGT获致ST(Service Ticket)，而不需要再次输入密码。

### TGS
当client向KDC发送一个合法的 TGT 时，TGS 会根据client的需求返回一个ST。client端拿着ST就可以访问自己需要访问的服务了。

这里[引用](http://www.ahathinking.com/archives/243.html)一段话理解下整个过程：
>用户要去游乐场，首先要在门口检查用户的身份(即 CHECK 用户的 ID 和 PASSWORD), 如果用户通过验证，游乐场的门卫 (AS) 即提供给用户一张门卡 (TGT)。这张卡片的用处就是告诉游乐场的各个场所，用户是通过正门进来，而不是后门偷爬进来的，并且也是获取进入场所一把钥匙。

现在用户有了卡（TGT），但是这对用户来不重要，因为用户来游乐场不是为了拿这张卡，而是为了游览游乐项目，比如说用户想去游玩摩天轮。这时摩天轮的服务员 (client) 拦下用户，向用户要求摩天轮的 (ST) 票据，用户说自己只有一个门卡 (TGT), 这里用户只要把 TGT 放在一旁的票据授权机 (TGS) 上刷一下。用户在票据授权机 (TGS) 进出自己的需求，票据授权机(TGS)就给用户一张摩天轮的票据 (ST), 这样用户有了摩天轮的票据，就可以畅通无阻的进入摩天轮游玩了。

如果用户玩完摩天轮后，想去游乐园的咖啡厅休息下，用户一样只要带着那张门卡 (TGT). 到相应的咖啡厅的票据授权机 (TGS) 刷一下，得到咖啡厅的票据 (ST) 就可以进入咖啡厅了。

当用户离开游乐场后，想用这张 TGT 去刷打的回家的费用，对不起，用户的 TGT 已经过期了，在用户离开游乐场那刻开始，用户的 TGT 就已经销毁了。

Session Key
---
当用户和服务间有一个session打开时，用户端和服务端很有必要共享一个密钥。	这个密钥由KDC在生成TGT时一起产生。

KDC 验证过程
---
如下图:

 ![kerberos image](../../../img/krbmsg.gif)

1. 客户端向AS发送一个请求TGT的消息。
2. AS通过database验证客户端访问权限，如果合法的话，其将创建一个TGT和Session Key。之后KDC使用客户端的密码来加密TGT和Session Key，然后返回给客户端。
   客户端使用密码来解密AS返回的结果，如果解密成功的话，客户端将使用TGT向TGS请求ST。
3. 当客户端想要访问某个服务时，其会向TGS发送一个请求，该请求中包含客户端名，realm名和一个时间戳，客户端使用步骤2中得到的Session key加密后的结果做为验证其合法性的证据。
4. TGS破译TGT和认证器(authenticator，其使用Session key来破解)，验证请求的合法性，并为被请求的机器创建一个ST，ST中会包括客户端名和可选的客户端ip，同时包括realm名和该ST的生命期。TGS将ST返回给客户端，返回的消息中同时还包括server session key 的两个复本--一份使用客户端密码加密，一份使用服务端密码加密。
5. 客户端向服务端发送一个服务请求，其包括步骤4中收到的ST和一个认证器，服务端通过解密session key来证明请求的合法性，如果ST和认证器匹配，将授权访问该服务。
6. 如果需要手动认证，服务端将回复一个验证信息。

SSO
----

KDC启动
---
[krb5.conf](http://web.mit.edu/kerberos/krb5-current/doc/admin/conf_files/krb5_conf.html#krb5-conf-5)文件配置了Kerberos的基本信息，其中包括配置KDCs和Kerberos realm 管理服务的位置，默认的realm，主机与kerberos realm的映射关系等。默认情况下其位于`/etc`目录。

[kdc.conf](http://web.mit.edu/kerberos/krb5-current/doc/admin/conf_files/kdc_conf.html#kdc-conf-5)作为krb5.conf的补充，其只对KDC有效，如[krb5kdc](http://web.mit.edu/kerberos/krb5-current/doc/admin/admin_commands/krb5kdc.html#krb5kdc-8)和[kadmind](http://web.mit.edu/kerberos/krb5-current/doc/admin/admin_commands/kadmind.html#kadmind-8)进程及[kdb5_util](http://web.mit.edu/kerberos/krb5-current/doc/admin/admin_commands/kdb5_util.html#kdb5-util-8)程序等。其默认位于 [LOCALSTATEDIR](http://web.mit.edu/kerberos/krb5-current/doc/mitK5defaults.html#paths)/krb5kdc位置下。

注意这两个文件的[默认位置](http://web.mit.edu/kerberos/krb5-current/doc/mitK5defaults.html#paths)。

### 配置 krb5.conf 和 kdc.conf
- 修改 `/etc/krb5.conf`

如下：
```
[libdefaults]
	default_realm = AJKDNS.COM

[realms]
AJKDNS.COM = {
	# use "kdc = ..." if realm admins haven't put SRV records into DNS
	kdc = dev-001.ajkdns.com
	admin_server = dev-001.ajkdns.com
}
```

- 修改 `/usr/local/var/krb5kdc/kdc.conf`

如下：
```
[kdcdefaults]
	kdc_ports = 750,88

[realms]
	AJKDNS.COM = {
		database_name = /usr/local/var/krb5kdc/principal
		acl_file = /usr/local/var/krb5kdc/kadm5.acl
		key_stash_file = /usr/local/var/krb5kdc/.k5.AJKDNS.COM
		kadmind_ports = 749
		max_life = 12h 0m 0s
		max_renewable_life = 7d 0h 0m 0s
	}
	
[logging]
	kdc = FILE:/var/log/krb5kdc.log
	admin_server = FILE:/var/log/kadmin.log
	default = FILE:/var/log/krb5lib.log
```

### 创建KDC数据库
如下命令：
```
# kdb5_util create -s -r AJKDNS.COM
Loading random data
Initializing database '/usr/local/var/krb5kdc/principal' for realm 'AJKDNS.COM',
master key name 'K/M@AJKDNS.COM'
You will be prompted for the database Master Password.
It is important that you NOT FORGET this password.
Enter KDC database master key:
Re-enter KDC database master key to verify:
```

### 配置ACL文件
创建kdc数据库后，需要将管理员加入到ACL(Access Control List)中，acl的格式为`principal  permissions  [target_principal  [restrictions]]`

### 启动Kerberos进程
命令如下：
```
% krb5kdc
% kadmind
```

参考
---
- [Dialogue](http://web.mit.edu/kerberos/dialogue.html)
- [Tutorial](http://www.kerberos.org/software/tutorial.html)
- [Installing KDCs](http://web.mit.edu/kerberos/krb5-current/doc/admin/install_kdc.html#install-and-configure-the-master-kdc)
