terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "societe-numerique"

    workspaces {
      prefix = "strapi-"
    }
  }

  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
    }
    random = {
      source = "hashicorp/random"
    }
  }
  required_version = ">= 0.13"
}

variable "REGISTRY_ENDPOINT" {
  type        = string
  description = "Container Registry endpoint where your application container is stored"
}

variable "DEFAULT_PROJECT_ID" {
  type        = string
  description = "Project ID where your resources will be created"
}

variable "DEFAULT_ORGANIZATION_ID" {
  type        = string
  description = "Organization ID where project is hosted"
}

variable "ADMIN_EMAIL" {
  type        = string
  description = "Strapi administrator email. Will be created at each container start."
}

variable "ADMIN_PASSWORD" {
  type        = string
  description = "Strapi administrator password. Will be updated at each container start."
}

locals {
  appName = "my-blog"
  secrets = ["app_keys", "api_token_salt", "admin_jwt_secret", "transfer_token_salt", "jwt_secret"]
}

resource "random_bytes" "generated_secrets" {
  for_each = toset(local.secrets)
  length   = 16
}

resource "scaleway_container_namespace" "main" {
  name        = local.appName
  description = "Namespace created for full serverless Strapi blog deployment"
  project_id  = var.DEFAULT_PROJECT_ID
}

resource "scaleway_container" "main" {
  name            = local.appName
  description     = "Container for Strapi blog"
  namespace_id    = scaleway_container_namespace.main.id
  registry_image  = "${var.REGISTRY_ENDPOINT}/my-strapi-blog:latest"
  port            = 1337
  cpu_limit       = 1120
  memory_limit    = 4096
  min_scale       = 0
  max_scale       = 5
  timeout         = 600
  max_concurrency = 80
  privacy         = "public"
  protocol        = "http1"
  deploy          = true

  environment_variables = {
    "DATABASE_CLIENT"   = "postgres",
    "DATABASE_USERNAME" = scaleway_iam_application.app.id,
    "DATABASE_HOST"     = trimsuffix(trimprefix(regex(":\\/\\/.*:", scaleway_sdb_sql_database.database.endpoint), "://"), ":")
    "DATABASE_NAME"     = scaleway_sdb_sql_database.database.name,
    "DATABASE_PORT"     = trimprefix(regex(":[0-9]{1,5}", scaleway_sdb_sql_database.database.endpoint), ":"),
    "DATABASE_SSL"      = "true",
    "ADMIN_EMAIL"       = "${var.ADMIN_EMAIL}"
  }
  secret_environment_variables = {
    "DATABASE_PASSWORD"   = scaleway_iam_api_key.api_key.secret_key,
    "ADMIN_PASSWORD"      = "${var.ADMIN_PASSWORD}",
    "APP_KEYS"            = random_bytes.generated_secrets["app_keys"].base64,
    "API_TOKEN_SALT"      = random_bytes.generated_secrets["api_token_salt"].base64,
    "ADMIN_JWT_SECRET"    = random_bytes.generated_secrets["admin_jwt_secret"].base64,
    "TRANSFER_TOKEN_SALT" = random_bytes.generated_secrets["transfer_token_salt"].base64,
    "JWT_SECRET"          = random_bytes.generated_secrets["jwt_secret"].base64
  }
}

resource "scaleway_iam_application" "app" {
  name            = local.appName
  organization_id = var.DEFAULT_ORGANIZATION_ID
}

resource "scaleway_iam_policy" "db_access" {
  name            = "${local.appName}-policy"
  organization_id = var.DEFAULT_ORGANIZATION_ID
  description     = "Gives tutorial Strapi blog access to Serverless SQL Database"
  application_id  = scaleway_iam_application.app.id
  rule {
    project_ids          = ["${var.DEFAULT_PROJECT_ID}"]
    permission_set_names = ["ServerlessSQLDatabaseReadWrite"]
  }
}

resource "scaleway_iam_api_key" "api_key" {
  application_id = scaleway_iam_application.app.id
}

resource "scaleway_sdb_sql_database" "database" {
  name       = local.appName
  project_id = var.DEFAULT_PROJECT_ID
  min_cpu    = 0
  max_cpu    = 8
}

output "database_connection_string" {
  // Output as an example, you can give this string to your application
  value = format("postgres://%s:%s@%s",
    scaleway_iam_application.app.id,
    scaleway_iam_api_key.api_key.secret_key,
    trimprefix(scaleway_sdb_sql_database.database.endpoint, "postgres://"),
  )
  sensitive = true
}

output "container_url" {
  // Output as an example, you can give this string to your application
  value     = scaleway_container.main.domain_name
  sensitive = false
}
