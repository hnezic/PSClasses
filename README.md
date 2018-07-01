# PSClasses

## Overview

The PSClasses project provides classes with inheritance to **PowerShell** versions earlier than 5.0.

PSClasses include important **features** of object-oriented languages, like following:
- class inheritance
- overriding methods
- ability to call overridden superclass methods
- multiple constructors
- ability to call other constructors of the same class
- ability to call superclass constructors

PSClasses also contain an uncommon feature: implicit **generation** of the constructor which accepts arguments corresponding to all instance variables. This feature resembles *case classes* in Scala or *data classes* in Kotlin.

The project includes a simple **template engine** used in implementation of some features.

The file *ClassGenerator_Test.ps1* contains numerous **examples** in form of **Pester** tests.

## Usage

### Class creation

- A class is created by calling **CreateClass** function.
- The created class is represented by a **class object**.
- A **variable** holding the class object is automatically created.
- The **variable name** is formed like this: **`$<className>Class`**.

The CreateClass function accepts following **arguments**: 

Argument | Alias | Mandatory
-------- | ----- | ---------
class name | -name | yes
superclass | -extends | no
instance variables | -variables | no
methods | -methods | no

#### Example

```powershell
CreateClass "Person" $null '[string] $name, [int] $age, [boolean] $male' @{
    
    reportAge = {
        "My age is $($this.age)"
    }
    
    reportName = {
        "My name is $($this.name)"
    }
}
```

This call creates the class object **$PersonClass**:

```powershell
> $PersonClass

className         : Person
super             :
allVariablesStr   : [string] $name, [int] $age, [boolean] $male
variables         : {name, age, male}
...
```

### Instance variables

- Instance variables are specified as a **string** containing a comma-separated variable list along with **optional** type specifiers.
- The string containing instance variables is also used for parameters of the **generated constructor** named **init**. 
- The string is **parsed** and the variable names extracted.
- Syntax is the same as syntax of function parameters or script block parameters.

#### Examples

```powershell
'[string] $name, [int] $age, [boolean] $male'

'[PSCustomObject] $successor, [string] $topic'

'$drive, $certSubject, $certAccount'

''
```

### Methods

- The methods are written as a **dictionary** of *(name, script block)* pairs.
- The methods dictionary can be an unordered hashtable or ordered dictionary.

#### Overriding methods

- A derived class can **override** superclass methods. 
- Each overridden method is available in following form: **`<className>_<methodName>`**.

#### Example

```powershell
CreateClass "IntCounter" $null '[int] $value' @{
    
    increment = {
        $this.value += 1
    }

    reset = {
        $this.value = 0
    }
}

CreateClass "ModularCounter" -extends "IntCounter" '[int] $modulus' @{

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
```

ModularCounter class overrides **increment** method. The ModularCounter's **increment** method calls the superclass version:

```powershell
$this.IntCounter_increment()
```

### Constructors

- Constructors are special **methods** whose names start with **init**.
- A class can contain **multiple** constructors.

Each constructor can call:
  - any other constructor of the **same class**, including the generated constructor 
  - any **superclass** constructor

When a custom constructor calls other constructors it must use one of following forms:  
  - **`<className>_<constructorName>`** (for calling other custom constructors)
  - **`<className>_gen_init`** (for calling the generated constructor)

#### Generated constructor

- The constructor named init is generated automatically. 
- It accepts arguments corresponding to all instance variables (including instance variables declared in superclasses).
- It copies the arguments into instance variables. 
- The generated constructor can be overridden by a custom constructor.
- If overridden, the generated constructor is still available to be called from other constructors as a method with following name: **`<className>_gen_init`**.

#### Example 1

Let's look at the example above which creates **Person** class. 
The Person's methods don't include custom constructors. The generated constructor **init** is available after class creation. Its arguments correspond to instance variables:
- $name
- $age
- $male

We can create new objects using the **init** constructor:

```powershell
$person = New "Person" { $self.init("John Smith", 23, $true) }

> $person

name       age male
----       --- ----
John Smith  23 True
```

#### Example 2

Let's rewrite **IntCounter** and **ModularCounter** classes to include only the constructor methods:

```powershell
CreateClass "IntCounter" $null '[int] $value' @{
    
    init0 = {
        $this.value = 0
    }
}

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
}
```

##### IntCounter

The IntCounter's generated constructor **init** accepts `[int] $value` parameter. 
The class also includes a parameterless constructor **init0**.

##### ModularCounter calls other constructors

The ModularCounter's generated constructor **init** which accepts the parameters `[int] $value` and `[int] $modulus` is overridden by the custom **init** constructor.
The custom init constructor calls the generated init constructor:

```powershell
$this.ModularCounter_gen_init($value, $modulus)
```

The class also includes a parameterless constructor **init0** which calls the custom init constructor: 

```powershell
$this.ModularCounter_init(0, $modulus)
```

#### Example 3

The following classes are a part of an example which illustrates the chain of responsibility design pattern.
For simplicity we have excluded non-constructor methods.

```powershell
CreateClass "HelpHandler" $null '[PSCustomObject] $successor, [string] $topic'

CreateClass "Widget" -extends "HelpHandler" '[PSCustomObject] $parent' @{

    init = {
        param([PSCustomObject] $parent, [string] $topic)

        # Widget's parent is HelpHandler's successor
        $this.HelpHandler_init($parent, $topic)
        $this.parent = $parent
    }
}
```

The Widget's init constructor calls the generated constructor of the HelpHandler **superclass**:

```powershell
$this.HelpHandler_init($parent, $topic)
```

### Object creation

- There are several ways to create new objects.
- The simplest way is to call function **New** (or alternatively **New_**).
- An alternative way is to call method **new** (or alternatively **new_** on the class object)

We'll illustrate creation of objects on the following simple class:

```powershell
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
```

#### New

- The function New accepts two arguments:
  - class name 
  - script block containing a constructor call

For example:

```powershell
$point = New "Point" { $self.init(10, 20) }
```

Here we supply a **parameterless** script block. 
When function **New** is executed it will create the **$self** object and then the call `$self.init(10, 20)` will be executed on this object.

The function New expects that the supplied script block contains a constructor call on the object **$self**. If we use any other object it will not work.

The way of object creation with function **New** will **not** work correctly within **closures**. For example:

```powershell
$script = {
    ...
    # This will not work
    $point = New "Point" { $self.init(-10, -50) }
    ...
}.GetNewClosure()
```

#### New_

The function New_ is similar to New but it expects a script block with a **single parameter** representing the object being created and initialized. The parameter name is irrelevant.

For example:

```powershell
$point1 = New_ "Point" { param($self) $self.init(30, 50) }

$point2 = New_ "Point" { param($_) $_.init(25, 35) }
```

The way of object creation with function **New_** will **work** correctly within **closures**.

#### Using class object methods

Instead of calling functions **New** or **New_** we can create objects by applying methods **new** or **new_** to the class object:

```powershell
$point1 = $PointClass.new( { $self.init(10, 20) } )

$point2 = $PointClass.new_( { param($_) $_.init(5, 8) } )
```
