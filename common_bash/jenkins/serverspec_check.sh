#!/bin/bash -e
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : serverspec_check.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-07-29>
## Updated: Time-stamp: <2016-01-20 15:35:28>
##-------------------------------------------------------------------

################################################################################################
## env variables:
##      test_spec:
##          describe service('apache2') do
##           it { should be_running }
##          end
##
################################################################################################

function install_serverspec() {
    if ! sudo gem list | grep serverspec 2>/dev/null 1>/dev/null; then
        sudo gem install serverspec
    fi

    if ! sudo dpkg -l rake 2>/dev/null 1>/dev/null; then
        sudo apt-get install -y rake
    fi
}

function setup_serverspec() {
    working_dir=${1?}
    cd $working_dir
    if [ ! -f spec/spec_helper.rb ]; then
        echo "Setup Serverspec Test case"
        cat > spec/spec_helper.rb <<EOF
require 'serverspec'

set :backend, :exec
EOF

        cat > Rakefile <<EOF
require 'rake'
require 'rspec/core/rake_task'

task :spec => 'spec:all'
task :default => :spec

namespace :spec do
 targets = []
 Dir.glob('./spec/*').each do |dir|
 next unless File.directory?(dir)
 target = File.basename(dir)
 target = "_#{target}" if target == "default"
 targets << target
 end

 task :all => targets
 task :default => :all

 targets.each do |target|
 original_target = target == "_default" ? target[1..-1] : target
 desc "Run serverspec tests to #{original_target}"
 RSpec::Core::RakeTask.new(target.to_sym) do |t|
 ENV['TARGET_HOST'] = original_target
 t.pattern = "spec/#{original_target}/*_spec.rb"
 end
 end
end
EOF
    fi
}


flag_file="/var/lib/jenkins/$JOB_NAME.flag"

function shell_exit() {
    errcode=$?
    if [ $errcode -eq 0 ]; then
        echo "OK"> $flag_file
    else
        echo "ERROR"> $flag_file
    fi
    exit $errcode
}

trap shell_exit SIGHUP SIGINT SIGTERM 0

#####################################################
working_dir="/var/lib/jenkins/serverspec"
mkdir -p $working_dir/spec/localhost
cd $working_dir

sudo /usr/sbin/locale-gen --lang en_US.UTF-8
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

install_serverspec
setup_serverspec $working_dir

cat > spec/localhost/sample_spec.rb <<EOF
require 'spec_helper'

# Check at least 3 GB free disk
describe command("[ `df -h -B 1G / | tail -n1 | awk -F' ' '{print $4}'` -gt 3 ]") do
  its(:exit_status) { should eq 0 }
end

# Check at least 1 GB free memory
describe command("[ `free -ml | grep 'buffers/cache' | awk -F' ' '{print $4}'` -gt 1024 ]") do
  its(:exit_status) { should eq 0 }
end

$test_spec
EOF

echo "Perform serverspec check"
sudo rake spec
## File : serverspec_check.sh ends
