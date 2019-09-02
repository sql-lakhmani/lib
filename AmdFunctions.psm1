#region BEGIN PAUSE FUNCTION DEFINITION

Function left {
   [CmdletBinding()]
 
   Param (
      [Parameter(Position=0, Mandatory=$True,HelpMessage="Enter a string of text")]
      [String]$text,
      [Parameter(Mandatory=$True)]
      [Int]$Length
   )
$left = $text.SubString(0, [math]::min($Length,$text.length))
$left
}

Function GUIPAUSE ($Message = "Click OK to continue or CANCEL to exit script", $Title = "Continue or Cancel") {
    Add-Type -AssemblyName System.Windows.Forms | Out-Null
    $MsgBox = [System.Windows.Forms.MessageBox]
    $Decision = $MsgBox::Show($Message,$Title,"OkCancel", "Information")
    If ($Decision -eq "Cancel") {exit}
}

#endregion

Function IsBetweenDates([Datetime]$start,[Datetime]$end)
{
	$d = get-date
	if (($d -ge $start) -and ($d -le $end))
	{
		return $true
	}
	else
	{
		return $false
	}
}
#-------------------------------------------------------------------------
function Import-CsvWithDuplicate($Path, $Delimiter=',', $Encoding='UTF8')
{
    # get the header line and all header items
    $headerLine = Get-Content $Path | Select-Object -First 1
    $headers = $headerLine.Split($Delimiter) 

    # check for duplicate header names, and if found, add an incremented
    # number to it
    $dupDict = @{}
    $newHeaders = @(foreach($header in $headers)
    {
        $incrementor = 1
        $header = $header.Trim('"')
        $newheader = $header

        # increment numbers until the new name is unique
        while ($dupDict.ContainsKey($newheader) -eq $true)
        {
            $newheader = "$header$incrementor"
            $incrementor++
        } 
        
        $dupDict.Add($newheader, $header)

        # return the new header, producing a string array
        $newheader
    })

    # read the CSV without its own headers..lakhmani
    Get-Content -Path $Path -Encoding $Encoding | 
      Select-Object -Skip 1 |
      # ..and replace headers with newly created list
      ConvertFrom-CSV -Delimiter $Delimiter -Header $newHeaders
}
#-------------------------------------------------------------------------
function FuncCheckService{
param($ServiceName)
$arrService = Get-Service -Name $ServiceName
$Date = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
$Start = "Started "
$Started = " service is Re started."
if ($arrService.Status -ne "Running"){
Start-Service $ServiceName
($Date + " - " + $Start + $ServiceName) | Out-file C:\ServiceLogs\serviceStart.txt -append
}
if ($arrService.Status -eq "Running"){ 
Restart-Service $ServiceName
($Date + " - " + $ServiceName + $Started) | Out-file c:\ServiceLogs\serviceStart.txt -append
}
}

#FuncCheckService -ServiceName "RCBTaxCommSrvc"
#-------------------------------------------------------------------------
Function Create-Monthly-CSV {
[cmdletbinding()]
Param
(
[string]$DirPath, 
[string]$FolderName,
[string]$Year
) 

Create-Directory($Dirpath)

Push-Location
Set-Location $Dirpath


for ($i=1; $i -le 12; $i++) {
    $NameOfFile=$FolderName+"-"+$year+"-"+$i.ToString("00")
    $DestinationFile = $FolderName+"-"+$year+"-"+$i.ToString("00")+".csv"
    Create-File($DestinationFile)
    }
    Pop-Location
}
#--PDF
Function Create-Monthly-PDFs {
[cmdletbinding()]
Param
(
[string]$DirPath, 
[string]$FolderName,
[string]$Year
) 

Create-Directory($Dirpath)

Push-Location
Set-Location $Dirpath


for ($i=1; $i -le 12; $i++) {
    $NameOfFile=$FolderName+"-"+$year+"-"+$i.ToString("00")
    $DestinationFile = $FolderName+"-"+$year+"-"+$i.ToString("00")+".PDF"
    Create-File($DestinationFile)
    }
    Pop-Location
}

# example: Create-monthly-files -dirpath $IT -FolderName $folderName -Year $YEAR
#---
function Create-Directory($dirPath) {

  if (!(Test-Path $dirPath)) {

    New-Item -ItemType directory -Path $dirPath.toupper()

  }
  } # function Create-Dir

function Create-File($fileName)
 {

  if (!(Test-Path $filename))
    {

    New-Item -ItemType file -Path $fileName.toupper()
    }
  } # function Create-File
#------------------
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "CSV (*.csv)| *.csv"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}
function ConvertFrom-ExcelToSQLInsert {
    param(
        [Parameter(Mandatory = $true)]
        $TableName,
        [Alias("FullName")]
        [Parameter(ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true, Mandatory = $true)]
        [ValidateScript( { Test-Path $_ -PathType Leaf })]
        $Path,
        [Alias("Sheet")]
        $WorkSheetname = 1,
        [int]$HeaderRow = 1,
        [string[]]$Header,
        [switch]$NoHeader,
        [switch]$DataOnly
    )

    $null = $PSBoundParameters.Remove('TableName')
    $params = @{} + $PSBoundParameters

    ConvertFrom-ExcelData @params {
        param($propertyNames, $record)

        $ColumnNames = "'" + ($PropertyNames -join "', '") + "'"
        $values = foreach ($propertyName in $PropertyNames) { $record.$propertyName }
        $targetValues = "'" + ($values -join "', '") + "'"

        "INSERT INTO {0} ({1}) Values({2});" -f $TableName, $ColumnNames, $targetValues
    }
    # $data = Import-Excel @params    
    
    # $PropertyNames = $data[0].psobject.Properties |
    #     Where-Object {$_.membertype -match 'property'} |
    #     Select-Object -ExpandProperty name
    
    # $ColumnNames = "'" + ($PropertyNames -join "', '") + "'"

    # foreach ($record in $data) {
    #     $values = $(foreach ($propertyName in $PropertyNames) {
    #             $record.$propertyName
    #         })

    #     $targetValues = "'" + ($values -join "', '") + "'"

    #     "INSERT INTO {0} ({1}) Values({2});" -f $TableName, $ColumnNames, $targetValues
    # }
}
#Requires -Version 3
Function Import-CsvToSql {
<# 
	.SYNOPSIS
	Efficiently imports very large (and small) CSV files into SQL Server using only the .NET Framework and PowerShell.
	
	.DESCRIPTION
	Import-CsvToSql takes advantage of .NET's super fast SqlBulkCopy class to import CSV files into SQL Server at up to 90,000
	rows a second.
		
	The entire import is contained within a transaction, so if a failure occurs or the script is aborted, no changes will persist.
	
	If the table specified does not exist, it will be automatically created using best guessed data types. In addition, 
	the destination table can be truncated prior to import. 
	
	The Query parameter be used to import only data returned from a SQL Query executed against the CSV file(s). This function 
	supports a number of bulk copy options. Please see parameter list for details.
	
	.PARAMETER CSV
	Required. The location of the CSV file(s) to be imported. Multiple files are allowed, so long as they are formatted 
	similarly. If no CSV file is specified, a Dialog box will appear.

	.PARAMETER FirstRowColumns
	Optional. This parameter specifies whether the first row contains column names. If the first row does not contain column 
	names and -Query is specified, use field names "column1, column2, column3" and so on.
	
	.PARAMETER Delimiter
	Optional. If you do not pass a Delimiter, then a comma will be used. Valid Delimiters include: tab "`t", pipe "|", 
	semicolon ";", and space " ".

	.PARAMETER SqlServer
	Required. The destination SQL Server.
	
	.PARAMETER SqlCredential
	Connect to SQL Server using specified SQL Login credentials.
	
	.PARAMETER Database
	Required. The name of the database where the CSV will be imported into. This parameter is autopopulated using the 
	-SqlServer and -SqlCredential (optional) parameters. 

	.PARAMETER Table
	SQL table or view where CSV will be imported into. 
	
	If a table name is not specified, the table name will be automatically determined from filename, and a prompt will appear
	to confirm table name.
	
	If table does not currently exist, it will created.  SQL datatypes are determined from the first row of the CSV that 
	contains data (skips first row if -FirstRowColumns). Datatypes used are: bigint, numeric, datetime and varchar(MAX). 
	
	If the automatically generated table datatypes do not work for you, please create the table prior to import.

	.PARAMETER Truncate
	Truncate table prior to import.
	
	.PARAMETER Safe
	Optional. By default, Import-CsvToSql uses StreamReader for imports. StreamReader is super fast, but may not properly parse some files. 
	Safe uses OleDb to import the records, it's slower, but more predictable when it comes to parsing CSV files. A schema.ini is automatically
	generated for best results. If schema.ini currently exists in the directory, it will be moved to a temporary location, then moved back.
	
	OleDB also enables the script to use the -Query parameter, which enables you to import specific subsets of data within a CSV file. OleDB 
	imports at up to 21,000 rows/sec.
	
	.PARAMETER Turbo
	Optional. Cannot be used in conjunction with -Query.
	
	Remember the Turbo button? This one actually works. Turbo is mega fast, but may not handle some datatypes as well as other methods. 
	If your CSV file is rather vanilla and doesn't have a ton of NULLs, Turbo may work well for you.  Note: Turbo mode uses a Table Lock.
	
	StreamReader/Turbo imports at up to 90,000 rows/sec (well, 93,000 locally for a 19 column file so, really, the number may be over 
	100,000 rows/sec for tables with only a couple columns using optimized datatypes).
		
	.PARAMETER First
	Only import first X rows. Count starts at the top of the file, but skips the first row if FirstRowColumns was specifeid.
	
	Use -Query if you need advanced First (TOP) functionality.
	
	.PARAMETER Query
	Optional. Cannot be used in conjunction with -Turbo or -First. When Query is specified, the slower import method, OleDb,
	will be used.
	
	If you want to import just the results of a specific query from your CSV file, use this parameter.
	To make command line queries easy, this module will convert the word "csv" to the actual CSV formatted table name. 
	If the FirstRowColumns switch is not used, the query should use column1, column2, column3, etc

	Example: select column1, column2, column3 from csv where column2 > 5
	Example: select distinct artist from csv
	Example: select top 100 artist, album from csv where category = 'Folk'

	See EXAMPLES for more example syntax.
	
	.PARAMETER TableLock
	SqlBulkCopy option. Per Microsoft "Obtain a bulk update lock for the duration of the bulk copy operation. When not 
	specified, row locks are used." TableLock is automatically used when Turbo is specified.
			
	.PARAMETER CheckConstraints
	SqlBulkCopy option. Per Microsoft "Check constraints while data is being inserted. By default, constraints are not checked."
	
	.PARAMETER FireTriggers
	SqlBulkCopy option. Per Microsoft "When specified, cause the server to fire the insert triggers for the rows being inserted 
	into the database."
	
	.PARAMETER KeepIdentity
	SqlBulkCopy option. Per Microsoft "Preserve source identity values. When not specified, identity values are assigned by 
	the destination."
	
	.PARAMETER KeepNulls
	SqlBulkCopy option. Per Microsoft "Preserve null values in the destination table regardless of the settings for default 
	values. When not specified, null values are replaced by default values where applicable."

	.PARAMETER shellswitch
	Internal parameter.
	
	.PARAMETER SqlCredentialPath
	Internal parameter.
	
	.NOTES
	Author: Chrissy LeMaire
	Requires: PowerShell 3.0
	Version: 0.8.2
	DateUpdated: 2015-Sept-6

	.LINK 
	https://gallery.technet.microsoft.com/scriptcenter/Import-Large-CSVs-into-SQL-fa339046

	.EXAMPLE   
	Import-CsvToSql -Csv C:\temp\housing.csv -SqlServer sql001 -Database markets
	
	Imports the entire *comma delimited* housing.csv to the SQL "markets" database on a SQL Server named sql001.
	Since a table name was not specified, the table name is automatically determined from filename as "housing"
	and a prompt will appear to confirm table name.
	
	The first row is not skipped, as it does not contain column names.
	
	.EXAMPLE   
	Import-CsvToSql -Csv .\housing.csv -SqlServer sql001 -Database markets -Table housing -First 100000 -Safe -Delimiter "`t" -FirstRowColumns
	
	Imports the first 100,000 rows of the tab delimited housing.csv file to the "housing" table in the "markets" database on a SQL Server 
	named sql001. Since Safe was specified, the OleDB method will be used for the bulk import. It's assumed Safe was used because 
	the first attempt without -Safe resulted in an import error. The first row is skipped, as it contains column names.

	.EXAMPLE
	Import-CsvToSql -csv C:\temp\huge.txt -sqlserver sqlcluster -Database locations -Table latitudes -Delimiter "|" -Turbo
	
	Imports all records from the pipe delimited huge.txt file using the fastest method possible into the latitudes table within the 
	locations database. Obtains a table lock for the duration of the bulk copy operation. This specific command has been used 
	to import over 10.5 million rows in 2 minutes.
	
	.EXAMPLE   
	Import-CsvToSql -Csv C:\temp\housing.csv, .\housing2.csv -SqlServer sql001 -Database markets -Table `
	housing -Delimiter "`t" -query "select top 100000 column1, column3 from csv" -Truncate
	
	Truncates the "housing" table, then imports columns 1 and 3 of the first 100000 rows of the tab-delimited 
	housing.csv in the C:\temp directory, and housing2.csv in the current directory. Since the query is executed against
	both files, a total of 200,000 rows will be imported.

	.EXAMPLE   
	Import-CsvToSql -Csv C:\temp\housing.csv -SqlServer sql001 -Database markets -Table housing -query `
	"select address, zip from csv where state = 'Louisiana'" -FirstRowColumns -Truncate -FireTriggers
	
	Uses the first line to determine CSV column names. Truncates the "housing" table on the SQL Server, 
	then imports the address and zip columns from all records in the housing.csv where the state equals Louisiana.
	
	Triggers are fired for all rows. Note that this does slightly slow down the import.

	#>
	[CmdletBinding(DefaultParameterSetName="Default")]
	Param(
		[string[]]$Csv,
		[Parameter(Mandatory=$true)]
		[string]$SqlServer,
		[object]$SqlCredential,
		[string]$Table,
		[switch]$Truncate,
		[string]$Delimiter = ",",
		[switch]$FirstRowColumns,
		[parameter(ParameterSetName="reader")]
		[switch]$Turbo,
		[parameter(ParameterSetName="ole")]
		[switch]$Safe,
		[int]$First = 0,
		[parameter(ParameterSetName="ole")]
		[string]$Query = "select * from csv",
		[int]$BatchSize = 50000,
		[int]$NotifyAfter,
		[switch]$TableLock,
		[switch]$CheckConstraints,
		[switch]$FireTriggers,
		[switch]$KeepIdentity,
		[switch]$KeepNulls,
		[switch]$shellswitch,
		[string]$SqlCredentialPath
		)
		
DynamicParam  {

	if ($sqlserver.length -gt 0) {
		# Auto populate database list from specified sqlserver
		$paramconn = New-Object System.Data.SqlClient.SqlConnection

		if ($SqlCredentialPath.length -gt 0) {
			$SqlCredential = Import-CliXml $SqlCredentialPath
		}
		
		if ($SqlCredential.count -eq 0 -or $SqlCredential -eq $null) {
			$paramconn.ConnectionString = "Data Source=$sqlserver;Integrated Security=True;"
		} else {
			$paramconn.ConnectionString = "Data Source=$sqlserver;User Id=$($SqlCredential.UserName); Password=$($SqlCredential.GetNetworkCredential().Password);"
		}
		
		try {
			$paramconn.Open()
			$sql = "select name from master.dbo.sysdatabases"
			$paramcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $paramconn, $null)	
			$paramdt = New-Object System.Data.DataTable
			$paramdt.Load($paramcmd.ExecuteReader())		
			$databaselist = $paramdt.rows.name
			$null = $paramcmd.Dispose()
			$null = $paramconn.Close()
			$null = $paramconn.Dispose()
		} catch { 
			# But if the routine fails, at least let them specify a database manually
			$databaselist = ""
		}

		# Reusable parameter setup
		$newparams = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
		$attributes = New-Object System.Management.Automation.ParameterAttribute
		$attributes.Mandatory = $false
		
		# Database list parameter setup
		$dbattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
		$dbattributes.Add($attributes)
		# If a list of databases were returned, populate the parameter set
		if ($databaselist.length -gt 0) { 
			$dbvalidationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $databaselist
			$dbattributes.Add($dbvalidationset) 
		}
		
		$Database = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Database", [String], $dbattributes)
		$newparams.Add("Database", $Database)
		return $newparams
	}
}
	
	Begin {
		Function Parse-OleQuery {
		<#
			.SYNOPSIS
			Tests to ensure query is valid. This will be used for the GUI.

			.EXAMPLE
			Parse-OleQuery -Csv sqlservera -Query $query -FirstRowColumns $FirstRowColumns -delimiter $delimiter
			
			.OUTPUT
			
					
		 #>
			param(
				[string]$Provider,
				[Parameter(Mandatory=$true)]
				[string[]]$csv,
				[Parameter(Mandatory=$true)]
				[string]$Query,
				[Parameter(Mandatory=$true)]
				[bool]$FirstRowColumns,
				[Parameter(Mandatory=$true)]
				[string]$delimiter
				
			)
		
			if ($query.ToLower() -notmatch "\bcsv\b") {
				return "SQL statement must contain the word 'csv'."
			}
						
			try {
				$datasource = Split-Path $csv[0]
				$tablename = (Split-Path $csv[0] -leaf).Replace(".","#")
				 switch ($FirstRowColumns) {
					$true { $FirstRowColumns = "Yes" }
					$false { $FirstRowColumns = "No" }
				}
				if ($provider -ne $null) {
					$connstring = "Provider=$provider;Data Source=$datasource;Extended Properties='text';"
				} else {
					$connstring = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$datasource;Extended Properties='text';"
				}

				$conn = New-Object System.Data.OleDb.OleDbconnection $connstring
				$conn.Open()
				$sql = $Query -replace "\bcsv\b"," [$tablename]"
				$cmd = New-Object System.Data.OleDB.OleDBCommand 
				$cmd.Connection = $conn
				$cmd.CommandText = $sql
				$null = $cmd.ExecuteReader()
				$cmd.Dispose()
				$conn.Dispose()
				return $true
			} catch { return $false }	
		}
		
		Function Test-SqlConnection {
		<#
			.SYNOPSIS
			Uses System.Data.SqlClient to gather list of user databases.

			.EXAMPLE
			$SqlCredential = Get-Credential
			Get-SqlDatabases -SqlServer sqlservera -SqlCredential $SqlCredential
			
			.OUTPUT
			Array of user databases
					
		 #>
			param(
				[Parameter(Mandatory=$true)]
				[string]$SqlServer,
				[object]$SqlCredential
			)
			$testconn = New-Object System.Data.SqlClient.SqlConnection
			if ($SqlCredential.count -eq 0) {
				$testconn.ConnectionString = "Data Source=$sqlserver;Integrated Security=True;Connection Timeout=3"
			} else {
				$testconn.ConnectionString = "Data Source=$sqlserver;User Id=$($SqlCredential.UserName); Password=$($SqlCredential.GetNetworkCredential().Password);Connection Timeout=3"
			}
			try {
				$testconn.Open()
				$testconn.Close()
				$testconn.Dispose()
				return $true
			} catch {
				$message = $_.Exception.Message.ToString()
				Write-Verbose $message
				if ($message -match "A network") { $message = "Can't connect to $sqlserver." }
				elseif ($message -match "Login failed for user") { $message = "Login failed for $username." }
				return $message
			}
		}
		
		Function Get-SqlDatabases {
		<#
			.SYNOPSIS
			Uses System.Data.SqlClient to gather list of user databases.

			.EXAMPLE
			$SqlCredential = Get-Credential
			Get-SqlDatabases -SqlServer sqlservera -SqlCredential $SqlCredential
			
			.OUTPUT
			Array of user databases
					
		 #>
			param(
				[Parameter(Mandatory=$true)]
				[string]$SqlServer,
				[object]$SqlCredential
			)
			$paramconn = New-Object System.Data.SqlClient.SqlConnection
			if ($SqlCredential.count -eq 0) {
				$paramconn.ConnectionString = "Data Source=$sqlserver;Integrated Security=True;Connection Timeout=3"
			} else {
				$paramconn.ConnectionString = "Data Source=$sqlserver;User Id=$($SqlCredential.UserName); Password=$($SqlCredential.GetNetworkCredential().Password);Connection Timeout=3"
			}
			try {
				$paramconn.Open()
				$sql = "select name from master.dbo.sysdatabases where dbid > 4 order by name"
				$paramcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $paramconn, $null)	
				$datatable = New-Object System.Data.DataTable
				[void]$datatable.Load($paramcmd.ExecuteReader())		
				$databaselist = $datatable.rows.name
				$null = $paramcmd.Dispose()
				$null = $paramconn.Close()
				$null = $paramconn.Dispose()
				return $databaselist
			} catch { throw "Cannot access $sqlserver" }
		}

		Function Get-SqlTables {
		<#
			.SYNOPSIS
			Uses System.Data.SqlClient to gather list of user databases.

			.EXAMPLE
			$SqlCredential = Get-Credential
			Get-SqlTables -SqlServer sqlservera -Database mydb -SqlCredential $SqlCredential
			
			.OUTPUT
			Array of tables
					
		 #>
			param(
				[Parameter(Mandatory=$true)]
				[string]$SqlServer,
				[string]$Database,
				[object]$SqlCredential
			)
			$tableconn = New-Object System.Data.SqlClient.SqlConnection
			if ($SqlCredential.count -eq 0) {
				$tableconn.ConnectionString = "Data Source=$sqlserver;Integrated Security=True;Connection Timeout=3"
			} else {
				$username = ($SqlCredential.UserName).TrimStart("\")
				$tableconn.ConnectionString = "Data Source=$sqlserver;User Id=$username; Password=$($SqlCredential.GetNetworkCredential().Password);Connection Timeout=3"
			}
			try {
				$tableconn.Open()
				$sql = "select name from $database.sys.tables order by name"
				$tablecmd = New-Object System.Data.SqlClient.SqlCommand($sql, $tableconn, $null)	
				$datatable = New-Object System.Data.DataTable
				[void]$datatable.Load($tablecmd.ExecuteReader())		
				$tablelist = $datatable.rows.name
				$null = $tablecmd.Dispose()
				$null = $tableconn.Close()
				$null = $tableconn.Dispose()
				return $tablelist
			} catch { return }
		}

		Function Get-Columns {
			<#
				.SYNOPSIS
				TextFieldParser will be used instead of an OleDbConnection.
				This is because the OleDbConnection driver may not exist on x64.

				.EXAMPLE
				$columns = Get-Columns -Csv .\myfile.csv -Delimiter "," -FirstRowColumns $true
				
				.OUTPUT
				Array of column names
						
			 #>
		 
			param(
			[Parameter(Mandatory=$true)]
			[string[]]$Csv,
			[Parameter(Mandatory=$true)]
			[string]$Delimiter,
			[Parameter(Mandatory=$true)]
			[bool]$FirstRowColumns
			)

			$columnparser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($csv[0])
			$columnparser.TextFieldType = "Delimited"
			$columnparser.SetDelimiters($Delimiter)
			$rawcolumns = $columnparser.ReadFields()
			
			if ($FirstRowColumns -eq $true) { 
				$columns = ($rawcolumns | ForEach-Object { $_ -Replace '"' } |  Select-Object -Property @{Name="name"; Expression = {"[$_]"}}).name
			} else {
				$columns  = @()
				foreach ($number in 1..$rawcolumns.count ) { $columns += "[column$number]" }  
			}
	
			$columnparser.Close()
			$columnparser.Dispose()
			return $columns
		}
		
		Function Get-ColumnText {
			<#
				.SYNOPSIS
				Returns an array of data, which can later be parsed for potential datatypes.

				.EXAMPLE
				$columns = Get-Columns -Csv .\myfile.csv -Delimiter ","
				
				.OUTPUT
				Array of column data
						
			 #>
			param(
			[Parameter(Mandatory=$true)]
			[string[]]$Csv,
			[Parameter(Mandatory=$true)]
			[string]$Delimiter
			)
			$columnparser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($csv[0])
			$columnparser.TextFieldType = "Delimited"
			$columnparser.SetDelimiters($Delimiter)
			$line = $columnparser.ReadLine()
			# Skip a line, in case first line are column names
			$line = $columnparser.ReadLine()
			$datatext = $columnparser.ReadFields()
			$columnparser.Close()
			$columnparser.Dispose()
			return $datatext
		}
		
		Function Write-Schemaini {
			<#
				.SYNOPSIS
				Unfortunately, passing delimiter within the OleDBConnection connection string is unreliable, so we'll use schema.ini instead
				The default delimiter in Windows changes depending on country, so we'll do this for every delimiter, even commas.
				
				Get OLE datatypes based on best guess of column data within the -Columns parameter.
				
				Sometimes SQL will accept a datetime that OLE won't, so Text will be used for datetime.

				.EXAMPLE
				$columns = Get-Columns -Csv C:\temp\myfile.csv -Delimiter ","
				$movedschemainis = Write-Schemaini -Csv  C:\temp\myfile.csv -Columns $columns -ColumnText $columntext -Delimiter "," -FirstRowColumns $true
				
				.OUTPUT
				Creates new schema files, that look something like this:
				[housingdata.csv]
				Format=Delimited(,)
				ColNameHeader=True
				Col1="House ID" Long
				Col2="Description" Memo
				Col3="Price" Double
				
				Returns an array of existing schema files that have been moved, if any.
						
			 #>
			param(
			[Parameter(Mandatory=$true)]
			[string[]]$Csv,
			[Parameter(Mandatory=$true)]
			[string[]]$Columns,
			[string[]]$ColumnText,
			[Parameter(Mandatory=$true)]
			[string]$Delimiter,
			[Parameter(Mandatory=$true)]
			[bool]$FirstRowColumns
			)
			
				$movedschemainis = @{}
				foreach ($file in $csv) {
					$directory = Split-Path $file
					$schemaexists = Test-Path "$directory\schema.ini"
					if ($schemaexists -eq $true) {
						$newschemaname = "$env:TEMP\$(Split-Path $file -leaf)-schema.ini"
						$movedschemainis.Add($newschemaname,"$directory\schema.ini")
						Move-Item "$directory\schema.ini" $newschemaname -Force
					}
					
					$filename = Split-Path $file -leaf; $directory = Split-Path $file
					Add-Content -Path "$directory\schema.ini" -Value "[$filename]"
					Add-Content -Path "$directory\schema.ini" -Value "Format=Delimited($Delimiter)"
					Add-Content -Path "$directory\schema.ini" -Value "ColNameHeader=$FirstRowColumns"
					
					$index = 0 
					$olecolumns = ($columns | ForEach-Object { $_ -Replace "\[|\]", '"' })
					
					foreach ($datatype in $columntext) {
						$olecolumnname = $olecolumns[$index]
						$index++
						
						try { [System.Guid]::Parse($datatype) | Out-Null;  $isguid = $true } catch { $isguid = $false } 
						
						if ($isguid -eq $true) { $oledatatype = "Text" }
						elseif ([int64]::TryParse($datatype,[ref]0) -eq $true) { $oledatatype = "Long" }
						elseif ([double]::TryParse($datatype,[ref]0) -eq $true) { $oledatatype = "Double" }
						elseif ([datetime]::TryParse($datatype,[ref]0) -eq $true) { $oledatatype = "Text" }
						else { $oledatatype = "Memo" }

						Add-Content -Path "$directory\schema.ini" -Value "Col$($index)`=$olecolumnname $oledatatype"
					}
				}
				return $movedschemainis
			}
			
		Function New-SqlTable {
			<#
				.SYNOPSIS
				Creates new Table using existing SqlCommand.
				
				SQL datatypes based on best guess of column data within the -ColumnText parameter.
				Columns paramter determine column names.

				.EXAMPLE
				New-SqlTable -Csv $Csv -Delimiter $Delimiter -Columns $columns -ColumnText $columntext -SqlConn $sqlconn -Transaction $transaction
				
				.OUTPUT
				Creates new table
			 #>
			 
			param(
			[Parameter(Mandatory=$true)]
			[string[]]$Csv,
			[Parameter(Mandatory=$true)]
			[string]$Delimiter,
			[string[]]$Columns,
			[string[]]$ColumnText,
			[System.Data.SqlClient.SqlConnection]$sqlconn,
			[System.Data.SqlClient.SqlTransaction]$transaction
			)
				# Get SQL datatypes by best guess on first data row
				$sqldatatypes = @(); $index = 0 
				
				foreach ($column in $columntext) {
					$sqlcolumnname = $Columns[$index]
					$index++
					
					# bigint, float, and datetime are more accurate, but it didn't work
					# as often as it should have, so we'll just go for a smaller datatype
					if ([int64]::TryParse($column,[ref]0) -eq $true) { $sqldatatype = "varchar(255)" }
					elseif ([double]::TryParse($column,[ref]0) -eq $true) { $sqldatatype = "varchar(255)"  }
					elseif ([datetime]::TryParse($column,[ref]0) -eq $true) { $sqldatatype = "varchar(255)"  }
					else { $sqldatatype = "varchar(MAX)" }
					
					$sqldatatypes += "$sqlcolumnname $sqldatatype"
				}
				
			$sql = "BEGIN CREATE TABLE [$table] ($($sqldatatypes -join ' NULL,')) END"
			$sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
			try { $null = $sqlcmd.ExecuteNonQuery()} catch { 
				$errormessage = $_.Exception.Message.ToString()
				throw "Failed to execute $sql. `nDid you specify the proper delimiter? `n$errormessage" 
			}
			
			Write-Output "[*] Successfully created table $table with the following column definitions:`n $($sqldatatypes -join "`n ")"
			# Write-Warning "All columns are created using a best guess, and use their maximum datatype."
			Write-Warning "This is inefficient but allows the script to import without issues."
			Write-Warning "Consider creating the table first using best practices if the data will be used in production."
	}
	

		if ($shellswitch -eq $false) { Write-Output "[*] Started at $(Get-Date)" }
		
		# Load the basics
		[void][Reflection.Assembly]::LoadWithPartialName("System.Data")
		[void][Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic")
		[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
		
		# Getting the total rows copied is a challenge. Use SqlBulkCopyExtension.
		# http://stackoverflow.com/questions/1188384/sqlbulkcopy-row-count-when-complete
		
		$source = 'namespace System.Data.SqlClient
			{    
				using Reflection;

				public static class SqlBulkCopyExtension
				{
					const String _rowsCopiedFieldName = "_rowsCopied";
					static FieldInfo _rowsCopiedField = null;

					public static int RowsCopiedCount(this SqlBulkCopy bulkCopy)
					{
						if (_rowsCopiedField == null) _rowsCopiedField = typeof(SqlBulkCopy).GetField(_rowsCopiedFieldName, BindingFlags.NonPublic | BindingFlags.GetField | BindingFlags.Instance);            
						return (int)_rowsCopiedField.GetValue(bulkCopy);
					}
				}
			}
		'
			Add-Type -ReferencedAssemblies 'System.Data.dll' -TypeDefinition $source -ErrorAction SilentlyContinue
	}

	Process {
		# Supafast turbo mode requires a table lock, or it's just regular fast
		if ($turbo -eq $true) { $tablelock = $true }
		
		# The query parameter requires OleDB which is invoked by the "safe" variable
		# Actually, a select could be performed on the datatable used in StreamReader, too.
		# Maybe that will be done later.
		if ($query -ne "select * from csv") { $safe = $true }
		
		if ($first -gt 0 -and $query -ne "select * from csv") { 
			throw "Cannot use both -Query and -First. If a query is necessary, use TOP $first within your SQL statement."
		}
		
		# In order to support -First in both Streamreader, and OleDb imports, the query must be modified slightly.
		if ($first -gt 0) { $query = "select top $first * from csv" }
		
		# If shell switch occured, and encrypted SQL credentials were written to disk, create $SqlCredential 
		if ($SqlCredentialPath.length -gt 0) {
			$SqlCredential = Import-CliXml $SqlCredentialPath
		}
		
		# Get Database string from RuntimeDefinedParameter if required
		if ($database -isnot [string]) { $database = $PSBoundParameters.Database }
		if ($database.length -eq 0) { throw "You must specify a database." }
		
		# Check to ensure a Windows account wasn't used as a SQL Credential
		if ($SqlCredential.count -gt 0 -and $SqlCredential.UserName -like "*\*") { throw "Only SQL Logins can be used as a SqlCredential." }
				
		# If no CSV was specified, prompt the user to select one.
		if ($csv.length -eq 0) {
				$fd = New-Object System.Windows.Forms.OpenFileDialog
				$fd.InitialDirectory =  [environment]::GetFolderPath("MyDocuments")
				$fd.Filter = "CSV Files (*.csv;*.tsv;*.txt)|*.csv;*.tsv;*.txt"
				$fd.Title = "Select one or more CSV files"
				$fd.MultiSelect = $true
				$null = $fd.showdialog()
				$csv = $fd.filenames
				if ($csv.length -eq 0) { throw "No CSV file selected." }
		} else {
			foreach ($file in $csv) {
				$exists = Test-Path $file
				if ($exists -eq $false) { throw "$file does not exist" }
			}
		}

		# Resolve the full path of each CSV
		$resolvedcsv = @()
		foreach ($file in $csv) { $resolvedcsv += (Resolve-Path $file).Path }
		$csv = $resolvedcsv
		
		# UniqueIdentifier kills OLE DB / SqlBulkCopy imports. Check to see if destination table contains this datatype. 
		if ($safe -eq $true) {
			$sqlcheckconn = New-Object System.Data.SqlClient.SqlConnection
			if ($SqlCredential.count -eq 0 -or $SqlCredential -eq $null) {
				$sqlcheckconn.ConnectionString = "Data Source=$sqlserver;Integrated Security=True;Connection Timeout=3; Initial Catalog=master"
			} else {
				$username = ($SqlCredential.UserName).TrimStart("\")
				$sqlcheckconn.ConnectionString = "Data Source=$sqlserver;User Id=$username; Password=$($SqlCredential.GetNetworkCredential().Password);Connection Timeout=3; Initial Catalog=master"
			}
			
			try { $sqlcheckconn.Open() } catch { throw $_.Exception }
			
			# Ensure database exists
			$sql = "select count(*) from master.dbo.sysdatabases where name = '$database'"
			$sqlcheckcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlcheckconn)	
			$dbexists = $sqlcheckcmd.ExecuteScalar()
			if ($dbexists -eq $false) { throw "Database does not exist on $sqlserver" }
			
			# Change database after the fact, because if db doesn't exist, the login would fail.	
			$sqlcheckconn.ChangeDatabase($database)
			
			$sql = "SELECT t.name as datatype FROM sys.columns c
					JOIN sys.types t ON t.system_type_id = c.system_type_id 
					WHERE c.object_id = object_id('$table') and t.name != 'sysname'"
			$sqlcheckcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlcheckconn)
			$sqlcolumns = New-Object System.Data.DataTable
			$sqlcolumns.load($sqlcheckcmd.ExecuteReader("CloseConnection"))
			$sqlcheckconn.Dispose()
			if ($sqlcolumns.datatype -contains "UniqueIdentifier") { 
				throw "UniqueIdentifier not supported by OleDB/SqlBulkCopy. Query and Safe cannot be supported."
			}
		}

		if ($safe -eq $true) {
			# Check for drivers. First, ACE (Access) if file is smaller than 2GB, then JET
			# ACE doesn't handle files larger than 2gb. What gives?
			foreach ($file in $csv) {
				$filesize = (Get-ChildItem $file).Length / 1GB
				if ($filesize -gt 1.99) { $jetonly = $true }
			}
			
			if ($jetonly -ne $true) { $provider = (New-Object System.Data.OleDb.OleDbEnumerator).GetElements() | Where-Object { $_.SOURCES_NAME -like "Microsoft.ACE.OLEDB.*" } } 
			
			if ($provider -eq $null) {
				$provider = (New-Object System.Data.OleDb.OleDbEnumerator).GetElements() | Where-Object { $_.SOURCES_NAME -like "Microsoft.Jet.OLEDB.*" }	
			}
			
			# If a suitable provider cannot be found (If x64 and Access hasn't been installed) 
			# switch to x86, because it natively supports JET
			if ($provider -ne $null) { 
				if ($provider -is [system.array]) { $provider = $provider[$provider.GetUpperBound(0)].SOURCES_NAME } else {  $provider = $provider.SOURCES_NAME }
			}
			
			# If a provider doesn't exist, it is necessary to switch to x86 which natively supports JET.
			if ($provider -eq $null) {
				# While Install-Module takes care of installing modules to x86 and x64, Import-Module doesn't.
				# Because of this, the Module must be exported, written to file, and imported in the x86 shell.
				$definition = (Get-Command Import-CsvToSql).Definition
				$function = "Function Import-CsvToSql { $definition }"
				Set-Content "$env:TEMP\Import-CsvToSql.psm1" $function
				
				# Encode the SQL string, since some characters may mess up after being passed a second time.
				$bytes  = [System.Text.Encoding]::UTF8.GetBytes($query)
				$query = [System.Convert]::ToBase64String($bytes)
				
				# Put switches back into proper format
				$switches = @()
				$options = "TableLock","CheckConstraints","FireTriggers","KeepIdentity","KeepNulls","Default","Truncate","FirstRowColumns","Safe"
				foreach ($option in $options) {
					$optionValue = Get-Variable $option -ValueOnly -ErrorAction SilentlyContinue
					if ($optionValue -eq $true) { $switches += "-$option" }
				}
				
				# Perform the actual switch, which removes any registered Import-CsvToSql modules
				# Then imports, and finally re-executes the command. 
				$csv = $csv -join ",";  $switches = $switches -join " "
				if ($SqlCredential.count -gt 0) {
					$SqlCredentialPath =  "$env:TEMP\sqlcredential.xml" 
					Export-CliXml -InputObject $SqlCredential $SqlCredentialPath
				}
				$command = "Import-CsvToSql -Csv $csv -SqlServer '$sqlserver'-Database '$database' -Table '$table' -Delimiter '$Delimiter' -First $First -Query '$query' -Batchsize $BatchSize -NotifyAfter $NotifyAfter $switches -shellswitch" 
				
				if ($SqlCredentialPath.length -gt 0) { $command += " -SqlCredentialPath $SqlCredentialPath"}
				Write-Verbose "Switching to x86 shell, then switching back." 
				&"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" "Set-ExecutionPolicy Bypass -Scope CurrentUser;Remove-Module Import-CsvToSql -ErrorAction SilentlyContinue;Import-Module $env:TEMP\Import-CsvToSql.psm1;$command"
				return
			}
		}
	
		# Do the first few lines contain the specified delimiter?
		foreach ($file in $csv) {
			try { $firstfewlines = Get-Content $file -First 3 -ErrorAction Stop } catch { throw "$file is in use." }
			foreach ($line in $firstfewlines) {
				if (($line -match $delimiter) -eq $false) {  throw "Delimiter $delimiter not found in first row of $file." }
			}
		}
		
		# If more than one csv specified, check to ensure number of columns match
		if ($csv -is [system.array]){ 
			$numberofcolumns = ((Get-Content $csv[0] -First 1 -ErrorAction Stop) -Split $delimiter).Count
			
			foreach ($file in $csv) {
				$firstline = Get-Content $file -First 1 -ErrorAction Stop
				$newnumcolumns = ($firstline -Split $Delimiter).Count
				if ($newnumcolumns -ne $numberofcolumns) { throw "Multiple csv file mismatch. Do both use the same delimiter and have the same number of columns?" }
			}
		}
		
		# Automatically generate Table name if not specified, then prompt user to confirm
		if ($table.length -eq 0) { 
			$table = [IO.Path]::GetFileNameWithoutExtension($csv[0])
			$title =  "Table name not specified."
			$message = "Would you like to use the automatically generated name: $table"
			$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Uses table name $table for import."
			$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Allows you to specify an alternative table name."
			$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
			$result = $host.ui.PromptForChoice($title, $message, $options, 0) 
			if ($result -eq 1) {
				do {$table = Read-Host "Please enter a table name"} while ($table.Length -eq 0)
			}
		}
		
		# If the shell has switched, decode the $query string.
		if ($shellswitch -eq $true) {
			$bytes  = [System.Convert]::FromBase64String($Query)
			$query = [System.Text.Encoding]::UTF8.GetString($bytes)
			$csv = $csv -Split ","
		}
		
		# Create columns based on first data row of first csv.
			Write-Output "[*] Calculating column names and datatypes"
			$columns = Get-Columns -Csv $Csv -Delimiter $Delimiter -FirstRowColumns $FirstRowColumns
			if ($columns.count -gt 255 -and $safe -eq $true) { 
					throw "CSV must contain fewer than 256 columns."
			}
			
			$columntext = Get-ColumnText -Csv $Csv -Delimiter $Delimiter
			
		# OLEDB method requires extra checks
		if ($safe -eq $true)	{	
			# Advanced SQL queries may not work (SqlBulkCopy likes a 1 to 1 mapping), so warn the user.
			if ($Query -match "GROUP BY" -or $Query -match "COUNT") { Write-Warning "Script doesn't really support the specified query. This probably won't work, but will be attempted anyway." }
	
			# Check for proper SQL syntax, which for the purposes of this module must include the word "table"
			if ($query.ToLower() -notmatch "\bcsv\b") {
				throw "SQL statement must contain the word 'csv'. Please see this module's documentation for more details."
			}

			# In order to ensure consistent results, a schema.ini file must be created.
			# If a schema.ini already exists, it will be moved to TEMP temporarily.		
			Write-Verbose "Creating schema.ini"
			$movedschemainis = Write-Schemaini -Csv $Csv -Columns $columns -Delimiter "$Delimiter" -FirstRowColumns $FirstRowColumns -ColumnText $columntext
		}
		
		# Display SQL Server Login info
		if ($sqlcredential.count -gt 0) { $username = "SQL login $($SqlCredential.UserName)" }
		else { $username = "Windows login $(whoami)" }
		# Open Connection to SQL Server
		Write-Output "[*] Logging into $sqlserver as $username"
		$sqlconn = New-Object System.Data.SqlClient.SqlConnection
		if ($SqlCredential.count -eq 0) {
			$sqlconn.ConnectionString = "Data Source=$sqlserver;Integrated Security=True;Connection Timeout=3; Initial Catalog=master"
		} else {
			$sqlconn.ConnectionString = "Data Source=$sqlserver;User Id=$($SqlCredential.UserName); Password=$($SqlCredential.GetNetworkCredential().Password);Connection Timeout=3; Initial Catalog=master"
		}
		
		try { $sqlconn.Open() } catch { throw "Could not open SQL Server connection. Is $sqlserver online?" }
		
		# Everything will be contained within 1 transaction, even creating a new table if required
		# and truncating the table, if specified.
		$transaction = $sqlconn.BeginTransaction()
		
		# Ensure database exists
		$sql = "select count(*) from master.dbo.sysdatabases where name = '$database'"
		$sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)	
		$dbexists = $sqlcmd.ExecuteScalar()
		if ($dbexists -eq $false) { throw "Database does not exist on $sqlserver" }
		Write-Output "[*] Database exists"
			
		$sqlconn.ChangeDatabase($database)
		
		# Ensure table exists
		$sql = "select count(*) from $database.sys.tables where name = '$table'"
		$sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
		$tablexists = $sqlcmd.ExecuteScalar()
		
		# Create the table if required. Remember, this will occur within a transaction, so if the script fails, the
		# new table will no longer exist.
		if ($tablexists -eq $false) {
			Write-Output "[*] Table does not exist"
			Write-Output "[*] Creating table"
			New-SqlTable -Csv $Csv -Delimiter $Delimiter -Columns $columns -ColumnText $columntext -SqlConn $sqlconn -Transaction $transaction
		} else { Write-Output "[*] Table exists" }
		
		# Truncate if specified. Remember, this will occur within a transaction, so if the script fails, the
		# truncate will not be committed.
		if ($truncate -eq $true) {
			Write-Output "[*] Truncating table"
			$sql = "TRUNCATE TABLE [$table]"
			$sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
			try { $null = $sqlcmd.ExecuteNonQuery() } catch { Write-Warning "Could not truncate $table" }
		}
		
		# Get columns for column mapping
		if ($columnMappings -eq $null) {
			$olecolumns = ($columns | ForEach-Object { $_ -Replace "\[|\]" })
			$sql = "select name from sys.columns where object_id = object_id('$table') order by column_id"
			$sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
			$sqlcolumns = New-Object System.Data.DataTable
			$sqlcolumns.Load($sqlcmd.ExecuteReader())
		}
		
		# Time to import!
		$elapsed = [System.Diagnostics.Stopwatch]::StartNew() 
		
		# Process each CSV file specified
		foreach ($file in $csv) {
			
			# Dynamically set NotifyAfter if it wasn't specified
			if ($notifyAfter -eq 0) {
				if ($resultcount -is [int]) { $notifyafter = $resultcount/10 }
				else { $notifyafter = 50000 }
			}
		
			# Setup bulk copy
			Write-Output "[*] Starting bulk copy for $(Split-Path $file -Leaf)"
			
			# Setup bulk copy options
			$bulkCopyOptions = @()
			$options = "TableLock","CheckConstraints","FireTriggers","KeepIdentity","KeepNulls","Default","Truncate"
			foreach ($option in $options) {
				$optionValue = Get-Variable $option -ValueOnly -ErrorAction SilentlyContinue
				if ($optionValue -eq $true) { $bulkCopyOptions += "$option" }
			}
			$bulkCopyOptions = $bulkCopyOptions -join " & "
			
			# Create SqlBulkCopy using default options, or options specified in command line.
			if ($bulkCopyOptions.count -gt 1) { $bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($oleconnstring, $bulkCopyOptions, $transaction) }
			else { $bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($sqlconn,"Default",$transaction) }
			
			$bulkcopy.DestinationTableName = "[$table]"
			$bulkcopy.bulkcopyTimeout = 0 
			$bulkCopy.BatchSize = $BatchSize
			$bulkCopy.NotifyAfter = $NotifyAfter
		
			if ($safe -eq $true) {
				# Setup bulkcopy mappings
				for ($columnid = 0; $columnid -lt $sqlcolumns.rows.count;  $columnid++) {
					$null = $bulkCopy.ColumnMappings.Add($olecolumns[$columnid], $sqlcolumns.rows[$columnid].ItemArray[0])
				}
				
				# Setup the connection string. Data Source is the directory that contains the csv.
				# The file name is also the table name, but with a "#" instead of a "."
				$datasource = Split-Path $file
				$tablename = (Split-Path $file -leaf).Replace(".","#")
				$oleconnstring = "Provider=$provider;Data Source=$datasource;Extended Properties='text';"
				
				# To make command line queries easier, let the user just specify "csv" instead of the
				# OleDbconnection formatted name (file.csv -> file#csv)
				$sql = $Query -replace "\bcsv\b"," [$tablename]"
				
				# Setup the OleDbconnection
				$oleconn = New-Object System.Data.OleDb.OleDbconnection
				$oleconn.ConnectionString = $oleconnstring
				
				# Setup the OleDBCommand
				$olecmd = New-Object System.Data.OleDB.OleDBCommand
				$olecmd.Connection = $oleconn
				$olecmd.CommandText = $sql
								
				try { $oleconn.Open() } catch { throw "Could not open OLEDB connection." }
				
				# Attempt to get the number of results so that a nice progress bar can be displayed.
				# This takes extra time, and files over 100MB take too long, so just skip them.
				if ($sql -match "GROUP BY") { "Query contains GROUP BY clause. Skipping result count." }
				else { Write-Output "[*] Determining total rows to be copied. This may take a few seconds." }
				
				if ($sql -match "\bselect top\b")  {
					try {
						$split = $sql -split "\bselect top \b"
						$resultcount = [int]($split[1].Trim().Split()[0])
						Write-Output "[*] Attempting to fetch $resultcount rows"
					} catch {  Write-Warning "Couldn't determine total rows to be copied." }
				} elseif ($sql -notmatch "GROUP BY") {
					$filesize = (Get-ChildItem $file).Length / 1MB
					if ($filesize -lt 100) {
						try {
							$split = $sql -split "\bfrom\b"
							$sqlcount = "select count(*) from $($split[1])"
							# Setup the OleDBCommand
							$olecmd = New-Object System.Data.OleDB.OleDBCommand
							$olecmd.Connection = $oleconn
							$olecmd.CommandText = $sqlcount
							$resultcount = [int]($olecmd.ExecuteScalar())
							Write-Output "[*] $resultcount rows will be copied"
						} catch { Write-Warning "Couldn't determine total rows to be copied" }
					} else { 
						Write-Output "[*] File is too large for efficient result count; progress bar will not be shown." 
					}
				}
			}	
			
			# Write to server :D
			try {
				if ($safe -ne $true) {
					# Check to ensure batchsize isn't equal to 0												
					if ($batchsize -eq 0) {
						write-warning "Invalid batchsize for this operation. Increasing to 50k"
						$batchsize = 50000
					}
										
					# Open the text file from disk 
					$reader = New-Object System.IO.StreamReader($file)
					if ($FirstRowColumns -eq $true) { $null = $reader.readLine() }
			
					# Create the reusable datatable. Columns will be genereated using info from SQL.
					$datatable = New-Object System.Data.DataTable 
					
					# Get table column info from SQL Server
					$sql = "SELECT c.name as colname, t.name as datatype, c.max_length, c.is_nullable FROM sys.columns c
							JOIN sys.types t ON t.system_type_id = c.system_type_id 
							WHERE c.object_id = object_id('$table') and t.name != 'sysname'	
							order by c.column_id"
					$sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn,$transaction)
					$sqlcolumns = New-Object System.Data.DataTable
					$sqlcolumns.load($sqlcmd.ExecuteReader())
					
					foreach ($sqlcolumn in $sqlcolumns) {
						$datacolumn = $datatable.Columns.Add()
						$colname = $sqlcolumn.colname
						$datacolumn.AllowDBNull = $sqlcolumn.is_nullable
						$datacolumn.ColumnName = $colname
						$datacolumn.DefaultValue = [DBnull]::Value
						$datacolumn.Datatype = [string]
						
						# The following data types can sometimes cause issues when they are null
						# so we will treat them differently
						$convert = "bigint", "DateTimeOffset", "UniqueIdentifier", "smalldatetime", "datetime"
						if ($convert -notcontains $sqlcolumn.datatype -and $turbo -ne $true){
							$null = $bulkCopy.ColumnMappings.Add($datacolumn.ColumnName, $sqlcolumn.colname)
						}
					}
					# For the columns that cause trouble, we'll add an additional column to the datatable 
					# which will perform a conversion.
					# Setting $column.datatype alone doesn't work as well as setting+converting.
					if ($turbo -ne $true) {
						$calcolumns = $sqlcolumns | Where-Object { $convert -contains $_.datatype }
						foreach ($calcolumn in $calcolumns) {
							$colname = $calcolumn.colname
							$null = $newcolumn = $datatable.Columns.Add()
							$null = $newcolumn.ColumnName = "computed$colname"
								switch ($calcolumn.datatype) {
									"bigint" { $netdatatype = "System.Int64"; $newcolumn.Datatype = [int64] }
									"DateTimeOffset" { $netdatatype = "System.DateTimeOffset"; $newcolumn.Datatype = [DateTimeOffset] }
									"UniqueIdentifier" { $netdatatype = "System.Guid"; $newcolumn.Datatype = [Guid] }
									{ "smalldatetime","datetime" -contains $_ } { $netdatatype = "System.DateTime"; $newcolumn.Datatype = [DateTime] }
								}
							# Use a data column expression to facilitate actual conversion
							$null = $newcolumn.Expression = "Convert($colname, $netdatatype)"
							$null = $bulkCopy.ColumnMappings.Add($newcolumn.ColumnName, $calcolumn.colname)
						}
					}
					
					# Check to see if file has quote identified data (ie. "first","second","third")
					$quoted = $false
					$checkline = Get-Content $file -Last 1
					$checkcolumns = $checkline.Split($delimiter)
					foreach ($checkcolumn in $checkcolumns) {
						if ($checkcolumn.StartsWith('"') -and $checkcolumn.EndsWith('"')) { $quoted = $true }
					}
					
					if ($quoted -eq $true) { 
						Write-Warning "The CSV file appears quote identified. This may take a little longer."
						# Thanks for this, Chris! http://www.schiffhauer.com/c-split-csv-values-with-a-regular-expression/
						$pattern = "((?<=`")[^`"]*(?=`"($delimiter|$)+)|(?<=$delimiter|^)[^$delimiter`"]*(?=$delimiter|$))"
					}
					if ($turbo -eq $true -and $first -eq 0) {
						while (($line = $reader.ReadLine()) -ne $null)  {
							$i++
							if ($quoted -eq $true) { 
								$null = $datatable.Rows.Add(($line.TrimStart('"').TrimEnd('"')) -Split "`"$delimiter`"")
							} else { $row = $datatable.Rows.Add($line.Split($delimiter)) }
							
							if (($i % $batchsize) -eq 0) {
								$bulkcopy.WriteToServer($datatable)
								Write-Output "[*] $i rows have been inserted in $([math]::Round($elapsed.Elapsed.TotalSeconds,2)) seconds"
								$datatable.Clear()
							}
						}
					} else {
						if ($turbo -eq $true -and $first -gt 0) { Write-Warning "Using -First makes turbo a smidge slower." }
						# Start import!
						while (($line = $reader.ReadLine()) -ne $null)  {
							$i++
							try {
								if ($quoted -eq $true) { 
									$row = $datatable.Rows.Add(($line.TrimStart('"').TrimEnd('"')) -Split $pattern) 
								} else { $row = $datatable.Rows.Add($line.Split($delimiter)) }
							} catch {
								$row = $datatable.NewRow() 
								try {
									$tempcolumn = $line.Split($delimiter)
									$colnum = 0
										foreach ($column in $tempcolumn) {
											if ($column.length -ne 0) {
												$row.item($colnum) = $column
											} else {
												$row.item($colnum) = [DBnull]::Value
											}
											$colnum++
										}
										$newrow = $datatable.Rows.Add($row)
									} catch {
										Write-Warning "The following line ($i) is causing issues:"
										Write-Output $line.Replace($delimiter,"`n")
										
										if ($quoted -eq $true) {
											Write-Warning "The import has failed, likely because the quoted data was a little too inconsistent. Try using the -Safe parameter."
										}
										
										Write-Verbose "Column datatypes:"
										foreach ($c in $datatable.columns) {
											Write-Verbose "$($c.columnname) = $($c.datatype)"
										}
										Write-Error $_.Exception.Message
										break
									}
							}
													
							if (($i % $batchsize) -eq 0 -or $i -eq $first) {
								$bulkcopy.WriteToServer($datatable)
								Write-Output "[*] $i rows have been inserted in $([math]::Round($elapsed.Elapsed.TotalSeconds,2)) seconds"
								$datatable.Clear()
								if ($i -eq $first) { break }
							}
						}
					}
					# Add in all the remaining rows since the last clear 
					if($datatable.Rows.Count -gt 0) { 
						$bulkcopy.WriteToServer($datatable) 
						$datatable.Clear() 
					}
				} else {
					# Add rowcount output
					$bulkCopy.Add_SqlRowscopied({
						$script:totalrows = $args[1].RowsCopied
						if ($resultcount -is [int]) {
							$percent = [int](($script:totalrows/$resultcount)*100)
							$timetaken = [math]::Round($elapsed.Elapsed.TotalSeconds,2)
							Write-Progress -id 1 -activity "Inserting $resultcount rows" -percentcomplete $percent `
							-status ([System.String]::Format("Progress: {0} rows ({1}%) in {2} seconds", $script:totalrows, $percent, $timetaken))
						} else {
							Write-Host "$($script:totalrows) rows copied in $([math]::Round($elapsed.Elapsed.TotalSeconds,2)) seconds" }
					})
					
						$bulkCopy.WriteToServer($olecmd.ExecuteReader("SequentialAccess"))
						if ($resultcount -is [int]) { Write-Progress -id 1 -activity "Inserting $resultcount rows" -status "Complete" -Completed }
					
				}
				$completed = $true
			} catch {
				# If possible, give more information about common errors.
				if ($resultcount -is [int]) { Write-Progress -id 1 -activity "Inserting $resultcount rows" -status "Failed" -Completed }
				$errormessage = $_.Exception.Message.ToString()
				$completed = $false
				if ($errormessage -like "*for one or more required parameters*") {
					
						Write-Error "Looks like your SQL syntax may be invalid. `nCheck the documentation for more information or start with a simple -Query 'select top 10 * from csv'"
						Write-Error "Valid CSV columns are $columns"
							
				} elseif ($errormessage -match "invalid column length") {
					
					# Get more information about malformed CSV input
					$pattern = @("\d+")
					$match = [regex]::matches($errormessage, @("\d+"))
					$index = [int]($match.groups[1].Value)-1
					$sql = "select name, max_length from sys.columns where object_id = object_id('$table') and column_id = $index"
					$sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn,$transaction)
					$datatable = New-Object System.Data.DataTable
					$datatable.load($sqlcmd.ExecuteReader())
					$column = $datatable.name
					$length = $datatable.max_length

					if ($safe -eq $true) {
						Write-Warning "Column $index ($column) contains data with a length greater than $length"
						Write-Warning "SqlBulkCopy makes it pretty much impossible to know which row caused the issue, but it's somewhere after row $($script:totalrows)."					
					}
				} elseif ($errormessage -match "does not allow DBNull" -or $errormessage -match "The given value of type") {
					
					if ($tablexists -eq $false) {
						Write-Error "Looks like the datatype prediction didn't work out. Please create the table manually with proper datatypes then rerun the import script."
					} else {
						$sql = "select name from sys.columns where object_id = object_id('$table') order by column_id"
						$sqlcmd = New-Object System.Data.SqlClient.SqlCommand($sql, $sqlconn, $transaction)
						$datatable = New-Object System.Data.DataTable
						$datatable.Load($sqlcmd.ExecuteReader())		
						$olecolumns = ($columns | ForEach-Object { $_ -Replace "\[|\]" }) -join ', '
						Write-Warning "Datatype mismatch."
						Write-Output "[*] This is sometimes caused by null handling in SqlBulkCopy or by quoted data."
						Write-Output "[*] This could also be because the data types don't match or the order of the columns within the CSV/SQL statement "
						Write-Output "[*] do not line up with the order of the table within the SQL Server.`n"
						Write-Output "[*] CSV order: $olecolumns`n"
						Write-Output "[*] SQL order: $($datatable.rows.name -join ', ')`n"
						Write-Output "[*] If this is the case, you can reorder columns by using the -Query parameter or execute the import against a view.`n"
						if ($safe -eq $false) {
							Write-Output "[*] You can also try running this import using the -Safe parameter, which handles quoted text well.`n"
						}
						Write-Error "`n$errormessage"
					}
					
					
				} elseif ($errormessage -match "Input string was not in a correct format" -or $errormessage -match "The given ColumnName") {
					Write-Warning "CSV contents may be malformed."
					Write-Error $errormessage
				} else { Write-Error $errormessage }
			}
		}
		
		if ($completed -eq $true) {
			# "Note: This count does not take into consideration the number of rows actually inserted when Ignore Duplicates is set to ON."
			$null = $transaction.Commit()
			
			if ($safe -eq $false) {
				Write-Output "[*] $i total rows copied"
			} else {
				$total = [System.Data.SqlClient.SqlBulkCopyExtension]::RowsCopiedCount($bulkcopy)
				Write-Output "[*] $total total rows copied"
			}
		} else { Write-Output "[*] Transaction rolled back." }
	
		# Script is finished. Show elapsed time.
		$totaltime = [math]::Round($elapsed.Elapsed.TotalSeconds,2)
		Write-Output "[*] Total Elapsed Time for bulk insert: $totaltime seconds"
	}

	End {
		# Close everything just in case & ignore errors
		try { $null = $sqlconn.close(); $null = $sqlconn.Dispose(); $null = $oleconn.close; 
			$null = $olecmd.Dispose(); $null = $oleconn.Dispose(); $null = $bulkCopy.close(); 
			$null = $bulkcopy.dispose(); $null = $reader.close; $null = $reader.dispose() } catch {}
		
		# Delete all the temp files
		if ($SqlCredentialPath.length -gt 0) {
			if ((Test-Path $SqlCredentialPath) -eq $true) {
				$null = cmd /c "del $SqlCredentialPath"
			}
		}
			
		if ($shellswitch -eq $false -and $safe -eq $true) {
			# Delete new schema files
			Write-Verbose "Removing automatically generated schema.ini"
			foreach ($file in $csv) {
				$directory = Split-Path $file
				$null = cmd /c "del $directory\schema.ini" | Out-Null
			}
			
			# If a shell switch occured, delete the temporary module file.
			if ((Test-Path "$env:TEMP\Import-CsvToSql.psm1") -eq $true) { cmd /c "del $env:TEMP\Import-CsvToSql.psm1"  | Out-Null }
			
			# Move original schema.ini's back if they existed
			if ($movedschemainis.count -gt 0) {
				foreach ($item in $movedschemainis) {
					Write-Verbose "Moving $($item.keys) back to $($item.values)"
					$null = cmd /c "move $($item.keys) $($item.values)"
				}
			}
		Write-Output "[*] Finished at $(Get-Date)"
		}
	}
}

function create-7zip([String] $aDirectory, [String] $aZipfile)
{
    [string]$pathToZipExe = "C:\Program Files\7-zip\7z.exe";
    [Array]$arguments = "a", "-tzip", "$aZipfile", "$aDirectory", "-r";
    & $pathToZipExe $arguments;
}


Function New-WPFMessageBox {

    # For examples for use, see my blog:
    # https://smsagent.wordpress.com/2017/08/24/a-customisable-wpf-messagebox-for-powershell/
    
    # CHANGES
    # 2017-09-11 - Added some required assemblies in the dynamic parameters to avoid errors when run from the PS console host.
    
    # Define Parameters
    [CmdletBinding()]
    Param
    (
        # The popup Content
        [Parameter(Mandatory=$True,Position=0)]
        [Object]$Content,

        # The window title
        [Parameter(Mandatory=$false,Position=1)]
        [string]$Title,

        # The buttons to add
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateSet('OK','OK-Cancel','Abort-Retry-Ignore','Yes-No-Cancel','Yes-No','Retry-Cancel','Cancel-TryAgain-Continue','None')]
        [array]$ButtonType = 'OK',

        # The buttons to add
        [Parameter(Mandatory=$false,Position=3)]
        [array]$CustomButtons,

        # Content font size
        [Parameter(Mandatory=$false,Position=4)]
        [int]$ContentFontSize = 14,

        # Title font size
        [Parameter(Mandatory=$false,Position=5)]
        [int]$TitleFontSize = 14,

        # BorderThickness
        [Parameter(Mandatory=$false,Position=6)]
        [int]$BorderThickness = 0,

        # CornerRadius
        [Parameter(Mandatory=$false,Position=7)]
        [int]$CornerRadius = 8,

        # ShadowDepth
        [Parameter(Mandatory=$false,Position=8)]
        [int]$ShadowDepth = 3,

        # BlurRadius
        [Parameter(Mandatory=$false,Position=9)]
        [int]$BlurRadius = 20,

        # WindowHost
        [Parameter(Mandatory=$false,Position=10)]
        [object]$WindowHost,

        # Timeout in seconds,
        [Parameter(Mandatory=$false,Position=11)]
        [int]$Timeout,

        # Code for Window Loaded event,
        [Parameter(Mandatory=$false,Position=12)]
        [scriptblock]$OnLoaded,

        # Code for Window Closed event,
        [Parameter(Mandatory=$false,Position=13)]
        [scriptblock]$OnClosed

    )

    # Dynamically Populated parameters
    DynamicParam {
        
        # Add assemblies for use in PS Console 
        Add-Type -AssemblyName System.Drawing, PresentationCore
        
        # ContentBackground
        $ContentBackground = 'ContentBackground'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.ContentBackground = "White"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ContentBackground, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ContentBackground, $RuntimeParameter)
        

        # FontFamily
        $FontFamily = 'FontFamily'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute)  
        $arrSet = [System.Drawing.FontFamily]::Families | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($FontFamily, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($FontFamily, $RuntimeParameter)
        $PSBoundParameters.FontFamily = "Segui"

        # TitleFontWeight
        $TitleFontWeight = 'TitleFontWeight'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Windows.FontWeights] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.TitleFontWeight = "Normal"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($TitleFontWeight, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($TitleFontWeight, $RuntimeParameter)

        # ContentFontWeight
        $ContentFontWeight = 'ContentFontWeight'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Windows.FontWeights] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.ContentFontWeight = "Normal"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ContentFontWeight, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ContentFontWeight, $RuntimeParameter)
        

        # ContentTextForeground
        $ContentTextForeground = 'ContentTextForeground'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.ContentTextForeground = "Black"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ContentTextForeground, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ContentTextForeground, $RuntimeParameter)

        # TitleTextForeground
        $TitleTextForeground = 'TitleTextForeground'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.TitleTextForeground = "Black"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($TitleTextForeground, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($TitleTextForeground, $RuntimeParameter)

        # BorderBrush
        $BorderBrush = 'BorderBrush'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.BorderBrush = "Black"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($BorderBrush, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($BorderBrush, $RuntimeParameter)


        # TitleBackground
        $TitleBackground = 'TitleBackground'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.TitleBackground = "White"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($TitleBackground, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($TitleBackground, $RuntimeParameter)

        # ButtonTextForeground
        $ButtonTextForeground = 'ButtonTextForeground'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = [System.Drawing.Brushes] | Get-Member -Static -MemberType Property | Select -ExpandProperty Name 
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $PSBoundParameters.ButtonTextForeground = "Black"
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ButtonTextForeground, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ButtonTextForeground, $RuntimeParameter)

        # Sound
        $Sound = 'Sound'
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $False
        #$ParameterAttribute.Position = 14
        $AttributeCollection.Add($ParameterAttribute) 
        $arrSet = (Get-ChildItem "$env:SystemDrive\Windows\Media" -Filter Windows* | Select -ExpandProperty Name).Replace('.wav','')
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)    
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($Sound, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($Sound, $RuntimeParameter)

        return $RuntimeParameterDictionary
    }

    Begin {
        Add-Type -AssemblyName PresentationFramework
    }
    
    Process {

# Define the XAML markup
[XML]$Xaml = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="Window" Title="" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" Opacity="1">
    <Window.Resources>
        <Style TargetType="{x:Type Button}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border>
                            <Grid Background="{TemplateBinding Background}">
                                <ContentPresenter />
                            </Grid>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Border x:Name="MainBorder" Margin="10" CornerRadius="$CornerRadius" BorderThickness="$BorderThickness" BorderBrush="$($PSBoundParameters.BorderBrush)" Padding="0" >
        <Border.Effect>
            <DropShadowEffect x:Name="DSE" Color="Black" Direction="270" BlurRadius="$BlurRadius" ShadowDepth="$ShadowDepth" Opacity="0.6" />
        </Border.Effect>
        <Border.Triggers>
            <EventTrigger RoutedEvent="Window.Loaded">
                <BeginStoryboard>
                    <Storyboard>
                        <DoubleAnimation Storyboard.TargetName="DSE" Storyboard.TargetProperty="ShadowDepth" From="0" To="$ShadowDepth" Duration="0:0:1" AutoReverse="False" />
                        <DoubleAnimation Storyboard.TargetName="DSE" Storyboard.TargetProperty="BlurRadius" From="0" To="$BlurRadius" Duration="0:0:1" AutoReverse="False" />
                    </Storyboard>
                </BeginStoryboard>
            </EventTrigger>
        </Border.Triggers>
        <Grid >
            <Border Name="Mask" CornerRadius="$CornerRadius" Background="$($PSBoundParameters.ContentBackground)" />
            <Grid x:Name="Grid" Background="$($PSBoundParameters.ContentBackground)">
                <Grid.OpacityMask>
                    <VisualBrush Visual="{Binding ElementName=Mask}"/>
                </Grid.OpacityMask>
                <StackPanel Name="StackPanel" >                   
                    <TextBox Name="TitleBar" IsReadOnly="True" IsHitTestVisible="False" Text="$Title" Padding="10" FontFamily="$($PSBoundParameters.FontFamily)" FontSize="$TitleFontSize" Foreground="$($PSBoundParameters.TitleTextForeground)" FontWeight="$($PSBoundParameters.TitleFontWeight)" Background="$($PSBoundParameters.TitleBackground)" HorizontalAlignment="Stretch" VerticalAlignment="Center" Width="Auto" HorizontalContentAlignment="Center" BorderThickness="0"/>
                    <DockPanel Name="ContentHost" Margin="0,10,0,10"  >
                    </DockPanel>
                    <DockPanel Name="ButtonHost" LastChildFill="False" HorizontalAlignment="Center" >
                    </DockPanel>
                </StackPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

[XML]$ButtonXaml = @"
<Button xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Width="Auto" Height="30" FontFamily="Segui" FontSize="16" Background="Transparent" Foreground="White" BorderThickness="1" Margin="10" Padding="20,0,20,0" HorizontalAlignment="Right" Cursor="Hand"/>
"@

[XML]$ButtonTextXaml = @"
<TextBlock xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" FontFamily="$($PSBoundParameters.FontFamily)" FontSize="16" Background="Transparent" Foreground="$($PSBoundParameters.ButtonTextForeground)" Padding="20,5,20,5" HorizontalAlignment="Center" VerticalAlignment="Center"/>
"@

[XML]$ContentTextXaml = @"
<TextBlock xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Text="$Content" Foreground="$($PSBoundParameters.ContentTextForeground)" DockPanel.Dock="Right" HorizontalAlignment="Center" VerticalAlignment="Center" FontFamily="$($PSBoundParameters.FontFamily)" FontSize="$ContentFontSize" FontWeight="$($PSBoundParameters.ContentFontWeight)" TextWrapping="Wrap" Height="Auto" MaxWidth="500" MinWidth="50" Padding="10"/>
"@

    # Load the window from XAML
    $Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))

    # Custom function to add a button
    Function Add-Button {
        Param($Content)
        $Button = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $ButtonXaml))
        $ButtonText = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $ButtonTextXaml))
        $ButtonText.Text = "$Content"
        $Button.Content = $ButtonText
        $Button.Add_MouseEnter({
            $This.Content.FontSize = "17"
        })
        $Button.Add_MouseLeave({
            $This.Content.FontSize = "16"
        })
        $Button.Add_Click({
            New-Variable -Name WPFMessageBoxOutput -Value $($This.Content.Text) -Option ReadOnly -Scope Script -Force
            $Window.Close()
        })
        $Window.FindName('ButtonHost').AddChild($Button)
    }

    # Add buttons
    If ($ButtonType -eq "OK")
    {
        Add-Button -Content "OK"
    }

    If ($ButtonType -eq "OK-Cancel")
    {
        Add-Button -Content "OK"
        Add-Button -Content "Cancel"
    }

    If ($ButtonType -eq "Abort-Retry-Ignore")
    {
        Add-Button -Content "Abort"
        Add-Button -Content "Retry"
        Add-Button -Content "Ignore"
    }

    If ($ButtonType -eq "Yes-No-Cancel")
    {
        Add-Button -Content "Yes"
        Add-Button -Content "No"
        Add-Button -Content "Cancel"
    }

    If ($ButtonType -eq "Yes-No")
    {
        Add-Button -Content "Yes"
        Add-Button -Content "No"
    }

    If ($ButtonType -eq "Retry-Cancel")
    {
        Add-Button -Content "Retry"
        Add-Button -Content "Cancel"
    }

    If ($ButtonType -eq "Cancel-TryAgain-Continue")
    {
        Add-Button -Content "Cancel"
        Add-Button -Content "TryAgain"
        Add-Button -Content "Continue"
    }

    If ($ButtonType -eq "None" -and $CustomButtons)
    {
        Foreach ($CustomButton in $CustomButtons)
        {
            Add-Button -Content "$CustomButton"
        }
    }

    # Remove the title bar if no title is provided
    If ($Title -eq "")
    {
        $TitleBar = $Window.FindName('TitleBar')
        $Window.FindName('StackPanel').Children.Remove($TitleBar)
    }

    # Add the Content
    If ($Content -is [String])
    {
        # Replace double quotes with single to avoid quote issues in strings
        If ($Content -match '"')
        {
            $Content = $Content.Replace('"',"'")
        }
        
        # Use a text box for a string value...
        $ContentTextBox = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $ContentTextXaml))
        $Window.FindName('ContentHost').AddChild($ContentTextBox)
    }
    Else
    {
        # ...or add a WPF element as a child
        Try
        {
            $Window.FindName('ContentHost').AddChild($Content) 
        }
        Catch
        {
            $_
        }        
    }

    # Enable window to move when dragged
    $Window.FindName('Grid').Add_MouseLeftButtonDown({
        $Window.DragMove()
    })

    # Activate the window on loading
    If ($OnLoaded)
    {
        $Window.Add_Loaded({
            $This.Activate()
            Invoke-Command $OnLoaded
        })
    }
    Else
    {
        $Window.Add_Loaded({
            $This.Activate()
        })
    }
    

    # Stop the dispatcher timer if exists
    If ($OnClosed)
    {
        $Window.Add_Closed({
            If ($DispatcherTimer)
            {
                $DispatcherTimer.Stop()
            }
            Invoke-Command $OnClosed
        })
    }
    Else
    {
        $Window.Add_Closed({
            If ($DispatcherTimer)
            {
                $DispatcherTimer.Stop()
            }
        })
    }
    

    # If a window host is provided assign it as the owner
    If ($WindowHost)
    {
        $Window.Owner = $WindowHost
        $Window.WindowStartupLocation = "CenterOwner"
    }

    # If a timeout value is provided, use a dispatcher timer to close the window when timeout is reached
    If ($Timeout)
    {
        $Stopwatch = New-object System.Diagnostics.Stopwatch
        $TimerCode = {
            If ($Stopwatch.Elapsed.TotalSeconds -ge $Timeout)
            {
                $Stopwatch.Stop()
                $Window.Close()
            }
        }
        $DispatcherTimer = New-Object -TypeName System.Windows.Threading.DispatcherTimer
        $DispatcherTimer.Interval = [TimeSpan]::FromSeconds(1)
        $DispatcherTimer.Add_Tick($TimerCode)
        $Stopwatch.Start()
        $DispatcherTimer.Start()
    }

    # Play a sound
    If ($($PSBoundParameters.Sound))
    {
        $SoundFile = "$env:SystemDrive\Windows\Media\$($PSBoundParameters.Sound).wav"
        $SoundPlayer = New-Object System.Media.SoundPlayer -ArgumentList $SoundFile
        $SoundPlayer.Add_LoadCompleted({
            $This.Play()
            $This.Dispose()
        })
        $SoundPlayer.LoadAsync()
    }

    # Display the window
    $null = $window.Dispatcher.InvokeAsync{$window.ShowDialog()}.Wait()

    }
}




