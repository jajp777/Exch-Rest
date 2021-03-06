function Find-EXRMessageFromMessageId
{
	[CmdletBinding()]
	param (
        [Parameter(Position=0, Mandatory=$false)] [string]$MailboxName,
        [Parameter(Position=1, Mandatory=$false)] [psobject]$AccessToken,
        [Parameter(Position=2, Mandatory=$false)] [string]$WellKnownFolder,
        [Parameter(Position=4, Mandatory=$false)] [switch]$ReturnSize,
		[Parameter(Position=5, Mandatory=$false)] [string]$SelectProperties,
		[Parameter(Position=5, Mandatory=$false)] [string]$MessageId,
        [Parameter(Position=10, Mandatory=$false)] [PSCustomObject]$PropList     
	)
	Process
	{
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
		$Filter = "internetMessageId eq '" + $MessageId + "'"
		Get-EXRWellKnownFolderItems -MailboxName $MailboxName -AccessToken $AccessToken -WellKnownFolder AllItems -ReturnSize:$ReturnSize.IsPresent -SelectProperties $SelectProperties -Filter $Filter -Top $Top -OrderBy $OrderBy -TopOnly:$TopOnly.IsPresent -PropList $PropList
		
		
	}
}
