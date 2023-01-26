New-Variable -Name ArcGisOutputFormats -Value @(
    'html', 
    'json', 
    'geojson', 
    'pbf'
    <#
    # Don't need pretty-printed since humans won't be reading it. 
    'pjson', 'pgeojson', 
    #> 
) -Option Constant, AllScope
<#
    cvd_level_of_impact

name          code
----          ----
Critical      critical
Informational informational

    cvd_impact_informational

name                   code
----                   ----
Adding fields          adding_fields
Adding Feature Classes adding_feature_classes
Other- Describe        other

    cvd_impact_critical

name                          code
----                          ----
Deleting Fields               deleting_fields
Changing Field Names          changing_field_names
URL Changes                   url_changes_
Deleting or retiring the data deleting_or_retiring_the_data
Other- Describe               other

    cvd_type_of_notification

name      code
----      ----
Open Data open_data
Agencies  agencies
Both      _both
#>

class NotificationAttributes
{
    # ObjectID
    [int]$ObjectId
    # GlobalID
    [guid]$globalid
    # CreationDate
    [datetime]$CreationDate
    # Creator
    [string]$Creator
    # EditDate
    [datetime]$EditDate
    # Editor
    [string]$Editor
    # Name of Content Impacted
    [string]$name_of_content_impacted
    # Brief Summary
    [string]$brief_summary
    # Reason for Change
    [string]$reason_for_change
    # Date of Change
    [datetime]$date_of_change
    # Level of Impact
    [string]$level_of_impact
    # Impact - Informational
    [string]$impact_informational
    # Other- Describe - Impact - Informational
    [string]$impact_informational_other
    # Impact - Critical
    [string]$impact_critical
    # Other- Describe - Impact - Critical
    [string]$impact_critical_other
    # Additional Information
    [string]$additional_information
    # Informational URL
    [string]$informational_url
    # Additional Informational URL
    [string]$additional_informational_url
    # Contact Email
    [string]$questions_contact
    # Type of Notification
    [string]$type_of_notification

    # NotificationAttributes([pscustomobject]$attributes) {
    #     Write-Debug "Entering $([NotificationAttributes]::new)"
    #     $attributes.Properties | Out-String | Write-Debug

        
        
    # }
}

<#
.SYNOPSIS
    Converts from a JavaScript Date value in milliseconds to a DateTimeOffset.
.DESCRIPTION
    The ArcGIS REST API returns dates as milliseconds since midnight 1970-01-01 (UTC).
    This function converts from that value to a .NET date value.

    In JavaScript, the milliseconds are converted via
    
    ```javascript
    const exampleMilliseconds 1556582400000;
    const exampleDate = new Date(exampleMilliseconds);
    // returns 2019-04-30T00:00:00.000Z
    ```
.OUTPUTS
    Returns the DateTimeOffset equivalent of $Milliseconds.
#>
function ConvertFrom-ArcGisJsonDate
{
    [CmdletBinding()]
    [OutputType([datetime])]
    param (
        # Number of milliseconds
        [Parameter(
            Mandatory,
            Position = 0
        )]
        [double]$Milliseconds
    )
    # return ([System.DateTimeOffset]::new(1970, 1, 1, 0, 0, 0, [timespan]::Zero)).AddMilliseconds($Milliseconds * 1000);
    $originDate = [datetime]::new(1970, 1, 1, 0, 0, 0)
    $output = $originDate.AddMilliseconds($Milliseconds)

    return $output
}

function Convert-Property
{
    [CmdletBinding()]
    param (
        # Name of a property
        [Parameter(
            Mandatory,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $PropertyName,
        
        # The value of the property associated with the name.
        [Parameter(
            Mandatory,
            Position = 1
        )]
        [AllowNull()]
        $PropertyValue
    )

    if (($null -eq $PropertyValue) -or ($PropertyValue -is [string] -and [string]::IsNullOrWhiteSpace($PropertyValue)))
    {
        $PropertyValue = $null
    }
    elseif ($PropertyName -ieq 'globalid')
    {
        $PropertyValue = [guid]$PropertyValue
    }
    elseif ($PropertyName -imatch 'Date')
    {
        $PropertyValue = ConvertFrom-ArcGisJsonDate($PropertyValue)  #::new($PropertyValue)
    }
    elseif ($PropertyName -imatch 'url')
    {
        # Append "https://" to URL strings that are lacking them.
        if ($PropertyValue -inotmatch '^https?://')
        {
            $PropertyValue = 'https://', $PropertyValue -join ''
        }
        $PropertyValue = [uri]$PropertyValue
    }
    elseif ($PropertyValue -is [System.Object]) {
        $PropertyValue = $PropertyValue | Convert-Properties
    }

    return $PropertyName, $PropertyValue
}

function Convert-Properties
{
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        $InputObject
    )

    # Create a temporary hashtable to store the converted properties.
    $temp = @{}
    foreach ($property in $attributes.PSObject.Properties | Select-Object Name, Value)
    {
        $pName = $property.Name
        $pValue = $property.Value
    
        $pName, $pValue = Convert-Property $pName $pValue
        $temp.Add($pName, $pValue)
    }
    
    return [pscustomobject]$temp
}

<#
.SYNOPSIS
    Converts ArcGIS Feature attributes into a NotificationAttributes object.
#>
function ConvertTo-NotificationAttributes
{
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [psobject]
        $attributes
    )
    
    # Create a temporary hashtable to store the converted properties.
    $temp = @{}
    foreach ($property in $attributes.PSObject.Properties | Select-Object Name, Value)
    {
        $pName = $property.Name
        $pValue = $property.Value

        $pName, $pValue = Convert-Property $pName $pValue
        $temp.Add($pName, $pValue)
    }

    return [NotificationAttributes]$temp
}

function Invoke-RequestForFeatureLayerInfo
{
    [CmdletBinding()]
    param (
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [uri]
        $Uri = 'https://services.arcgis.com/jsIt88o09Q0r1j8h/ArcGIS/rest/services/survey123_75f94f8a0675460796843c95665a814b/FeatureServer/0',

        # html | json | pjson
        [Parameter()]
        [ValidateSet('json', 'pjson', 'html')]
        [string]
        $OutputFormat = 'json'
    )

    $args | ConvertTo-Json | Write-Debug

    $requestParams = @{
        Uri  = $Uri
        Body = @{f = $OutputFormat }
    }
    
    if (($null -eq $OutputFormat) -or (('json', 'pjson') -notcontains $OutputFormat))
    {
        Invoke-WebRequest @requestParams | Select-Object -ExpandProperty Content
    }
    else
    {
        Invoke-RestMethod @requestParams
    }

}

<#
.SYNOPSIS
    Gets the WSDOT items from the Geospatial Open Data Notifications site.
.DESCRIPTION
    Gets the WSDOT items from the Geospatial Open Data Notifications site(https://wa-geoservices.maps.arcgis.com/apps/dashboards/cdf666ff7fa5499a88f3ebf4488cae5d) by querying the underlying feature
    service layer that provides its data.
.NOTES
    See https://wa-geoservices.maps.arcgis.com/apps/dashboards/cdf666ff7fa5499a88f3ebf4488cae5d
.EXAMPLE
    PS C:> Get-WsdotItems | Sort-Object date_of_change -Descending | Sort-Object type_of_notification | Format-List -GroupBy type_of_notification
    
       type_of_notification: _both
    
    impact_informational         : 
    informational_url            : 
    Editor                       : 
    name_of_content_impacted     : WSDOT Traffic Volume Trend
    CreationDate                 : 5/12/2022 9:30:27 PM
    level_of_impact              : critical
    brief_summary                : This content will be removed on May 26, 2022.
    globalid                     : 9e0c22ae-6290-4112-8a7a-b68932fbb3ad
    impact_critical_other        : 
    additional_informational_url : 
    Creator                      : 
    additional_information       : 
    impact_informational_other   : 
    impact_critical              : deleting_or_retiring_the_data
    type_of_notification         : _both
    ObjectId                     : 107
    reason_for_change            : Data to be retired
    questions_contact            : OnlineMapSupport@wsdot.wa.gov
    EditDate                     : 5/12/2022 9:30:27 PM
    date_of_change               : 5/26/2022 7:00:00 PM
    
    impact_informational         : 
    informational_url            : 
    Editor                       : OnlineMapSupport_WSDOT
    name_of_content_impacted     : WSDOT Bicycle and Pedestrian Count Portal application
    CreationDate                 : 8/7/2019 5:01:56 PM
    level_of_impact              : critical
    brief_summary                : This application is deprecated and will no longer be available after August 27, 2019. A new version of the application is now available at the associated URL.
    globalid                     : 1c0418a3-74ec-4016-86e1-6dc44c3762fc
    impact_critical_other        : 
    additional_informational_url : https://wsdot.wa.gov/data/tools/bikepedcounts/
    Creator                      : OnlineMapSupport_WSDOT
    additional_information       : 
    impact_informational_other   : 
    impact_critical              : url_changes_
    type_of_notification         : _both
    ObjectId                     : 26
    reason_for_change            : A new version of the application is now available at the associated URL.
    questions_contact            : onlinemapsupport@wsdot.wa.gov
    EditDate                     : 8/7/2019 5:23:29 PM
    date_of_change               : 8/27/2019 7:00:00 AM
    
       type_of_notification: open_data
    
    impact_informational         : 
    informational_url            : https://data.wsdot.wa.gov/arcgis/rest/services/Shared/LRSData/MapServer/9
    Editor                       : OnlineMapSupport_WSDOT
    name_of_content_impacted     : WSDOT - Washington All Public Roads (WAPR)
    CreationDate                 : 10/2/2020 12:13:25 AM
    level_of_impact              : critical
    brief_summary                : The WAPR dataset has become outdated, and is no used by WSDOT for reporting by the Highway Performance Management System. To avoid confusion/errors, we are retiring this dataset. 
    globalid                     : 8b6e23b4-e0ad-4942-8910-0c251f5e910d
    impact_critical_other        : 
    additional_informational_url : 
    Creator                      : OnlineMapSupport_WSDOT
    additional_information       : 
    impact_informational_other   : 
    impact_critical              : deleting_or_retiring_the_data
    type_of_notification         : open_data
    ObjectId                     : 77
    reason_for_change            : This dataset will no longer be available. The data is out of date and no longer maintained.
    questions_contact            : julie.jackson@wsdot.wa.gov
    EditDate                     : 10/2/2020 12:13:25 AM
    date_of_change               : 10/15/2020 7:00:00 PM
.EXAMPLE
    PS C:> Get-WsdotItems | Select-Object -ExpandProperty fields | Format-Table

    name                         type                  alias                                    sqlType      domain
    ----                         ----                  -----                                    -------      ------                                                          
    ObjectId                     esriFieldTypeOID      ObjectID                                 sqlTypeOther                                                                 
    globalid                     esriFieldTypeGlobalID GlobalID                                 sqlTypeOther                                                                 
    CreationDate                 esriFieldTypeDate     CreationDate                             sqlTypeOther                                                                 
    Creator                      esriFieldTypeString   Creator                                  sqlTypeOther                                                                 
    EditDate                     esriFieldTypeDate     EditDate                                 sqlTypeOther                                                                 
    Editor                       esriFieldTypeString   Editor                                   sqlTypeOther                                                                 
    name_of_content_impacted     esriFieldTypeString   Name of Content Impacted                 sqlTypeOther                                                                 
    brief_summary                esriFieldTypeString   Brief Summary                            sqlTypeOther                                                                 
    reason_for_change            esriFieldTypeString   Reason for Change                        sqlTypeOther                                                                 
    date_of_change               esriFieldTypeDate     Date of Change                           sqlTypeOther                                                                 
    level_of_impact              esriFieldTypeString   Level of Impact                          sqlTypeOther @{type=codedValue; name=cvd_level_of_impact; codedValues=System…
    impact_informational         esriFieldTypeString   Impact - Informational                   sqlTypeOther @{type=codedValue; name=cvd_impact_informational; codedValues=S…
    impact_informational_other   esriFieldTypeString   Other- Describe - Impact - Informational sqlTypeOther                                                                 
    impact_critical              esriFieldTypeString   Impact - Critical                        sqlTypeOther @{type=codedValue; name=cvd_impact_critical; codedValues=System…
    impact_critical_other        esriFieldTypeString   Other- Describe - Impact - Critical      sqlTypeOther                                                                 
    additional_information       esriFieldTypeString   Additional Information                   sqlTypeOther                                                                 
    informational_url            esriFieldTypeString   Informational URL                        sqlTypeOther                                                                 
    additional_informational_url esriFieldTypeString   Additional Informational URL             sqlTypeOther                                                                 
    questions_contact            esriFieldTypeString   Contact Email                            sqlTypeOther                                                                 
    type_of_notification         esriFieldTypeString   Type of Notification                     sqlTypeOther @{type=codedValue; name=cvd_type_of_notification; codedValues=S…
.EXAMPLE
    PS C:> Get-WsdotItems 
    | Select-Object -ExpandProperty fields 
    | Where-Object { $_.domain?.type -eq 'codedValue' } 
    | Select-Object -ExpandProperty domain 
    | Select-Object name,codedValues
    | ForEach-Object {
        Write-Output $_.name
        $_.codedValues | Format-Table
    }

    Display all of the coded value domains

    cvd_level_of_impact

    name          code
    ----          ----
    Critical      critical
    Informational informational

    cvd_impact_informational

    name                   code
    ----                   ----
    Adding fields          adding_fields
    Adding Feature Classes adding_feature_classes
    Other- Describe        other

    cvd_impact_critical

    name                          code
    ----                          ----
    Deleting Fields               deleting_fields
    Changing Field Names          changing_field_names
    URL Changes                   url_changes_
    Deleting or retiring the data deleting_or_retiring_the_data
    Other- Describe               other

    cvd_type_of_notification

    name      code
    ----      ----
    Open Data open_data
    Agencies  agencies
    Both      _both
#>
function Get-WsdotItems
{
    [CmdletBinding()]
    param (
        # ArcGIS Feature Server Layer URL.
        [Parameter(
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = 'ArcGIS Feature Server Layer URL.'
        )]
        [ValidateNotNullOrEmpty()]
        [uri]
        $FeatureServerLayerUrl = 'https://services.arcgis.com/jsIt88o09Q0r1j8h/ArcGIS/rest/services/survey123_75f94f8a0675460796843c95665a814b/FeatureServer/0/query',

        # By default, only the attributes of the query result's features will be returned.
        # This is done because the feature service layer's geometry is always a point of 0,0
        # and not meant to be used for anything.
        # Use this switch to override this behavior and return the whole feature set.
        [Parameter()]
        [switch]
        $ReturnFeatureSet,

        # Unless the schema of the service changes, you can just use the default value.
        [Parameter()]
        $Where = "questions_contact LIKE '%@wsdot.wa.gov'",
        
        [Parameter()]
        [ValidateSet('json', 'geojson', 'pbf', 'html')]
        [string]
        $Format = 'json',

        # Specify which fields you want to return.
        # If null or empty, all fields will be returned.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]
        $outFields

    )

    $QueryParams = @{
        where                = $Where
        # If no outfields were provided (either null or empty array), return all fields ('*').
        outFields            = $null -eq $outFields -or $outFields.Length -lt 1 ? '*' : $outFields -join ','
        returnGeometry       = $false
        useStandardizedQuery = $true
        f                    = $Format ?? 'json'
    }

    # Define a list of formats that should use
    New-Variable -Name jsonFormats -Value ('json', 'geojson') -Option Constant -Description 'These formats should use Invoke-RestMethod rather than Invoke-WebMethod'

    if ($jsonFormats -inotcontains $Format)
    {

        return Invoke-WebRequest -QueryParams $QueryParams
    }

    $featureSet = Invoke-RestMethod $FeatureServerLayerUrl -Body $QueryParams -Method Get

    if ($null -ne $featureSet.error)
    {
        $featureSet | Select-Object -ExpandProperty error | Out-String | Write-Error
    }

    if ($ReturnFeatureSet)
    {
        return $featureSet
    }


    $features = $featureSet | Select-Object -ExpandProperty features

    foreach ($feature in $features)
    {
        $feature.attributes | ConvertTo-NotificationAttributes
    }

}