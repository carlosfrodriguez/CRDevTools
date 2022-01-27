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

package Console::Command::Dev::SystemAddress::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::SystemAddress',
    'Kernel::System::SystemAddress',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search SystemAddresses in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search system addresses with specified system address name e.g. *MySystemAddress*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'email',
        Description => "Search system addresses with specified system address email e.g. *MySystemAddress\@Email*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing System Addresses...</yellow>\n");

    my %SearchOptions;

    my %List;

    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');

        %List = $Kernel::OM->Get('Dev::SystemAddress')->SystemAddressSearch(
            %SearchOptions,
            Valid => 0,
        );
    }
    elsif ( $Self->GetOption('email') ) {
        $SearchOptions{Email} = $Self->GetOption('email');

        %List = $Kernel::OM->Get('Dev::SystemAddress')->SystemAddressSearch(
            %SearchOptions,
            Valid => 0,
        );
    }
    else {
        %List = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressList(
            Valid => 0,
        );
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    my @Items;

    my $SystemAddressObject = $Kernel::OM->Get('Kernel::System::SystemAddress');

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        my %Item = $SystemAddressObject->SystemAddressGet(
            ID => $ItemID,
        );
        next ITEM if !%Item;

        # Prepare system address information.
        $Item{ID}    = $Item{ID}       || '';
        $Item{Email} = $Item{Name}     || '';
        $Item{Name}  = $Item{Realname} || '';

        push @Items, \%Item;
    }

    if ( !@Items ) {
        $Self->Print("No system addresses found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'ID', 'Email', 'Name', ],
            Body   => [ map { [ $_->{ID}, $_->{Email}, $_->{Name} ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
