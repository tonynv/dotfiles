#!/usr/bin/env python2.7
import json
import argparse
import os

def create_file(file_path):
    with open(file_path, 'wb') as json_file:
        json_file.write(json.dumps(json_data, indent=4, separators=(',', ': '), sort_keys=True))

parser = argparse.ArgumentParser(description='Creates json file for Alfred')
parser.add_argument("template",  type=str, help="Specify the path of template file")
args = parser.parse_args()

if os.path.isfile(args.template) and args.template.endswith('.template'):
    parameters = json.load(open(args.template, 'r'))
else:
    print "[ERROR]: File invalid"
    exit(0)

json_data = []
# For each parameter create item for json file
for params in sorted(parameters['Parameters']):
    temp_dict = {"ParameterKey": params}
    if 'Default' in parameters['Parameters'][params]:  # Checks if parameter has default value
        temp_dict["ParameterValue"] = parameters['Parameters'][params]['Default']
    else:  # TODO: If default isn't there, ask user for value to put in
        temp_dict["ParameterValue"] = "NEED_VALUE"
    json_data.append(temp_dict)

file_name = os.path.splitext(os.path.basename(args.template))[0]
new_file = os.path.join(os.path.dirname(os.path.abspath(args.template)), file_name + ".json")
if os.path.isfile(new_file):
    print "JSON file already exists, would you like to overwrite? (y/n): "
    reply = raw_input()
    if reply == 'y':
        create_file(new_file)
    else:
        print "What would you like to call file name? Do not include .json"
        new_name = raw_input()
        new_file = str(new_file).replace(file_name, new_name)
        create_file(new_file)
else:
    create_file(new_file)
