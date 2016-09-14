#!/bin/bash -e
##-------------------------------------------------------------------
## File : sandbox_configure_ufw.sh
## Author : Denny <denny.zhang@totvs.com>
## Description :
## --
## Created : <2015-05-28>
## Updated: Time-stamp: <2016-09-14 10:37:17>
##-------------------------------------------------------------------

# enable ufw
iptables -F; iptables -X
echo 'y' | ufw reset
echo 'y' | ufw enable
ufw default deny incoming
ufw default deny forward
ufw allow 22,80,443/tcp
ufw allow 8443,8080,18080/tcp
ufw allow in on docker0
ufw allow from 12.145.25.178
ufw status
## File : sandbox_configure_ufw.sh ends
