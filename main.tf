data "aws_region" "default" {}

resource "aws_kinesis_firehose_delivery_stream" "kinesis_firehose_stream" {
  name        = "${var.kinesis_firehose_stream_name}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn       = "${aws_iam_role.kinesis_firehose_stream_role.arn}"
    bucket_arn     = "${aws_s3_bucket.kinesis_firehose_stream_bucket.arn}"
    buffer_size    = 128
    s3_backup_mode = "Enabled"

    s3_backup_configuration {
      role_arn    = "${aws_iam_role.kinesis_firehose_stream_role.arn}"
      bucket_arn  = "${aws_s3_bucket.kinesis_firehose_stream_bucket.arn}"
      prefix      = "${var.kinesis_firehose_stream_backup_prefix}"

      cloudwatch_logging_options {
        enabled         = true
        log_group_name  = "${aws_cloudwatch_log_group.kinesis_firehose_stream_logging_group.name}"
        log_stream_name = "${aws_cloudwatch_log_stream.kinesis_firehose_stream_logging_stream.name}"
      }
    }

    processing_configuration {
      enabled    = true
      processors = [{
        type = "Lambda"
        parameters = [{
          parameter_name  = "LambdaArn",
          parameter_value = "${aws_lambda_function.lambda_kinesis_firehose_data_transformation.arn}:$LATEST"
        }]
      }]
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "${aws_cloudwatch_log_group.kinesis_firehose_stream_logging_group.name}"
      log_stream_name = "${aws_cloudwatch_log_stream.kinesis_firehose_stream_logging_stream.name}"
    }

    data_format_conversion_configuration {
      input_format_configuration {
        deserializer {
          hive_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {}
        }
      }

      schema_configuration {
        database_name = "${aws_glue_catalog_database.glue_catalog_database.name}"
        table_name    = "${aws_glue_catalog_table.glue_catalog_table.name}"
        role_arn      = "${aws_iam_role.kinesis_firehose_stream_role.arn}"
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "kinesis_firehose_stream_logging_group" {
  name = "/aws/kinesisfirehose/${var.kinesis_firehose_stream_name}"
}

resource "aws_cloudwatch_log_stream" "kinesis_firehose_stream_logging_stream" {
  log_group_name = "${aws_cloudwatch_log_group.kinesis_firehose_stream_logging_group.name}"
  name = "S3Delivery"
}

resource "aws_s3_bucket" "kinesis_firehose_stream_bucket" {
  bucket = "${var.bucket_name}"
  acl = "private"
}

data "null_data_source" "lambda_file" {
  inputs {
    filename = "${substr("${path.module}/functions/${var.lambda_function_file_name}.py", length(path.cwd) + 1, -1)}"
  }
}

data "null_data_source" "lambda_archive" {
  inputs {
    filename = "${substr("${path.module}/functions/${var.lambda_function_file_name}.zip", length(path.cwd) + 1, -1)}"
  }
}

data "archive_file" "kinesis_firehose_data_transformation" {
  type        = "zip"
  source_file = "${data.null_data_source.lambda_file.outputs.filename}"
  output_path = "${data.null_data_source.lambda_archive.outputs.filename}"
}

resource "aws_cloudwatch_log_group" "lambda_function_logging_group" {
  name = "/aws/lambda/${var.lambda_function_name}"
}

resource "aws_lambda_function" "lambda_kinesis_firehose_data_transformation" {
  filename      = "${data.archive_file.kinesis_firehose_data_transformation.0.output_path}"
  function_name = "${var.lambda_function_name}"

  role              = "${aws_iam_role.lambda.arn}"
  handler           = "${var.lambda_function_file_name}.lambda_handler"
  source_code_hash  = "${data.archive_file.kinesis_firehose_data_transformation.0.output_base64sha256}"
  runtime           = "python3.6"
  timeout           = 60
}

resource "aws_glue_catalog_database" "glue_catalog_database" {
  name = "${var.glue_catalog_database_name}"
}

resource "aws_glue_catalog_table" "glue_catalog_table" {
  name          = "${var.glue_catalog_table_name}"
  database_name = "${aws_glue_catalog_database.glue_catalog_database.name}"
  parameters    = { "classification" = "parquet" }

  storage_descriptor = {
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
    location      = "s3://${aws_s3_bucket.kinesis_firehose_stream_bucket.bucket}/"
    ser_de_info   = {
      name                  = "JsonSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = 1
        "explicit.null"        = false
        "parquet.compression"  = "SNAPPY"
      }
    }

    columns = "${var.glue_catalog_table_columns}"
  }
}

resource "aws_cloudwatch_log_subscription_filter" "cloudwatch_subscription_filter" {
  name           = "${var.cloudwatch_subscription_filter_name}"
  log_group_name = "${var.cloudwatch_log_group_name}"
  filter_pattern = "${var.cloudwatch_filter_pattern}"

  destination_arn = "${aws_kinesis_firehose_delivery_stream.kinesis_firehose_stream.arn}"
  distribution    = "ByLogStream"
  
  role_arn = "${aws_iam_role.cloudwatch_logs_role.arn}"
}

