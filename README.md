# Content Management System infrastructure

## About

Content Management System infrastructure describes resources involved in cms part of [société numérique website](https://societenumerique.gouv.fr/).

> This repository is NOT required for local development.

## Table of contents

- 🪧 [About](#about)
- 📦 [Prerequisites](#prerequisites)
- 🚀 [Installation](#installation)
- 🛠️ [Usage](#usage)
- 🤝 [Contribution](#contribution)
- 🏗️ [Built with](#built-with)
- 📝 [Licence](#licence)

## Prerequisites

- [Docker](https://www.docker.com/) or [Terraform CLI](https://www.terraform.io/cli)
- [Docker](https://www.docker.com/) or [Scaleway CLI](https://www.scaleway.com/en/docs/developer-tools/scaleway-cli/)

## Installation

The following command allows to use the Terraform command line via Docker:
```shell
docker run --rm -it --name terraform -v ~/:/root/ -v $(pwd):/workspace -w /workspace hashicorp/terraform:light
```

For simplified use, you can create an alias:
```shell
alias terraform='docker run --rm -it --name terraform -v ~/:/root/ -v $(pwd):/workspace -w /workspace hashicorp/terraform:light'
```

Using this alias, there is no longer any difference between a terraform command executed via Docker or via Terraform CLI.

We can use the same trick to use Scaleway command line via Docker:
```shell
docker run --rm -it --name scaleway -v ~/:/root/ scaleway/cli:latest
```

For simplified use, you can create an alias:
```shell
alias scw='docker run --rm -it --name scaleway -v ~/:/root/ scaleway/cli:latest'
```

## Usage

### Check and fix `.tf` files format

```shell
terraform fmt
```

### Verify ressources consistency

```shell
terraform validate
```

### Retrieve Terraform Cloud authentication token locally

```shell
terraform login
```

### Initialize state and plugins locally

```shell
terraform init
```

### Plan a run to check differences between the current and the next infrastructure state to be deployed

```shell
terraform plan
```

## Contribution

### Apply the next state of the infrastructure

Simply push the changes to the `main` branch, to apply the next state of the infrastructure in production.

## Built with

### Langages & Frameworks

- [Terraform](https://www.terraform.io/) is an infrastructure as code software tool that allow to define and provide infrastructure using a declarative configuration language

### Tools

#### CI

- [Github Actions](https://docs.github.com/en/actions) is the continuous integration and deployment tool provided by GitHub
  - Deployment history is available [under Actions tab](https://github.com/societenumerique-gouv-fr/infrastructure-content-management-system/actions)
- Repository secrets:
  - `TF_API_TOKEN`: Terraform Cloud API token which allows the CI to operate actions on Terraform Cloud, you can create a `Team API Token` in your Terraform Cloud Workspace `Settings` under `Teams` menu. 

#### Deployment

- [Terraform Cloud](https://app.terraform.io/) is a cloud platform provided by HashiCorp to host Terraform infrastructure state and apply changes
  - Organization: [societenumerique](https://app.terraform.io/app/societenumerique/workspaces)
  - Workspaces: `content-management-system-*`
    - [content-management-system-production](https://app.terraform.io/app/societenumerique/workspaces/content-management-system-production)
    - Variables:
      - `ADMIN_EMAIL` `terraform` Strapi administrator email: any email you want to log into Strapi admin panel
      - `ADMIN_PASSWORD` `terraform` `sensitive` Strapi administrator password: A secure password you will need to log into Strapi admin panel
      - `APPLICATION_ID` `terraform` Scaleway appication id: created by ANCT Scaleway administrator
      - `APPLICATION_ACCESS_KEY` `terraform` Scaleway application access key: created by ANCT Scaleway administrator
      - `APPLICATION_SECRET_KEY` `terraform` `sensitive` Scaleway application secret key: created by ANCT Scaleway administrator
      - `PROJECT_ID` `terraform` Scaleway project id: [available in Societe Numerique project dashboard settings](https://console.scaleway.com/project/settings)
      - `REGISTRY_ENDPOINT` `terraform` Scaleway registry endpoint: get the endpoint after [creating docker registry and push the initial image](#create-docker-registry-and-push-the-initial-image)
      - `SCW_ACCESS_KEY` `env` Scaleway access key: [generate API key for your user](https://console.scaleway.com/iam/users)
      - `SCW_SECRET_KEY` `env` `sensitive` Scaleway secret key: [generate API key for your user](https://console.scaleway.com/iam/users)
- [Scaleway](https://console.scaleway.com/) is a cloud provider platform provided by Scaleway
  - Organization : Agence nationale de la cohésion des territoires
  - Project: Societe Numerique

#### Create docker registry and push the initial image

> You need to complete this actions before the first run on the CI in order to get a ready to use docker registry endpoint with a first image ready to deploy.

Initialize scaleway CLI using Scaleway access and secret key you generated with the API key for your user:
```bash
scw init
```
Run the command below in a terminal to export your API access and secret keys as environment variables:
```bash
export SCW_ACCESS_KEY=$(scw config get access-key)
export SCW_SECRET_KEY=$(scw config get secret-key)
```
Go in initialized `content-management-system` project (you should be able to run it locally) and run:
```bash
docker build -t content-management-system .
```

Run the following command to create a Container Registry namespace and export its endpoint as a variable:
```bash
export REGISTRY_ENDPOINT=$(scw registry namespace create -o json | jq -r '.endpoint')
```

Run the following command to log in to your Container Registry:
```bash
docker login $REGISTRY_ENDPOINT -u nologin --password-stdin <<< "$SCW_SECRET_KEY"
```

Tag and push your container image to your Container Registry namespace:
```bash
docker tag content-management-system:latest $REGISTRY_ENDPOINT/content-management-system:latest
docker push $REGISTRY_ENDPOINT/content-management-system:latest
```

## Licence

See [LICENSE.md](./LICENSE.md) file in this repository.
