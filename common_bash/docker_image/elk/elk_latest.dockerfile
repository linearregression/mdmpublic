########## How To Use Docker Image ###############
##
##  Install docker utility
##  Download docker image: docker pull denny/elk:latest
##  Boot docker container:
##     container_name="elk-aio"
##     docker run -t -d -h mytest --name my-test --privileged -p 5022:22 -p 5601:5601 denny/elk:latest /usr/sbin/sshd -D
##  Start services:
##     docker start $container_name
##
##  service elasticsearch start
##  service kibana4 start
##  service nginx start
##  /opt/logstash/bin/logstash -e 'input { stdin { } } output { elasticsearch { host => localhost } }'
##
##  service logstash status
##  lsof -i tcp:9301
##
##  service elasticsearch status
##  lsof -i tcp:9200
##
##  service kibana4 status
##  lsof -i tcp:5601
##
##  service nginx status
##  curl http://localhost:80
##################################################

FROM elk:v1
MAINTAINER DennyZhang.com <denny.zhang001@gmail.com>

########################################################################################

########################################################################################
