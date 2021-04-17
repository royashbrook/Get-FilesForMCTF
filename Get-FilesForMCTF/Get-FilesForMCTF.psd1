@{
    RootModule = 'Get-FilesForMCTF.psm1'
    ModuleVersion = '1.0.0.0'
    GUID = 'bd4f6053-0c8d-4ba2-8ddb-fdc085f35486'
    Author = 'Roy Ashbrook'
    CompanyName = 'ashbrook.io'
    Copyright = '(c) 2021 royashbrook. All rights reserved.'
    Description = 'Uses other modules to gather the files required for Motor Carrier Tax Filing. Note, requires ConvertTo-TaxFile to be loaded in global scope but *WILL NOT CHECK* prior to running.'
    RequiredModules = 'Add-PrefixForLogging','Get-TestResultsForMCTF','Get-FreightItemsForMCTF','Split-FreightItemsGBForMCTF','Split-FreightItemsGBForMCTF'
    FunctionsToExport = 'Get-FilesForMCTF'
    AliasesToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
}