# terraform-aws-kinesis-firehose
Terraform module to starting a [kinesis firehose]('https://aws.amazon.com/kinesis/data-firehose/') analytics

## Usage
```
module "kinesis-firehose" {
  source                                = "git::https://github.com/felipefrizzo/terraform-aws-kinesis-firehose.git?ref=master"
  kinesis_firehose_stream_name          = "stream_name"
  kinesis_firehose_stream_backup_prefix = "bucket_backup_prefix"
  bucket_name                           = "bucket_name"
  lambda_function_name                  = "lambda_function_name"
  lambda_function_file_name             = "kinesis-firehose-cloudwatch-logs-json-processor-python"
  glue_catalog_database_name            = "glue_catalog_database_name"
  glue_catalog_table_name               = "glue_catalog_table_name"
  glue_catalog_table_columns            = []
  cloudwatch_subscription_filter_name   = "cloudwatch_subscription_filter_name"
  cloudwatch_log_group_name             = "cloudwatch_log_group_name"
  cloudwatch_filter_pattern             = "cloudwatch_filter_pattern"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-------:|:--------:|
| kinesis_firehose_stream_name | Name to be use on kinesis firehose stream (e.g. `poc_logs`) | string | - | yes |
| kinesis_firehose_stream_backup_prefix | The prefix name to use for the kinesis backup (e.g. `backup_prefix`) | string | `` | no |
| bucket_name | Bucket name | string | - | yes |
| lambda_function_name | Lambda function name (e.g. `lambda_kinesis`) | string | - | yes |
| lambda_function_file_name | Lambda function file name | string | - | yes |
| glue_catalog_database_name | Glue catalog database name | string | - | yes |
| glue_catalog_table_name | Glue catalog database table name | string | - | yes |
| glue_catalog_table_columns | A list of table columns (e.g. `['id', 'name']`) | list | `<list>` | yes |
| cloudwatch_subscription_filter_name | Subscription filter name | string | - | yes |
| cloudwatch_log_group_name | Cloudwatch log group name | string | - | yes |
| cloudwatch_filter_pattern | Cloudwatch filter pattern | string | - | yes |
