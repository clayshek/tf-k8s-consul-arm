# tf-k8s-consul-arm

## Summary

<a href="https://www.terraform.io/">Terraform</a> Provisioner for a 3 node <a href="https://www.consul.io/">Consul</a> Service Discovery cluster on top of <a href="https://kubernetes.io/">Kubernetes</a> running on ARM architecture / <a href="https://www.raspberrypi.org">Raspberry Pi</a>. Makes use of custom Kubernetes Terraform Provider from <a href="https://github.com/sl1pm4t/terraform-provider-kubernetes"> https://github.com/sl1pm4t/terraform-provider-kubernetes</a>. Will ultimately change this to use the standard <a href="https://www.terraform.io/docs/providers/kubernetes/">Terraform Kubernetes provider</a> when StatefulSets are supported. See related <a href="https://github.com/terraform-providers/terraform-provider-kubernetes/issues/3">GitHub Issue</a>.

Includes Terraform resource definitions for Kubernetes Service, Persistent Volume (for Consul data persistent storage), and Stateful Set. Functionality mostly similar to deploying using a <a href="https://helm.sh/">Helm</a> chart, but currently no version of Tiller available to run on ARM architecture. This method allows for single-command Terraform deployment, with a single variables config file. 

Container based off of Docker image located at <a href="https://hub.docker.com/r/clayshek/consul-arm/">https://hub.docker.com/r/clayshek/consul-arm/</a>. Runs on top of ARM32v7/Debian:stretch-slim, approx size 96 MB. Containers based off this image configurable via terraform.tfvars and should work for most use-cases, but for deeper configuration needs, custom Docker images can be built and used by modifying image_name parameter in terraform.tfvars.

Makes use of NFS shares as Kubernetes Persistent Volumes for Consul data storage. 

**Note that this deployment is not to be considered "production ready" as there are some small issues and several items that would not be considered best-practice, including in terms of security. However, this is a good starting point for a lab-based Consul setup.**

Some code based off of:
<a href="https://github.com/hashicorp/docker-consul/blob/master/0.X/Dockerfile">https://github.com/hashicorp/docker-consul/</a> & 
<a href="https://github.com/kelseyhightower/consul-on-kubernetes">https://github.com/kelseyhightower/consul-on-kubernetes</a>

**Native Kubernetes manifest files for creating Service, PersistentVolumes, and StatefulSet with volumeClaimTemplates are included in the _non-tf-k8s-manifests folder as an alternative to Terraform deployment. This is less flexible than Terraform deployment, but an alternative regardless.**

## Requirements

- Working Kubernetes cluster (developed on v1.9) on Raspberry Pi. <a href="https://gist.github.com/alexellis/fdbc90de7691a1b9edb545c17da2d975">Info</a>
- <a href="https://www.terraform.io/downloads.html">Terraform</a> (tested with v0.11.7)
- Terraform must have connectivity to Kubernetes. Either run on K8s master (easiest), or other workstation with properly configured Kube config file and <a href="https://www.terraform.io/docs/providers/kubernetes/guides/getting-started.html#provider-setup">Terraform provider setup</a>.
- Pre-configured NFS shares (default) or other Kubernetes supported <a href="https://kubernetes.io/docs/concepts/storage/persistent-volumes/">Persistent Volume</a> for Consul data storage. If using other than NFS, customization of main.tf likely required in addition to tfvars file. See <a href="https://www.terraform.io/docs/providers/kubernetes/r/persistent_volume.html">Terraform kubernetes_persistent_volume</a> resource documentation for further details. An alternative, if not using persistent storage, would be to comment out all Persistent Volume related code, but risk Consul data loss. See NFS Setup section below for more details.

## NFS Setup

Will not go in depth on NFS setup here, but as this repo is coded, it requires only two variables in terraform.tfvars:

* nfs_server - IP address or resolvable hostname
* vol_path - The path of the shares, as should be visible using <code>showmount -e IP_ADDRESS</code>

The single vol_path variable will support any number of Consul servers (consul_count variable), so long as the NFS shares for each exist, and so long as each share ends in a number beginning with zero and incrementing by one. 
Example /etc/exports file for my deployment of 3 Consul servers with associated NFS shares on an attached USB drive:

```
/mnt/usbdrive1/consul-data0 192.168.1.0/24(rw,sync)
/mnt/usbdrive1/consul-data1 192.168.1.0/24(rw,sync)
/mnt/usbdrive1/consul-data2 192.168.1.0/24(rw,sync)
```

NFS References: 
* <a href="https://blog.alexellis.io/hardened-raspberry-pi-nas/">Raspberry Pi NFS NAS</a>
* <a href="https://www.htpcguides.com/configure-nfs-server-and-nfs-client-raspberry-pi/">NFS Setup on Raspberry Pi</a>
* <a href="https://wiki.archlinux.org/index.php/NFS">NFS Reference</a>

## Usage

- Clone the repository
- Customize the parameters in the terraform.tfvars file as applicable for provisioning.
- Build the custom Terraform Kubernetes provider (see steps below), or alternatively use the pre-built binary (terraform-provider-kubernetes.exe for Windows or terraform-provider-kubernetes for ARM) included in this repo.
- Run <code>terraform init</code> (required for first run). 
- Apply the configuration:

```
terraform apply
```

- Remove the configuration from Kubernetes:

```
terraform destroy
```

## Custom Terraform Provider Build

As described in the Summary section above, the Terraform Kubernetes provider does not support <a href="https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/">StatefulSet</a> deployments. Until that feature is added (<a href="https://github.com/terraform-providers/terraform-provider-kubernetes/issues/3">GitHub Issue</a>, <a href="https://github.com/terraform-providers/terraform-provider-kubernetes/issues/100">another one</a>), a custom TF K8s Provider with that capability is used:  <a href="https://github.com/sl1pm4t/terraform-provider-kubernetes/tree/custom">https://github.com/sl1pm4t/terraform-provider-kubernetes/tree/custom</a>

In order to use that provider with the code in this repo, follow the steps below to clone & build:

- Install Go: https://golang.org/doc/install
- Clone Repo & Build Provider
```
$ mkdir -p $GOPATH/src/github.com/sl1pm4t
$ cd $GOPATH/src/github.com/sl1pm4t
$ git clone -b custom https://github.com/sl1pm4t/terraform-provider-kubernetes.git
$ cd terraform-provider-kubernetes
$ make build  (or go build on windows)
```

- Copy the compiled provider (either terraform-provider-kubernetes.exe on Windows, or terraform-provider-kubernetes on Linux) to same directory as the terraform code. 

Reference: <a href="https://www.hashicorp.com/blog/writing-custom-terraform-providers">Writing Custom Terraform Providers</a>
 

## To-Do

 - [ ] Metrics & Monitoring. 
 - [ ] Enable Encryption: <a href="https://www.consul.io/docs/agent/encryption.html">https://www.consul.io/docs/agent/encryption.html</a> 
 - [ ] Change to use Terraform standard provider when StatefulSet is supported. See <a href="https://github.com/terraform-providers/terraform-provider-kubernetes/issues/3">Git Issue</a>
 - [ ] Evaluate other Storage options. Possibly <a href="https://rook.io/">Rook</a>? <a href="https://ceph.com/">Ceph</a>?
 - [ ] Terraform destroy / Kubectl delete operation does not reliably remove Kubernetes Persistent Volume Claims, requires removal with <code>kubectl delete pvc PVC-NAME</code>. Likely something to do with the way volumeClaimTemplate provisions these. Occurs with Terraform or with native K8s manifests. Dig into this and address. 


## License

This is open-sourced software licensed under the [MIT license](http://opensource.org/licenses/MIT).
