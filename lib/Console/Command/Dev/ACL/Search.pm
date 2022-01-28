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

package Console::Command::Dev::ACL::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::ACL',
    'Kernel::System::ACL::DB::ACL',
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

    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');
    }

    my $ACLObject = $Kernel::OM->Get('Kernel::System::ACL::DB::ACL');

    my %List;
    if (%SearchOptions) {
        %List = $Kernel::OM->Get('Dev::ACL')->ACLSearch(
            %SearchOptions,
        );
    }
    else {
        %List = %{ $ACLObject->ACLList( UserID => 1 ) };
    }

    my @ItemIDs = sort { $a cmp $b } keys %List;

    my @Items;

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        my $Item = $ACLObject->ACLGet(
            ID     => $ItemID,
            UserID => 1,
        );
        next ITEM if !$Item;

        push @Items, $Item,;
    }

    if ( !@Items ) {
        $Self->Print("No ACLS found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'ID', 'Name', ],
            Body   => [ map { [ $_->{ID}, $_->{Name}, ] } @Items ],
        },
        Indention => 2,
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
