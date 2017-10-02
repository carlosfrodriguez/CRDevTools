# --
# Copyright (C) 2016 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --

package Kernel::System::Console::Command::CR::Dev::State::Search;

use strict;
use warnings;

use parent qw(
    Kernel::System::Console::BaseCommand
    Kernel::System::Console::CRBaseCommand
);

our @ObjectDependencies = (
    'Kernel::System::CR::Dev::State',
    'Kernel::System::State',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search States in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search States with specified State name e.g. *MyState*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing States...</yellow>\n");

    my %SearchOptions;

    my %List;

    # State name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');
        %List = $Kernel::OM->Get('Kernel::System::CR::Dev::State')->StateSearch(
            %SearchOptions,
            Valid => 0,
        );
    }
    else {
        %List = $Kernel::OM->Get('Kernel::System::State')->StateList(
            Valid  => 0,
            UserID => 1,
        );
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    # to store all item details
    my @Items;

    # get State object
    my $StateObject = $Kernel::OM->Get('Kernel::System::State');

    ITEM:
    for my $ItemID (@ItemIDs) {
        next ITEM if !$ItemID;

        # get item details
        my %Item = $StateObject->StateGet(
            ID     => $ItemID,
            UserID => 1,
        );
        next ITEM if !%Item;

        # prepare State information
        $Item{ID} = $Item{ID} || '';

        # store item details
        push @Items, \%Item,
    }

    if ( !@Items ) {
        $Self->Print("No States found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->OutputTable(
        Items        => \@Items,
        Columns      => [ 'ID', 'Name', ],
        ColumnLength => {
            ID   => 7,
            Name => 20,
        },
    );

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
