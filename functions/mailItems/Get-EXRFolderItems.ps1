function Get-EXRFolderItems{
    [CmdletBinding()]
    param( 
        [Parameter(Position=0, Mandatory=$false)] [string]$MailboxName,
        [Parameter(Position=1, Mandatory=$false)] [psobject]$AccessToken,
        [Parameter(Position=2, Mandatory=$false)] [psobject]$Folder,
 	[Parameter(Position=3, Mandatory=$false)] [String]$FolderPath,
        [Parameter(Position=4, Mandatory=$false)] [switch]$ReturnSize,
        [Parameter(Position=5, Mandatory=$false)] [string]$SelectProperties,
        [Parameter(Position=6, Mandatory=$false)] [string]$Filter,
        [Parameter(Position=7, Mandatory=$false)] [string]$Top,
        [Parameter(Position=8, Mandatory=$false)] [string]$OrderBy,
        [Parameter(Position=9, Mandatory=$false)] [bool]$TopOnly,
        [Parameter(Position=10, Mandatory=$false)] [PSCustomObject]$PropList,
        [Parameter(Position=11, Mandatory=$false)] [string]$Search,
        [Parameter(Position=12, Mandatory=$false)] [switch]$TrackStatus,
        [Parameter(Position=13, Mandatory=$false)] [switch]$ReturnAttachments
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
            $Filter = "`&`$filter=" + $Filter
        }
        if(![String]::IsNullorEmpty($Search)){
            $Search = "`&`$Search=`"" + $Search + "`""
        }
        if(![String]::IsNullorEmpty($Orderby)){
            $OrderBy = "`&`$OrderBy=" + $OrderBy
        }
        $TopValue = "1000"    
        if(![String]::IsNullorEmpty($Top)){
            $TopValue = $Top
        }      
        if([String]::IsNullorEmpty($SelectProperties)){
            $SelectProperties = "`$select=ReceivedDateTime,Sender,Subject,IsRead,hasAttachments"
        }
        else{
            $SelectProperties = "`$select=" + $SelectProperties
        }
	if(![String]::IsNullorEmpty($FolderPath))
	{
		$Folder = Get-ExrFolderFromPath -MailboxName $MailboxName -AccessToken $AccessToken -FolderPath $FolderPath	
	}
        if($Folder -ne $null)
        {
            $HttpClient =  Get-HTTPClient -MailboxName $MailboxName
            $EndPoint =  Get-EndPoint -AccessToken $AccessToken -Segment "users"
            $RequestURL =  $EndPoint + "('" + $MailboxName + "')/MailFolders('" + $Folder.Id + "')/messages/?" +  $SelectProperties + "`&`$Top=" + $TopValue 
            $folderURI =  $EndPoint + "('" + $MailboxName + "')/MailFolders('" + $Folder.Id + "')"
            if($ReturnSize.IsPresent){
                if($PropList -eq $null){
                    $PropList = @()
                    $PidTagMessageSize = Get-EXRTaggedProperty -DataType "Integer" -Id "0x0E08"  
                    $PropList += $PidTagMessageSize
                }
            }
            if($PropList -ne $null){
               $Props = Get-EXRExtendedPropList -PropertyList $PropList -AccessToken $AccessToken
               $RequestURL += "`&`$expand=SingleValueExtendedProperties(`$filter=" + $Props + ")"
            }
            $RequestURL += $Search + $Filter + $OrderBy
            do{
                $JSONOutput = Invoke-RestGet -RequestURL $RequestURL -HttpClient $HttpClient -AccessToken $AccessToken -MailboxName $MailboxName -TrackStatus $TrackStatus.IsPresent
                foreach ($Message in $JSONOutput.Value) {
                    Add-Member -InputObject $Message -NotePropertyName ItemRESTURI -NotePropertyValue ($folderURI  + "/messages('" + $Message.Id + "')")
                    Expand-ExtendedProperties -Item $Message
                    Expand-MessageProperties -Item $Message
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
                    Write-Output $Message
                }           
                $RequestURL = $JSONOutput.'@odata.nextLink'
            }while(![String]::IsNullOrEmpty($RequestURL) -band (!$TopOnly))     
       } 
   

    }
}
