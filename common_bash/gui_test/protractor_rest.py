# -*- coding: utf-8 -*-
#!/usr/bin/python
##-------------------------------------------------------------------
## @copyright 2016 DennyZhang.com
## Licensed under MIT 
##   https://raw.githubusercontent.com/DennyZhang/devops_public/master/LICENSE
##
## File : protractor_rest.py
## Author : Denny <denny@dennyzhang.com>
## Description :
## --
## Created : <2016-05-29>
## Updated: Time-stamp: <2016-05-30 09:14:39>
##-------------------------------------------------------------------
# pip install flask
# export FLASK_DEBUG=1

import os, commands
from datetime import datetime

from flask import Flask
from flask import request, send_file, render_template

app = Flask(__name__)

WORKING_DIR = '/opt/protractor'

#################################################################################
def get_conf_js_content(request_js_file):
    return '''exports.config = {
    seleniumAddress: 'http://localhost:4444/wd/hub',
    specs: ['%s']
    };''' % (request_js_file)

def make_tree(path):
    tree = dict(name=os.path.basename(path), children=[])
    try: lst = os.listdir(path)
    except OSError:
        pass #ignore errors
    else:
        for name in lst:
            fn = os.path.join(path, name)
            if os.path.isdir(fn):
                tree['children'].append(make_tree(fn))
            else:
                tree['children'].append(dict(name=name))
    return tree
#################################################################################
# curl -v -F upload=@/etc/hosts  http://127.0.0.1:5000/protractor_request
@app.route("/protractor_request", methods=['POST'])
def protractor_request():
    print "Accept request"
    if os.path.exists(WORKING_DIR) is False:
        os.mkdir(WORKING_DIR)

    tmp_request_id = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
    protractor_js = "%s/%s.js" % (WORKING_DIR, tmp_request_id)
    conf_js = "%s/%s-conf.js" % (WORKING_DIR, tmp_request_id)

    f = request.files['upload']
    f.save(protractor_js)

    open(conf_js, "wab").write(get_conf_js_content(protractor_js))
    # Run command: protractor conf.js
    cmd = "protractor %s" % (conf_js)
    # cmd = "cat %s" % (conf_js)
    print cmd
    os.chdir(WORKING_DIR)
    status, output = commands.getstatusoutput(cmd)

    # remove temporarily files
    os.remove(conf_js)
    os.remove(protractor_js)

    # TODO: return http code
    return output

@app.route('/get_image/<filename>', methods=['GET'])
def get_image(filename):
    if filename == "all":
        # If filename is not given, list images under working_dir
        return render_template("%s/dirtree.html" % (WORKING_DIR), tree = make_tree(WORKING_DIR))
    else:
        return send_file("%s/%s" % (WORKING_DIR, filename), mimetype='image/png')

if __name__ == "__main__":
    flask_port = "4445"
    app.run(host="0.0.0.0", port=int(flask_port))
## File : protractor_rest.py ends
