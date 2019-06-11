# encryptAlgorithm

## 快速上手

| # 制作serverKey.pem和serverCert.cer |                                                              |
| ----------------------------------- | ------------------------------------------------------------ |
|                                     | ```                                                          |
|                                     | openssl req -newkey rsa:2048 -nodes -keyout serverKey.pem \  |
|                                     | -x509 -days 365 -out serverCert.cer \                        |
|                                     | -subj "/C=CN/ST=GD/L=GZ/O=abc/OU=defg/CN=hijk/emailAddress=132456.com" |
|                                     | ```                                                          |
|                                     |                                                              |
|                                     | # CentOS环境编译前需要安装开发工具                           |
|                                     | ```                                                          |
|                                     | sudo yum groupinstall "Development Tools"                    |
|                                     | sudo yum install cmake3 openssl-devel                        |
|                                     | ```                                                          |
|                                     |                                                              |
|                                     | # 编译步骤                                                   |
|                                     | ```                                                          |
|                                     | cmake3 .                                                     |
|                                     | make                                                         |
|                                     | ```                                                          |



## 命令行编译

| # 制作serverKey.pem和serverCert.cer |                                                              |
| ----------------------------------- | ------------------------------------------------------------ |
|                                     | ```                                                          |
|                                     | openssl req -newkey rsa:2048 -nodes -keyout serverKey.pem \  |
|                                     | -x509 -days 365 -out serverCert.cer \                        |
|                                     | -subj "/C=CN/ST=GD/L=GZ/O=abc/OU=defg/CN=server/emailAddress=server@132456.com" |
|                                     | ```                                                          |
|                                     |                                                              |
|                                     | # 验证                                                       |
|                                     | ```                                                          |
|                                     | 在第一个终端窗口运行                                         |
|                                     | openssl s_server -accept 4430 -key serverKey.pem -cert serverCert.cer |
|                                     |                                                              |
|                                     | 在第二个终端窗口制作clientKey.pem和clientCert.cer，然后运行openssl s_client |
|                                     | openssl req -newkey rsa:2048 -nodes -keyout clientKey.pem \  |
|                                     | -x509 -days 365 -out clientCert.cer \                        |
|                                     | -subj "/C=CN/ST=GD/L=GZ/O=abc/OU=defg/CN=client/emailAddress=client@132456.com" |
|                                     | openssl s_client -connect 127.0.0.1:4430 -key clientKey.pem -cert clientCert.cer |
|                                     | ```                                                          |



快速上手指南介绍GmSSL的编译、安装和`gmssl`命令行工具的基本指令。

1. 下载源代码([zip](https://github.com/guanzhi/GmSSL/archive/master.zip))，解压缩至当前工作目录

   ```
   $ unzip GmSSL-master.zip
   ```

2. 编译与安装

   Linux平台 (其他平台的安装过程见[编译与安装](http://gmssl.org/))

   ```
   $ ./config no-saf no-sdf no-skf no-sof no-zuc
   $ make
   $ sudo make install
   ```

   安装之后可以执行`gmssl`命令行工具检查是否成功

   ```
   $ gmssl version
   GmSSL 2.0 - OpenSSL 1.1.0d
   ```

3. SM4加密文件

   ```
   $ gmssl sms4 -e -in <yourfile> -out <yourfile>.sms4
   enter sms4-cbc encryption password: <your-password>
   Verifying - enter sms4-cbc encryption password: <your-password>
   ```

   解密

   ```
   $ gmssl sms4 -d -in <yourfile>.sms4
   enter sms4-cbc decryption password: <your-password>
   ```

4. 生成SM3摘要

   ```
   $ gmssl sm3 <yourfile>
   SM3(yourfile)= 66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0
   ```

5. 生成SM2密钥并签名

   ```
   $ gmssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:sm2p256v1 \
                   -out signkey.pem
   $ gmssl pkeyutl -sign -pkeyopt ec_scheme:sm2 -inkey signkey.pem \
                   -in <yourfile> -out <yourfile>.sig
   ```

   可以将公钥从`signkey.pem`中导出并发发布给验证签名的一方

   ```
   $ gmssl pkey -pubout -in signkey.pem -out vrfykey.pem
   $ gmssl pkeyutl -verify -pkeyopt ec_scheme:sm2 -pubin -inkey vrfykey.pem \
                   -in <yourfile> -sigfile <yourfile>.sig
   ```

6. 生成SM2私钥及证书请求

   ```
   $ gmssl ecparam -genkey -name sm2p256v1 -text -out user.key
   $ gmssl req -new -key user.key -out user.req
   ```

   查看证书请求内容：

   ```
   $ gmssl req -in user.req -noout -text -subject
   ```