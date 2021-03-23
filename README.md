# literate-enigma
Ghost Blog on the Google Kubernetes Engine

# Development Deployment

## Enable APIs
```
#The Compoute Engine API has be enabled for the VPC subnet creation.
gcloud services enable compute.googleapis.com

#This enables the GKE API
gcloud services enable container.googleapis.com

#This enables the Google Cloud SQL API
gcloud services enable sqladmin.googleapis.com

#This may not be needed since the ghost blog container is hosted in DockerHub
#gcloud services enable containerregistry.googleapis.com
```
## Create the VPC network
```
gcloud compute networks create gke --subnet-mode=custom
```

### Create the VPC subnet
See https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters#custom_subnet
```
gcloud compute networks subnets create gke-subnet-01 --network=gke --region us-central1 --range 192.168.0.0/20 --secondary-range gke-pods=10.4.0.0/14,gke-services=10.0.32.0/20 --enable-private-ip-google-access
```

### Create the Cloud NAT and Router
See:
https://cloud.google.com/sdk/gcloud/reference/compute/routers/create
https://cloud.google.com/nat/docs/using-nat
```
gcloud compute routers create gke-router --network=gke

gcloud compute routers nats create gke-nat --router=gke-router --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges --enable-logging
```

## Create the GKE cluster
See https://cloud.google.com/sdk/gcloud/reference/container/clusters/create#--scopes for specifying the scopes
```
gcloud container clusters create <cluster-name> --network=gke --subnetwork=gke-subnet-01  --cluster-secondary-range-name=gke-pods --services-secondary-range-name=gke-services --enable-private-nodes --enable-ip-alias --enable-master-global-access --no-enable-master-authorized-networks --master-ipv4-cidr 172.16.0.16/28 --num-nodes=2 --machine-type=e2-small --scopes=https://www.googleapis.com/auth/compute.readonly,sql-admin,gke-default --zone us-central1-c
```

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
## Create a Google Cloud Storage bucket or FileStore NFS share
Reference https://stackoverflow.com/questions/48222871/i-am-trying-to-use-gcs-bucket-as-the-volume-in-gke-pod for mounting a GCS bucket in GKE.

Alternatively, Google Filestore that uses NFS may also be a solution: https://cloud.google.com/filestore/docs/accessing-fileshares

## Deploy the production Ghost Blog Application, Service and Ingress
May require a separate ingress type deployment for session affinity based on the "ghost-admin-api-session" cookie.
See: 
https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-features#session_affinity
https://forum.ghost.org/t/check-user-is-logged-in-or-not/2719/4