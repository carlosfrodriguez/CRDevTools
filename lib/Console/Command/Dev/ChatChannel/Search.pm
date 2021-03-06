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

package Console::Command::Dev::ChatChannel::Search;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::ChatChannel',
    'Kernel::System::ChatChannel',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->{ItemName}       = 'Chat Channel';
    $Self->{ItemNamePlural} = 'Chat Channels';

    $Self->Description("Search Chat Channels in the system.");

    $Self->AddOption(
        Name        => 'name',
        Description => "Search $Self->{ItemNamePlural} with specified $Self->{ItemName} name e.g. *MyChatChannel*.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing $Self->{ItemNamePlural} ...</yellow>\n");

    my %SearchOptions;

    my %List;

    # Item name search.
    if ( $Self->GetOption('name') ) {
        $SearchOptions{Name} = $Self->GetOption('name');
    }

    my $ChatChannelObject = $Kernel::OM->Get('Kernel::System::ChatChannel');

    if (%SearchOptions) {

        %List = $Kernel::OM->Get('Dev::ChatChannel')->ChatChannelSearch(
            %SearchOptions,
        );
    }
    else {

        my @AllChatChannels = $ChatChannelObject->ChatChannelsGet(
            Valid          => 0,
            IncludeDefault => 0,
        );

        %List = map { $_->{ChatChannelID} => $_->{Name} } @AllChatChannels;
    }

    my @ItemIDs = sort { $a <=> $b } keys %List;

    # To store all item details.
    my @Items;

    ITEM:
    for my $ItemID (@ItemIDs) {

        next ITEM if !$ItemID;

        # Get item details.
        my %Item = $ChatChannelObject->ChatChannelGet(
            ChatChannelID => $ItemID,
            UserID        => 1,
        );
        next ITEM if !%Item;

        # Store item details.
        push @Items, \%Item,;
    }

    if ( !@Items ) {
        $Self->Print("No $Self->{ItemNamePlural} found\n");

        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->OutputTable(
        Items        => \@Items,
        Columns      => [ 'ChatChannelID', 'Name', ],
        ColumnLength => {
            ChatChannelID => 50,
            Name          => 50,
        },
    );

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
