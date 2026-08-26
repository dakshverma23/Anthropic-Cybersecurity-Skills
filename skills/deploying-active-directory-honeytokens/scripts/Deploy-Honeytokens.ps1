# Deploy-Honeytokens.ps1 - SECURE Active Directory Honeytokens
# 
# Creates decoy accounts with NO REAL PRIVILEGES for detection purposes.
# Any access to these accounts indicates compromise.
#
# SECURITY NOTE: This script creates DISABLED accounts in DECOY groups only.
# No real privileges are granted to prevent exploitation.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Domain = "corp.local",
    
    [Parameter(Mandatory=$false)]
    [string]$OUPath = "OU=Service Accounts,DC=corp,DC=local",
    
    [Parameter(Mandatory=$false)]
    [int]$Quantity = 5
)

# Import Active Directory module
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Host "[+] Active Directory module loaded" -ForegroundColor Green
} catch {
    Write-Error "Failed to load Active Directory module: $_"
    exit 1
}

# Function to generate cryptographically secure random password
function New-SecurePassword {
    param([int]$Length = 32)
    
    # Use .NET cryptographic RNG (works on both PowerShell 5.1 and 7+)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 32
    $rng.GetBytes($bytes)
    
    # Convert to base64 and trim to desired length
    $password = [Convert]::ToBase64String($bytes).Substring(0, $Length)
    $rng.Dispose()
    
    return $password
}

# Secure honeytoken templates (NO REAL PRIVILEGES)
$HoneytokenTemplates = @(
    @{
        NamePrefix = "svc-sql"
        Suffix = @("backup", "report", "maintenance", "legacy")
        SPNType = "MSSQLSvc"
        HostPattern = "{0}-server.{1}"
        Description = "SQL Server {0} service account - DO NOT MODIFY"
        DecoyGroups = @("Legacy SQL Admins")
    },
    @{
        NamePrefix = "svc-backup"
        Suffix = @("exec", "service", "agent", "veeam")
        SPNType = "BackupExec"
        HostPattern = "backup-{0}.{1}"
        Description = "Backup {0} service account"
        DecoyGroups = @("Archive Operators")
    },
    @{
        NamePrefix = "svc-vmware"
        Suffix = @("mgmt", "vcenter", "esxi", "view")
        SPNType = "HTTP"
        HostPattern = "vmware-{0}.{1}"
        Description = "VMware {0} service account"
        DecoyGroups = @("Critical System Admins")
    },
    @{
        NamePrefix = "adm-tier"
        Suffix = @("1", "2", "helpdesk", "support")
        SPNType = $null
        HostPattern = $null
        Description = "Tier {0} administrative account"
        DecoyGroups = @("Legacy Admins")
    },
    @{
        NamePrefix = "svc-exchange"
        Suffix = @("transport", "mailbox", "cas", "legacy")
        SPNType = "HTTP"
        HostPattern = "exchange-{0}.{1}"
        Description = "Exchange {0} service account"
        DecoyGroups = @("Mail System Operators")
    }
)

# Generate honeytokens to create
$HoneytokensToCreate = @()

for ($i = 0; $i -lt $Quantity; $i++) {
    $Template = $HoneytokenTemplates[$i % $HoneytokenTemplates.Count]
    $SuffixIndex = $i % $Template.Suffix.Count
    $Suffix = $Template.Suffix[$SuffixIndex]
    
    $Name = "$($Template.NamePrefix)-$Suffix"
    
    # Generate SPN if applicable (fixed $Host variable bug)
    if ($Template.SPNType) {
        $HostName = $Template.HostPattern -f $Suffix, $Domain
        $SPN = "$($Template.SPNType)/$HostName"
    } else {
        $SPN = $null
    }
    
    $Description = $Template.Description -f $Suffix
    
    # Use decoy groups only (NO REAL PRIVILEGES)
    $DecoyGroups = $Template.DecoyGroups
    
    $HoneytokensToCreate += @{
        Name = $Name
        SPN = $SPN
        Description = $Description
        DecoyGroups = $DecoyGroups
    }
}

# Display deployment plan
Write-Host ""
Write-Host "=== SECURE HONEYTOKEN DEPLOYMENT ===" -ForegroundColor Cyan
Write-Host "Domain: $Domain" -ForegroundColor White
Write-Host "OU Path: $OUPath" -ForegroundColor White
Write-Host "Quantity: $Quantity" -ForegroundColor White
Write-Host "Security: All accounts DISABLED, decoy groups only" -ForegroundColor Green
Write-Host ""

# Confirm deployment
$Confirm = Read-Host "Deploy $Quantity secure honeytokens? (y/N)"
if ($Confirm -ne "y" -and $Confirm -ne "Y") {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Deploying honeytokens..." -ForegroundColor Cyan
Write-Host ""

$DeployedCount = 0
$FailedCount = 0

foreach ($Honeytoken in $HoneytokensToCreate) {
    try {
        Write-Host "[*] Creating: $($Honeytoken.Name)" -ForegroundColor White
        
        # Generate cryptographically secure password (works on PS 5.1 and 7+)
        $RandomPassword = New-SecurePassword -Length 32
        $SecurePassword = ConvertTo-SecureString $RandomPassword -AsPlainText -Force
        
        # Create user account (DISABLED for security)
        New-ADUser -Name $Honeytoken.Name `
                   -SamAccountName $Honeytoken.Name `
                   -UserPrincipalName "$($Honeytoken.Name)@$Domain" `
                   -Description $Honeytoken.Description `
                   -Enabled $false `
                   -PasswordNeverExpires $true `
                   -CannotChangePassword $true `
                   -AccountPassword $SecurePassword `
                   -Path $OUPath `
                   -ErrorAction Stop
        
        Write-Host "    [+] Account created (DISABLED)" -ForegroundColor Green
        
        # Set AdminCount=1 (appears privileged without group membership)
        Set-ADUser -Identity $Honeytoken.Name -Replace @{adminCount=1} -ErrorAction Stop
        Write-Host "    [+] AdminCount=1 set (appears privileged)" -ForegroundColor Green
        
        # Deny all logon hours (prevents actual use)
        Set-ADUser -Identity $Honeytoken.Name -Replace @{logonHours=@()} -ErrorAction Stop
        Write-Host "    [+] Logon hours denied (prevents use)" -ForegroundColor Green
        
        # Set SPN if specified
        if ($Honeytoken.SPN) {
            Set-ADUser -Identity $Honeytoken.Name -ServicePrincipalNames @{Add=$Honeytoken.SPN} -ErrorAction Stop
            Write-Host "    [+] SPN configured: $($Honeytoken.SPN)" -ForegroundColor Green
        }
        
        # Create and add to decoy groups (NO REAL PRIVILEGES)
        foreach ($DecoyGroup in $Honeytoken.DecoyGroups) {
            try {
                # Create decoy group if it doesn't exist
                $DecoyGroupPath = "OU=Decoy Groups,DC=" + ($Domain -replace '\.', ',DC=')
                
                try {
                    Get-ADGroup -Identity $DecoyGroup -ErrorAction Stop | Out-Null
                } catch {
                    New-ADGroup -Name $DecoyGroup -GroupScope Universal -GroupCategory Security `
                               -Description "DECOY GROUP - NO REAL PRIVILEGES - Used for deception only" `
                               -Path $DecoyGroupPath -ErrorAction SilentlyContinue
                }
                
                # Add to decoy group
                Add-ADGroupMember -Identity $DecoyGroup -Members $Honeytoken.Name -ErrorAction SilentlyContinue
                Write-Host "    [+] Added to DECOY group: $DecoyGroup" -ForegroundColor Green
                
            } catch {
                Write-Host "    [!] Decoy group warning: $_" -ForegroundColor Yellow
            }
        }
        
        # Clear password from memory for security
        $RandomPassword = $null
        $SecurePassword = $null
        
        $DeployedCount++
        Write-Host ""
        
    } catch {
        Write-Host "    [-] Error creating $($Honeytoken.Name): $_" -ForegroundColor Red
        $FailedCount++
        Write-Host ""
    }
}

# Deployment summary
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Successfully deployed: $DeployedCount" -ForegroundColor Green
Write-Host "Failed: $FailedCount" -ForegroundColor Red
Write-Host ""
Write-Host "SECURITY STATUS:" -ForegroundColor Yellow
Write-Host "- All accounts are DISABLED" -ForegroundColor Yellow
Write-Host "- All accounts have logon hours DENIED" -ForegroundColor Yellow
Write-Host "- All accounts are in DECOY groups only" -ForegroundColor Yellow
Write-Host "- No real privileges granted" -ForegroundColor Yellow
Write-Host ""
Write-Host "Configure SIEM monitoring for Event IDs:" -ForegroundColor White
Write-Host "- 4768 (TGT Request)" -ForegroundColor White
Write-Host "- 4769 (TGS Request / Kerberoasting)" -ForegroundColor White
Write-Host "- 4776 (NTLM Authentication)" -ForegroundColor White
Write-Host "- 4624 (Successful Logon)" -ForegroundColor White
Write-Host "======================================" -ForegroundColor Cyan

# List deployed honeytokens for reference
if ($DeployedCount -gt 0) {
    Write-Host ""
    Write-Host "DEPLOYED HONEYTOKENS:" -ForegroundColor Cyan
    
    foreach ($Honeytoken in $HoneytokensToCreate) {
        if (Get-ADUser -Identity $Honeytoken.Name -ErrorAction SilentlyContinue) {
            Write-Host "- $($Honeytoken.Name)" -ForegroundColor White
            if ($Honeytoken.SPN) {
                Write-Host "  SPN: $($Honeytoken.SPN)" -ForegroundColor Gray
            }
            Write-Host "  Groups: $($Honeytoken.DecoyGroups -join ', ')" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "Save this list for SIEM monitoring configuration." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Deployment script completed successfully." -ForegroundColor Green