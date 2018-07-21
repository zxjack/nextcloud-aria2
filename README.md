## 什么是nextcloud

Nextcloud 是一套用于创建网络硬盘的客户端－服务器软件。其功能与 Dropbox 相近，但 Nextcloud 是自由及开放源代码软件，每个人都可以在私人服务器上安装并运行它。与 Dropbox 等专有服务相比，Nextcloud 的开放架构让用户可以利用应用程序的方式在服务器上新增额外的功能，并让用户可以完全掌控自己的数据。
[ownCloud](https://zh.wikipedia.org/wiki/OwnCloud) 原先的开发者弗兰克 · 卡利切创建了 ownCloud 的分支——Nextcloud，继而让卡利切与其他原先的 ownCloud 团队成员持续积极地开发。

Nextcloud官方网站：https://nextcloud.com/ 

## 什么是aria2c

Aria2 是一个命令行下运行、多协议、多来源下载工具（HTTP/HTTPS、FTP、BitTorrent、Metalink），内建 XML-RPC 用户界面。 轻巧，支持多协议是它的特点，平均 4-9MB 内存使用量，BitTorrent 下载速度 2.8MiB/s 时 CPU 占用约 6%。全面的 BitTorrent 特性支持，包括 DHT, PEX, Encryption, Magnet URI, Web-Seeding，选择下载，本地资源探测。Mtalink 支持。包括 File verification, HTTP/FTP/BitTorrent integration and Configuration for language, location, OS, 之类。

## Docker+Nextcloud+aria2c能干吗

Nextcloud+aria2c能够将vps部署成一个带离线下载功能的私人网盘。部署上述两个东西常见的是直接部署在自己的VPS上，采用docker最大的好处是可以一键部署完成，一旦vps出现了问题或者更换别的空间的时候，只要重新`pull docker`就ok了。

我在尝试将二者结合在一起的时候碰到最大的问题是Nextcloud使用的用户是www-data，而aria2c用的root用户，这就导致了一个结果，用aria2c下载的文件在Nextlcoud无法进行删除，这个就比较麻烦了。vps上的空间是有限的，当我将文件拉到本地之后还要ssh登录到vps上用命令进行删除。通过Google找到了一个方法尝试成功了。

如何搭建呢？使用`docker  build`,其中搭建需要的Dockerfile:

```
#基于nextcloud官方最新版镜像构建
FROM nextcloud:latest
 
#https://github.com/e-alfred/ocdownloader
RUN apt-get update; \
    apt-get install -y aria2 sudo curl python; \
    rm -rf /var/lib/apt/lists/*;
 
#youtube-dl是用来下载youtube视频的
#install youtube-dl
#link: https://github.com/rg3/youtube-dl
RUN curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl
RUN chmod a+rx /usr/local/bin/youtube-dl
 
 
ADD ./run.sh /var/www
RUN chmod +x /var/www/run.sh
 
RUN mkdir /var/aria2; \
    #这个文件一定要先手动创建，否则Aria2就运行不起来了
     #这是我测试了好多遍测试出来的问题，因为按照作者项目里面的运行命令运行是没有任何反应的,不会报错，Aria2也没运行起来。
    touch /var/aria2/aria2c.sess; \
    chown -R www-data:root /var/aria2
 
RUN mkdir /etc/aria2
ADD ./aria2.conf /etc/aria2
 
#这个可以不要
EXPOSE 6800
 
CMD ["/bin/bash", "-c", "/var/www/run.sh"]
```

搭建所需要的run.sh和aria2.conf如下：

run.sh:

```
#!/bin/bash
 
#nextcloud的运行用户是www-data，所以aria2也是以这个用户来运行
sudo -u www-data aria2c -D --conf-path=/etc/aria2/aria2.conf
```

aria2.conf:

```
daemon=true
listen-port=6887 
dht-listen-port=6885
seed-ratio=1.0 
max-overall-upload-limit=2M 
max-upload-limit=512K 
max-download-limit=20M 
enable-rpc=true 
rpc-allow-origin-all=true
rpc-listen-all=true
rpc-listen-port=6800
rpc-save-upload-metadata=true
log=/var/aria2/aria2.log
check-certificate=false
save-session=/var/aria2/aria2c.sess
save-session-interval=10
dir=/var/www/data/
input-file=/var/aria2/aria2c.sess
continue=true
log-level=warn
dht-file-path=/var/aria2/dht.dat
dht-file-path6=/var/aria2/dht6.dat
```

将这三个文件放在一个目录下，进行`docker build`就OK了

为了更加方便的使用，我还加入了nginx-proxy，这样就可以使用域名进行登录Nextcloud。通过docker-compose进行部署，docker-compose部署需要的docker-compose.yaml如下：

docker-compose.yaml:

```yaml
version: '2'

services:
   nginx-proxy:
      image: jwilder/nginx-proxy:latest
      restart: always
      container_name: nginx-proxy
      ports:
          - "80:80"
          - "443:443"
      volumes:
          - /root/proxy/certs:/etc/nginx/certs:ro
          - /root/proxy/vhost.d:/etc/nginx/vhost.d:rw
          - /usr/share/nginx/html
          - /var/run/docker.sock:/tmp/docker.sock:ro
   nextcloud:
     image: zxjack/nextcloud-aria2
     container_name: nextcloud
     ports:
          - "8000:80"
          - "6800:6800"
     expose:
          - "80"
     environment:
          - VIRTUAL_HOST=域名  #使用自己的域名填入
          - VIRTUAL_PORT=80
          - DOMAIN=:80  
     volumes:
          - /data/nextcloud:/var/www/html:rw
          - /data:/var/www/data:rw
     restart: always       
```

将这个文件也放在同一个目录下，然后运行

```
docker-compose up -d
```

全部搞定！！