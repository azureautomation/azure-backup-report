#############################################################################
#                                     			 		                    #
#   This Sample Code is provided for the purpose of illustration only       #
#   and is not intended to be used in a production environment.  THIS       #
#   SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT    #
#   WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT    #
#   LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS     #
#   FOR A PARTICULAR PURPOSE.  We grant You a nonexclusive, royalty-free    #
#   right to use and modify the Sample Code and to reproduce and distribute #
#   the object code form of the Sample Code, provided that You agree:       #
#   (i) to not use Our name, logo, or trademarks to market Your software    #
#   product in which the Sample Code is embedded; (ii) to include a valid   #
#   copyright notice on Your software product in which the Sample Code is   #
#   embedded; and (iii) to indemnify, hold harmless, and defend Us and      #
#   Our suppliers from and against any claims or lawsuits, including        #
#   attorneys' fees, that arise or result from the use or distribution      #
#   of the Sample Code.                                                     #
#   Version 1.0                              			 	                #
#   Last Update Date: 23-09-2019                            	            #
#                                     			 		                    #
#############################################################################

#Requires -version 4
Param([String]$FolderPath='.',[String[]]$ExcludeVault,[Parameter(ParameterSetName='EmailSet')][Switch]$EmailReport,[Parameter(ParameterSetName='EmailSet')][String]$SMTPServer,[Parameter(ParameterSetName='EmailSet')][String]$Recipients,[Parameter(ParameterSetName='EmailSet')][String]$MailFrom)

Import-Module AzureRM
#login to Azure
Login-AzureRmAccount

$AzureSubscriptions = Get-AzureRmSubscription

$Data = @()

foreach($Subscription in $AzureSubscriptions) #Loop through all Subscriptions
    {
    Select-AzureRmSubscription -SubscriptionObject $Subscription
    $RSVaults = Get-AzureRmRecoveryServicesVault | ?{$_.Name -notin @($ExcludeVault)}#Get Backup Vaults 
    
        foreach($Vault in $RSVaults)
        {
        Set-AzureRmRecoveryServicesVaultContext -Vault $Vault
            #Process each Vault
        $DebugPreference = 'Continue'
        Get-AzureRmRecoveryServicesBackupJob 5>"$($FolderPath)\Debug.log" | %{  $Data +=   [PSCustomObject]@{
                                                                                Subscription = $Subscription.Name
                                                                                Vault = $Vault.Name
                                                                                VMName = $_.WorkloadName
                                                                                StartTime = $_.StartTime
                                                                                EndTime = $_.EndTime
                                                                                Duration = $_.Duration
                                                                                Status =  $_.Status
                                                                                                            }
                                                                               }
        $DebugPreference = 'SilentlyContinue'
        
        #MARS Agent backup , currently only works with Debug info - Should be supported in the Future
        $D_i = 0 #Debug Object set
        $D_Obj = @{Subscription = $Subscription.Name
                   Vault = $Vault.Name
                   VMName = ''
                   StartTime = ''
                   EndTime = ''
                   Duration = ''
                   Status =  ''
                  }
        Foreach ($str in @(Get-Content .\Debug.log))
                {
                $a_Str = (($str.Replace('"','').replace(",","").trim()) -split ' ')[1]
                    If ($str -like '*"jobType": "MabJob",*')
                        {$D_i = 1}

                    If ($Str -like '*"duration":*' -and $D_i -eq 1)
                        {$D_Obj.'Duration' =  $a_Str}
    
                    If ($Str -like '*"mabServerName":*' -and $D_i -eq 1)
                        {$D_Obj.'VMName' =  $a_Str}

                    If ($Str -like '*"status":*' -and $D_i -eq 1)
                        {$D_Obj.'Status' =  $a_Str}

                    If ($Str -like '*"startTime":*' -and $D_i -eq 1)
                        {$D_Obj.'StartTime' =  [datetime]$a_Str}   

                    If ($Str -like '*"endTime":*' -and $D_i -eq 1)
                        {$D_Obj.'EndTime' =  [datetime]$a_Str
 
                        $Data  += [pscustomobject]$D_Obj

                        $D_i = 0
                        #Reset the Object
                        $D_Obj = @{Subscription = $Subscription.Name
                           Vault = $Vault.Name
                           VMName = ''
                           StartTime = ''
                           EndTime = ''
                           Duration = ''
                           Status =  ''
                           }
                        }  

                  }


        }
    }
  

#Region HTML Report
$css = @"
<Title>Azure Backup Report: $(Get-Date -Format 'dd MMMM yyyy' )</Title>
<Style>
th {
	font: bold 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	color: #FFFFFF;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	border-top: 1px solid #C1DAD7;
	letter-spacing: 2px;
	text-transform: uppercase;
	text-align: left;
	padding: 6px 6px 6px 12px;
	background: #5F9EA0;
}
td {
	font: 11px "Trebuchet MS", Verdana, Arial, Helvetica,
	sans-serif;
	border-right: 1px solid #C1DAD7;
	border-bottom: 1px solid #C1DAD7;
	background: #fff;
	padding: 6px 6px 6px 12px;
	color: #6D929B;
}
</Style>
"@
[string]$FileName = "AzureBackupReport-$(Get-date -f ddMMyyyy).html"
$Report = $Data | ConvertTo-Html -Head $css; $Report |Out-File "$FolderPath\$FileName"
If ($EmailReport)
{
Send-email -SMTPserver $SMTPServer -Recipients $Recipients -FromAddress $MailFrom  -HTMLbody $Report -Subject "Azure Backup Report - $(Get-date -f 'dd MMMM yyyy' )"
}



