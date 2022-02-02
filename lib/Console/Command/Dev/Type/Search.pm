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

package Console::Command::Dev::Type::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Type',
    'Kernel::System::Type',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Ticket Types in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search types with specified type name e.g. *MyType*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing Types...</yellow>\n");

    my %SearchOptions;

    my %List;

    # Type name search.
    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');
        %List = $Kernel::OM->Get('Dev::Type')->TypeSearch(
            %SearchOptions,
            Valid => 0,
        );
    }
    else {
        %List = $Kernel::OM->Get('Kernel::System::Type')->TypeList(
            Valid  => 0,
            UserID => 1,
        );
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    my @Items;

    my $TypeObject = $Kernel::OM->Get('Kernel::System::Type');

    ITEMID:
    for my $ItemID (@ItemIDs) {
        next ITEMID if !$ItemID;

        my %Item = $TypeObject->TypeGet(
            ID     => $ItemID,
            UserID => 1,
        );
        next ITEMID if !%Item;

        # prepare Type information
        $Item{ID} = $Item{ID} || '';

        push @Items, \%Item;
    }

    if ( !@Items ) {
        $Self->Print("No types found\n");

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
