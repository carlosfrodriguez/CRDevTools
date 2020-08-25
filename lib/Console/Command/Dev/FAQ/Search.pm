# --
# Copyright (C) 2020 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2020 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::FAQ::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::FAQ',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search FAQ items in the system.');

    $Self->AddOption(
        Name        => 'faq-name',
        Description => "Search FAQ with specified name e.g. *MyFAQ*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'faq-full-text',
        Description => "Search FAQ with specified text e.g. *MyFAQ*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing FAQ Items...</yellow>\n");

    my %SearchOptions = ();

    # FAQ name search
    if ( $Self->GetOption('faq-name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');
    }

    # Text search
    if ( $Self->GetOption('faq-full-text') ) {
        $SearchOptions{What} = $Self->GetOption('text');
    }

    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

    # Search all tickets
    my @FAQIDs = $FAQObject->FAQSearch(
        Result           => 'ARRAY',
        UserID           => 1,
        OrderBy          => [ 'FAQID', ],
        OrderByDirection => ['Up'],
        %SearchOptions,
    );

    my @Items;
    FAQID:
    for my $FAQID (@FAQIDs) {

        next FAQID if !$FAQID;

        # Get FAQ details
        my %FAQ = $FAQObject->FAQGet(
            ItemID => $FAQID,
            UserID => 1,
        );
        next FAQID if !%FAQ;

        # Prepare FAQ information
        $FAQ{Number} //= '--';

        # store ticket details
        push @Items, \%FAQ;
    }

    if ( !@Items ) {
        $Self->Print("No FAQ item found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my %ColumnLength = (
        ItemID => 20,
        Number => 20,
        Title  => 24,
    );

    $Self->OutputTable(
        Items        => \@Items,
        Columns      => [ 'ItemID', 'Number', 'Title', ],
        ColumnLength => {
            ItemID => 20,
            Number => 20,
            Title  => 24,
        },
    );

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
