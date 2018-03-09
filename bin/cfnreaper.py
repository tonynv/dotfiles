#!/usr/bin/env python
# author: sancard@amazon.com

from __future__ import print_function
import boto3
import botocore
import argparse
import os
import yaml
import datetime
import sys


# Creating Parser
parser = argparse.ArgumentParser(prog="cfnreaper.py", description="Reaper for AWS Quick Starts")
environment = parser.add_mutually_exclusive_group(required=True)
environment.add_argument("-d", "--develop", action='store_true', help="Specify to reap develop resources")
environment.add_argument("-m", "--master", action='store_true', help="Specify to reap master resources")
parser.add_argument("-sam", "--stack-age-minutes", type=int, help="Specify the age in MINUTES for the resources to destroy. If not provided, the default from the YML config is used.")
parser.add_argument("-r", "--repo-name", type=str, help="Specify the git repository name. Use this to narrow down to specific Quick Start stacks.")
parser.add_argument("-cfn", "--cfn-only", action='store_true', help="Specify to only reap CFN stacks")
parser.add_argument("-s3", "--s3-only", action='store_true', help="Specify to only reap S3 buckets")
parser.add_argument("-c", "--config", type=str, help="YML config input")
parser.add_argument("-p", "--profile", type=str, help="Use existing AWS credentials profile")
parser.add_argument("-a", "--access-key-id", type=str, help="AWS Access Key ID")
parser.add_argument("-s", "--secret-access-key", type=str, help="Secret Access Key ID")
parser.add_argument("-v", "--verbose", action='count', help="Verbose mode. Can be supplied multiple times to increase verbosity")
args = parser.parse_args()
if args.profile is not None:
    if not (args.secret_access_key is None and args.access_key_id is None):
        parser.error("Cannot use -p/--profile with -a/--access-key-id or -s/--secret-access-key")

deleted_buckets = []


def delete_bucket(target_bucket_name):
    if args.verbose >= 1:
        print("\n[INFO]: Working on bucket [" + str(target_bucket_name) + "]")
    bucket_resource = s3_resource.Bucket(target_bucket_name)
    if args.verbose >= 1:
        print("[INFO]: Getting and deleting all object versions")
    try:
        object_versions = bucket_resource.object_versions.all()
        for object_version in object_versions:
            # TODO: Delete sets of 1000 object versions to reduce delete requests
            object_version.delete()
    except botocore.exceptions.ClientError as e:
        if e.response['Error']['Code'] == 'AccessDenied':
            print("[WARNING]: Unable to delete object versions. (AccessDenied)")
        if e.response['Error']['Code'] == 'NoSuchBucket':
            print("[WARNING]: Unable to get versions. (NoSuchBucket)")
        else:
            print(e)
    if args.verbose >= 1:
        print("[INFO]: Deleting bucket [" + str(target_bucket_name) + "]")
    try:
        bucket_resource.delete()
    except botocore.exceptions.ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchBucket':
            print("[WARNING]: Bucket was already deleted. (NoSuchBucket)")
        else:
            print(e)
    deleted_buckets.append(target_bucket_name)


def delete_security_groups(vpc_id):
    ec2_client = boto_session.client('ec2')
    ec2_resource = boto_session.resource('ec2')
    # EMR-managed SG Cleanup
    sec_groups = ec2_client.describe_security_groups(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    # Clear out ingress/egress rules
    for sec_group in sec_groups['SecurityGroups']:
        if str(sec_group['GroupName']).startswith('ElasticMapReduce-'):
            sec_group_obj = ec2_resource.SecurityGroup(sec_group['GroupId'])
            ip_permissions = sec_group_obj.ip_permissions
            if len(ip_permissions) >= 1:
                sec_group_obj.revoke_ingress(IpPermissions=ip_permissions)
            ip_permissions_egress = sec_group_obj.ip_permissions_egress
            if len(ip_permissions_egress) >= 1:
                sec_group_obj.revoke_egress(IpPermissions=ip_permissions_egress)
    # Delete group
    for sec_group in sec_groups['SecurityGroups']:
        if str(sec_group['GroupName']).startswith('ElasticMapReduce-'):
            sec_group_obj = ec2_resource.SecurityGroup(sec_group['GroupId'])
            sec_group_obj.delete()


# NOTE: SIMILAR get_cfn_stack_resources EXISTS IN ALFRED
# TODO: Make a common library
def get_cfn_stack_resources(stack_name):
    try:
        stack_resource_summaries = []
        resources_response = cfn_client.list_stack_resources(StackName=stack_name)
        stack_resource_summaries.extend(resources_response['StackResourceSummaries'])
        while 'NextToken' in resources_response:
            resources_response = cfn_client.list_stack_resources(NextToken=resources_response['NextToken'], StackName=stack_name)
            stack_resource_summaries.extend(resources_response['StackResourceSummaries'])
    except botocore.exceptions.ClientError:
        print("\nError trying to get the resources for stack [" + str(stack_name) + "] in region [" + str(region) + "]")
        sys.exit("[FATAL]: Error trying to get the resources for stack [" + str(stack_name) + "] in region [" + str(region) + "]")

    return stack_resource_summaries


def specialized_cleanup():
    resources = get_cfn_stack_resources(stack_name=stack['StackName'])
    for resource in resources:
        if resource['ResourceType'] == 'AWS::S3::Bucket' and 'PhysicalResourceId' in resource:
            # S3 Cleanup
            delete_bucket(resource['PhysicalResourceId'])
        elif resource['ResourceType'] == 'AWS::EC2::VPC' and 'PhysicalResourceId' in resource:
            delete_security_groups(resource['PhysicalResourceId'])
        # Below elif is not needed since the reaper goes over every stack
        '''
        elif resource['ResourceType'] == 'AWS::CloudFormation::Stack' and 'PhysicalResourceId' in resource:
            specialized_cleanup_cfn_stack(resource['PhysicalResourceId'])
        '''


def create_boto_session(profile_name=None, aws_access_key_id=None, aws_secret_access_key=None, region_name=None):
        # Use profile
        if profile_name:
            _boto_session = boto3.Session(profile_name=profile_name, region_name=region_name)
        # Use explicit credentials
        elif aws_access_key_id and aws_secret_access_key:
            _boto_session = boto3.Session(aws_access_key_id=aws_access_key_id,
                                         aws_secret_access_key=aws_secret_access_key, region_name=region_name)
        # Attempt to use IAM role from instance profile
        else:
            _boto_session = boto3.Session(region_name=region_name)
        return _boto_session


# Loading configuration YAML
if args.config is None:
    yml_config_path = os.path.join(os.path.split(os.path.realpath(__file__))[0], "cfnreaper.yml")
else:
    yml_config_path = args.config

if args.verbose >= 1:
    print("[INFO]: Loading YAML config from [{}]".format(yml_config_path))
with open(yml_config_path, 'r') as yml_config:
    yml_data = yaml.safe_load(yml_config)


# Determine search string
if args.develop:
    search_string = yml_data['global']['alfred']['develop']['search-string-prefix']
elif args.master:
    search_string = yml_data['global']['alfred']['master']['search-string-prefix']

if args.repo_name is not None:
    if args.repo_name.startswith('quickstart-'):
        search_string = '-'.join([search_string, args.repo_name])
    else:
        print("[ERROR]: Repo name must start with 'quickstart-'. Aborting.")
        exit(1)
if args.verbose >= 1:
    print("[INFO]: The search string to be used for the CFN stacks is [" + str(search_string) + "]")


# Determine cutoff time from stack age
current_utc_time = datetime.datetime.utcnow()
if args.verbose >= 1:
    print("[INFO]: Current UTC time is [" + str(current_utc_time) + "]")

if args.stack_age_minutes is None:
    stack_age = yml_data['global']['settings']['stack-age-minutes']
else:
    stack_age = args.stack_age_minutes
cutoff_utc_time = current_utc_time - datetime.timedelta(minutes=stack_age)
if args.verbose >= 1:
    print("[INFO]: Cutoff UTC time for reaping resources is anything created before [" + str(cutoff_utc_time) + "]")

if not args.s3_only:
    boto_session = create_boto_session(profile_name=args.profile, aws_access_key_id=args.access_key_id, aws_secret_access_key=args.secret_access_key)

    regions = boto_session.get_available_regions('cloudformation')
    # Manually adding ap-south-1, us-east-2 region...
    if u'ap-south-1' not in regions:
        regions.append(u'ap-south-1')
    if u'us-east-2' not in regions:
        regions.append(u'us-east-2')
    if u'ca-central-1' not in regions:
        regions.append(u'ca-central-1')
    if u'eu-west-2' not in regions:
        regions.append(u'eu-west-2')
    regions.sort()
    if args.verbose >= 1:
        print("[INFO]: Regions to work on:\n  - {}".format('\n  - '.join(regions)))

    for region in regions:
        if args.verbose >= 1:
            print("\n[INFO]: REGION [{}]".format(region))

        boto_session = create_boto_session(profile_name=args.profile, aws_access_key_id=args.access_key_id, aws_secret_access_key=args.secret_access_key, region_name=region)

        cfn_client = boto_session.client('cloudformation')
        cfn_resource = boto_session.resource('cloudformation')
        s3_client = boto_session.client('s3')
        s3_resource = boto_session.resource('s3')

        print("[INFO]: CloudFormation Stacks and Resources")

        # Not using the describe_stacks because it's more chatty. Instead let's use list_stacks but filter DELETE_COMPLETE
        '''
        stacks = cfn_client.describe_stacks()

        if stacks['Stacks']:
            for stack in stacks['Stacks']:
                if args.verbose >= 2:
                    print("[INFO]: ********************************************************")
                    print("[INFO]: Stack Name: [{}]".format(stack['StackName']))
                    print("[INFO]: Stack ID: [{}]".format(stack['StackId']))
                    print("[INFO]: Stack Creation Time: [{}]".format(stack['CreationTime']))
                    print("[INFO]: Stack Status: [{}]".format(stack['StackStatus']))
                    if args.verbose >= 3:
                        print("[INFO]: Stack Summary:")
                        print(stack)
                    print("[INFO]: ********************************************************")
                if stack['StackName'].startswith(search_string):
                    if args.verbose >= 1:
                        print("[INFO]: Found a stack to reap! [{}]".format(stack['StackName']))
                    current_stack = cfn_resource.Stack(stack['StackName'])
                else:
                    if args.verbose >= 3:
                        print("[INFO]: The stack [{}] is not eligible for reaping. Maybe next time!".format(stack['StackName']))
        else:
            if args.verbose >= 3:
                print("[INFO]: Nothing here. Maybe next time!")


        '''
        # Skip for DELETE_COMPLETE since they are already reaped
        stack_filter = [
            'CREATE_IN_PROGRESS',
            'CREATE_FAILED',
            'CREATE_COMPLETE',
            'ROLLBACK_IN_PROGRESS',
            'ROLLBACK_FAILED',
            'ROLLBACK_COMPLETE',
            'DELETE_IN_PROGRESS',
            'DELETE_FAILED',
            # 'DELETE_COMPLETE',
            'UPDATE_IN_PROGRESS',
            'UPDATE_COMPLETE_CLEANUP_IN_PROGRESS',
            'UPDATE_COMPLETE',
            'UPDATE_ROLLBACK_IN_PROGRESS',
            'UPDATE_ROLLBACK_FAILED',
            'UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS',
            'UPDATE_ROLLBACK_COMPLETE',
        ]
        stack_summary = []
        response = cfn_client.list_stacks(StackStatusFilter=stack_filter)
        deleted_a_stack = False
        if 'StackSummaries' in response and len(response['StackSummaries']) > 0:
            stack_summary.extend(response['StackSummaries'])
            while 'NextToken' in response:
                response = cfn_client.list_stacks(NextToken=response['NextToken'], StackStatusFilter=stack_filter)
                stack_summary.extend(response['StackSummaries'])

            for stack in stack_summary:
                # Ensure that stack start with search string
                if stack['StackName'].startswith(search_string) and stack['CreationTime'].replace(tzinfo=None) < cutoff_utc_time:
                    if args.verbose >= 2:
                        print("[INFO]: ********************************************************")
                        print("[INFO]: Stack Name: [{}]".format(stack['StackName']))
                        print("[INFO]: Stack ID: [{}]".format(stack['StackId']))
                        print("[INFO]: Stack Creation Time: [{}]".format(stack['CreationTime'].replace(tzinfo=None)))
                        print("[INFO]: Stack Status: [{}]".format(stack['StackStatus']))
                        if args.verbose >= 4:
                            print("[INFO]: Stack Summary:")
                            print(stack)
                        print("[INFO]: ********************************************************")
                    if args.verbose >= 1:
                        print("[INFO]: Found the stack [{}]. Time to reap it!".format(stack['StackName']))

                    # Try to get the stack and delete it (if the status hasn't changed to DELETE_COMPLETE)
                    try:
                        current_stack = cfn_resource.Stack(stack['StackName'])
                        if current_stack.stack_status != 'DELETE_COMPLETE':
                            specialized_cleanup()

                            current_stack.delete()
                            deleted_a_stack = True
                            if args.verbose >= 2:
                                print("[INFO]: Delete signal sent!")
                        else:
                            if args.verbose >= 1:
                                print("[WARNING]: The status changed and the stack couldn't be deleted.")
                    except:
                        print("[WARNING]: Oops! Something happened when trying to reap the stack [{}]".format(stack['StackName']))
                        print("[WARNING]: Info:")
                        print(sys.exc_info[0])
                else:
                    # print(ineligible stack details only at level 3 verbosity
                    if args.verbose >= 3:
                        print("[INFO]: ********************************************************")
                        print("[INFO]: Stack Name: [{}]".format(stack['StackName']))
                        print("[INFO]: Stack ID: [{}]".format(stack['StackId']))
                        print("[INFO]: Stack Creation Time: [{}]".format(stack['CreationTime'].replace(tzinfo=None)))
                        print("[INFO]: Stack Status: [{}]".format(stack['StackStatus']))
                        if args.verbose >= 4:
                            print("[INFO]: Stack Summary:")
                            print(stack)
                        print("[INFO]: ********************************************************")
                    if args.verbose >= 2:
                        print("[INFO]: The stack [{}] is not eligible for reaping. Maybe next time!".format(stack['StackName']))
            if not deleted_a_stack and args.verbose >= 1:
                print("[INFO]: No eligible stacks here. Maybe next time!")
        else:
            if args.verbose >= 1:
                print("[INFO]: No stacks here. Maybe next time!")

if not args.cfn_only:
    # TODO: Iterate through all accounts/profiles/keys
    print("\n\n[INFO]: S3 buckets")
    boto_session = create_boto_session(profile_name=args.profile, aws_access_key_id=args.access_key_id, aws_secret_access_key=args.secret_access_key)
    s3_client = boto_session.client('s3', config=boto3.session.Config(signature_version='s3v4'))
    s3_resource = boto_session.resource('s3', config=boto3.session.Config(signature_version='s3v4'))
    buckets = s3_client.list_buckets()
    print("[INFO]: ACCOUNT [{}]".format(buckets['Owner']['DisplayName']))
    for bucket in buckets['Buckets']:
        if bucket['Name'] not in deleted_buckets and bucket['Name'].startswith(search_string) and bucket['CreationDate'].replace(tzinfo=None) < cutoff_utc_time:
            delete_bucket(bucket['Name'])

if args.verbose >= 1:
    print("[INFO]: Done.")
