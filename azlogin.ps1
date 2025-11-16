# Connect to Microsoft Graph with required scopes

Connect-MgGraph -TenantId "XXX" -Scopes "Application.ReadWrite.All", "Application.Read.All", "Directory.ReadWrite.All"

# Connect to Azure for Key Vault operations
Connect-AzAccount -Tenant "XXX" -Subscription "XXX"
