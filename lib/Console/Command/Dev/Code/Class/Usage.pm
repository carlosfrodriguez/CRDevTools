# --
# Copyright (C) 2023 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2022 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::Code::Class::Usage;

use strict;
use warnings;

use File::Spec();

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Find class usage, listing all methods, results are printed on the screen in markdown format.');

    $Self->AddOption(
        Name        => 'parent-directory',
        Description => "The directory to start searching",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'search-class',
        Description => "The object to search for",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'version',
        Description => "look for spacial version in directory e.g. Package-123_0",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'include-sub',
        Description => "look for spacial sub-routines only",
        Required    => 0,
        HasValue    => 1,
        Multiple    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'exclude-file',
        Description => "skip files that matches...",
        Required    => 0,
        HasValue    => 1,
        Multiple    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ParentDirectory = $Self->GetOption('parent-directory');
    my $SearchClass     = $Self->GetOption('search-class');
    my $Version         = $Self->GetOption('version');
    my $IncludeSub      = $Self->GetOption('include-sub');
    my $ExcludeFile     = $Self->GetOption('exclude-file');

    $ParentDirectory = File::Spec->rel2abs( $Self->GetOption('parent-directory') );

    $Self->Print("\n<yellow>Searching for $SearchClass in $ParentDirectory...</yellow>\n\n");

    no warnings qw(once);    ## no critic
    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');
    use warnings;

    my $Filter = $Version ? ["*$Version"] : ['*'];

    my @RootDirectories = $MainObject->DirectoryRead(
        Directory => $ParentDirectory,
        Filter    => $Filter,
        Recursive => 0,
    );

    my $RootDirectoriesLookup = $Self->_SetRootDirectoriesLookup(
        ParentDirectory => $ParentDirectory,
        SearchClass     => $SearchClass,
        Version         => $Version,
        RootDirectories => \@RootDirectories,
    );

    $Self->_PrintHeader(
        SearchClass           => $SearchClass,
        ParentDirectory       => $ParentDirectory,
        RootDirectoriesLookup => $RootDirectoriesLookup,
    );

    my %IncludeSubLookup = map { $_ => 1 } @{$IncludeSub};

    #my %ExcluseFileLookup = map{$_ => 1} @{$ExcludeFile};

    for my $RootDirectory ( sort keys %{$RootDirectoriesLookup} ) {

        # Search only in perl modules and test files.
        my @FilesInDirectory = $MainObject->DirectoryRead(
            Directory => $RootDirectory,
            Filter    => [ '*.pl', '*.pm', '*.t' ],
            Recursive => 1,
            Silent    => 1,
        );

        my %Files;

        FILE:
        for my $File (@FilesInDirectory) {

            for my $ExcludeFile ( @{$ExcludeFile} ) {
                next FILE if $File =~ m{$ExcludeFile}x;
            }

            my $ContentRef = $MainObject->FileRead(
                Location => $File,
                Mode     => 'binmode',
                Result   => 'SCALAR',
            );

            next FILE if !$$ContentRef;
            next FILE if ( $$ContentRef !~ m{$SearchClass'}g );

            # FIXME: Initial idea was to use RegEx with full file but It was not detecting e.g.
            #   'Kernel::System::ABC'
            #   if other similar classes where found too like:
            #   'Kernel::System::ABC::DEF',
            #   'Kernel::System::ABC::XYZ'.
            #
            # So the workaround was to split the file into lines and only check those lines with the found class,
            #   for sure this is terrible slow but at least is working for now.
            my @Lines = split "\n", $$ContentRef;
            @Lines = grep {/$SearchClass'/} @Lines;

            my %Functions;
            my %LocalObjects;

            LINE:
            for my $Line (@Lines) {

                # Check if class is found in a direct function call using object Manager e.g.
                #   my $Result = $Kernel::OM->Get('Kernel::System::ABC')->MySub();
                my ($Function) = $Line =~ m{\$Kernel::OM->Get\('$SearchClass'\)->(\w+)\(}smx;
                if ($Function) {

                    next LINE if !$Function;
                    next LINE if ( %IncludeSubLookup && !$IncludeSubLookup{$Function} );

                    $Functions{$Function} = 1;
                    next LINE;
                }

                # Check if the class is found in a local object assignment e.g.
                #   my $Object =  $Kernel::OM->Get('Kernel::System::ABC');
                my ($LocalObject) = $Line =~ m{my \s+ \$(\w+)\s+ = \s+ \$Kernel::OM->Get\('$SearchClass'\)}smx;
                if ($LocalObject) {
                    $LocalObjects{$LocalObject} = 1;
                    next LINE;
                }
            }

            # If there are no local object assignments, jump to the next file.
            if ( !%LocalObjects ) {
                next FILE if ( %IncludeSubLookup && !%Functions );

                $Files{$File} = \%Functions;
                next FILE;
            }

            for my $LocalObject ( sort keys %LocalObjects ) {

                # Get all lines from original file where local object is found.
                @Lines = split "\n", $$ContentRef;
                @Lines = grep {/$LocalObject/} @Lines;

                # Check if the local object is found in a function call.
                LINE:
                for my $Line (@Lines) {
                    my ($Function) = $Line =~ m{$LocalObject->(\w+)\(}smx;

                    next LINE if !$Function;
                    next LINE if ( %IncludeSubLookup && !$IncludeSubLookup{$Function} );

                    $Functions{$Function} = 1;
                }
            }

            next FILE if ( %IncludeSubLookup && !%Functions );
            $Files{$File} = \%Functions;
        }

        # Print directory with all files.
        if (%Files) {
            $Self->_PrintDirectory(
                RootDirectory         => $RootDirectory,
                RootDirectoriesLookup => $RootDirectoriesLookup,
                Files                 => \%Files,
            );
        }
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

sub _SetRootDirectoriesLookup {
    my ( $Self, %Param ) = @_;

    my %RootDirectoriesLookup;

    my $ParentDirectorySearch = qr($Param{ParentDirectory}/)x;
    my $VersionSearch         = qr(-$Param{Version});
    for my $RootDirectory ( @{ $Param{RootDirectories} } ) {
        ( my $RootDirectoryClean = $RootDirectory ) =~ s{$ParentDirectorySearch}{}x;

        if ( $Param{Version} ) {
            $RootDirectoryClean =~ s{$VersionSearch}{};
        }

        $RootDirectoriesLookup{$RootDirectory} = $RootDirectoryClean;
    }

    return \%RootDirectoriesLookup;
}

sub _PrintHeader {
    my ( $Self, %Param ) = @_;

    $Self->Print("# Usage of $Param{SearchClass}\n\n");
    $Self->Print(
        "`$Param{SearchClass}` and its subroutines by local objects or using object manager directly in the "
            . "following directories:\n\n"
    );

    for my $RootDirectoryClean ( sort values %{ $Param{RootDirectoriesLookup} } ) {
        $Self->Print("- $RootDirectoryClean\n");
    }
    $Self->Print("\n");

    return 1;
}

sub _PrintDirectory {
    my ( $Self, %Param ) = @_;

    $Self->Print("## $Param{RootDirectoriesLookup}->{$Param{RootDirectory}}\n\n");

    my $RootDirectorySearch = qr($Param{RootDirectory}/)x;

    FILE:
    for my $File ( sort keys %{ $Param{Files} } ) {

        ( my $FileClean = $File ) =~ s{$RootDirectorySearch}{}msx;
        $Self->Print("### $FileClean\n\n");

        my %Functions = %{ $Param{Files}->{$File} };

        if ( !%Functions ) {
            $Self->Print("Could not found any subroutine usage!\n\n");
            next FILE;
        }

        for my $Function ( sort keys(%Functions) ) {
            $Self->Print("- $Function()\n");
        }

        $Self->Print("\n");
    }

    return 1;
}

1;
