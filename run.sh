#!/bin/bash
 
#nextcloud的运行用户是www-data，所以aria2也是以这个用户来运行
sudo -u www-data aria2c -D --conf-path=/etc/aria2/aria2.conf