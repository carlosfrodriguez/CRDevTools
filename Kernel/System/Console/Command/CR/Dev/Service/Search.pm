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

package Kernel::System::Console::Command::CR::Dev::Service::Search;

use strict;
use warnings;

use parent qw(
    Kernel::System::Console::BaseCommand
    Kernel::System::Console::CRBaseCommand
);

our @ObjectDependencies = (
    'Kernel::System::CR::Dev::Service',
    'Kernel::System::Service',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Services in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search Services with specified Service name e.g. *MyService*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing Services...</yellow>\n");

    my %SearchOptions;

    my %List;

    # Service name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');

        %List = $Kernel::OM->Get('Kernel::System::CR::Dev::Service')->ServiceSearch(
            %SearchOptions,
            Valid => 0,
        );
    }
    else {
        %List = $Kernel::OM->Get('Kernel::System::Service')->ServiceList(
            Valid  => 0,
            UserID => 1,
        );
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    # to store all item details
    my @Items;

    # get Service object
    my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        # get item details
        my %Item = $ServiceObject->ServiceGet(
            ServiceID => $ItemID,
            UserID    => 1,
        );
        next ITEM if !%Item;

        # prepare Service information
        $Item{ID} = $Item{ServiceID} || '';

        # store item details
        push @Items, \%Item,
    }

    if ( !@Items ) {
        $Self->Print("No Services found\n");

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
