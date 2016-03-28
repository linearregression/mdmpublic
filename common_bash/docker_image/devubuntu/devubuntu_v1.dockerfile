########## How To Use Docker Image ###############
##
##  Install docker utility
##  Download docker image: docker pull denny/devubuntu:v1
##  Boot docker container: docker run -t -d denny/devubuntu:v1 /bin/bash
##
##     ruby --version
##     gem --version
##     python --version
##     java -version
##     chef-solo --version
##     nc -l 80
##     which pidstat
##################################################

FROM denny/sshd:v1
MAINTAINER DennyZhang.com <denny@dennyzhang.com>

########################################################################################
apt-get update
apt-get install -y lsof vim strace ltrace tmux curl tar telnet
apt-get install -y software-properties-common python-software-properties tree
apt-get install -y build-essential openssl git-core
apt-get install -y python-pip python-dev
apt-get install -y sysstat
# http://xmodulo.com/record-replay-terminal-session-linux.html
pip install TermRecord

# install ruby
apt-get -yqq install python-software-properties && \
apt-add-repository ppa:brightbox/ruby-ng && \
apt-get -yqq update && \
apt-get -yqq install ruby2.0 ruby2.0-dev && \
rm -rf /usr/bin/ruby && \
ln -s /usr/bin/ruby2.0 /usr/bin/ruby

# sete locale to UTF-8
locale-gen --lang en_US.UTF-8 && \
cat > /etc/profile.d/locale.sh <<EOF
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
EOF && \

chmod o+x /etc/profile.d/locale.sh

# install java8
add-apt-repository ppa:webupd8team/java
apt-get -y update && \
apt-get -y install oracle-java8-installer

# install docker
wget -qO- https://get.docker.com/ | sh

# stop services
service docker stop

# install chef
curl -L https://www.opscode.com/chef/install.sh | bash

# change ruby gem sources
gem sources -a https://ruby.taobao.org/ && \
gem sources -r https://rubygems.org/ && \
gem sources -r http://rubygems.org/

# install nc and tcpdump
apt-get install netcat
apt-get install tcpdump

# install inotify
apt-get install inotify-tools
rm -rf /var/cache/*

# http://justniffer.sourceforge.net/#!/install
sudo add-apt-repository ppa:oreste-notelli/ppa 
sudo apt-get update
sudo apt-get install justniffer
########################################################################################
