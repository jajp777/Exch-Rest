function Get-EXRWellKnownFolderItems{
    [CmdletBinding()]
    param( 
        [Parameter(Position=0, Mandatory=$false)] [string]$MailboxName,
        [Parameter(Position=1, Mandatory=$false)] [psobject]$AccessToken,
        [Parameter(Position=2, Mandatory=$false)] [string]$WellKnownFolder,
        [Parameter(Position=4, Mandatory=$false)] [switch]$ReturnSize,
        [Parameter(Position=5, Mandatory=$false)] [string]$SelectProperties,
        [Parameter(Position=6, Mandatory=$false)] [string]$Filter,
        [Parameter(Position=7, Mandatory=$false)] [string]$Top,
        [Parameter(Position=8, Mandatory=$false)] [string]$OrderBy,
        [Parameter(Position=9, Mandatory=$false)] [switch]$TopOnly,
        [Parameter(Position=10, Mandatory=$false)] [PSCustomObject]$PropList,
        [Parameter(Position=11, Mandatory=$false)] [psobject]$ClientFilter,
        [Parameter(Position=12, Mandatory=$false)] [string]$ClientFilterTop,
        [Parameter(Position=13, Mandatory=$false)] [string]$Search,
        [Parameter(Position=14, Mandatory=$false)] [switch]$ReturnFolderPath,
        [Parameter(Position=14, Mandatory=$false)] [switch]$ReturnStats,
        [Parameter(Position=15, Mandatory=$false)] [switch]$ReturnAttachments
    )
    Begin{
		if($AccessToken -eq $null)
        {
            $AccessToken = Get-ProfiledToken -MailboxName $MailboxName  
            if($AccessToken -eq $null){
                $AccessToken = Get-EXRAccessToken -MailboxName $MailboxName       
            }                 
        }
        if([String]::IsNullOrEmpty($MailboxName)){
            $MailboxName = $AccessToken.mailbox
        } 
        if(![String]::IsNullorEmpty($Filter)){
            $Filter = "`&`$filter=" + [System.Web.HttpUtility]::UrlEncode($Filter)
        }
        if(![String]::IsNullorEmpty($Orderby)){
            $OrderBy = "`&`$OrderBy=" + $OrderBy
        }
        $TopValue = "1000"    
        if(![String]::IsNullorEmpty($Top)){
            $TopValue = $Top
        }      
        if(![String]::IsNullOrEmpty($ClientFilterTop)){
            $TopOnly = $false
        }
        if([String]::IsNullorEmpty($SelectProperties)){
            $SelectProperties = "`$select=ReceivedDateTime,Sender,Subject,IsRead,inferenceClassification,parentFolderId,hasAttachments"
        }
        else{
            $SelectProperties = "`$select=" + $SelectProperties
        }
        if(![String]::IsNullorEmpty($Search)){
            $Search = "`&`$Search=`"" + $Search + "`""
        }
        $ParentFolderCollection = New-Object 'system.collections.generic.dictionary[[string],[string]]'
        $stats = "" | Select TotalItems
        $stats.TotalItems = 0;
        if($WellKnownFolder -ne $null)
        {
            $HttpClient =  Get-HTTPClient -MailboxName $MailboxName
            $EndPoint =  Get-EndPoint -AccessToken $AccessToken -Segment "users"
            $RequestURL =  $EndPoint + "('" + $MailboxName + "')/MailFolders/" + $WellKnownFolder + "/messages/?" +  $SelectProperties + "`&`$Top=" + $TopValue 
            $folderURI =  $EndPoint + "('" + $MailboxName + "')/MailFolders/" + $WellKnownFolder
             if($ReturnSize.IsPresent){
                if($PropList -eq $null){
                    $PropList = @()
                    $PidTagMessageSize = Get-EXRTaggedProperty -DataType "Integer" -Id "0x0E08"  
                    $PropList += $PidTagMessageSize
                }
                else{
                    $PidTagMessageSize = Get-EXRTaggedProperty -DataType "Integer" -Id "0x0E08"  
                    $PropList += $PidTagMessageSize
                }
            }
            $RequestURL += $Filter + $Search + $OrderBy
            if($PropList -ne $null){
               $Props = Get-EXRExtendedPropList -PropertyList $PropList -AccessToken $AccessToken
               $RequestURL += "`&`$expand=SingleValueExtendedProperties(`$filter=" + $Props + ")"
            }
            $clientReturnCount = 0;
            do{
                $JSONOutput = Invoke-RestGet -RequestURL $RequestURL -HttpClient $HttpClient -AccessToken $AccessToken -MailboxName $MailboxName
                foreach ($Message in $JSONOutput.Value) {
                    $stats.TotalItems++
                    Add-Member -InputObject $Message -NotePropertyName ItemRESTURI -NotePropertyValue ($EndPoint + "('" + $MailboxName + "')/messages('" + $Message.Id + "')")
                    Expand-MessageProperties -Item $Message
                    Expand-ExtendedProperties -Item $Message
                    if($ReturnFolderPath.IsPresent){
                        if($ParentFolderCollection.ContainsKey($Message.parentFolderId)){
                            add-Member -InputObject $Message -NotePropertyName FolderPath -NotePropertyValue $ParentFolderCollection[$Message.parentFolderId]
                        }
                        else{
                            $Folder = Get-EXRFolderFromId -MailboxName $MailboxName -AccessToken $AccessToken -FolderId $Message.parentFolderId
                            if($Folder -ne $null){
                                 $ParentFolderCollection.Add($Message.parentFolderId,$Folder.PR_Folder_Path)
                                 
                            }else{
                                $ParentFolderCollection.Add($Message.parentFolderId,"Unavailable")
                            }
                            add-Member -InputObject $Message -NotePropertyName FolderPath -NotePropertyValue $ParentFolderCollection[$Message.parentFolderId]                      

                        }
                    }
                    if($ReturnAttachments.IsPresent -band $Message.hasAttachments){
                        $AttachmentNames = @()
                        $AttachmentDetails = @()
                        Get-EXRAttachments -MailboxName $MailboxName -AccessToken $AccessToken -ItemURI $Message.ItemRESTURI | ForEach-Object{
                            $AttachmentNames += $_.name
                            $AttachmentDetails += $_    
                        }
                        add-Member -InputObject $Message -NotePropertyName AttachmentNames -NotePropertyValue $AttachmentNames
                        add-Member -InputObject $Message -NotePropertyName AttachmentDetails -NotePropertyValue $AttachmentDetails
                    }
                    if(![String]::IsNullOrEmpty($ClientFilter)){
                        switch($ClientFilter.Operator){
                            "eq" {
                                if($Message.($ClientFilter.Property) -eq $ClientFilter.Value){
                                     Write-Output $Message
                                     $clientReturnCount++
                                }   
                            }
                            "ne" {
                                if($Message.($ClientFilter.Property) -ne $ClientFilter.Value){
                                     Write-Output $Message
                                     $clientReturnCount++
                                }
                            }
                        }
                        if(![String]::IsNullOrEmpty($ClientFilterTop)){
                            if($clientReturnCount -ge [Int]::Parse($ClientFilterTop)){
                                return 
                            }
                        }

                    }
                    else{
                        Write-Output $Message
                    }                    
                }           
                $RequestURL = $JSONOutput.'@odata.nextLink'
            }while(![String]::IsNullOrEmpty($RequestURL) -band (!$TopOnly))  
            if($ReturnStats.IsPresent){
                Write-Host $stats -ForegroundColor Green
            }   
       } 
   

    }
}
