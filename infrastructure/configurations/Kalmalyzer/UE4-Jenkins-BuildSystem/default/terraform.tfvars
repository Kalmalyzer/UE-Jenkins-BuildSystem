terraform_state_bucket = "kalms-ue4-jenkins-buildsystem-state"

project_id = "kalms-ue4-jenkins-buildsystem"
zone       = "europe-west1-b"

image          = "ubuntu-os-cloud/ubuntu-minimal-2004-lts"
boot_disk_type = "pd-balanced"
boot_disk_size = "10"
machine_type   = "n1-standard-1"
instance_name  = "jenkins-master"
ssh_username = "ansible"
ssh_pub_key_path = "jenkins-master-ansible.pub"