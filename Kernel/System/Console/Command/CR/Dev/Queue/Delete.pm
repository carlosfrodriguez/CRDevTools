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

package Kernel::System::Console::Command::CR::Dev::Queue::Delete;

use strict;
use warnings;

use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::CR::Dev::Queue',
    'Kernel::System::Queue',
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more queues.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more queue ids of queues to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of queue ids to be deleted e.g. 1..10.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'name',
        Description => "Specify queue names to be deleted e.g. *MyQueue*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'delete-tickets',
        Description => "also remove all associated tickets with deleted queues.",
        Required    => 0,
        HasValue    => 0,
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

    $Self->Print("<yellow>Deleting queues...</yellow>\n");

    my $DevQueueObject = $Kernel::OM->Get('Kernel::System::CR::Dev::Queue');

    my @ItemsToDelete;
    if ( $Self->GetOption('id') ) {
        @ItemsToDelete = @{ $Self->GetOption('id') };
    }
    elsif ( $Self->GetOption('id-range') ) {
        if ( $Self->GetOption('id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @ItemsToDelete = ( $1 .. $2 );
        }
    }
    elsif ( $Self->GetOption('name') ) {
        my %List = $DevQueueObject->QueueSearch(
            Name  => $Self->GetOption('name'),
            Valid => 0,
        );
        @ItemsToDelete = sort keys %List;
    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');

    my $Failed;

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        # get item details
        my %Item = $QueueObject->QueueGet(
            ID => $ItemID,
        );

        # check if item exists
        if ( !%Item ) {
            $Self->PrintError("The Queue with ID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        my @TicketIDs = $TicketObject->TicketSearch(
            Result   => 'ARRAY',
            Limit    => 1000,
            QueueIDs => [$ItemID],
            UserID   => 1,
        );

        if ( $Self->GetOption('delete-tickets') ) {

            for my $TicketID (@TicketIDs) {

                # delete ticket
                my $Success = $TicketObject->TicketDelete(
                    TicketID => $TicketID,
                    UserID   => 1,
                );

                if ($Success) {
                    $Self->Print("  Ticket $TicketID deleted as it was used by Queue <yellow>$ItemID</yellow>\n");
                }
                else {
                    $Self->PrintError("Can't delete ticket $TicketID\n");
                    $Failed = 1;
                }
            }
        }
        elsif (@TicketIDs) {
            $Self->PrintError("Could not delete Queue $ItemID due the following tickets use it:\n");
            for my $TicketID (@TicketIDs) {
                $Self->Print("  Used by Ticket <red>$TicketID</red>\n");
                $Failed = 1;
            }
            next ITEMID;
        }

        # delete queue
        my $Success = $DevQueueObject->QueueDelete(
            QueueID => $ItemID,
            UserID  => 1,
        );

        if ( !$Success ) {
            $Self->PrintError("Can't delete Queue $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted Queue <yellow>$ItemID</yellow>\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all queues where deleted\n");
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
