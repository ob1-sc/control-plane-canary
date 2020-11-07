# Description

The goal of this repository is to provide a quick and easy way to stand up a Canary Control Plane (Concourse + UAA + Credhub) on any IAAS. (Only AWS/Azure supported currently)

The control plane will be stood up based on the instructions for [Installing Concourse for Platform Automation](https://docs.pivotal.io/p-concourse/v6/installation/install-platform-automation/)

The content of this repository is not a supported product, rather a template for setting up a Concourse based Control Plane that can be used for Tanzu Platform Automation tasks.

A DNS hosted zone will get created based on the `environment_name` and `hosted_zone` variables that you will need to provide. So if you have the following vars:
  - `environment_name` = cp
  - `hosted_zone` = example.com

then a hosted zone called `cp.example.com` would be created with the following DNS A records:
  - ci.cp.example.com (Concourse Web Interface)
  - opsmanager.cp.example.com (Ops Manager Web Interface)

It will be your responsibility to ensure the NS records of the hosted zone are recorded with the relevent parent DNS zone to ensure DNS resolves correctly. The installation will pause and provide you with the relevent hosted zone and NS details to allow registration to take place.

## Dependencies

- Valid [Tanzu Network](https://network.pivotal.io/) Account token
- Tools
  1. om cli
  1. pivnet cli
  1. jq cli
  1. bosh cli

### AWS

1. In your AWS account, ensure you have an IAM user with the following permissions:
  - IAM Policies:
    - AmazonEC2FullAccess
    - AmazonRDSFullAccess
    - AmazonRoute53FullAccess
    - AmazonS3FullAccess
    - AmazonVPCFullAccess
    - IAMFullAccess
    - AWSKeyManagementServicePowerUser
  - Key Policies:
    - kms:UpdateKeyDescription action allowed


### Azure

1. In your Azure account, ensure you have a Service Principle configured, see the following instructions for how to setup a service principle: https://docs.pivotal.io/ops-manager/2-10/azure/prepare-azure-terraform.html

## Getting Started

1. Set an environment variable to indicate the IAAS to deploy to:
```
$ export IAAS="aws|azure"
```

2. Set an environment variable to specicify you Tanzu Network account token (for downloading product files):
```
$ export PIVNET_TOKEN="<your pivnet token>"
```

3. Update the vars files for the IAAS you are deploying too under the `<repo root>/vars` directory, you should supply valid values based on your individual IAAS account.

Note, if you have forked this repo, be careful not to commit any secrets that you configure under the `<repo root>/vars` directory back to git as you do not want to expose your environment specifics/secrets.

3. Run the `<repo root>/scripts/control-plane/00-full-deploy.sh` script. During installation, the script will pause to provide you with hosted zone name and NS details so that you can register with DNS (required to allow the deploy script to successfully complete), once your DNS is successfully resolving you can hit [enter] to allow the script to continue.

### Troubleshooting

- If you have an issue during deployment such as file download error (common issue) or your script times out due to the time it takes to setup your DNS entries, you can either run the `00-full-deploy.sh` script again or if you want you can call the individual scripts that the full deploy delegates to. For example if the full deploy has succesfully deployed Ops Manager/BOSH and uploaded all of the Concourse bosh releases and stemcell but fails during Concourse deployment you could just run `05-deploy-concourse.sh`

## Accessing your environment

- To get your Ops Manager `admin` user password run the following command:
  ```
  $ <repo root>/scrips/utils/10-print-om-var.sh ops_manager_password
  ```

- Your login details for Concourse can be found in the `<repo root>/vars/<iaas>/concourse.yml` file

- To access the Concourse Credhub using the credhub cli, you can source the following script to set the relevent environement variables needed to access credhub:
  ```
  $ . <repo root>/scrips/utils/12-concourse-credhub-proxy.sh
  ```

## Tear Down

1. Run the `<repo root>/scripts/control-plane/20-full-delete.sh` script.