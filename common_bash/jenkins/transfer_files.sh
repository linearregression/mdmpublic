#!/bin/bash -xe
################################################################################################
# * Author        : doungni
# * Email         : doungni@doungni.com
# * Last modified : 2016-01-25 12:40
# * Filename      : scp_remote.sh
# * Description   : 
################################################################################################

############################## Function Start ##################################################
function scp_remote() {
    local repo_ssh_key_file=$2
    local repo_server_list=$3
    local repo_keey_days=$4
    local remote_server_list=$5
    local remote_ssh_key_file=$6

    for repo_server in ${repo_server_list[@]}
    do

        repo_server_split=(${repo_server//:/ })
        repo_server_ip=${repo_server_split[0]}
        repo_server_port=${repo_server_split[1]}
        repo_server_file_pathname=${repo_server_split[2]}
        repo_ssh_connect="ssh -i $repo_ssh_key_file -p $repo_server_port -o StrictHostKeyChecking=no root@$repo_server_ip"

        for remote_server in ${remote_server_list[@]}
        do

            remote_server_split=(${remote_server//:/ })
            remote_server_ip=${remote_server_split[0]}
            remote_server_port=${remote_server_split[1]}
            remote_server_file_pathname=${remote_server_split[2]}
            remote_ssh_connect="ssh -i $remote_ssh_key_file -p $remote_server_port -o StrictHostKeyChecking=no root@$remote_server_ip"

            # Select upload mode: scp rsync
            case $1 in 
                scp)
                    $remote_ssh_connect "$repo_ssh_connect [ -d $repo_server_file_pathname ] || mkdir -p $repo_server_file_pathname"
                    $remote_ssh_connect  "scp -P $repo_server_port -i $repo_ssh_key_file -o StrictHostKeyChecking=no -r $remote_server_file_pathname root@$repo_server_ip:$repo_server_file_pathname"
                    ;;
                #rsync)
                #    ;;
                *)
                    echo "ok"
            esac
        done

        # rm repo gather than $repo_keey_days file
        $repo_ssh_connect "find $repo_server_file_pathname -name "$remote_server_file_pathname*" -mtime +$repo_keey_days -exec rm -rfv {} \+"
    done
}
############################## Function End ####################################################

############################## Shell Start #####################################################

# $*:
    # 0 upload remote shell pathname and name
    # 1 upload remote mode[scp/rsync/...]
    # 2 repo ssh key pathname[/root/.ssh/id_rsa]
    # 3 repo server[ip:port:filepath]
    # 4 repo server data keep days[7] 
    # 5 remote server[ip:port:filepath], by this shell provide
    # 6 remote server[$ssh_key_file], by this shell provide
scp_remote "$@"
############################## Shell End #######################################################
