# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::Process::DeleteTickets;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete All Processes Tickets.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting Process Tickets...</yellow>\n");

    my $ProcessIDDF = $Kernel::OM->Get('Kernel::Config')->Get('Process::DynamicFieldProcessManagementProcessID');

    if ( !$ProcessIDDF ) {
        $Self->PrintError("Could not get DynamicField used for ProcessID from the system configuration\n");
        return $Self->ExitCodeError();
    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # Search all process tickets.
    my @TicketIDs = $TicketObject->TicketSearch(
        Result                      => 'ARRAY',
        UserID                      => 1,
        SortBy                      => 'Age',
        OrderBy                     => 'Up',
        ContentSearch               => 'OR',
        FullTextIndex               => 1,
        "DynamicField_$ProcessIDDF" => {
            Like => '****',
        },
    );

    if ( !@TicketIDs ) {
        $Self->Print("No Tickets to delete\n");
        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $Failed;

    TICKETID:
    for my $TicketID (@TicketIDs) {

        next TICKETID if !$TicketID;

        next TICKETID if $TicketID eq 1;

        # Get ticket details.
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # Check if ticket exists.
        if ( !%Ticket ) {
            $Self->PrintError("The ticket with ID $TicketID does not exist!\n");
            $Failed = 1;
            next TICKETID;
        }

        # Delete ticket.
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

=head1 TERMS AND CONDITIONS

This software is a component of the CRDevTools project (L<https://github.com/carlosfrodriguez/CRDevTools/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
