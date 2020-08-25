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

package Console::Command::Dev::FAQ::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::FAQ',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more FAQs.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more FAQ ids of FAQs to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of FAQ ids to be deleted. (e.g. 1..10)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'clean-system',
        Description => "Remove all FAQs but leave initial welcome FAQ",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $OptionsCounter = 0;
    for my $Option (qw(id id-range clean-system)) {
        if ( $Self->GetOption($Option) ) {
            $OptionsCounter++;
        }
    }

    if ( $OptionsCounter > 1 ) {
        die("Only one option (id or id-range or clean-system) can be used at a time!\n");
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting FAQ items...</yellow>\n");

    my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

    my @FAQIDs;
    if ( $Self->GetOption('id') ) {
        @FAQIDs = @{ $Self->GetOption('id') };
    }
    elsif ( $Self->GetOption('id-range') ) {
        if ( $Self->GetOption('id-range') =~ m{\A(\d+)\.\.(\d+)\z} ) {
            @FAQIDs = ( $1 .. $2 );
        }
    }
    elsif ( $Self->GetOption('clean-system') ) {

        # search all FAQs
        my @FAQIDsRaw = $FAQObject->FAQSearch(
            Result           => 'ARRAY',
            UserID           => 1,
            OrderBy          => [ 'FAQID', ],
            OrderByDirection => ['Up'],
        );

        # remove welcome FAQ
        @FAQIDs = grep { $_ != 1 } @FAQIDsRaw;
    }

    if ( !@FAQIDs ) {
        $Self->Print("<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $Failed;

    FAQID:
    for my $FAQID (@FAQIDs) {

        next FAQID if !$FAQID;

        # get FAQ details
        my %FAQ = $FAQObject->FAQGet(
            ItemID => $FAQID,
            UserID => 1,
        );

        # check if FAQ exists
        if ( !%FAQ ) {
            $Self->PrintError("The FAQ with ID $FAQID does not exist!\n");
            $Failed = 1;
            next FAQID;
        }

        # delete FAQ
        my $Success = $FAQObject->FAQDelete(
            ItemID => $FAQID,
            UserID => 1,
        );

        if ( !$Success ) {
            $Self->Print("<red>Can't delete FAQ $FAQID</red>\n");
            $Failed = 1;
        }
        else {
            $Self->Print(" Deleted FAQ $FAQID\n");
        }
    }

    if ($Failed) {
        $Self->Print("<red>Not all FAQs where deleted</red>\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
