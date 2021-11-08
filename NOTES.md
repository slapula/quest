# mediocre.systems

### 1. Assumptions
* Administrator access to an AWS account
* `awscli` installed and properly configured
* Docker installed
* Terraform installed
* `kubectl` installed

### 2. Building the Container

At the root of this git repository, I added a simple `node.js` Dockerfile that containerizes the provided application.  I then used the following commands to build the container image and push it to an AWS ECR repository that I created manually.  My personal preference is to keep repositories like this one out of Terraform to prevent accidental deletion.
```console
$ aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin XXXXXXXX.dkr.ecr.us-east-1.amazonaws.com
$ docker build -t rearc/quest .
$ docker tag rearc/quest:latest XXXXXXXX.dkr.ecr.us-east-1.amazonaws.com/rearc/quest:latest
$ docker push XXXXXXXX.dkr.ecr.us-east-1.amazonaws.com/rearc/quest:latest
```

### 3. Spinning up the Infrastructure
```console
$ tree
.
└── ops
    └── terraform
        ├── aws
        │   ├── eks.tf
        │   ├── main.tf
        │   ├── networking.tf
        │   └── outputs.tf
        └── kubernetes
            ├── kubeconfig_rearc-quest
            └── main.tf
```

To build out the AWS infrastructure to host this container, I wrote some Terraform code to spin up an EKS backed Fargate environment.  This project is split up by provider: AWS (`ops/terraform/aws/`) and Kubernetes (`ops/terraform/kubernetes/`).  

##### AWS
The AWS code spins up all the required resources for an EKS cluster. It is another personal preference of mine to not reinvent the wheel so I chose to utilitze two well-vetted Terraform modules to do most of the heavy lifting:

* `terraform-aws-modules/vpc`: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
* `terraform-aws-modules/eks`: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest

To execute this code, the operator simply needs to `cd` into the `aws` directory and perform `terraform init/plan/apply`.  AWS will then start spinning up the infrastructure.

##### Kubernetes
When Terraform has finish provisioning the EKS infrastructure, the operator will then need to use `awscli` to grab the kubeconfig of the new cluster (which will give you and Terraform administration access):


`aws eks --region us-east-1 update-kubeconfig --name rearc-quest`

Once this has been done, `kubectl` should now return valid results from the cluster.  This can be tested by simply running something like `kubectl get nodes` or `kubectl get pods --all-namespaces`.

After confirming access to the EKS cluster, the operator can then to `cd` into the `kubernetes` directory and perform `terraform init/plan/apply`.  Terraform will apply two Kubernetes objects: 

1. `Deployment`: This object spins up 3 pods using the `rearc/quest` container image from earlier in this walkthrough.
2. `Service`:  This object exposes those 3 pods to the Internet via an AWS Load Balancer.

Terraform will output data related to accessing the website once it is finished (specifically the value of `load_balancer_hostname`).  This hostname can be accessed directly via HTTP or you can use AWS Route53 to assign a hostname that's easier to remember.  In this particular example, I'm hosting my Quest on `mediocre.systems`.

### 4. Post-Deploy Tweaks

* I manually went back into the AWS Console to submit/configure an SSL certificate via ACM.  To make the load balancer use it, I had to go back and add the appropriate annotations to the Kubernetes Service object (specifically adding ACm certificate ARN).
* No Kubernetes environment is complete without some sort of monitoring/logging solution.  I used Helm to add a Prometheus/Grafana/Loki stack.  The Quest application doesn't appear to be too chatty though.  Also, I'm not exposing this stack externally and opt'ing to port-forward access locally as needed.
* The Quest application's loadbalanced endpoint doesn't appear to like my `mediocre.systems` domain name.  Hitting the load balancer URL directly seems to resolve this issue.