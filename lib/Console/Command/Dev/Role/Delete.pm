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

package Console::Command::Dev::Role::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Role',
    'Kernel::System::Group',
    'Kernel::System::Ticket',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more Roles.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more role ids of Roles to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of role ids to be deleted. (e.g. 1..10)",
        Required    => 0,
        HasValue    => 1,
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

    $Self->Print("<yellow>Deleting Roles...</yellow>\n");

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');

    my @ItemsToDelete;
    if ( $Self->GetOption('id') ) {
        @ItemsToDelete = @{ $Self->GetOption('id') };
    }
    elsif ( $Self->GetOption('id-range') ) {
        if ( $Self->GetOption('id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @ItemsToDelete = ( $1 .. $2 );
        }
    }

    my $DevRoleObject = $Kernel::OM->Get('Dev::Role');

    my $Failed;

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        my %Item = $GroupObject->RoleGet(
            ID     => $ItemID,
            UserID => 1,
        );

        if ( !%Item ) {
            $Self->PrintError("The role with ID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        # Delete Role
        my $Success = $DevRoleObject->RoleDelete(
            RoleID => $ItemID,
            UserID => 1,
        );

        if ( !$Success ) {
            $Self->PrintError("Can't delete role $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted role <yellow>$ItemID</yellow>\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all roles where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();

}

1;
