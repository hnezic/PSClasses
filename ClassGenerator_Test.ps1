$folder = Split-Path -Parent $MyInvocation.MyCommand.Path 
. "$folder\ClassGenerator.ps1"

Describe "IntCounter class hierarchy" {

    BeforeEach {

        # IntCounter

        CreateClass "IntCounter" $null '[int] $value' @{
            
            init0 = {
                $this.value = 0
            }

            increment = {
                $this.value += 1
            }

            reset = {
                $this.value = 0
            }
        }

        # ModularCounter

        CreateClass "ModularCounter" -extends "IntCounter" '[int] $modulus' @{

            # Same as generated constructor, but with argument checks
            init = {
                param([int] $value, [int] $modulus)

                # Call generated constructor
                $this.ModularCounter_gen_init($value, $modulus)

                If ($modulus -lt 1) {
                    throw "ModularCounter: modulus bad"
                }
                If ($value -lt 0 -or $value -gt $modulus) {
                    throw "ModularCounter: value bad"
                } 
            }

            # A simplified constructor
            init0 = {
                param([int] $modulus)

                $this.ModularCounter_init(0, $modulus)
            }

            # Override superclass method
            increment = {
                If ($this.value -eq $this.modulus - 1) {
                    # Call inherited method
                    $this.reset()
                } Else {
                    # Call superclass version
                    $this.IntCounter_increment()
                }
            }
        }

        # BoundedCounter

        CreateClass "BoundedCounter" -extends "IntCounter" '[int] $bound' @{

            # Same as generated constructor, but with argument checks
            init = {
                param([int] $value, [int] $bound)

                # Call superclass constructor
                $this.IntCounter_init($value)
                
                $this.bound = $bound

                If ($bound -lt 1) {
                    throw "BoundedCounter: bound bad"
                }
                If ($value -lt 0 -or $value -gt $bound) {
                    throw "BoundedCounter: value bad"
                } 
            }

            # Override superclass method
            increment = {
                If ($this.value -lt $this.bound) {
                    # Call superclass version
                    $this.IntCounter_increment()
                }
            }
        }

        # Objects

        $counter = New "IntCounter" { $self.init(0) }
        $counter2 = New "IntCounter" { $self.init0() }
        $modCounter = New "ModularCounter" { $self.init(6, 10) }
        $modCounter2 = New "ModularCounter" { $self.init0(20) }
        $bCounter = New "BoundedCounter" { $self.init(7, 10) }

        $counter, $counter2, $modCounter, $modCounter2, $bCounter
    }

    It "IntCounter variables & methods" {
        $counter.value | Should Be 0
        $counter.increment()
        $counter.increment()
        $counter.increment()
        $counter.value | Should Be 3
        $counter.reset()
        $counter.value | Should Be 0
        $counter2.value | Should Be 0
    }

    It "ModularCounter: call gen. constructor, call other constructor, override, call superclass version" {
        $modCounter.value | Should Be 6
        $modCounter.modulus| Should Be 10
        $modCounter.increment()
        $modCounter.increment()
        $modCounter.increment()
        $modCounter.value | Should Be 9
        $modCounter.increment()
        $modCounter.value | Should Be 0
        $modCounter2.value | Should Be 0
        $modCounter2.modulus | Should Be 20
        { New "ModularCounter" { $self.init(0, 0) } } | Should Throw "ModularCounter: modulus bad"
    }

    It "BoundedCounter: call superclass constructor, override, call superclass version" {
        $bCounter.value | Should Be 7
        $bCounter.bound | Should Be 10
        $bCounter.increment()
        $bCounter.increment()
        $bCounter.increment()
        $bCounter.increment()
        $bCounter.increment()
        $bCounter.value | Should Be 10
    }
}

# -------------------------------------------------------------------------------------------------------------------

Describe "HelpHandler class hierarchy" {

    "Chain of responsibility design pattern"

    BeforeEach {

        # HelpHandler
        CreateClass "HelpHandler" $null '[PSCustomObject] $successor, [string] $topic' @{

            setHandler = {
                
                param([PSCustomObject] $successor, [string] $topic)

                $this.successor = $successor
                $this.topic = $topic
            }

            hasHelp = {
                $this.topic -ne "No topic"
            }

            handleHelp = {
                If ($this.successor -ne $null) {
                    $this.successor.handleHelp()
                }
            }
        }

        # Widget
        CreateClass "Widget" -extends "HelpHandler" '[PSCustomObject] $parent' @{

            init = {
                param([PSCustomObject] $parent, [string] $topic)

                # Widget's parent is HelpHandler's successor
                $this.HelpHandler_init($parent, $topic)
                $this.parent = $parent
            }

            handleHelp = {
  
                $this.HelpHandler_handleHelp()
            }
        }

        # Button
        CreateClass "Button" -extends "Widget" '' @{

            init = {
                param([PSCustomObject] $parent, [string] $topic)

                $this.Widget_init($parent, $topic)
            }

            handleHelp = {
                
                If ($this.hasHelp()) {
                    "Button: " + $this.topic
                } Else {
                    $this.Widget_handleHelp()
                }
            }
        }

        # Dialog
        CreateClass "Dialog" -extends "Widget" '' @{

            init = {

                # Dialog doesn't have a parent
                param([PSCustomObject] $helpHandler, [string] $topic)

                $this.Widget_init($null, "No topic")
                $this.setHandler($helpHandler, $topic)
            }
            
            handleHelp = {
                
                If ($this.hasHelp()) {
                    "Dialog: " + $this.topic
                } Else {
                    $this.Widget_handleHelp()
                }
            }
        }

        # Application
        CreateClass "Application" -extends "HelpHandler" '' @{

            init = {

                param([string] $topic)

                $this.HelpHandler_init($null, $topic)
            }

            handleHelp = {
                "Application: " + $this.topic
            }
        }

        # Objects
        $app = New "Application" { $self.init("Application topic") }
        $dialog = New "Dialog" { $self.init($app, "Print topic") }
        $dialog2 = New "Dialog" { $self.init($app, "No topic") }
        
        $button = New "Button" { $self.init($dialog, "Paper orientation topic") }
        $button2 = New "Button" { $self.init($dialog, "No topic") }
        $button3 = New "Button" { $self.init($dialog2, "No topic") }
        
        $button, $button2, $button3
    }

    It "Button handles the request" {
        $button.handleHelp() | Should Be "Button: Paper orientation topic"
    }

    It "Dialog handles the request" {
        $button2.handleHelp() | Should Be "Dialog: Print topic"
    }

    It "Application handles the request" {
        $button3.handleHelp() | Should Be "Application: Application topic"
    }
}

# -------------------------------------------------------------------------------------------------------------------

Describe "Person class hierarchy" {

    BeforeEach {
        
        # Person
        
        CreateClass "Person" $null '[string] $name, [int] $age, [boolean] $male' @{
            
            reportAge = {
                "My age is $($this.age)"
            }
            
            reportName = {
                "My name is $($this.name)"
            }
        }
        
        $person = New "Person" { $self.init("John Smith", 23, $true) }
        $person2 = New "Person" { $self.init("Ivana Ivanović", 18, $false) }
        $person3 = New Person { $self.init("Paul White", 34, $true) }

        $person, $person2, $person3

        # ------------------------------------------------------------------------------------------

        # SpecialPerson

        CreateClass "SpecialPerson" -extends "Person" -methods @{

            reportName = {
                "My name is $($this.name). I am a special one."
            }
        }

        $specialPerson = New "SpecialPerson" { $self.init("Jose Mourinho", 55, $true) }
        $specialPerson

        # ------------------------------------------------------------------------------------------

        # Student

        CreateClass "Student" -extends "Person" -variables '$school, $city' @{

            reportAge = {
                "My age is $($this.age). I am a student."
            }
            
            reportName = {
                "My name is $($this.name). I am a student."
            }
            
            reportSchool = {
                "I am studying on $($this.school)."
            }
        }

        $student = New "Student" { $self.init("Ivan Marković", 20, $true, "FER", "Zagreb") }
        $student2 = New Student { $self.init("Tea Petrović", 21, $false, "FER", "Zagreb") }

        $student, $student2
    }

    It "Person method results" {
        $person.reportName() | Should Be "My name is John Smith"
        $person2.reportName() | Should Be "My name is Ivana Ivanović"
        $person3.reportName() | Should Be "My name is Paul White"
        $person.reportAge() | Should Be "My age is 23"
        $person2.reportAge() | Should Be "My age is 18"
        $person3.reportAge() | Should Be "My age is 34"
    }

    It "Person instance variables" {
        $person.name | Should Be "John Smith"
        $person2.name | Should Be "Ivana Ivanović"
        $person3.name | Should Be "Paul White"
        $person.age | Should Be 23
        $person2.age | Should Be 18
        $person3.age | Should Be 34
    }

    It "SpecialPerson inherits Person, no new variables" {
        $specialPerson.name | Should Be "Jose Mourinho"
        $specialPerson.reportAge() | Should Be "My age is 55"
        $specialPerson.reportName() | Should Be "My name is Jose Mourinho. I am a special one."
    }

    It "Student method results" {
        $student.reportAge() | Should Be "My age is 20. I am a student."
        $student.reportName() | Should Be "My name is Ivan Marković. I am a student."
        $student.reportSchool() | Should Be "I am studying on FER."
        $student2.reportAge() | Should Be "My age is 21. I am a student."
        $student2.reportName() | Should Be "My name is Tea Petrović. I am a student."
    }

    It "Student instance variables" {
        $student.name | Should Be "Ivan Marković"
        $student.age | Should Be 20
        $student.school | Should Be "FER"
        $student.city | Should Be "Zagreb"
    }

    It "Invokes same method on each object" {
        $names = "My name is John Smith", "My name is Ivana Ivanović", "My name is Ivan Marković. I am a student."
        $person, $person2, $student | ForEach-Object { $_.reportName() } | Should Be $names
    }

}

# -------------------------------------------------------------------------------------------------------------------

Describe "Config class hierarchy (without methods)" {

    BeforeEach {
        CreateClass "Config" $null '$drive, $certSubject, $certAccount'
        
        CreateClass "WebConfig" -extends "Config" '$port'

        # Alternative syntax

        CreateClass -name "Config2" -variables '$drive, $certSubject, $certAccount'   # without super class
        
        CreateClass -name "WebConfig2" -extends "Config2" -variables '$port'

        # Objects

        $config = New "Config" { $self.init("C:", "CN=johnsmith", "johnsmith") }
        $webConfig = New "WebConfig" { $self.init("D:", "CN=annbrown", "annbrown", 443) }

        $config2 = New "Config2" { $self.init("C:", "CN=johnsmith", "johnsmith") }
        $webConfig2 = New "WebConfig2" { $self.init("D:", "CN=annbrown", "annbrown", 443) }

        $config, $webConfig, $config2, $webConfig2
    }

    It "Config instance variables" {
        $config.drive | Should Be "C:"
        $config.certSubject | Should Be "CN=johnsmith"
        $config.certAccount | Should Be "johnsmith"
    }

    It "WebConfig instance variables" {
        $webConfig.drive | Should Be "D:"
        $webConfig.certSubject | Should Be "CN=annbrown"
        $webConfig.certAccount | Should Be "annbrown"
        $webConfig.port | Should Be 443
    }

    It "Config2 instance variables" {
        $config2.drive | Should Be "C:"
        $config2.certSubject | Should Be "CN=johnsmith"
        $config2.certAccount | Should Be "johnsmith"
    }

    It "WebConfig2 instance variables" {
        $webConfig2.drive | Should Be "D:"
        $webConfig2.certSubject | Should Be "CN=annbrown"
        $webConfig2.certAccount | Should Be "annbrown"
        $webConfig2.port | Should Be 443
    }
}

# -------------------------------------------------------------------------------------------------------------------

Describe "Actions class (no instance variables) hierarchy" {

    BeforeEach {
        # Actions class

        CreateClass "Actions" -methods @{
            
            first = {
                param([string] $str)

                $this.second("First: $str")
            }
            
            second = {
                param([string] $str)

                $this.third("Second: $str")
            }
            
            third = {
                param([string] $str)

                "Third: $str"
            }
        }

        $actions = New "Actions" { $self.init() }
        $actions

        # ------------------------------------------------------------------------------------------

        # SecretActions class

        CreateClass "SecretActions" -extends "Actions" -variables '$secret'

        $secretActions = New "SecretActions" { $self.init("The secret of happiness") }
        $secretActions
    }

    It "Actions class" {
        $actions.first("Hello") | Should Be "Third: Second: First: Hello"
    }

    It "SecretActions class" {
        $secretActions.first("Hello") | Should Be "Third: Second: First: Hello"
        $secretActions.secret | Should Be "The secret of happiness"
    }    
}

# -------------------------------------------------------------------------------------------------------------------

Describe "Tokens and Arguments classes" {

    BeforeEach {

        # ExtendedToken2 class

        CreateClass "ExtendedToken2" $null '[System.Management.Automation.PSToken] $token, [int] $index, [int] $level' @{
            
            isComma_level0 = {
                ($this.token.Type -eq [System.Management.Automation.PSTokenType]::Operator) `
                    -and ($this.token.Content -eq ",") -and ($this.level -eq 0)
            }
        
            isVar_level0 = {
                ($this.token.Type -eq [System.Management.Automation.PSTokenType]::Variable) -and ($this.level -eq 0)
            }
        }

        $str = '@ForEach $_ in $container -comma'
        $tokens = [System.Management.Automation.PSParser]::Tokenize($str, [ref] $null)
        $extToken = New "ExtendedToken2" { $self.init($tokens[3], 3, 0) }
        $extToken

        $str2 = '[int[]] $numbers, [string[]] $strings'
        $tokens2 = [System.Management.Automation.PSParser]::Tokenize($str2, [ref] $null)
        $extToken1 = New "ExtendedToken2" { $self.init($tokens2[0], 0, 0) }
        $extToken2 = New "ExtendedToken2" { $self.init($tokens2[1], 1, 0) }
        $extToken3 = New "ExtendedToken2" { $self.init($tokens2[2], 2, 0) }
        $extTokensArray = @($extToken1, $extToken2, $extToken3)

        # ------------------------------------------------------------------------------------------------------------

        # Segment2 class

        CreateClass "Segment2" $null '$index1, $index2, $indexesCorrect, $variables, $variablesCorrect, $variable' @{
            
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
        }

        $segment = New "Segment2" { $self.init($extTokensArray, 0, 1) }
        $segment
    }

    It "ExtendedToken2 instance variables" {
        $extToken.token.Content | Should Be "container"
        $extToken.index | Should Be 3
    }

    It "ExtendedToken2 methods" {
        $extToken.isVar_level0() | Should Be $true
        $extToken.isComma_level0() | Should Be $false
    }

    It "Segment2 (custom constructor) instance variables" {
        $segment.index1 | Should Be 0
        $segment.index2 | Should Be 1
        $segment.indexesCorrect | Should Be $true
        $segment.variablesCorrect | Should Be $true
        $segment.variable | Should Be "numbers"
    }

    It "Segment2 (custom constructor) methods" {
        $segment.isCorrect() | Should Be $true
    }
}

# -------------------------------------------------------------------------------------------------------------------

Describe "Alternative object construction syntax" {

    BeforeEach {

        # Point

        CreateClass "Point" $null '[double] $x, [double] $y' @{

            translate = {
                param([double] $x, [double] $y)

                $this.x += $x
                $this.y += $y
            }

            scale = {
                param([double] $factor)

                $this.x *= $factor
                $this.y *= $factor
            }
        }

        $point1 = $PointClass.new( { $self.init(10, 20) } )
        $point2 = $PointClass.new( { $self.init(5, 8) } )

        $point3 = New_ "Point" { param($self) $self.init(30, 50) }
        $point4 = New_ "Point" { param($_) $_.init(25, 35) }

        $point1, $point2, $point3, $point4
    }

    It "Point variables and methods" {
        $point1.x | Should Be 10
        $point1.y | Should Be 20
        $point1.translate($point2.x, $point2.y) 
        $point1.x | Should Be 15
        $point1.y | Should Be 28

        $point4.x | Should Be 25
        $point4.y | Should Be 35
        $point4.scale(2) 
        $point4.x | Should Be 50
        $point4.y | Should Be 70
    }
}

# -------------------------------------------------------------------------------------------------------------------

Describe "Alternative class inheritance syntax" {

    BeforeEach {

        # Person2
        
        CreateClass "Person2" $null '[string] $name, [string] $phoneNumber'

        # Employee

        CreateClass "Employee" -extends $Person2Class '[int] $employeeNumber, [double] $hourlyPay'

        $employee = New "Employee" { $self.init("Jack Dawkins", "098-123-5678", 2468, 100) }
        $employee
    }

    It "Employee variables" {
        $employee.name | Should Be "Jack Dawkins"
        $employee.phoneNumber | Should Be "098-123-5678"
        $employee.employeeNUmber | Should Be 2468
        $employee.hourlyPay | Should Be 100
    }
}

# -------------------------------------------------------------------------------------------------------------------

Describe "Alternative methods syntax (using addMethods method)" {

    BeforeEach {

        # Collection2
        CreateClass "Collection2" $null '[array] $array'

        $Collection2Class.addMethods( @{

            # Find first element satisfying the predicate
            # Return $null if not found
            find = {
                param([ScriptBlock] $predicate)

                $result = $null

                ForEach ($elem in $this.array)
                {
                    If (& $predicate $elem) {
                        $result = $elem
                        Break
                    }
                }

                $result
            }

            # Returns new Collection2
            map = {
                param([ScriptBlock] $fn)
                
                $mappedArray = @( $this.array | ForEach-Object { & $fn $_ } )
                
                New Collection2 { $self.init($mappedArray) }
            }
        } )

        $collection = New "Collection2" { $self.init(@(10, 20, 30, 40, 50, 30, 10)) }
        $collection2 = $collection.map( { param($item) $item + 100 } )
        $collection, $collection2
    }

    It "Collection2 methods" {
        $collection.find( { param($item) $item -gt 10 -and $item -le 40 } ) | Should Be 20
        $collection.find( { param($item) $item -gt 100 } ) | Should Be $null
        $collection2.array | Should Be @(110, 120, 130, 140, 150, 130, 110)
    }
}

# -------------------------------------------------------------------------------------------------------------------

Describe "Alternative methods syntax (ordered dictionary, PS version >= 2.0)" {
    
    BeforeEach {
        
        # BankAccount
        CreateClass "BankAccount" $null '[string] $accountNumber, [string] $accountName, [double] $balance'

        function BankAccountMethods {

            $methods = Methods_Start

            # -----------------------------------------------------------------------------------------------
        
            $init = {
                param([string] $accountNumber, [string] $accountName, [double] $balance)

                $this.BankAccount_gen_init($accountNumber, $accountName, 0)
            }

            $deposit = {
                
                param([double] $amount)

                If ($amount -gt 0) 
                {
                    $this.balance += $amount
                    $true
                } Else {
                    $false
                }
            }

            $withdraw = {
                
                param([double] $amount)

                If ($amount -le $this.balance) 
                {
                    $this.balance -= $amount
                    $true
                } Else {
                    $false
                }
            }

            # -----------------------------------------------------------------------------------------------
        
            $init, $deposit, $withdraw | Out-Null   # Just to avoid VS Code complaints

            Methods_End $methods
        }
        
        $BankAccountClass.addMethods((BankAccountMethods))

        $account = New "BankAccount" { $self.init("135468", "Jack Dawkins") }
        $account
    }

    It "BankAccount variables and methods" {
        $account.accountNumber | Should Be "135468"
        $account.balance | Should Be 0
        $account.deposit(1000)
        $account.deposit(500)
        $account.balance | Should Be 1500
        $account.withdraw(700)
        $account.balance | Should Be 800
    }
}

# -------------------------------------------------------------------------------------------------------------------

Describe "Unknown class" {

    It "Throws exception if class doesn't exist" {
        { New "MagicalCounter" { $self.init(10, 20) } } | Should Throw "Class MagicalCounter not found!"
    }
}

# -------------------------------------------------------------------------------------------------------------------

Describe "Multiple addMethods calls not allowed" {

    BeforeEach {

        CreateClass "Complex" $null '[double] $real, [double] $imag'

        $ComplexClass.addMethods( @{

            plus = {
                param([PSCustomObject] $other)

                $real = $this.real + $other.real
                $imag = $this.imag + $other.imag
                New "Complex" { $self.init($real, $imag) }
            }
        } )
    }

    It "Throws exception on second addMethods call " {
        {
            $ComplexClass.addMethods( @{

                minus = {
                    param([PSCustomObject] $other)
    
                    $real = $this.real - $other.real
                    $imag = $this.imag - $other.imag
                    New "Complex" { $self.init($real, $imag) }
                }
            } )
        } | Should Throw "Multiple addMethods calls are not allowed!"
    }
}

<#
    Some examples were adapted from following sources:

        Richard E. Pattis: Inheritance in Class Hierarchies
            (https://www.cs.cmu.edu/~pattis/15-1XX/15-200/lectures/inheritancei/)

        Erich Gamma, Richard Helm, Ralph Johnson, John Vissides: Design Patterns
        
        Abdul Rahman Sherzad: Object Oriented Programming with Real World Examples
            (https://www.slideshare.net/oxus20/object-oriented-programming-30241569)
#>
