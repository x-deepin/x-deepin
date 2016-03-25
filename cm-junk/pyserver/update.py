#!/usr/bin/env python

# -*- coding: utf-8 -*-

import sys
import os
import json
import optparse
import pyjsonrpc
import shutil
import tempfile

def get_collect_scripts():
    # cp scrpits to work_dir for test purpose
    print('copying scripts...')
    os.system("cp -ar %s/../*.sh %s" % (old_cur, work_dir))
    os.system("cp -ar %s/../test.conf %s" % (old_cur, work_dir))

old_cur = os.getcwd()
work_dir = tempfile.mkdtemp(prefix='updateinfo')
os.chdir(work_dir)
get_collect_scripts()
os.system("./info.sh 1")

fp = open('./1', 'r')
info = json.load(fp)
fp.close()
print(json.dumps(info, indent=2))

client = pyjsonrpc.HttpClient(
         url='http://localhost:4000/'
         )

print(json.dumps(client.call("update", info), indent=2))

shutil.rmtree(work_dir)
