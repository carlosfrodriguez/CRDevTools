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

package Kernel::System::Console::Command::CR::Dev::ACL::Search;

use strict;
use warnings;

use parent qw(
    Kernel::System::Console::BaseCommand
    Kernel::System::Console::CRBaseCommand
);

our @ObjectDependencies = (
    'Kernel::System::ACL::DB::ACL',
    'Kernel::System::CR::Dev::ACL',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search ACLs in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search ACLs with specified ACL name e.g. *MyACL*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing ACLs...</yellow>\n");

    my %SearchOptions;

    my %List;

    # ACL name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{UserLogin} = $Self->GetOption('name');
    }

    my $ACLObject = $Kernel::OM->Get('Kernel::System::ACL::DB::ACL');

    if (%SearchOptions) {

        %List = $Kernel::OM->Get('Kernel::System::CR::Dev::ACL')->ACLSearch(
            %SearchOptions,
        );
    }
    else {
        %List = %{ $ACLObject->ACLList( UserID => 1 ) };
    }

    my @ItemIDs = sort { $a cmp $b } keys %List;

    # to store all item details
    my @Items;

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        # get item details
        my $Item = $ACLObject->ACLGet(
            ID     => $ItemID,
            UserID => 1,
        );
        next ITEM if !$Item;

        # store item details
        push @Items, $Item,
    }

    if ( !@Items ) {
        $Self->Print("No ACLS found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->OutputTable(
        Items        => \@Items,
        Columns      => [ 'ID', 'Name', ],
        ColumnLength => {
            ID   => 50,
            Name => 50,
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
