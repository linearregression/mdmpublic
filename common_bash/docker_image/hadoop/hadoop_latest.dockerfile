########## How To Use Docker Image ###############
##
##  Install docker utility
##  Download docker image: docker pull denny/hadoop:latest
##  Boot docker container:
##     docker run -d -t -h mytest --name my-test --privileged -v /root/ -p 5022:22 -p 8088:8088 -p 50070:50070 -p 50090:50090 denny/hadoop:latest /usr/sbin/sshd -D
##  Start services:
##     docker start $container_name
##     docker exec $container_name bash /usr/local/hadoop/sbin/start-all.sh
##
##################################################

FROM denny/hadoop:v1
MAINTAINER DennyZhang.com <denny@dennyzhang.com>

########################################################################################

########################################################################################
