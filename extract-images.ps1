# A script file to parse through the IMAGE.SRC file from the original Sinistar arcade
# source (available on Git-Hub), and export the data as FLC files.
#
param (
	[Alias("src")]
	[string] $SourcePath = $null,
	[Alias("v")]
	[switch] $Verbose = $false
)

$ErrorResults = [System.Collections.ArrayList]@()

# A class to hold a frame of parsed image data
class ImageFrame
{
	[uint] $byteWidth = 0
	[uint] $height = 0
	[uint] $originX = 0
	[uint] $originY = 0
	[string] $label = ""
	[byte[]] $dataBytes
	[bool] $complete = $false
}

# A class to hold the header and all the references to frames of an image
class ImageHeader
{
	[string] $label = ""
	[System.Collections.ArrayList]$frames = [System.Collections.ArrayList]@()
	[bool] $complete = $false
	[bool] $written = $false

	ImageHeader()
	{

	}

	ImageHeader([string] $str)
	{
		$this.label = $str
	}

	[void] Clear()
	{
		$this.label = ""
		$this.frames = [System.Collections.ArrayList]@()
		$this.complete = $false
		$this.written = $false
	}

	# Check to see if the Image has been completely read in
	[bool] CheckComplete()
	{
		# If it is already marked complete, then return
		if ($this.complete -eq $false)
		{
			# Must have some frames
			if ($this.frames.Count -gt 0)
			{
				foreach($entry in $this.frames)
				{
					if ($entry.complete -eq $false)
					{
						return $false
					}
				}
				# All the frames have data
				$this.complete = $true
			}
		}

		return $this.complete
	}
}

# Palette color entry
class ColorEntry
{
	[byte] $red
	[byte] $green
	[byte] $blue

	ColorEntry() {}
	ColorEntry([byte] $r, [byte] $g, [byte] $b)
	{
		$this.red = $r
		$this.green = $g
		$this.blue = $b
	}
}

# Simple palette
class Palette
{
	[uint] $colorCount = 256
	[ColorEntry[]] $colors = [ColorEntry[]]::new(256)
}

# A basic FLIC header definition.
# This does not have any of the folow on extensions defined
class FLICHeader
{
	[uint] $fileSize = 0
	[ushort] $fileID = 0
	[ushort] $frameCount = 0
	[ushort] $width = 0
	[ushort] $height = 0
	[ushort] $pixDepth = 0
	[ushort] $flags = 0
	[uint] $frameDelay = 0
	[ushort] $reserved1 = 0

	[uint] $creationDate = 0
	[uint] $creatorSN = 0
	[uint] $lastupdated = 0
	[uint] $updaterSN = 0
	[ushort] $xAspect = 0
	[ushort] $yAspect = 0
	[byte[]] $reserved2 = [byte[]]::new(38)
	[uint] $frame1Offset = 0
	[uint] $frame2Offset = 0
	[byte[]] $reserved3 = [byte[]]::new(40)
}

# A FLIC Chunk definition
# Size is inclusive
class FLICChunk
{
	[uint] $size = 0
	[ushort] $chunkType = 0
	[ushort] $subChunkCount = 0
	[byte[]] $reserved = [byte[]]::new(8)
}

# A FLIC sub-chunk definition
# Size is inclusive
class FLICSubChunk
{
	[uint] $size = 0
	[ushort] $chunkType = 0
}

# A class that holds a sub-chunk header and the data to write to the sub-chunk
class FLICSubChunkData
{
	[FLICSubChunk] $subChunk = @{}
	[System.IO.MemoryStream] $subChunkData = $null
}

# A class that holds a chunk header and the sub-chunks to write to the chunk
class FLICChunkData
{
	[FLICChunk] $chunk = @{}
	[System.Collections.ArrayList] $subChunks = [System.Collections.ArrayList]@()
}

# Some FLIC constants
enum FLICEnums {
	STANDARD_256 = 0xaf12		# Standard FLC file type, with 256 colors
	PREFIX = 0xf100
	FRAME = 0xf1fa
	COLOR_256 =	0x04
	DELTA_FLC = 0x07
	COLOR_64 = 	0x0b
	DELTA_FLI = 0x0c
	BLACK = 0x0d
	BYTE_RUN = 0x0f
	COPY = 0x10
	PSTAMP = 0x12
}

# Sizes of FLIC items
enum FLICSizes {
	CHUNK = 4 + 2 + 2 + 8
	SUBCHUNK = 4 + 2
	HEADER = 50 + 38 + 40
}

class Dimensions
{
	[uint] $width = 0
	[uint] $height = 0
}

# A static class to help write out a FLIC file
Class FLIC
{
	# Get the destination dimentions, by finding the largest frame, then padding out by a set amount
	static [Dimensions] GetDestinationDimensions([ref] $imageHeader)
	{
		[Dimensions] $dims = @{}

		foreach ($frame in $imageHeader.Value.frames)
		{
			[int] $framePixelWidth = [Math]::Floor($frame.bytewidth * 2)

			if ($framePixelWidth -gt $dims.width)
			{
				$dims.width = $framePixelWidth
			}

			if ($frame.height -gt $dims.height)
			{
				$dims.height = $frame.height
			}
		}

		# Give some space around the image, primarily for the origin ticks
		$dims.width = $dims.width + 16
		$dims.height = $dims.height + 16

		return $dims
	}

	# Convert a palette to a sub-chunk
	static [FLICSubChunkData] PaletteToSubChunk([ref] $palette)
	{
		[FLICSubChunkData] $data = @{}

		$data.subChunk.chunkType = [FLICEnums]::COLOR_256

		$data.subChunkData = [System.IO.MemoryStream]::new()
		# Use a writer for easier access
		[System.IO.BinaryWriter] $writer = [System.IO.BinaryWriter]::new($data.subChunkData)

		$writer.Write([ushort]1)		# 1 Palette
		$writer.Write([byte]0)			# start at 0
		$writer.Write([byte]0)			# number of color triplets, 0, means 256

		foreach ($color in $palette.Value.colors)
		{
			$writer.Write([byte]$color.red)
			$writer.Write([byte]$color.green)
			$writer.Write([byte]$color.blue)
		}

		$data.subChunk.size = [uint][FLICSizes]::SUBCHUNK + 2 + 1 + 1 + (3 * 256)
		return $data
	}

	# Convert a frame into a sub-chunk
	# This converts it to an uncompressed image
	static [FLICSubChunkData] FrameToSubChunk([ref] $frame, [Dimensions] $dims)
	{
		[FLICSubChunkData] $data = @{}

		# To be easy-peasy, I'm going to just copy all the lines, rather than try and do byte runs
		$data.subChunk.chunkType = [FLICEnums]::COPY

		$data.subChunkData = [System.IO.MemoryStream]::new()
		# Use a writer for easier access
		[System.IO.BinaryWriter] $writer = [System.IO.BinaryWriter]::new($data.subChunkData)

		# Figure out where the frame will appear, in the larger dimensions of the destination surface
		$frameByteWidth = $frame.Value.byteWidth
		$framePixelWidth = [Math]::Floor($frameByteWidth * 2)
		$frameY1 = [Math]::Floor(($dims.height - $frame.Value.height) / 2)
		$frameY2 = $frame.Value.height + $frameY1
		$frameX1 = [Math]::Floor(($dims.width - $framePixelWidth) / 2)
		$frameX2 = $framePixelWidth + $frameX1

		[ref] $frameBytes = $frame.Value.dataBytes

		for ($y = 0; $y -lt $dims.height; $y++)
		{
			# If we are outside the frame range, write 255 (the transparent color)
			if ($y -lt $frameY1 -or $y -ge $frameY2)
			{
				for ($i = 0; $i -lt $dims.width; $i++)
				{
					$writer.Write([byte]255)
				}
			}
			else
			{
				# Write any left padding
				if ($frameX1 -gt 0)
				{
					for ($i = 0; $i -lt $frameX1; $i++)
					{
						$writer.Write([byte]255)
					}
				}

				$offset = ($y - $frameY1) * $frameByteWidth
				for ($i = 0; $i -lt $frameByteWidth; $i++)
				{
					$frameByte = $frameBytes.Value[$offset]
					# Two pixels in a byte.  The high nybble is the first pixel
					[byte] $b = [byte][Math]::Floor($frameByte / 16);
					# Transparent color translate
					if ($b -eq 0)
					{
						$b = 255
					}

					$writer.Write($b)

					$b = [byte][Math]::Floor($frameByte % 16)
					if ($b -eq 0)
					{
						$b = 255
					}

					$writer.Write($b)
					$offset++
				}

				# Write any right padding
				if ($frameX2 -gt 0)
				{
					for ($i = $frameX2; $i -lt $dims.width; $i++)
					{
						$writer.Write([byte]255)
					}
				}
			}
		}

		$data.subChunk.size = [uint][FLICSizes]::SUBCHUNK + [uint]($dims.width * $dims.height)
		return $data
	}

	# Convert a frame into a sub-chunk
	# This converts it to an RLE image
	static [FLICSubChunkData] FrameToRLESubChunk([ref] $frame, [Dimensions] $dims)
	{
		[FLICSubChunkData] $data = @{}

		# Using RLE compression
		$data.subChunk.chunkType = [FLICEnums]::BYTE_RUN

		$data.subChunkData = [System.IO.MemoryStream]::new()
		# Use a writer for easier access
		[System.IO.BinaryWriter] $writer = [System.IO.BinaryWriter]::new($data.subChunkData)

		# Figure out where the frame will appear, in the larger dimensions of the destination surface
		$frameByteWidth = $frame.Value.byteWidth
		$framePixelWidth = [Math]::Floor($frameByteWidth * 2)
		$frameY1 = [Math]::Floor(($dims.height - $frame.Value.height) / 2)
		$frameY2 = $frame.Value.height + $frameY1
		$frameX1 = [Math]::Floor(($dims.width - $framePixelWidth) / 2)
		$frameX2 = $framePixelWidth + $frameX1

		[ref] $frameBytes = $frame.Value.dataBytes

		# Keep track of how many bytes we write
		[uint] $writeSize = 0

		# Writing to a line buffer, then compressing that to the output
		[byte[]] $lineBuffer = [byte[]]::new($dims.width)
		for ($y = 0; $y -lt $dims.height; $y++)
		{
			[uint] $x = 0
			# If we are outside the frame range, write 255 (the transparent color)
			if ($y -lt $frameY1 -or $y -ge $frameY2)
			{
				for ($i = 0; $i -lt $dims.width; $i++)
				{
					$lineBuffer[$x++]=[byte]255
				}

				if ($y -eq 0)
				{
					# We will end up rotating the image, so put the X tick on the top line
					$lineBuffer[$frame.Value.originX + $frameX1] =[byte]0
				}
			}
			else
			{
				# Write any left padding
				if ($frameX1 -gt 0)
				{
					for ($i = 0; $i -lt $frameX1; $i++)
					{
						$lineBuffer[$x++]=[byte]255
					}
				}

				$offset = ($y - $frameY1) * $frameByteWidth
				for ($i = 0; $i -lt $frameByteWidth; $i++)
				{
					$frameByte = $frameBytes.Value[$offset]
					# Two pixels in a byte.  The high nybble is the first pixel
					[byte] $b = [byte][Math]::Floor($frameByte / 16);
					# Transparent color translate
					if ($b -eq 0)
					{
						$b = 255
					}

					# I'm also going to swap index 1 and 15 (white and yellow), so that white is the last color, which
					# is kinda 'traditional' with IIgs graphics
					if ($b -eq 1)
					{
						$b = 15
					}
					elseif ($b -eq 15)
					{
						$b = 1
					}

					$lineBuffer[$x++]=$b

					$b = [byte][Math]::Floor($frameByte % 16)
					if ($b -eq 0)
					{
						$b = 255
					}

					if ($b -eq 1)
					{
						$b = 15
					}
					elseif ($b -eq 15)
					{
						$b = 1
					}

					$lineBuffer[$x++]=$b
					$offset++
				}

				# Write any right padding
				if ($frameX2 -gt 0)
				{
					for ($i = $frameX2; $i -lt $dims.width; $i++)
					{
						$lineBuffer[$x++]=[byte]255
					}
				}

				if ($y -eq ($frame.Value.originX + $frameX1))
				{
					# Put the X tick on the start of the line
					$lineBuffer[0] =[byte]0
				}
			}

			# Write the RLE encoded line
			# The encoding has a byte at the start, it is positive, if there is a 'run' of the same byte
			# in which case the the next byte is to be repeated, n times
			# if the value is negative, there are n*-1 non-repeating bytes following

			# There is a 'packet' count that was on each line.  It is ignored
			$writer.Write([byte]0)

			$writeSize++

			$x = 0
			[uint] $width = $dims.width
			while ($width -gt 0)
			{
				if ($width -gt 1 -and $lineBuffer[$x] -eq $lineBuffer[$x+1])
				{
					# Run of the same bytes
					[byte] $b = $lineBuffer[$x]
					[sbyte] $length = 2
					$width = $width - 2
					$x = $x + 2
					while ($width -ne 0 -and $lineBuffer[$x] -eq $b -and $length -lt 127)
					{
						$x++
						$width--
						$length++
					}

					$writer.Write([byte]$length)
					$writer.Write([byte]$b)
					$writeSize = $writeSize + [uint]2
				}
				else
				{
					[uint] $start = $x
					$x++
					$width--
					[sbyte] $length = 1
					while ($width -gt 1 -and $lineBuffer[$x] -ne $lineBuffer[$x+1] -and $length -lt 127)
					{
						$x++
						$width--
						$length++
					}
					[sbyte]$negLength = [sbyte]($length * -1)
					$writer.Write([sbyte]$neglength)
					$writer.Write($lineBuffer, $start, [uint]$length)

					$writeSize = $writeSize + [uint]1 + [uint]$length
				}
			}
		}

		$data.subChunk.size = [uint][FLICSizes]::SUBCHUNK + [uint]$writeSize
		return $data
	}

	# Make a chunk data out of a frame and a palette
	static [FLICChunkData] MakeFrameChunk([uint] $frameIndex, [ref] $frame, [Dimensions] $dims, [ref] $palette)
	{
		[FLICChunkData] $data = @{}

		$data.chunk.chunkType = [FLICEnums]::FRAME
		$data.chunk.subChunkCount = 0
		$data.chunk.size = [uint][FLICSizes]::CHUNK

		if ($frameIndex	-eq 0)
		{
			# Put a palette in the first frame chunk
			[FLICSubChunkData] $paletteSubChunk = [FLIC]::PaletteToSubChunk($palette)
			$data.subChunks.Add($paletteSubChunk)
			$data.chunk.size += $paletteSubChunk.subChunk.size
			$data.chunk.subChunkCount++
		}

		[FLICSubChunkData] $frameSubChunk = [FLIC]::FrameToRLESubChunk($frame, $dims)
		$data.subChunks.Add($frameSubChunk)
		$data.chunk.size += $frameSubChunk.subChunk.size
		$data.chunk.subChunkCount++

		return $data
	}

	# Make a chunk data out of a frame and a palette
	static [void] WriteChunk([ref] $chunk, [ref] $writer)
	{
		$writer.Value.Write($chunk.Value.chunk.size)
		$writer.Value.Write($chunk.Value.chunk.chunkType)
		$writer.Value.Write($chunk.Value.chunk.subChunkCount)
		$writer.Value.Write($chunk.Value.chunk.reserved)

		foreach($subChunk in $chunk.Value.subChunks)
		{
			$writer.Value.Write($subChunk.subChunk.size)
			$writer.Value.Write($subChunk.subChunk.chunkType)
			$writer.Value.Write($subChunk.subChunkData.ToArray())
		}
	}

	# Write an image
	static [bool] Write([string] $path, [ref] $imageHeader, [ref] $palette)
	{
		[bool] $result = $true

		[FLICHeader] $header = @{}

		$header.fileID = [FLICEnums]::STANDARD_256
		[Dimensions] $dims = [FLIC]::GetDestinationDimensions($imageHeader)
		$header.width = $dims.width
		$header.height = $dims.height
		$header.pixDepth = 8
		$header.frameDelay = 100

		[uint] $offset = [uint][FLICSizes]::HEADER

		[uint] $frameIndex = 0
		# Make all the chunks.
		# This probably isn't the most memory efficent way, as I'm writing everything at the end
		# but I have to figure out the size of all the data, before writing it in the header
		# I could write out dummy values, and seek back to re-write.
		[System.Collections.ArrayList] $chunks = [System.Collections.ArrayList]@()
		foreach ($frame in $imageHeader.Value.frames)
		{
			[FLICChunkData] $frameChunk = [FLIC]::MakeFrameChunk($frameIndex, $frame, $dims, $palette)

			$header.frameCount++
			if ($header.frameCount -eq 1)
			{
				$header.frame1Offset = $offset
			}

			if ($header.frameCount -eq 2)
			{
				$header.frame2Offset = $offset
			}

			$offset += $frameChunk.chunk.size

			$chunks.Add($frameChunk)

			$frameIndex++
		}

		# Finalize the header size
		$header.fileSize = $offset

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
			[System.IO.BinaryWriter] $writer = [System.IO.BinaryWriter]::new($out)

			$writer.Write($header.fileSize)
			$writer.Write($header.fileID)
			$writer.Write($header.frameCount)
			$writer.Write($header.width)
			$writer.Write($header.height)
			$writer.Write($header.pixDepth)
			$writer.Write($header.flags)
			$writer.Write($header.frameDelay)
			$writer.Write($header.reserved1)

			$writer.Write($header.creationDate)
			$writer.Write($header.creatorSN)
			$writer.Write($header.lastupdated)
			$writer.Write($header.updaterSN)
			$writer.Write($header.xAspect)
			$writer.Write($header.yAspect)
			$writer.Write($header.reserved2)
			$writer.Write($header.frame1Offset)
			$writer.Write($header.frame2Offset)
			$writer.Write($header.reserved3)

			foreach($chunk in $chunks)
			{
				[FLIC]::WriteChunk($chunk, $writer)
			}

			$writer.Close()
		}

		return $result
	}
}

# The app class that does the parsing and exporting of the images
# from the Sinistar IMAGES.SRC file
class App
{
	[string[]] $sourceLines
	[int] $radix
	[System.Collections.ArrayList] $imageHeaders = [System.Collections.ArrayList]@()
	[int] $parsingImageHeaderFrameComponent = 0	# the component of the frame we are processing, 0 - 3
	[string] $parsingFrameLabel = ""			# the label of the frame we are processing
	[int] $parsingByteIndex = 0					# the byte index for the frame we are parsing

	[Palette] $palette = @{}

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

	# Get an int from the input.  This uses the current radix to evaluate the number
	[uint] GetUInt([string] $str)
	{
		[int] $result = 0
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
			if ($this.radix -eq 16)
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

	# Handle the RADIX opcode
	[void] ParseRadix([string] $opcode, [string] $operands)
	{
		if ($null -ne $operands -and $operands.Length -ne 0)
		{
			[int] $i = 0
			try {
				$i = [int]$operands
			}
			catch {
				Write-Host $_
			}

			if ($i -eq 10 -or $i -eq 16)
			{
				if ($Script:Verbose)
				{
					Write-Host "Setting Radix to " $this.radix
				}
				$this.radix = $i
			}
			else {
				Write-Host "Expected a 10 or 16 for the radix opcode, got" $opcode -ForegroundColor Red
			}
		}
		else {
			Write-Host "Expected a value after" $opcode -ForegroundColor Red
		}
	}

	# Handle the FDB opcode
	# While that opcode is a general assembler opcode to declare double-byte values (word)
	# It is only used when defining an image headers, so we will key off that.
	# The header consists of sequences of 4 words, per 'frame' of the image
	# word 0, the width/height value for the frame, with the width in the high byte
	#         and the height in the low byte.  The width is the number of bytes wide
	# word 1, the address of the frame pixels.  In the source, this will be a label
	# word 2, the address of the 'edge' indent values, used for collision.
	#         this is a label, but sometimes it is the label of the pixels, plus an
	#         offset.  I'm not parsing this, as I don't need it.
	# word 3, the x/y origin for the frame.  x in the high byte, y in the low byte.
	#         this is in pixels.
	[void] ParseImageHeader([string] $label, [string] $opcode, [string] $operands)
	{
		if ($label.Length -eq 0)
		{
			if ($this.imageHeaders.Count -eq 0)
			{
				Write-Host "Expecting to be in an Image Header section when parsing an FDB" -ForegroundColor Red
				return
			}
		}
		else
		{
			# Stop any frame parsing, that might have been occuring
			$this.StopFrameParsing()

			# New Image Header.  We support multiple started at the same time
			$this.imageHeaders.Add([ImageHeader]::new($label))

			$this.parsingFrameLabel = ""
			$this.parsingByteIndex = 0
			$this.parsingImageHeaderFrameComponent = 0

			if ($Script:Verbose)
			{
				Write-Host "Parsing Image $label"
			}
		}

		if ($null -ne $operands -and $operands.Length -ne 0)
		{
			$values = $operands -split ","

			[ref] $imageHeader = $this.imageHeaders[$this.imageHeaders.Count - 1]

			for ($i = 0; $i -lt $values.Count; $i++)
			{
				switch ($this.parsingImageHeaderFrameComponent) {
					0 {
						# On the width / height value
						[uint] $t = $this.GetUInt($values[$i])
						$imageHeader.Value.frames.Add([ImageFrame]::new())
						$lastIndex = $imageHeader.Value.frames.Count - 1;
						$imageHeader.Value.frames[$lastIndex].byteWidth = [Math]::Floor($t / 256)
						$imageHeader.Value.frames[$lastIndex].height = [Math]::Floor($t % 256)

						$this.parsingImageHeaderFrameComponent++
					}
					1 {
						# On the label entry
						$lastIndex = $imageHeader.Value.frames.Count - 1;
						$imageHeader.Value.frames[$lastIndex].label = $values[$i]
						$this.parsingImageHeaderFrameComponent++
					}
					2 {
						# On the edge entry
						$this.parsingImageHeaderFrameComponent++
					}
					3 {
						# On the origin entry
						[uint] $t = $this.GetUInt($values[$i])
						$lastIndex = $imageHeader.Value.frames.Count - 1;
						$imageHeader.Value.frames[$lastIndex].originX = [Math]::Floor($t / 256)
						$imageHeader.Value.frames[$lastIndex].originY = [Math]::Floor($t % 256)

						$this.parsingImageHeaderFrameComponent = 0

					}
					Default {}
				}
			}
		}
	}

	# Stop the frame parsing, if it was active.
	# Overall, if this 'hits', it is an error, but we continue on
	[void] StopFrameParsing()
	{
		if ($this.parsingFrameLabel.Length -ne 0)
		{
			# Ok, well.  We hit a new label, and we didn't finish the parsing of the frame
			# This is an issue with some of the input data
			# I'm going to mark the previous one as 'complete' and move on
			[bool] $found = $false
			foreach ($imageHeader in $this.imageHeaders)
			{
				# Is this header already completed?
				if ($imageHeader.complete -eq $false)
				{
					for ($j = 0; $j -lt $imageHeader.frames.Count; $j++)
					{
						[ref] $frame = $imageHeader.frames[$j]
						# Is this frame already completed?
						if ($frame.Value.complete -eq $false)
						{
							if ($frame.Value.label -eq $this.parsingFrameLabel)
							{
								Write-Host "Stopping frame $($frame.Value.label) for $($imageheader.label), early" -ForegroundColor Red
								$frame.Value.complete = $true
								$found = $true
								break
							}
						}
					}
				}

				# Did we find the frame?
				if ($found -eq $true)
				{
					break
				}
			}
			$this.parsingFrameLabel = ""
		}
	}

	# Parse a image frame(s)
	# This expects that we have parsed an image header, and this will fill in the frame data
	# for that image
	[void] ParseImageFrame([string] $label, [string] $opcode, [string] $operands)
	{
		if ($this.imageHeaders.Count -eq 0)
		{
			# If we don't have a image we are parsing into, just skip
			# We are probaly passing over the trailing edge data.
			return
		}

		# Do we have a label?  If so, it is the start of the frame data
		if ($label.Length -ne 0)
		{
			# Stop any frame parsing, that might have been occuring
			$this.StopFrameParsing()
			$this.parsingFrameLabel = $label
		}

		[ref] $parsingFrame = $null
		# Find the frame in one of the headers, that matches the label
		foreach ($imageHeader in $this.imageHeaders)
		{
			# Is this header already completed?
			if ($imageHeader.complete -eq $false)
			{
				for ($j = 0; $j -lt $imageHeader.frames.Count; $j++)
				{
					[ref] $frame = $imageHeader.frames[$j]
					# Is this frame already completed?
					if ($frame.Value.complete -eq $false)
					{
						if ($frame.Value.label -eq $this.parsingFrameLabel)
						{
							# Have we started the databytes yet?
							if ($null -eq $frame.Value.dataBytes)
							{
								# Create some
								$this.parsingByteIndex = 0
								[uint] $size = $frame.Value.byteWidth * $frame.Value.height
								$frame.Value.dataBytes = [byte[]]::new($size)
								if ($Script:Verbose)
								{
									Write-Host "Parsing frame $j at label $label"
								}
							}
							$parsingFrame = $frame
							break
						}
					}
				}
			}

			# Did we find the frame?
			if ($null -ne $parsingFrame.Value)
			{
				break
			}
		}

		# It can be the case, where we hit a label, it it is not frame data, it is most likely the edge data,
		# which we just want to skip
		if ($null -eq $parsingFrame.Value)
		{
			return
		}

		# Put the bytes, into the frame we matched
		if ($null -ne $operands -and $operands.Length -ne 0)
		{
			$values = $operands -split ","

			[int] $byteIndex = $this.parsingByteIndex

			[ref] $destBytes = $parsingFrame.Value.dataBytes
			for ($i = 0; $i -lt $values.Count; $i++)
			{
				[uint] $t = $this.GetUInt($values[$i])
				$destBytes.Value[$byteIndex] = [byte]$t
				$byteIndex++
				if ($byteIndex -ge $destBytes.Value.Count)
				{
					# We have read all the bytes we need
					if ($Script:Verbose)
					{
						Write-Host "Completed frame $($this.parsingFrameLabel), read $byteIndex bytes"
					}

					$parsingFrame.Value.complete = $true
					$this.parsingFrameLabel = ""
					break
				}
			}
			$this.parsingByteIndex = $byteIndex
		}
	}

	# Write any completed images
	[void] WriteImage()
	{
		foreach($entry in $this.imageHeaders)
		{
			if ($entry.written -eq $false)
			{
				if ($entry.CheckComplete())
				{
					[string] $path = $entry.label.ToLower() + ".flc"

					if ($Script:Verbose)
					{
						Write-Host "Writing image" $path
					}

					[FLIC]::Write($path, $entry, $this.palette)

					$entry.written = $true
					# Should we just remove it from the array?
				}
			}
		}
	}

	# Check to see in there were any incomplete images
	[void] CheckIncomplete()
	{
		foreach($entry in $this.imageHeaders)
		{
			if ($entry.written -eq $false)
			{
				Write-Host "Image $($entry.label), was not completed"
			}
		}
	}

	# Parse the loaded input
	# This is expecting a fairly simple "assembler" style format
	# This follows a "column" format, where the first column is the
	# label field, the second is the opcode field the third
	# is the operand(s) and the forth or really, all the way to the eol,
	# is considered a comment
	#
	# eol comments can start with a ; or a *, if it is the first
	# character on the line, else, it must be in the comment field
	# In the latter case, the character is not necessarily needed
	[bool] Parse()
	{
		[bool] $result = $true
		[bool] $done = $false
		[int] $lineIndex = 0

		[int] $lineCount = $this.sourceLines.Count

		# We have to track the radix settings
		# This controls whether or not a 'plain' number is hex or decimal
		# Any number prefixed by $, is always hex

		$this.radix = 16

		if ($lineCount -ne 0)
		{
			while ($done -eq $false) {
				$line = $this.sourceLines[$lineIndex]
				if ($line -match "^[\*;]" -eq $true)
				{

				}
				else
				{
					# Split the lines into the fields
					[string] $label, $opcode, $operands = ($line -split "\s+")

					if ($null -ne $opcode -and $opcode.Length -ne 0)
					{
						if ($opcode -like "radix")
						{
							$this.ParseRadix($opcode, $operands)
						}
						elseif ($opcode -like "FDB") {
							$this.ParseImageHeader($label, $opcode, $operands)
						}
						elseif ($opcode -like "FCB") {
							$this.ParseImageFrame($label, $opcode, $operands)
						}
					}
				}

				# Write any completed images
				$this.WriteImage()

				$lineIndex = $lineIndex + 1
				if ($lineIndex -eq $lineCount)
				{
					$done = $true
				}
			}
		}

		$this.CheckIncomplete()

		return $result
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

	# Create the palette we will attach to all the extracted images
	# The values come from the PALETTE label in SAMTABLE.SRC, in the
	# original source.  I didn't feel like it was necessary to parse that
	# file, just to get these values.
	# The Williams hardware seems to use a single byte for a palette
	# entry, with Red defined by bits 0-2, Green defined by 3-5 and
	# Blue defined by 6-7.
	# I have two simple conversions to 256-bit-per-component
	# color, both look 'ok', it is hard to tell how the original
	# hardware scaled the values for the final output.
	# Maybe a peek at the Williams emulation code in MAME might
	# show a more complex algorithm.
	[void] CreatePalette()
	{
		for ($i = 0; $i -lt $this.palette.colors.Count; $i++)
		{
			$this.palette.colors[$i] = @{}
		}

		# Shift and 'fill'. Colors appear a bit 'light'
		#		[byte] $rgscale = 31
		#		[byte] $rg7 = (32 * 7) + $rgscale
		#		[byte] $rg6 = (32 * 6) + $rgscale
		#		[byte] $rg5 = (32 * 5) + $rgscale
		#		[byte] $rg4 = (32 * 4) + $rgscale
		#		[byte] $rg3 = (32 * 3) + $rgscale
		#		[byte] $rg2 = (32 * 2) + $rgscale
		#		[byte] $rg1 = (32 * 1) + $rgscale
		#		[byte] $rg0 = 0

		#		[byte] $bscale = 61;
		#		[byte] $b3 = (64 * 3) + $bscale
		#		[byte] $b2 = (64 * 2) + $bscale
		#		[byte] $b1 = (64 * 1) + $bscale
		#		[byte] $b0 = 0

		# Scale in FP, then round.  Colors are darker
		$rgscale = (255 / 7)
		[byte] $rg7 = [Math]::Floor(($rgscale * 7))
		[byte] $rg6 = [Math]::Floor(($rgscale * 6))
		[byte] $rg5 = [Math]::Floor(($rgscale * 5))
		[byte] $rg4 = [Math]::Floor(($rgscale * 4))
		[byte] $rg3 = [Math]::Floor(($rgscale * 3))
		[byte] $rg2 = [Math]::Floor(($rgscale * 2))
		[byte] $rg1 = [Math]::Floor(($rgscale * 1))
		[byte] $rg0 = 0

		$bscale = (255 / 3);
		[byte] $b3 = [Math]::Floor(($bscale * 3))
		[byte] $b2 = [Math]::Floor(($bscale * 2))
		[byte] $b1 = [Math]::Floor(($bscale * 1))
		[byte] $b0 = 0

		# black
		$this.palette.colors[0]= [ColorEntry]::new($rg0,$rg0,$b0)

		# yellow.  Note this this is swapped from the original palette, where it was white
		# It will be translated in the pixel writer
		$this.palette.colors[1] = [ColorEntry]::new($rg7,$rg6,$b0)

		# cream
		$this.palette.colors[2] = [ColorEntry]::new($rg7,$rg7,$b2)

		# salmon pink
		$this.palette.colors[3] = [ColorEntry]::new($rg6,$rg5,$b2)

		# tan grey
		$this.palette.colors[4] = [ColorEntry]::new($rg5,$rg5,$b2)

		# grey
		$this.palette.colors[5] = [ColorEntry]::new($rg4,$rg4,$b2)

		# blue-grey
		$this.palette.colors[6] = [ColorEntry]::new($rg2,$rg3,$b2)

		# special effect
		$this.palette.colors[7] = [ColorEntry]::new(0,0,0)

		# special effect
		$this.palette.colors[8] = [ColorEntry]::new(0,0,0)

		# blue-intense
		$this.palette.colors[9] = [ColorEntry]::new($rg1,$rg1,$b3)

		# dark grey
		$this.palette.colors[10] = [ColorEntry]::new($rg0,$rg2,$b1)

		# dark purple
		$this.palette.colors[11] = [ColorEntry]::new($rg3,$rg1,$b1)

		# burgundy
		$this.palette.colors[12] = [ColorEntry]::new($rg5,$rg0,$b0)

		# red
		$this.palette.colors[13] = [ColorEntry]::new($rg7,$rg0,$b0)

		# special effect
		$this.palette.colors[14] = [ColorEntry]::new(0,0,0)

		# white.  Note this this is swapped from the original palette, where it was yellow
		# It will be translated in the pixel writer
		$this.palette.colors[15] = [ColorEntry]::new($rg7,$rg7,$b3)

		# Transparent color for FLC
		$this.palette.colors[255] = [ColorEntry]::new(255,0,255)
	}

	# Run the script
	[void] Run()
	{
		# Create the palette we will be using
		$this.CreatePalette()

		if ($this.GetFile($script:SourcePath) -eq $true)
		{
			$this.Parse()
		}
	}
}

# Note.  I like using a class to run the guts of a Powershell script, because
# classes don't have the odd-ball, hidden, return value accumulation issues.

# Create the processor
$app = [App]::new()

# Run it!
$app.Run()

