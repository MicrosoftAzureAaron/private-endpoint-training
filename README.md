## Expected VM IPs
- VM1: `10.0.1.4` (first available in VM1Subnet)
- VM2: `10.0.2.4` (first available in VM2Subnet)
# Private Endpoint Training Deployment

This template deploys a secure Azure environment for private endpoint training, including:

- **Virtual Network (VNET)**: Address space `10.0.0.0/16` with four subnets:
  - `AzureFirewallSubnet`: `10.0.0.0/24` (for Azure Firewall)
  - `VM1Subnet`: `10.0.1.0/24` (for VM1)
  - `VM2Subnet`: `10.0.2.0/24` (for VM2, with private endpoint policies enabled)
  - `PESubnet`: `10.0.3.0/24` (for Private Endpoint)
- **Storage Account**: With File service enabled, secured by a private endpoint.
- **Private Endpoint**: For File access to the Storage Account, deployed in `PESubnet` (IP: `10.0.3.254`).
- **Private DNS Zone**: For the Storage Account's private endpoint, linked to the VNET.
- **Azure Firewall**: Deployed in `AzureFirewallSubnet`.
- **Two Virtual Machines**:
  - VM1 in `VM1Subnet`
  - VM2 in `VM2Subnet`
- **Route Tables**:
  - VM1Subnet: Default route (`0.0.0.0/0`) to Azure Firewall
  - VM2Subnet: Route for private endpoint traffic to Azure Firewall
    - The address prefix for the overriding route must be >= /32
      - Greater than or equal to the private endpoint IP address
    - The address prefix for the overriding route must be <= /16
      - Less than or equal to the VNET IP prefix
  - Private Endpoint subnet: Private endpoint policies for route tables enabled only on PE subnet

## IP Ranges
- VNET: `10.0.0.0/16`
- AzureFirewallSubnet: `10.0.0.0/24`
- VM1Subnet: `10.0.1.0/24`
- VM2Subnet: `10.0.2.0/24`
- PESubnet: `10.0.3.0/24`
## Private Endpoint IP
- Private Endpoint IP: `10.0.3.254` (last IP in PESubnet)


## Route Table Details
- **VM1Subnet Route Table**
  - Route: `0.0.0.0/0` → Next hop: Azure Firewall
  - **Note:** VM1's route table does not impact traffic destined for the private endpoint. Azure automatically handles private endpoint traffic, bypassing user-defined routes in the subnet. This means VM1 cannot route private endpoint traffic through the firewall unless private endpoint policies are enabled on the subnet.
- **VM2Subnet Route Table**
  - Route: Private endpoint traffic → Next hop: Azure Firewall
  - **Note:** With private endpoint policies enabled on the PE subnet, VM2's subnet can enforce custom routing for private endpoint traffic, allowing inspection and control through the Azure Firewall. This is a key difference from VM1's subnet, which does not have a route table that fits the private endpoint override and cannot control private endpoint traffic via its route table.

## Effective Routes


### VM1 Effective Routes
![VM1 Effective Routes](https://raw.githubusercontent.com/MicrosoftAzureAaron/private-endpoint-training/main/images/vm1effectiveroutes.png)

### VM2 Effective Routes
![VM2 Effective Routes](https://raw.githubusercontent.com/MicrosoftAzureAaron/private-endpoint-training/main/images/vm2effectiveroutes.png)

## Deploy to Azure
To deploy this template in your Azure subscription:

1. Export the Bicep file to an ARM template (JSON):
   ```pwsh
   bicep build main.bicep
   ```
   This will generate `main.json`.

2. Click the button below to deploy the ARM template to your Azure subscription:


[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FMicrosoftAzureAaron%2Fprivate-endpoint-training%2Fmain%2Fmain.json?nocache=0.2.9c)

> **Note:** The button above will deploy the latest `main.json` from this GitHub repository's main branch.

---

## Template Overview
This template is designed for secure, segmented access to Azure Storage via private endpoints, with all traffic routed through Azure Firewall for inspection and control. VM2's subnet enforces private endpoint policies, while VM1's subnet routes all outbound traffic through the firewall.

For questions or improvements, please open an issue or contact the author.
