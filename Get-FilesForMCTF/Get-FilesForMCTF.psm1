using namespace System.Collections.Generic
function Get-FilesForMCTF($cfg, $file) {

    #set output file names
    $now = (get-date)
    $of_FreightItemsAll = ("{0:yyyyMMdd}-FreightItemsAll.csv" -f $now)
    $of_CompanyTR = ("{0:yyyyMMdd}-CompanyExceptions.csv" -f $now)
    $of_FreightTR = ("{0:yyyyMMdd}-FreightExceptions.csv" -f $now)
    $of_FreightItemsG = ("{0:yyyyMMdd}-FreightItemsGood.csv" -f $now)
    $of_FreightItemsB = ("{0:yyyyMMdd}-FreightItemsBad.csv" -f $now)

    l "Getting FreightItems"
    $FreightItems = Get-FreightItemsForMCTF $cfg.sql $cfg.cs $of_FreightItemsAll
    l "FreightItems:`t$($FreightItems.count)"
    if ($FreightItems.count -eq 0) {
        l "no data to process"
        break;
    }

    l "Getting Company and Freight TestResults"
    $TestResults = Get-TestResultsForMCTF $FreightItems $cfg.tests $cfg.companytypes
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

    l "Saving Files"
    ConvertTo-TaxFile $cfg $file $FreightItemsG
    $CompanyTR | Export-Csv -NoTypeInformation $of_CompanyTR
    $FreightTR | Export-Csv -NoTypeInformation $of_FreightTR
    $FreightItemsG | Export-Csv -NoTypeInformation $of_FreightItemsG
    $FreightItemsB | Export-Csv -NoTypeInformation $of_FreightItemsB

    l "Zipping Files"
    $FilesToZip = $of_CompanyTR, $of_FreightTR, $of_FreightItemsG, $of_FreightItemsB, $file
    $ZipFile = "$file.zip"
    Compress-Archive -Path $FilesToZip -Force -DestinationPath $ZipFile
}
function Get-TestResultsForMCTF($FreightItems, $Tests, $CompanyTypeMappings) {
    #get freight only test results
    $tt = $Tests | Where-Object Type -eq "Freight"
    $FreightOnlyTR = @()
    foreach ($t in $tt) {
        foreach ($f in $FreightItems) {
            if ($f.$($t.field) -NotMatch $t.test) {
                $FreightOnlyTR += [pscustomobject]@{
                    ord_hdrnumber = $f.ord_hdrnumber
                    fgt_number    = $f.fgt_number
                    test          = $t.name
                    current       = $f.$($t.field)
                }
            }
        }
    }
    #get company only test results
    $CompanyTR = @()
    foreach ($ctm in $CompanyTypeMappings) {
        $companies = $FreightItems |
        Where-Object $ctm.k -match ".+" |
        Group-Object $ctm.f |
        ForEach-Object { $_.Group[0] | Select-Object $ctm.f }
        $tt = $Tests |
        Where-Object Type -eq $ctm.t
        foreach ($c in $companies) {
            foreach ($t in $tt) {
                if ($c.$($t.field) -NotMatch $t.test) {
                    $CompanyTR += [pscustomobject]@{
                        type    = $t.type
                        cmp_id  = $c.$($ctm.k)
                        test    = $t.name
                        current = $c.$($t.field)
                    }
                }                
            }
        }
    }
    #convert the company results to a single record formatted like the freight errors
    $BadCompanyTRF = @()
    foreach ($ctm in $CompanyTypeMappings) {
        $CompanyTRGroups = $CompanyTR | Where-Object Type -eq $ctm.t | Group-Object Type
        foreach ($c in $CompanyTRGroups) {
            $badids = [HashSet[string]]::new([string[]]($c.Group.cmp_id))
            foreach ($f in $FreightItems) {
                if ($badids.Contains($f.$($ctm.k))) {
                    $BadCompanyTRF += [PSCustomObject]@{
                        ord_hdrnumber = $f.ord_hdrnumber
                        fgt_number    = $f.fgt_number
                        test          = "Bad {0} Record" -f $ctm.t
                        current       = $f.$($ctm.k)
                    }
                }
            }
        }
    }

    #return company errors and combined errors formatted for freight.
    $CompanyTR, ($FreightOnlyTR + $BadCompanyTRF)
}
function Get-FreightItemsForMCTF($sqlfile, $cs, $of_FreightItemsAll) {

    Invoke-Sqlcmd -QueryTimeout 1800 -ConnectionString $cs -InputFile $sqlfile |
        Select-Object * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors |
        Export-Csv -NoTypeInformation $of_FreightItemsAll
    Import-Csv $of_FreightItemsAll

}
function Split-FreightItemsGBForMCTF($FreightItems, $FreightTR) {
    if ($FreightTR.count -eq 0) {
        $FreightItems, @()
    }
    else {
        $b_fgt_numbers = [HashSet[string]]::new([string[]]($FreightTR.fgt_number))
        $v = $FreightItems | Group-Object { $b_fgt_numbers.Contains($_.fgt_number) } -AsHashTable -AsString
        $FreightItemsG = $v.False
        $FreightItemsB = $v.True
        if ($null -eq $FreightItemsG) { $FreightItemsG = @() }
        if ($null -eq $FreightItemsB) { $FreightItemsB = @() }
        $FreightItemsG, $FreightItemsB
    }
}
Export-ModuleMember -Function Get-FilesForMCTF