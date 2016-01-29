########## How To Use Docker Image ###############
##
##  Install docker utility
##  Download docker image: denny/jenkins:v1
##  Boot docker container: docker run -t -d -h jenkins --name denny-jenkins --privileged -p 61022:9000 -p 61023:22 -p 61081:28000 -p 61082:28080 denny/jenkins:v1 /usr/sbin/sshd -D
##
##     ruby --version
##     gem --version
##     which docker
##     which kitchen
##     which chef-solo
##     source /etc/profile
##     service jenkins start
##      curl -v http://localhost:28080
##
##     service apache2 start
##      curl -v http://localhost:28000/README.txt
##
##     source /etc/profile
##     sudo $SONARQUBE_HOME/bin/linux-x86-64/sonar.sh start
##       ps -ef | grep sonar
##       curl -v http://localhost:9000
##       ls -lth /var/lib/jenkins/tool
##################################################

FROM denny/sshd:v1
MAINTAINER DennyZhang.com <denny.zhang001@gmail.com>

########################################################################################
# install kitchen
cd /tmp/
wget https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/x86_64/chefdk_0.4.0-1_amd64.deb
dpkg -i chefdk_0.4.0-1_amd64.deb
rm -rf /tmp/chefdk_0.4.0-1_amd64.deb

apt-get install -y git unzip

# install docker
curl -sSL https://get.docker.com/ | sudo sh

# install bundler and gems for kitchen
gem install bundler
gem install test-kitchen -v '= 1.4.1'
gem install kitchen-docker -v '= 2.1.0'
gem install 'berkshelf'
gem install 'docker'
gem install 'busser'
gem install serverspec -v '>= 1.6'
gem install chefspec -v '~> 4.1.0'
gem install foodcritic -v '~> 4.0.0'
gem install rubocop -v '~> 0.28.0'

# install snar for code quality: http://www.sonarsource.org
cat > /etc/profile.d/sonar.sh <<EOF
export SONARQUBE_HOME=/var/lib/jenkins/tool/sonarqube-4.5.6
export SONAR_RUNNER_HOME=/var/lib/jenkins/tool/sonar-scanner-2.5
export PATH=\$PATH:\$SONARQUBE_HOME/bin/linux-x86-64:\$SONAR_RUNNER_HOME/bin
EOF

chmod o+x /etc/profile.d/sonar.sh
source /etc/profile

su jenkins
source /etc/profile
which sonar.sh
mkdir -p /var/lib/jenkins/tool
cd /var/lib/jenkins/tool
wget https://sonarsource.bintray.com/Distribution/sonar-scanner-cli/sonar-scanner-2.5.zip
unzip sonar-scanner-2.5.zip && rm -rf sonar-scanner-2.5.zip
wget https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-4.5.6.zip
unzip sonarqube-4.5.6.zip && rm -rf sonarqube-4.5.6.zip

source /etc/profile

# TODO: install jenkins jobs by chef deployment

rm -rf /var/cache/*
########################################################################################
