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

package Console::Command::Dev::CustomerUser::Delete;

use strict;
use warnings;

use parent qw(Console::BaseCommand);

our @ObjectDependencies = (
    'Dev::CustomerUser',
    'Kernel::System::CustomerUser',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete one or more Customer Users.');
    $Self->AddOption(
        Name        => 'login',
        Description => "Specify the login of customer users to be deleted e.g. *MyCustomerUser*..",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
        Multiple    => 0,
    );
    $Self->AddOption(
        Name        => 'email',
        Description => 'Specify the email address of customer users to be deleted e.g. *some@example.com*..',
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
    for my $Option (qw(login email)) {
        if ( $Self->GetOption($Option) ) {
            $OptionsCounter++;
        }
    }

    if ( $OptionsCounter > 1 ) {
        die("Only one option (login or email) can be used at a time!\n");
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting customer users...</yellow>\n");

    my %SearchOptions;

    my $Login = $Self->GetOption('login');
    my $Email = $Self->GetOption('email');

    # CustomerUser name search
    if ( $Login && $Login =~ m{\*} ) {
        $SearchOptions{UserLogin} = $Login;
    }
    if ( $Email && $Email =~ m{\*} ) {
        $SearchOptions{PostMasterSearch} = $Email;
    }

    my %List;

    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    if (%SearchOptions) {
        %List = $CustomerUserObject->CustomerSearch(
            %SearchOptions,
            Valid => 0,
            Limit => 10_000,
        );
    }
    elsif ($Login) {
        my %User = $CustomerUserObject->CustomerUserDataGet(
            User => $Login,
        );
        $List{ $User{UserLogin} } = $User{UserEmail};
    }
    elsif ($Email) {
        my %User = $CustomerUserObject->CustomerUserDataGet(
            UserEmail => $Email,
        );
        $List{ $User{UserLogin} } = $User{UserEmail};
    }

    my @ItemsToDelete = sort keys %List;

    my $Failed;

    my $DevCustomerUserObject = $Kernel::OM->Get('Dev::CustomerUser');

    ITEMID:
    for my $ItemID (@ItemsToDelete) {

        next ITEMID if !$ItemID;

        my %Item = $CustomerUserObject->CustomerUserDataGet(
            User => $ItemID,
        );
        if ( !%Item ) {
            $Self->PrintError("The customer user with Login $ItemID does not exist!\n");
            $Failed = 1;
            next ITEMID;
        }

        my $Success = $DevCustomerUserObject->CustomerUserDelete(
            CustomerUser => $ItemID,
        );
        if ( !$Success ) {
            $Self->PrintError("Can't delete customer user $ItemID!\n");
            $Failed = 1;
            next ITEMID;
        }

        $Self->Print("  Deleted customer user <yellow>$ItemID</yellow>\n");
    }

    if ($Failed) {
        $Self->PrintError("Not all customer users where deleted.\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();

}

1;
