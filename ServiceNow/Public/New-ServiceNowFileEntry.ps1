function New-ServiceNowFileEntry
{
    <#
    .SYNOPSIS
        Uses the File method of the Attachment API to attach a file.
    .DESCRIPTION
        Uses the File method of the Attachment API to attach a file.
        $FileContents input is in [byte[]], which is useful to submit dynamic data without saving to a file first.
    .EXAMPLE
        $changeRecord = Get-ServiceNowChangeRequest -MatchExact @{number=$Number}
        $fileContents = Get-Content 'Excel.xlsx' -Raw -Encoding Byte
        New-ServiceNowFileEntry -Table "change_request" -TableId $changeRecord.sys_id -FileName "report.xlsx" -FileContents $fileContents

        Attaches the contents of Excel.xlsx to the specified record as report.xlsx

    .EXAMPLE
        $changeRecord = Get-ServiceNowChangeRequest -MatchExact @{number=$Number}
        $fileContents = Get-Service | ConvertTo-Csv -NoTypeInformation | Out-String
        $fileContents = [System.Text.Encoding]::Utf8.GetBytes($fileContents)
        New-ServiceNowFileEntry -Table "change_request" -TableId $changeRequest.sys_id -FileName "services.csv" -FileContents $fileContents -ContentType "text/csv"

        Attaches the output of Get-Service to the specified record as services.csv
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .NOTES

    #>

    param
    (
        # Name of the table we're inserting into (e.g. change_request)
        [parameter(mandatory=$true)]
        [parameter(ParameterSetName='SpecifyConnectionFields')]
        [parameter(ParameterSetName='UseConnectionObject')]
        [parameter(ParameterSetName='SetGlobalAuth')]
        [string]
        $Table,

        # table_sys_id we're inserting into
        [parameter(mandatory=$true)]
        [parameter(ParameterSetName='SpecifyConnectionFields')]
        [parameter(ParameterSetName='UseConnectionObject')]
        [parameter(ParameterSetName='SetGlobalAuth')]
        [string]
        $TableId,

        # Name of the file we're uploading
        [parameter(mandatory=$true)]
        [string]
        $FileName,

        # Contents of the file we're uploading (e.g. Get-Content 'File.zip' -Raw -Encoding Byte)
        [parameter(mandatory=$true)]
        [byte[]]
        $FileContents,

        # MIME type of the file being uploaded
        [parameter()]
        [string]
        $ContentType = 'application/octet-stream',

        # Credential used to authenticate to ServiceNow  
        [Parameter(ParameterSetName='SpecifyConnectionFields', Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]
        $ServiceNowCredential,

        # The URL for the ServiceNow instance being used  
        [Parameter(ParameterSetName='SpecifyConnectionFields', Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ServiceNowURL,

        #Azure Automation Connection object containing username, password, and URL for the ServiceNow instance
        [Parameter(ParameterSetName='UseConnectionObject', Mandatory=$True)] 
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $Connection
    )

    begin
    {
        #Get credential and ServiceNow REST URL
        if ($Connection -ne $null)
        {
            $SecurePassword = ConvertTo-SecureString $Connection.Password -AsPlainText -Force
            $ServiceNowCredential = New-Object System.Management.Automation.PSCredential ($Connection.Username, $SecurePassword)
            $ServiceNowURL = 'https://' + $Connection.ServiceNowUri + '/api/now/v1'
        }
        elseif ($ServiceNowCredential -ne $null -and $ServiceNowURL -ne $null)
        {
            $ServiceNowURL = 'https://' + $ServiceNowURL + '/api/now/v1'
        }
        elseif ((Test-ServiceNowAuthIsSet))
        {
            $ServiceNowCredential = $Global:ServiceNowCredentials
            $ServiceNowURL = $global:ServiceNowRESTURL
        }
        else
        {
            throw "Exception:  You must do one of the following to authenticate: `n 1. Call the Set-ServiceNowAuth cmdlet `n 2. Pass in an Azure Automation connection object `n 3. Pass in an endpoint and credential"
        }

        $uri = $ServiceNowURL + "/attachment/file?table_name=$Table&table_sys_id=$TableId&file_name=$FileName"
    }

    process
    {
        $response = (Invoke-RestMethod -uri $uri -Method Post -Body $FileContents -ContentType $ContentType -Credential $ServiceNowCredential -UseBasicParsing).result
        return $response
    }
}
