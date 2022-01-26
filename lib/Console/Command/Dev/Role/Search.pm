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

package Console::Command::Dev::Role::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Role',
    'Kernel::System::Group',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search Roles in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search Roles with specified Role name e.g. *MyRole*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing Roles...</yellow>\n");

    my %SearchOptions;

    my %List;

    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    # Group name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');
        %List = $Kernel::OM->Get('Dev::Role')->RoleSearch(
            %SearchOptions,
            Valid => 0,
        );
    }
    else {
        %List = $GroupObject->RoleList(
            Valid  => 0,
            UserID => 1,
        );
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    my @Items;

    ITEM:
    for my $ItemID (@ItemIDs) {
        next ITEM if !$ItemID;

        my %Item = $GroupObject->RoleGet(
            ID     => $ItemID,
            UserID => 1,
        );
        next ITEM if !%Item;

        # Prepare Role information.
        $Item{ID} = $Item{ID} || '';

        push @Items, \%Item,;
    }

    if ( !@Items ) {
        $Self->Print("No Roles found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my @Body = map { [ $_->{ID}, $_->{Name} ] } @Items;

    my $FormattedOutput = $Self->TableOutput(
        TableData => {
            Header => [ 'ID', 'Name', ],
            Body   => \@Body,
        },
        Indention => 2,
        EvenOdd   => 'yellow',
    );

    $Self->Print("$FormattedOutput");

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
