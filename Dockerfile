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