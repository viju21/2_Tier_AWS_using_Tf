# EC2_RDS_S3_Tf

## Overview

This Terraform project sets up a secure 2-tier architecture in AWS, featuring:
- A **Bastion host** in the public subnet for accessing resources.
- An **EC2 instance** and **RDS PostgreSQL instance** in a private subnet.
- An **S3 bucket** to store database tables or any other data.

This architecture follows AWS best practices by keeping the EC2 instance and RDS in private subnets, using a **NAT Gateway** for internet access via the Bastion host, and leveraging **AWS Secrets Manager** and **KMS** for security and encryption.

## Prerequisites

Before starting, ensure you have the following:
- An AWS Account with appropriate IAM privileges.
- [AWS CLI](https://aws.amazon.com/cli/) and [Terraform](https://www.terraform.io/downloads) installed on your local machine.
- Basic understanding of AWS, networking, and Terraform.

## Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-repo/EC2_RDS_S3_Tf.git
   cd EC2_RDS_S3_Tf
   ```

2. **Update Configuration**:
   - Modify the `terraform.tfvars` file to match your AWS setup (e.g., region, instance type, etc.).
   - **Secrets Manager**: Ensure you’ve created secrets for your database credentials in AWS Secrets Manager (if not, Terraform will manage this as part of the setup).
   - **S3 Bucket Name**: Update the S3 bucket name in the Terraform files to a globally unique name.

## Architecture Overview

### 1. Bastion Host (Public Subnet)
- The **Bastion host** acts as a secure gateway to access your private EC2 instance and RDS instance.
- It is placed in a public subnet and attached to an **Internet Gateway (IGW)** for direct internet access.
  
### 2. EC2 and RDS (Private Subnet)
- The **EC2 instance** and **RDS (PostgreSQL)** are placed in private subnets, ensuring they are not directly accessible from the internet.
- A **NAT Gateway** is configured to allow the private EC2 to access the internet for updates and patches.
  
### 3. S3 Bucket
- An **S3 bucket** is created to store data exported from the RDS PostgreSQL database. You will upload the database tables to this bucket after creating and exporting them from the EC2 instance.
  
### 4. Security Best Practices
- The project uses **AWS Secrets Manager** to securely store and manage the database credentials, eliminating the need for hardcoding sensitive information.
- **AWS KMS (Key Management Service)** is employed to encrypt the Secrets Manager values and any sensitive data.

## Terraform Configuration

1. **Initialize Terraform**:
   Initialize the working directory and download necessary provider plugins:
   ```bash
   terraform init
   ```

2. **Validate the Configuration**:
   Ensure the configuration is correct by running:
   ```bash
   terraform validate
   ```

3. **Apply the Terraform Plan**:
   Deploy the infrastructure with:
   ```bash
   terraform apply
   ```
   After confirming the plan, Terraform will provision the Bastion host, EC2 instance, RDS, and S3 bucket. 

4. **Outputs**:
   Once the infrastructure is provisioned, Terraform will output:
   - **Bastion Host Public IP**: Use this IP to SSH into the Bastion host.
   - **RDS Endpoint**: This is the connection string to your PostgreSQL database hosted on RDS.

## Post-Deployment Tasks

### 1. Connect to the Bastion Host
- Use the following command to SSH into the Bastion host:
   ```bash
   ssh -i <path_to_key_pair.pem> ec2-user@<bastion_host_public_ip>
   ```
- From the Bastion host, SSH into the private EC2 instance:
   ```bash
   ssh -i <path_to_key_pair.pem> ec2-user@<private_ec2_ip>
   ```

### 2. Install PostgreSQL Client on EC2
Once you're inside the private EC2 instance, install the PostgreSQL client:
```bash
sudo yum install postgresql -y
```

### 3. Connect to the RDS Instance
Use the PostgreSQL client to connect to the RDS instance using the endpoint provided in the Terraform output:
```bash
psql -h <rds_endpoint> -U <db_username> -d <db_name>
```
- The database username and password are stored in **AWS Secrets Manager**. You can retrieve them from within the EC2 instance using the AWS CLI or API calls.

### 4. Create a Table and Export Data
After connecting to the RDS PostgreSQL database, create a sample table:
```sql
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    department VARCHAR(100)
);
INSERT INTO employees (name, department) VALUES ('John Doe', 'Engineering'), ('Jane Smith', 'Marketing');
```

Export the table data to a CSV file:
```bash
psql -h <rds_endpoint> -U <db_username> -d <db_name> -c "\copy employees TO '/home/ec2-user/employees.csv' CSV HEADER;"
```

### 5. Upload the Exported File to S3
Use the AWS CLI to upload the exported CSV file to the S3 bucket:
```bash
aws s3 cp /home/ec2-user/employees.csv s3://<your_bucket_name>/
```

## Security and Best Practices
- **Private Subnets**: The EC2 instance and RDS are in private subnets, ensuring that they are not directly exposed to the internet.
- **Secrets Manager**: The use of AWS Secrets Manager ensures that sensitive data like database credentials are stored securely and accessed programmatically.
- **KMS Encryption**: AWS KMS is used to encrypt secrets and sensitive data, providing an additional layer of security.

## Clean-Up
To destroy the infrastructure created by this Terraform setup, run:
```bash
terraform destroy
```
This will tear down all the resources, including the Bastion host, EC2 instance, RDS instance, and S3 bucket.

## Additional Enhancements
- **Auto-Scaling**: Implement auto-scaling for the EC2 instance for better performance under varying loads.
- **Monitoring**: Set up CloudWatch monitoring for the EC2 instance and RDS to track performance metrics.
- **Multi-AZ RDS**: Consider enabling Multi-AZ deployment for RDS for increased availability.

## Conclusion
This project demonstrates how to securely build a 2-tier architecture on AWS using Terraform. By leveraging AWS services like Secrets Manager, KMS, and private subnets, we ensure a highly secure environment for managing and interacting with the database.
