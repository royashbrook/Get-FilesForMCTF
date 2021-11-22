# What is this?
This module provides the core function for pulling data out of TMW Suite to use for Motor Carrier Tax Filing. This module assumes TMW Suite is installed on a sql server. This module will also use custom data validation tests to generate error reports for data that cannot be submitted for filings.

This module can theoretically be used with any system that conforms to the data structures expected to be passed in. The module could be extended to use any testing method required as well as any type of data source as needed. 
# Why does this exist?
High level, some states require companies that deliver goods with trucks (motor carriers) to file taxes reports about what they transported. While no taxes are paid, this is generally required in order to maintain a license to carry some things in some states.

More details about these items:

- [TMW Suite](https://transportation.trimble.com/products/tmw-suite)
- Motor Carrier Tax Filing - Google this topic. Rules vary by state. 

This was built from an immediate need after many years of previous similar processes began to fail. This common module was created to allow for common reporting and a common structure for generation of these files. Jobs existed to output the appropriate file format for a state, but this process creates a common framework for validating all of the data to be filed and provide common exception reporting along side that generation. This way data could be corrected and filing regenerated as needed. In the event that filings are done with missing data, it provides a way to plan for filing amendments and gives a way to plan level of effort for those exercises.
# How do I use this module?

## High level steps
1. Ensure dependencies are in place
2. Install the module where needed
3. Import the module as needed 
4. Invoke the function passing in the expected $config structure and an output file name.
5. Utilize the output files for filings and error reporting
# Example

The notes above may make this process seem easy, and it _is_, once all dependencies are in place. Generally these filings are done monthly, so once this is setup, it is relatively low maintenance, but it does require some more detailed setup as there are some other dependencies expected to be in place.

First let's start with an example of invoking this in a scheduled powershell job. Then some of the details, dependencies, and other items of notes will be explored.

Below is a sample implementation utilizing this.

## Sample Job

```ps1
# job.ps1
function main{

    #set location to script path
    Set-Location $PSScriptRoot

    #import modules
    Import-Module Add-PrefixForLogging
    Import-Module SqlServer -Cmdlet "Invoke-Sqlcmd"
    Import-Module .\ConvertTo-TaxFile.psm1 -Force
    Import-Module Get-FilesForMCTF
    Import-Module Send-FileViaEmail

    #get config, set primary output file name
    $cfg   = Get-Content settings.json -Raw | ConvertFrom-Json
    $file  = $cfg.file_format -f (get-date).AddMonths(-1)

    #main logic
    Get-FilesForMCTF $cfg $file
    Send-FileViaEmail "$file.zip" $cfg

}
#run main, output to screen and log
& { main } *>&1 | Tee-Object -Append ("{0:yyyyMMdd}.log" -f (get-date))

```

job.ps1 is a powershell script that will be scheduled to run monthly. It performs the following sequence of steps:

1. set our location to the script root. this way we are running where the script is located
2. import dependency modules
   - `Add-PrefixForLogging` is a very basic logging module that prepends a timestamp to logged messages.
      - In future versions this may be removed, but for now it is used internally in this module so must be included.
   - sql server is used by `Get-FilesForMCTF` to get data from the database
      - only a single cmdlet is required, so that is all that is loaded
   - `ConvertTo-TaxFile.psm1` is used by `Get-FilesForMCTF` to generate the final output file for submission to a state
      - Force param is used mostly for live testing of changes to this command
   - `Get-FilesForMCTF` is this module
      - The output of this step will be a zip file containing the file to send to the state as well as several report files to be used by staff filing with the state for decision making.
   - `Send-FileViaEmail` is an example for what to do with the payload after the fact
      - This could be replaced with any other delivery mechanism, but typically the actual filing is done by a person, so emailing the output payload to a human is preferable.
3. load job config from settings.json
4. define the file name, this is the file name to be used for filing with a state.
   - most states have a specific naming convention
   - typically as you would run a job like this in the next month, it will backdate the file name for the previous month
   - file name config is inside of settings.json
5. call `Get-FilesForMCTF` to generate file and report output
6. call `Send-FileViaEmail` to send file to filing staff. file name has .zip appended to it as a .zip will be generated with the contents of the file as well as the reports
7. in this job, main is a function that performs the above steps, it is invoked at the bottom and tee'd to a log file as well in on screen monitoring is desired.
8. note: no cleanup is performed as these are tax files. it is assumed that cleanup of files will be manual since files should likely be kept for 7+ years.

## Inputs
As we see in the sample job above, we have some inputs required in addition to our dependencies to discuss.

- $cfg
- $file

### $cfg

As the shortened name may imply, this is a configuration object. Below is an example with a truncated set of data.

```json
{
    "file_format": "{0:yyyyMM}somestate.edi",
    "cs": "yourconnectionstring",
    "sql": "get-data.sql",
    "companytypes": [
        {
            "t": "Shipper",
            "k": "shipper.cmp_id",
            "f": ["shipper.cmp_id", "shipper.name", "shipper.state", "shipper.tcn"]
        },
        {
            "t": "Consignee",
            "k": "consignee.cmp_id",
            "f": ["consignee.cmp_id", "consignee.name", "consignee.address", "consignee.city", "consignee.state", "consignee.zip", "consignee.tax_id", "consignee.dep"]
        }
    ],
    "tests": [
        {
            "type": "Freight",
            "name": "Net is not a 3 to 6 digit number",
            "field": "net",
            "test": "^[0-9]{3,6}$"
        },
        {
            "type": "Freight",
            "name": "Missing Consignee",
            "field": "consignee.cmp_id",
            "test": "^.+$"
        },
        {
            "type": "Consignee",
            "name": "Missing Consignee name",
            "field": "consignee.name",
            "test": "^.+$"
        },
        {
            "type": "Consignee",
            "name": "Consignee Tax ID is not a 9 digit number",
            "field": "consignee.tax_id",
            "test": "^[0-9]{9,}$"
        }
    ]
}
```

Details on the config structure:
- $cfg.file_format - string format to be used for generating the final filing file. when the final output package is generated, it will include test reports as well as this file in a zip file.
- $cfg.cs - connection string to sql database
- $cfg.sql - file name for sql script used to extract data from tmw database. this sql must contain all fields expected by this module. this is a mix of required fields as well as fields required by each of the tests listed in the config.
- $cfg.companytypes - due to the way data is structured, some items impact multiple line items of freight. so if you have a bad consignee or shipper tax id number, it will cause every load associated with those items to fail. due to this, company types are created which allow 'company' level testing so those reports can be generated seperately with one of each error, and in the freight level error report only a single error noting there is an error with the specific company type is listed.
   - $cfg.companytypes.[].t - human readable string for the company type. 
   - $cfg.companytypes.[].k - this is the 'key' field name used for this company type. must match the value in sql
   - $cfg.companytypes.[].f - value is a list of field names that we normally want to include in our company object
   - note that the key field should be in this list
- $cfg.tests - list of internal tests to run on fields. currently these are all regex pattern tests.
   - $cfg.tests.[].type - there are two types of tests. freight tests and company tests. company tests are as noted above, but freight tests are associated with a piece of freight. for example of a fuel load has 0 gallons when it should have something, or if a freight line does not have a shipper associated with it.
   - $cfg.tests.[].name - human readable name for the test, used in the exception reporting.
   - $cfg.tests.[].field - name of the field we are testing. must matchin sql.
   - $cfg.tests.[].test - regex to use for test on this field

#### Note:
settings.json may also have other config sections required by other modules. emailer module, for example, will expect a segment with the appropriate config. to provide maximum future flexibility, we simply pass the entire config value into this module rather than individual sections.

### $file
$file is simply the name of the output file to be generated for the state. This is the name of the file that will actually be sent to the state during filing.
## Output

The output of this module will be a zip file. The module does not return this to the pipeline, but will actually generate and save a zip file. The name of the zip file will vary based on the config file_format value. Assuming file_format is a valid string format, the output of this module will be a zip file named file_format.zip. For example, if the file_format ends up generating a name like 200101WA.edi, the final output file will be named 200101WA.edi.zip and it will have the reports as well as the file 200101WA.edi inside.

### Files Generated

The basic use case of this module is that a bundle of report files as well as a file to be uploaded to a state site will be emailed to a person who will do this filing. The report files are all commonly generated for every state filing with identical names. This is different than the state file which may have different formats and is passed in. At the outset of this module, the output file names are defined like so:

```ps1
    #set output file names
    $now = (get-date)
    $of_FreightItemsAll = ("{0:yyyyMMdd}-FreightItemsAll.csv" -f $now)
    $of_CompanyTR = ("{0:yyyyMMdd}-CompanyExceptions.csv" -f $now)
    $of_FreightTR = ("{0:yyyyMMdd}-FreightExceptions.csv" -f $now)
    $of_FreightItemsG = ("{0:yyyyMMdd}-FreightItemsGood.csv" -f $now)
    $of_FreightItemsB = ("{0:yyyyMMdd}-FreightItemsBad.csv" -f $now)
```

The final zip file will not include the `all` file. That is persisted just for troubleshooting purposes, but the exceptions and the good/bad files will be included. In terms of data flow-down things look like this:

- All (pulled from sql)
  - Good
      - State file
  - Bad
      - Exception Reports

So all the data ends up in the all csv, that data will end up in either good or bad, and the bad data will have exception reports showing how it is bad, and the state file will have the properly formatted version of the good data.

The steps used internally to generate the files are:
- Get FreightItems from DB
- Calculate Test Results
- Split data into good or bad based on Test Results
- Save output reports with test results and good/bad split
- Use good data to generate tax file in state's format
- Zip up test results, good/bad split files, and state specific tax file into a bundle

## Additional Notes

### SQL

While the sql will not be completely outlined here, the data comes from TMW Suite and so requires some knowledge of how that system stores data internally. The common output used for this effort has these fields.

```sql
[ord_hdrnumber]
[fgt_number]
[bol]
[shipped]
[delivered]
[gross]
[net]
[shipper.cmp_id]
[shipper.name]
[shipper.state]
[shipper.tcn]
[supplier.cmp_id]
[supplier.name]
[supplier.tax_id]
[consignor.cmp_id]
[consignor.name]
[consignor.tax_id]
[consignee.cmp_id]
[consignee.name]
[consignee.address]
[consignee.city]
[consignee.state]
[consignee.zip]
[consignee.tax_id]
[schedule]
[cmd_code]
```

As these field names line up with tests, and we use many common tests, we generally use the same sql with some simple changes to account for state differences. It is possible to simply add or rename fields and then adjust tests and field names as needed in the config. All testing can be removed and the job should still run appropriately, but the purpose of this process is to not only generate the files, but to provide immediate visibility to items that cannot be put into a filing because they will be rejected by the state systems.

While this entire process is normally run within a month for data in the previous month, this is simply a limitation within sql. For situations where amendments must be filed, the sql can be updated to pull whatever range of data is required, as long as it comes out in the expected fields above and matches what is needed for testing, it will work fine.

### Other Notes

A custom version of this module can be used where it is needed. Generally speaking the customization is held in the 'conversion' step or in the 'send data' step. Most times we send a file to someone, but in some instances auto-filing is done.

Currently, we typically run these jobs weekly to look for exceptions prior to filing, and file in the third or fourth week of the month. The jobs can be fired manually as needed after corrections may have been made.

If auto-filing is done, generally the autofiling logic is contained in the custom file formatting module and instead of a simple 'send email' function there will be something like 'file and send email' and that function would contain a step to confirm if it should actually file. Below is an example of a function like that with some explanation of the logic to return a true/false response.

```ps1
function Confirm-ShouldFile([DateTime]$d) {

    # The job runs every Tuesday and filing is due on the 20th

    # If before 14th, the job will run again before the due date so skip
    # If it is 14-20 it will not run again until after the due so run it
    # If it is after the 20th, it should have already been filed

    # So we simply return whether or not we are 14-20th as a bool

    (14..20).Contains($d.Day)

}
```

