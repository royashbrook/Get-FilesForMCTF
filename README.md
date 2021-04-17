# Get-FilesForMCTF

This process will create all of the files required for Motor Carrier Tax Filing. It uses various other modules for most of the heavy lifting and mostly calls those processes and creates files. The module manifest lists the dependencies *HOWEVER* there is one item to note.

As this module is utilized for multiple feeds and each feed has it's own format conversion logic, the module `ConvertTo-TaxFile` must be loaded into the global scope prior to this module being called. Otherwise it will fail. This should be loaded in the master job along with all other customizations prior to logic in this file being called to avoid problems.

The `ConvertTo-TaxFile` job cannot be loaded systemwide as a common module, because it is custom for each job. The logic in this function should not change, so it was turned into a module.