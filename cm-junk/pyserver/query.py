#!/usr/bin/env python

# -*- coding: utf-8 -*-

import sys
import os
import optparse
import json
import pyjsonrpc


options = optparse.OptionParser()
options.add_option("--devclass", dest = "devclass", help = "device class: netcard/gfxcard/Optimus")
options.add_option("--vendor", dest = "vendor", help = "hardware vendor ID, use lspci or hwinfo to get this information")
options.add_option("--device", dest = "device", help = "hardware device ID")
options.add_option("--subdevice", dest = "subdevice", help = "hardware subdevice ID")
options.add_option("--subvendor", dest = "subvendor", help = "hardware subvendor ID")
options.add_option("--revision", dest = "revision", help = "hardware revisin")
options.add_option("--krelease", dest = "krelease", help = "kernel release number, given by 'uname -r'")
options.add_option("--kversion", dest = "kversion", help = "kernel version number, given by 'uname -v'")
options.add_option("--arch", dest = "arch", help = "machine architecture, given by 'uname -m'")
options.add_option("--manufacturer", dest = "manufacturer", help = "machine manufacturer, given by dmidecode")
options.add_option("--product", dest = "product", help = "product name, given by dmidecode")
options.add_option("--distributor", dest = "distributor", help = "os vendor ID, lsb_release -i")
options.add_option("--osrelease", dest = "osrelease", help = "os release, lsb_release -r")
options.add_option("--oscodename", dest = "oscodename", help = "os codename, lsb_release -c")
options.add_option("--Xversion", dest = "Xversion", help = "Xorg version on target machine")
options.add_option("--rvendor", dest = "rvendor", help = "render device hardware vendor ID, use lspci or hwinfo to get this information")
options.add_option("--rdevice", dest = "rdevice", help = "render device hardware device ID")
options.add_option("--rsubdevice", dest = "rsubdevice", help = "render device hardware subdevice ID")
options.add_option("--rsubvendor", dest = "rsubvendor", help = "render device hardware subvendor ID")
options.add_option("--rrevision", dest = "rrevision", help = "render device hardware revision")

# maybe more options for gfxcard

query = {}

opts, args = options.parse_args()

query['DevClass'] = opts.devclass
query['Vendor'] = opts.vendor
query['Device'] = opts.device
query['SubDevice'] = opts.subdevice
query['SubVendor'] = opts.subvendor
query['Revision'] = opts.revision
query['Kernel Release'] = opts.krelease
query['Kernel Version'] = opts.kversion
query['Architecture'] = opts.arch
query['Manufacturer'] = opts.manufacturer
query['Product Name'] = opts.product
query['OS Distributor'] = opts.distributor
query['OS Release'] = opts.osrelease
query['OS CodeName'] = opts.oscodename
query['Xorg Version'] = opts.Xversion
query['Render Device'] = None
tmp = {}
tmp['Vendor'] = opts.rvendor
tmp['Device'] = opts.rdevice
tmp['SubVendor'] = opts.rsubvendor
tmp['SubDevice'] = opts.rsubdevice
tmp['Revision'] = opts.rrevision
if query['DevClass'] == 'Optimus':
    query['Render Device'] = tmp

# FIXME, some sanity check here?

if query['Vendor'] is None or \
   query['Device'] is None or \
   query['SubDevice'] is None or \
   query['SubVendor'] is None or \
   query['Kernel Release'] is None or \
   query['Kernel Version'] is None or \
   query['Architecture'] is None or \
   query['Manufacturer'] is None or \
   query['Product Name'] is None or \
   query['OS Distributor'] is None or \
   query['OS Release'] is None or \
   query['OS CodeName'] is None or \
   query['DevClass'] is None:
    print("Parameter error!\n")
    print("Please provide devclass, (sub)vendor, (sub)device, kernel, machine, OS arguments\n")
    sys.exit(-1)

if query['DevClass'] == 'netcard' and \
   (query['Xorg Version'] is not None or \
   query['Render Device'] is not None):
    print("netcard and Xorg Version cannot be used at the same time.\n")
    print("netcard cannot be use with render device. render device can only"
           " be used with Optimus.\n")
    sys.exit(-1)

if query['DevClass'] == 'gfxcard' and \
   (query['Xorg Version'] is None or \
   query['Render Device'] is not None):
    print("Xorg Version must be used with gfxcard\n")
    print("gfxcard cannot be use with render device. render device can only"
           " be used with Optimus.\n")
    sys.exit(-1)

if query['DevClass'] == 'Optimus' and \
   (query['Xorg Version'] is None or \
   query['Render Device'] is None or \
   query['Render Device']['Vendor'] is None or \
   query['Render Device']['Device'] is None or \
   query['Render Device']['SubVendor'] is None or \
   query['Render Device']['SubDevice'] is None):
    print("Optimus must provide Xorg Version.\n")
    print("Optimus must provide render device information.\n")
    sys.exit(-1)

if query['DevClass'] != 'Optimus' and \
  (tmp['Vendor'] is not None or \
   tmp['Device'] is not None or \
   tmp['SubVendor'] is not None or \
   tmp['SubDevice'] is not None):
    print("None Optimus device has no render device.")
    sys.exit(-1)

client = pyjsonrpc.HttpClient(
         url='http://localhost:4000/'
         )

print(json.dumps(query, indent=2))
print(json.dumps(client.call("query", query), indent=2))
# print(client.call("update", 2))
