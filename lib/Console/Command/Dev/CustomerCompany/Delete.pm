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

package Console::Command::Dev::CustomerCompany::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::CustomerCompany',
    'Kernel::System::CustomerCompany',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more Customer Companies.');
    $Self->AddOption(
        Name        => 'name',
        Description => "Specify the name of customer companies to be deleted e.g. *MyCustomerCompany*..",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'id',
        Description => 'Specify the email id of customer companies to be deleted e.g. *customercompany*..',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 0,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $OptionsCounter = 0;
    for my $Option (qw(name id)) {
        if ( $Self->GetOption($Option) ) {
            $OptionsCounter++;
        }
    }

    if ( $OptionsCounter > 1 ) {
        die("Only one option (name or id) can be used at a time!\n");
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting customer companies...</yellow>\n");

    my %SearchOptions;

    my $Name = $Self->GetOption('name');
    my $ID   = $Self->GetOption('id');

    # CustomerCompany name search
    if ($Name) {
        $SearchOptions{CutomerCompanyName} = $Name;
    }
    if ( $ID && $ID =~ m{\*}x ) {
        $SearchOptions{CustomerID} = $ID;
    }

    my @List;

    my $CustomerCompanyObject = $Kernel::OM->Get('Kernel::System::CustomerCompany');

    if (%SearchOptions) {

        my $ItemIDs = $CustomerCompanyObject->CustomerCompanySearchDetail(
            %SearchOptions,
            Valid => 0,
            Limit => 10_000,
        );
        @List = sort @{$ItemIDs};
    }
    elsif ($ID) {
        push @List, $ID,;
    }

    my @ItemsToDelete = @List;

    my $Failed;

    my $DevCustomerCompanyObject = $Kernel::OM->Get('Dev::CustomerCompany');

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        my %Item = $CustomerCompanyObject->CustomerCompanyGet(
            CustomerID => $ItemID,
        );
        if ( !%Item ) {
            $Self->PrintError("The customer company with CustomerID $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        my $Success = $DevCustomerCompanyObject->CustomerCompanyDelete(
            CustomerID => $ItemID,
        );
        if ( !$Success ) {
            $Self->PrintError("Can't delete customer company $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted customer company <yellow>$ItemID</yellow>\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all customer companies where deleted.\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
