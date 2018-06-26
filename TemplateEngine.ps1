If (-not $ClassGenFunctions_Included) {
    . "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\ClassGenFunctions.ps1"
}

$TemplateEngineModule = CreateObject @()

AddMethodsToObject $TemplateEngineModule @{

    renderTemplate = {
        param([string] $template, [Hashtable] $arguments)

        $lineEndings = "`n"

        $lines = $this.getLines($template)

        While ($this.containsKeyword($lines, '@ForEach'))
        {
            $lines = $this.replaceForEach($lines, $arguments)
        }

        While ($this.containsKeyword($lines, '@If'))
        {
            $lines = $this.replaceIf($lines, $arguments)
        }

        $rendered = $lines -Join $lineEndings
        
        $this.replaceArguments($rendered, $arguments)
    }

    trimLines = {
        param($str)

        $lineEndings = "`n"

        $lines = $this.getLines($str) | ForEach-Object { $_.Trim() }
        $lines -Join $lineEndings
    }

    getLines = {
        param([string] $str)

        $lineEndings = "`n"
        
        $str.Replace("`r", "").Split($lineEndings)
    }

    containsKeyword = {   
        param([string[]] $lines, [string] $keyword)

        ForEach ($line in $lines)
        {
            If ($line -Match ($keyword + '\b')) 
            {
                return $true
            }
        }
        return $false
    }

    replaceForEach = {
        param([string[]] $lines, [Hashtable] $arguments)

        $ix1 = 0..($lines.Count - 1) | Where-Object { $lines[$_] -Match '@ForEach\b' } | Select-Object -first 1
        $ix2 = 0..($lines.Count - 1) | Where-Object { $lines[$_] -Match '@End\b' } | Select-Object -first 1
    
        $forEachLine = $lines[$ix1]
        $innerRange = $lines[($ix1 + 1)..($ix2 - 1)]

        # PARSE ForEach LINE
        $parseResult = $this.parseForEach($forEachLine, $arguments)

        $container = $parseResult.Item1
        $separator = $parseResult.Item2
        $isArray = $container -is [array]

        # SET $BODY

        If ($isArray) {
            $body = $innerRange.replace('$', '`$').replace('`$(`$_', '$($_').replace('`$_', '$_')
        }
        Else {
            $temp = $innerRange.replace('$', '`$')

            $keyRegex = '`\$key\b'
            $temp = $temp -Replace $keyRegex, '$key'
            
            $valueRegex = '`\$value\b'
            $body = $temp -Replace $valueRegex, '$value'        
        }

        # EVALUATE $BODY FOR EACH $CONTAINER MEMBER

        $ix = 0
        $lastIx = $container.count - 1
        $bodySep = $body + $separator

        $thisRange = $container.GetEnumerator() | ForEach-Object {
            If (-not $isArray) {
                $key = $_.Key
                $value = $_.Value
            }
            
            If ($separator -eq "" -or $ix -eq $lastIx) {
                Invoke-Expression "`"$body`""
            }
            Else {
                Invoke-Expression "`"$bodySep`""
            }
            ++ $ix
        }

        # ASSEMBLE ALL PARTS 

        # Start range
        If ($ix1 -gt 0) {
            $startRange = $lines[0..($ix1 - 1)]
        } Else {
            $startRange = @()
        }

        # End range
        If ($ix2 -lt $lines.Count - 1) {
            $endRange = $lines[($ix2 + 1)..($lines.Count - 1)]
        } Else {
            $endRange = @()
        }

        $startRange + $thisRange + $endRange
    }

    # Syntax: @ForEach $_ in <$container> [-backtick | -comma]
    # Return tuple (container object, separator or "")
    parseForEach = {
        param([string] $forEachLine, [Hashtable] $arguments)

        $t = [System.Management.Automation.PSParser]::Tokenize($forEachLine, [ref] $null)

        $countCorrect = ($t.Count -eq 4) -or ($t.Count -eq 5)
        If (-not $countCorrect) {
            throw "Incorrect syntax (wrong number of parameters): $forEachLine"
        }

        $for = $t[0]
        $under = $t[1]
        $in = $t[2]
        $cont = $t[3]
        $mandatoryCorrect = ($this.isVariable($for)) -and ($this.isVariable($under)) -and ($this.isCommand($in)) -and ($this.isVariable($cont)) -and `
                            ($under.Content -eq "_") -and ($in.Content -eq "in")
        
        # Handle optional parameter
        If ($t.Count -eq 4) {    
            $optionalCorrect = $true
            $separator = ""
        } Else {
            $sep = $t[4]
            $optionalCorrect = ($this.isCommandParameter($sep)) -and ($sep.Content -in @("-backtick", "-comma"))
            
            switch ($sep.Content) {
                "-backtick" {
                    $separator = ' ``'
                }
                "-comma" {
                    $separator = ","
                }
            }
        }
        
        $correct = $mandatoryCorrect -and $optionalCorrect
        If (-not $correct) {
            throw "Incorrect syntax: $forEachLine"
        }

        # Evaluate container
        [Tuple]::Create($arguments[$cont.Content], $separator)    
    }

    replaceIf = {
        param([string[]] $lines, [Hashtable] $arguments)

        # SET $BODY
        $ix1 = 0..($lines.Count - 1) | Where-Object { $lines[$_] -Match '@If\b' } | Select-Object -first 1
        $ix2 = 0..($lines.Count - 1) | Where-Object { $lines[$_] -Match '@EndIf\b' } | Select-Object -first 1
        $innerRange = $lines[($ix1 + 1)..($ix2 - 1)]
        $body = $innerRange.replace('$', '`$').replace('`$(`$_', '$($_').replace('`$_', '$_')

        # EVALUATE CONDITION
        $ifLine = $lines[$ix1]
        $condition = $this.parseIf($ifLine, $arguments)

        # EVALUATE $BODY IF CONDITION IS SATISFIED
        If ($condition) {
            $thisRange = Invoke-Expression "`"$body`""
        } Else { 
            $thisRange = ""
        }

        # ASSEMBLE ALL PARTS 

        # Start range
        If ($ix1 -gt 0) {
            $startRange = $lines[0..($ix1 - 1)]
        } Else {
            $startRange = @()
        }

        # End range
        If ($ix2 -lt $lines.Count - 1) {
            $endRange = $lines[($ix2 + 1)..($lines.Count - 1)]
        } Else {
            $endRange = @()
        }

        $startRange + $thisRange + $endRange
    }

    # Return evaluated condition
    parseIf = {
        param([string] $ifLine, [Hashtable] $arguments)

        $t = [System.Management.Automation.PSParser]::Tokenize($ifLine, [ref] $null)

        $if = $t[0]
        $cond = $t[1]
        $correct = ($t.Count -eq 2) -and ($this.isVariable($if)) -and ($this.isVariable($cond)) -and ($if.Content -eq "If")

        If (-not $correct) {
            throw "Incorrect syntax: $ifLine"
        }

        # Evaluate condition
        $arguments[$t[1].Content]
    }

    isVariable = {
        param($token)

        $token.Type -eq [System.Management.Automation.PSTokenType]::Variable
    }

    isCommand = {
        param($token)

        $token.Type -eq [System.Management.Automation.PSTokenType]::Command
    }

    isCommandParameter = {
        param($token)

        $token.Type -eq [System.Management.Automation.PSTokenType]::CommandParameter
    }

    replaceArguments = {
        param([string] $template, [Hashtable] $arguments)    

        $rendered = $template
        $arguments.GetEnumerator() | ForEach-Object {
            $regex = '\$' + "$($_.Key)" + '\b'
            $rendered = $rendered -Replace $regex, $_.Value 
        }

        $rendered
    }
}
