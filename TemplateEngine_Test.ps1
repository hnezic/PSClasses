$folder = Split-Path -Parent $MyInvocation.MyCommand.Path 
. "$folder\TemplateEngine.ps1"

function renderTemplate {
    param([string] $template, [Hashtable] $arguments)
    $TemplateEngineModule.renderTemplate($template, $arguments)
}

function trimLines {
    param($str)
    $TemplateEngineModule.trimLines($str)
}

Describe "Array with and without separators" {

    BeforeEach {
        $arguments = @{ 
            container = @("name", "age", "male")
        }
        
        $template = @'
            @ForEach $_ in $container
                $script.$_ = $$_
            @End
        
            @ForEach $_ in $container -comma
                $_
            @End
        
            @ForEach $_ in $container -backtick
                $_
            @End
'@
        $result = renderTemplate $template $arguments
        $result
    }

    It "Array with and without separators" {
        (trimLines $result) | Should Be (trimLines @'
            $script.name = $name
            $script.age = $age
            $script.male = $male

            name,
            age,
            male

            name `
            age `
            male
'@)
    }
}

Describe "Array with backtick separator" {

    BeforeEach {
        $arguments = @{ 
            container = @("name", "age", "male")
        }
        
        $template = @'
            New-Object -TypeName PSObject `
            @ForEach $_ in $container -backtick
                | Add-Member -Name $_ -Value $null -MemberType NoteProperty -PassThru
            @End
'@
        $result = renderTemplate $template $arguments
        $result
    }

    It "Array with backtick separator" {
        (trimLines $result) | Should Be (trimLines @'
            New-Object -TypeName PSObject `
                    | Add-Member -Name name -Value $null -MemberType NoteProperty -PassThru `
                    | Add-Member -Name age -Value $null -MemberType NoteProperty -PassThru `
                    | Add-Member -Name male -Value $null -MemberType NoteProperty -PassThru
'@)
    }
}

Describe "Two @ForEach statements" {

    BeforeEach {
        $arguments = @{ 
            container = @("name", "age", "male")
            classObjectName = '$MyClass'
            factoryName = "New-MyClass"
        }
        
        $template = @'
        function $factoryName {
            param(
                @ForEach $_ in $container -comma
                    $_
                @End
            )
        
            $result = $classObjectName.PSObject.copy()
            @ForEach $_ in $container
                $result.$_ = $$_
            @End
        
            $result
        }
'@
        $result = renderTemplate $template $arguments
        $result
    }

    It "Two @ForEach statements" {
        (trimLines $result) | Should Be (trimLines @'
            function New-MyClass {
                param(
                        name,
                        age,
                        male
                )
        
                $result = $MyClass.PSObject.copy()
                    $result.name = $name
                    $result.age = $age
                    $result.male = $male
        
                $result
            }
'@)
    }
}

Describe "@ForEach key in a dictionary" {

    BeforeEach {
        $dict = New-Object System.Collections.Specialized.OrderedDictionary
        $dict.Add("switzerland","bern")
        $dict.Add("germany","berlin")
        $dict.Add("spain","madrid")
        $dict.Add("italy","rome")
        
        $arguments = @{ 
            container = $dict 
        }
        
        $template = @'
            @ForEach $_ in $container
               $ScriptInfoClass | Add-Member -Name $key -Value $dict['$key'] -MemberType ScriptMethod
            @End
'@
        $result = renderTemplate $template $arguments
        $result
    }

    It "@ForEach key in a dictionary" {
        (trimLines $result) | Should Be (trimLines @'
            $ScriptInfoClass | Add-Member -Name switzerland -Value $dict['switzerland'] -MemberType ScriptMethod
            $ScriptInfoClass | Add-Member -Name germany -Value $dict['germany'] -MemberType ScriptMethod
            $ScriptInfoClass | Add-Member -Name spain -Value $dict['spain'] -MemberType ScriptMethod
            $ScriptInfoClass | Add-Member -Name italy -Value $dict['italy'] -MemberType ScriptMethod        
'@)
    }
}

Describe "A simple @If statement" {

    BeforeEach {

        $arguments = @{ 
            condition = $true
        }
        
        $template = @'
            @If $condition
               abcd
            @EndIf
'@
        $result = renderTemplate $template $arguments
        $result
    }

    It "A simple @If statement" {
        (trimLines $result) | Should Be (trimLines @'
            abcd
'@)
    }
}

Describe "Another @If statement" {

    BeforeEach {
        $arguments = @{
            superInit__ = "ModularCounter_init"
            inherited__ = $true    
        }
        
        $template = @'
            @If $inherited__
                $this.$superInit__()
            @EndIf
'@
        $result = renderTemplate $template $arguments
        $result
    }

    It "Another @If statement" {
        (trimLines $result) | Should Be (trimLines @'
                $this.ModularCounter_init()
'@)
    }
}

Describe "@ForEach and @If statements" {

    BeforeEach {
        $arguments = @{ 
            container = @("name", "age", "male")
            condition1 = $true
            condition2 = $false    
        }
        
        $template = @'
            @ForEach $_ in $container
                $script.$_ = $$_
            @End
        
            @If $condition1
                ;
            @EndIf
        
            @ForEach $_ in $container -comma
                $_
            @End
        
            @If $condition2
                ;
            @EndIf
        
            @ForEach $_ in $container -backtick
                $_
            @End
'@        
        $result = renderTemplate $template $arguments
        $result
    }

    It "@ForEach and @If statements" {
        (trimLines $result) | Should Be (trimLines @'
            $script.name = $name
            $script.age = $age
            $script.male = $male

            ;

            name,
            age,
            male



            name `
            age `
            male        
'@)
    }
}
