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

package Console::Command::Dev::Service::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Service',
    'Kernel::System::Service',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Services in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search services with specified service name e.g. *MyService*.",
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

        %List = $Kernel::OM->Get('Dev::Service')->ServiceSearch(
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

    my @Items;

    my $ServiceObject = $Kernel::OM->Get('Kernel::System::Service');

    ITEMID:
    for my $ItemID (@ItemIDs) {
        next ITEMID if !$ItemID;

        my %Item = $ServiceObject->ServiceGet(
            ServiceID => $ItemID,
            UserID    => 1,
        );
        next ITEMID if !%Item;

        $Item{ID} = $Item{ServiceID} || '';

        push @Items, \%Item,;
    }

    if ( !@Items ) {
        $Self->Print("No services found\n");

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
