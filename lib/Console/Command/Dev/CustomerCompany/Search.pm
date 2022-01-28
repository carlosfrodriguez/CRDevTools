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

package Console::Command::Dev::CustomerCompany::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
    'Kernel::System::CustomerCompany',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Customer Companies in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search customer companies with specified customer company name e.g. *MyCustomerName*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'id',
        Description => 'Search customer companies with specified customer company id e.g. *Customer*.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing Customer Companies...</yellow>\n");

    my %SearchOptions;

    if ( $Self->GetOption('name') ) {
        $SearchOptions{CustomerCompanyName} = $Self->GetOption('name');
    }
    if ( $Self->GetOption('id') ) {
        $SearchOptions{CustomerID} = $Self->GetOption('id');
    }

    no warnings 'once';    ## no critic
    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    my $ItemIDs;

    if (%SearchOptions) {
        $ItemIDs = $CustomerCompanyObject->CustomerCompanySearchDetail(
            %SearchOptions,
            Valid => 0,
            Limit => 10_000,
        );
    }
    else {
        $ItemIDs = $CustomerCompanyObject->CustomerCompanySearchDetail(
            Search => '**',
            Valid  => 0,
            Limit  => 10_000,
        );
    }

    my @Items;

    ITEM:
    for my $ItemID ( sort { $a cmp $b } @{ $ItemIDs || [] } ) {

        next ITEM if !$ItemID;

        my %Item = $CustomerCompanyObject->CustomerCompanyGet(
            CustomerID => $ItemID,
        );
        next ITEM if !%Item;

        # Prepare CustomerCompany information.
        $Item{Name} = $Item{CustomerCompanyName} || '';
        $Item{ID}   = $Item{CustomerID}          || '';

        push @Items, \%Item,;
    }

    if ( !@Items ) {
        $Self->Print("No CustomerCompanies found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'CustomerID', 'Name', ],
            Body   => [ map { [ $_->{ID}, $_->{Name}, ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
