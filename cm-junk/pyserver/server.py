#!/usr/bin/env python

# -*- coding: utf-8 -*-

import pyjsonrpc
import sys
import os
import json
import math
import time

global MODE_MATCH_EXACT
global MODE_MATCH_WITHOUT_OS
global MODE_MATCH_WITHOUT_MACHINE
global MODE_MATCH_WITHOUT_OS_OR_MACHINE
global policy
global find_matched_drivers
global match_db_record
global copy_record
global match_result_record
global array_equal
global update_result_record
global xv_equal
global nv_settings_equal
global render_device_equal
global perfmodes_equal
global get_perf_mode
global debug

MODE_MATCH_EXACT = 0
MODE_MATCH_WITHOUT_OS = 1
MODE_MATCH_WITHOUT_MACHINE = 2
MODE_MATCH_WITHOUT_OS_OR_MACHINE = 3

policy = ["exact match", "match without os info", "match without machine type", \
          "match without os info or machine type"]

global get_driver_file
def get_driver_file(rec):
    return rec['Driver File']

global get_attr_name
def get_attr_name(rec):
    return rec['name']

def array_equal(s, d):
    if len(s) != len(d):
        return False

    s.sort(reverse = False)
    d.sort(reverse = False)
    for i in range(len(s)):
        if s[i] != d[i]:
            return False

    return True

def xv_equal(xv1, xv2):
    if len(xv1) != len(xv2):
        return False

    # If the xorg video driver equals
    xv1.sort(key = get_driver_file, reverse = False)
    xv2.sort(key = get_driver_file, reverse = False)
    for i in range(len(xv1)):
        if xv1[i]['Driver File']   != xv2[i]['Driver File'] or \
          xv1[i]['Driver Package'] != xv2[i]['Driver Package'] or \
          xv1[i]['Driver Version'] != xv2[i]['Driver Version'] or \
          xv1[i]['sha256sum']      != xv2[i]['sha256sum']:
            return False

    return True

def get_perf_mode(rec):
    return rec['perf']

def perfmodes_equal(s, d):
    if (len(s) != len(d)):
        return False

    s.sort(key = get_perf_mode, reverse = False)
    d.sort(key = get_perf_mode, reverse = False)
    for i in range(len(s)):
        if s[i]['perf']                   != d[i]['perf'] or \
          s[i]['nvclock']                 != d[i]['nvclock'] or \
          s[i]['nvclockmin']              != d[i]['nvclockmin'] or \
          s[i]['nvclockmax']              != d[i]['nvclockmax'] or \
          s[i]['nvclockeditable']         != d[i]['nvclockeditable'] or \
          s[i]['memclock']                != d[i]['memclock'] or \
          s[i]['memclockmin']             != d[i]['memclockmin'] or \
          s[i]['memclockmax']             != d[i]['memclockmax'] or \
          s[i]['memclockeditable']        != d[i]['memclockeditable'] or \
          s[i]['memTransferRate']         != d[i]['memTransferRate'] or \
          s[i]['memTransferRatemin']      != d[i]['memTransferRatemin'] or \
          s[i]['memTransferRatemax']      != d[i]['memTransferRatemax'] or \
          s[i]['memTransferRateeditable'] != d[i]['memTransferRateeditable']:
            return False

    return True

global ignorescreenattrs
global ignoregpuattrs

ignorescreenattrs=["GPUPerfModes", "GPUCoreTemp", "GPUCurrentClockFreqs",
                   " GPUCurrentPerfLevel", "GPUCurrentClockFreqsString"]

ignoregpuattrs=["GPUPerfModes", "GPUCoreTemp", "GPUCurrentClockFreqs",
                   " GPUCurrentPerfLevel", "GPUCurrentClockFreqsString"]

global in_ignored_attrs
def in_ignored_attrs(c, a):
    for e in a:
        if c == e:
            return True

    return False

global nv_attributes_equal
def nv_attributes_equal(nv1, nv2, t):
    if nv1 is None and nv2 is None:
        return True

    if t == "screen":
        ignore = ignorescreenattrs

    if t == "gpu":
        ignore = ignoregpuattrs
    
    n = len(nv1)
    i = 0
    while i < n:
        if in_ignored_attrs(nv1[i]['name'], ignore):
            del nv1[i]
            n = n - 1
            continue
        i = i + 1
    
    n = len(nv2)
    i = 0
    while i < n:
        if in_ignored_attrs(nv2[i]['name'], ignore):
            del nv2[i]
            n = n - 1
            continue
        i = i + 1

    if len(nv1) != len(nv2):
        return False

    nv1.sort(key = get_attr_name, reverse = False)
    nv2.sort(key = get_attr_name, reverse = False)
    for i in range(len(nv1)):
        if nv1[i]['name'] == 'GPUPerfModes' and \
           nv2[i]['name'] == 'GPUPerfModes':
            tmp1 = nv1[i]['value']
            tmp2 = nv2[i]['value']
            if not perfmodes_equal(tmp1, tmp2):
                print("perfmode not equal.")
                return False
        else:
            if nv1[i]['name'] != nv2[i]['name'] or \
               nv1[i]['value'] != nv2[i]['value']:
                print(nv1[i]['name'] + '\n' + nv2[i]['name'] + '\n' + nv1[i]['value'] + '\n' + nv2[i]['value'])
                return False

    return True

def nv_settings_equal(nv1, nv2):
    if (not nv_attributes_equal(nv1['Screen Attributes'], nv2['Screen Attributes'], 'screen')) or \
      (not nv_attributes_equal(nv1['GPU Attributes'], nv2['GPU Attributes'], 'gpu')):
        return False

    return True

def render_device_equal(rd1, rd2):
    if rd1['Driver'] != rd2['Driver'] or \
     rd1['Driver File'] != rd2['Driver File'] or \
     rd1['Driver Version'] != rd2['Driver Version'] or \
     rd1['sha256sum'] != rd2['sha256sum'] or \
     not array_equal(rd1['Environment'], rd2['Environment']) or \
     not array_equal(rd1['Module Parameters'], rd2['Module Parameters']):
        return False

    if rd1['Driver'] == 'nvidia':
        if not nv_settings_equal(rd1['Nvidia Settings'], rd2['Nvidia Settings']):
            return False

    return True

def match_db_record(rec, conds, mode):
    if rec['DevClass'] == conds['DevClass'] and \
     rec['Vendor'] == conds['Vendor'] and \
     rec['Device'] == conds['Device'] and \
     rec['SubVendor'] == conds['SubVendor'] and \
     rec['SubDevice'] == conds['SubDevice'] and \
     ((conds['Revision'] is None  and rec['Revision'] is None) or \
     rec['Revision'] == conds['Revision']) and \
     rec['Kernel Release'] == conds['Kernel Release'] and \
     rec['Kernel Version'] == conds['Kernel Version'] and \
     rec['Architecture'] == conds['Architecture'] and \
     (conds['DevClass'] == 'netcard' or \
     rec['Xorg Version'] ==conds['Xorg Version']) and \
     (conds['DevClass'] != 'Optimus' or \
     (conds['Render Device']['Vendor'] == rec['Render Device']['Vendor'] and \
     conds['Render Device']['Device'] == rec['Render Device']['Device'] and \
     conds['Render Device']['SubVendor'] == rec['Render Device']['SubVendor'] and \
     conds['Render Device']['SubDevice'] == rec['Render Device']['SubDevice'] and \
     ((conds['Render Device']['Revision'] is None and \
     rec['Render Device']['Revision'] is None) or \
     conds['Render Device']['Revision'] == rec['Render Device']['Revision']))):

        if MODE_MATCH_WITHOUT_OS_OR_MACHINE == mode:
            return True

        if MODE_MATCH_WITHOUT_MACHINE == mode and \
         rec['OS Distributor'] == conds['OS Distributor'] and \
         rec['OS Release'] == conds['OS Release'] and \
         rec['OS CodeName'] == conds['OS CodeName']:
            return True

        if MODE_MATCH_WITHOUT_OS == mode and \
         rec['Manufacturer'] == conds['Manufacturer'] and \
         rec['Product Name'] == conds['Product Name']:
            return True

        if MODE_MATCH_EXACT == mode and \
         rec['Manufacturer'] == conds['Manufacturer'] and \
         rec['Product Name'] == conds['Product Name'] and \
         rec['OS Distributor'] == conds['OS Distributor'] and \
         rec['OS Release'] == conds['OS Release'] and \
         rec['OS CodeName'] == conds['OS CodeName']:
            return True

    return False

def copy_record(rec):
    tmp = {}
    tmp['DevClass'] = rec['DevClass']
    tmp['Vendor'] = rec['Vendor']
    tmp['Device'] = rec['Device']
    tmp['SubVendor'] = rec['SubVendor']
    tmp['SubDevice'] = rec['SubDevice']
    tmp['Revision'] = rec['Revision']
    tmp['Kernel Release'] = rec['Kernel Release']
    tmp['Kernel Version'] = rec['Kernel Version']
    tmp['Architecture'] = rec['Architecture']
    tmp['Manufacturer'] = rec['Manufacturer']
    tmp['Product Name'] = rec['Product Name']
    tmp['OS Distributor'] = rec['OS Distributor']
    tmp['OS Release'] = rec['OS Release']
    tmp['OS CodeName'] = rec['OS CodeName']
    tmp['Driver'] = rec['Driver']
    tmp['Driver Version'] = rec['Driver Version']
    tmp['Driver File'] = rec['Driver File']
    tmp['Module Parameters'] = rec['Module Parameters']
    tmp['Kernel cmdline'] = rec['Kernel cmdline']
    tmp['sha256sum'] = rec['sha256sum']
    tmp['File URL'] = rec['File URL']

    if rec['DevClass'] == 'gfxcard' or \
       rec['DevClass'] == 'Optimus':
        tmp['Xorg Version'] = rec['Xorg Version']
        tmp['Environment'] = rec['Environment']
        tmp['Xorg Video Driver'] = rec['Xorg Video Driver']
        tmp['XFS Driver File'] = rec['XFS Driver File']
        tmp['XFS Driver Version'] = rec['XFS Driver Version']
        tmp['XFS sha256sum'] = rec['XFS sha256sum']
        tmp['XFS File URL'] = rec['XFS File URL']
        if tmp['Driver'] == 'nvidia':
            tmp['Nvidia Settings'] = rec['Nvidia Settings']

    if rec['DevClass'] == 'Optimus':
        tmp['Render Device'] = rec['Render Device']
        tmp['Bumblebee Version'] = rec['Bumblebee Version']

    tmp['Score'] = rec['Score']
    tmp['Package'] = rec['Package']

    if int(tmp['Score']) > 0:
        tmp['Works'] = 1
        tmp['Fails'] = 0
    else:
        tmp['Works'] = 0
        tmp['Fails'] = 1
    return tmp

def match_result_record(tmp, res):
    if tmp['Driver'] == res['Driver'] and \
     tmp['Driver Version'] == res['Driver Version'] and \
     tmp['Driver File'] == res['Driver File'] and \
     tmp['sha256sum'] == res['sha256sum'] and \
     (tmp['DevClass'] == 'netcard' or \
      (tmp['Xorg Version'] == res['Xorg Version'] and \
       array_equal(tmp['Environment'], res['Environment']) and \
       tmp['XFS Driver Version'] == res['XFS Driver Version'] and \
       tmp['XFS Driver File'] == res['XFS Driver File'] and \
       tmp['XFS sha256sum'] == res['XFS sha256sum'])) and \
     array_equal(tmp['Kernel cmdline'], res['Kernel cmdline']) and \
     array_equal(tmp['Module Parameters'], res['Module Parameters']) and \
     tmp['Manufacturer'] == res['Manufacturer'] and \
     tmp['Product Name'] == res['Product Name'] and \
     tmp['OS Distributor'] == res['OS Distributor'] and \
     tmp['OS Release'] == res['OS Release'] and \
     tmp['OS CodeName'] == res['OS CodeName']:
        # netcard
        if tmp['DevClass'] == 'netcard':
            return True

        # gfxcard or Optimus
        if not xv_equal(tmp['Xorg Video Driver'], res['Xorg Video Driver']):
            return False

        if tmp['Driver'] == 'nvidia':
            if not nv_settings_equal(tmp['Nvidia Settings'], res['Nvidia Settings']):
                return False

        if tmp['DevClass'] == 'gfxcard':
            return True

        # Optimus
        if tmp['DevClass'] == 'Optimus':
            if tmp['Bumblebee Version'] != res['Bumblebee Version']:
                return False

            if not render_device_equal(tmp['Render Device'], res['Render Device']):
                return False

        return True

    return False

def update_result_record(tmp, res):
    res['Score'] = math.floor((float(res['Score']) * (float(res['Works']) + \
                              float(res['Fails'])) + float(tmp['Score'])) / \
                              (float(res['Works']) + float(res['Fails']) + 1))
    res['Works'] = int(tmp['Works']) + int(res['Works'])
    res['Fails'] = int(tmp['Fails']) + int(res['Fails'])

def find_matched_drivers(db, conds, mode):
    result = []
    found = False
    for rec in db:
        if match_db_record(rec, conds, mode):
            found = True
            tmp = copy_record(rec)
            in_result = False
            for res in result:
                in_result = match_result_record(tmp, res)
                if in_result:
                    update_result_record(tmp, res)
                    break
            if not in_result:
                result.append(tmp)
    ret = {}
    ret['Error Code'] = 0
    ret['Policy'] = policy[mode]
    ret['Result'] = result
    return found, ret

# for the same machine only allow one feedback one day
global UPDATE_INTERVAL
debug = 1
if debug:
    UPDATE_INTERVAL = 3 * 60
else:
    UPDATE_INTERVAL=24 * 60 * 60

global update_record
def update_record(rec, vdb):
    rec['TimeStamp'] = time.time()

    rec['File URL'] = None
    for entry in vdb:
        if rec['sha256sum'] == entry['sha256sum']:
            rec['File URL'] = entry['File URL']
            break

    if rec['DevClass'] == 'gfxcard' or \
     rec['DevClass'] == 'Optimus':
        for i in range(len(rec['Xorg Video Driver'])):
            tmp = rec['Xorg Video Driver'][i]
            tmp['File URL'] = None
            for entry in vdb:
                if tmp['sha256sum'] == entry['sha256sum']:
                    tmp['File URL'] = entry['File URL']
                    break

        # XFS information
        rec['XFS File URL'] = None
        for entry in vdb:
            if rec['XFS sha256sum'] == entry['sha256sum']:
                rec['XFS File URL'] = entry['File URL']
                break

    if rec['DevClass'] == 'Optimus':
        # FIXME, maybe bumblebee's File URI too?
        tmp = rec['Render Device']
        tmp['File URL'] = None
        for entry in vdb:
            if tmp['sha256sum'] == entry['sha256sum']:
                tmp['File URL'] = entry['File URL']
                break

    if rec['File URL'] is None:
        return False

    if rec['DevClass'] == 'gfxcard' or \
     rec['DevClass'] == 'Optimus':
        for i in range(len(rec['Xorg Video Driver'])):
            if rec['Xorg Video Driver'][i]['File URL'] is None:
                return False
        if rec['XFS File URL'] is None:
            return False

    if rec['DevClass'] == 'Optimus':
        if rec['Render Device']['File URL'] is None:
            return False

    return True

class RequestHandler(pyjsonrpc.HttpRequestHandler):

    @pyjsonrpc.rpcmethod
    def query(self, conds):
        """Method for query"""
        # Do actual query here
        dbfile = '../1'
        dbfp = open(dbfile, 'r')
        db = json.load(dbfp)
        dbfp.close()
        print(json.dumps(db, indent = 2))

        # Try exact match first
        found, result = find_matched_drivers(db, conds, MODE_MATCH_EXACT)
        if found:
            return result

        found, result = find_matched_drivers(db, conds, MODE_MATCH_WITHOUT_OS)
        if found:
            return result

        found, result = find_matched_drivers(db, conds, MODE_MATCH_WITHOUT_MACHINE)
        if found:
            return result

        found, result = find_matched_drivers(db, conds, MODE_MATCH_WITHOUT_OS_OR_MACHINE)
        if found:
            return result
        # Not found any driver, return error
        result = {'Error Code': 1,
                  'Message': 'Not found matched driver.'}
        return result

    @pyjsonrpc.rpcmethod
    def update(self, info):
        """Update collected information"""
        # Do update here
        result = {}
        result['Error Code'] = 0
        result['Message'] = ''

        fp = open('../1', 'r')
        db = json.load(fp)
        fp.close()

        fp = open('../vfile.json', 'r')
        vdb = json.load(fp)
        fp.close()

        for rec in info:
            for entry in db:
                if rec['Machine ID'] == entry['Machine ID'] and \
                  match_db_record(entry, rec, MODE_MATCH_EXACT):
                    if time.time() - entry['TimeStamp'] < UPDATE_INTERVAL:
                        result['Error Code'] = 2
                        result['Message'] = "Feedback too frequently, only once allowed each day."
                        return result

            success = update_record(rec, vdb)
            db.append(rec)

            if success:
                #db.append(rec)
                pass
            else:
                result['Error Code'] = 1
                if result['Message'] == '':
                    result['Message'] = "Driver File not found for %s" % (rec['Driver'])
                else:
                    result['Message'] = result['Message'] + "\n" +\
                                        "Driver File not found for %s" % (rec['Driver'])

        if result['Error Code'] == 0:
            result['Message'] = "Information Updated successfully"

        fp = open('../1', 'w')
        json.dump(db, fp, indent = 2)
        fp.close()

        return result

# Threading http server

server = pyjsonrpc.ThreadingHttpServer(
         server_address = ('localhost', 4000),
         RequestHandlerClass = RequestHandler
         )

print("Starting HTTP server ...")
print("URL: http://localhost:4000/")

server.serve_forever()
