########## How To Use Docker Image ###############
##
##  Install docker utility
##  Download docker image: docker pull denny/shadowsock:v1
##
##  Start container:
##   docker run -t -d --privileged -h shadowsock --name denny-shadowsock -p 6187:6187 -p 6188:22 denny/shadowsock:v1 /usr/sbin/sshd -D
##
##   docker exec -it denny-shadowsock bash
##     ps -ef | grep shadow
##     service supervisor start
##     supervisorctl reload
##
##     service supervisor status
##     telnet 127.0.0.1 6187
##     tail -f /var/log/supervisor/shadowsocks-stderr*
##################################################

FROM denny/sshd:v1
MAINTAINER DennyZhang.com <denny.zhang001@gmail.com>

########################################################################################
apt-get update
apt-get install python-pip python-m2crypto supervisor lsof
pip install shadowsocks

# create /etc/shadowsocks.json
# create /etc/supervisor/conf.d/shadowsocks.conf
# autostart supervisord
# vim /etc/rc.local

service supervisor start

supervisorctl reload

########################################################################################
