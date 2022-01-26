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

package Console::Command::Dev::Type::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Type',
    'Kernel::System::Type',
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more ticket types.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more Type ids of Types to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of Type ids to be deleted. (e.g. 1..10)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'delete-tickets',
        Description => "also remove all associated tickets with deleted Types",
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

    $Self->Print("<yellow>Deleting Types...</yellow>\n");

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TypeObject   = $Kernel::OM->Get('Kernel::System::Type');

    my @ItemsToDelete;
    if ( $Self->GetOption('id') ) {
        @ItemsToDelete = @{ $Self->GetOption('id') };
    }
    elsif ( $Self->GetOption('id-range') ) {
        if ( $Self->GetOption('id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @ItemsToDelete = ( $1 .. $2 );
        }
    }

    my $DevTypeObject = $Kernel::OM->Get('Dev::Type');

    my $Failed;

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        # get item details
        my %Item = $TypeObject->TypeGet(
            ID     => $ItemID,
            UserID => 1,
        );

        # check if item exists
        if ( !%Item ) {
            $Self->PrintError("The Type with ID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        my @TicketIDs = $TicketObject->TicketSearch(
            Result  => 'ARRAY',
            Limit   => 1000,
            TypeIDs => [$ItemID],
            UserID  => 1,
        );

        if ( $Self->GetOption('delete-tickets') ) {

            for my $TicketID (@TicketIDs) {

                # delete ticket
                my $Success = $TicketObject->TicketDelete(
                    TicketID => $TicketID,
                    UserID   => 1,
                );

                if ($Success) {
                    $Self->Print("  Ticket $TicketID deleted as it was used by Type <yellow>$ItemID</yellow>\n");
                }
                else {
                    $Self->PrintError("Can't delete ticket $TicketID\n");
                    $Failed = 1;
                }
            }
        }
        elsif (@TicketIDs) {
            $Self->PrintError("Could not delete Type $ItemID due the following tickets use it:\n");
            for my $TicketID (@TicketIDs) {
                $Self->Print("  Used by Ticket <red>$TicketID</red>\n");
                $Failed = 1;
            }
            next ITEMID;
        }

        # delete Type
        my $Success = $DevTypeObject->TypeDelete(
            TypeID => $ItemID,
            UserID => 1,
        );

        if ( !$Success ) {
            $Self->PrintError("Can't delete Type $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted Type <yellow>$ItemID</yellow>\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all Types where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();

}

1;
