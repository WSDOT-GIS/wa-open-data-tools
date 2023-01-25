BeforeAll {
    $DebugPreference = 'Continue'
    Import-Module '.\wa-open-data.psm1' -Scope Local -Force
}

Describe 'wa-open-data' {
    It 'can convert from ArcGIS date representation (milliseconds since 1970-01-01T00:00:00) to .NET date types' {
        $milliseconds = 1556582400000

        $expectedDate = ([datetime]::Parse('2019-04-30'))

        ConvertFrom-ArcGisJsonDate $milliseconds | Should -EQ $expectedDate
    }
}
