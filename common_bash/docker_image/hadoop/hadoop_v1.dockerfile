########## How To Use Docker Image ###############
##
##  Install docker utility
##  Download docker image: docker pull denny/hadoop:v1
##  Boot docker container:
##     docker run -d -t -h mytest --name my-test --privileged -v /root/ -p 5022:22 -p 8088:8088 -p 50070:50070 -p 50090:50090 denny/hadoop:v1 /usr/sbin/sshd -D
##  Start services:
##     docker start $container_name
##     docker exec $container_name bash /usr/local/hadoop/sbin/start-all.sh
##
##################################################

FROM ubuntu:14.04
MAINTAINER DennyZhang.com <denny@dennyzhang.com>

########################################################################################

########################################################################################
