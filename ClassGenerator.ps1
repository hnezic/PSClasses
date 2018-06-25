$classGeneratorFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$classGeneratorFolder\Arguments.ps1"

# CLASS
# The class which represents Class objects

$ClassClass = CreateObject @("className", "super", "allVariablesStr", "variables", "allVariables", "allMethods",
                             "templateObject", "classVarName", "superAllVariables", "methodsAdded")

# ---------------------------------------------------------------------------------------------------------------

function CreateClass {

    # variablesStr: instance variables separated by commas
    # Example: "$name, $age, $male" 
	param(
        [Parameter(Mandatory=$true)]
        [Alias("name")] [string] $className, 
        
        [Parameter(Mandatory=$false)] 
        [Alias("extends")] $super = $null,
        
        [Parameter(Mandatory=$false)] 
        [Alias("variables")] [string] $variablesStr = '',

        [Parameter(Mandatory=$false)] 
        [Alias("methods")] $methodsDict = $null
    )
    
    function JoinVariablesStr
    {
        param([string] $vars1, [string] $vars2)

        If ($vars1.Trim() -eq "" -or $vars2.Trim() -eq "") {
            $vars1 + $vars2
        } Else {
            $vars1 + ", " + $vars2
        }
    }

    $class = $ClassClass.PSObject.copy()
    $class.className = $className

    # SUPERCLASS

    If ($super -is [String]) 
    {
        $class.super = Invoke-Expression ('$' + $super + "Class")
    
        If ($class.super -eq $null) {
            throw "Class $super not found!"
        }
    }
    Else {
        $class.super = $super
    }

    # VARIABLES

    # variables
    $parameters = New "Arguments" { $self.init($variablesStr) }
    $class.variables = $parameters.variables
    
    # allVariablesStr, allVariables, superAllVariables
    If ($class.super -ne $null) {
        If ($class.super.allVariables.Count -ne 0) {
            $class.allVariablesStr = JoinVariablesStr $class.super.allVariablesStr $variablesStr 
        } Else {
            $class.allVariablesStr = $variablesStr
        }
        
        # Check duplicate variables
        If ($class.intersectArrays($class.super.allVariables, $class.variables) -eq $null) 
        {
            $class.allVariables = $class.super.allVariables + $class.variables
        } 
        Else {
            throw "Class $($className): Instance variable(s) cannot override inherited instance variable(s)!"
        }

        $class.superAllVariables = $class.super.allVariables        
    }
    Else {
        $class.allVariablesStr = $variablesStr
        $class.allVariables = $class.variables
        $class.superAllVariables = @()
    }

    # TEMPLATE OBJECT
    $class.templateObject = CreateObject $class.allVariables

    # NAMES
    $class.classVarName = '$' + $className + "Class"

    # CLASS VARIABLE
    New-Variable -Name $class.classVarName.Substring(1) -Value $class -Scope Global -Force

    # METHODS

    $class.methodsAdded = $false

    $class.allMethods = $class.createDict_defaultConstructor()
    If ($class.super -ne $null) 
    {
        $class.copyMethods($class.super.allMethods, $class.allMethods)
    }
    $class.addExtendedMethodsToObject()

    If ($methodsDict -ne $null) 
    {
        $class.addMethods($methodsDict)
    }
}

# --------------------------------------------------------------------------------------------------------

# METHODS
 
function ClassMethods
{
    . "$classGeneratorFolder\TemplateEngine.ps1"

    $methods = Methods_Start

    # -------------------------------------------------------------------------------------------------------

    $new = {
        param([ScriptBlock] $constructor)

        $self = $this.cloneTemplateObject()
        & $constructor
        
        $self
    }

    $new_ = {
        param([ScriptBlock] $constructor)

        $self = $this.cloneTemplateObject()
        & $constructor($self)
        
        $self
    }

    $cloneTemplateObject = {
        $this.templateObject.PSObject.copy()
    }

    # -------------------------------------------------------------------------------------------------------

    $createDict_defaultConstructor = {

        $arguments = @{
            classNameInit__ = $this.className + "_init"
            classNameDefaultInit__ = $this.className + "_gen_init"
            allVariablesStr__ = $this.allVariablesStr
            variables__ = $this.variables
            superAllVariables__ = $this.superAllVariables
            superInit__ = $this.super.className + "_init"          
            inherited__ = $this.super -ne $null                       
        }

        $template = @'
            function CreateExtDict 
            {
                $dict = New-Object System.Collections.Specialized.OrderedDictionary

                $init = {
                    param(
                        $allVariablesStr__
                    )              
    
                    # Call constructor of the base class
                    @If $inherited__
                        $this.$superInit__(
                            @ForEach $_ in $superAllVariables__ -comma
                                $$_
                            @End
                        )
                    @EndIf
                    
                    # Copy parameters specific to this class to object
                    @ForEach $_ in $variables__
                        $this.$_ = $$_
                    @End
                }
            
                $init | Out-Null
            
                $dict.Add("init", (New_ "Method" { param($_) $_.init($init, "Constructor") } ))
                $dict.Add("$classNameInit__", (New_ "Method" { param($_) $_.init($init, "SuperConstructor") } ))
                $dict.Add("$classNameDefaultInit__", (New_ "Method" { param($_) $_.init($init, "SuperConstructor") } ))

                $dict
            }     
'@
        $createDictFnStr = $TemplateEngineModule.renderTemplate($template, $arguments)
        Invoke-Expression $createDictFnStr

        CreateExtDict
    
    }.GetNewClosure()

    # -------------------------------------------------------------------------------------------------------

    $addMethods = {

        param($methodsDict)

        If ($this.methodsAdded) {
            throw "Multiple addMethods calls are not allowed!"
        }

        # Convert $methodsDict to OrderedDictionary if needed
        If ($methodsDict -is [Hashtable]) 
        {
            $methodsDict = HashtableToOrderedDict($methodsDict)
        }

        # Check correctness of new method names, throw exception if some are incorrect
        $this.checkMethodNames($methodsDict, $this.allMethods)

        # If needed, remove init and <className>_init from $this.allMethods
        If ($methodsDict.Contains("init")) {
            $this.allMethods.Remove("init")
            $this.allMethods.Remove($this.className + "_init")
        }

        # Create extended dictionary
        $extMethodsDict = New-Object System.Collections.Specialized.OrderedDictionary
        $this.plainDictToExtendedDict($methodsDict, $extMethodsDict)

        If ($this.super -ne $null) 
        {
            # Create intersection of two method sets
            [object[]] $keys1 = $this.allMethods.Keys
            [object[]] $keys2 = $extMethodsDict.Keys
            $intersection = $this.intersectArrays($keys1, $keys2)

            If ($intersection -ne $null) 
            {
                # Remove common items
                $intersection | ForEach-Object { $this.allMethods.Remove($_) }

                # Copy and change all methods in intersection
                $this.copyAndChangeBaseMethods($this.super.className, $this.super.allMethods, $this.allMethods, $intersection)
            }       
        }

        $this.addMethodsAndPrefixedConstructors($extMethodsDict)

        # Recreate object
        # (We don't have to recreate object in all cases, but it doesn't hurt)
        $this.templateObject = CreateObject $this.allVariables
        $this.addExtendedMethodsToObject()

        $this.methodsAdded = $true
    }

    # -------------------------------------------------------------------------------------------------------

    $addMethodsAndPrefixedConstructors = {

        param($extMethodsDict)            
            
        # Add all methods
        $this.allMethods += $extMethodsDict
        
        # For each constructor add <className>_<constructorName> method
        $constructors = @( $extMethodsDict.GetEnumerator() | Where-Object { $_.Value.category -eq "Constructor"} )
        $constructors | ForEach-Object {
            $newMethodName = $this.className + "_" + $_.Key
            $this.allMethods.Add($newMethodName, (New "Method" { $self.init($_.Value.scriptBlock, "SuperConstructor") } ))
        }           
    }

    $addExtendedMethodsToObject = {

        # Convert extended dictionary to plain dictionary
        $methodsDict = New-Object System.Collections.Specialized.OrderedDictionary
        
        $this.allMethods.GetEnumerator() | ForEach-Object {
            $methodsDict.Add($_.Key, $_.Value.scriptBlock) 
        }

        AddMethodsToObject $this.templateObject $methodsDict
    }

    $plainDictToExtendedDict = {

        param($plainDict, $extendedDict)

        $plainDict.GetEnumerator() | ForEach-Object {
            $isConstructor = ($_.Key -Match "^init")
            
            If ($isConstructor) {
                $extendedDict.Add($_.Key, (New "Method" { $self.init($_.Value, "Constructor") } ))
            } Else {
                $extendedDict.Add($_.Key, (New "Method" { $self.init($_.Value, "Method") } ))
            }
        }    
    }

    $copyMethods = {
        
        param($sourceDict, $targetDict)

        $sourceDict.GetEnumerator() | ForEach-Object {
            If ($_.Value.category -ne "Constructor") {
                $targetDict.Add($_.Key, $_.Value)
            }
        }
    }

    # Change name and category
    $copyAndChangeBaseMethods = {
        
        param($superclassName, $sourceDict, $targetDict, $keys)

        $sourceDict.getEnumerator() | Where-Object { $_.Key -in $keys } | ForEach-Object {

            $newMethodName = "$($superclassName)_$($_.Name)"
            $targetDict.Add($newMethodName, (New "Method" { $self.init($_.Value.scriptBlock, "SuperMethod") } ))
        }
    }

    $checkMethodNames = {

        param($newDict, $thisDict)

        # Check prefixed names of this class
        $prefixedNames = $newDict.GetEnumerator() | Where-Object { $_.Key -match ("^" + $this.className + "_") }
        If ($prefixedNames -ne $null) {
            throw "Illegal method name(s): " + ($prefixedNames | ForEach-Object { $_.Name } )
        }

        # Check prefixed names of inherited classes
        If ($this.super -ne $null) {
            $selMethods = @( $thisDict.GetEnumerator() | Where-Object { $_.Value.category -in @("", "SuperConstructor", "SuperMethod") } )
            [object[]] $thisKeys = @( $selMethods | ForEach-Object { $_.Key } )
            [object[]] $newKeys = $newDict.Keys
            
            $intersection = $this.intersectArrays($thisKeys, $newKeys)
            
            If ($intersection -ne $null) {
                throw "Illegal method name(s): " + $intersection
            }
        }
    }

    $intersectArrays = {

        param([object[]] $a, [object[]] $b)

        $a | Where-Object { $b -Contains $_ }
    }

    # -------------------------------------------------------------------------------------------------------

    $new, $new_, $cloneTemplateObject, $createDict_defaultConstructor,
    $addMethods, $addMethodsAndPrefixedConstructors, $addExtendedMethodsToObject, $plainDictToExtendedDict, 
    $copyMethods, $copyAndChangeBaseMethods, $checkMethodNames, $intersectArrays | Out-Null  
        # Just to avoid VS Code complaints

    Methods_End $methods
}

AddMethodsToObject $ClassClass (ClassMethods)

# -----------------------------------------------------------------------------------------------------------
# -----------------------------------------------------------------------------------------------------------

# METHOD

$MethodClass = CreateSimpleClass @("scriptBlock", "category")

$MethodClass.addMethods( @{

    init = {
        param([ScriptBlock] $scriptBlock, [string] $category)

        $this.scriptBlock = $scriptBlock
        $this.category = $category
    }
} )    
