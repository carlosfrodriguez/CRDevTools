# --
# Copyright (C) 2020 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2020 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::Ticket::Archive;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Archive one or more tickets.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more ticket ids of tickets to be archived.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of ticket ids to be archived. (e.g. 1..10)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'restore',
        Description => "Restore archived tickets instead to archive them",
        Required    => 0,
        HasValue    => 0,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $OptionsCounter = 0;
    for my $Option (qw(id id-range)) {
        if ( $Self->GetOption($Option) ) {
            $OptionsCounter++;
        }
    }

    if ( $OptionsCounter > 1 ) {
        die("Only one option (id or id-range) can be used at a time!\n");
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ArchiveFlag = 'y';
    if ( $Self->GetOption('restore') ) {
        $ArchiveFlag = 'n';
    }

    if ( $ArchiveFlag eq 'y' ) {
        $Self->Print("<yellow>Archiving tickets...</yellow>\n");
    }
    else {
        $Self->Print("<yellow>Restoring archived tickets...</yellow>\n");
    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my @TicketIDs;
    if ( $Self->GetOption('id') ) {
        @TicketIDs = @{ $Self->GetOption('id') };
    }
    elsif ( $Self->GetOption('id-range') ) {
        if ( $Self->GetOption('id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @TicketIDs = ( $1 .. $2 );
        }
    }

    if ( !@TicketIDs ) {
        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $Failed;

    TICKETID:
    for my $TicketID (@TicketIDs) {

        next TICKETID if !$TicketID;

        # get ticket details
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # check if ticket exists
        if ( !%Ticket ) {
            $Self->PrintError("The ticket with ID $TicketID does not exist!\n");
            $Failed = 1;
            next TICKETID;
        }

        if ( lc $Ticket{ArchiveFlag} eq $ArchiveFlag ) {
            $Self->Print("The ticket with ID $TicketID is already archived / restored <yellow>skipping...</yellow>");
            next TICKETID;
        }

        # Archive ticket.
        my $Success = $TicketObject->TicketArchiveFlagSet(
            ArchiveFlag => $ArchiveFlag,
            TicketID    => $TicketID,
            UserID      => 1,
        );

        if ( !$Success ) {
            if ( $ArchiveFlag eq 'y' ) {
                $Self->PrintError("Can't archive ticket $TicketID\n");
            }
            else {
                $Self->PrintError("Can't restore ticket $TicketID\n");
            }
            $Failed = 1;
        }
        else {
            if ( $ArchiveFlag eq 'y' ) {
                $Self->Print(" Archived ticket $TicketID\n");
            }
            else {
                $Self->Print(" Restored ticket $TicketID\n");
            }
        }
    }

    if ($Failed) {
        if ( $ArchiveFlag eq 'y' ) {
            $Self->PrintError("Not all tickets where archived\n");
        }
        else {
            $Self->PrintError("Not all tickets where restored\n");
        }
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
