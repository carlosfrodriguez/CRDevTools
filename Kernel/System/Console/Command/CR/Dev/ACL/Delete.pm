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

package Kernel::System::Console::Command::CR::Dev::ACL::Delete;

use strict;
use warnings;

use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::ACL::DB::ACL',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more ACLs.');
    $Self->AddOption(
        Name        => 'id',
        Description => "Specify one or more ACL ids of ACLs to be deleted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'id-range',
        Description => "Specify a range of ACL ids to be deleted. (e.g. 1..10)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+\.\.\d+/smx,
        Multiple    => 0,
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

    $Self->Print("<yellow>Deleting ACLs...</yellow>\n");

    my $ACLObject = $Kernel::OM->Get('Kernel::System::ACL::DB::ACL');

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
        my $Item = $ACLObject->ACLGet(
            ID     => $ItemID,
            UserID => 1,
        );

        # check if item exists
        if ( !$Item ) {
            $Self->PrintError("The ACL with ID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        # delete Type
        my $Success = $ACLObject->ACLDelete(
            ID     => $ItemID,
            UserID => 1,
        );

        if ( !$Success ) {
            $Self->PrintError("Can't delete ACL $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted ACL <yellow>$ItemID</yellow>\n");
    }

    my $Location = $Kernel::OM->Get('Kernel::Config')->Get('Home') . '/Kernel/Config/Files/ZZZACL.pm';

    my $ACLDump = $ACLObject->ACLDump(
        ResultType => 'FILE',
        Location   => $Location,
        UserID     => 1,
    );

    if ($ACLDump) {
        my $Success = $ACLObject->ACLsNeedSyncReset();
        if ( !$Success ) {
            $Self->PrintError("There was an error setting the entity sync status.");
        }
    }
    else {
        $Self->PrintError("There was an error synchronizing the ACLs.");
    }

    if ($Failed) {
        $Self->PrintError("Not all ACLs where deleted\n");
        return $Self->ExitCodeError();
    }

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
