terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "societenumerique"

    workspaces {
      prefix = "content-management-system-"
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

variable "ADMIN_EMAIL" {
  type        = string
  description = "Strapi administrator email. Will be created at each container start."
}

variable "ADMIN_PASSWORD" {
  type        = string
  description = "Strapi administrator password. Will be updated at each container start."
}

variable "APPLICATION_ID" {
  type        = string
  description = "Application ID where policy need to be created"
}

variable "APPLICATION_ACCESS_KEY" {
  type        = string
  description = "Application API access key to give accès to the database and the bucket from the container"
}

variable "APPLICATION_SECRET_KEY" {
  type        = string
  description = "Application API secret key to give accès to the database and the bucket from the container"
}

variable "PROJECT_ID" {
  type        = string
  description = "Project ID where your resources will be created"
}

variable "REGISTRY_ENDPOINT" {
  type        = string
  description = "Container Registry endpoint where your application container is stored"
}

locals {
  appName = "content-management-system"
  secrets = ["app_keys", "api_token_salt", "admin_jwt_secret", "transfer_token_salt", "jwt_secret"]
}

resource "random_bytes" "generated_secrets" {
  for_each = toset(local.secrets)
  length   = 16
}

resource "scaleway_object_bucket" "media_library_bucket" {
  name = "${local.appName}-media"
}

resource "scaleway_object_bucket_acl" "media_library_bucket_acl" {
  bucket = scaleway_object_bucket.media_library_bucket.id
  acl    = "public-read"
}

resource "scaleway_container_namespace" "main" {
  name        = local.appName
  description = "Namespace created for full serverless Website Content management System deployment"
  project_id  = var.PROJECT_ID
}

resource "scaleway_container" "main" {
  name            = local.appName
  description     = "Container for Website Content management System"
  namespace_id    = scaleway_container_namespace.main.id
  registry_image  = "${var.REGISTRY_ENDPOINT}/content-management-system:latest"
  port            = 1337
  cpu_limit       = 1120
  memory_limit    = 4096
  min_scale       = 1
  max_scale       = 5
  timeout         = 600
  max_concurrency = 80
  privacy         = "public"
  protocol        = "http1"
  deploy          = true

  environment_variables = {
    "DATABASE_CLIENT"   = "postgres",
    "DATABASE_USERNAME" = var.APPLICATION_ID,
    "DATABASE_HOST"     = trimsuffix(trimprefix(regex(":\\/\\/.*:", scaleway_sdb_sql_database.database.endpoint), "://"), ":")
    "DATABASE_NAME"     = scaleway_sdb_sql_database.database.name,
    "DATABASE_PORT"     = trimprefix(regex(":[0-9]{1,5}", scaleway_sdb_sql_database.database.endpoint), ":"),
    "DATABASE_SSL"      = "true",
    "ADMIN_EMAIL"       = var.ADMIN_EMAIL
    "BUCKET_NAME"       = scaleway_object_bucket.media_library_bucket.name
    "BUCKET_REGION"     = scaleway_object_bucket.media_library_bucket.region
  }
  secret_environment_variables = {
    "BUCKET_ACCESS_KEY"   = var.APPLICATION_ACCESS_KEY
    "BUCKET_SECRET_KEY"   = var.APPLICATION_SECRET_KEY
    "DATABASE_PASSWORD"   = var.APPLICATION_SECRET_KEY,
    "ADMIN_PASSWORD"      = var.ADMIN_PASSWORD,
    "APP_KEYS"            = random_bytes.generated_secrets["app_keys"].base64,
    "API_TOKEN_SALT"      = random_bytes.generated_secrets["api_token_salt"].base64,
    "ADMIN_JWT_SECRET"    = random_bytes.generated_secrets["admin_jwt_secret"].base64,
    "TRANSFER_TOKEN_SALT" = random_bytes.generated_secrets["transfer_token_salt"].base64,
    "JWT_SECRET"          = random_bytes.generated_secrets["jwt_secret"].base64
  }
}

resource "scaleway_sdb_sql_database" "database" {
  name       = local.appName
  project_id = var.PROJECT_ID
  min_cpu    = 0
  max_cpu    = 8
}

output "database_connection_string" {
  value = format("postgres://%s:%s@%s",
    var.APPLICATION_ID,
    var.APPLICATION_SECRET_KEY,
    trimprefix(scaleway_sdb_sql_database.database.endpoint, "postgres://"),
  )
  sensitive = true
}

output "container_url" {
  value     = scaleway_container.main.domain_name
  sensitive = false
}

output "container_id" {
  value     = scaleway_container.main.id
  sensitive = false
}

