# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --

package Kernel::System::Console::Command::CR::Dev::Ticket::Search;

use strict;
use warnings;

use parent qw(
    Kernel::System::Console::BaseCommand
    Kernel::System::Console::CRBaseCommand
);

our @ObjectDependencies = (
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search tickets in the system.');

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

    $Self->Print("<yellow>Listing tickets...</yellow>\n");

    my %SearchOptions;

    # ticket number search
    if ( $Self->GetOption('ticket-number') ) {
        $SearchOptions{TicketNumber} = $Self->GetOption('ticket-number');
    }

    # title search
    if ( $Self->GetOption('ticket-title') ) {
        $SearchOptions{Title} = $Self->GetOption('ticket-title');
    }

    # customer search
    if ( $Self->GetOption('ticket-customer') ) {
        $SearchOptions{CustomerUserLogin} = $Self->GetOption('ticket-customer');
    }

    # full text search on From To Cc Subject Body
    if ( $Self->GetOption('ticket-full-text') ) {
        $SearchOptions{ContentSearch} = 'OR';
        for my $TicketElement (qw(From To Cc Subject Body)) {
            $SearchOptions{$TicketElement} = $Self->GetOption('ticket-full-text');
        }
    }

    # owner ID search
    if ( $Self->GetOption('ticket-owner') ) {

        my $OwnerLogin = $Self->GetOption('ticket-owner');

        # search by owner needs to have a valid user, do a user lookup and retrieve the UserID
        my $UserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserLogin => $OwnerLogin,
        );
        if ( !$UserID ) {
            $Self->PrintError("The user $OwnerLogin does not exist in the database!\n");
            return $Self->ExitCodeError();
        }

        $SearchOptions{OwnerIDs} = [$UserID];
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # search all tickets
    my @TicketIDs = $TicketObject->TicketSearch(
        Result  => 'ARRAY',
        UserID  => 1,
        SortBy  => 'Age',
        OrderBy => 'Up',
        %SearchOptions,
    );

    my @Items;
    TICKETID:
    for my $TicketID (@TicketIDs) {

        next TICKETID if !$TicketID;

        # get ticket details
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );
        next TICKETID if !%Ticket;

        # prepare ticket information
        $Ticket{ID}       = $Ticket{TicketID}       || '';
        $Ticket{Number}   = $Ticket{TicketNumber}   || '';
        $Ticket{Owner}    = $Ticket{Owner}          || '';
        $Ticket{Customer} = $Ticket{CustomerUserID} || '';
        $Ticket{Title}    = $Ticket{Title}          || '';

        # store ticket details
        push @Items, \%Ticket,
    }

    if ( !@Items ) {
        $Self->Print("No tickets found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my %ColumnLength = (
        ID       => 7,
        Number   => 20,
        Owner    => 24,
        Customer => 30,
        Title    => 24,
    );

    $Self->OutputTable(
        Items        => \@Items,
        Columns      => [ 'ID', 'Number', 'Owner', 'Customer', 'Title' ],
        ColumnLength => {
            ID       => 7,
            Number   => 20,
            Owner    => 24,
            Customer => 30,
            Title    => 24,
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
