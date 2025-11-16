# Function to validate input parameters
function Test-Parameters {
    param(
        [string]$FileInput,
        [string]$AppRegObjectId
    )
    
    if ([string]::IsNullOrEmpty($FileInput)) { 
        Write-Error "No file attached"
        exit 1
    }
    if ([string]::IsNullOrEmpty($AppRegObjectId)) { 
        Write-Error "AppRegObjectId is null"
        exit 1
    }
}

# Initialize logging
$LogFile = "AppRegistration_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogFile

# Import CSV file
try {
    $InputFile = Import-Csv -Path "/appregistration.csv" -Delimiter ";" -Encoding UTF8
    Write-Host "Successfully imported CSV file"
} catch {
    Write-Error "Failed to import CSV file: $_"
    exit 1
}

$StartDate = Get-Date

foreach ($AppInput in $InputFile) { 
    try {
        # Construct application name with consistent format
        $AppName = "app-apim-$($AppInput.proj)-$($AppInput.name)-$($AppInput.env)"
        $EndDate = $StartDate.AddYears([int]$AppInput.time)
        
        # Check if application exists using Graph
        $ExistingApps = Get-MgApplication -Filter "displayName eq '$AppName'" -ErrorAction SilentlyContinue
        
        if (-not $ExistingApps) {
            Write-Host "Creating new application: $AppName"
            
            # Create new application via Microsoft Graph
            $NewApp = New-MgApplication -DisplayName $AppName
            $AppId = $NewApp.AppId
            Update-MgApplication -ApplicationId $NewApp.Id -IdentifierUris "api://$AppId"

            # Definir los permisos expuestos
            $permissionScope = @{
            Id = (New-Guid) # Genera un nuevo GUID
            AdminConsentDisplayName = "Access app"
            AdminConsentDescription = "Allow the application to access itself"
            IsEnabled = $true
            Type = "User"  # O "Admin", dependiendo de si quieres que sea para los usuarios o administradores
            Value = "user_impersonation"
            }

            # Update application URI using Graph; ensure identifier URIs are in an array
            Update-MgApplication -ApplicationId $NewApp.Id -Api @{Oauth2PermissionScopes = @($permissionScope)}

            $NewApp.AppId
            $authorizedClientId = $NewApp.AppId  # Client ID of the authorized application
            $scopeId = $permissionScope.Id       # Use the GUID generated for the permission scope

            # Structure of the pre-authorized application
            $preAuthorizedApp = @{
                AppId = $authorizedClientId
                DelegatedPermissionIds = @($scopeId)  # Now correctly use the permission scope GUID
                }

            Update-MgApplication -ApplicationId $NewApp.Id -Api @{
                PreAuthorizedApplications = @($preAuthorizedApp)
                }

            $updatedApp = Get-MgApplication -ApplicationId $NewApp.Id
            $updatedApp.Api.PreAuthorizedApplications
            
            # Prepare password credential details with correct type for CustomKeyIdentifier
            $PasswordCredential = @{
                StartDateTime       = $StartDate.ToUniversalTime().ToString("o")
                EndDateTime         = $EndDate.ToUniversalTime().ToString("o")
                CustomKeyIdentifier = [System.Text.Encoding]::UTF8.GetBytes("apim")
            }

            # Create secret/password credential for the application using the corrected hashtable
            $NewSecret = Add-MgApplicationPassword -ApplicationId $NewApp.Id -PasswordCredential $PasswordCredential

            
            # Store the new secret securely in Azure Key Vault
            if ($NewSecret.SecretText) {
                $SecureSecret = ConvertTo-SecureString $NewSecret.SecretText -AsPlainText -Force
                Set-AzKeyVaultSecret -VaultName $AppInput.kv `
                                     -Name $AppName `
                                     -SecretValue $SecureSecret `
                                     -Expires $EndDate `
                                     -ContentType $AppId
            } else {
                Write-Warning "Failed to retrieve secret text for application $AppName."
            }
            
            # Delay to allow application registration propagation
            Write-Host "Waiting for application registration to propagate..."
            Start-Sleep -Seconds 5
            
            # Create Service Principal for the application using Graph
            New-MgServicePrincipal -AppId $AppId -AccountEnabled:$true
            Write-Host "Service Principal created successfully for $AppName"
        } else {
            Write-Host "Application $AppName already exists"
        }
    } catch {
        Write-Error "Error processing $AppName : $_"
        continue
    }
}

Stop-Transcript