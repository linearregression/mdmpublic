########## How To Use Docker Image ###############
##
##  Install docker utility
##  Download docker image: docker pull denny/elk:v1
##  Boot docker container:
##     container_name="elk-aio"
##     docker run -t -d -h mytest --name my-test --privileged -p 5022:22 -p 5601:5601 denny/elk:v1 /usr/sbin/sshd -D
##  Start services:
##     docker start $container_name
##     docker exec $container_name /opt/logstash/bin/logstash -e 'input { stdin { } } output { elasticsearch { host => localhost } }'
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
##  curl http://localhost:9200/_search?pretty
##
##  service kibana4 status
##  curl http://localhost:5601
##
##  service nginx status
##  curl http://localhost:80
##################################################

FROM denny/sshd:v1
MAINTAINER DennyZhang.com <denny.zhang001@gmail.com>

########################################################################################
#  https://www.digitalocean.com/community/tutorials/how-to-install-elasticsearch-logstash-and-kibana-4-on-ubuntu-14-04
apt-get install lsof curl libc6-dev

########################################################################################
