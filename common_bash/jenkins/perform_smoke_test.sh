#!/usr/bin/env bash
##-------------------------------------------------------------------
## @copyright 2015 DennyZhang.com
## File : perform_smoke_test.sh
## Author : Denny <denny.zhang001@gmail.com>
## Description :
## --
## Created : <2015-08-16>
## Updated: Time-stamp: <2016-01-20 15:35:14>
##-------------------------------------------------------------------
function log() {
    local msg=$*
    echo -ne `date +['%Y-%m-%d %H:%M:%S']`" $msg\n"
}

function prepare_protractor() {
    working_dir=${1?}
    shift
    server_ip=${1?}
    shift
    gui_test_case=$*
    protractor_conf_cfg="$working_dir/protractor_conf.js"
    protractor_testcase="$working_dir/protractor_testcase.js"

    log "configure $protractor_conf_cfg"
    cat > $protractor_conf_cfg <<EOF
exports.config = {
    seleniumAddress: 'http://localhost:4444/wd/hub',
    // ----- What tests to run -----
    specs: ['$protractor_testcase'],
    // If you would like to run more than one instance of webdriver on the same
    // tests, use multiCapabilities, which takes an array of capabilities.
    // If this is specified, capabilities will be ignored.
    multiCapabilities: [
        {
            'browserName': 'chrome',
            'shardTestFiles': true,
            'maxInstances': 10,
            'acceptSslCerts': true,
            'trustAllSSLCertificates': true
        }
    ],
    // ----- Parameters for tests -----
    params: {
        login: {
            server_ip: '$server_ip',
        }
    },

    onPrepare: function() {
        browser.driver.manage().window().setSize(1600, 800);
    },

    jasmineNodeOpts: {
        showColors: true,
        defaultTimeoutInterval: 30000,
        isVerbose: true,
        includeStackTrace: true
    },
    // The timeout in milliseconds for each script run on the browser. This should
    // be longer than the maximum time your application needs to stabilize between
    // tasks.
    allScriptsTimeout: 30000,

    // How long to wait for a page to load.
    getPageTimeout: 30000
};
EOF

    log "configure $protractor_testcase"
    cat > $protractor_testcase <<EOF
describe('Authright GUI verification', function() {
url = "http://" + browser.params.login.server_ip

$gui_test_case

});
EOF
}

function test_protractor() {
    working_dir=${1?}
    protractor_conf_cfg="$working_dir/protractor_conf.js"
    log "================ protractor $protractor_conf_cfg ============"
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
    protractor $protractor_conf_cfg
}

#################################################################################
working_dir="/var/lib/jenkins/code/smoketest/"
[ -d $working_dir ] || mkdir -p $working_dir

prepare_protractor $working_dir "$server_ip" "gui_test_case"
test_protractor $working_dir
## File : perform_smoke_test.sh ends
