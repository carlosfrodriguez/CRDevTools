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

package Kernel::System::Console::Command::CR::Dev::User::Search;

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

    $Self->Description('Search Users in the system.');

    $Self->AddOption(
        Name        => 'login',
        Description => "Search Users with specified User login name e.g. *MyUser*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'email',
        Description => 'Search Users with specified User email address e.g. some@example.com.',
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

    $Self->Print("<yellow>Listing Users...</yellow>\n");

    my %SearchOptions;

    my %List;

    # User name search
    if ( $Self->GetOption('login') ) {
        $SearchOptions{UserLogin} = $Self->GetOption('login');
    }
    if ( $Self->GetOption('email') ) {
        $SearchOptions{PostMasterSearch} = $Self->GetOption('email');
    }
    if ( $Self->GetOption('full-text') ) {
        $SearchOptions{Search} = $Self->GetOption('full-text');
    }

    # get User object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    if (%SearchOptions) {

        %List = $UserObject->UserSearch(
            %SearchOptions,
            Valid => 0,
        );
    }
    else {
        %List = $Kernel::OM->Get('Kernel::System::User')->UserList(
            Valid => 0,
        );
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    # to store all item details
    my @Items;

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        # get item details
        my %Item = $UserObject->GetUserData(
            UserID => $ItemID,
        );

        next ITEM if !%Item;

        # prepare User information
        $Item{ID}    = $Item{UserID}    || '';
        $Item{Login} = $Item{UserLogin} || '';
        $Item{Email} = $Item{UserEmail} || '';

        # store item details
        push @Items, \%Item,
    }

    if ( !@Items ) {
        $Self->Print("No Users found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->OutputTable(
        Items        => \@Items,
        Columns      => [ 'ID', 'Login', 'Email', ],
        ColumnLength => {
            ID    => 7,
            Login => 50,
            Email => 50,
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
