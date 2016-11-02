<############################################################################################ 
 # File: Pester.PowerShell.ODataUtils.Tests.ps1
 # This suite contains Tests that are
 # used for validating Microsoft.PowerShell.ODataUtils module.
 ############################################################################################>
$script:TestSourceRoot = $PSScriptRoot
Describe "Test suite for Microsoft.PowerShell.ODataUtils module" -Tags "BVT" {

    BeforeAll {
        $ModuleBase = Split-Path $script:TestSourceRoot
        $ModuleBase = Join-Path (Join-Path $ModuleBase 'src') 'ModuleGeneration'
    }

    Context "OData validation test cases" {

        BeforeAll {
            $scriptToDotSource = Join-Path $ModuleBase 'Microsoft.PowerShell.ODataUtilsHelper.ps1'
            . $scriptToDotSource
            $scriptToDotSource = Join-Path $ModuleBase 'Microsoft.PowerShell.ODataAdapter.ps1'
            . $scriptToDotSource

            $metadataXmlPath = Join-Path $script:TestSourceRoot "metadata.xml"
            $metadataXml = Get-Content $metadataXmlPath
        }
    
        function Get-MockCmdlet {[CmdletBinding()] param()
            return $PSCmdlet
        }
        
        It "Checks type coversion to CLR types" {
            
            $ODataTypes = @{
                "Edm.Binary"="Byte[]";
                "Edm.Boolean"="Boolean";
                "Edm.Byte"="Byte";
                "Edm.DateTime"="DateTime";
                "Edm.Decimal"="Decimal";
                "Edm.Double"="Double";
                "Edm.Single"="Single";
                "Edm.Guid"="Guid";
                "Edm.Int16"="Int16";
                "Edm.Int32"="Int32";
                "Edm.Int64"="Int64";
                "Edm.SByte"="SByte";
                "Edm.String"="String"}

            foreach ($h in $ODataTypes.GetEnumerator()) 
            {
                $resultType = Convert-ODataTypeToCLRType "$($h.Name)"
                $resultType | Should Be "$($h.Value)"
            }
        }

        It "Checks collection coversion to CLR types" {
            
            Convert-ODataTypeToCLRType 'Collection(Edm.Int16)' | Should Be 'Int16[]'
            Convert-ODataTypeToCLRType 'Collection(Collection(Edm.Byte))' | Should Be 'Byte[][]'
            Convert-ODataTypeToCLRType 'Collection(Collection(Edm.Binary))' | Should Be 'Byte[][][]'
        }

        It "Checks parsing metadata" {
            
            $tmpcmdlet = Get-MockCmdlet
            $result = ParseMetadata -metadataXml $metadataXml -metaDataUri 'https://SomeUri.org' -cmdletAdapter 'ODataAdapter' -callerPSCmdlet $tmpcmdlet
            $result.Namespace | Should Be "ODataDemo"
            $result.DefaultEntityContainerName | Should Be "DemoService"

            
            $result.EntitySets.Length | Should Be 7
            @($result.EntitySets | ?{$_.Name -eq 'Products'}).Count | Should Be 1
            
            $result.EntityTypes.Length | Should Be 10
            @($result.EntityTypes | ?{$_.Name -eq 'Customer'}).Count | Should Be 1

            $result.ComplexTypes.Length | Should Be 1
            @($result.ComplexTypes | ?{$_.Name -eq 'Address'}).Count | Should Be 1

            $result.Associations.Length | Should Be 5
            @($result.Associations | ?{$_.Name -eq 'Product_Categories_Category_Products'}).Count | Should Be 1

            $result.Actions.Length | Should Be 2
            @($result.Actions | ?{$_.Verb -eq 'IncreaseSalaries'}).Count | Should Be 1
        }

        It "Verifies that generated module has correct contents" {
            
            $tmpcmdlet = Get-MockCmdlet
            $metadata = ParseMetadata -metadataXml $metadataXml -metaDataUri 'https://SomeUri.org' -cmdletAdapter 'ODataAdapter' -callerPSCmdlet $tmpcmdlet

            $entitySet = $metadata.EntitySets[0]
            [string]$generatedModuleName = $entitySet.Type.Name

            $moduleDir = join-path $TestDrive "v3Module"
            mkdir $moduleDir -ErrorAction SilentlyContinue

            try
            {
                GenerateCRUDProxyCmdlet $entitySet $metadata 'http://fakeuri/Service.svc' $moduleDir 'Post' 'Patch' 'ODataAdapter' $null $null $null ' ' ' ' 10 5 10 1 $tmpcmdlet
            }
            catch
            {
                $_.FullyQualifiedErrorId | Should Be NotImplementedException
            }
            
            $modulepath = join-path $moduleDir $generatedModuleName
            $modulepath += ".cdxml"
            [xml]$doc = Get-Content $modulepath -Raw

            $queryableProperties = $doc.GetElementsByTagName("QueryableProperties")
            $queryableProperties.Count | Should Be 1
            $queryableProperties[0].ChildNodes.Count | Should Be 10
            $doc.GetElementsByTagName("QueryableAssociations").Count | Should Be 0
            $doc.GetElementsByTagName("GetCmdlet").Count | Should Be 1
            $staticCmdlets = $doc.GetElementsByTagName("StaticCmdlets")
            $staticCmdlets.Count | Should Be 1
            $staticCmdlets[0].ChildNodes.Count | Should Be 4
            $doc.GetElementsByTagName("Cmdlet").Count | Should Be 4
            $doc.GetElementsByTagName("Method").Count | Should Be 10
        }

        It "Verifies that generated module manifest has correct amount of nested modules" {
            
            $tmpcmdlet = Get-MockCmdlet
            $metadata = ParseMetadata -metadataXml $metadataXml -metaDataUri 'https://SomeUri.org' -cmdletAdapter 'ODataAdapter' -callerPSCmdlet $tmpcmdlet
            $moduleDir = join-path $TestDrive "v3Module"
            mkdir $moduleDir -ErrorAction SilentlyContinue
            $modulePath = Join-Path $moduleDir 'GeneratedModule.psd1'

            GenerateModuleManifest $metadata $modulePath @('GeneratedServiceActions.cdxml') $null 'Sample ProgressBar message'

            $fileContents = Get-Content $modulepath -Raw

            $rx = new-object System.Text.RegularExpressions.Regex('\bNestedModules = @\([^\)]*\)', ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline))
            $nestedModules = $rx.Match($fileContents).Value;

            $rx2 = new-object System.Text.RegularExpressions.Regex('([\w]*\.cdxml)', ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline))
            $rx2.Matches($nestedModules).Count | Should Be 8
        }
    }

     Context "OData v4 validation test cases" {
            
    
        BeforeAll {
            $scriptToDotSource = Join-Path $ModuleBase 'Microsoft.PowerShell.ODataUtilsHelper.ps1'
            . $scriptToDotSource
            $scriptToDotSource = Join-Path $ModuleBase 'Microsoft.PowerShell.ODataV4Adapter.ps1'
            . $scriptToDotSource

            $metadatav4XmlPath = Join-Path $script:TestSourceRoot "metadataV4.xml"
            $metadatav4Xml = Get-Content $metadatav4XmlPath
        }

        It "Checks parsing metadata" {
            
            $MetadataSet = New-Object System.Collections.ArrayList
            $result = ParseMetadata -MetadataXML $metadatav4Xml -MetadataSet $MetadataSet
            $result.Namespace | Should Be "Microsoft.OData.SampleService.Models.TripPin"
            
            $result.EntitySets.Length | Should Be 4
            @($result.EntitySets | ?{$_.Name -eq 'People'}).Count | Should Be 1
            
            $result.EntityTypes.Length | Should Be 9
            @($result.EntityTypes | ?{$_.Name -eq 'Person'}).Count | Should Be 1

            $result.ComplexTypes.Length | Should Be 4
            @($result.ComplexTypes | ?{$_.Name -eq 'Location'}).Count | Should Be 1

            $result.EnumTypes.Length | Should Be 1
            @($result.EnumTypes | ?{$_.Name -eq 'PersonGender'}).Count | Should Be 1

            $result.SingletonTypes.Length | Should Be 1
            @($result.SingletonTypes | ?{$_.Name -eq 'Me'}).Count | Should Be 1

            $result.Actions.Length | Should Be 2
            $result.Functions.Length | Should Be 4
        }

        It "Verify normalization" {

            #Verifies that NormalizeNamespace normalizes namespace name as expected.
            $normalizedNamespaces = @{}
            NormalizeNamespace 'Microsoft.OData.SampleService.Models.TripPin.1.0.0' 'SomeUri' $normalizedNamespaces $false
            $normalizedNamespaces.Count | Should Be 1
            GetNamespace 'Microsoft.OData.SampleService.Models.TripPin.1.0.0' $normalizedNamespaces $false | Should Be "Microsoft_OData_SampleService_Models_TripPin_1_0_0"

            #Verifies that NormalizeNamespace normalizes alias name as expected.
            $normalizedNamespaces = @{}
            NormalizeNamespace 'TripPin.1.0.0' 'SomeUri' $normalizedNamespaces $false
            $normalizedNamespaces.Count | Should Be 1
            GetNamespace 'TripPin.1.0.0' $normalizedNamespaces $false | Should Be "TripPin_1_0_0"

            #Verifies that NormalizeNamespace normalizes namespace name as expected.
            $normalizedNamespaces = @{}
            NormalizeNamespace 'Microsoft.OData.SampleService.Models.TripPin' 'SomeUri' $normalizedNamespaces $true
            $normalizedNamespaces.Count | Should Be 1
            GetNamespace 'Microsoft.OData.SampleService.Models.TripPin' $normalizedNamespaces $false | Should Be "Microsoft.OData.SampleService.Models.TripPinNs"

            #Verifies that NormalizeNamespace normalizes alias name as expected.
            $normalizedNamespaces = @{}
            NormalizeNamespace 'TripPin' 'SomeUri' $normalizedNamespaces $true
            $normalizedNamespaces.Count | Should Be 1
            GetNamespace 'TripPin' $normalizedNamespaces $false | Should Be "TripPinNs"

            #Verifies that IsNamespaceNormalizationNeeded returns true when namespace contains combination of dots and numbers.
            $normalizedNamespaces = @{}
            NormalizeNamespace 'Microsoft.OData.SampleService.Models.TripPin.1.0.0' 'SomeUri' $normalizedNamespaces $false
            $normalizedNamespaces.Count | Should Be 1

            #Verifies that IsNamespaceNormalizationNeeded returns false when namespace is a combination of Namespace and TypeName and namespace name does not require normalization.
            $normalizedNamespaces = @{}
            NormalizeNamespace 'Microsoft.OData.SampleService.Models.TripPin' 'SomeUri' $normalizedNamespaces $false
            GetNamespace 'Microsoft.OData.SampleService.Models.TripPin.Photo' $normalizedNamespaces $true | Should Be "Microsoft.OData.SampleService.Models.TripPin.Photo"

            #Verifies that IsNamespaceNormalizationNeeded returns true when namespace contains combination of dots and numbers.
            $normalizedNamespaces = @{}
            NormalizeNamespace 'Microsoft.OData.SampleService.Models.TripPin' 'SomeUri' $normalizedNamespaces $false
            $normalizedNamespaces.Count | Should Be 0
        }

        It "Verifies that generated module has correct contents" {
            
            $GlobalMetadata = New-Object System.Collections.ArrayList
            $metadata = ParseMetadata -MetadataXML $metadatav4Xml -MetadataSet $GlobalMetadata
            $GlobalMetadata.Add($metadata)
            $normalizedNamespaces = @{}
            $entitySet = $metadata.EntitySets[0]
            [string]$generatedModuleName = $entitySet.Type.Name
            $moduleDir = join-path $TestDrive "v4Module"
            mkdir $moduleDir

            SaveCDXML $entitySet $metadata $GlobalMetadata 'http://fakeuri/Service.svc' $moduleDir 'Post' 'Patch' 'ODataV4Adapter' -UriResourcePathKeyFormat 'EmbeddedKey' -normalizedNamespaces $normalizedNamespaces

            $modulepath = join-path $moduleDir $generatedModuleName
            $modulepath += ".cdxml"
            [xml]$doc = Get-Content $modulepath -Raw

            $queryableProperties = $doc.GetElementsByTagName("QueryableProperties")
            $queryableProperties.Count | Should Be 1
            $queryableProperties[0].ChildNodes.Count | Should Be 7
            $doc.GetElementsByTagName("GetCmdlet").Count | Should Be 1
            $staticCmdlets = $doc.GetElementsByTagName("StaticCmdlets")
            $staticCmdlets.Count | Should Be 1
            $staticCmdlets[0].ChildNodes.Count | Should Be 3
            $doc.GetElementsByTagName("Cmdlet").Count | Should Be 3
            $doc.GetElementsByTagName("Method").Count | Should Be 3
        }
        
        It "Verifies that generated module manifest has correct amount of nested modules" {
            
            $GlobalMetadata = New-Object System.Collections.ArrayList
            $metadata = ParseMetadata -MetadataXML $metadatav4Xml -MetadataSet $GlobalMetadata
            $GlobalMetadata.Add($metadata)


            $moduleDir = join-path $TestDrive "v4Module"
            mkdir $moduleDir -ErrorAction SilentlyContinue
            $modulePath = Join-Path $moduleDir 'GeneratedModule.psd1'

            GenerateModuleManifest $GlobalMetadata $modulePath @('GeneratedServiceActions.cdxml') $null 'Sample ProgressBar message'

            $fileContents = Get-Content $modulepath -Raw

            $rx = new-object System.Text.RegularExpressions.Regex('\bNestedModules = @\([^\)]*\)', ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline))
            $nestedModules = $rx.Match($fileContents).Value;

            $rx2 = new-object System.Text.RegularExpressions.Regex('([\w]*\.cdxml)', ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline))
            $rx2.Matches($nestedModules).Count | Should Be 6
        }
    }

    Context "Redfish validation test cases" {
    
        BeforeAll {
            $scriptToDotSource = Join-Path $ModuleBase 'Microsoft.PowerShell.ODataUtilsHelper.ps1'
            . $scriptToDotSource
            $scriptToDotSource = Join-Path $ModuleBase 'Microsoft.PowerShell.RedfishAdapter.ps1'
            . $scriptToDotSource

            $metaFilesRoot = Join-Path $script:TestSourceRoot 'RedfishData'
            $metaFilePaths = Get-ChildItem $metaFilesRoot -Filter '*.xml'

            $metaXmls= @()
            foreach($metaFile in $metaFilePaths)
            {
                $metaXmls += Get-Content $metaFile.FullName -Raw
            }
        }

        It "Checks parsing metadata" {
            
            # based on Redfish Schema DSP8010 / 2016.1 / 31 May 2016

            try { ExportODataEndpointProxy } catch {} # calling this here just to initialize module variables

            foreach($metaXml in $metaXmls)
            {
                ParseMetadata -MetadataXML $metaXml -ODataVersion '4.0' -MetadataUri 'http://fakeuri/redfish/v1/$metadata' -Uri 'http://fakeuri/redfish/v1'
            }

            @($GlobalMetadata | ?{if ($_) {$_}}).Count | Should Be 159
            @($GlobalMetadata.EntityTypes | ?{if ($_) {$_}}).Count | Should Be 158
            @($GlobalMetadata.ComplexTypes | ?{if ($_) {$_}}).Count | Should Be 94
            @($GlobalMetadata.EnumTypes | ?{if ($_) {$_}}).Count | Should Be 74
            @($GlobalMetadata.SingletonTypes | ?{if ($_) {$_}}).Count | Should Be 11
            @($GlobalMetadata.Actions | ?{if ($_) {$_}}).Count | Should Be 19
            @($GlobalMetadata.EntityTypes.NavigationProperties | ?{if ($_) {$_}}).Count | Should Be 76
        }

        It "Verifies that generated module has correct contents" {
            
            try { ExportODataEndpointProxy } catch {} # calling this here just to initialize module variables

            foreach($metaXml in $metaXmls)
            {
                ParseMetadata -MetadataXML $metaXml -ODataVersion '4.0' -MetadataUri 'http://fakeuri/redfish/v1/$metadata' -Uri 'http://fakeuri/redfish/v1'
            }

            $moduleDir = join-path $TestDrive "RedfishModule"
            mkdir $moduleDir

            $ODataEndpointProxyParameters = [ODataUtils.ODataEndpointProxyParameters] @{
                "MetadataUri" = 'http://fakeuri/redfish/v1/$metadata';
                "Uri" = 'http://fakeuri/redfish/v1';
                "OutputModule" = $moduleDir;
                "Force" = $true;
            }
            
            GenerateClientSideProxyModule $GlobalMetadata $ODataEndpointProxyParameters $moduleDir 'Post' 'Patch' 'ODataV4Adapter' -progressBarStatus 'generating module'

            # check generated files in module directory
            @(dir $moduleDir -Filter '*.cdxml').Count | Should Be 63
            $psd1 = dir $moduleDir -Filter '*.psd1'
            @($psd1).Count | Should Be 1

            # basic check for generated psd1
            $fileContents = Get-Content $psd1.FullName -Raw
            $rx = new-object System.Text.RegularExpressions.Regex('\bNestedModules = @\([^\)]*\)', ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline))
            $nestedModules = $rx.Match($fileContents).Value;
            $rx2 = new-object System.Text.RegularExpressions.Regex('([\w]*\.cdxml)', ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline))
            $rx2.Matches($nestedModules).Count | Should Be 63

            # basic check for ServiceRoot cdxml
            @(dir $moduleDir -Filter 'ServiceRoot.cdxml').Count | Should Be 1
            
            # basic check for other sample cdxml
            $modulepath = Join-Path $moduleDir 'ComputerSystem.cdxml'
            [xml]$doc = Get-Content $modulepath -Raw
            
            $doc.GetElementsByTagName("GetCmdlet").Count | Should Be 1
            $staticCmdlets = $doc.GetElementsByTagName("StaticCmdlets")
            $staticCmdlets.Count | Should Be 1
            $staticCmdlets[0].ChildNodes.Count | Should Be 4
            $doc.GetElementsByTagName("Cmdlet").Count | Should Be 4
            $doc.GetElementsByTagName("Method").Count | Should Be 9
        }
    }
}