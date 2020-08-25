# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::DynamicField::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicFieldValue',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more DynamicFields.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more DynamicField ids of DynamicFields to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of DynamicField ids to be deleted. (e.g. 1..10)",
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

    $Self->Print("<yellow>Deleting DynamicFields...</yellow>\n");

    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    my @ItemsToDelete;
    if ( $Self->GetOption('id') ) {
        @ItemsToDelete = @{ $Self->GetOption('id') };
    }
    elsif ( $Self->GetOption('id-range') ) {
        if ( $Self->GetOption('id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @ItemsToDelete = ( $1 .. $2 );
        }
    }

    my $Failed;
    my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        # get item details
        my $Item = $DynamicFieldObject->DynamicFieldGet(
            ID     => $ItemID,
            UserID => 1,
        );

        # check if item exists
        if ( !$Item || !%{$Item} ) {
            $Self->PrintError("The DynamicField with ID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        my $ValuesDeleteSuccess = $DynamicFieldValueObject->AllValuesDelete(
            FieldID => $ItemID,
            UserID  => 1,
        );
        if ( !$ValuesDeleteSuccess ) {
            $Self->PrintError("Can't delete all DynamicField $ItemID values!\n");
            $Failed = 1;
            next ITEMID;
        }

        # delete dynamic field
        my $Success = $DynamicFieldObject->DynamicFieldDelete(
            ID     => $ItemID,
            UserID => 1,
        );
        if ( !$Success ) {
            $Self->PrintError("Can't delete DynamicField $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted DynamicField <yellow>$ItemID</yellow>\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all DynamicFields where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();

}

1;
