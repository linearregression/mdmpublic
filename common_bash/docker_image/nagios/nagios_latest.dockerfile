########## How To Use Docker Image ###############
##
##  Install docker utility
##  Download docker image: docker pull denny/nagios:latest
##
##  Start container:
##   docker stop  denny-nagios
##   docker rm  denny-nagios
##
##   docker run -t -d --privileged --name denny-nagios -h nagios -p 61423:22 -p 61481:80 denny/nagios:latest /usr/sbin/sshd -D
##
##   docker exec -it denny-nagios bash
##     curl -u nagiosadmin:password1234 http://127.0.0.1:80/nagios
##################################################

FROM denny/nagios:v1
MAINTAINER DennyZhang.com <denny.zhang001@gmail.com>

########################################################################################
# inject chef client key
curl -o /root/client.pem http://repo.dennyzhang.com/chef/cheftrial.pem

# generate client.rb
node_name="cheftrial"
chef_server_url="https://chef.dennyzhang.com/organizations/digitalocean"
cat > /root/client.rb <<EOF
log_level :info
log_location STDOUT
node_name "$node_name"
client_key '/root/client.pem'
chef_server_url '$chef_server_url'
cache_type 'BasicFile'
no_lazy_load true
cache_options( :path => '/root/checksums' )
ssl_verify_mode :verify_none
EOF

##################################################
# generate dna.json
cat > /root/dna.json <<EOF
{"run_list": ["recipe[nagios3::default]"]}
EOF

# run chef-client update
chef-client -j /root/dna.json -c /root/client.rb -L /var/log/chef_client.log -l debug
# tail /var/log/chef_client.log
########################################################################################
