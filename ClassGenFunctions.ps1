If (-not $ClassGenFunctions_Included)
{
    $ClassGenFunctions_Included = $true
    function New {

        param([string] $className, [ScriptBlock] $constructor)

        $class = Invoke-Expression ('$' + $className + "Class")
        If ($class -eq $null) {
            throw "Class $className not found!"
        }
        
        $class.new($constructor)
    }

    function New_ {

        param([string] $className, [ScriptBlock] $constructor)

        $class = Invoke-Expression ('$' + $className + "Class")
        If ($class -eq $null) {
            throw "Class $className not found!"
        }
        
        $class.new_($constructor)
    }

    function Methods_Start 
    {
        Get-Variable
    }

    function Methods_End 
    {
        param($vars)

        $varsName = ($MyInvocation.Line.Trim() -Split "\s+").Replace('$', "")[1]

        $methodsVars = Compare-Object (Get-Variable) $vars -Property Name -PassThru | Where-Object { @($varsName, "varsName", "vars") -notcontains $_.Name  }

        $methodsDict = New-Object System.Collections.Specialized.OrderedDictionary
        
        $methodsVars | ForEach-Object {
            $methodsDict.Add($_.Name, $_.Value) 
        }

        $methodsDict
    }

    function CreateObject {

        param([string[]] $variables)
        
        $object = New-Object -TypeName PSObject

        $variables | ForEach-Object {
            $object | Add-Member -Name $_ -Value $null -MemberType NoteProperty
        }

        $object
    }

    function AddMethodsToObject {

        param($object, $methodsDict)

        # Convert $methodsDict to OrderedDictionary if needed
        If ($methodsDict -is [Hashtable]) 
        {
            $methodsDict = HashtableToOrderedDict($methodsDict)
        }

        $methodsDict.GetEnumerator() | ForEach-Object {
            $object | Add-Member -Name $_.Key -Value $_.Value -MemberType ScriptMethod
        }
    }

    function CreateSimpleClass {

        param([string[]] $variables)

        $class = CreateObject @("templateObject")
        $class.templateObject = CreateObject $variables

        AddMethodsToObject $class @{

            new = {
                param([ScriptBlock] $constructor)

                $self = $this.cloneTemplateObject()
                & $constructor
                
                $self
            }

            new_ = {
                param([ScriptBlock] $constructor)

                $self = $this.cloneTemplateObject()
                & $constructor($self)
                
                $self
            }

            cloneTemplateObject = {
                $this.templateObject.PSObject.copy()
            }

            addMethods = {

                param($methodsDict)

                AddMethodsToObject $this.templateObject $methodsDict
            }
        }

        $class
    }

    function HashtableToOrderedDict {

        param([Hashtable] $hashtable)

        $dict = New-Object System.Collections.Specialized.OrderedDictionary
        $hashtable.GetEnumerator() | ForEach-Object { $dict.Add($_.Key, $_.Value) }
        $dict
    }
}