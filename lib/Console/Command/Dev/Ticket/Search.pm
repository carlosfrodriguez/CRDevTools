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

package Console::Command::Dev::Ticket::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Tickets in the system.');

    $Self->AddOption(
        Name        => 'ticket-number',
        Description => "Search tickets with specified ticket number e.g. *1234*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'ticket-title',
        Description => "Search tickets with specified ticket title e.g. *welcome*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'ticket-owner',
        Description => "Search tickets with specified ticket owner login.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'ticket-customer',
        Description => "Search tickets with specified ticket customer login.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'ticket-full-text',
        Description => "Full text search on fields To, From Cs Subject and Body e.g. *text*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing Tickets...</yellow>\n");

    my %SearchOptions = (
        ArchiveFlags => [ 'y', 'n' ],
    );

    # Ticket number search.
    if ( $Self->GetOption('ticket-number') ) {
        $SearchOptions{TicketNumber} = $Self->GetOption('ticket-number');
    }

    # Title search.
    if ( $Self->GetOption('ticket-title') ) {
        $SearchOptions{Title} = $Self->GetOption('ticket-title');
    }

    # Customer search.
    if ( $Self->GetOption('ticket-customer') ) {
        $SearchOptions{CustomerUserLogin} = $Self->GetOption('ticket-customer');
    }

    # Full text search on From To Cc Subject Body.
    if ( $Self->GetOption('ticket-full-text') ) {
        $SearchOptions{ContentSearch} = 'OR';
        for my $TicketElement (qw(From To Cc Subject Body)) {
            $SearchOptions{$TicketElement} = $Self->GetOption('ticket-full-text');
        }
    }

    # OwnerID search.
    if ( $Self->GetOption('ticket-owner') ) {

        my $OwnerLogin = $Self->GetOption('ticket-owner');

        # Search by owner needs to have a valid user, do a user lookup and retrieve the UserID.
        my $UserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $OwnerLogin,
        );
        if ( !$UserID ) {
            $Self->PrintError("The user $OwnerLogin does not exist in the database!\n");
            return $Self->ExitCodeError();
        }

        $SearchOptions{OwnerIDs} = [$UserID];
    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my @ItemIDs = $TicketObject->TicketSearch(
        Result  => 'ARRAY',
        UserID  => 1,
        SortBy  => 'ID',
        OrderBy => 'Up',
        %SearchOptions,
    );

    my @Items;
    ITEMID:
    for my $ItemID (@ItemIDs) {

        next ITEMID if !$ItemID;

        my %Item = $TicketObject->TicketGet(
            TicketID => $ItemID,
            UserID   => 1,
        );
        next ITEMID if !%Item;

        # Prepare ticket information.
        $Item{ID}       = $Item{TicketID}       || '';
        $Item{Number}   = $Item{TicketNumber}   || '';
        $Item{Owner}    = $Item{Owner}          || '';
        $Item{Customer} = $Item{CustomerUserID} || '';
        $Item{Title}    = $Item{Title}          || '';

        push @Items, \%Item;
    }

    if ( !@Items ) {
        $Self->Print("No tickets found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'ID', 'Number', 'Owner', 'Customer', 'Title' ],
            Body   => [ map { [ $_->{ID}, $_->{Number}, $_->{Owner}, $_->{Customer}, $_->{Title}, ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
