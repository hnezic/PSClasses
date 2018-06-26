. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\Collection.ps1"

# EXTENDED TOKEN

$ExtendedTokenClass = CreateSimpleClass @("token", "index", "level")

$ExtendedTokenClass.addMethods( @{

    init = {
        param([System.Management.Automation.PSToken] $token, [int] $index, [int] $level)
    
        $this.token = $token
        $this.index = $index
        $this.level = $level    
    }

    isComma_level0 = {
        ($this.token.Type -eq [System.Management.Automation.PSTokenType]::Operator) `
            -and ($this.token.Content -eq ",") -and ($this.level -eq 0)
    }

    isVar_level0 = {
        ($this.token.Type -eq [System.Management.Automation.PSTokenType]::Variable) -and ($this.level -eq 0)
    }
} )

# --------------------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------------

# SEGMENT

$SegmentClass = CreateSimpleClass @("index1", "index2", "indexesCorrect", "variables", "variablesCorrect", "variable")

$SegmentClass.addMethods( @{

    init = {
        param([PSCustomObject[]] $extTokens, [int] $index1, [int] $index2)
        
        $this.index1 = $index1
        $this.index2 = $index2
        $this.indexesCorrect = $index1 -le $index2

        $tokensRange = $extTokens[$index1..$index2]
        $this.variables = @( $tokensRange | Where-Object { $_.isVar_level0() } | ForEach-Object { $_.token.Content } )

        $this.variablesCorrect = $this.variables.Count -eq 1

        If ($this.variablesCorrect) {
            $this.variable = $this.variables[0]
        } Else {
            $this.variable = $null
        }
    }

    isCorrect = {
        $this.indexesCorrect -and $this.variablesCorrect
    }
    
    errorMessage = 
    {
        If (-not $this.indexesCorrect) 
        {
            $message = "Syntax error: missing arguments"
        } 
        ElseIf (-not $this.variablesCorrect) 
        {
            $message = "Syntax error: missing arguments or separators"
        }

        $message
    }
} )

# --------------------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------------

# EXT TOKENS COLLECTION

$ExtTokensCollectionClass = CreateSimpleClass @("currentLevel", "extTokens")

$ExtTokensCollectionClass.addMethods( @{ 

    init = {
        param([string] $argumentsStr)

        $this.currentLevel = 0

        $tokens = [System.Management.Automation.PSParser]::Tokenize($argumentsStr, [ref] $null)

        If ($tokens.Count -gt 0) 
        {
            $this.extTokens = @( 0..($tokens.Count-1) | ForEach-Object { $this.createExtendedToken($tokens[$_], $_) } )
        } 
        Else 
        {
            $this.extTokens = @()
        }
    }

    createExtendedToken = 
    {
        param($token, $index)

        $currentLevel = $this.currentLevel

        If ($token.Type -eq [System.Management.Automation.PSTokenType]::Operator) {
            Switch ($token.Content) {
                "[" {
                    New "ExtendedToken" { $self.init($token, $index, $currentLevel + 1) }
                    $this.currentLevel += 1
                }
                "]" {
                    New "ExtendedToken" { $self.init($token, $index, $currentLevel) }
                    $this.currentLevel -= 1
                }
                default {
                    New "ExtendedToken" { $self.init($token, $index, $currentLevel) }
                }
            }
        } 
        ElseIf ($token.Type -eq [System.Management.Automation.PSTokenType]::GroupStart) 
        {
            New "ExtendedToken" { $self.init($token, $index, $currentLevel + 1) }
            $this.currentLevel += 1
        }
        ElseIf ($token.Type -eq [System.Management.Automation.PSTokenType]::GroupEnd) 
        {
            New "ExtendedToken" { $self.init($token, $index, $currentLevel) }
            $this.currentLevel -= 1
        }
        Else {
            New "ExtendedToken" { $self.init($token, $index, $currentLevel) }
        }
    }

} )

# --------------------------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------------------------

# ARGUMENTS

$ArgumentsClass = CreateSimpleClass @("argumentsStr", "variables")

$ArgumentsClass.addMethods( @{

    init = {
    
        param([string] $argumentsStr)
            
        $this.argumentsStr = $argumentsStr
    
        $extTokensColl = New "ExtTokensCollection" { $self.init($argumentsStr) }
        $extTokens = $extTokensColl.extTokens

        # Check current level
        If ($extTokensColl.currentLevel -ne 0) 
        {
            $this.throwException("Syntax error: unmatched brackets")
        }

        If ($extTokens.Count -gt 0) 
        {
            $segments = $this.createSegments($extTokens)
    
            # Check segments correctness, get variables
            If ($segments.forAll( { param($segment) $segment.isCorrect() } )) {
                $this.variables = $segments.map( { param($segment) $segment.variable } ).array
            } Else {
                # At least one segment is not correct
                $failedSegment = $segments.find( { param($segment) -not $segment.isCorrect() } )
                $this.throwException($failedSegment.errorMessage())
            }
        } Else {
            [string[]] $this.variables = @()
        }
    }

    # -------------------------------------------------------------------------------------------------------

    # Return a Collection of Segment objects
    createSegments = 
    {
        param([PSCustomObject[]] $extTokens)

        # Filter comma tokens on basic level
        $separatorIndexes = @( $extTokens | Where-Object { $_.isComma_level0() } | ForEach-Object { $_.index } )

        If ($separatorIndexes.Count -eq 0) 
        {
            $newSegment = New "Segment" { $self.init($extTokens, 0, $extTokens.Count - 1) }
            New "Collection" { $self.init( @( $newSegment ) ) }
        } 
        Else 
        {
            # Check first and last separator
            $firstTokenIx = 0
            $lastTokenIx = $extTokens.Count - 1

            $firstSeparatorIndex = $separatorIndexes[0]
            $lastSeparatorIndex = $separatorIndexes[$separatorIndexes.Count - 1]

            If ($firstSeparatorIndex -eq $firstTokenIx -or $lastSeparatorIndex -eq $lastTokenIx) {
                $this.throwException("Syntax error: missing arguments")
            }

            $lowIndexes = @( $firstTokenIx ) + @( $separatorIndexes | ForEach-Object { $_ + 1 } )
            $highIndexes = @( $separatorIndexes | ForEach-Object { $_ - 1 } ) + @( $lastTokenIx )

            $segments = @( 0..($lowIndexes.Count - 1) | ForEach-Object { New "Segment" { $self.init($extTokens, $lowIndexes[$_], $highIndexes[$_]) } } )
            
            New "Collection" { $self.init( $segments ) }
        }
    }

    # -------------------------------------------------------------------------------------------------------

    throwException = 
    {
        param([string] $errorStr)

        $exceptionErrorStr = @"
            $errorStr
            Input string: $($this.argumentsStr)
"@
        throw $exceptionErrorStr
    }
} )
