#!/bin/bash -xe
################################################################################################
## @copyright 2015 DennyZhang.com
# * Author        : doungni
# * Email         : doungni@doungni.com
# * Last modified : 2015-12-12 12:12
# * Filename      : docker_images_common.sh
# * Description   : 
################################################################################################

################################################################################################
# * Jenkins Parameter     
#   docker_repository     : By jenkins job configuration
#                           docker repository name
#   SPLIT_SIZE_MB         : By jenkins job configuration
#                           docker image tar file split size
#   SSH_PORT_FROM         : By jenkins job configuration
#                           Machine:docker image save 
#   SSH_PORT_TO           : By jenkins job configuration
#                           Machine:docker image load 
#   MACHINE_IP_FROM       : By jenkins job configuration
#                           Machine:docker image save 
#   MACHINE_IP_TO         : By jenkins job configuration
#                           Machine:docker image load 
#
# * Define Parameter
#   repository            : docker image name
#   image_name            : Test docker image container name
#   ssh_identityfile      : Jenkins server id_rsa
#   SSH_IDENTITY_FILE_FROM: "FROM":beginning server id_rsa pathname
#   SSH_IDENTITY_FILE_TO  : "TO": destination server id_rsa pathname
################################################################################################

############################## Function Start ##################################################
# print log message
function log() {
    local msg=$*
    echo `date +'[%Y-%m-%d %H-%M-%S']` "\n $msg\n"
}

# verigy privileged ,for save load operate
function verify_privileged() {
    # Verify root privileged
    if [ $EUID -ne 0 ]; then
        log "ERROR: Please use root login"
        exit 1
    fi

    # Verify docker install and if run or not
    docker version
    RETVAL=$?
    if [ $RETVAL -ne 0];
        log "ERROR: Please install docker daemon"
        exit 1
    fi
}

# Deel with docker repository, include save and load
function docker_repository () {
    if [ -n $docker_repository ]; then
        if [ ${docker_repository%/*} != ${docker_repository#*/} ]; then
            local repository=${docker_repository%/*}-${docker_repository#*/}
        else
            local repository=$docker_repository
        fi
    else
        tty erase ^h
        read -p "In 7s, Please input or copy docker repository:" -t 7 repository
    fi
    image_name=$repository
}

# docker save image, local operate
function save() {
    case "$1" in
        1)
            # local save
            verify_privileged
            local repository=$repository

            mkdir -p $repository
            cd $repository

            log "docker save image"
            docker save $docker_repository > ${repository}.tar.gz

            # Test ${repository}.tar.gz is a complete tar file
            tar tvf ${repository}.tar.gz > /dev/null 2>&1
            local RETVAL=$?
            if [ $RETVAL -ne 0 ]; then
                log "Split ${repository}.tar.gz, Unit: MB, Named: sp.${repository}.*"
                split -b ${split_size_mb}m ${repository}.tar.gz sp.${repository}.

                # Use md5 check
                log "By md5sum, generate ${repository}.md5"
                md5sum sp.${repository}.* > ${repository}.md5 
            else
                log "ERROR:${repository}.tar.gz is not a complete tar file"
                exit 1
            fi
            ;;
        2)
            # remote save
            scp -P $ssh_port -i $ssh_identity_file -o StrickHostKeyChecking=no $0 root@$machine_ip:/root
            $ssh_connect chmod +x $0
            $ssh_connect /root/$0 save
            ;;
        *)
            log "Please input incorrect value"
    esac
}


# docker load image, local operate
function load() {
case "$1" in
    1)
        # Local docker image load
        # judge $repository and docker exist and not null
        verify_privileged

        # Verify $repository is directory and not empty
        if [ ! -d $repository ]; then
            log "$repository can not find in"
            exit 1
        fi

        cd /root/$repository

        # Check md5
        if [ -r ${repository}.md5 ]; then
            log "Checking ${repository}.md5"
            md5sum -c ${repository}.md5

            local RETVAL_1=$?
            if [ $RETVAL_1 -eq 0 ]; then
                log "Generate a tar file: ${repository}.tar.gz"
                find ./ -name "split.${repository}.*" -exec cat {} \+ | sort > ${repository}.tar.gz
            else
                log "ERROR: ${repository}.md5 verify failed"
                exit 1
            fi
        else
            log "${repository}.md5 can not read"
            exit 1
        fi

        log "Test ${repository}.tar.gz is a complete tar file"
        tar tvf ${repository}.tar.gz > /dev/null 2>&1
        local RETVAL_2=$?
        if [ $RETVAL_2 -ne 0 ]; then
            log "ERROR: ${repository}.tar.gz check failed"
            exit 1
        fi

        # load docker images
        log "docker load image"
        docker load -i ${repository}.tar.gz

        if [ $? -eq 0 ]; then
            log "docker load image: ${repository}.tar.gz load success"

            # Check if docker is installed or not
            log "Create docker container, test docker image"
            docker run -td --name=$image_name $docker_repository /bin/bash
            if [ $? -ne 0 ]; then
                log "ERROR: docker images install failed"
                exit 1
            else
                log "docker images install success"
            fi

            log "Delete docker container"
            docker stop $image_name
            if [ $? -ne 0 ]; then
                log "ERROR: Can not stop container: $image_name"
                exit 1
            else
                docker rm $image_name
                if [ $? -ne 0 ]; then
                    log "ERROR: Can not rm container: $image_name"
                    exit 1
                else
                    log "docker rm $image_name success"
                fi
            fi
        else
            log "docker load image failed"
            exit 1
        fi
        ;;
    2)
        # Remote docker image load, image in remote $machine_ip_from, need load to remote $machine_ip_to, $0 in local
        log "Scp $repository from $machine_ip_from to $achine_ip_to"

        # Copy $repository from "$machine_ip_from" to "$machine_ip_to"
        scp_image_from_to="scp -P $machine_port_to -i $ssh_identity_file_from -o StrickHostkeyChecking=no -r $repsitory root@$machine_ip_to:/root"
        ssh -p $machine_port_from -i $ssh_identity_file -o StrickHostKetChecking=no root@$machine_ip_from "$scp_image_from_to"

        # Test $machine_ip_to $repository exist
        log "Test $machine_ip_to $repository directory exist and list filename"
        ssh -p $machine_ip_to -i $ssh_identitt_file -o StrickHostKeyChecking=no root@$machine_ip_to "test -d $repository&&ls -l $repository"

        local RETVAL=$?
        if [ $RETVAL -eq 0]; then
            scp -P $machine_port_to -i $ssh_identity_file -o StrickHostKeyChecking=no $0 root@$machine_ip_to:/root/$repository
            ssh -p $machine_port_to -i $ssh_identity_file -o StrickHostKeyChecking=no root@$machine_ip_to /root/$repository/$0 load
        else
            log "ERROR: $machine_ip_to:/root/$repository can not found"
            exit 1
        fi
        ;;
    *)
        log "Operate error"
        exit 1
esac
}

############################## Function End ####################################################

############################## Shell Start #####################################################

# Ssh identity file, include save and load, exist jenkins CI container
ssh_identity_file="/var/lib/jenkins/.ssh/id_rsa"

# Ssh identity file, only load function, exist $machine_ip_from
ssh_identity_file_from="/root/.ssh/id_rsa"

# SSH connect parameter, only save
ssh_connect="ssh -p $ssh_port -i $ssh_identity_file -o StrickHostKeyChecking=no root@$machine_ip"

# Main executed
case "$1" in
    save)
        log "Notice: Will be executed-docker save image"
        docker_repository
        if [ -z $machine_ip ]; then
            log "Local docker image save"
            save 1
        else
            log "Remote docker image save"
            save 2
        fi
        ;;
    load)
        log "Notice: Will be executed-docker load image, local method"
        docker_repository
        if [ -z $machine_ip_from ]; then
            log "Local docker image load"
            load 1
        else
            log "Remote docker image load"
            load 2
        fi
        ;;
    *)
        echo $"Usage: $0 {save|load|}"
esac

############################## Shell End #######################################################
