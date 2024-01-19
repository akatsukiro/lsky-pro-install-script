# lsky-pro-install-script
开源版 Lsky Pro 一键安装脚本

随便糊的，抛砖引玉之用。

目前仅在 Debian 12 x86_64 纯净系统上测试通过。

## 致谢

pre check 部分来自 [nezha monitor](https://github.com/naiba/nezha) 。非常好用的探针，爱 ♥ 来自瓷器。

## 用法

```bash
curl -L https://raw.githubusercontent.com/akatsukiro/lsky-pro-install-script/master/install.sh  -o lsky.sh && chmod +x lsky.sh && sudo ./lsky.sh
```

## 说明

- 拉取 [Lsky Pro](https://github.com/lsky-org/lsky-pro) 最新 Release
- 安装的环境为 LAMP
    - Apache 2
    - MariaDB (Debian 12: 10.11, Debian 11: 10.6, RHEL: 10.6)
    - PHP 8.1