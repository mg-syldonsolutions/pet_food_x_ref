terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# Catch-all proxy: /{proxy+}
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy_any" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}


locals {
  app  = "petxref"
  env  = "prod"
  name = "${local.app}-${local.env}"
}
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-igw" }
}

# Public subnets (2 AZs)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name}-public-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-public-rt" }
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role      = aws_iam_role.api_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private subnets (2 AZs)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 100 + count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "${local.name}-private-${count.index}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.name}-private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
resource "aws_security_group" "lambda_sg" {
  name        = "${local.name}-lambda-sg"
  description = "Lambda security group"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-lambda-sg" }
}

resource "aws_security_group" "db_sg" {
  name        = "${local.name}-db-sg"
  description = "Aurora security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "Postgres from Lambda"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-db-sg" }
}
resource "aws_db_subnet_group" "aurora" {
  name       = "${local.name}-aurora-subnets"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "${local.name}-aurora"
  engine             = "aurora-postgresql"
  database_name      = "petxref"
  master_username    = "postgres"

  # RDS will create/store the password in Secrets Manager automatically:
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # Serverless v2 scaling
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 2
  }

  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = { Name = "${local.name}-aurora" }
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier         = "${local.name}-aurora-1"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
}

# --- IAM for Lambda ---
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_lambda_role" {
  name               = "${local.name}-api-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.api_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Lambda (zip) ---
resource "aws_lambda_function" "api" {
  function_name = "${local.name}-api"
  role          = aws_iam_role.api_lambda_role.arn
  runtime       = "python3.14"
  handler       = "api_handler.lambda_handler"

  filename         = "${path.module}/build/api.zip"
  source_code_hash = filebase64sha256("${path.module}/build/api.zip")

  memory_size   = 256
  timeout       = 10
  architectures = ["arm64"]
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
  environment {
    variables = {
      ENV          = local.env
      ADMIN_KEY = "lsdhjfljsaldjflaj"

      SERVICE_NAME = "api"

      # DB connectivity (we’ll use these next)
      DB_HOST       = aws_rds_cluster.aurora.endpoint
      DB_NAME       = "petxref"
      DB_SECRET_ARN = aws_rds_cluster.aurora.master_user_secret[0].secret_arn
    }
  }
}

data "aws_iam_policy_document" "api_secret_access" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_rds_cluster.aurora.master_user_secret[0].secret_arn]
  }
  statement {
    actions   = ["kms:Decrypt"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "api_secret_access" {
  name   = "${local.name}-api-secret-access"
  policy = data.aws_iam_policy_document.api_secret_access.json
}

resource "aws_iam_role_policy_attachment" "api_secret_access" {
  role       = aws_iam_role.api_lambda_role.name
  policy_arn = aws_iam_policy.api_secret_access.arn
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = 14
}

# --- API Gateway REST ---
resource "aws_api_gateway_rest_api" "api" {
  name = "${local.name}-rest"
}

# /health
resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "health"
}

resource "aws_api_gateway_method" "health_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "health_get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.health.id
  http_method             = aws_api_gateway_method.health_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# /meta
resource "aws_api_gateway_resource" "meta" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "meta"
}

# /meta/symptoms
resource "aws_api_gateway_resource" "meta_symptoms" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.meta.id
  path_part   = "symptoms"
}

resource "aws_api_gateway_method" "meta_symptoms_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.meta_symptoms.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "meta_symptoms_get" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.meta_symptoms.id
  http_method             = aws_api_gateway_method.meta_symptoms_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
}

# Permission for API Gateway to invoke Lambda
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Deploy
resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    # force redeploy on changes
    redeploy = sha1(jsonencode([
      aws_api_gateway_method.health_get.id,
      aws_api_gateway_integration.health_get.id,
      aws_api_gateway_method.meta_symptoms_get.id,
      aws_api_gateway_integration.meta_symptoms_get.id,
      aws_api_gateway_method.proxy_any.id,
      aws_api_gateway_integration.proxy_any.id,
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.health_get,
    aws_api_gateway_integration.meta_symptoms_get,
    aws_api_gateway_integration.proxy_any,
  ]

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.deploy.id
  stage_name    = local.env
}

output "api_base_url" {
  value = aws_api_gateway_stage.prod.invoke_url
}
output "db_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "db_secret_arn" {
  value = aws_rds_cluster.aurora.master_user_secret[0].secret_arn
}
resource "aws_security_group" "vpce_sg" {
  name        = "${local.name}-vpce-sg"
  description = "VPC endpoint security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "HTTPS from Lambda"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-west-2.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id]
}
