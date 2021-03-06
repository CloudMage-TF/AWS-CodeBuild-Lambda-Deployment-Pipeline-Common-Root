# Terraform configuration 
terraform {
  required_version = ">= 0.12"
}

#Provider configuration. Typically there will only be one provider config, unless working with multi account and / or multi region resources
provider "aws" {
  region = var.provider_region
}

######################
# CodeBuild KMS Key: #
######################
// Create the required KMS Key
module "codebuild_cmk" {
  source = "git@github.com:CloudMage-TF/AWS-KMS-Module.git?ref=v1.0.3"

  // Required Vars
  kms_key_alias_name          = var.cmk_alias
  kms_key_description         = var.cmk_description
  
  // Optional Vars
  # kms_owner_principal_list    = var.cmk_owners
  # kms_admin_principal_list    = var.cmk_admins
  # kms_user_principal_list     = var.cmk_users
  # kms_resource_principal_list = var.cmk_grantees

  // Tags
  kms_tags = merge(
    var.tags,
    {
      Module_GitHub_URL     = "https://github.com/CloudMage-TF/AWS-KMS-Module.git"
    }
  )
}

###########################
# SNS Notification Topic: #
###########################
resource "aws_sns_topic" "events" {
  name              = var.sns_topic_name
  display_name      = var.sns_display_name
  kms_master_key_id = module.codebuild_cmk.kms_key_arn
}

#############################
# Lambda Deployment Bucket: #
#############################
module "codebuild_s3_artifact_bucket" {
  source = "git@github.com:CloudMage-TF/AWS-S3Bucket-Module.git?ref=v1.1.0"

  // Required Vars
  s3_bucket_name              = var.bucket_name
  s3_bucket_region            = var.bucket_region
  s3_bucket_prefix_list       = var.bucket_prefix
  s3_bucket_suffix_list       = var.bucket_suffix
  s3_versioning_enabled       = var.s3_versioning_enabled
  s3_encryption_enabled       = var.s3_encryption_enabled
  s3_kms_key_arn              = module.codebuild_cmk.kms_key_arn
  
  // Optional Vars
  # s3_mfa_delete               = var.s3_mfa_delete
  # s3_bucket_acl               = var.s3_bucket_acl

  // Tags
  s3_bucket_tags = merge(
    var.tags,
    {
      Module_GitHub_URL     = "https://github.com/CloudMage-TF/AWS-S3Bucket-Module.git"
    }
  )
}

#####################################
# Lambda Deployment Security Group: #
#####################################
resource "aws_security_group" "codebuild_security_group" {
  name        = var.security_group_name
  description = "Allows Outbound from CodeBuild to Public for updates."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    description = "All traffic"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###########################
# Lambda Deployment Role: #
###########################
module "codebuild_service_role" {
  source = "git@github.com:CloudMage-TF/AWS-CodeBuild-Lambda-Deployment-Pipeline-Role-Module.git?ref=v1.0.3"
  
  // Required Vars
  codebuild_role_name                     = var.role_name
  codebuild_role_description              = var.role_description
  codebuild_role_s3_resource_access       = [module.codebuild_s3_artifact_bucket.s3_bucket_arn]
  codebuild_sns_resource_access           = [aws_sns_topic.events.arn]
  codebuild_cmk_resource_access           = [module.codebuild_cmk.kms_key_arn]

  // Tags
  codebuild_role_tags = merge(
    var.tags,
    {
      Module_GitHub_URL     = "https://github.com/CloudMage-TF/AWS-CodeBuild-Lambda-Deployment-Pipeline-Role-Module.git"
    }
  )
}
