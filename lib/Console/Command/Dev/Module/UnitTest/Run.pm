# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Console::Command::Dev::Module::UnitTest::Run;

use strict;
use warnings;

use File::Spec();
use Cwd qw(cwd);
use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Console::Command::Dev::UnitTest::Run',
    'Kernel::System::Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Execute unit tests from a module.');
    $Self->AddArgument(
        Name        => 'module',
        Description => "Specify a module directory.",
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'verbose',
        Description => "Show details for all tests, not just failing.",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'selenium',
        Description => "include Selenium tests.",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub PreRun {
    my ($Self) = @_;

    my @Directories;

    my $Module          = $Self->GetArgument('module');
    my $ModuleDirectory = File::Spec->rel2abs($Module);
    if ( !-e $ModuleDirectory || !-d $ModuleDirectory ) {
        die "$Module is not a directory or does not exists";
    }

    return;
}

sub Run {
    my ($Self) = @_;

    my @Directories;

    my $Module          = $Self->GetArgument('module');
    my $ModuleDirectory = File::Spec->rel2abs($Module);

    my $Verbose      = $Self->GetOption('verbose');
    my $SkipSelenium = $Self->GetOption('selenium') ? 0 : 1;

    $Self->Print("\n<yellow>Executing module unit tests...</yellow>\n");

    my $FrameworkDirectory = cwd;

    # TODO: change file reading to Module::Pluggable::Object when OTRS 6 gets obsolete.
    my @TestFiles;
    my $TestFilesStr      = '';
    my $NotLinkedFilesStr = '';

    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    my $TestDirectory = "${ModuleDirectory}/scripts/test/";
    my @FullPathFiles = $MainObject->DirectoryRead(
        Directory => $TestDirectory,
        Filter    => '*.t',
        Recursive => 1,
        Silent    => 1,
    );

    TESTFILE:
    for my $TestFileRaw (@FullPathFiles) {

        if ( $SkipSelenium && $TestFileRaw =~ m{Selenium}msxi ) {
            next TESTFILE;
        }

        # Remove the trailing .t extension.
        my $TestFile = substr( $TestFileRaw, 0, length($TestFileRaw) - 2 );

        # Remove the heading module directory.
        $TestFile = substr( $TestFile, length($ModuleDirectory) + 1 );

        # Remove double slashes.
        $TestFile =~ s{\/\/}{\/}msxgi;

        $TestFilesStr .= "        <yellow>$TestFile</yellow>\n";

        if ( !-e "$FrameworkDirectory/$TestFile.t" ) {
            $NotLinkedFilesStr .= "        <red>$TestFile</red>\n";
            next TESTFILE;
        }
        push @TestFiles, $TestFile;
    }

    $TestDirectory = "${ModuleDirectory}/Kernel/Test/Case/";
    @FullPathFiles = $MainObject->DirectoryRead(
        Directory => $TestDirectory,
        Filter    => '*.pm',
        Recursive => 1,
        Silent    => 1,
    );

    TESTFILE:
    for my $TestFileRaw (@FullPathFiles) {

        if ( $SkipSelenium && $TestFileRaw =~ m{Selenium}msxi ) {
            next TESTFILE;
        }

        # Remove the trailing .pm extension.
        my $TestFile = substr( $TestFileRaw, 0, length($TestFileRaw) - 3 );

        # Remove the heading module directory.
        $TestFile = substr( $TestFile, length($ModuleDirectory) + 1 );

        # Remove double slashes.
        $TestFile =~ s{\/\/}{\/}msxgi;

        $TestFilesStr .= "        <yellow>$TestFile</yellow>\n";

        if ( !-e "$FrameworkDirectory/$TestFile.pm" ) {
            $NotLinkedFilesStr .= "        <red>$TestFile</red>\n";
            next TESTFILE;
        }

        push @TestFiles, $TestFile;
    }

    if ( !@TestFiles && !$NotLinkedFilesStr ) {
        $Self->Print("\n<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my @Params;
    for my $TestFile (@TestFiles) {
        push @Params, '--test';
        push @Params, $TestFile;
    }

    if ( $TestFilesStr && $Verbose ) {
        push @Params, '--verbose';
        $Self->Print("\n    Unit tests found in module:\n");
        $Self->Print($TestFilesStr);
        $Self->Print("\n");
    }

    if ($NotLinkedFilesStr) {
        $Self->Print("\n    Unit tests NOT found in framework:\n");
        $Self->Print($NotLinkedFilesStr);
        $Self->Print("\n");
    }

    my $TestCommand = $Kernel::OM->Get('Kernel::System::Console::Command::Dev::UnitTest::Run');
    $TestCommand->Execute(@Params);

    if ($NotLinkedFilesStr) {
        $Self->Print("\n<red>Not all unit tests where executed.</red>\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("\n<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
