# -*- encoding: utf-8 -*-
#!/usr/bin/ruby
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : jenkins_helper.rb
## Author : DennyZhang.com <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-05-10>
## Updated: Time-stamp: <2016-06-04 09:58:11>
##-------------------------------------------------------------------
################################################################################
require 'socket'
require 'serverspec'
require 'open3'

# Required by serverspec
set :backend, :exec

# Jenkins
def wait_jenkins_up(jenkins_run_cmd)
  # After Jenkins deployment, it may take time for Jenkins to be up and running
  # TODO: make code more general
  url_link_prefix = \
  'https://raw.githubusercontent.com/TOTVS/mdmpublic/master/common_bash/jenkins'

  %w(poll_jenkins_job.sh wait_jenkins_up.sh).each do |f|
    describe command("#{jenkins_run_cmd} curl -o /root/#{f} " \
                     "#{url_link_prefix}/#{f}") do
      its(:exit_status) { should eq 0 }
    end
  end

  # Wait for jenkins to up
  describe command("#{jenkins_run_cmd} bash /root/wait_jenkins_up.sh " \
                   'http://127.0.0.1:18080/jnlpJars/jenkins-cli.jar') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should contain 'Jenkins is up' }
  end

  # Download facility tools from Jenkins
  describe command("#{jenkins_run_cmd} curl -o /root/jenkins-cli.jar " \
                   'http://127.0.0.1:18080/jnlpJars/jenkins-cli.jar') do
    its(:exit_status) { should eq 0 }
  end
end

# functions to trigger jenknis jobs
def run_jenkins_job(jenkins_run_cmd, job_name, parameters)
  # Run Jenkins jobs by jenkins CLI
  describe command("#{jenkins_run_cmd} #{job_name} -w #{parameters}") do
    its(:stdout) { should contain 'Started ' }
    its(:exit_status) { should eq 0 }
  end
end

def run_jenkins_job_with_retry(jenkins_run_cmd, jenkins_check_cmd, \
                               job_name, parameters)
  # Run Jenkins jobs. If it fails for the first time, give a retry
  run_command = "#{jenkins_run_cmd} #{job_name} -w #{parameters}"
  describe command(run_command) do
    its(:stdout) { should contain 'Started ' }
    its(:exit_status) { should eq 0 }
  end

  describe command("#{jenkins_check_cmd} #{job_name}|| #{run_command}") do
    its(:exit_status) { should eq 0 }
  end

  describe command("#{jenkins_check_cmd} #{job_name}") do
    its(:stdout) { should contain 'Jenkins job success: ' }
    its(:exit_status) { should eq 0 }
  end
end

def run_check_jenkins_job(jenkins_run_cmd, jenkins_check_cmd, \
                          job_name, parameters)
  # Run jenkins jobs once and verify the job status
  describe command("#{jenkins_run_cmd} #{job_name} -w #{parameters}") do
    its(:stdout) { should contain 'Started ' }
    its(:exit_status) { should eq 0 }
  end

  describe command("#{jenkins_check_cmd} #{job_name}") do
    its(:stdout) { should contain 'Jenkins job success: ' }
    its(:exit_status) { should eq 0 }
  end
end
#############################################################################
## File : jenkins_helper.rb ends
