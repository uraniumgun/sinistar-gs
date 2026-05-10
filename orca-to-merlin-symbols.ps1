# A script to take an ORCA linker map file and assembler trace files and make
# a Merlin32 style symbols file, for use with Cyrene.
#
param (
	[Alias("map")]
	[string] $MapFilePath = $null,
	[Alias("source","src")]
	[string] $SourceFilePath = $null,
	[Alias("output","out","dest")]
	[string] $SymbolFilePath = $null,
	[Alias("l","lower")]
	[switch] $LowerCaseLabels = $true,
	[Alias("v")]
	[switch] $Verbose = $false
)

$ErrorResults = [System.Collections.ArrayList]@()

enum SectionType {
	CODE = 0
	DATA = 1
}

# A class to a
class SymbolSectionEntry
{
	[uint] $offset = 0
	[uint] $length = 0
	[SectionType] $type = [SectionType]::CODE
	[string] $label = ""
	[string] $filename = ""
	[uint] $line = 0
	[uint] $mx = 0
}

class SymbolSegmentEntry
{
	[uint] $number = 0
	[uint] $length = 0
	[SectionType] $type = [SectionType]::CODE
	[string] $name = ""
	[System.Collections.ArrayList] $sections = [System.Collections.ArrayList]@()
}

# The app class that does the parsing and exporting  ORCA map/assembler output to a Merlin32 Symbol Table
class App
{
	# A string array for the file that is being parsed
	[string[]] $sourceLines
	$segments = [ordered]@{}

	[void] ShowErrors()
	{
		if ($script:ErrorResults.Count -ne 0)
		{
			Write-Host -ForegroundColor Red "Errors during processing"
			foreach ($entry in $script:ErrorResults)
			{
				if ($null -ne $entry["filePath"] -and $null -ne $entry.filePath)
				{
					Write-Host -ForegroundColor Red $entry.filePath
				}
			}
		}
	}

	# Add a parsing error message
	[void] AddParsingError([string] $str)
	{
		$errorEntry = @{}
		$errorEntry.message = $str
		$Script:ErrorResults.Add($errorEntry)
	}

	# Get an int from the input.  This uses the current radix to evaluate the number
	[uint] GetUInt([string] $str, [int] $radix)
	{
		[uint] $result = 0
		if ($str.StartsWith('$'))
		{
			# Always a hex value, but we need to put a different prefix on
			try {
				$result = [uint]("0x" + $str.Remove(0, 1))
			}
			catch {
				Write-Host "Unable to convert" $str "to a number" -ForegroundColor Red
			}
		}
		else {
			if ($radix -eq 16)
			{
				# Hex value, but we have no prefix, so add one
				try {
					$result = [uint]("0x" + $str)
				}
				catch {
					Write-Host "Unable to convert" $str "to a number" -ForegroundColor Red
				}
			}
			else {
				try {
					$result = [uint]$str
				}
				catch {
					Write-Host "Unable to convert" $str "to a number" -ForegroundColor Red
				}
			}
		}
		return $result
	}

	# Parse the map file input
	# There are two parts that are of interest the "Segment:" section
	# and the "Segment Information:" section.
	#
	# The "Segment:" section contains the segment / function name listing
	# Each line consists of :
	# A 4-byte hex value, denoting the offset in the segment
	# A 4-byte hex value denoting the length of the code/data
	# A 2-byte hex value, denoting the segment number
	# The type, either "Code:" or "Data:"
	# The label
	#
	# The "Segment Information:" section is a summary, and is useful for getting
	# the name of the segment to match up to the number.
	# There is a blank line, then a column header line, then another blank line, then
	# the segment information is:
	# A decimal number for the segment.
	# The name of the segment.  Note, this can be empty, and the max characters is 10
	# The type, this time a 2-byte hex value, but starting with a $
	# The length, a 4-byte hex value, starting with a $
	# The origin, either a 4-byte hex value or Relocatable.
	# The fields in this section have multiple spaces to align them into columns
	[bool] ParseMapFile([bool] $makeLabelsLowerCase)
	{
		[bool] $result = $true
		[bool] $done = $false
		[int] $lineIndex = 0

		[int] $lineCount = $this.sourceLines.Count

		enum Section {
			UNKNOWN
			SEGMENT
			SEGMENT_INFORMATION
		}

		enum SegmentInformationColumns {
			NUMBER
			NAME
			TYPE
			LENGTH
			ORG
			COLUMN_COUNT
		}

		[Section] $inSection = [Section]::UNKNOWN
		[bool] $foundColumHeader = $false
		[int[]] $columnStarts = 0,0,0,0,0

		if ($lineCount -ne 0)
		{
			while ($done -eq $false) {
				$line = $this.sourceLines[$lineIndex]

				if ($line -match "^Segment:" -eq $true)	{
					$inSection = [Section]::SEGMENT
				}
				elseif ($line -match "^Segment Information:" -eq $true)	{
					$inSection = [Section]::SEGMENT_INFORMATION
					$foundColumHeader = $false
				}
				elseif ($line -match "^There are" -eq $true)	{
					$inSection = [Section]::UNKNOWN			# We hit the last line, just set to UNKNOWN, and we will skip out
				}
				elseif ($inSection -eq [Section]::SEGMENT) {
					# Segment parsing
					if ($line.Length -ne 0)
					{
						# Split the lines into the fields
						[string] $offset, $length, $segment, $type, $label = ($line -split "\s+")

						[uint] $segmentNum = $this.GetUInt($segment, 16)

						[SymbolSectionEntry] $section = @{}
						$section.offset = $this.GetUInt($offset, 16)
						$section.length = $this.GetUInt($length, 16)
						if ($type -like "Code:") {
							$section.type = [SectionType]::CODE
						} elseif ($type -like "Data:") {
							$section.type = [SectionType]::DATA
						} else {
							Write-Host "Unknown type " $type "parsing the Segment, line" $lineIndex -ForegroundColor Red
						}
						if ($makeLabelsLowerCase -eq $true){
							$section.label = $label.ToLower()
						} else {
							$section.label = $label
						}
						$section.filename = "fake.s"
						$section.line = 1

						if ($null -eq $this.segments[$segmentNum]) {
							[SymbolSegmentEntry] $segmentEntry = @{}
							$segmentEntry.number = $segmentNum
							$this.segments.Add($segmentNum, $segmentEntry);
						}

						$this.segments[$segmentNum].sections.Add($section)
					}
				} elseif ($inSection -eq [Section]::SEGMENT_INFORMATION) {
					# Segment Information
					# I can't effectively use split on this data, as the Name column can be empty, or contain spaces
					if ($line.Length -ne 0)
					{
						# I could hard-code the column starts, but where is the fun in that?
						if ($false -eq $foundColumHeader) {
							# Parse the column header line and use the start of the name, as the start of the column data
							# Could iterate over the line and find the first letters, but I will have some hard-coded values, by using the known column names
							$columnStarts[[SegmentInformationColumns]::NUMBER] = $line.IndexOf("Number")
							$columnStarts[[SegmentInformationColumns]::NAME] = $line.IndexOf("Name")
							$columnStarts[[SegmentInformationColumns]::TYPE] = $line.IndexOf("Type")
							$columnStarts[[SegmentInformationColumns]::LENGTH] = $line.IndexOf("Length")
							$columnStarts[[SegmentInformationColumns]::ORG] = $line.IndexOf("Org")
							$foundColumHeader = $true
						}
						else {
							$numberStr = $line.Substring($columnStarts[[SegmentInformationColumns]::NUMBER], $columnStarts[[SegmentInformationColumns]::NAME] - $columnStarts[[SegmentInformationColumns]::NUMBER]).Trim()
							$nameStr = $line.Substring($columnStarts[[SegmentInformationColumns]::NAME], $columnStarts[[SegmentInformationColumns]::TYPE] - $columnStarts[[SegmentInformationColumns]::NAME]).Trim()
							$typeStr = $line.Substring($columnStarts[[SegmentInformationColumns]::TYPE], $columnStarts[[SegmentInformationColumns]::LENGTH] - $columnStarts[[SegmentInformationColumns]::TYPE]).Trim()
							$lengthStr = $line.Substring($columnStarts[[SegmentInformationColumns]::LENGTH], $columnStarts[[SegmentInformationColumns]::ORG] - $columnStarts[[SegmentInformationColumns]::LENGTH]).Trim()
							$orgStr = $line.Substring($columnStarts[[SegmentInformationColumns]::ORG]).Trim()

							[uint] $number = $this.GetUInt($numberStr, 10)

							if ($null -eq $this.segments[$number]) {
								[SymbolSegmentEntry] $segment = @{}
								$segment.number = $number
								$this.segments.Add($number, $segment);
							}

							[ref]$segment = $this.segments[$number]
							$segment.Value.name = $nameStr
							$segment.Value.length = $this.GetUInt($lengthStr, 16)
							$segmentType = $this.GetUInt($typeStr, 16)
							if ($segmentType -eq 0) {
								$segment.Value.type = [SectionType]::CODE
							} else {
								$segment.Value.type = [SectionType]::DATA
							}
						}
					}
				}
				$lineIndex = $lineIndex + 1
				if ($lineIndex -eq $lineCount)
				{
					$done = $true
				}
			}
		}

		return $result
	}

	[string] GetOffsetAsBankAddress([uint] $offset)
	{
		return "{0:X2}/{1:X4}" -f ([uint][math]::Floor($offset/65536)), ([uint][math]::Floor($offset%65536))
	}

	[string] GetSectionTypeName([SectionType] $type)
	{
		if ($type -eq [SectionType]::CODE) {
			return "Code"
		}
		return "Data"
	}

	[string] GetSectionDataTypeName([SectionType] $type)
	{
		if ($type -eq [SectionType]::CODE) {
			return ""
		}
		return "HEX"
	}

	[string] GetSectionMXTypeName([uint] $mx)
	{
		if ($mx -eq 0) {
			return "00"
		} elseif ($mx -eq 1) {
			return "01"
		} elseif ($mx -eq 2) {
			return "10"
		}

		return "11"
	}

	# Write the parsed Orca files as Merlin32
	# The format is:
	# The segment name
	# The segment line.
	#	- This seems to be the file line, assuming that macros are 'expanded'
	#	  as well as concatenated to the next file in the segment.  i.e. an ever
	#     increasing number.   I hope Cyrene doesn't need this, because it might be hard to generate.
	# The file name
	# The file line
	# The offset, in 3-byte hex.  No prefix, but a / between the bank byte and the lower 2 bytes.
	# The label name.  Can be empty
	# The section type, Code or Data
	# The data type, empty if the section is Code or if Data, it is the type of data format, HEX, ASC, DS, STRL, etc.
	# The length of the data / code
	# The MX state, which is a 2-bit binary representation of the M and X status flag state
	# Relocation value.  A decimal number of the number of bytes at the location, that need relocation fixup. Can be empty, or 1, 2 or 3.
	#    - Also seems to support a suffix of >>n, where n is the number of bits to shift.
	#
	# Each value is separated by a ;
	# The symbol table doesn't seem to contain an entry for every line in the assembled output,
	# just the lines that have labels or lines that have relocation fixup needs.
	[void] WriteSymbols([string] $path)
	{
		# Write
		[System.IO.FileStream] $out = $null
		try {
			$out = [System.IO.FileStream]::new($path, [System.IO.FileMode]::Create)
		}
		catch {
			Write-Host "Failed to open $path"
			Write-Host $_
		}

		if ($null -ne $out)
		{
			[System.IO.StreamWriter] $writer = [System.IO.StreamWriter]::new($out)


			$writer.Write("Segment Name;Segment Line;File Name;File Line;Address;Name;Type;Data Type;Size;MX;Reloc`r`n")
			foreach ($sectionKey in $this.segments.keys)
			{
				$segment = $this.segments[$sectionKey]
				[uint] $sectionLineNum = 1
				foreach ($section in $segment.sections) {
					[string] $line = ""
					$line = $segment.name + ";" `
							+ $sectionLineNum.ToString() + ";" `
							+ $section.filename + ";" `
							+ $section.line.ToString() + ";" `
							+ $this.GetOffsetAsBankAddress($section.offset) + ";" `
							+ $section.label + ";" `
							+ $this.GetSectionTypeName($section.type) + ";" `
							+ $this.GetSectionDataTypeName($section.type) + ";" `
							+ $section.length.ToString() + ";" `
							+ $this.GetSectionMXTypeName($section.mx) + ";"
					# It seems like Cyrene needs to see at least 1 "relocatable" command for something in a segment, else, it doesn't think the segment is relocatable
					# and so, doesn't map anything in the segment.  I'm going to fake something for now.
					if ($sectionLineNum -eq 1) {
						$line = $line + "2"
					}

					$sectionLineNum = $sectionLineNum + 1
					$writer.Write($line)
					$writer.Write("`r`n")
				}
			}
			$writer.Close();
		}
	}

	# Get the supplied file and put it into an array of strings, by line
	[bool] GetFile([string] $path)
	{
		[bool] $result = $true

		if ($null -eq $path -or $path.Length -eq 0)
		{
			Write-Host "Path is empty"
			$result = $false
		}
		else
		{
			try {
				$this.sourceLines = Get-Content -Path $path
			}
			catch {
				Write-Host "Failed to load " $path
				Write-Host $_

				$result = $false
			}
		}
		return $result
	}

	# Run the script
	[void] Run()
	{
		if ($this.GetFile($script:MapFilePath) -eq $true)
		{
			Write-Host "Opened " $script:MapFilePath
			$this.ParseMapFile($script:LowerCaseLabels)
			$this.WriteSymbols($script:SymbolFilePath)
			Write-Host "Success!"
		}
	}
}

# Note.  I like using a class to run the guts of a Powershell script, because
# classes don't have the odd-ball, hidden, return value accumulation issues.

Write-Host "Converting Orca Symbols to Merlin32"
# Create the processor
$app = [App]::new()

# Run it!
$app.Run()

