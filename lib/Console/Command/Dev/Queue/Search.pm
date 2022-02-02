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

    $Self->Print("<yellow>Listing Queues...</yellow>\n");

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

    ITEMID:
    for my $ItemID (@ItemIDs) {
        next ITEMID if !$ItemID;

        my %Item = $QueueObject->QueueGet(
            ID => $ItemID,
        );
        next ITEMID if !%Item;

        # Prepare queue information.
        $Item{ID} = $Item{QueueID} || '';

        push @Items, \%Item,;
    }

    if ( !@Items ) {
        $Self->Print("No queues found\n");

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
