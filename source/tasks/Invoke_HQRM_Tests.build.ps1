<#
    .SYNOPSIS
        This is a build task that generates conceptual help.

    .PARAMETER ProjectPath
        The root path to the project. Defaults to $BuildRoot.

    .PARAMETER OutputDirectory
        The base directory of all output. Defaults to folder 'output' relative to
        the $BuildRoot.

    .PARAMETER ProjectName
        The project name.

    .PARAMETER SourcePath
        The path to the source folder name.

    .PARAMETER BuildInfo
        The build info object from ModuleBuilder. Defaults to an empty hashtable.

    .NOTES
        This is a build task that is primarily meant to be run by Invoke-Build but
        wrapped by the Sampler project's build.ps1 (https://github.com/gaelcolas/Sampler).
#>
param
(
    # Project path
    [Parameter()]
    [System.String]
    $ProjectPath = (property ProjectPath $BuildRoot),

    [Parameter()]
    # Base directory of all output (default to 'output')
    [System.String]
    $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

    [Parameter()]
    [System.String]
    $ProjectName = (property ProjectName ''),

    [Parameter()]
    [System.String]
    $SourcePath = (property SourcePath ''),

    [Parameter()]
    [System.String]
    $DscTestOutputFolder = (property DscTestOutputFolder 'testResults'),

    # [Parameter()]
    # [System.String]
    # $DscTestPesterOutputFormat = (property DscTestPesterOutputFormat ''),

    # [Parameter()]
    # [System.String[]]
    # $DscTestPesterScript = (property DscTestPesterScript ''),

    # [Parameter()]
    # [System.String[]]
    # $DscTestPesterTag = (property DscTestPesterTag @()),

    # [Parameter()]
    # [System.String[]]
    # $DscTestPesterExcludeTag = (property DscTestPesterExcludeTag @()),

    # Build Configuration object
    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ })
)

# Synopsis: Making sure the Module meets some quality standard (help, tests)
task Invoke_HQRM_Tests {
    if ([System.String]::IsNullOrEmpty($ProjectName))
    {
        $ProjectName = Get-ProjectName -BuildRoot $BuildRoot
    }

    if ([System.String]::IsNullOrEmpty($SourcePath))
    {
        $SourcePath = Get-SourcePath -BuildRoot $BuildRoot
    }

    if (-not (Split-Path -IsAbsolute $OutputDirectory))
    {
        $OutputDirectory = Join-Path -Path $ProjectPath -ChildPath $OutputDirectory

        Write-Build Yellow "Absolute path to Output Directory is $OutputDirectory"
    }

    if (-not (Split-Path -IsAbsolute $DscTestOutputFolder))
    {
        $DscTestOutputFolder = Join-Path -Path $OutputDirectory -ChildPath $DscTestOutputFolder
    }

    $getModuleVersionParameters = @{
        OutputDirectory = $OutputDirectory
        ProjectName     = $ProjectName
    }

    $ModuleVersion = Get-BuiltModuleVersion @getModuleVersionParameters

    if (-not (Test-Path -Path $DscTestOutputFolder))
    {
        Write-Build -Color 'Yellow' -Text "Creating folder $DscTestOutputFolder"

        $null = New-Item -Path $DscTestOutputFolder -ItemType Directory -Force -ErrorAction 'Stop'
    }

    # $DscTestPesterScript = $DscTestPesterScript.Where{ -not [System.String]::IsNullOrEmpty($_) }
    # $DscTestPesterTag = $DscTestPesterTag.Where{ -not [System.String]::IsNullOrEmpty($_) }
    # $DscTestPesterExcludeTag = $DscTestPesterExcludeTag.Where{ -not [System.String]::IsNullOrEmpty($_) }

    <#
        Default values for parameters for Pester 5.
        The parameter PassThru will be overridden further down
    #>
    $defaultPesterParameters = @{
        Output = 'Detailed'
    }

    # Default parameters for Pester 5.
    $defaultScriptParameters = @{
        # None for now.
    }

    Import-Module -Name 'Pester' -MinimumVersion 5.1 -ErrorAction 'Stop'

    if ($BuildInfo.DscTest -and $BuildInfo.DscTest.Script)
    {
        <#
            This will build the DscTestScript* variables (e.g. DscTestScriptExcludeSourceFile)
            in this scope that are used in the rest of the code.

            It will use values for the variables in the following order:

            1. Skip creating the variable if a variable is already available because
               it was already set in a passed parameter (DscTestScript*).
            2. Use the value from a property in the build.yaml under the key 'DscTest:'.
        #>
        foreach ($propertyName in $BuildInfo.DscTest.Script.Keys)
        {
            $taskParameterName = "DscTestScript$propertyName"
            $taskParameterValue = Get-Variable -Name $taskParameterName -ValueOnly -ErrorAction 'SilentlyContinue'

            if ($taskParameterValue)
            {
                Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Build Invocation Parameters"
            }
            else
            {
                $taskParameterValue = $BuildInfo.DscTest.Script.($propertyName)

                if ($taskParameterValue)
                {
                    # Use the value from build.yaml.
                    Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Build Config"

                    Set-Variable -Name $taskParameterName -Value $taskParameterValue
                }
            }
        }
    }
    # else
    # {
    #     throw 'Missing the key ''DscTest:'' or the child key ''Script:'' in the build configuration file build.yaml.'
    # }

    if ($BuildInfo.DscTest -and $BuildInfo.DscTest.Pester)
    {
        <#
            This will build the DscTestPester* variables (e.g. DscTestPesterExcludeTag)
            in this scope that are used in the rest of the code.

            It will use values for the variables in the following order:

            1. Skip creating the variable if a variable is already available because
               it was already set in a passed parameter (DscTestPester*).
            2. Use the value from a property in the build.yaml under the key 'DscTest:'.
        #>
        foreach ($propertyName in $BuildInfo.DscTest.Pester.Keys)
        {
            $taskParameterName = "DscTestPester$propertyName"
            $taskParameterValue = Get-Variable -Name $taskParameterName -ValueOnly -ErrorAction 'SilentlyContinue'

            if ($taskParameterValue)
            {
                Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Build Invocation Parameters"
            }
            else
            {
                $taskParameterValue = $BuildInfo.DscTest.Pester.($propertyName)

                if ($taskParameterValue)
                {
                    # Use the value from build.yaml.
                    Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Build Config"

                    Set-Variable -Name $taskParameterName -Value $taskParameterValue
                }
            }
        }
    }
    # else
    # {
    #     throw 'Missing the key ''DscTest:'' or the child key ''Pester:'' in the build configuration file build.yaml.'
    # }

    # Set the default value for all "Script:" properties that still have no value.
    foreach ($propertyName in $defaultScriptParameters.Keys)
    {
        $taskParameterName = "DscTestScript$propertyName"
        $taskParameterValue = Get-Variable -Name $taskParameterName -ValueOnly -ErrorAction 'SilentlyContinue'

        if (-not $taskParameterValue)
        {
            Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Defaults"

            Set-Variable -Name $taskParameterName -Value $defaultScriptParameters.($propertyName)
        }
    }

    # Set the default value for all "Pester:" properties that still have no value.
    foreach ($propertyName in $defaultPesterParameters.Keys)
    {
        $taskParameterName = "DscTestPester$propertyName"
        $taskParameterValue = Get-Variable -Name $taskParameterName -ValueOnly -ErrorAction 'SilentlyContinue'

        if (-not $taskParameterValue)
        {
            Write-Build -Color 'DarkGray' -Text "Using $taskParameterName from Defaults"

            Set-Variable -Name $taskParameterName -Value $defaultPesterParameters.($propertyName)
        }
    }

    "`tProject Path        = $ProjectPath"
    "`tProject Name        = $ProjectName"
    "`tSource Path         = $SourcePath"
    "`tOutput Directory    = $OutputDirectory"
    "`tBuild Module Output = $BuildModuleOutput"
    "`tModule Version      = $ModuleVersion"
    "`tTest Output Folder  = $DscTestOutputFolder"
    "`t"

    $pesterParameters = @{}

    $dscTestPesterVariables = Get-Variable -Name 'DscTestPester*' -Scope 'Local'

    $longestPropertyNameLength = (
        ($dscTestPesterVariables).Name |
            ForEach-Object -Process { $_.Length } |
            Measure-Object -Maximum
    ).Maximum

    foreach ($variable in $dscTestPesterVariables)
    {
        $pesterParameterName = $variable.Name -replace 'DscTestPester'

        $pesterParameters[$pesterParameterName] = $variable.Value

        $paddedVariableName = $variable.Name.PadRight($longestPropertyNameLength)

        "`t$($paddedVariableName) = $($variable.Value -join ', ')"
    }

    # Override the PassThru property if it was wrongly set through build configuration.
    $pesterParameters['PassThru'] = $true

    "`t"

    $scriptParameters = @{}

    $dscTestScriptVariables = Get-Variable -Name 'DscTestScript*' -Scope 'Local'

    $longestPropertyNameLength = (
        ($dscTestScriptVariables).Name |
            ForEach-Object -Process { $_.Length } |
            Measure-Object -Maximum
    ).Maximum

    foreach ($variable in $dscTestScriptVariables)
    {
        $scriptParameterName = $variable.Name -replace 'DscTestScript'

        $scriptParameters[$scriptParameterName] = $variable.Value

        $paddedVariableName = $variable.Name.PadRight($longestPropertyNameLength)

        "`t$($paddedVariableName) = $($variable.Value -join ', ')"
    }

    $pesterData = @{
        ProjectPath        = $ProjectPath
        SourcePath         = $SourcePath
        MainGitBranch      = $scriptParameters['MainGitBranch']
        # ModuleBase         = $ModuleUnderTest.ModuleBase
        # ModuleName         = $ModuleUnderTest.Name
        # ExcludeModuleFile  = $ExcludeModuleFile
        # ExcludeSourceFile  = $ExcludeSourceFile
    }

    $pathToHqrmTests = Join-Path -Path $PSScriptRoot -ChildPath '../Tests/QA'

    Write-Verbose -Message ('Path to HQRM tests: {0}' -f $pathToHqrmTests)

    $hqrmTestScripts = Get-ChildItem -Path $pathToHqrmTests

    $pesterContainers = @()

    foreach ($testScript in $hqrmTestScripts)
    {
        $pesterContainers += New-PesterContainer -Path $testScript.FullName -Data $pesterData
    }

    $pesterParameters['Container'] = $pesterContainers

    <#
        Avoiding processing the verbose statements unless it is necessary since
        ConvertTo-Json outputs a warning message ("serialization has exceeded the
        set depth") even if the verbose message is not outputted.
    #>
    if ($VerbosePreference -ne 'SilentlyContinue')
    {
        Write-Verbose -Message ($pesterParameters | ConvertTo-Json)
        Write-Verbose -Message ($scriptParameters | ConvertTo-Json)
    }

    $script:testResults = Invoke-Pester @pesterParameters

    $os = if ($isWindows -or $PSVersionTable.PSVersion.Major -le 5)
    {
        'Windows'
    }
    elseif ($isMacOS)
    {
        'MacOS'
    }
    else
    {
        'Linux'
    }

    $psVersion = 'PSv.{0}' -f $PSVersionTable.PSVersion
    $DscTestOutputFileFileName = "DscTest_{0}_v{1}.{2}.{3}.xml" -f $ProjectName, $ModuleVersion, $os, $psVersion
    # $DscTestOutputFullPath = Join-Path -Path $DscTestOutputFolder -ChildPath "$($DscTestPesterOutputFormat)_$DscTestOutputFileFileName"

    $DscTestResultObjectCliXml = Join-Path -Path $DscTestOutputFolder -ChildPath "DscTestObject_$DscTestOutputFileFileName"

    $null = $script:testResults | Export-CliXml -Path $DscTestResultObjectCliXml -Force
}