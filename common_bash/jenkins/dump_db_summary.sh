#!/bin/bash -e
##-------------------------------------------------------------------
## File : dump_db_summary.sh
## Author : Manley <daywbdb@qq.com>
## Description :
## --
## Created : <2016-02-23>
## Updated: Time-stamp: <2016-04-10 12:18:50>
##-------------------------------------------------------------------

################################################################################################
## Purpose: Show the summary information of a designated database
##
## Input parameter:
##       db_service : mongodb;ldap;redis;etc..
##       mongodb:
##          db_ip: 123.57.240.189, localhost , 127.0.0.1
##          db_port : Database server port.
##          db_name : Database name, e.g. : db1; userRoot; etc..
##          db_user : Database user name which is a security authentication user. 
##                    The parameter can be null.
##          db_pwd  : Database user's password.
##                    The parameter can be null. It must be used together with db_user.
##      ldap:
##          db_ip   : Support ip or local hostname. e.g.: 123.57.240.189, localhost , 127.0.0.1
##          db_port : ldap server port.
##          baseDn  : BaseDN of the ldap. e.g.: dc=jingantech,dc=com or dc=Tenant,dc=jingantech,dc=com
##      -h|--help   : Show the help information. 
## Usage:
##       dump_db_summary.sh mongodb localhost 27017 db1
##           # The command must be executed in the database server
##       dump_db_summary.sh mongodb 123.57.240.189 27017 db1 admin password1
##           # The command can be executed in the database client server.
##       dump_db_summary.sh ldap localhost 1389 dc=jingantech,dc=com
##       dump_db_summary.sh -h
################################################################################################
################################################################################################
if [ ! -f /var/lib/enable_common_library.sh ]; then
    wget -O /var/lib/enable_common_library.sh \
         https://raw.githubusercontent.com/DennyZhang/devops_public/master/common_library/enable_common_library.sh
fi
# export AVOID_REFRESH_LIBRARY=true
bash /var/lib/enable_common_library.sh "1512381967"
################################################################################################
function shell_exit() {
    errcode=$?

    [ ${errcode} -eq ${RETURN_CODE} ] && exit 0
    
    if [ ${errcode} -ne 0 ];then
        log "`date +['%Y-%m-%d %H-%M-%S']`Dump ${db_service} summary information failed."
    else
        log "`date +['%Y-%m-%d %H-%M-%S']`Dump ${db_service} summary information successfully."
    fi
    exit $errcode
}

function usage()
{
    echo "usage: dump_db_summary.sh db_service db_ip db_port <db_name [db_user,db_pwd], baseDn>
        Options:
            db_service  : Presently, only support mongodb;ldap;redis
        mongodb:
            db_ip       : Support ip or local hostname. e.g.: 123.57.240.189, localhost , 127.0.0.1
            db_port     : Database server port.
            db_name     : Database name, e.g. : db1; userRoot; etc..
            db_user     : Database user name which is a security authentication user.
                          The parameter can be null.
            db_pwd      : Database user's password.
                          The parameter can be null. It must be used together with db_user.
        ldap:
            db_ip       : Support ip or local hostname. e.g.: 123.57.240.189, localhost , 127.0.0.1
            db_port     : ldap server port.
            baseDn      : BaseDN of the ldap. e.g.: dc=jingantech,dc=com or dc=Tenant,dc=jingantech,dc=com
        redis:
            Presently, do not support the database.
        -h|--help       : Show the help information.
        For example:
            dump_db_summary.sh mongodb localhost 27017 db1
            dump_db_summary.sh mongodb 123.57.240.189 27017 db1 admin password1
            dump_db_summary.sh ldap localhost 1389 dc=jingantech,dc=com
            dump_db_summary.sh --help
         "
}

function dump_mongodb_summary()
{
    local db_ip=${1?}
    local db_port=${2?}
    local db_name=${3?}
    local db_user=${4}
    local db_pwd=${5}
    
    mongodb_connect="${db_ip}:${db_port}/${db_name}"
    
    if [ -n "${db_user}" -a -n "${db_pwd}" ];then
        mongodb_connect="${mongodb_connect} -u ${db_user} -p ${db_pwd}"
    fi
    
    # TODO:Summary items: collectionNames; dataSum; dataSize; indexSum; indexSize; storageEngine
    # Get the collectionNames
    collectionNames=$(echo "show collections" | mongo ${mongodb_connect} | sed -n "3,$ {$ ! p}")
    collectionNames=$(echo $collectionNames)
    collectionSum=$(echo ${collectionNames} | awk '{print NF}')
    
    # Get the dataSum and indexSum
    db_stats=$(echo "db.stats()" | mongo ${mongodb_connect})
    
    dataSum=$(echo $db_stats |  grep -o "objects[^,]*" | awk -F: '{print $2}')
    dataSize=$(echo $db_stats |  grep -o "dataSize[^,]*" | awk -F: '{print $2}')
    indexSum=$(echo $db_stats |  grep -o "indexes[^,]*" | awk -F: '{print $2}')
    indexSize=$(echo $db_stats |  grep -o "indexSize[^,]*" | awk -F: '{print $2}')

    storageEngine=$(echo "db.serverStatus().storageEngine.name" | mongo ${mongodb_connect} | sed -n '3,$ {$ ! p}')

    current_connect=$(echo 'db.serverStatus().connections.current' | mongo ${mongodb_connect} | sed -n '3,$ {$ ! p}')
    available_connect=$(echo 'db.serverStatus().connections.available' | mongo ${mongodb_connect} | sed -n '3,$ {$ ! p}')

    log "*************************${db_service} SUMMARY*******START********************************"
    log "The current connect number : ${current_connect}"
    log "    (Query command: echo 'db.serverStatus().connections.current' | mongo ${mongodb_connect})"
    log "The current available connect number : ${available_connect}"
    log "    (Query command: echo 'db.serverStatus().connections.available' | mongo ${mongodb_connect})"
    log "The total number of all the collections's data : ${dataSum}"
    log "    (Query command: echo 'db.stats().objects' | mongo ${mongodb_connect})"
    log "The total size of all the collections's data : ${dataSize}"
    log "    (Query command: echo 'db.stats().dataSize' | mongo ${mongodb_connect})"
    log "The total number of all the collections's index : ${indexSum}"
    log "    (Query command: echo 'db.stats().indexes' | mongo ${mongodb_connect})"
    log "The total size of all the collections's index : ${indexSize}"
    log "    (Query command: echo 'db.stats().indexSize' | mongo ${mongodb_connect})"
    log "The storage engine name : ${storageEngine}"
    log "    (Query command: echo 'db.serverStatus().storageEngine.name' | mongo ${mongodb_connect})"
    log "The total number of all the collections : $collectionSum"
    log "    (Query command: echo 'show collections' | mongo ${mongodb_connect} | sed -n '3,$ {$ ! p}' | awk '{print NF}')"
    log "The name list of all the collections    :\n${collectionNames}"
    log "    (Query command: echo 'show collections' | mongo ${mongodb_connect} | sed -n '3,$ {$ ! p}'"
    log "*************************${db_service} SUMMARY********END*********************************"
}

function dump_ldap_summary()
{
    local host=${1?}
    local serverPort=${2?}

    # The baseDN of ldap , e.g. : dc=jingantech,dc=com
    local baseDn=${3?}  
    
    # TODO:Summary items: dataSum; dataSize; indexSum; indexSize; storageEngine
    
    # Get the path of config.ldif from the process. e.g.:/usr/local/ldap/config/config.ldif
    local config_path=$(ps -aux | grep ldap | grep -o 'configFile .*config.ldif' | awk '{print $2}' )
    ldap_bin_path=$(echo `dirname $(dirname $config_path)`/bin)
    
    dataSum=$(${ldap_bin_path}/ldapsearch -h ${host} --port ${serverPort} --baseDN ${baseDn} '(uid=*)' -d | grep -c "^dn:")
    
    
    log "*******************${db_service} SUMMARY*******START**********************"
    log "The total number of the ldap's baseDN '${baseDn}' : ${dataSum}"
    log "*******************${db_service} SUMMARY*******END************************"
}

function dump_redis_summary()
{
   log "Presently, don't support dumping summary of redis database service."
}

########################################################################
trap shell_exit SIGHUP SIGINT SIGTERM 0

# Define a return code constant : 99 
RETURN_CODE=99

if [ "x$1" == "x-h" -o "x$1" == "x--help" ];then
    usage
    exit ${RETURN_CODE}
fi

log "`date +['%Y-%m-%d %H-%M-%S']`All the input parameter: $@."

db_service=${1?}
shift

func_name="dump_${db_service}_summary"

# Call the function according the first parameter
if ! type -t ${func_name} | grep -wi function > /dev/null; then
    log "[ERROR] Do not support the db service:${db_service}"
    usage
    exit 1
fi
${func_name} "$@"
## File : dump_db_summary.sh ends
