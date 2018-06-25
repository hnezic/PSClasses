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

# ARGUMENTS

$ArgumentsClass = CreateSimpleClass @("argumentsStr", "variables")

$ArgumentsClass.addMethods( @{

    init = {
    
        param([string] $argumentsStr)
            
        $this.argumentsStr = $argumentsStr
    
        $extTokensColl = $this.createExtendedTokens()
        $extTokens = $extTokensColl.array
    
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

    # Return array of ExtendedToken objects
    # The method uses $this.argumentsStr variable
    createExtendedTokens = 
    {
        $tokens = [System.Management.Automation.PSParser]::Tokenize($this.argumentsStr, [ref] $null)

        $currentLevel_ = 0
        $currentLevel = [ref] $currentLevel_
        
        If ($tokens.Count -gt 0) 
        {
            $rangeColl = New_ "Collection" { param($_) $_.init( 0..($tokens.Count-1) ) }
            $extTokensColl = $rangeColl.map( 
            {
                param($index)

                $token = $tokens[$index]
                If ($token.Type -eq [System.Management.Automation.PSTokenType]::Operator) {
                    Switch ($token.Content) {
                        "[" {
                            New_ "ExtendedToken" { param($_) $_.init($token, $index, $currentLevel.value + 1) }
                            ++ $currentLevel.value
                        }
                        "]" {
                            New_ "ExtendedToken" { param($_) $_.init($token, $index, $currentLevel.value) }
                            -- $currentLevel.value
                        }
                        default {
                            New_ "ExtendedToken" { param($_) $_.init($token, $index, $currentLevel.value) }
                        }
                    }
                } 
                ElseIf ($token.Type -eq [System.Management.Automation.PSTokenType]::GroupStart) 
                {
                    New_ "ExtendedToken" { param($_) $_.init($token, $index, $currentLevel.value + 1) }
                    ++ $currentLevel.value
                }
                ElseIf ($token.Type -eq [System.Management.Automation.PSTokenType]::GroupEnd) 
                {
                    New_ "ExtendedToken" { param($_) $_.init($token, $index, $currentLevel.value) }
                    -- $currentLevel.value
                }
                Else {
                    New_ "ExtendedToken" { param($_) $_.init($token, $index, $currentLevel.value) }
                }
            }.GetNewClosure())
        } Else {
            $extTokensColl = New_ "Collection" { param($_) $_.init( @() ) }
        }
        
        # Check current level
        If ($currentLevel_ -ne 0) {
            $this.throwException("Syntax error: unmatched brackets")
        }

        $extTokensColl
    
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
