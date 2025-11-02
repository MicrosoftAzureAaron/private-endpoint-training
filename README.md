# Private Endpoint Training Deployment

This template deploys a secure Azure environment for private endpoint training, including:

- **Virtual Network (VNET)**: Address space `10.0.0.0/16` with three subnets:
  - `AzureFirewallSubnet`: `10.0.1.0/24` (for Azure Firewall)
  - `VM1Subnet`: `10.0.2.0/24` (for VM1)
  - `VM2Subnet`: `10.0.3.0/24` (for VM2, with private endpoint policies enabled)
- **Storage Account**: With File service enabled, secured by a private endpoint.
- **Private Endpoint**: For File access to the Storage Account, deployed in `VM2Subnet`.
- **Private DNS Zone**: For the Storage Account's private endpoint, linked to the VNET.
- **Azure Firewall**: Deployed in `AzureFirewallSubnet`.
- **Two Virtual Machines**:
  - VM1 in `VM1Subnet`
  - VM2 in `VM2Subnet`
- **Route Tables**:
  - VM1Subnet: Default route (`0.0.0.0/0`) to Azure Firewall
  - VM2Subnet: Route for private endpoint traffic to Azure Firewall, with private endpoint policies enabled

## IP Ranges
- VNET: `10.0.0.0/16`
- AzureFirewallSubnet: `10.0.1.0/24`
- VM1Subnet: `10.0.2.0/24`
- VM2Subnet: `10.0.3.0/24`

## Route Table Details
- **VM1Subnet Route Table**
  - Route: `0.0.0.0/0` → Next hop: Azure Firewall
- **VM2Subnet Route Table**
  - Route: Private endpoint traffic → Next hop: Azure Firewall
  - Private endpoint policies: Enabled

## Deploy to Azure
To deploy this template in your Azure subscription:

1. Export the Bicep file to an ARM template (JSON):
   ```pwsh
   bicep build main.bicep
   ```
   This will generate `main.json`.

2. Click the button below to deploy the ARM template to your Azure subscription:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/{REPLACE_WITH_YOUR_JSON_FILE_URL})

> **Note:** Upload your `main.json` to a public location (e.g., GitHub, Azure Blob Storage) and replace `{REPLACE_WITH_YOUR_JSON_FILE_URL}` with the direct link to your file.

---

## Template Overview
This template is designed for secure, segmented access to Azure Storage via private endpoints, with all traffic routed through Azure Firewall for inspection and control. VM2's subnet enforces private endpoint policies, while VM1's subnet routes all outbound traffic through the firewall.

For questions or improvements, please open an issue or contact the author.
