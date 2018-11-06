data "aws_iam_policy_document" "kinesis_firehose_stream_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "kinesis_firehose_access_bucket_assume_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.kinesis_firehose_stream_bucket.arn}",
      "${aws_s3_bucket.kinesis_firehose_stream_bucket.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "kinesis_firehose_access_glue_assume_policy" {
  statement {
    effect    = "Allow"
    actions   = ["glue:GetTableVersions"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "kinesis_firehose_stream_role" {
  name               = "kinesis_firehose_stream_role"
  assume_role_policy = "${data.aws_iam_policy_document.kinesis_firehose_stream_assume_role.0.json}"
}

resource "aws_iam_role_policy" "kinesis_firehose_access_bucket_policy" {
  name   = "kinesis_firehose_access_bucket_policy"
  role   = "${aws_iam_role.kinesis_firehose_stream_role.name}"
  policy = "${data.aws_iam_policy_document.kinesis_firehose_access_bucket_assume_policy.0.json}"
}

resource "aws_iam_role_policy" "kinesis_firehose_access_glue_policy" {
  name   = "kinesis_firehose_access_glue_policy"
  role   = "${aws_iam_role.kinesis_firehose_stream_role.name}"
  policy = "${data.aws_iam_policy_document.kinesis_firehose_access_glue_assume_policy.0.json}"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_assume_policy" {
  statement {
    effect = "Allow"

    actions = [
      "lambda:InvokeFunction",
      "lambda:GetFunctionConfiguration",
    ]

    resources = [
      "${aws_lambda_function.lambda_kinesis_firehose_data_transformation.arn}",
      "${aws_lambda_function.lambda_kinesis_firehose_data_transformation.arn}:*",
    ]
  }
}

data "aws_iam_policy_document" "lambda_to_cloudwatch_assume_policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "lambda_function_role"
  assume_role_policy = "${data.aws_iam_policy_document.lambda_assume_role.0.json}"
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda_function_policy"
  role   = "${aws_iam_role.kinesis_firehose_stream_role.name}"
  policy = "${data.aws_iam_policy_document.lambda_assume_policy.0.json}"
}

resource "aws_iam_role_policy" "lambda_to_cloudwatch_policy" {
  name   = "lambda_to_cloudwatch_policy"
  role   = "${aws_iam_role.lambda.name}"
  policy = "${data.aws_iam_policy_document.lambda_to_cloudwatch_assume_policy.0.json}"
}

data "aws_iam_policy_document" "cloudwatch_logs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["logs.${length(var.region) > 0 ? var.region: data.aws_region.default.name}.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudwatch_logs_assume_policy" {
  statement {
    effect    = "Allow"
    actions   = ["firehose:*"]
    resources = ["${aws_kinesis_firehose_delivery_stream.kinesis_firehose_stream.arn}"]
  }
}

resource "aws_iam_role" "cloudwatch_logs_role" {
  name               = "cloudwatch_logs_role"
  assume_role_policy = "${data.aws_iam_policy_document.cloudwatch_logs_assume_role.0.json}"
}

resource "aws_iam_role_policy" "cloudwatch_logs_policy" {
  name   = "cloudwatch_logs_policy"
  role   = "${aws_iam_role.cloudwatch_logs_role.name}"
  policy = "${data.aws_iam_policy_document.cloudwatch_logs_assume_policy.0.json}"
}
