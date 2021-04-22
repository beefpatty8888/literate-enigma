# literate-enigma
Ghost Blog on the Google Kubernetes Engine

# Development Deployment

## Enable APIs
```
#The Compute Engine API has be enabled for the VPC subnet creation.
gcloud services enable compute.googleapis.com

#This enables the GKE API
gcloud services enable container.googleapis.com

#This enables the Google Cloud SQL Admin API
gcloud services enable sqladmin.googleapis.com

#This enables the Google Cloud SQL API
gcloud services enable sql-component.googleapis.com

#This may not be needed since the ghost blog container is hosted in DockerHub
#gcloud services enable containerregistry.googleapis.com
```

## Apply Terraform Configuration File
This creates the VPC network, VPC subnets, the Cloud NAT and Router and the GKE cluster
```
cd vpc-gke

terraform init

terraform plan

terraform apply
```
See:
https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/getting_started
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat 
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
https://github.com/hashicorp/terraform-provider-google/issues/1382

## Configure kubectl
```
gcloud container clusters get-credentials <cluster_name> --zone us-central1-c
```

## Deploy the development Ghost Blog Application and Service
```
kubectl apply -f app-deployment-dev.yml

kubectl apply -f service-deployment-dev.yml
```

# Production Deployment
Additional steps for a production, highly available install of Ghost Blog. Apparently, the first Google result yields the discussion at https://forum.ghost.org/t/making-ghost-highly-available-and-scalable/1633/2 which I had participated in a few years ago, so I'm not sure if Ghost Blog has progressed so that it can be horizontally scaled.

## Enable the Service Network API
```
gcloud services enable servicenetworking.googleapis.com
```

## Enable the FireStore API
```
gcloud services enable file.googleapis.com
```

## Allocate a range for the Google Cloud MySQL database
See: 
https://cloud.google.com/vpc/docs/configure-private-services-access?_ga=2.157578361.-2113870819.1605925679
```
gcloud compute addresses create mysql --global --purpose=VPC_PEERING --addresses=192.168.16.0 --prefix-length=24 --description="Allocated range for MySQL database" --network=gke
```

## Create the VPC Peering Connection
See: 
https://cloud.google.com/vpc/docs/configure-private-services-access?_ga=2.157578361.-2113870819.1605925679
```
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=mysql \
    --network=gke \
    --project=[PROJECT_ID]
```

## Create the MySQL Google Cloud SQL database
See https://cloud.google.com/sql/docs/mysql/create-instance#gcloud
```
 gcloud beta sql instances create <database_name> --database-version=MYSQL_8_0 --cpu=1 --memory=3840MB --network=gke --availability-type=regional --zone=us-central1-c --secondary-zone=us-central1-a --enable-bin-log --no-assign-ip
```

## Configure the MySQL Google Cloud SQL database
See:
https://cloud.google.com/sql/docs/mysql/create-instance#gcloud
```
gcloud sql users set-password root --host=% --instance <database_name> --password <password>
```
## Deploy Ceph and Rook ?
See:
https://timberry.dev/posts/gke-storage-service-with-rook-ceph/

## Create FileStore NFS share
See: 
https://cloud.google.com/sdk/gcloud/reference/filestore/instances/create
https://cloud.google.com/filestore/docs/accessing-fileshares

NOTE: 1024 GB is the mimimum capacity for a FileStore instance. Monthly cost is more than $200 a month,
so this is an expensive option.
```
gcloud filestore instances create ghost-blog --description="ghost-blog filestore" --tier=STANDARD --file-share=name=ghostblog,capacity=1024GB --network=name=gke --zone=us-central1-c
```

## Deploy the production Ghost Blog Application, Service and Ingress
May require a separate ingress type deployment for session affinity based on the "ghost-admin-api-session" cookie.
See: 
https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features#session_affinity
https://forum.ghost.org/t/check-user-is-logged-in-or-not/2719/4