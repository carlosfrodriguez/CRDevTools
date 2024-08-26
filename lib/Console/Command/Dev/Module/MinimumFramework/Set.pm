# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Console::Command::Dev::Module::MinimumFramework::Set;

use strict;
use warnings;

use File::Spec();
use Cwd qw(cwd);
use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Set minimum framework version for a module or modules.');

    $Self->AddOption(
        Name        => 'parent-directory',
        Description => "Specify the parent directory where modules are stored.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'version',
        Description => "Specify the target version.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.0\.\d+/smx,
    );

    return;
}

sub Run {
    my ($Self) = @_;

    my $Directory       = $Self->GetOption('parent-directory');
    my $ParentDirectory = File::Spec->rel2abs($Directory);

    my $TargetVersion = $Self->GetOption('version');

    my ( $Major, $Minor, $Patch ) = split /\./, $TargetVersion;

    my @Directories = glob "$ParentDirectory/*";

    $Self->Print("\n<yellow>Setting minimum framework version...</yellow>\n\n");

    my $MainObject = $Kernel::OM->Get('Kernel::System::Main');

    my @Items;
    my $Failed;

    MODULEDIRECTORY:
    for my $ModuleDirectory (@Directories) {

        # Look if an sopm exists.
        my @SOPMs = glob "$ModuleDirectory/*.sopm";

        if ( !@SOPMs || !$SOPMs[0] ) {
            $Self->PrintError("Couldn't find the SOPM file in $ModuleDirectory");
            next MODULEDIRECTORY;
        }

        my $ModuleName = $SOPMs[0];
        $ModuleName =~ s{$ModuleDirectory/(.*)\.sopm}{$1}ix;

        my $Branch = `cd $ModuleDirectory && git rev-parse --abbrev-ref HEAD`;
        $Branch =~ s{\s+}{}msxg;

        my $SOPMContentRef = $MainObject->FileRead(
            Location => "$SOPMs[0]",
            Mode     => 'utf8',
            Result   => 'SCALAR',
        );

        my ( $CurrentVersion, $FoundMajor )
            = ${$SOPMContentRef} =~ m{<Framework\s(?: Minimum="($Major\.0\.\d+)")*>($Major\.0\.x)}msxi;

        if ( !$FoundMajor || !$CurrentVersion ) {
            push @Items, {
                Module => "$ModuleName <yellow>($Branch)</yellow>",
                From   => '-',
                To     => '-',
                Result => 'Skipped',
            };
            next MODULEDIRECTORY;
        }
        elsif ( $CurrentVersion eq $TargetVersion ) {
            push @Items, {
                Module => "$ModuleName <yellow>($Branch)</yellow>",
                From   => "<yellow>$CurrentVersion</yellow>",
                To     => "<yellow>$TargetVersion</yellow>",
                Result => 'Skipped',
            };
            next MODULEDIRECTORY;
        }

        my $Search = "(<Framework\\sMinimum=\")$Major\\.0\\.\\d+(\">$Major\\.0\\.x)";
        ${$SOPMContentRef} =~ s{$Search}{$1$TargetVersion$2}gismx;

        my $FileLocation = $MainObject->FileWrite(
            Location => "$SOPMs[0]",
            Mode     => 'utf8',
            Content  => $SOPMContentRef,
        );

        if ( !$FileLocation ) {
            push @Items, {
                Module => "$ModuleName <yellow>($Branch)</yellow>",
                From   => "<red>$CurrentVersion</red>",
                To     => "<green>$TargetVersion</green>",
                Result => '<red>Fail</red>',
            };
            $Failed = 1;
            next MODULEDIRECTORY;
        }

        push @Items, {
            Module => "$ModuleName <yellow>($Branch)</yellow>",
            From   => "<red>$CurrentVersion</red>",
            To     => "<green>$TargetVersion</green>",
            Result => '<green>OK</green>',
        };

    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'Module', 'From', 'To', 'Result' ],
            Body   => [ map { [ $_->{Module}, $_->{From}, $_->{To}, $_->{Result} ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    if ($Failed) {
        $Self->Print("\n<red>Fail.</red>\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("\n<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
