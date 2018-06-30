# PSClasses

Classes with inheritance for PowerShell versions earlier than 5.0

## Overview

### Class creation

- A class is created by calling **CreateClass** function.
- The created class is represented by a **class object**.
- A **variable** holding the class object is automatically created.
- The variable name is formed like this: `$<className>Class`.

The CreateClass function accepts following **arguments**: 

Argument | Alias | Mandatory
-------- | ----- | ---------
Class name | -name | yes
Superclass | -extends | no
Instance variables | -variables | no
Methods | -methods | no

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
- The string containing instance variables is **parsed** and the variable names extracted.
- The string is also used to create parameters of the generated constructor named **init**. 

### Methods

- Methods are written as a **dictionary** of *(name, script block)* pairs.
- The methods dictionary can be an unordered hashtable or ordered dictionary.

#### Overriding

- A class can **override** superclass methods, but each overridden methods is still available in following form: **<className>_<methodName>**.

### Constructors

- Constructors are special **methods** starting with **init**.
- A class can contain **multiple** constructors.

#### Generated constructor

- The constructor named init is generated automatically. 
- It accepts arguments corresponding to all instance variables (including instance variables declared in superclasses).
- It copies the arguments into instance variables. 
- The generated constructor can be overridden by a custom constructor, but is still available to be called from other constructors as a method with following name: **<className>_gen_init**.

#### Calling other constructors

- Each constructor can call any other constructor of the **same class** or a **superclass** constructor by using the constructor name in following form: **<className>_<constructorName>**.

### Object creation

- New objects are created by calling function **New** (or alternatively **New_**). 
- The functions accepts two arguments:
  - class name 
  - script block containing a constructor call.