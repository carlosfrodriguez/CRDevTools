# --
# Copyright (C) 2022 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2022 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::Git::Branch::Cleanup;

use strict;
use warnings;

use IPC::Open3;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = ();

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Remove local branches where remote has already gone.');

    # TODO: add support for non Framework directories commands must look like cd <DIR> &&
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Cleaning local branches where remote has already gone...</yellow>\n\n");

    my ( $Outlines, $Errlines, $ExitCode )
        = $Self->ExecuteCommand("git branch -vv | grep gone | sed 's/gone].*/gone]/g'");

    my @Branches;
    LINE:
    for my $Line ( @{$Outlines} ) {
        $Line = substr( $Line, 2, );
        chomp $Line;
        if ( $Line =~ m{\A([^\s]+)\s+[\w]+\s\[[^\s]+\sgone\]\z}gismx ) {
            push @Branches, $1,;
        }
    }

    if ( !@Branches ) {
        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $Failed;

    BRANCH:
    for my $Branch (@Branches) {
        ( $Outlines, $Errlines, $ExitCode ) = $Self->ExecuteCommand("git branch -D $Branch");
        if ($ExitCode) {
            for my $Line ( @{$Errlines} ) {
                chomp $Line;
                $Self->Print("<red>$Line<red>");
            }
            $Failed = 1;

            next BRANCH;
        }

        my $Line = $Outlines->[0];
        chomp $Line;
        $Line =~ s{(\(was\s[^\)]+\))\.}{<yellow>$1<\/yellow>}gismx;
        $Self->Print("  $Line\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all branches where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("\n<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

sub ExecuteCommand {
    my ( $Self, $Command ) = @_;

    my @Outlines;
    my @Errlines;
    my $ExitCode;

    my $EvalSuccess = eval {

        local $SIG{CHLD} = 'DEFAULT';

        # Localize the standard output and error, everything will be restored after the eval block.
        local ( *CMDIN, *CMDOUT, *CMDERR );    ## no critic (Variables::RequireInitializationForLocalVars)
        my $CMDPID = open3( *CMDIN, *CMDOUT, *CMDERR, $Command, );
        close CMDIN;

        waitpid( $CMDPID, 0 );

        # Redirect the standard output and error to a variable.
        @Outlines = <CMDOUT>;
        @Errlines = <CMDERR>;

        $ExitCode = $? >> 8;
        $ExitCode //= 0;
    };

    return ( \@Outlines, \@Errlines, $ExitCode );
}

1;
