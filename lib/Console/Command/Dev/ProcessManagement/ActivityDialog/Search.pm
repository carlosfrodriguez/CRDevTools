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

package Console::Command::Dev::ProcessManagement::ActivityDialog::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Process',
    'Dev::ProcessManagement::ActivityDialog',
    'Kernel::System::ProcessManagement::DB::ActivityDialog',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Process Management Activity Dialogs in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search Activities with specified ActivityDialog name e.g. *MyActivityDialog*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing Activity Dialogs...</yellow>\n");

    my %SearchOptions;

    my %List;

    # Process name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{UserLogin} = $Self->GetOption('name');
    }

    my $ActivityDialogObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::DB::ActivityDialog');

    if (%SearchOptions) {

        %List = $Kernel::OM->Get('Dev::ProcessManagement::ActivityDialog')->ActivityDialogSearch(
            %SearchOptions,
        );
    }
    else {
        %List = %{ $ActivityDialogObject->ActivityDialogList( UserID => 1 ) };
    }

    my @ItemIDs = sort { $a cmp $b } keys %List;

    # to store all item details
    my @Items;

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        # get item details
        my $Item = $ActivityDialogObject->ActivityDialogGet(
            ID     => $ItemID,
            UserID => 1,
        );
        next ITEM if !$Item;

        # store item details
        push @Items, $Item,;
    }

    if ( !@Items ) {
        $Self->Print("No Activity Dialogs found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->OutputTable(
        Items        => \@Items,
        Columns      => [ 'ID', 'EntityID', 'Name', ],
        ColumnLength => {
            ID       => 20,
            EntityID => 50,
            Name     => 30,
        },
    );

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
