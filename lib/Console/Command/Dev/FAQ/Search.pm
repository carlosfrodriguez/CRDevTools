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

    no warnings qw(once);    ## no critic
    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

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

        my %FAQ = $FAQObject->FAQGet(
            ItemID => $FAQID,
            UserID => 1,
        );
        next FAQID if !%FAQ;

        # Prepare FAQ information.
        $FAQ{Number} //= '--';

        push @Items, \%FAQ;
    }

    if ( !@Items ) {
        $Self->Print("No FAQ item found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'ItemID', 'Number', 'Title', ],
            Body   => [ map { [ $_->{ItemID}, $_->{Number}, $_->{Title}, ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
