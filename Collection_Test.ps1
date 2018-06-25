$folder = Split-Path -Parent $MyInvocation.MyCommand.Path 
. "$folder\Collection.ps1"


Describe "Collection variables and methods" {

    BeforeEach {

        $coll = $CollectionClass.new({ $self.init(@(10, 20, 30, 40, 50, 30, 10)) })
        $coll
    }
   
    It "Collection variables" {

        $coll.array -is [array] | Should Be $true
        $coll.array.Count | Should Be 7
        $coll.array[0] | Should Be 10
        $coll.array[2] | Should Be 30
    }

    It "Collection methods" {
        $coll.forAll( { param($item) $item -ge 10 } ) | Should Be $true
        $coll.find( { param($item) $item -gt 10 -and $item -le 40 } ) | Should Be 20
    }

    It "Collection map method" {
        $mapped = $coll.map( { param($item) $item + 100 } )
        $mapped.array -is [array] | Should Be $true
        $mapped.array.Count | Should Be 7
        $mapped.array[0] | Should Be 110
        $mapped.array[2] | Should Be 130
    }
}