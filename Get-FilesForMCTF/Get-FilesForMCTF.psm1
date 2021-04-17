function Get-FilesForMCTF($now,$cfg,$file){
    #set output file names
    $of_FreightItemsAll = ("{0:yyyyMMdd}-FreightItemsAll.csv" -f $now)
    $of_CompanyTR       = ("{0:yyyyMMdd}-CompanyExceptions.csv" -f $now)
    $of_FreightTR       = ("{0:yyyyMMdd}-FreightExceptions.csv" -f $now)
    $of_FreightItemsG   = ("{0:yyyyMMdd}-FreightItemsGood.csv" -f $now)
    $of_FreightItemsB   = ("{0:yyyyMMdd}-FreightItemsBad.csv" -f $now)

    l "Getting Config"

    l "Getting CompanyTypeMappings"
    $CompanyTypeMappings = $cfg.companytypes
    l "CompanyTypeMappings:`t$($CompanyTypeMappings.count)"

    l "Getting Tests"
    $Tests = $cfg.tests
    l "Tests:`t$($Tests.count)"

    l "Getting FreightItems"
    $FreightItems = Get-FreightItemsForMCTF $cfg.sql $cfg.cs $of_FreightItemsAll
    l "FreightItems:`t$($FreightItems.count)"
    if ($FreightItems.count -eq 0){
        l "no data to process"
        break;
    }

    l "Getting Company and Freight TestResults"
    $TestResults = Get-TestResultsForMCTF $FreightItems $Tests $CompanyTypeMappings
    $CompanyTR = $TestResults[0]
    $FreightTR = $TestResults[1]
    l "CompanyTR:`t$($CompanyTR.count)"
    l "FreightTR:`t$($FreightTR.count)"

    l "Getting Good/Bad FreightItems"
    $FreightItemsGB = Split-FreightItemsGBForMCTF $FreightItems $FreightTR
    $FreightItemsG = $FreightItemsGB[0]
    $FreightItemsB = $FreightItemsGB[1]
    l "FreightItemsG:`t$($FreightItemsG.count)"
    l "FreightItemsB:`t$($FreightItemsB.count)"

    l "Converting Good FreightItems to TaxFile"
    $TaxFileData = ConvertTo-TaxFile $FreightItemsG

    l "Saving All Files"
    $CompanyTR | Export-Csv -NoTypeInformation $of_CompanyTR
    $FreightTR | Export-Csv -NoTypeInformation $of_FreightTR
    $FreightItemsG | Export-Csv -NoTypeInformation $of_FreightItemsG
    $FreightItemsB | Export-Csv -NoTypeInformation $of_FreightItemsB
    $TaxFileData | Set-Content $file

    l "Generating Zip File"
    $FilesToZip = $of_CompanyTR,$of_FreightTR,$of_FreightItemsG,$of_FreightItemsB,$file
    $ZipFile = "$file.zip"
    Compress-Archive -Path $FilesToZip -Force -DestinationPath $ZipFile
}
Export-ModuleMember -Function * -Alias *