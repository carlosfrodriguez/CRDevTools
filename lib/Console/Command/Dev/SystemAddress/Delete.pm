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

package Console::Command::Dev::SystemAddress::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::SystemAddress',
    'Kernel::System::SystemAddress',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more system addresses.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more system address ids of system addresses to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of system address ids to be deleted e.g. 1..10.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'email',
        Description => "Specify system address email to be deleted e.g. *MySystemAddress\@Email*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'name',
        Description => "Specify system address names to be deleted e.g. *MySystemAddress*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
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

    $Self->Print("<yellow>Deleting System Addresses...</yellow>\n");

    my $DevSystemAddressObject = $Kernel::OM->Get('Dev::SystemAddress');

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
        my %List = $DevSystemAddressObject->SystemAddressSearch(
            Name  => $Self->GetOption('name'),
            Valid => 0,
        );
        @ItemsToDelete = sort keys %List;
    }
    elsif ( $Self->GetOption('email') ) {
        my %List = $DevSystemAddressObject->SystemAddressSearch(
            Name  => $Self->GetOption('email'),
            Valid => 0,
        );
        @ItemsToDelete = sort keys %List;
    }

    my $SystemAddressObject = $Kernel::OM->Get('Kernel::System::SystemAddress');

    my $Failed;

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        my %Item = $SystemAddressObject->SystemAddressGet(
            ID => $ItemID,
        );

        if ( !%Item ) {
            $Self->PrintError("The system address with ID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        # Delete system address
        my $Success = $DevSystemAddressObject->SystemAddressDelete(
            SystemAddressID => $ItemID,
            UserID          => 1,
        );

        if ( !$Success ) {
            $Self->PrintError("Can't delete system address $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted system address <yellow>$ItemID</yellow>\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all system addresses where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();

}

1;
