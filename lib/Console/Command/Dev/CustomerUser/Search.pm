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

package Console::Command::Dev::CustomerUser::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
    'Kernel::System::CustomerUser',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Customer Users in the system.');

    $Self->AddOption(
        Name        => 'login',
        Description => "Search customer users with specified customer user login name e.g. *MyCustomerUser*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'email',
        Description => 'Search CustomerUsers with specified customer user email address e.g. *some@example.com*.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'full-text',
        Description => "Full text search on fields login, first_name last_name e.g. *text*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing Customer Users...</yellow>\n");

    my %SearchOptions;

    my %List;

    # CustomerUser name search
    if ( $Self->GetOption('login') ) {
        $SearchOptions{UserLogin} = $Self->GetOption('login');
    }
    if ( $Self->GetOption('email') ) {
        $SearchOptions{Postmaster} = $Self->GetOption('email');
    }
    if ( $Self->GetOption('full-text') ) {
        $SearchOptions{Search} = $Self->GetOption('full-text');
    }

    no warnings 'once';    ## no critic
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    if (%SearchOptions) {

        %List = $CustomerUserObject->CustomerSearch(
            %SearchOptions,
            Valid => 0,
            Limit => 10_000,
        );
    }
    else {
        %List = $CustomerUserObject->CustomerSearch(
            Search => '**',
            Valid  => 0,
            Limit  => 10_000,
        );
    }

    my @ItemIDs = sort { $a cmp $b } keys %List;

    my @Items;

    ITEMID:
    for my $ItemID (@ItemIDs) {

        next ITEMID if !$ItemID;

        # get item details
        my %Item = $CustomerUserObject->CustomerUserDataGet(
            User => $ItemID,
        );
        next ITEMID if !%Item;

        # prepare CustomerUser information
        $Item{Login} = $Item{UserLogin} || '';
        $Item{Email} = $Item{UserEmail} || '';

        # store item details
        push @Items, \%Item,;
    }

    if ( !@Items ) {
        $Self->Print("No CustomerUsers found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'Login', 'Email', ],
            Body   => [ map { [ $_->{Login}, $_->{Email}, ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
