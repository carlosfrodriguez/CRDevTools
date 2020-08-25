# --
# Copyright (C) 2017 Carlos Rodriguez, https://github.com/carlosfrodriguez
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --
# DO NOT USE THIS FILE ON PRODUCTION SYSTEMS!
#
# otrs is Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --

package Console::Command::Dev::ChatChannel::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Chat',
    'Kernel::System::ChatChannel',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->{ItemName}         = 'Chat Channel';
    $Self->{ItemNamePlural}   = 'Chat Channels';
    $Self->{ItemNamePluralLC} = lc $Self->{ItemNamePlural};

    $Self->Description("Delete one or more $Self->{ItemNamePluralLC}.");
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more $Self->{ItemName} IDs of $Self->{ItemNamePlural} to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of $Self->{ItemName} IDs to be deleted. (e.g. 1..10)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'delete-chats',
        Description => "also remove all associated chats with deleted $Self->{ItemNamePlural}",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $OptionsCounter = 0;
    for my $Option (qw(id id-range)) {
        if ( $Self->GetOption($Option) ) {
            $OptionsCounter++;
        }
    }

    if ( $OptionsCounter > 1 ) {
        die("Only one option (id or id-range) can be used at a time!\n");
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting $Self->{ItemNamePlural} ...</yellow>\n");

    my $ChatObject        = $Kernel::OM->Get('Kernel::System::Chat');
    my $ChatChannelObject = $Kernel::OM->Get('Kernel::System::ChatChannel');

    my @ItemsToDelete;
    if ( $Self->GetOption('id') ) {
        @ItemsToDelete = @{ $Self->GetOption('id') };
    }
    elsif ( $Self->GetOption('id-range') ) {
        if ( $Self->GetOption('id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @ItemsToDelete = ( $1 .. $2 );
        }
    }

    my $Failed;

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        # get item details
        my %Item = $ChatChannelObject->ChatChannelGet(
            ChatChannelID => $ItemID,
            UserID        => 1,
        );

        # Check if item exists.
        if ( !%Item ) {
            $Self->PrintError("The $Self->{ItemName} with ID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        my @Chats = $ChatObject->ChatList(
            ChannelIDs => [$ItemID],
        );

        if ( $Self->GetOption('delete-chats') ) {

            for my $Chat (@Chats) {

                my $ChatID = $Chat->{ChatID};

                # Delete dependent item.
                my $Success = $ChatObject->ChatDelete(
                    ChatID => $ChatID,
                    UserID => 1,
                );

                if ($Success) {
                    $Self->Print(
                        "  Chat $ChatID deleted as it was used by $Self->{ItemName} <yellow>$ItemID</yellow>\n"
                    );
                }
                else {
                    $Self->PrintError("Can't delete chat $ChatID\n");
                    $Failed = 1;
                }
            }
        }
        elsif (@Chats) {
            $Self->PrintError("Could not delete $Self->{ItemName} $ItemID due the following chats use it:\n");
            for my $Chat (@Chats) {
                $Self->Print("  Used by Chat <red>$Chat->{ChatID}</red>\n");
                $Failed = 1;
            }
            next ITEMID;
        }

        # Delete Item.
        my $Success = $ChatChannelObject->ChatChannelDelete(
            ChatChannelID => $ItemID,
            UserID        => 1,
        );

        if ( !$Success ) {
            $Self->PrintError("Can't delete $Self->{ItemName} $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted $Self->{ItemName} <yellow>$ItemID</yellow>\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all $Self->{ItemNamePlural} where deleted\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();

}

1;
