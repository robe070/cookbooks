# LANSA Docker Image Creation and Usage Instructions

## 1. Overview
The code is in the GitHub Repository: git@github.com:robe070/cookbooks.git (sub-directory: Docker). Branch: debug/paas.

I have published a Visual LANSA runtime base image to Docker Hub. The AWAMAPP example image is not published. The base image includes only the prerequisites to install and run LANSA.
**lansalpc/vlbase-servercore**
**Tags**
16.0.0-ltsc2025 (Immutable)
v16ga-ltsc2025 (Floating)
15.0.0-ltsc2025 (Immutable)
v15ga-ltsc2025 (Floating)

This image is essentially the same as the images we publish in AWS and Azure Marketplace. To run a Visual LANSA app you need to deploy a VL MSI into the image.

All the code to assemble the base image and to deploy a VL MSI into the image and construct an image of that is published here: https://github.com/robe070/cookbooks/tree/debug/paas/Docker

The AWAMAPP example demonstrates installing a LANSA MSI into the base container.

Database state is integral to the MSI installation. The resulting image and database must match.

IMAGE-NAMING.md describes the image naming structure.
LANSA Docker Image creation and Usage Instructions.md is the user guide. (This file)

You will need to install Hot Fix EPC160000HF_260417 for V16 and Hot Fix ****** for V15 and construct an MSI to deploy into the Docker image. These Hot Fixes enable Cloud Account Id licensing in a Docker image for both AWS and Azure. I have tested both. Scripts in the above github repo require a Cloud type to be supplied when constructing the application image.

Infrastructure creation like load balancers has not been provided.

N.B. Docker Host must match the image pretty closely. You will need the latest version of Windows Server 2025. This is a Windows on Docker restriction. Nothing to do with LANSA.

It also means that constructing a Visual LANSA base image for another version of Windows requires setting up a new VM running that version.

## 2. Licensing
Obtain a Cloud Account Id license for either AWS or Azure, add it to the x_lic*.lic file using the "Licensing - Server Licenses" application int the development environment Settings & Administration folder and place the x_lic*.lic file in the application root directory (e.g. AWAMAPP). Multiple license files may be added so that the Docker image you create may be used in both your AWS and Azure accounts, and also support multiple accounts and multiple regions if thats necessary.

The license files are copied into the LANSA licensing directory during installation.

Instructions for obtaining the Cloud Account Id license:
https://docs.lansa.com/16/en/lansa041/content/lansa/l4winsba_0055.htm

## 3. Images and Tags
Base image repository: lansalpc/vlbase-servercore

AWAMAPP image repository: lansalpc/vldemoapp-servercore

Floating label tags (example: v16ga-ltsc2025) are for ease of customer testing.

Use immutable tags for production (example: 16.0.26030-ltsc2025).

## 4. Construction Flow
### 4.1 run.ps1
Creates the install container (LANSA-APP) and runs init.ps1 to install the MSI into the base image.

Key inputs: -DockerLabel, -VersionNum, -VersionLabel, -SQLHost (optional), -SQLPort (optional), -Trace (optional), -Cloud (required).

Before `init.ps1` is invoked, `run.ps1` copies the top-level `*.*` files from `iis\AWAMAPP` into the container root directory `C:\`. Files matched by `iis\AWAMAPP\.dockerignore` are skipped. This provides Dockerfile-like override behavior without rebuilding the base image.

`run.ps1` passes selected host environment variables through to the container based on `-Cloud`.

When `-Cloud Azure`, these host environment variables must exist:
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_LOCATION`

When `-Cloud AWS`, these host environment variables must exist:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION`

When `-Cloud AWS`, `AWS_SESSION_TOKEN` is also passed through if it exists on the host.

#### 4.1.1 Creating Cloud Security Entities and Obtaining Variable Values

The environment variables above authenticate `init.ps1` against your cloud provider. This is used for Cloud Account Id license validation during image construction. Create a dedicated, least-privilege security entity for this purpose — do not use personal or administrator accounts.

---

##### Azure — Service Principal

**Create the service principal**

1. Open the [Azure Portal](https://portal.azure.com) and navigate to **Microsoft Entra ID → App registrations → New registration**.
2. Give it a descriptive name (e.g. `lansa-docker-build`) and accept the default single-tenant option. Click **Register**.
3. Navigate to **Certificates & secrets → Client secrets → New client secret**. Set an appropriate expiry, click **Add**, and copy the **Value** immediately — it is only shown once.
4. Navigate to **Subscriptions**, select your target subscription, then go to **Access control (IAM) → Add → Add role assignment**.
5. Assign the built-in **Reader** role and select the service principal you just created as the member. This is the minimum role required for license validation (account/tenant identification).

> If your workflow also pushes or pulls images to/from Azure Container Registry, additionally assign the **AcrPush** role (which includes pull) on that specific registry resource rather than at subscription scope.

**Where each variable comes from**

| Variable | Where to find it |
|---|---|
| `AZURE_TENANT_ID` | **Microsoft Entra ID → Overview** — copy the **Tenant ID** (also called Directory ID) |
| `AZURE_CLIENT_ID` | **Entra ID → App registrations → your app → Overview** — copy the **Application (client) ID** |
| `AZURE_CLIENT_SECRET` | The secret **Value** copied at step 3 above. If lost, delete the old secret and create a new one. |
| `AZURE_LOCATION` | Not a credential. Set this to the Azure region string for your deployment, e.g. `australiaeast`, `eastus`, `westeurope`. Find region strings at **portal.azure.com → Subscriptions → your subscription → Resource providers → locations**. |

---

##### AWS — IAM User with Programmatic Access

**Create the IAM user and policy**

1. Open the [AWS IAM Console](https://console.aws.amazon.com/iam) and navigate to **Users → Create user**.
2. Give it a descriptive name (e.g. `lansa-docker-build`), and on the permissions step choose **Attach policies directly**.
3. Click **Create policy**, choose the **JSON** editor, and paste the following minimum policy. This allows license validation (account identification) only:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    }
  ]
}
```

> If your workflow also pushes or pulls images to/from Amazon ECR, add the `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:CompleteLayerUpload`, `ecr:InitiateLayerUpload`, `ecr:PutImage`, and `ecr:UploadLayerPart` actions to the policy (or attach the AWS managed **AmazonEC2ContainerRegistryPowerUser** policy) scoped to the specific registry ARN.

4. Name the policy (e.g. `lansa-docker-build-policy`), save it, then attach it to the user.
5. Complete the user creation. Then open the user, go to **Security credentials → Access keys → Create access key**, choose **Other** as the use case, and click **Create**.
6. Copy both the **Access key ID** and the **Secret access key** — the secret is only shown once.

**Where each variable comes from**

| Variable | Where to find it |
|---|---|
| `AWS_ACCESS_KEY_ID` | The **Access key ID** from step 6 above. Visible later under **IAM → Users → your user → Security credentials → Access keys**. |
| `AWS_SECRET_ACCESS_KEY` | The **Secret access key** from step 6 above. If lost, deactivate the old key and create a new one. |
| `AWS_DEFAULT_REGION` | Not a credential. Set this to the AWS region string for your deployment, e.g. `ap-southeast-2`, `us-east-1`, `eu-west-1`. |
| `AWS_SESSION_TOKEN` | Only required when using **temporary credentials** issued by AWS STS (e.g. via `AssumeRole`). Not needed for the permanent IAM user access key created above. If your organisation requires role assumption rather than IAM user keys, obtain temporary credentials with `aws sts assume-role` and use all three values (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) that it returns. |

---

`run.ps1` remains attached because `init.ps1` ends by tailing the IIS log in the PowerShell window. Once you have tested that the application is running and has been deployed successfully, type `Ctrl-C` to end that PowerShell window. This stops the container so the image can then be committed.

The provided scripts expose the container's port 80 as port 50080. Therefore an example url to execute a WAM is http://localhost:50080/cgi-bin/lansaweb?wam=DEPTABWA&webrtn=BuildFirst&ml=LANSA:XHTML&part=DEX&lang=ENG

### 4.2 commit.ps1
Stops `LANSA-APP` with an extended timeout and then commits it as a new image, replacing the entrypoint with `C:\bootstrap.ps1`.

Do not restart a stopped `LANSA-APP` container. Until commit time its configured startup still runs `init.ps1`, so starting it again reruns the install flow.

### 4.3 Patching
If an additional DLL must be added after the MSI install, there are two supported approaches. And you should consider re-building the MSI and then re-building the application Docker image.

Quick one-off test:
- Run `.\run.ps1` first so the install container `LANSA-APP` exists and the repository is mounted as `C:\docker`.
- To inspect the running container with a PowerShell command prompt:
```
docker exec -it LANSA-APP powershell -NoLogo
```
- To copy `X_PDFMS.DLL` into the running container before commit:
```
docker exec LANSA-APP powershell -NoLogo -NoProfile -Command "Copy-Item 'C:\docker\iis\AWAMAPP\Patch\X_PDFMS.DLL' 'C:\Program Files (x86)\Docker\X_Win95\X_Lansa\Execute\X_Pdfms.dll' -Force"
```
- After validation, run `.\commit.ps1` to capture the patched container as an image.

Repeatable patch image:
- Complete the normal `.\run.ps1` and `.\commit.ps1` flow first to create the parent image.
- Place `X_PDFMS.DLL` in `iis\AWAMAPP\Patch`.
- Build a child image from `iis\AWAMAPP\Patch\build.ps1`.
- This is the preferred option when the patch needs to be reproducible. The default patched image tag is `lansalpc/vldemoapp-servercore:16.0.26030.1-ltsc2025`.
- Its a very fast process so it may as well be used every time you need to patch.

### 4.4 run_img.ps1
Runs the committed image for test/validation.

Key inputs: -DockerLabel, -VersionNum, -SQLHost (optional), -SQLPort (optional), -SQLDsn (optional), -Trace (optional), -ByPassSQLServerDNSChecks (optional).

run_img.ps1 can be run without database parameters if the database server has not changed. In that case, pass -ByPassSQLServerDNSChecks so bootstrap.ps1 skips DNS and ODBC validation. But note that stopping a Cloud VM and restarting it may change the VM IP Address and if your database is on the container host the ODBC DSN needs to be modified. run_img.ps1 obtains the current IP address and passes it to bootstrap.ps1 to modify the ODBC DSN. It also is quite quick, so its recommended to always run without -ByPassSQLServerDNSChecks.

## 5. Installation Examples
### 5.1 SQL Server Instance on the Host
This uses the host NAT address by default and port 1433.

Command:
```
.\run.ps1 -DockerLabel ltsc2025 -VersionNum 16.0.0 -VersionLabel "V16 GA" -Cloud Azure
```

### 5.2 SQL Server on the Network (DNS Name)
Provide a stable DNS name and port.

Command:
```
.\run.ps1 -DockerLabel ltsc2025 -VersionNum 16.0.0 -VersionLabel "V16 GA" -SQLHost sql01.corp.local -SQLPort 1433 -Cloud Azure
```

### 5.3 Commit the Installed App Image
Use this after `.\run.ps1` has completed validation and `LANSA-APP` has been stopped. The numeric tag matches the image tag used by `.\run_img.ps1`.

Command:
```
.\commit.ps1 -DockerLabel ltsc2025 -VersionNum 16.0.26030
```

### 5.4 Run Final App Image with Database Overrides
These overrides are applied at runtime by C:\bootstrap.ps1.

Command:
```
.\run_img.ps1 -DockerLabel ltsc2025 -VersionNum 16.0.26030 -SQLHost sql01.corp.local -SQLPort 1433 -Trace
```

### 5.5 Run Final App Image without Database Parameters
Use this only when the database server has not changed since install.

Command:
```
.\run_img.ps1 -DockerLabel ltsc2025 -VersionNum 16.0.26030 -ByPassSQLServerDNSChecks
```

### 5.6 Inspect the Running Install Container
Use this after `.\run.ps1` while `LANSA-APP` is still running.

Command:
```
docker exec -it LANSA-APP powershell -NoLogo
```

### 5.7 Quick One-Off DLL Patch Before Commit
Use this after `.\run.ps1` and before `.\commit.ps1`.

Command:
```
docker exec LANSA-APP powershell -NoLogo -NoProfile -Command "Copy-Item 'C:\docker\iis\AWAMAPP\Patch\X_PDFMS.DLL' 'C:\Program Files (x86)\Docker\X_Win95\X_Lansa\Execute\X_Pdfms.dll' -Force"
```

### 5.8 Build Repeatable Patch Image
Use this after the parent image `lansalpc/vldemoapp-servercore:16.0.26030-ltsc2025` has been created and `X_PDFMS.DLL` has been placed in `iis\AWAMAPP\Patch`.

Command:
```
cd iis\AWAMAPP\Patch
.\build.ps1
```

### 5.9 Build V15 Application Image

V15 Cloud Account ID license file added to the AWAMAPP directory.
The MSI file in run.ps1 changed to the V15 MSI file.
Database name changed to AWAMAPP-V15 on the run.ps1 command line

Command
```
cd iis\AWAMAPP
.\run.ps1 -DockerLabel ltsc2025 -VersionNum 15.0.0 -Cloud Azure -DbName 'AWAMAPP-V15'
.\commit.ps1 -DockerLabel ltsc2025 -VersionNum 15.0.26010 -VersionLabel "V15 GA" -Cloud Azure
cd patch
.\build.ps1 -Cloud Azure -ParentVersionNum 15.0.26010
.\run_img.ps1 -Cloud Azure -VersionNum 15.0.26010.1 -trace
```

## 6. Running the Application Image from First Principles

`run_img.ps1` is a convenience wrapper suited to local development. It discovers the host NAT address, builds argument arrays, and mounts local directories. In a container orchestration environment none of that is applicable, and the wrapper cannot address secure credential injection. This section documents the underlying `docker run` command and how to supply credentials correctly per deployment target.

### 6.1 The docker run Command

The committed image (`lansalpc/vldemoapp-servercore`) has `powershell -File C:\bootstrap.ps1` baked in as its entrypoint by `commit.ps1`. No `--entrypoint` override is required.

The minimal production-style command is:

```powershell
docker run --name LANSA-IMG -d `
  -e SQL_HOST=<db-host-or-ip> `
  -e SQL_PORT=1433 `
  -p 80:80 `
  -p 4545:4545 `
  lansalpc/vldemoapp-servercore:16.0.26030-ltsc2025-Azure
```

Substitute the `-AWS` image tag when deploying to AWS.

For local testing where the web port must not conflict with the host, mirror the `run_img.ps1` port mapping:

```powershell
  -p 50080:80 -p 54545:4545
```

**`-d` vs `-it`**: Use `-d` (detached) for any persistent or orchestrated deployment. Use `-it` only when you need an interactive session for debugging, as `run_img.ps1` does.

### 6.2 Environment Variables Accepted by bootstrap.ps1

| Variable | Required | Description |
|---|---|---|
| `SQL_HOST` | Recommended | Hostname or IP of the SQL Server. If omitted, bootstrap.ps1 uses the value baked in at install time. Must be overridden whenever the database host differs from the build host. |
| `SQL_PORT` | Optional | SQL Server port. Defaults to `1433`. |
| `SQL_DSN` | Optional | Override the ODBC DSN name. Use when the DSN name must differ from the installed default. |
| `DEBUG` | Optional | Set to `Y` to enable verbose bootstrap logging. |
| `X_RUN` | Optional | LANSA trace flags, e.g. `ITRO:Y ITRL:4`. Equivalent to the `-Trace` switch in `run_img.ps1`. |

Cloud credential variables are **not** passed as environment variables in production deployments — see section 6.3.

### 6.3 Cloud Credential Injection — Secure Approaches by Deployment Target

The container requires cloud credentials so that `bootstrap.ps1` can validate the Cloud Account Id license at startup. Because this is a Windows container image, the cloud provider metadata services (`169.254.169.254`) are not accessible from inside the container. The required cloud identity variables must therefore be supplied as environment variables at runtime.

**Do not hardcode credentials** in `docker run` commands, task definitions, or deployment scripts. Use the platform's native secrets management so that plaintext values never appear in shell history, log files, or orchestrator state.

The required variables per cloud are:

| Cloud | Variables required |
|---|---|
| Azure | `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_LOCATION` |
| AWS | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `AWS_SESSION_TOKEN` (if using temporary credentials) |

---

#### 6.3.1 Azure

##### Azure Container Instances (ACI)

ACI supports two mechanisms for secure env var injection.

**Option A — `secureValue` in the container group definition (simplest)**

Variables declared with `secureValue` instead of `value` are encrypted at rest and are never returned by the Azure Portal, CLI, or ARM APIs after deployment — they are write-only.

```json
{
  "name": "AZURE_CLIENT_SECRET",
  "secureValue": "<secret>"
}
```

Full ARM/Bicep example:

```json
"environmentVariables": [
  { "name": "SQL_HOST",           "value":       "<db-host>" },
  { "name": "SQL_PORT",           "value":       "1433" },
  { "name": "AZURE_LOCATION",     "value":       "australiaeast" },
  { "name": "AZURE_TENANT_ID",    "secureValue": "<tenant-id>" },
  { "name": "AZURE_CLIENT_ID",    "secureValue": "<client-id>" },
  { "name": "AZURE_CLIENT_SECRET","secureValue": "<client-secret>" }
]
```

**Option B — Azure Key Vault + managed identity on the container group (most secure)**

1. Store each secret in Azure Key Vault.
2. Assign a managed identity to the container group and grant it the **Key Vault Secrets User** role on the vault.
3. In a startup wrapper (or your CI/CD pipeline), use the managed identity to retrieve the secrets from Key Vault and pass them as `secureValue` environment variables when creating or updating the container group. The managed identity is used by the *deployment process*, not inside the container itself — the container still receives standard environment variables.

##### Azure Kubernetes Service (AKS)

Store secrets in **Azure Key Vault** and sync them into Kubernetes Secrets using the [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) with the Azure Key Vault provider. Reference the Kubernetes Secret in the pod spec via `secretKeyRef` so that values are never written into the manifest in plaintext.

```yaml
env:
  - name: AZURE_TENANT_ID
    valueFrom:
      secretKeyRef:
        name: lansa-azure-creds
        key: AZURE_TENANT_ID
  - name: AZURE_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: lansa-azure-creds
        key: AZURE_CLIENT_ID
  - name: AZURE_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: lansa-azure-creds
        key: AZURE_CLIENT_SECRET
  - name: AZURE_LOCATION
    value: australiaeast
```

Kubernetes Secrets are base64-encoded, not encrypted, by default. Enable [envelope encryption with a KMS key](https://learn.microsoft.com/en-us/azure/aks/use-kms-etcd-encryption) on the AKS cluster for encryption at rest.

##### Azure VM (standalone Docker)

Assign a system-assigned managed identity to the VM and grant it the **Key Vault Secrets User** role on your vault. In the deployment script that runs `docker run` on the host (not inside the container), retrieve the secrets using the VM's identity and pass them to the container:

```powershell
# Runs on the VM host — the managed identity authenticates to Key Vault
$tenantId     = az keyvault secret show --vault-name <vault> --name lansa-tenant-id     --query value -o tsv
$clientId     = az keyvault secret show --vault-name <vault> --name lansa-client-id     --query value -o tsv
$clientSecret = az keyvault secret show --vault-name <vault> --name lansa-client-secret --query value -o tsv

docker run --name LANSA-IMG -d `
  -e SQL_HOST=<db-host> `
  -e AZURE_TENANT_ID=$tenantId `
  -e AZURE_CLIENT_ID=$clientId `
  -e AZURE_CLIENT_SECRET=$clientSecret `
  -e AZURE_LOCATION=australiaeast `
  -p 80:80 `
  lansalpc/vldemoapp-servercore:16.0.26030-ltsc2025-Azure

# Clear variables from host memory immediately
Remove-Variable tenantId, clientId, clientSecret
```

Credentials exist in host memory only for the duration of the `docker run` call and are not written to disk.

---

#### 6.3.2 AWS

##### Amazon ECS (Fargate or EC2 launch type)

ECS natively supports injecting secrets from **AWS Secrets Manager** or **SSM Parameter Store** as environment variables via the `secrets` field in the task definition. The ECS agent fetches the values at task launch and injects them — they are never stored in the task definition in plaintext and do not appear in `docker inspect` inside the container.

1. Store each credential in Secrets Manager (individual secrets, or a single JSON secret containing all values).
2. Grant the ECS **task execution role** (`ecsTaskExecutionRole`) the `secretsmanager:GetSecretValue` permission on those secrets.
3. Reference them in the task definition:

```json
{
  "family": "lansa-img",
  "containerDefinitions": [
    {
      "name": "lansa-img",
      "image": "lansalpc/vldemoapp-servercore:16.0.26030-ltsc2025-AWS",
      "portMappings": [{"containerPort": 80, "hostPort": 80}],
      "environment": [
        {"name": "SQL_HOST",           "value": "<db-host>"},
        {"name": "SQL_PORT",           "value": "1433"},
        {"name": "AWS_DEFAULT_REGION", "value": "ap-southeast-2"}
      ],
      "secrets": [
        {"name": "AWS_ACCESS_KEY_ID",     "valueFrom": "arn:aws:secretsmanager:<region>:<account>:secret:lansa/aws-access-key-id"},
        {"name": "AWS_SECRET_ACCESS_KEY", "valueFrom": "arn:aws:secretsmanager:<region>:<account>:secret:lansa/aws-secret-access-key"}
      ]
    }
  ]
}
```

`AWS_DEFAULT_REGION` is not sensitive and can be an ordinary `environment` entry. `AWS_SESSION_TOKEN` should be added to `secrets` if temporary credentials are in use.

> **Note on key rotation**: With Secrets Manager, rotating the secret automatically takes effect on the next task launch with no task definition update required.

##### Amazon EKS

Use the [AWS Secrets and Configuration Provider (ASCP)](https://docs.aws.amazon.com/secretsmanager/latest/userguide/integrating_csi_driver.html) (Secrets Store CSI Driver with the AWS provider) to sync Secrets Manager values into Kubernetes Secrets. Reference them via `secretKeyRef` in the pod spec (same pattern as the AKS example above, substituting the Kubernetes Secret name).

Alternatively, use the [External Secrets Operator](https://external-secrets.io/) to manage the sync from Secrets Manager to Kubernetes Secrets.

##### EC2 (standalone Docker)

Grant the EC2 instance an IAM role with `secretsmanager:GetSecretValue` on the relevant secrets. In the deployment script running on the host, retrieve values using the instance role (no explicit credentials needed for the CLI call) and pass them to the container:

```powershell
# Runs on the EC2 host — the instance role authenticates to Secrets Manager
$keyId     = aws secretsmanager get-secret-value --secret-id lansa/aws-access-key-id     --query SecretString --output text
$keySecret = aws secretsmanager get-secret-value --secret-id lansa/aws-secret-access-key  --query SecretString --output text

docker run --name LANSA-IMG -d `
  -e SQL_HOST=<db-host> `
  -e AWS_ACCESS_KEY_ID=$keyId `
  -e AWS_SECRET_ACCESS_KEY=$keySecret `
  -e AWS_DEFAULT_REGION=ap-southeast-2 `
  -p 80:80 `
  lansalpc/vldemoapp-servercore:16.0.26030-ltsc2025-AWS

# Clear variables from host memory immediately
Remove-Variable keyId, keySecret
```

---

### 6.4 Development and Testing (Local Machine)

On a developer workstation there is no cloud metadata service and no secrets manager agent. Retrieve short-lived credentials interactively and pass them directly. **Do not store long-lived credentials in scripts or shell profiles.**

**Azure:**

```powershell
# Authenticate interactively once per session
az login

# Retrieve from Key Vault using your personal account
$tenantId     = az keyvault secret show --vault-name <vault> --name lansa-tenant-id     --query value -o tsv
$clientId     = az keyvault secret show --vault-name <vault> --name lansa-client-id     --query value -o tsv
$clientSecret = az keyvault secret show --vault-name <vault> --name lansa-client-secret --query value -o tsv

docker run --name LANSA-IMG -d `
  -e SQL_HOST=<db-host> `
  -e AZURE_TENANT_ID=$tenantId `
  -e AZURE_CLIENT_ID=$clientId `
  -e AZURE_CLIENT_SECRET=$clientSecret `
  -e AZURE_LOCATION=australiaeast `
  -p 50080:80 `
  lansalpc/vldemoapp-servercore:16.0.26030-ltsc2025-Azure

Remove-Variable tenantId, clientId, clientSecret
```

**AWS:**

```powershell
# Obtain short-lived credentials via STS AssumeRole (1-hour expiry by default)
$creds = (aws sts assume-role `
  --role-arn arn:aws:iam::<account-id>:role/lansa-docker-run `
  --role-session-name lansa-dev | ConvertFrom-Json).Credentials

docker run --name LANSA-IMG -d `
  -e SQL_HOST=<db-host> `
  -e AWS_ACCESS_KEY_ID=$creds.AccessKeyId `
  -e AWS_SECRET_ACCESS_KEY=$creds.SecretAccessKey `
  -e AWS_SESSION_TOKEN=$creds.SessionToken `
  -e AWS_DEFAULT_REGION=ap-southeast-2 `
  -p 50080:80 `
  lansalpc/vldemoapp-servercore:16.0.26030-ltsc2025-AWS

Remove-Variable creds
```

In both cases credentials live only in host memory for the duration of the call, expire automatically, and are never written to disk.

---

## 7. Notes
- The AWAMAPP MSI install writes database state. Do not mix a previously installed database with a different MSI/image version.
- Use floating label tags for testing only. Use immutable tags for production.
- If a Powershell command window is opened inside the container, the Powershell prompt will display 'Cont C:\>' instead of the standard 'PS C:\>' to clearly show its in the container.

## Example Image Tags

The following example shows immutable and floating tags for the AWAMAPP and Base images.

![Example Docker image tags](images/docker-image-tags.png)

