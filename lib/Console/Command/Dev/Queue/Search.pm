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

package Console::Command::Dev::Queue::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::Queue',
    'Kernel::System::Queue',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Search queues in the system.');

    $Self->AddOption(
        Name        => 'name',
        Description => "Search queues with specified queue name e.g. *MyQueue*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing queues...</yellow>\n");

    my %SearchOptions;

    my %List;

    # queue name search
    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');

        %List = $Kernel::OM->Get('Dev::Queue')->QueueSearch(
            %SearchOptions,
            Valid => 0,
        );
    }
    else {
        %List = $Kernel::OM->Get('Kernel::System::Queue')->QueueList(
            Valid => 0,
        );
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    # to store all item details
    my @Items;

    # get Queue object
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        # get item details
        my %Item = $QueueObject->QueueGet(
            ID => $ItemID,
        );
        next ITEM if !%Item;

        # prepare queue information
        $Item{ID} = $Item{QueueID} || '';

        # store item details
        push @Items, \%Item,;
    }

    if ( !@Items ) {
        $Self->Print("No queues found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->OutputTable(
        Items        => \@Items,
        Columns      => [ 'ID', 'Name', ],
        ColumnLength => {
            ID   => 7,
            Name => 20,
        },
    );

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
