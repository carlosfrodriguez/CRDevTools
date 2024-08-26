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

package Console::Command::Dev::User::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::User',
    'Kernel::System::User',
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more Users.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more user ids of users to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of user ids to be deleted. (e.g. 1..10)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'login',
        Description => "Specify the login of users to be deleted e.g. *MyCustomerUser*..",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'delete-tickets',
        Description => "Also remove all associated tickets with deleted users",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $OptionsCounter = 0;
    for my $Option (qw(id id-range login)) {
        if ( $Self->GetOption($Option) ) {
            $OptionsCounter++;
        }
    }

    if ( $OptionsCounter > 1 ) {
        die("Only one option (id, id-range login) can be used at a time!\n");
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting users...</yellow>\n");

    my $Login = $Self->GetOption('login');

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    my @ItemsToDelete;
    if ( $Self->GetOption('id') ) {
        @ItemsToDelete = @{ $Self->GetOption('id') };
    }
    elsif ( $Self->GetOption('id-range') ) {
        if ( $Self->GetOption('id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @ItemsToDelete = ( $1 .. $2 );
        }
    }
    elsif ($Login) {
        my %List;

        if ( $Login =~ m{\*} ) {

            %List = $UserObject->UserSearch(
                UserLogin => $Login,
                Valid     => 0,
            );
        }
        elsif ($Login) {
            my %User = $UserObject->GetUserData(
                UserLogin => $Login,
            );
            $List{ $User{UserLogin} } = $User{UserEmail};
        }
        @ItemsToDelete = sort keys %List;
    }

    my $Failed;

    my $DevUserObject = $Kernel::OM->Get('Dev::User');
    my $TicketObject  = $Kernel::OM->Get('Kernel::System::Ticket');

    my %UserList = $UserObject->UserList(
        Type  => 'Short',
        Valid => 0,
    );

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        # check if item exists
        if ( !$UserList{$ItemID} ) {
            $Self->Print("<yellow>The user with ID $ItemID does not exist, skipping... </yellow>\n");
            next ITEMID;
        }

        my @TicketIDs = $DevUserObject->RelatedTicketsGet(
            Limit  => 1000,
            UserID => $ItemID,
        );

        if ( $Self->GetOption('delete-tickets') ) {

            TICKETID:
            for my $TicketID (@TicketIDs) {

                # Delete ticket
                my $Success = $TicketObject->TicketDelete(
                    TicketID => $TicketID,
                    UserID   => 1,
                );
                if ( !$Success ) {
                    $Self->PrintError("Can't delete ticket $TicketID\n");
                    $Failed = 1;
                    next TICKETID;
                }

                $Self->Print("  Ticket $TicketID deleted as it was used by User <yellow>$ItemID</yellow>\n");
            }
        }
        elsif (@TicketIDs) {
            $Self->PrintError("Could not delete User $ItemID due the following tickets use it:\n");
            for my $TicketID (@TicketIDs) {
                $Self->Print("  Used by Ticket <red>$TicketID</red>\n");
                $Failed = 1;
            }
            next ITEMID;
        }

        my $Success = $DevUserObject->UserDelete(
            UserID => $ItemID,
        );
        if ( !$Success ) {
            $Self->PrintError("Can't delete user $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted user <yellow>$ItemID</yellow>\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all users where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
