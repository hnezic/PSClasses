If (-not $ClassGenFunctions_Included) {
    . "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\ClassGenFunctions.ps1"
}

# COLLECTION

$CollectionClass = CreateSimpleClass @("array")

$CollectionClass.addMethods( @{

    init = { 
        param([array] $array)

        $this.array = $array
    }

    # Find the first element satisfying a predicate
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

    # Tests whether a predicate holds for all array elements
    forAll = {
        param([ScriptBlock] $predicate)

        $result = $true

        ForEach ($elem in $this.array)
        {
            If (-not (& $predicate $elem)) {
                $result = $false
                Break
            }
        }

        $result
    }
    
    # Returns new Collection
    map = {
        param([ScriptBlock] $fn)
        
        $mappedArray = @( $this.array | ForEach-Object { & $fn $_ } )
        
        New "Collection" { $self.init($mappedArray) } 
    }
} )
