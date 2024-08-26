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

package Console::Command::Dev::GeneralCatalog::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::GeneralCatalog',
    'Kernel::System::GeneralCatalog',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search GeneralCatalogs in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search GeneralCatalogs with specified GeneralCatalog name e.g. *MyGeneralCatalog*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing GeneralCatalogs...</yellow>\n");

    my %SearchOptions;

    my %List;

    # GeneralCatalog name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');

        %List = $Kernel::OM->Get('Dev::GeneralCatalog')->GeneralCatalogSearch(
            %SearchOptions,
            Valid => 0,
        );
    }
    else {

        my $ClassList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ClassList();

        for my $Class ( @{$ClassList} ) {

            my $ListPart = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
                Class => $Class,
                Valid => 0,
            );

            for my $ItemID ( sort keys %{$ListPart} ) {
                $List{$ItemID} = $ListPart->{$ItemID};
            }
        }
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    my @Items;

    my $GeneralCatalogObject = $Kernel::OM->Get('Kernel::System::GeneralCatalog');

    ITEMID:
    for my $ItemID (@ItemIDs) {
        next ITEMID if !$ItemID;

        my $Item = $GeneralCatalogObject->ItemGet(
            ItemID => $ItemID,
            UserID => 1,
        );
        my %Item = %{$Item};
        next ITEMID if !%Item;

        $Item{ID} = $Item->{ItemID} || '';

        push @Items, \%Item,;
    }

    if ( !@Items ) {
        $Self->Print("No GeneralCatalogs found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'ID', 'Name', ],
            Body   => [ map { [ $_->{ID}, $_->{Name} ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
