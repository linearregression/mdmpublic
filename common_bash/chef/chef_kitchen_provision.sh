#!/bin/bash -x
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : chef_kitchen_provision.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-11-30>
## Updated: Time-stamp: <2016-03-28 08:49:17>
##-------------------------------------------------------------------
# pre-cache Chef Omnibus installation
mkdir -p /tmp/install.sh.14
if [ ! -f /tmp/install.sh.14/metadata.txt ]; then
    wget -O /tmp/install.sh.14/metadata.txt "https://omnitruck-direct.chef.io/stable/chef/metadata?v=&p=ubuntu&pv=14.04&m=x86_64"
fi

if [ ! -f /tmp/install.sh.14/chef_12.7.2-1_amd64.deb ]; then
    wget -O /tmp/install.sh.14/chef_12.7.2-1_amd64.deb https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/14.04/x86_64/chef_12.7.2-1_amd64.deb
fi

echo "Inject ssh key to kitchen user and root user"
wget -O inject_ssh_key.sh  https://raw.githubusercontent.com/DennyZhang/inject_ssh_key/master/inject_ssh_key.sh

user_home_list='kitchen:/home/kitchen,root:/root'
ssh_email='denny.zhang001@gmail.com'
ssh_key='AAAAB3NzaC1yc2EAAAADAQABAAABAQDAwp69ZIA8Usz5EgSh5gBXKGFZBUawP8nDSgZVW6Vl/+NDhij5Eo5BePYvUaxg/5aFxrxROOyLGE9xhNBk7PP49Iz1pqO9T/QNSIiuuvQ/Xhpvb4OQfD5xr6l4t/9gLf+OYGvaFHf/xzMnc9cKzZ+azLlDHbeewu1GMI/XNFWo4VWAsH+6xM8VIpdJSaR7alJn/W6dmyRBbk0uS3Yut63jVFk4zalAzXquU0BX1ne+DLB/LW8ZanN5PWECabSi4dXYLfxC2rDhDcQdXU3MwV5b7TtR5rFoNS8IGcyHoeq5tasAtAAaD2sEzyJbllAfFsNyxNQ+Yh8935HcWqx2/T0r'
sudo bash ./inject_ssh_key.sh $user_home_list $ssh_email $ssh_key

user_home_list='kitchen:/home/kitchen,root:/root'
ssh_email='denny.zhang001@gmail.com'
ssh_key='AAAAB3NzaC1yc2EAAAADAQABAAABAQDGVkT4Ka/Pt6M/xREwYWatYyBqaBgDVS1bCy7CViZ5VGr1z+sNwI2cBoRwWxqHwvOgfAm+Wbzwqs+WNvXW6GDZ1kjayh2YnBN5UBYZjpNQK9tmO8KHQwX29UvOaOJ6HIEWOJB9ylyUoWL+WwNf71arpXULBW6skx9fp9F5rHuB0UmQ+omhJGs6+PRSLAEzWaQvtxmm7CuZ7LgslNKskkqx/6CHlQPq2qchRVN5xvnZPuFWgF6cvWvK7kylAQsv8hQtFGsE9Rw1itjisCBVILzEC2mAjg5SqeEB0i7QwdlRr4jgxaxO5jR9wdKo7PaEl9+bibuZrCIhp6V4Y4eaIzAP'
sudo bash ./inject_ssh_key.sh $user_home_list $ssh_email $ssh_key

echo "enable chef"
if ! which chef-solo; then
    curl -L https://www.opscode.com/chef/install.sh | bash
fi

echo "configure no_proxy"
eth0_ip=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
local_ip="${eth0_ip%.*}.*"
echo no_proxy="localhost,127.0.0.1,$local_ip" > /etc/profile.d/no_proxy.sh

# bypass kitchen verify hang
# TODO: remove this hardcode http download link
wget -O /tmp/preinstall_kitchen_verify.sh https://raw.githubusercontent.com/DennyZhang/devops_public/master/chef/preinstall_kitchen_verify.sh
bash -e /tmp/preinstall_kitchen_verify.sh
## File : chef_kitchen_provision.sh ends
