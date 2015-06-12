# --
# Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::CRSearch;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

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

    my @Tickets;
    TICKETID:
    for my $TicketID (@TicketIDs) {

        next TICKETID if !$TicketID;

        # get ticket details
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );
        next TICKETID if !%Ticket;

        # store ticket details
        push @Tickets, \%Ticket,
    }

    my %ColumnLength = (
        ID       => 7,
        Number   => 20,
        Owner    => 24,
        Customer => 30,
        Title    => 24,
    );

    my $Header;
    for my $HeaderName (qw(ID Number Owner Customer Title)) {
        my $HeaderLength = length $HeaderName;
        my $WhiteSpaces;
        if ( $HeaderLength < $ColumnLength{$HeaderName} ) {
            $WhiteSpaces = $ColumnLength{$HeaderName} - $HeaderLength;
        }

        # $WhiteSpaces = $WhiteSpaces + 3;
        # print STDERR "Debug $WhiteSpaces \n"; # TODO: Delete developer comment
        $Header .= sprintf '%-*s', $ColumnLength{$HeaderName}, "$HeaderName";
    }
    $Header .= "\n";
    $Header .= '=' x 100;
    $Self->Print("$Header\n");

    if ( !@Tickets ) {
        $Self->Print("No tickets found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $Content;

    # print each ticket row
    for my $Ticket (@Tickets) {

        my $Row;

        # prepare ticket information
        $Ticket->{ID}       = $Ticket->{TicketID}       || '';
        $Ticket->{Number}   = $Ticket->{TicketNumber}   || '';
        $Ticket->{Owner}    = $Ticket->{Owner}          || '';
        $Ticket->{Customer} = $Ticket->{CustomerUserID} || '';
        $Ticket->{Title}    = $Ticket->{Title}          || '';

        # print ticket row
        for my $Element (qw(ID Number Owner Customer Title)) {
            my $ElementLength = length $Ticket->{$Element};
            my $WhiteSpaces;
            if ( $ElementLength < $ColumnLength{$Element} ) {
                $WhiteSpaces = $ColumnLength{$Element} - $ElementLength;
            }
            $Row .= sprintf '%-*s', $ColumnLength{$Element}, $Ticket->{$Element};
        }
        $Row .= "\n";
        $Content .= $Row;
    }

    $Self->Print("$Content\n");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
