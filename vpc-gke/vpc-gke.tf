provider "google" {
  project = "gke-ghost-blog-309416"
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_compute_subnetwork" "gke-subnets" {
  name          = "gke-subnet-01"
  ip_cidr_range = "192.168.0.0/20"
  region        = "us-central1"
  network       = google_compute_network.vpc-gke.id
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.4.0.0/14"
  }
  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.0.32.0/20"
  }
}

resource "google_compute_network" "vpc-gke" {
  name = "gke"
  mtu  = 1500
  auto_create_subnetworks = false
}

resource "google_compute_router" "gke-router" {
  name    = "gke-router"
  region  = google_compute_subnetwork.gke-subnets.region
  network = google_compute_network.vpc-gke.id
}

resource "google_compute_router_nat" "gke-nat" {
  name                               = "gke-router"
  router                             = google_compute_router.gke-router.name
  region                             = google_compute_router.gke-router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_container_cluster" "k8s-cluster" {
  provider           = google-beta
  // the project has to specified one more time, probably because 
  // of the google-beta provider needed for the "networking_mode" parameter.
  project            = "gke-ghost-blog-309416"
  name               = "ghost-blog"
  location           = "us-central1-c"
  initial_node_count = 3
  node_config {
      machine_type = "e2-small"
      //aliases such as a "gke-default" do not seem work ...
      //list of scopes is at https://cloud.google.com/sdk/gcloud/reference/container/clusters/create#--scopes
      oauth_scopes = [
      "https://www.googleapis.com/auth/compute.readonly",
      "https://www.googleapis.com/auth/sqlservice.admin",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }

  // below is currently a google-beta only feature - 04-01-2021
  networking_mode = "VPC_NATIVE"
  network    = google_compute_network.vpc-gke.name
  subnetwork = google_compute_subnetwork.gke-subnets.name

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.gke-subnets.secondary_ip_range.0.range_name
    services_secondary_range_name = google_compute_subnetwork.gke-subnets.secondary_ip_range.1.range_name
  }

  private_cluster_config {
      enable_private_nodes = true
      enable_private_endpoint = false
      master_global_access_config {
        enabled = true
      }
      master_ipv4_cidr_block = "172.16.0.16/28"
  }

}

