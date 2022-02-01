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

package Console::Command::Dev::ITSMConfigItem::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::ITSMConfigItem',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more ITSM Config Items.');
    $Self->AddOption(
        Name        => 'name',
        Description => "Specify the name of config items to be deleted e.g. *MyName*..",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'id',
        Description => 'Specify the email id of config items to be deleted e.g. *ITSMConfigItem*..',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of config items to be deleted. (e.g. 1..10)",
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
    for my $Option (qw(name id id-range)) {
        if ( $Self->GetOption($Option) ) {
            $OptionsCounter++;
        }
    }

    if ( $OptionsCounter > 1 ) {
        die("Only one option (name, id or id-range) can be used at a time!\n");
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting ITSM config items...</yellow>\n");

    my %SearchOptions;

    my $Name = $Self->GetOption('name');

    my @ItemsToDelete;
    if ( $Self->GetOption('id') ) {
        @ItemsToDelete = ( $Self->GetOption('id') );
    }
    elsif ( $Self->GetOption('id-range') ) {
        if ( $Self->GetOption('id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @ItemsToDelete = ( $1 .. $2 );
        }
    }

    # ITSMConfigItem name search
    elsif ($Name) {
        $SearchOptions{Name} = $Name;
    }

    no warnings 'once';    ## no critic
    my $ITSMConfigItemObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem');

    if (%SearchOptions) {

        my $ItemIDs = $ITSMConfigItemObject->ConfigItemSearchExtended(
            %SearchOptions,
            Valid => 0,
            Limit => 10_000,
        );
        @ItemsToDelete = sort @{$ItemIDs};
    }

    my $Failed;

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        my %Item = $ITSMConfigItemObject->ConfigItemGet(
            ConfigItemID => $ItemID,
        );
        if ( !%Item ) {
            $Self->PrintError("The ITSM config item with ConfigItemID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        my $Success = $ITSMConfigItemObject->ConfigItemDelete(
            ConfigItemID => $ItemID,
            UserID       => 1,
        );
        if ( !$Success ) {
            $Self->PrintError("Can't delete ITSM config item $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted ITSM config item <yellow>$ItemID</yellow>\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all ITSM config items where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
