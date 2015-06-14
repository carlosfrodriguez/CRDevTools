# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::CRDelete;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more tickets.');
    $Self->AddOption(
        Name        => 'ticket-id',
        Description => "Specify one or more ticket ids of tickets to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'ticket-id-range',
        Description => "Specify a range of ticket ids to be deleted. (e.g. 1..10)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'clean-system',
        Description => "Remove all tickets but leave initial welcome ticket",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $OptionsCounter;
    for my $Option (qw(ticket-id ticket-id-range clean-system)) {
        if ( $Self->GetOption($Option) ) {
            $OptionsCounter++;
        }
    }

    if ( $OptionsCounter > 1 ) {
        die("Only one option (ticket-id or ticket-id-range or clean-system) can be used at a time!\n");
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting tickets...</yellow>\n");

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my @TicketIDs;
    if ( $Self->GetOption('ticket-id') ) {
        @TicketIDs = @{ $Self->GetOption('ticket-id') };
    }
    elsif ( $Self->GetOption('ticket-id-range') ) {
        if ( $Self->GetOption('ticket-id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @TicketIDs = ( $1 .. $2 );
        }
    }
    elsif ( $Self->GetOption('clean-system') ) {

        # search all tickets
        my @TicketIDsRaw = $TicketObject->TicketSearch(
            Result  => 'ARRAY',
            UserID  => 1,
            SortBy  => 'Age',
            OrderBy => 'Up',
        );

        # remove welcome ticket
        @TicketIDs = grep { $_ != 1 } @TicketIDsRaw;
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

        # delete ticket
        my $Success = $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );

        if ( !$Success ) {
            $Self->PrintError("Can't delete ticket $TicketID\n");
            $Failed = 1;
        }
        else {
            $Self->Print(" Deleted ticket $TicketID\n");
        }
    }

    if ($Failed) {
        $Self->PrintError("Not all tickets where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
