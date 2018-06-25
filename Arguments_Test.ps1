$folder = Split-Path -Parent $MyInvocation.MyCommand.Path 
. "$folder\Arguments.ps1"

Describe "Various argument sets" {

    BeforeEach {
        $arguments1 = New "Arguments" { $self.init('$port') }
        $arguments2 = New "Arguments" { $self.init('[ValidateScript({$_ -ge (get-date)})] [DateTime] $EventDate, [string] $abc') }
        $noArguments = New "Arguments" { $self.init('') }

        $arguments1, $arguments2, $noArguments
    }

    It "One simple argument" {
        $arguments1.argumentsStr | Should Be '$port'
        $arguments1.variables | Should Be @("port")
    }

    It "Two arguments, validate script" {
        $arguments2.argumentsStr | Should Be '[ValidateScript({$_ -ge (get-date)})] [DateTime] $EventDate, [string] $abc'
        $arguments2.variables | Should Be @("EventDate", "abc")
    }

    It "No arguments" {
        $noArguments.argumentsStr | Should Be ''
        $noArguments.variables -is [array] | Should Be $true
        $noArguments.variables.Count | Should Be 0
    }
}
